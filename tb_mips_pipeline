`timescale 1ns/1ps
// ============================================================================
// tb_mips_pipeline.v
// Self-checking testbench. Loads program.hex into the processor's instruction
// memory, clocks it, prints a write-back trace, then compares the final
// register file and data memory against hand-computed expected values.
// ============================================================================
module tb_mips_pipeline;
    reg clk = 0;
    reg reset = 1;
    integer i, errors = 0;

    // Device under test
    mips_pipeline #(.PROGFILE("program.hex")) dut (.clk(clk), .reset(reset));

    always #5 clk = ~clk;         // 100 MHz

    // ---- write-back trace: show what commits each cycle ----
    always @(negedge clk) begin
        if (!reset && dut.wb_reg_write && dut.wb_write_reg != 0)
            $display("  [t=%0t] WB: $%0d <= %0d (0x%08h)",
                     $time, dut.wb_write_reg, dut.wb_write_data, dut.wb_write_data);
    end

    task check_reg(input [4:0] r, input [31:0] exp);
        begin
            if (dut.rf.regs[r] !== exp) begin
                $display("  FAIL: $%0d = %0d  (expected %0d)", r, dut.rf.regs[r], exp);
                errors = errors + 1;
            end else
                $display("  ok  : $%0d = %0d", r, dut.rf.regs[r]);
        end
    endtask

    task check_mem(input integer word_idx, input [31:0] exp);
        begin
            if (dut.dmem.mem[word_idx] !== exp) begin
                $display("  FAIL: mem[%0d] = %0d  (expected %0d)",
                         word_idx, dut.dmem.mem[word_idx], exp);
                errors = errors + 1;
            end else
                $display("  ok  : mem[%0d] = %0d", word_idx, dut.dmem.mem[word_idx]);
        end
    endtask

    initial begin
        $dumpfile("sim/wave.vcd");
        $dumpvars(0, tb_mips_pipeline);

        // hold reset two edges, then release
        repeat (2) @(posedge clk);
        reset = 0;

        $display("\n--- write-back trace ---");
        repeat (60) @(posedge clk);   // plenty of cycles to drain the pipe

        $display("\n--- register checks ---");
        check_reg(1,  5);
        check_reg(2,  3);
        check_reg(3,  8);
        check_reg(4,  5);
        check_reg(5,  13);
        check_reg(6,  5);
        check_reg(7,  1);
        check_reg(8,  8);
        check_reg(9,  13);   // load-use path
        check_reg(12, 7);
        check_reg(14, 9);
        check_reg(16, 42);
        // squashed instructions must NOT have executed:
        check_reg(10, 0);
        check_reg(11, 0);
        check_reg(13, 0);
        check_reg(15, 0);
        check_reg(17, 0);

        $display("\n--- data-memory checks ---");
        check_mem(0, 8);     // sw $3, 0($0)
        check_mem(1, 13);    // sw $9, 4($0)

        $display("\n=========================================");
        if (errors == 0)
            $display("  ALL CHECKS PASSED");
        else
            $display("  %0d CHECK(S) FAILED", errors);
        $display("=========================================\n");
        $finish;
    end
endmodule
