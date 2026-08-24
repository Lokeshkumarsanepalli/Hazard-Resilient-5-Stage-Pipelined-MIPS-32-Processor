`timescale 1ns / 1ps
// ============================================================================
// instruction_memory.v
// Harvard-style INSTRUCTION memory (separate from data memory).
// Word-addressed internally; the PC is a byte address so we index with
// addr[?:2]. Combinational read (fetch happens within the IF stage).
// The program is loaded from a hex file via $readmemh.
// ============================================================================

// https://www.dsi.unive.it/~gasparetto/materials/MIPS_Instruction_Set.pdf

module instruction_memory #(
    parameter WORDS    = 256,                 // 256 instructions
    parameter PROGFILE = "program.hex"
)(
    input      [31:0] addr,        // byte address (from PC)
    output     [31:0] instr
);
    reg [31:0] mem [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0000; // NOP fill
        $readmemh(PROGFILE, mem);
    end

    assign instr = mem[addr[31:2]]; // divide byte address by 4
endmodule
