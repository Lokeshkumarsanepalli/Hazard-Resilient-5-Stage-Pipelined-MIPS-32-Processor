`timescale 1ns / 1ps
// ============================================================================
// alu_control.v
// Second-level ("local") control. Combines the 2-bit ALUOp from the main
// control unit with the R-type funct field to pick the ALU operation.
//
//   ALUOp = 00  -> ADD   (lw / sw / addi : address or immediate add)
//   ALUOp = 01  -> SUB   (beq / bne     : subtract, test zero)
//   ALUOp = 10  -> look at funct         (R-type)
// ============================================================================
module alu_control (
    input      [1:0] alu_op,
    input      [5:0] funct,
    output reg [3:0] alu_ctrl
);
    localparam AND = 4'b0000,
               OR  = 4'b0001,
               ADD = 4'b0010,
               SUB = 4'b0110,
               SLT = 4'b0111;

    // R-type funct codes
    localparam F_ADD = 6'b100000,
               F_SUB = 6'b100010,
               F_AND = 6'b100100,
               F_OR  = 6'b100101,
               F_SLT = 6'b101010;

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = ADD;      // lw/sw/addi
            2'b01: alu_ctrl = SUB;      // beq/bne
            2'b10: begin                // R-type: decode funct
                case (funct)
                    F_ADD: alu_ctrl = ADD;
                    F_SUB: alu_ctrl = SUB;
                    F_AND: alu_ctrl = AND;
                    F_OR:  alu_ctrl = OR;
                    F_SLT: alu_ctrl = SLT;
                    default: alu_ctrl = ADD;
                endcase
            end
            default: alu_ctrl = ADD;
        endcase
    end
endmodule
