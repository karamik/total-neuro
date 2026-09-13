// ========================================================================
// tb_loader_fsm.sv – Testbench для Loader FSM
// Симулирует загрузку прошивки из SPI Flash и проверяет запись в SRAM.
// ========================================================================

`timescale 1ns / 1ps

module tb_loader_fsm_error;

    localparam CLK_PERIOD = 10;
    localparam NUM_ROUTERS = 4;
    localparam ADDR_WIDTH = 8;
    localparam SRAM_WIDTH = 32;

    // Clock and reset
    logic clk;
    logic rst_n;

    // APB
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [5:0]  paddr;
    logic [31:0] pwdata;
    logic        pready;
    logic [31:0] prdata;

    // Memory (SPI Flash emulation)
    logic        mem_data_valid;
    logic [31:0] mem_data;
    logic        mem_req;
    logic [31:0] mem_addr;

    // SRAM
    logic [NUM_ROUTERS-1:0] sram_csn;
    logic [NUM_ROUTERS-1:0] sram_wen;
    logic [NUM_ROUTERS-1:0][ADDR_WIDTH-1:0] sram_addr;
    logic [NUM_ROUTERS-1:0][SRAM_WIDTH-1:0] sram_din;

    // Status
    logic load_done;
    logic load_error;
    logic noc_ready;


    // ================================================================
    // DUT instantiation
    // ================================================================
    loader_fsm_asic #(
        .NUM_ROUTERS(NUM_ROUTERS),
        .SRAM_DEPTH(256),
        .SRAM_WIDTH(SRAM_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
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

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;


    // ================================================================
    // SPI Flash emulation (firmware image)
    // ================================================================
    // Firmware structure:
    //   [0-4]   "NEURO" signature (5 bytes)
    //   [5]     version (0x01)
    //   [6-7]   num_routers (2 bytes, little-endian)
    //   For each router:
    //     [n+0..1] router_id (2 bytes)
    //     [n+2..5] num_instrs (4 bytes)
    //     [n+6..]  instructions (4 bytes each)
    logic [7:0] flash_mem [0:255];

    initial begin
        // Инициализация прошивки (4 роутера)
        flash_mem[0] = 8'h58;  // 'X' (WRONG)
        flash_mem[1] = 8'h45;  // 'E'
        flash_mem[2] = 8'h55;  // 'U'
        flash_mem[3] = 8'h52;  // 'R'
        flash_mem[4] = 8'h4F;  // 'O'
        flash_mem[5] = 8'h01;  // version
        flash_mem[6] = 8'h04;  // num_routers = 4 (low)
        flash_mem[7] = 8'h00;  // num_routers = 4 (high)
        // Router 0: ID=0, 2 instructions
        flash_mem[8]  = 8'h00; flash_mem[9]  = 8'h00; // router_id = 0
        flash_mem[10] = 8'h02; flash_mem[11] = 8'h00; // num_instrs = 2
        flash_mem[12] = 8'h00; flash_mem[13] = 8'h00;
        flash_mem[14] = 8'h10; flash_mem[15] = 8'h00; flash_mem[16] = 8'h01; flash_mem[17] = 8'h00; // instr 0
        flash_mem[18] = 8'h20; flash_mem[19] = 8'h00; flash_mem[20] = 8'h02; flash_mem[21] = 8'h00; // instr 1
        // Router 1: ID=1, 1 instruction
        flash_mem[22] = 8'h01; flash_mem[23] = 8'h00;
        flash_mem[24] = 8'h01; flash_mem[25] = 8'h00; flash_mem[26] = 8'h00; flash_mem[27] = 8'h00;
        flash_mem[28] = 8'h30; flash_mem[29] = 8'h00; flash_mem[30] = 8'h03; flash_mem[31] = 8'h00;
        // Router 2: ID=2, 3 instructions
        flash_mem[32] = 8'h02; flash_mem[33] = 8'h00;
        flash_mem[34] = 8'h03; flash_mem[35] = 8'h00; flash_mem[36] = 8'h00; flash_mem[37] = 8'h00;
        flash_mem[38] = 8'h40; flash_mem[39] = 8'h00; flash_mem[40] = 8'h04; flash_mem[41] = 8'h00;
        flash_mem[42] = 8'h50; flash_mem[43] = 8'h00; flash_mem[44] = 8'h05; flash_mem[45] = 8'h00;
        flash_mem[46] = 8'h60; flash_mem[47] = 8'h00; flash_mem[48] = 8'h06; flash_mem[49] = 8'h00;
        // Router 3: ID=3, 2 instructions
        flash_mem[50] = 8'h03; flash_mem[51] = 8'h00;
        flash_mem[52] = 8'h02; flash_mem[53] = 8'h00; flash_mem[54] = 8'h00; flash_mem[55] = 8'h00;
        flash_mem[56] = 8'h70; flash_mem[57] = 8'h00; flash_mem[58] = 8'h07; flash_mem[59] = 8'h00;
        flash_mem[60] = 8'h80; flash_mem[61] = 8'h00; flash_mem[62] = 8'h08; flash_mem[63] = 8'h00;
    end

    // Подача данных из flash по запросу mem_req
    logic [31:0] mem_addr_latched;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_data_valid <= 1'b0;
            mem_data <= 32'h0;
            mem_addr_latched <= 32'h0;
        end else if (mem_req && !mem_data_valid) begin
            mem_addr_latched <= mem_addr;
            mem_data <= {24'h0, flash_mem[mem_addr]};
            mem_data_valid <= 1'b1;
        end else begin
            mem_data_valid <= 1'b0;
        end
    end


    // ================================================================
    // APB tasks
    // ================================================================
    task apb_write(input [5:0] addr, input [31:0] data);
        @(posedge clk);
        psel = 1; penable = 0; pwrite = 1; paddr = addr; pwdata = data;
        @(posedge clk);
        penable = 1;
        @(posedge clk);
        psel = 0; penable = 0; pwrite = 0;
    endtask

    task apb_read(input [5:0] addr);
        @(posedge clk);
        psel = 1; penable = 0; pwrite = 0; paddr = addr;
        @(posedge clk);
        penable = 1;
        @(posedge clk);
        psel = 0; penable = 0;
    endtask

    // ================================================================
    // SRAM monitor (перехватываем запись)
    // ================================================================
    logic [31:0] sram_captured [0:NUM_ROUTERS-1][0:255];
    logic [31:0] sram_write_count [0:NUM_ROUTERS-1];

    integer r;
    initial begin
        for (r = 0; r < NUM_ROUTERS; r = r + 1) begin
            sram_write_count[r] = 0;
        end
    end

    always_ff @(posedge clk) begin
        for (r = 0; r < NUM_ROUTERS; r = r + 1) begin
            if (sram_csn[r] == 1'b0 && sram_wen[r] == 1'b0) begin
                sram_captured[r][sram_addr[r]] <= sram_din[r];
                sram_write_count[r] <= sram_write_count[r] + 1;
                $display("[%0t] SRAM[%0d][%0d] <= 0x%08X", $time, r, sram_addr[r], sram_din[r]);
            end
        end
    end


    // ================================================================
    // Main test scenario
    // ================================================================
    initial begin
        // Initial values
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        rst_n = 0;

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("=== Starting Loader FSM test ===");

        // Write base address (0x0000) to REG_BASE_LO (0x08)
        apb_write(6'h08, 32'h0000_0000);
        // Set START_LOAD in REG_CONTROL (0x04)
        apb_write(6'h04, 32'h0000_0001);

        // Wait for load completion
        #(CLK_PERIOD * 500);

        // Check status
        apb_read(6'h00);
        #(CLK_PERIOD * 2);

        // Check error flag (expected load_error=1)
        if (load_error && !load_done) begin
            $display("✅ load_error=1, load_done=0 (expected)");
        end else begin
            $display("❌ load_error=%0d, load_done=%0d (unexpected)", load_error, load_done);
        end
        #(CLK_PERIOD * 20);
        $display("=== Error Test complete ===");
        $finish;
    end

endmodule
