`timescale 1ns / 1ps
// ============================================================================
// mips_pipeline.v   -- TOP LEVEL
// Hazard-resilient 5-stage pipelined MIPS32 processor.
//
//   Stages :  IF  ->  ID  ->  EX  ->  MEM  ->  WB
//   Pipe regs:   IF/ID    ID/EX    EX/MEM    MEM/WB
//
//   Data hazards  : forwarding_unit (EX-EX, MEM-EX) + negedge regfile write
//   Load-use      : hazard_detection_unit inserts 1 bubble, then forwards
//   Control hazard: beq/bne resolved in EX (2-cycle flush)
//                   j       resolved in ID (1-cycle flush)
//   Memories      : separate instruction & data memory (Harvard)
//
// This file also declares the four pipeline registers (as `reg`s updated in
// clocked always blocks) and instantiates every functional unit.
// ============================================================================
module mips_pipeline #(
    parameter PROGFILE = "program.hex"
)(
    input clk,
    input reset
);
    // =====================================================================
    // IF STAGE
    // =====================================================================
    reg  [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] instr;

    instruction_memory #(.PROGFILE(PROGFILE)) imem (
        .addr (pc),
        .instr(instr)
    );

    // ---- IF/ID pipeline register ----
    reg [31:0] ifid_instr;
    reg [31:0] ifid_pc4;

    // =====================================================================
    // ID STAGE
    // =====================================================================
    wire [5:0]  opcode = ifid_instr[31:26];
    wire [4:0]  rs     = ifid_instr[25:21];
    wire [4:0]  rt     = ifid_instr[20:16];
    wire [4:0]  rd     = ifid_instr[15:11];
    wire [5:0]  funct  = ifid_instr[5:0];
    wire [15:0] imm16  = ifid_instr[15:0];
    wire [25:0] jaddr  = ifid_instr[25:0];

    // main control
    wire       c_reg_dst, c_alu_src, c_mem_to_reg, c_reg_write;
    wire       c_mem_read, c_mem_write, c_branch, c_bne, c_jump;
    wire [1:0] c_alu_op;
    control_unit ctrl (
        .opcode(opcode),
        .reg_dst(c_reg_dst), .alu_src(c_alu_src), .mem_to_reg(c_mem_to_reg),
        .reg_write(c_reg_write), .mem_read(c_mem_read), .mem_write(c_mem_write),
        .branch(c_branch), .bne(c_bne), .jump(c_jump), .alu_op(c_alu_op)
    );

    // register file
    wire [31:0] rf_rd1, rf_rd2;
    // write-back signals (declared here, driven by WB stage below)
    wire        wb_reg_write;
    wire [4:0]  wb_write_reg;
    wire [31:0] wb_write_data;

    register_file rf (
        .clk(clk), .we(wb_reg_write),
        .ra1(rs), .ra2(rt), .wa(wb_write_reg), .wd(wb_write_data),
        .rd1(rf_rd1), .rd2(rf_rd2)
    );

    // sign extend
    wire [31:0] imm32;
    sign_extend se (.in(imm16), .out(imm32));

    // jump target: (PC+4)[31:28] : jaddr : 00
    wire [31:0] jump_target = {ifid_pc4[31:28], jaddr, 2'b00};

    // hazard detection (load-use)
    wire stall;
    hazard_detection_unit hdu (
        .id_ex_mem_read(idex_mem_read),
        .id_ex_rt      (idex_rt),
        .if_id_rs      (rs),
        .if_id_rt      (rt),
        .stall         (stall)
    );

    // ---- ID/EX pipeline register ----
    reg        idex_reg_dst, idex_alu_src, idex_mem_to_reg, idex_reg_write;
    reg        idex_mem_read, idex_mem_write, idex_branch, idex_bne;
    reg [1:0]  idex_alu_op;
    reg [31:0] idex_rd1, idex_rd2, idex_imm32, idex_pc4;
    reg [4:0]  idex_rs, idex_rt, idex_rd;
    reg [5:0]  idex_funct;

    // =====================================================================
    // EX STAGE
    // =====================================================================
    wire [3:0] alu_ctrl;
    alu_control aluc (.alu_op(idex_alu_op), .funct(idex_funct), .alu_ctrl(alu_ctrl));

    // forwarding
    wire [1:0] forward_a, forward_b;
    forwarding_unit fwd (
        .id_ex_rs(idex_rs), .id_ex_rt(idex_rt),
        .ex_mem_rd(exmem_write_reg), .ex_mem_regwrite(exmem_reg_write),
        .mem_wb_rd(memwb_write_reg), .mem_wb_regwrite(memwb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    // 3:1 forwarding muxes (00 = regfile value, 10 = EX/MEM alu, 01 = WB data)
    reg [31:0] fwd_a_val, fwd_b_val;
    always @(*) begin
        case (forward_a)
            2'b10:   fwd_a_val = exmem_alu_result;
            2'b01:   fwd_a_val = wb_write_data;
            default: fwd_a_val = idex_rd1;
        endcase
        case (forward_b)
            2'b10:   fwd_b_val = exmem_alu_result;
            2'b01:   fwd_b_val = wb_write_data;
            default: fwd_b_val = idex_rd2;
        endcase
    end

    // ALU
    wire [31:0] alu_in_b = idex_alu_src ? idex_imm32 : fwd_b_val;
    wire [31:0] alu_result;
    wire        alu_zero;
    alu alu_u (.a(fwd_a_val), .b(alu_in_b), .alu_ctrl(alu_ctrl),
               .result(alu_result), .zero(alu_zero));

    // destination register (RegDst)
    // the destination register number selected in the Execute (EX) stage, which will receive the instruction's result in the Write-Back (WB) stage
    wire [4:0] ex_write_reg = idex_reg_dst ? idex_rd : idex_rt;

    // branch resolution (in EX)
    wire [31:0] branch_target = idex_pc4 + (idex_imm32 << 2);
    wire        branch_taken  = idex_branch & (idex_bne ? ~alu_zero : alu_zero);

    // ---- EX/MEM pipeline register ----
    reg        exmem_mem_read, exmem_mem_write, exmem_mem_to_reg, exmem_reg_write;
    reg [31:0] exmem_alu_result, exmem_store_data;
    reg [4:0]  exmem_write_reg;

    // =====================================================================
    // MEM STAGE
    // =====================================================================
    wire [31:0] mem_read_data;
    data_memory dmem (
        .clk(clk),
        .mem_read (exmem_mem_read),
        .mem_write(exmem_mem_write),
        .addr     (exmem_alu_result),
        .write_data(exmem_store_data),
        .read_data(mem_read_data)
    );

    // ---- MEM/WB pipeline register ----
    reg        memwb_mem_to_reg, memwb_reg_write;
    reg [31:0] memwb_read_data, memwb_alu_result;
    reg [4:0]  memwb_write_reg;

    // =====================================================================
    // WB STAGE
    // =====================================================================
    assign wb_write_data = memwb_mem_to_reg ? memwb_read_data : memwb_alu_result;
    assign wb_write_reg  = memwb_write_reg;
    assign wb_reg_write  = memwb_reg_write;

    // =====================================================================
    // SEQUENTIAL: PC + all pipeline registers, with stall & flush control
    // =====================================================================

    // ---- PC ----
    always @(posedge clk) begin
        if (reset)                pc <= 32'd0;
        else if (branch_taken)    pc <= branch_target;   // control hazard (EX)
        else if (c_jump)          pc <= jump_target;      // control hazard (ID)
        else if (stall)           pc <= pc;               // load-use freeze
        else                      pc <= pc_plus4;
    end

    // ---- IF/ID ----
    always @(posedge clk) begin
        if (reset || branch_taken || c_jump) begin
            ifid_instr <= 32'h0000_0000;                  // flush -> NOP
            ifid_pc4   <= 32'h0000_0000;
        end else if (stall) begin
            ifid_instr <= ifid_instr;                     // freeze (hold)
            ifid_pc4   <= ifid_pc4;
        end else begin
            ifid_instr <= instr;
            ifid_pc4   <= pc_plus4;
        end
    end

    // ---- ID/EX ----
    // Bubble on reset, branch flush, or load-use stall.
    task idex_bubble; begin
        idex_reg_dst    <= 1'b0; idex_alu_src  <= 1'b0; idex_mem_to_reg <= 1'b0;
        idex_reg_write  <= 1'b0; idex_mem_read <= 1'b0; idex_mem_write  <= 1'b0;
        idex_branch     <= 1'b0; idex_bne      <= 1'b0; idex_alu_op     <= 2'b00;
        idex_rd1 <= 32'b0; idex_rd2 <= 32'b0; idex_imm32 <= 32'b0; idex_pc4 <= 32'b0;
        idex_rs  <= 5'b0;  idex_rt  <= 5'b0;  idex_rd    <= 5'b0;  idex_funct <= 6'b0;
    end endtask

    always @(posedge clk) begin
        if (reset || branch_taken || stall) begin
            idex_bubble;
        end else begin
            idex_reg_dst    <= c_reg_dst;
            idex_alu_src    <= c_alu_src;
            idex_mem_to_reg <= c_mem_to_reg;
            idex_reg_write  <= c_reg_write;
            idex_mem_read   <= c_mem_read;
            idex_mem_write  <= c_mem_write;
            idex_branch     <= c_branch;
            idex_bne        <= c_bne;
            idex_alu_op     <= c_alu_op;
            idex_rd1        <= rf_rd1;
            idex_rd2        <= rf_rd2;
            idex_imm32      <= imm32;
            idex_pc4        <= ifid_pc4;
            idex_rs         <= rs;
            idex_rt         <= rt;
            idex_rd         <= rd;
            idex_funct      <= funct;
        end
    end

    // ---- EX/MEM ----
    always @(posedge clk) begin
        if (reset) begin
            exmem_mem_read <= 0; exmem_mem_write <= 0;
            exmem_mem_to_reg <= 0; exmem_reg_write <= 0;
            exmem_alu_result <= 0; exmem_store_data <= 0; exmem_write_reg <= 0;
        end else begin
            exmem_mem_read   <= idex_mem_read;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_reg_write  <= idex_reg_write;
            exmem_alu_result <= alu_result;
            exmem_store_data <= fwd_b_val;        // forwarded rt value (for sw)
            exmem_write_reg  <= ex_write_reg;
        end
    end

    // ---- MEM/WB ----
    always @(posedge clk) begin
        if (reset) begin
            memwb_mem_to_reg <= 0; memwb_reg_write <= 0;
            memwb_read_data <= 0; memwb_alu_result <= 0; memwb_write_reg <= 0;
        end else begin
            memwb_mem_to_reg <= exmem_mem_to_reg;
            memwb_reg_write  <= exmem_reg_write;
            memwb_read_data  <= mem_read_data;
            memwb_alu_result <= exmem_alu_result;
            memwb_write_reg  <= exmem_write_reg;
        end
    end
endmodule
