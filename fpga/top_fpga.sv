// ========================================================================
// top_fpga.sv – FPGA demo top module for TOTAL-Neuro
// Target: Arty A7-35T (Xilinx Artix-7)
// 
// Controls:
//   btn[0] – reset (active high)
//   btn[1] – start firmware load
//   sw[0]  – select firmware image (0 = good, 1 = corrupted)
//
// Status LEDs:
//   led[0]  – load_done
//   led[1]  – load_error
//   led[2]  – shield_ok
//   led[3]  – kill_triggered
//   led[4]  – clock alive (heartbeat)
//   led[7:5] – reserved
//   led[15:8] – cycle counter (visual activity)
// ========================================================================

`timescale 1ns / 1ps

module top_fpga (
    input  logic        clk,          // 100 MHz onboard oscillator (pin E3)
    input  logic [3:0]  btn,          // 4 buttons
    input  logic [3:0]  sw,           // 4 switches
    output logic [15:0] led           // 16 LEDs
);

    // ================================================================
    // 1. Reset synchronization
    // ================================================================
    logic rst_n;
    logic rst_sync_1, rst_sync_2;
    
    always_ff @(posedge clk) begin
        rst_sync_1 <= btn[0];         // btn[0] = reset (active high)
        rst_sync_2 <= rst_sync_1;
    end
    
    assign rst_n = ~rst_sync_2;


    // ================================================================
    // 2. Embedded firmware image (fake SPI Flash)
    //    Two variants: good (NEURO signature) and bad (WRONG signature)
    // ================================================================
    logic [7:0] firmware_rom [0:63];   // 64 bytes
    logic [7:0] firmware_byte;
    logic [5:0] firmware_addr;

    always_comb begin
        // Bad firmware: first byte 0x58 ('X' instead of 'N')
        // Good firmware: first byte 0x4E ('N')
        if (sw[0]) begin
            // Corrupted signature
            firmware_rom[0] = 8'h58;  // 'X' (WRONG)
        end else begin
            // Valid signature
            firmware_rom[0] = 8'h4E;  // 'N'
        end
        // Shared firmware body
        firmware_rom[1]  = 8'h45;  // 'E'
        firmware_rom[2]  = 8'h55;  // 'U'
        firmware_rom[3]  = 8'h52;  // 'R'
        firmware_rom[4]  = 8'h4F;  // 'O'
        firmware_rom[5]  = 8'h01;  // version
        firmware_rom[6]  = 8'h02;  // num_routers = 2
        firmware_rom[7]  = 8'h00;
        // Router 0: 2 instructions
        firmware_rom[8]  = 8'h00;
        firmware_rom[9]  = 8'h00;
        firmware_rom[10] = 8'h02;
        firmware_rom[11] = 8'h00;
        firmware_rom[12] = 8'h00;
        firmware_rom[13] = 8'h00;
        firmware_rom[14] = 8'h10;
        firmware_rom[15] = 8'h00;
        firmware_rom[16] = 8'h01;
        firmware_rom[17] = 8'h00;
        firmware_rom[18] = 8'h20;
        firmware_rom[19] = 8'h00;
        firmware_rom[20] = 8'h02;
        firmware_rom[21] = 8'h00;
        // Router 1: 1 instruction
        firmware_rom[22] = 8'h01;
        firmware_rom[23] = 8'h00;
        firmware_rom[24] = 8'h01;
        firmware_rom[25] = 8'h00;
        firmware_rom[26] = 8'h00;
        firmware_rom[27] = 8'h00;
        firmware_rom[28] = 8'h30;
        firmware_rom[29] = 8'h00;
        firmware_rom[30] = 8'h03;
        firmware_rom[31] = 8'h00;
        // Remaining bytes zero
        for (int i = 32; i < 64; i = i + 1)
            firmware_rom[i] = 8'h00;
    end

    assign firmware_byte = firmware_rom[firmware_addr];


    // ================================================================
    // 3. Loader FSM instantiation + memory emulation
    // ================================================================
    localparam NUM_ROUTERS = 4;
    localparam ADDR_WIDTH  = 8;
    localparam SRAM_WIDTH  = 32;

    // APB signals
    logic        psel, penable, pwrite;
    logic [5:0]  paddr;
    logic [31:0] pwdata, prdata;
    logic        pready;

    // Memory interface
    logic        mem_data_valid;
    logic [31:0] mem_data;
    logic        mem_req;
    logic [31:0] mem_addr;

    // SRAM
    logic [NUM_ROUTERS-1:0] sram_csn, sram_wen;
    logic [NUM_ROUTERS-1:0][ADDR_WIDTH-1:0] sram_addr;
    logic [NUM_ROUTERS-1:0][SRAM_WIDTH-1:0] sram_din;

    // Status
    logic load_done, load_error, noc_ready;

    // ================================================================
    // 4. Firmware loader state machine (fake SPI Flash controller)
    // ================================================================
    typedef enum logic [2:0] {
        FW_IDLE,
        FW_WAIT_REQ,
        FW_DRIVE,
        FW_DONE
    } fw_state_t;

    fw_state_t fw_state, fw_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fw_state       <= FW_IDLE;
            mem_data_valid <= 1'b0;
            mem_data       <= 32'h0;
            firmware_addr  <= 6'h0;
        end else begin
            case (fw_state)
                FW_IDLE: begin
                    mem_data_valid <= 1'b0;
                    firmware_addr  <= 6'h0;
                    if (btn[1]) fw_state <= FW_WAIT_REQ;
                end
                FW_WAIT_REQ: begin
                    if (mem_req) fw_state <= FW_DRIVE;
                end
                FW_DRIVE: begin
                    mem_data       <= {24'h0, firmware_byte};
                    mem_data_valid <= 1'b1;
                    firmware_addr  <= firmware_addr + 6'h1;
                    fw_state       <= FW_WAIT_REQ;
                end
                FW_DONE: begin
                    mem_data_valid <= 1'b0;
                end
                default: fw_state <= FW_IDLE;
            endcase
        end
    end


    // ================================================================
    // 5. APB master FSM (initiates load sequence on button press)
    // ================================================================
    typedef enum logic [2:0] {
        APB_IDLE,
        APB_WR_BASE,
        APB_WR_CTRL,
        APB_DONE
    } apb_state_t;

    apb_state_t apb_state;
    logic       btn1_prev;
    logic       btn1_rising;

    always_ff @(posedge clk) begin
        btn1_prev   <= btn[1];
        btn1_rising <= btn[1] & ~btn1_prev;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            apb_state <= APB_IDLE;
            psel      <= 1'b0;
            penable   <= 1'b0;
            pwrite    <= 1'b0;
            paddr     <= 6'h0;
            pwdata    <= 32'h0;
        end else begin
            case (apb_state)
                APB_IDLE: begin
                    psel <= 1'b0; penable <= 1'b0; pwrite <= 1'b0;
                    if (btn1_rising) apb_state <= APB_WR_BASE;
                end
                APB_WR_BASE: begin
                    psel   <= 1'b1;
                    penable <= 1'b0;
                    pwrite <= 1'b1;
                    paddr  <= 6'h08;          // REG_BASE_LO
                    pwdata <= 32'h0;
                    apb_state <= APB_WR_CTRL;
                end
                APB_WR_CTRL: begin
                    penable <= 1'b1;
                    paddr   <= 6'h04;         // REG_CONTROL
                    pwdata  <= 32'h0000_0001; // START_LOAD
                    apb_state <= APB_DONE;
                end
                APB_DONE: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;
                    pwrite  <= 1'b0;
                    apb_state <= APB_DONE;
                end
                default: apb_state <= APB_IDLE;
            endcase
        end
    end


    // ================================================================
    // 6. Loader FSM instance
    // ================================================================
    loader_fsm_asic #(
        .NUM_ROUTERS(NUM_ROUTERS),
        .SRAM_DEPTH(256),
        .SRAM_WIDTH(SRAM_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_loader (
        .clk(clk),
        .rst_n(rst_n),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pready(pready),
        .prdata(prdata),
        .mem_data_valid(mem_data_valid),
        .mem_data(mem_data),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .sram_csn(sram_csn),
        .sram_wen(sram_wen),
        .sram_addr(sram_addr),
        .sram_din(sram_din),
        .load_done(load_done),
        .load_error(load_error),
        .noc_ready(noc_ready)
    );

    // ================================================================
    // 7. Security modules (simplified for FPGA demo)
    // ================================================================
    logic shield_ok;
    logic kill_triggered;
    logic zeroize_req;
    logic glitch_detected;

    // Shield Health Monitor (3 traces, all OK for demo)
    logic [2:0] trace_ok;
    assign trace_ok = 3'b111;  // all intact
    logic level_ok, level_warning, level_critical, level_zeroize;
    logic [7:0] breaks_count;
    logic [1:0] alarm_level;

    shield_health_monitor #(.NUM_TRACES(3)) u_shield_health (
        .clk(clk),
        .rst_n(rst_n),
        .trace_ok(trace_ok),
        .test_mode(1'b0),
        .level_ok(level_ok),
        .level_warning(level_warning),
        .level_critical(level_critical),
        .level_zeroize(level_zeroize),
        .breaks_count(breaks_count),
        .alarm_level(alarm_level)
    );

    assign shield_ok = level_ok;

    // Cycle Monitor (not used in demo, but instantiated to prove it compiles)
    logic cm_glitch, cm_ok;
    logic [31:0] cycles_measured;

    cycle_monitor #(
        .EXPECTED_CYCLES(32'd16),
        .TOLERANCE(32'd4)
    ) u_cycle_mon (
        .clk(clk),
        .rst_n(rst_n),
        .start(btn1_rising),
        .done(load_done),
        .test_mode(1'b0),
        .glitch_detected(cm_glitch),
        .operation_ok(cm_ok),
        .cycles_measured(cycles_measured)
    );

    assign glitch_detected = cm_glitch;

    // Apollo-2 Kill Switch (simplified)
    logic kill_armed;
    apollo_kill_switch u_apollo (
        .clk(clk),
        .rst_n(rst_n),
        .zeroize_req(zeroize_req),
        .integrity_fault(load_error),
        .clock_glitch(cm_glitch),
        .global_key(1'b1),
        .sovereign_key(1'b1),
        .arm(btn[2]),
        .test_mode(1'b0),
        .power_cutoff(),
        .kill_armed(kill_armed),
        .kill_triggered(kill_triggered)
    );

    assign zeroize_req = 1'b0;


    // ================================================================
    // 8. Heartbeat counter (visual proof of clock activity)
    // ================================================================
    logic [31:0] heartbeat;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            heartbeat <= 32'h0;
        else
            heartbeat <= heartbeat + 32'h1;
    end

    // ================================================================
    // 9. LED assignments
    // ================================================================
    always_comb begin
        led[0]    = load_done;
        led[1]    = load_error;
        led[2]    = shield_ok;
        led[3]    = kill_triggered;
        led[4]    = heartbeat[25];        // ~1.5 Hz blink at 100 MHz
        led[7:5]  = 3'b0;
        led[15:8] = heartbeat[23:16];     // fast changing pattern
    end

endmodule
