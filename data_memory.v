`timescale 1ns / 1ps
// ============================================================================
// data_memory.v
// Harvard-style DATA memory (separate from instruction memory).
// Word-addressed internally; `addr` is a byte address (the ALU result).
// Read is combinational (lw in the MEM stage); write is clocked (sw).
// ============================================================================
module data_memory #(
    parameter WORDS = 256
)(
    input             clk,
    input             mem_read,
    input             mem_write,
    input      [31:0] addr,        // byte address (ALU result)
    input      [31:0] write_data,  // store data (rt)
    output     [31:0] read_data
);
    reg [31:0] mem [0:WORDS-1];
    integer i;

    initial for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0000;

    // Combinational read
    assign read_data = (mem_read) ? mem[addr[31:2]] : 32'h0000_0000;

    // Clocked write
    always @(posedge clk)
        if (mem_write)
            mem[addr[31:2]] <= write_data;
endmodule
