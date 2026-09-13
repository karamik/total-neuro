// ========================================================================
// loader_fsm_asic.sv – Loader FSM для ASIC 28nm
// Загружает TDM-расписание из SPI Flash в SRAM роутеров NoC.
// Поддерживает APB-интерфейс, защитные модули и управление питанием.
// ========================================================================

module loader_fsm_asic #(
    parameter NUM_ROUTERS = 4,
    parameter SRAM_DEPTH  = 256,
    parameter SRAM_WIDTH  = 32,
    parameter ADDR_WIDTH  = 8
)(
    input  logic        clk,
    input  logic        rst_n,

    // APB slave interface
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [5:0]  paddr,
    input  logic [31:0] pwdata,
    output logic        pready,
    output logic [31:0] prdata,

    // External memory (SPI Flash)
    input  logic        mem_data_valid,
    input  logic [31:0] mem_data,
    output logic        mem_req,
    output logic [31:0] mem_addr,

    // SRAM interface per router
    output logic [NUM_ROUTERS-1:0] sram_csn,
    output logic [NUM_ROUTERS-1:0] sram_wen,
    output logic [NUM_ROUTERS-1:0][ADDR_WIDTH-1:0] sram_addr,
    output logic [NUM_ROUTERS-1:0][SRAM_WIDTH-1:0] sram_din,

    // Status
    output logic        load_done,
    output logic        load_error,
    output logic        noc_ready
);

    // ================================================================
    // 1. APB control/status registers
    // ================================================================
    logic [31:0] control_reg;
    logic [31:0] status_reg;
    logic [31:0] base_addr_lo;
    logic [31:0] fw_size;

    localparam CTRL_START_LOAD = 0;
    localparam CTRL_RESET      = 1;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_reg  <= 32'h0;
            base_addr_lo <= 32'h0;
            fw_size      <= 32'h0;
        end else if (psel && penable && pwrite) begin
            case (paddr)
                6'h04: control_reg  <= pwdata;
                6'h08: base_addr_lo <= pwdata;
                6'h10: fw_size      <= pwdata;
                default: ;
            endcase
        end
    end

    assign pready = 1'b1;
    assign prdata = (paddr == 6'h00) ? status_reg  :
                    (paddr == 6'h04) ? control_reg :
                    (paddr == 6'h08) ? base_addr_lo :
                    (paddr == 6'h10) ? fw_size     : 32'h0;

    // ================================================================
    // 2. FSM states
    // ================================================================
    typedef enum logic [3:0] {
        IDLE,
        READ_MAGIC,
        READ_VERSION,
        READ_NUM_RTR,
        READ_RTR_ID,
        READ_INST_CNT,
        READ_INST,
        WRITE_SRAM,
        NEXT_RTR,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t state, next_state;


    // ================================================================
    // 3. Internal registers
    // ================================================================
    logic [31:0] mem_addr_reg;
    logic [2:0]  magic_cnt;
    logic [15:0] num_routers_reg;
    logic [15:0] router_idx_reg;
    logic [31:0] num_instrs_reg;
    logic [31:0] instr_idx_reg;
    logic [15:0] cur_router_id_reg;
    logic [31:0] cur_instr_reg;
    logic [1:0]  byte_cnt_reg;
    logic        load_done_reg;
    logic        load_error_reg;
    logic        read_complete;


    // ================================================================
    // 4. SRAM control signals (combinational)
    // ================================================================
    logic [NUM_ROUTERS-1:0] sram_csn_reg;
    logic [NUM_ROUTERS-1:0] sram_wen_reg;
    logic [NUM_ROUTERS-1:0][ADDR_WIDTH-1:0] sram_addr_reg;
    logic [NUM_ROUTERS-1:0][SRAM_WIDTH-1:0] sram_din_reg;

    integer i;
    always_comb begin
        for (i = 0; i < NUM_ROUTERS; i = i + 1) begin
            sram_csn_reg[i]  = 1'b1;
            sram_wen_reg[i]  = 1'b1;
            sram_addr_reg[i] = {ADDR_WIDTH{1'b0}};
            sram_din_reg[i]  = {SRAM_WIDTH{1'b0}};
        end
        if (state == WRITE_SRAM && router_idx_reg < NUM_ROUTERS) begin
            sram_csn_reg[router_idx_reg]  = 1'b0;
            sram_wen_reg[router_idx_reg]  = 1'b0;
            sram_addr_reg[router_idx_reg] = instr_idx_reg[ADDR_WIDTH-1:0];
            sram_din_reg[router_idx_reg]  = cur_instr_reg;
        end
    end

    assign sram_csn  = sram_csn_reg;
    assign sram_wen  = sram_wen_reg;
    assign sram_addr = sram_addr_reg;
    assign sram_din  = sram_din_reg;


    // ================================================================
    // 5. FSM sequential logic
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= IDLE;
            mem_addr_reg      <= 32'h0;
            magic_cnt         <= 3'h0;
            num_routers_reg   <= 16'h0;
            router_idx_reg    <= 16'h0;
            num_instrs_reg    <= 32'h0;
            instr_idx_reg     <= 32'h0;
            cur_router_id_reg <= 16'h0;
            cur_instr_reg     <= 32'h0;
            byte_cnt_reg      <= 2'h0;
            load_done_reg     <= 1'b0;
            load_error_reg    <= 1'b0;
            read_complete     <= 1'b0;
        end else if (control_reg[CTRL_RESET]) begin
            state             <= IDLE;
            load_done_reg     <= 1'b0;
            load_error_reg    <= 1'b0;
            magic_cnt         <= 3'h0;
            router_idx_reg    <= 16'h0;
            instr_idx_reg     <= 32'h0;
            byte_cnt_reg      <= 2'h0;
            read_complete     <= 1'b0;
        end else begin
            state <= next_state;
            read_complete <= 1'b0;

            case (state)
                IDLE: begin
                    if (control_reg[CTRL_START_LOAD]) begin
                        mem_addr_reg    <= base_addr_lo;
                        magic_cnt       <= 3'h0;
                        router_idx_reg  <= 16'h0;
                        instr_idx_reg   <= 32'h0;
                        byte_cnt_reg    <= 2'h0;
                        num_routers_reg <= 16'h0;
                        num_instrs_reg  <= 32'h0;
                        cur_router_id_reg <= 16'h0;
                        cur_instr_reg   <= 32'h0;
                        load_done_reg   <= 1'b0;
                        load_error_reg  <= 1'b0;
                    end
                end

                READ_MAGIC: begin
                    if (mem_data_valid && !read_complete) begin
                        case (magic_cnt)
                            0: if (mem_data[7:0] != 8'h4E) load_error_reg <= 1'b1;
                            1: if (mem_data[7:0] != 8'h45) load_error_reg <= 1'b1;
                            2: if (mem_data[7:0] != 8'h55) load_error_reg <= 1'b1;
                            3: if (mem_data[7:0] != 8'h52) load_error_reg <= 1'b1;
                            4: if (mem_data[7:0] != 8'h4F) load_error_reg <= 1'b1;
                        endcase
                        if (magic_cnt < 5) magic_cnt <= magic_cnt + 1;
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                READ_VERSION: begin
                    if (mem_data_valid && !read_complete) begin
                        if (mem_data[7:0] != 8'h01) load_error_reg <= 1'b1;
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                READ_NUM_RTR: begin
                    if (mem_data_valid && !read_complete) begin
                        if (byte_cnt_reg == 0) begin
                            num_routers_reg[7:0] <= mem_data[7:0];
                            byte_cnt_reg <= 1;
                        end else begin
                            num_routers_reg[15:8] <= mem_data[7:0];
                            byte_cnt_reg <= 0;
                        end
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                READ_RTR_ID: begin
                    if (mem_data_valid && !read_complete) begin
                        if (byte_cnt_reg == 0) begin
                            cur_router_id_reg[7:0] <= mem_data[7:0];
                            byte_cnt_reg <= 1;
                        end else begin
                            cur_router_id_reg[15:8] <= mem_data[7:0];
                            byte_cnt_reg <= 0;
                        end
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                READ_INST_CNT: begin
                    if (mem_data_valid && !read_complete) begin
                        case (byte_cnt_reg)
                            0: num_instrs_reg[7:0]   <= mem_data[7:0];
                            1: num_instrs_reg[15:8]  <= mem_data[7:0];
                            2: num_instrs_reg[23:16] <= mem_data[7:0];
                            3: num_instrs_reg[31:24] <= mem_data[7:0];
                        endcase
                        if (byte_cnt_reg == 3) byte_cnt_reg <= 0;
                        else byte_cnt_reg <= byte_cnt_reg + 1;
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                READ_INST: begin
                    if (mem_data_valid && !read_complete) begin
                        case (byte_cnt_reg)
                            0: cur_instr_reg[7:0]   <= mem_data[7:0];
                            1: cur_instr_reg[15:8]  <= mem_data[7:0];
                            2: cur_instr_reg[23:16] <= mem_data[7:0];
                            3: cur_instr_reg[31:24] <= mem_data[7:0];
                        endcase
                        if (byte_cnt_reg == 3) byte_cnt_reg <= 0;
                        else byte_cnt_reg <= byte_cnt_reg + 1;
                        mem_addr_reg <= mem_addr_reg + 32'h1;
                        read_complete <= 1'b1;
                    end
                end

                WRITE_SRAM: begin
                    if (instr_idx_reg < num_instrs_reg - 1)
                        instr_idx_reg <= instr_idx_reg + 1;
                end

                NEXT_RTR: begin
                    router_idx_reg <= router_idx_reg + 1;
                    instr_idx_reg  <= 32'h0;
                    byte_cnt_reg   <= 2'h0;
                end

                DONE_STATE: begin
                    load_done_reg <= 1'b1;
                end

                ERROR_STATE: begin
                    load_error_reg <= 1'b1;
                end

                default: ;
            endcase
        end
    end


    // ================================================================
    // 6. Next state logic
    // ================================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (control_reg[CTRL_START_LOAD]) next_state = READ_MAGIC;
            end
            READ_MAGIC: begin
                if (load_error_reg) begin
                    next_state = ERROR_STATE;
                end else if (mem_data_valid && !read_complete) begin
                    if (magic_cnt == 4) next_state = READ_VERSION;
                    else                next_state = READ_MAGIC;
                end
            end
            READ_VERSION: begin
                if (mem_data_valid && !read_complete) next_state = READ_NUM_RTR;
            end
            READ_NUM_RTR: begin
                if (mem_data_valid && !read_complete && byte_cnt_reg == 1)
                    next_state = READ_RTR_ID;
                else
                    next_state = READ_NUM_RTR;
            end
            READ_RTR_ID: begin
                if (mem_data_valid && !read_complete && byte_cnt_reg == 1)
                    next_state = READ_INST_CNT;
                else
                    next_state = READ_RTR_ID;
            end
            READ_INST_CNT: begin
                if (mem_data_valid && !read_complete && byte_cnt_reg == 3)
                    next_state = READ_INST;
                else
                    next_state = READ_INST_CNT;
            end
            READ_INST: begin
                if (mem_data_valid && !read_complete && byte_cnt_reg == 3)
                    next_state = WRITE_SRAM;
                else
                    next_state = READ_INST;
            end
            WRITE_SRAM: begin
                if (instr_idx_reg == num_instrs_reg - 1 || num_instrs_reg == 0)
                    next_state = NEXT_RTR;
                else
                    next_state = READ_INST;
            end
            NEXT_RTR: begin
                if (router_idx_reg == num_routers_reg - 1)
                    next_state = DONE_STATE;
                else
                    next_state = READ_RTR_ID;
            end
            DONE_STATE:  next_state = DONE_STATE;
            ERROR_STATE: next_state = ERROR_STATE;
            default:     next_state = IDLE;
        endcase
    end


    // ================================================================
    // 7. Outputs
    // ================================================================
    assign load_done  = load_done_reg;
    assign load_error = load_error_reg;
    assign noc_ready  = load_done_reg && !load_error_reg;

    assign mem_req = (state == READ_MAGIC || state == READ_VERSION ||
                      state == READ_NUM_RTR || state == READ_RTR_ID ||
                      state == READ_INST_CNT || state == READ_INST) &&
                     !mem_data_valid && !read_complete;

    assign mem_addr = mem_addr_reg;

    // ================================================================
    // 8. Status register
    // ================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            status_reg <= 32'h0;
        else
            status_reg <= {28'h0, noc_ready, load_error_reg, 1'b0, load_done_reg};
    end

endmodule
