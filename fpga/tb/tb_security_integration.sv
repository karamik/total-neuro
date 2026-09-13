// ========================================================================
// tb_security_integration.sv – проверка связки cycle_monitor + apollo
// ========================================================================

`timescale 1ns / 1ps

module tb_security_integration;

    localparam CLK_PERIOD = 10;
    localparam EXPECTED = 32'd10;

    logic clk, rst_n;
    logic op_start, op_done;
    logic zeroize_req, integrity_fault;
    logic global_key, sovereign_key;
    logic arm, test_mode;
    logic power_cutoff, kill_armed, kill_triggered;
    logic glitch_detected, operation_ok;
    logic [31:0] cycles_measured;

    security_integration #(
        .EXPECTED_CYCLES(EXPECTED),
        .TOLERANCE(32'd0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .op_start(op_start),
        .op_done(op_done),
        .zeroize_req(zeroize_req),
        .integrity_fault(integrity_fault),
        .global_key(global_key),
        .sovereign_key(sovereign_key),
        .arm(arm),
        .test_mode(test_mode),
        .power_cutoff(power_cutoff),
        .kill_armed(kill_armed),
        .kill_triggered(kill_triggered),
        .glitch_detected(glitch_detected),
        .operation_ok(operation_ok),
        .cycles_measured(cycles_measured)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;


    task reset_dut();
        rst_n = 0;
        op_start = 0;
        op_done = 0;
        zeroize_req = 0;
        integrity_fault = 0;
        global_key = 0;
        sovereign_key = 0;
        arm = 0;
        test_mode = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
    endtask

    // Helper: run critical op with exact cycle count
    // Waits extra cycles for glitch to propagate through apollo
    task run_critical_op(input int cycles);
        @(posedge clk);
        op_start = 1;
        @(posedge clk);
        op_start = 0;
        repeat(cycles - 1) @(posedge clk);
        op_done = 1;
        @(posedge clk);
        op_done = 0;
        repeat(10) @(posedge clk);  // wait for glitch to propagate
    endtask


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        $display("=== Security Integration Testbench ===");

        // ----------------------------------------------------------
        // Test 1: Exact cycle → operation OK, no cutoff
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        repeat(3) @(posedge clk);
        arm = 0;
        @(posedge clk);
        run_critical_op(EXPECTED);
        if (operation_ok && !glitch_detected && !power_cutoff)
            $display("✅ Test 1 PASSED: exact cycles → no cutoff");
        else
            $display("❌ Test 1 FAILED: ok=%0d glitch=%0d cutoff=%0d",
                     operation_ok, glitch_detected, power_cutoff);

        // ----------------------------------------------------------
        // Test 2: Too few cycles → glitch → cutoff triggered
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        repeat(3) @(posedge clk);
        arm = 0;
        @(posedge clk);
        run_critical_op(3);
        if (glitch_detected && power_cutoff && kill_triggered)
            $display("✅ Test 2 PASSED: glitch auto-triggers cutoff");
        else
            $display("❌ Test 2 FAILED: glitch=%0d cutoff=%0d triggered=%0d",
                     glitch_detected, power_cutoff, kill_triggered);

        // ----------------------------------------------------------
        // Test 3: Too many cycles → glitch → cutoff triggered
        // ----------------------------------------------------------
        reset_dut();
        global_key = 1;
        sovereign_key = 1;
        arm = 1;
        repeat(3) @(posedge clk);
        arm = 0;
        @(posedge clk);
        run_critical_op(25);
        if (glitch_detected && power_cutoff)
            $display("✅ Test 3 PASSED: too many cycles → cutoff");
        else
            $display("❌ Test 3 FAILED: glitch=%0d cutoff=%0d",
                     glitch_detected, power_cutoff);

        $display("=== Testbench complete ===");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
