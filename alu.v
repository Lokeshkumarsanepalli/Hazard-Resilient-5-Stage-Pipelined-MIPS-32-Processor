`timescale 1ns / 1ps
// ============================================================================
// alu.v
// 32-bit ALU. The 4-bit alu_ctrl selects the operation; `zero` is asserted
// when the result is 0 (used by beq/bne to decide the branch in EX).
// ============================================================================
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_ctrl,
    output reg [31:0] result,
    output            zero
);
    // ALU operation encodings (produced by alu_control.v)
    localparam AND = 4'b0000,
               OR  = 4'b0001,
               ADD = 4'b0010,
               SUB = 4'b0110,
               SLT = 4'b0111;

    always @(*) begin
        case (alu_ctrl)
            AND: result = a & b;
            OR:  result = a | b;
            ADD: result = a + b;
            SUB: result = a - b;
            SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
