`timescale 1ns/1ps

module tb_poisson_delay;
    import emulator_mutrig_pkg::*;

    localparam real CLK_PERIOD_NS = 8.0;

    typedef struct {
        longint unsigned enq_cycle;
        bit              measure;
    } enq_item_t;

    typedef struct {
        longint unsigned enq_cycle;
        longint unsigned deq_cycle;
        bit              measure;
    } pop_item_t;

    string out_csv_path;
    string out_summary_path;
    int    out_csv_fd;
    int    out_summary_fd;

    int hit_rate_cfg;
    int warmup_cycles;
    int measure_cycles;
    int drain_timeout_cycles;

    logic clk;
    logic rst;

    logic [8:0]  aso_tx8b1k_data;
    logic        aso_tx8b1k_valid;
    logic [3:0]  aso_tx8b1k_channel;
    logic [2:0]  aso_tx8b1k_error;

    logic [8:0]  asi_ctrl_data;
    logic        asi_ctrl_valid;
    logic        asi_ctrl_ready;
    logic        coe_inject_pulse;

    logic [3:0]  avs_csr_address;
    logic        avs_csr_read;
    logic        avs_csr_write;
    logic [31:0] avs_csr_writedata;
    logic [31:0] avs_csr_readdata;
    logic        avs_csr_waitrequest;

    logic        parser_rst;
    logic [8:0]  parser_rx_data;
    logic        parser_rx_valid;
    logic [2:0]  parser_rx_error;
    logic [3:0]  parser_rx_channel;
    logic [8:0]  parser_ctrl_data;
    logic        parser_ctrl_valid;
    logic        parser_ctrl_ready;
    logic [1:0]  parser_csr_address;
    logic        parser_csr_read;
    logic        parser_csr_write;
    logic [31:0] parser_csr_writedata;
    logic [31:0] parser_csr_readdata;
    logic        parser_csr_waitrequest;
    logic [3:0]  parser_hit_channel;
    logic        parser_hit_sop;
    logic        parser_hit_eop;
    logic [2:0]  parser_hit_error;
    logic [44:0] parser_hit_data;
    logic        parser_hit_valid;
    logic [41:0] parser_headerinfo_data;
    logic        parser_headerinfo_valid;
    logic [3:0]  parser_headerinfo_channel;

    localparam logic [8:0] CTRL_IDLE        = 9'b000000001;
    localparam logic [8:0] CTRL_RUN_PREPARE = 9'b000000010;
    localparam logic [8:0] CTRL_SYNC        = 9'b000000100;
    localparam logic [8:0] CTRL_RUNNING     = 9'b000001000;

    enq_item_t accept_q[$];
    pop_item_t pop_q[$];

    longint unsigned cycle_count;
    longint unsigned measure_start_cycle;
    longint unsigned measure_end_cycle;
    longint unsigned total_accepted_hits;
    longint unsigned measured_accepted_hits;
    longint unsigned measured_dequeued_hits;
    longint unsigned measured_parser_hits;
    longint unsigned parser_header_count;
    longint unsigned total_parser_hits;
    longint unsigned occupancy_sum;
    longint unsigned occupancy_samples;
    longint unsigned max_occupancy;
    longint unsigned full_cycles;
    int              underflow_errors;
    bit              measure_window_active;

    function automatic bit measure_cycle(input longint unsigned cycle_v);
        return measure_window_active &&
               (cycle_v >= measure_start_cycle) &&
               (cycle_v <= measure_end_cycle);
    endfunction

    task automatic csr_write(input logic [3:0] addr, input logic [31:0] data);
        @(posedge clk);
        avs_csr_address   <= addr;
        avs_csr_writedata <= data;
        avs_csr_write     <= 1'b1;
        avs_csr_read      <= 1'b0;
        @(posedge clk);
        while (avs_csr_waitrequest) @(posedge clk);
        avs_csr_write <= 1'b0;
    endtask

    task automatic send_run_state(input logic [8:0] state);
        @(posedge clk);
        asi_ctrl_data  <= state;
        asi_ctrl_valid <= 1'b1;
        parser_ctrl_data  <= state;
        parser_ctrl_valid <= 1'b1;
        do begin
            @(posedge clk);
        end while (asi_ctrl_ready !== 1'b1);
        asi_ctrl_valid    <= 1'b0;
        asi_ctrl_data     <= CTRL_IDLE;
        parser_ctrl_valid <= 1'b0;
        parser_ctrl_data  <= CTRL_IDLE;
    endtask

    task automatic run_sequence_start;
        send_run_state(CTRL_RUN_PREPARE);
        repeat (5) @(posedge clk);
        send_run_state(CTRL_SYNC);
        repeat (5) @(posedge clk);
        send_run_state(CTRL_RUNNING);
    endtask

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #(CLK_PERIOD_NS * 10.0);
        rst = 1'b0;
    end

    emulator_mutrig #(
        .FIFO_DEPTH     (RAW_FIFO_DEPTH),
        .CSR_ADDR_WIDTH (4)
    ) dut (
        .i_clk               (clk),
        .i_rst               (rst),
        .aso_tx8b1k_data     (aso_tx8b1k_data),
        .aso_tx8b1k_valid    (aso_tx8b1k_valid),
        .aso_tx8b1k_channel  (aso_tx8b1k_channel),
        .aso_tx8b1k_error    (aso_tx8b1k_error),
        .asi_ctrl_data       (asi_ctrl_data),
        .asi_ctrl_valid      (asi_ctrl_valid),
        .asi_ctrl_ready      (asi_ctrl_ready),
        .coe_inject_pulse    (coe_inject_pulse),
        .avs_csr_address     (avs_csr_address),
        .avs_csr_read        (avs_csr_read),
        .avs_csr_write       (avs_csr_write),
        .avs_csr_writedata   (avs_csr_writedata),
        .avs_csr_readdata    (avs_csr_readdata),
        .avs_csr_waitrequest (avs_csr_waitrequest)
    );

    frame_rcv_ip #(
        .CHANNEL_WIDTH (4),
        .CSR_ADDR_WIDTH(2),
        .MODE_HALT     (0),
        .DEBUG_LV      (0)
    ) parser (
        .asi_rx8b1k_data             (parser_rx_data),
        .asi_rx8b1k_valid            (parser_rx_valid),
        .asi_rx8b1k_error            (parser_rx_error),
        .asi_rx8b1k_channel          (parser_rx_channel),
        .aso_hit_type0_channel       (parser_hit_channel),
        .aso_hit_type0_startofpacket (parser_hit_sop),
        .aso_hit_type0_endofpacket   (parser_hit_eop),
        .aso_hit_type0_endofrun      (/*unused*/),
        .aso_hit_type0_error         (parser_hit_error),
        .aso_hit_type0_data          (parser_hit_data),
        .aso_hit_type0_valid         (parser_hit_valid),
        .aso_headerinfo_data         (parser_headerinfo_data),
        .aso_headerinfo_valid        (parser_headerinfo_valid),
        .aso_headerinfo_channel      (parser_headerinfo_channel),
        .avs_csr_readdata            (parser_csr_readdata),
        .avs_csr_read                (parser_csr_read),
        .avs_csr_address             (parser_csr_address),
        .avs_csr_waitrequest         (parser_csr_waitrequest),
        .avs_csr_write               (parser_csr_write),
        .avs_csr_writedata           (parser_csr_writedata),
        .asi_ctrl_data               (parser_ctrl_data),
        .asi_ctrl_valid              (parser_ctrl_valid),
        .asi_ctrl_ready              (parser_ctrl_ready),
        .i_rst                       (parser_rst),
        .i_clk                       (clk)
    );

    assign parser_rx_data        = aso_tx8b1k_data;
    assign parser_rx_valid       = aso_tx8b1k_valid;
    assign parser_rx_error       = aso_tx8b1k_error;
    assign parser_rx_channel     = aso_tx8b1k_channel;
    assign parser_rst            = rst;
    assign parser_csr_address    = '0;
    assign parser_csr_read       = 1'b0;
    assign parser_csr_write      = 1'b0;
    assign parser_csr_writedata  = '0;

    always @(posedge clk) begin : latency_monitor
        enq_item_t acc_item;
        pop_item_t pop_item;
        longint unsigned sample_cycle;
        int queue_delay_cycles;
        int parser_delay_cycles;
        int serializer_delay_cycles;

        if (rst) begin
            cycle_count           = 0;
            total_accepted_hits   = 0;
            measured_accepted_hits = 0;
            measured_dequeued_hits = 0;
            measured_parser_hits  = 0;
            parser_header_count   = 0;
            total_parser_hits     = 0;
            occupancy_sum         = 0;
            occupancy_samples     = 0;
            max_occupancy         = 0;
            full_cycles           = 0;
            underflow_errors      = 0;
            measure_window_active = 1'b0;
            accept_q.delete();
            pop_q.delete();
        end else begin
            cycle_count = cycle_count + 1;
            sample_cycle = cycle_count;

            if (measure_cycle(sample_cycle)) begin
                occupancy_sum     = occupancy_sum + dut.u_hit_gen.fifo_count;
                occupancy_samples = occupancy_samples + 1;
                if (dut.u_hit_gen.fifo_count > max_occupancy)
                    max_occupancy = dut.u_hit_gen.fifo_count;
                if (dut.u_hit_gen.fifo_full)
                    full_cycles = full_cycles + 1;
            end

            if (dut.u_hit_gen.hit_wr_en && !dut.u_hit_gen.fifo_full) begin
                acc_item.enq_cycle = sample_cycle;
                acc_item.measure   = measure_cycle(sample_cycle);
                accept_q.push_back(acc_item);
                total_accepted_hits = total_accepted_hits + 1;
                if (acc_item.measure)
                    measured_accepted_hits = measured_accepted_hits + 1;
            end

            if (dut.fifo_rd_en && !dut.u_hit_gen.fifo_empty) begin
                if (accept_q.size() == 0) begin
                    underflow_errors = underflow_errors + 1;
                end else begin
                    acc_item = accept_q.pop_front();
                    pop_item.enq_cycle = acc_item.enq_cycle;
                    pop_item.deq_cycle = sample_cycle;
                    pop_item.measure   = acc_item.measure;
                    pop_q.push_back(pop_item);
                    if (pop_item.measure)
                        measured_dequeued_hits = measured_dequeued_hits + 1;
                end
            end

            if (parser_headerinfo_valid)
                parser_header_count = parser_header_count + 1;

            if (parser_hit_valid) begin
                total_parser_hits = total_parser_hits + 1;
                if (pop_q.size() == 0) begin
                    underflow_errors = underflow_errors + 1;
                end else begin
                    pop_item = pop_q.pop_front();
                    if (pop_item.measure) begin
                        queue_delay_cycles      = pop_item.deq_cycle - pop_item.enq_cycle;
                        parser_delay_cycles     = sample_cycle - pop_item.enq_cycle;
                        serializer_delay_cycles = sample_cycle - pop_item.deq_cycle;
                        measured_parser_hits    = measured_parser_hits + 1;
                        $fdisplay(out_csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d",
                                  pop_item.enq_cycle,
                                  pop_item.deq_cycle,
                                  sample_cycle,
                                  queue_delay_cycles,
                                  parser_delay_cycles,
                                  serializer_delay_cycles);
                    end
                end
            end
        end
    end

    initial begin : runbench
        int drain_waited;
        int average_occupancy_milli;

        if (!$value$plusargs("HIT_RATE=%d", hit_rate_cfg))
            hit_rate_cfg = 0;
        if (!$value$plusargs("WARMUP_CYCLES=%d", warmup_cycles))
            warmup_cycles = 50000;
        if (!$value$plusargs("MEASURE_CYCLES=%d", measure_cycles))
            measure_cycles = 200000;
        if (!$value$plusargs("DRAIN_TIMEOUT_CYCLES=%d", drain_timeout_cycles))
            drain_timeout_cycles = 400000;
        if (!$value$plusargs("OUT_CSV=%s", out_csv_path))
            out_csv_path = "poisson_delay.csv";
        if (!$value$plusargs("OUT_SUMMARY=%s", out_summary_path))
            out_summary_path = "poisson_delay.summary";

        measure_start_cycle = 64'hFFFF_FFFF_FFFF_FFFF;
        measure_end_cycle   = 0;
        measure_window_active = 1'b0;

        asi_ctrl_data      = '0;
        asi_ctrl_valid     = 1'b0;
        coe_inject_pulse   = 1'b0;
        avs_csr_address    = '0;
        avs_csr_read       = 1'b0;
        avs_csr_write      = 1'b0;
        avs_csr_writedata  = '0;
        parser_ctrl_data   = '0;
        parser_ctrl_valid  = 1'b0;

        out_csv_fd = $fopen(out_csv_path, "w");
        if (out_csv_fd == 0)
            $fatal(1, "failed to open OUT_CSV=%s", out_csv_path);
        $fdisplay(out_csv_fd, "enqueue_cycle,dequeue_cycle,parser_cycle,queue_delay_cycles,parser_delay_cycles,serializer_delay_cycles");

        out_summary_fd = $fopen(out_summary_path, "w");
        if (out_summary_fd == 0)
            $fatal(1, "failed to open OUT_SUMMARY=%s", out_summary_path);

        wait (rst == 1'b0);
        repeat (5) @(posedge clk);

        csr_write(4'd3, 32'hDEAD_BEEF);
        csr_write(4'd2, 32'h0404_1001);
        csr_write(4'd4, 32'h0000_000C);
        csr_write(4'd1, {16'h0000, hit_rate_cfg[15:0]});
        csr_write(4'd0, 32'h0000_0009);

        run_sequence_start();
        repeat (warmup_cycles) @(posedge clk);

        measure_start_cycle = cycle_count + 1;
        measure_end_cycle   = measure_start_cycle + measure_cycles - 1;
        measure_window_active = 1'b1;
        repeat (measure_cycles) @(posedge clk);
        measure_window_active = 1'b0;

        csr_write(4'd1, 32'h0000_0000);

        drain_waited = 0;
        while (((accept_q.size() != 0) || (pop_q.size() != 0) || (dut.u_hit_gen.fifo_count != 0)) &&
               (drain_waited < drain_timeout_cycles)) begin
            @(posedge clk);
            drain_waited++;
        end

        average_occupancy_milli = (occupancy_samples == 0) ? 0 :
            ((occupancy_sum * 1000) / occupancy_samples);

        $fdisplay(out_summary_fd, "hit_rate_cfg=%0d", hit_rate_cfg);
        $fdisplay(out_summary_fd, "warmup_cycles=%0d", warmup_cycles);
        $fdisplay(out_summary_fd, "measure_cycles=%0d", measure_cycles);
        $fdisplay(out_summary_fd, "measure_start_cycle=%0d", measure_start_cycle);
        $fdisplay(out_summary_fd, "measure_end_cycle=%0d", measure_end_cycle);
        $fdisplay(out_summary_fd, "total_accepted_hits=%0d", total_accepted_hits);
        $fdisplay(out_summary_fd, "measured_accepted_hits=%0d", measured_accepted_hits);
        $fdisplay(out_summary_fd, "measured_dequeued_hits=%0d", measured_dequeued_hits);
        $fdisplay(out_summary_fd, "measured_parser_hits=%0d", measured_parser_hits);
        $fdisplay(out_summary_fd, "parser_header_count=%0d", parser_header_count);
        $fdisplay(out_summary_fd, "total_parser_hits=%0d", total_parser_hits);
        $fdisplay(out_summary_fd, "occupancy_samples=%0d", occupancy_samples);
        $fdisplay(out_summary_fd, "average_occupancy_milli=%0d", average_occupancy_milli);
        $fdisplay(out_summary_fd, "max_occupancy=%0d", max_occupancy);
        $fdisplay(out_summary_fd, "full_cycles=%0d", full_cycles);
        $fdisplay(out_summary_fd, "drain_waited_cycles=%0d", drain_waited);
        $fdisplay(out_summary_fd, "accept_queue_remaining=%0d", accept_q.size());
        $fdisplay(out_summary_fd, "pop_queue_remaining=%0d", pop_q.size());
        $fdisplay(out_summary_fd, "fifo_count_remaining=%0d", dut.u_hit_gen.fifo_count);
        $fdisplay(out_summary_fd, "underflow_errors=%0d", underflow_errors);

        $display("SUMMARY hit_rate_cfg=%0d measured_accepted_hits=%0d measured_parser_hits=%0d parser_header_count=%0d total_parser_hits=%0d max_occupancy=%0d full_cycles=%0d avg_occupancy=%.3f drain_waited=%0d remaining_fifo=%0d underflow_errors=%0d",
                 hit_rate_cfg, measured_accepted_hits, measured_parser_hits, parser_header_count, total_parser_hits,
                 max_occupancy, full_cycles, average_occupancy_milli / 1000.0, drain_waited, dut.u_hit_gen.fifo_count,
                 underflow_errors);

        if (underflow_errors != 0)
            $display("WARNING: latency monitor observed %0d off-window underflow events near saturation", underflow_errors);
        if (measured_accepted_hits != measured_parser_hits)
            $fatal(1, "measured hit mismatch accepted=%0d parser=%0d", measured_accepted_hits, measured_parser_hits);
        if (accept_q.size() != 0 || pop_q.size() != 0 || dut.u_hit_gen.fifo_count != 0)
            $fatal(1, "drain timeout accept_q=%0d pop_q=%0d fifo_count=%0d", accept_q.size(), pop_q.size(), dut.u_hit_gen.fifo_count);

        $fclose(out_csv_fd);
        $fclose(out_summary_fd);
        $finish;
    end
endmodule
