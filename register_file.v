`timescale 1ns / 1ps
// ============================================================================
// register_file.v
// 32 x 32-bit MIPS register file.
//   - Two combinational read ports (used in the ID stage).
//   - One write port, clocked on the NEGATIVE edge.
//
// Why negedge write?  A value written by an instruction in WB becomes visible
// to an instruction reading in ID during the SAME cycle. That resolves the
// "distance-3" data hazard (producer in WB, consumer in ID) with no extra
// forwarding path. Distances 1 and 2 are handled by the forwarding_unit.
//
//   - Register $0 is hardwired to 0; writes to it are ignored.
// ============================================================================
module register_file (
    input             clk,
    input             we,        // RegWrite, arriving from the WB stage
    input      [4:0]  ra1,       // read address 1 (rs)
    input      [4:0]  ra2,       // read address 2 (rt)
    input      [4:0]  wa,        // write address (rd or rt)
    input      [31:0] wd,        // write data
    output     [31:0] rd1,
    output     [31:0] rd2
);
    integer i;
    reg [31:0] regs [0:31];

    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;

    // Combinational reads; $0 always reads as 0.
    assign rd1 = (ra1 == 5'd0) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'b0 : regs[ra2];

    // Write on the falling edge, never to $0.
    always @(negedge clk)
        if (we && (wa != 5'd0))
            regs[wa] <= wd;
endmodule
