// ========================================================================
// tb_cycle_monitor.sv – тестбенч для Fixed Cycle Count Monitor
// ========================================================================

`timescale 1ns / 1ps

module tb_cycle_monitor;

    localparam CLK_PERIOD = 10;
    localparam EXPECTED = 32'd10;  // small value for testing

    logic clk, rst_n;
    logic start, done, test_mode;
    logic glitch_detected, operation_ok;
    logic [31:0] cycles_measured;

    // DUT with EXPECTED=10, TOLERANCE=0
    cycle_monitor #(
        .EXPECTED_CYCLES(EXPECTED),
        .TOLERANCE(32'd0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .test_mode(test_mode),
        .glitch_detected(glitch_detected),
        .operation_ok(operation_ok),
        .cycles_measured(cycles_measured)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task reset_dut();
        rst_n = 0;
        start = 0;
        done = 0;
        test_mode = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
    endtask

    // Helper: run operation with exact cycle count
    task run_operation(input int num_cycles);
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(num_cycles) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
    endtask


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        $display("=== Cycle Monitor Testbench ===");

        // Test 1: Exact cycle count (should be OK)
        reset_dut();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(9) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
        if (operation_ok && !glitch_detected)
            $display("✅ Test 1 PASSED: exact cycles OK (measured=%0d)", cycles_measured);
        else
            $display("❌ Test 1 FAILED: ok=%0d glitch=%0d measured=%0d",
                     operation_ok, glitch_detected, cycles_measured);

        // Test 2: Too few cycles (glitch)
        reset_dut();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(3) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
        if (glitch_detected && !operation_ok)
            $display("✅ Test 2 PASSED: too few cycles detected (measured=%0d)", cycles_measured);
        else
            $display("❌ Test 2 FAILED: ok=%0d glitch=%0d measured=%0d",
                     operation_ok, glitch_detected, cycles_measured);


        // Test 3: Too many cycles (glitch)
        reset_dut();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(20) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
        if (glitch_detected && !operation_ok)
            $display("✅ Test 3 PASSED: too many cycles detected (measured=%0d)", cycles_measured);
        else
            $display("❌ Test 3 FAILED: ok=%0d glitch=%0d measured=%0d",
                     operation_ok, glitch_detected, cycles_measured);

        // Test 4: test_mode disables monitoring
        reset_dut();
        test_mode = 1;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(3) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
        if (!glitch_detected)
            $display("✅ Test 4 PASSED: test_mode disables monitoring");
        else
            $display("❌ Test 4 FAILED: test_mode didn't disable");

        // Test 5: glitch clears on new operation
        reset_dut();
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(3) @(posedge clk);
        done = 1;
        @(posedge clk);
        done = 0;
        @(posedge clk);
        if (!glitch_detected) begin
            $display("❌ Test 5 FAILED: glitch not detected first time");
        end else begin
            // Start new operation - glitch should clear
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            @(posedge clk);
            if (!glitch_detected)
                $display("✅ Test 5 PASSED: glitch cleared on new operation");
            else
                $display("❌ Test 5 FAILED: glitch not cleared");
        end

        $display("=== Testbench complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
