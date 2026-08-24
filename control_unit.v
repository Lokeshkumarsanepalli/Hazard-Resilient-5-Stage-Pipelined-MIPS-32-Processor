`timescale 1ns / 1ps
// ============================================================================
// control_unit.v
// Main control. Decodes the 6-bit opcode into the datapath control signals.
// Operates in the ID stage. The bundle is latched into ID/EX and travels down
// the pipe with the instruction (a "bubble" = all of these forced to 0).
//
// Supported opcodes:
//   R-type 000000 : add sub and or slt   (funct decides in alu_control)
//   addi   001000
//   lw     100011
//   sw     101011
//   beq    000100
//   bne    000101
//   j      000010
// ============================================================================
module control_unit (
    input      [5:0] opcode,
    output reg       reg_dst,     // 1: write rd (R-type); 0: write rt
    output reg       alu_src,     // 1: 2nd ALU operand = sign-ext imm
    output reg       mem_to_reg,  // 1: write-back value from data memory
    output reg       reg_write,   // 1: instruction writes a register
    output reg       mem_read,    // 1: lw
    output reg       mem_write,   // 1: sw
    output reg       branch,      // 1: beq/bne
    output reg       bne,         // 1: bne (invert the equal test)
    output reg       jump,        // 1: j
    output reg [1:0] alu_op
);
    localparam R_TYPE = 6'b000000,
               ADDI   = 6'b001000,
               LW     = 6'b100011,
               SW     = 6'b101011,
               BEQ    = 6'b000100,
               BNE    = 6'b000101,
               J      = 6'b000010;

    always @(*) begin
        // Safe defaults = NOP (writes nothing, no memory access, no control flow)
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        bne        = 1'b0;
        jump       = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            R_TYPE: begin
                reg_dst   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 2'b10;
            end
            ADDI: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 2'b00;
            end
            LW: begin
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_op     = 2'b00;
            end
            SW: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b00;
            end
            BEQ: begin
                branch = 1'b1;
                alu_op = 2'b01;
            end
            BNE: begin
                branch = 1'b1;
                bne    = 1'b1;
                alu_op = 2'b01;
            end
            J: begin
                jump = 1'b1;
            end
            default: ; // keep NOP defaults
        endcase
    end
endmodule
