`timescale 1ns/1ps

module tb_adc_rxd_vcs;

logic         jesd_clk;
logic         afe_clk;
logic         jesd_rst_n;
logic         adc_rst_n;
logic         afe_rst_n;
logic         sysref;
logic         chn_en_jesd;
logic         chn_en_afe;
logic         link_ready_afe_r1;
logic         link_ready_afe;
logic [1:0]   smp_prec;
logic [1:0]   smp_mode;
logic         frame_fmt;
logic [7:0]   dec_m;
logic [1:0]   dec_del_mode;
logic         fifo_full;
logic [9:0]   fifo_wlevel;

logic [63:0]  phy_rx_data;
logic [7:0]   phy_rx_charisk;
logic [7:0]   phy_rx_disperr;
logic [7:0]   phy_rx_notintable;
logic         phy_rx_reset_done;
logic         phy_pll_lock;
logic [1:0]   phy_byte_aligned;
logic         phy_rx_encommalign;
logic         phy_sync_n;
logic [2:0]   model_phase;

logic [511:0] fifo_wr_data;
logic         fifo_wr_valid;
logic [1:0]   jesd_state;
logic         link_ready;
logic [1:0]   lane_ready;
logic [1:0]   comma_detected;
logic         link_error_evt;
logic         sysref_error_evt;
logic         sysref_seen_evt;
logic [1:0]   disparity_evt;
logic [1:0]   notintable_evt;
logic         data_drop_evt;

logic [511:0] expected_data;
string        pattern_i_path;
string        pattern_q_path;
string        fsdb_path;
integer       sample_index;
integer       wait_count;
logic         disparity_seen;

always #3.125 jesd_clk = ~jesd_clk; // 160 MHz
always #12.5  afe_clk  = ~afe_clk;  // 40 MHz

always_ff @(posedge afe_clk or negedge adc_rst_n) begin
    if (!adc_rst_n) begin
        link_ready_afe_r1 <= 1'b0;
        link_ready_afe    <= 1'b0;
    end else begin
        link_ready_afe_r1 <= link_ready;
        link_ready_afe    <= link_ready_afe_r1;
    end
end

AC9810_MASTER ac9810_gth_model(
    .jesd_clk          (jesd_clk),
    .jesd_rst_n        (jesd_rst_n),
    .model_enable      (chn_en_jesd),
    .sysref            (sysref),
    .sync_n            (phy_sync_n),
    .rx_encommalign    (phy_rx_encommalign),
    .rx_data           (phy_rx_data),
    .rx_charisk        (phy_rx_charisk),
    .rx_disperr        (phy_rx_disperr),
    .rx_notintable     (phy_rx_notintable),
    .rx_reset_done     (phy_rx_reset_done),
    .pll_lock          (phy_pll_lock),
    .byte_aligned      (phy_byte_aligned),
    .model_phase       (model_phase)
);

ADC_RXD dut(
    .jesd_clk             (jesd_clk),
    .jesd_rst_n           (jesd_rst_n),
    .afe_clk              (afe_clk),
    .adc_rst_n            (adc_rst_n),
    .afe_rst_n            (afe_rst_n),
    .sysref               (sysref),
    .chn_en_jesd          (chn_en_jesd),
    .chn_en_afe           (chn_en_afe),
    .link_ready_afe       (link_ready_afe),
    .smp_prec             (smp_prec),
    .smp_mode             (smp_mode),
    .frame_fmt            (frame_fmt),
    .dec_m                (dec_m),
    .dec_del_mode         (dec_del_mode),
    .phy_rx_data          (phy_rx_data),
    .phy_rx_charisk       (phy_rx_charisk),
    .phy_rx_disperr       (phy_rx_disperr),
    .phy_rx_notintable    (phy_rx_notintable),
    .phy_rx_reset_done    (phy_rx_reset_done),
    .phy_pll_lock         (phy_pll_lock),
    .fifo_full            (fifo_full),
    .fifo_wlevel          (fifo_wlevel),
    .phy_rx_encommalign   (phy_rx_encommalign),
    .phy_sync_n           (phy_sync_n),
    .fifo_wr_data         (fifo_wr_data),
    .fifo_wr_valid        (fifo_wr_valid),
    .jesd_state           (jesd_state),
    .link_ready           (link_ready),
    .lane_ready           (lane_ready),
    .comma_detected       (comma_detected),
    .link_error_evt       (link_error_evt),
    .sysref_error_evt     (sysref_error_evt),
    .sysref_seen_evt      (sysref_seen_evt),
    .disparity_evt        (disparity_evt),
    .notintable_evt       (notintable_evt),
    .data_drop_evt        (data_drop_evt)
);

initial begin
    jesd_clk        = 1'b0;
    afe_clk         = 1'b0;
    jesd_rst_n      = 1'b0;
    adc_rst_n       = 1'b0;
    afe_rst_n       = 1'b0;
    sysref          = 1'b0;
    chn_en_jesd     = 1'b0;
    chn_en_afe      = 1'b0;
    smp_prec        = 2'd0; // 10-bit, right aligned
    smp_mode        = 2'd0; // pure ADC
    frame_fmt       = 1'b0;
    dec_m           = 8'd0;
    dec_del_mode    = 2'd0;
    fifo_full       = 1'b0;
    fifo_wlevel     = 10'd0;
    expected_data   = 512'd0;
    disparity_seen  = 1'b0;

    for (sample_index = 0; sample_index < 32; sample_index = sample_index + 1)
        expected_data[sample_index * 16 +: 16] = sample_index + 1;

    if (!$value$plusargs("PATTERN_I=%s", pattern_i_path))
        pattern_i_path = "vcs/patterns/afe0_i.hex";
    if (!$value$plusargs("PATTERN_Q=%s", pattern_q_path))
        pattern_q_path = "vcs/patterns/afe0_q.hex";
    if (!$value$plusargs("FSDB_FILE=%s", fsdb_path))
        fsdb_path = "results/adc_rxd_vcs.fsdb";

    ac9810_gth_model.load_i_pattern(pattern_i_path);
    ac9810_gth_model.load_q_pattern(pattern_q_path);
    ac9810_gth_model.configure_stream(0, 0, 0);

`ifdef FSDB
    $fsdbDumpfile(fsdb_path);
    $fsdbDumpvars(0, tb_adc_rxd_vcs, "+all");
`else
    $vcdplusfile("adc_rxd_vcs.vpd");
    $vcdpluson(0, tb_adc_rxd_vcs);
`endif

    #100;
    jesd_rst_n  = 1'b1;
    adc_rst_n   = 1'b1;
    afe_rst_n   = 1'b1;
    chn_en_jesd = 1'b1;
    chn_en_afe  = 1'b1;

    wait (phy_rx_reset_done && phy_pll_lock && (phy_byte_aligned == 2'b11));
    repeat (80) @(posedge jesd_clk);
    @(negedge afe_clk);
    sysref = 1'b1;
    repeat (3) @(posedge afe_clk);
    @(negedge afe_clk);
    sysref = 1'b0;

    wait_count = 0;
    while (!link_ready && wait_count < 5000) begin
        @(posedge jesd_clk);
        wait_count = wait_count + 1;
    end
    if (!link_ready)
        $fatal(1, "VCS_SMOKE_FAIL: JESD link did not reach DATA, state=%0d phase=%0d", jesd_state, model_phase);
    $display("VCS_PATTERN_MARKER: link_ready after %0d JESD clocks", wait_count);

    wait_count = 0;
    while (!fifo_wr_valid && wait_count < 5000) begin
        @(posedge afe_clk);
        #1;
        wait_count = wait_count + 1;
    end
    if (!fifo_wr_valid)
        $fatal(1, "VCS_SMOKE_FAIL: no unpacked AC9810 beat");
    if (fifo_wr_data !== expected_data)
        $fatal(1, "VCS_SMOKE_FAIL: AC9810 channel mapping mismatch\nexpected=%h\nactual  =%h", expected_data, fifo_wr_data);
    $display("VCS_PATTERN_MARKER: pure ADC pattern mapped to channels 0..31");

    @(negedge jesd_clk);
    ac9810_gth_model.inject_disparity(8'h01);
    repeat (20) begin
        @(posedge jesd_clk);
        #1;
        if (disparity_evt != 2'b00)
            disparity_seen = 1'b1;
    end
    if (!disparity_seen)
        $fatal(1, "VCS_SMOKE_FAIL: disparity injection was not observed");

    $display("VCS_SMOKE_PASS: CGS/ILAS/DATA, AC9810 mapping and GTH error injection passed");
    #100;
    $finish;
end

initial begin
    #500000;
    $fatal(1, "VCS_SMOKE_FAIL: global timeout");
end

endmodule
