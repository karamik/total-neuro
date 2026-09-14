// ========================================================================
// tb_puf_health_monitor.sv – тестбенч для мониторинга старения PUF
// ========================================================================

`timescale 1ns / 1ps

module tb_puf_health_monitor;

    localparam CLK_PERIOD = 10;

    logic clk, rst_n, test_mode;
    logic [127:0] puf_id_current;
    logic [127:0] puf_id_golden;
    logic puf_valid;
    logic drift_warning, drift_critical;
    logic [7:0] drift_percent;
    logic [31:0] samples_since_reset;

    // DUT with low thresholds for testing
    puf_health_monitor #(
        .DRIFT_WARNING_THRESHOLD(8'd10),   // 10% for testing
        .DRIFT_CRITICAL_THRESHOLD(8'd25)   // 25% for testing
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .puf_id_current(puf_id_current),
        .puf_id_golden(puf_id_golden),
        .puf_valid(puf_valid),
        .test_mode(test_mode),
        .drift_warning(drift_warning),
        .drift_critical(drift_critical),
        .drift_percent(drift_percent),
        .samples_since_reset(samples_since_reset)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task reset_dut();
        rst_n = 0;
        puf_valid = 0;
        test_mode = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
    endtask


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        $display("=== PUF Health Monitor Testbench ===");

        // Initialize golden as all zeros
        puf_id_golden = 128'h0;

        // Test 1: No drift (current == golden)
        reset_dut();
        puf_id_current = 128'h0;
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (!drift_warning && !drift_critical && drift_percent < 2)
            $display("✅ Test 1 PASSED: no drift (drift=%0d%%)", drift_percent);
        else
            $display("❌ Test 1 FAILED: warn=%0d crit=%0d drift=%0d%%",
                     drift_warning, drift_critical, drift_percent);

        // Test 2: Small drift (5 bits set = ~4%)
        puf_id_current = 128'h1F;  // 5 bits
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (!drift_warning && !drift_critical)
            $display("✅ Test 2 PASSED: small drift no warning (drift=%0d%%)", drift_percent);
        else
            $display("❌ Test 2 FAILED: warn=%0d crit=%0d drift=%0d%%",
                     drift_warning, drift_critical, drift_percent);


        // Test 3: Warning level drift (~15 bits = ~12%)
        puf_id_current = 128'h7FFF;  // 15 bits
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (drift_warning && !drift_critical)
            $display("✅ Test 3 PASSED: warning level (drift=%0d%%)", drift_percent);
        else
            $display("❌ Test 3 FAILED: warn=%0d crit=%0d drift=%0d%%",
                     drift_warning, drift_critical, drift_percent);

        // Test 4: Critical level drift (~40 bits = ~31%)
        puf_id_current = 128'hFFFFFFFFFF;  // 40 bits
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (drift_warning && drift_critical)
            $display("✅ Test 4 PASSED: critical level (drift=%0d%%)", drift_percent);
        else
            $display("❌ Test 4 FAILED: warn=%0d crit=%0d drift=%0d%%",
                     drift_warning, drift_critical, drift_percent);

        // Test 5: test_mode disables monitoring
        reset_dut();
        test_mode = 1;
        puf_id_current = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;  // full drift
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (!drift_warning && !drift_critical && drift_percent == 0)
            $display("✅ Test 5 PASSED: test_mode forces clear");
        else
            $display("❌ Test 5 FAILED: warn=%0d crit=%0d drift=%0d%%",
                     drift_warning, drift_critical, drift_percent);

        // Test 6: samples counter increments
        reset_dut();
        puf_id_current = 128'h0;
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        puf_valid = 1;
        #(CLK_PERIOD * 2);
        puf_valid = 0;
        #(CLK_PERIOD * 2);
        if (samples_since_reset >= 2)
            $display("✅ Test 6 PASSED: samples counter works (=%0d)", samples_since_reset);
        else
            $display("❌ Test 6 FAILED: samples=%0d", samples_since_reset);

        $display("=== Testbench complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
