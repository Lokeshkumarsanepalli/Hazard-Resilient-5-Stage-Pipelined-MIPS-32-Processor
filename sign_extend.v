`timescale 1ns / 1ps
// ============================================================================
// sign_extend.v
// Sign-extends the 16-bit immediate/offset to 32 bits. MIPS offsets are
// 16-bit words sign-extended to 32 bits (matches the course note:
// "16-bit sign extended to 32-bit").
// ============================================================================
module sign_extend (
    input      [15:0] in,
    output     [31:0] out
);
    assign out = {{16{in[15]}}, in};
endmodule
