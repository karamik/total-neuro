// ========================================================================
// tb_shield_health_monitor.sv – тестбенч для graduated response
// ========================================================================

`timescale 1ns / 1ps

module tb_shield_health_monitor;

    localparam CLK_PERIOD = 10;

    logic clk, rst_n, test_mode;
    logic [2:0] trace_ok;
    logic level_ok, level_warning, level_critical, level_zeroize;
    logic [7:0] breaks_count;
    logic [1:0] alarm_level;

    // DUT with NUM_TRACES=3
    shield_health_monitor #(.NUM_TRACES(3)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .trace_ok(trace_ok),
        .test_mode(test_mode),
        .level_ok(level_ok),
        .level_warning(level_warning),
        .level_critical(level_critical),
        .level_zeroize(level_zeroize),
        .breaks_count(breaks_count),
        .alarm_level(alarm_level)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task reset_dut();
        rst_n = 0;
        trace_ok = 3'b111;
        test_mode = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
    endtask


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        $display("=== Shield Health Monitor Testbench ===");

        // Test 1: All traces OK → level 0
        reset_dut();
        trace_ok = 3'b111;
        #(CLK_PERIOD * 2);
        if (level_ok && !level_warning && !level_critical && !level_zeroize && breaks_count == 0)
            $display("✅ Test 1 PASSED: 0 breaks → level OK");
        else
            $display("❌ Test 1 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);

        // Test 2: 1 trace broken → WARNING
        trace_ok = 3'b110;
        #(CLK_PERIOD * 2);
        if (level_warning && !level_critical && !level_zeroize && breaks_count == 1)
            $display("✅ Test 2 PASSED: 1 break → WARNING");
        else
            $display("❌ Test 2 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);

        // Test 3: 2 traces broken → CRITICAL
        trace_ok = 3'b100;
        #(CLK_PERIOD * 2);
        if (level_critical && !level_zeroize && breaks_count == 2)
            $display("✅ Test 3 PASSED: 2 breaks → CRITICAL");
        else
            $display("❌ Test 3 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);


        // Test 4: 3 traces broken → ZEROIZE
        trace_ok = 3'b000;
        #(CLK_PERIOD * 2);
        if (level_zeroize && breaks_count == 3)
            $display("✅ Test 4 PASSED: 3 breaks → ZEROIZE");
        else
            $display("❌ Test 4 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);

        // Test 5: Recovery (graduated response clears)
        trace_ok = 3'b111;
        #(CLK_PERIOD * 2);
        if (level_ok && breaks_count == 0)
            $display("✅ Test 5 PASSED: recovery to OK");
        else
            $display("❌ Test 5 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);

        // Test 6: test_mode disables monitoring
        reset_dut();
        test_mode = 1;
        trace_ok = 3'b000;
        #(CLK_PERIOD * 2);
        if (level_ok && breaks_count == 0)
            $display("✅ Test 6 PASSED: test_mode forces OK");
        else
            $display("❌ Test 6 FAILED: level=%0d breaks=%0d", alarm_level, breaks_count);

        $display("=== Testbench complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
