`timescale 1ns/1ps

module consent_gate_tb;

    localparam int CMD_WIDTH      = 32;
    localparam int TIMEOUT_CYCLES = 16;
    localparam int REFUSAL_WIDTH  = 8;

    logic clk_main  = 0;
    logic clk_gate  = 0;
    logic clk_audit = 0;

    logic rst_main_n  = 0;
    logic rst_gate_n  = 0;
    logic rst_audit_n = 0;

    logic                  cmd_valid_i;
    logic [CMD_WIDTH-1:0]  cmd_data_i;

    logic sig_ecdsa_valid_i;
    logic sig_dilithium_valid_i;
    logic both_valid_i = 1'b0;
    logic external_consent_i;
    logic tamper_detect_i;

    logic                  gated_cmd_valid_o;
    logic [CMD_WIDTH-1:0]  gated_cmd_data_o;
    logic                  refusal_flag_o;
    logic                  kill_switch_o;
    logic [REFUSAL_WIDTH-1:0] refusal_count_o;
    logic                  audit_valid_o;
    logic [31:0]           audit_event_o;

    consent_gate #(
        .CMD_WIDTH(CMD_WIDTH),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
        .REFUSAL_WIDTH(REFUSAL_WIDTH)
    ) dut (.*);

    always #5  clk_main  = ~clk_main;
    always #7  clk_gate  = ~clk_gate;
    always #13 clk_audit = ~clk_audit;

    task automatic reset_all();
        rst_main_n = 0; rst_gate_n = 0; rst_audit_n = 0;
        cmd_valid_i = 0; cmd_data_i = 0;
        sig_ecdsa_valid_i = 0; sig_dilithium_valid_i = 0;
        external_consent_i = 0; tamper_detect_i = 0;
        #200;
        rst_main_n = 1; rst_gate_n = 1; rst_audit_n = 1;
        #50;
    endtask

    task automatic cause_refuse_no_consent(input logic [31:0] data);
        cmd_data_i = data;
        cmd_valid_i = 1;
        #40; cmd_valid_i = 0;
        sig_ecdsa_valid_i = 1; sig_dilithium_valid_i = 1;
        #2000;
        sig_ecdsa_valid_i = 0; sig_dilithium_valid_i = 0;
        #200;
    endtask

    task automatic cause_refuse_no_sigs(input logic [31:0] data);
        cmd_data_i = data;
        cmd_valid_i = 1;
        #40; cmd_valid_i = 0;
        #2000;
        #200;
    endtask

    initial begin
        $dumpfile("sim/consent_gate.vcd");
        $dumpvars(0, consent_gate_tb);

        reset_all();

        $display("[%0t] === TEST 1: PASS ===", $time);
        cmd_data_i = 32'hDEADBEEF;
        cmd_valid_i = 1;
        #40; cmd_valid_i = 0;
        #20;
        sig_ecdsa_valid_i = 1; sig_dilithium_valid_i = 1;
        #40;
        external_consent_i = 1;
        #100;
        external_consent_i = 0;
        sig_ecdsa_valid_i = 0; sig_dilithium_valid_i = 0;
        #200;

        $display("[%0t] === TEST 2: REFUSE no consent ===", $time);
        cause_refuse_no_consent(32'hCAFEBABE);

        $display("[%0t] === TEST 3: reset pulse ===", $time);
        rst_gate_n = 0;
        #100;
        rst_gate_n = 1;
        #100;
        $display("[%0t]     After reset: refusal_count=%0d (expected 1)",
                 $time, refusal_count_o);

        $display("[%0t] === TEST 4: REFUSE no sigs ===", $time);
        cause_refuse_no_sigs(32'h12345678);

        $display("[%0t] === TEST 5: TAMPER + RESET together ===", $time);
        tamper_detect_i = 1;
        rst_gate_n = 0;
        #200;
        rst_gate_n = 1;
        #100;
        tamper_detect_i = 0;
        #200;
        $display("[%0t]     After tamper+reset: kill=%0b state=%0d count=%0d",
                 $time, kill_switch_o, dut.state, refusal_count_o);
        if (kill_switch_o !== 1'b1)
            $display("     FAIL: kill switch did not latch");
        else
            $display("     OK: kill switch latched");
        if (dut.state !== 3'd5)
            $display("     FAIL: state not ZEROIZE (got %0d)", dut.state);
        else
            $display("     OK: state is ZEROIZE");
        if (refusal_count_o !== '0)
            $display("     FAIL: refusal_count not cleared");
        else
            $display("     OK: refusal_count cleared");

        $display("[%0t] === TEST 6: command after zeroize ===", $time);
        cmd_data_i = 32'hFEEDFACE;
        cmd_valid_i = 1;
        #40; cmd_valid_i = 0;
        #20;
        sig_ecdsa_valid_i = 1; sig_dilithium_valid_i = 1;
        external_consent_i = 1;
        #200;
        external_consent_i = 0;
        sig_ecdsa_valid_i = 0; sig_dilithium_valid_i = 0;
        #200;
        if (dut.state !== 3'd5)
            $display("     FAIL: state changed from ZEROIZE");
        else
            $display("     OK: state still ZEROIZE");

        $display("[%0t] === TEST 7: second reset after zeroize ===", $time);
        rst_gate_n = 0;
        #200;
        rst_gate_n = 1;
        #200;
        $display("[%0t]     After reset: kill=%0b state=%0d",
                 $time, kill_switch_o, dut.state);
        if (dut.state !== 3'd5)
            $display("     FAIL: reset revived FSM (state=%0d)", dut.state);
        else
            $display("     OK: FSM remains ZEROIZE");

        $display("[%0t] === Simulation complete ===", $time);
        $finish;
    end

    logic kill_switch_d;
    logic gated_cmd_valid_d;
    logic refusal_flag_d;

    always @(posedge clk_gate) begin
        kill_switch_d     <= kill_switch_o;
        gated_cmd_valid_d <= gated_cmd_valid_o;
        refusal_flag_d    <= refusal_flag_o;
    end

    always @(posedge clk_gate) begin
        if (gated_cmd_valid_o && !gated_cmd_valid_d)
            $strobe("[%0t] >>> PASS cmd=0x%08X", $time, gated_cmd_data_o);
        if (refusal_flag_o && !refusal_flag_d)
            $strobe("[%0t] >>> REFUSE count=%0d", $time, refusal_count_o);
        if (kill_switch_o && !kill_switch_d)
            $strobe("[%0t] >>> KILL SWITCH ACTIVE", $time);
    end

    always @(posedge clk_audit) begin
        if (audit_valid_o)
            $strobe("[%0t]     AUDIT event=0x%08X", $time, audit_event_o);
    end

endmodule
