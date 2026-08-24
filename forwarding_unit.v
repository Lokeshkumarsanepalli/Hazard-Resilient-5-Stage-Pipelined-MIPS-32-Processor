`timescale 1ns / 1ps
// ============================================================================
// forwarding_unit.v
// Removes RAW data hazards WITHOUT stalling by steering already-computed
// results straight into the ALU inputs in the EX stage.
//
// Two forwarding paths (this is what the resume calls EX-EX and MEM-EX):
//   forward = 10  -> take EX/MEM.alu_result  (producer is 1 instr ahead, in MEM)
//   forward = 01  -> take MEM/WB.write_data  (producer is 2 instr ahead, in WB)
//   forward = 00  -> use the value read from the register file (no hazard)
//
// EX/MEM is checked first so the MOST RECENT producer wins when a register is
// written by two instructions in flight. $0 is never forwarded.
// ============================================================================
module forwarding_unit (
    input      [4:0] id_ex_rs,
    input      [4:0] id_ex_rt,
    input      [4:0] ex_mem_rd,      // destination reg in MEM stage
    input            ex_mem_regwrite,
    input      [4:0] mem_wb_rd,      // destination reg in WB stage
    input            mem_wb_regwrite,
    output reg [1:0] forward_a,      // control for ALU input A (rs)
    output reg [1:0] forward_b       // control for ALU input B (rt)
);
    always @(*) begin
        // ---- operand A (rs) ----
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs))
            forward_a = 2'b10;                                   // EX-EX
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs))
            forward_a = 2'b01;                                   // MEM-EX
        else
            forward_a = 2'b00;

        // ---- operand B (rt) ----
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rt))
            forward_b = 2'b10;                                   // EX-EX
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rt))
            forward_b = 2'b01;                                   // MEM-EX
        else
            forward_b = 2'b00;
    end
endmodule
