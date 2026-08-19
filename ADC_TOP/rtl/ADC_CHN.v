`timescale 1ns / 1ps

module ADC_CHN(
    input wire adc_clk, input wire adc_rst_n, input wire afe_clk, input wire afe_rst_n,
    input wire jesd_clk, input wire jesd_rst_n, input wire sysref, input wire [2:0] afe_id,
    input wire afe_en, input wire fifo_clr, input wire [31:0] adc_ctl, input wire [31:0] frame_cfg,
    input wire [63:0] phy_rx_data, input wire [7:0] phy_rx_charisk, input wire [7:0] phy_rx_disperr,
    input wire [7:0] phy_rx_notintable, input wire phy_rx_reset_done, input wire phy_pll_lock,
    input wire [1:0] phy_byte_aligned, output wire phy_rx_encommalign, output wire phy_sync_n,
    output wire [511:0] m_axis_tdata, output wire [63:0] m_axis_tkeep,
    output wire m_axis_tvalid, output wire m_axis_tlast, input wire m_axis_tready,
    output wire link_ready_adc, output wire fifo_empty_adc, output wire fifo_full_adc,
    output wire afe_idle_adc, output wire pll_lock_adc, output wire rx_reset_done_adc,
    output wire [1:0] lane_ready_adc, output wire [1:0] byte_aligned_adc,
    output wire [1:0] comma_detected_adc, output wire fifo_overflow_evt_afe,
    output wire data_drop_evt_adc, output wire link_error_evt_adc, output wire sysref_seen_evt_adc,
    output wire [1:0] disparity_evt_adc, output wire [1:0] notintable_evt_adc
);
wire chn_en_eff, chn_en_afe, chn_en_jesd;
wire [255:0] rxd_data;
wire [15:0] rxd_somf;
wire link_ready_afe, link_ready_jesd;
wire [511:0] fifo_wr_data, fifo_rd_data;
wire fifo_wr_valid, fifo_full_afe, fifo_rd_inc, fifo_rd_empty, fifo_rst_n;
wire [9:0] fifo_wr_level, fifo_rd_level;
wire [1:0] lane_ready_jesd, comma_detected_jesd, disparity_evt_jesd, notintable_evt_jesd;
wire link_error_evt_jesd, sysref_error_evt_afe, sysref_seen_evt_afe, data_drop_evt_afe;
wire [511:0] m_axis_tdata_int;
wire [63:0] m_axis_tkeep_int;
wire m_axis_tvalid_int, m_axis_tlast_int;

assign m_axis_tdata=m_axis_tdata_int;
assign m_axis_tkeep=m_axis_tkeep_int;
assign m_axis_tvalid=m_axis_tvalid_int;
assign m_axis_tlast=m_axis_tlast_int;
assign fifo_empty_adc=fifo_rd_empty;
assign fifo_rst_n=afe_rst_n & adc_rst_n & ~fifo_clr;

ADC_RXD adc_rxd(
    .afe_clk(afe_clk), .afe_rst_n(afe_rst_n), .jesd_clk(jesd_clk), .jesd_rst_n(jesd_rst_n),
    .sysref(sysref), .chn_en_adc(chn_en_eff), .phy_rx_data(phy_rx_data), .phy_rx_charisk(phy_rx_charisk),
    .phy_rx_disperr(phy_rx_disperr), .phy_rx_notintable(phy_rx_notintable),
    .phy_rx_reset_done(phy_rx_reset_done), .phy_pll_lock(phy_pll_lock), .chn_en_afe(chn_en_afe),
    .chn_en_jesd(chn_en_jesd), .phy_rx_encommalign(phy_rx_encommalign), .phy_sync_n(phy_sync_n),
    .rxd_data(rxd_data), .rxd_somf(rxd_somf), .link_ready(link_ready_jesd),
    .link_ready_afe(link_ready_afe), .lane_ready(lane_ready_jesd), .comma_detected(comma_detected_jesd),
    .link_error_evt(link_error_evt_jesd), .sysref_error_evt(sysref_error_evt_afe),
    .sysref_seen_evt(sysref_seen_evt_afe), .disparity_evt(disparity_evt_jesd),
    .notintable_evt(notintable_evt_jesd)
);
ADC_UPK adc_upk(
    .afe_clk(afe_clk), .afe_rst_n(afe_rst_n), .chn_en_afe(chn_en_afe), .rxd_data(rxd_data),
    .rxd_somf(rxd_somf), .link_ready_afe(link_ready_afe), .adc_ctl(adc_ctl), .frame_cfg(frame_cfg),
    .fifo_wlevel(fifo_wr_level), .fifo_wr_data(fifo_wr_data), .fifo_wr_valid(fifo_wr_valid),
    .data_drop_evt(data_drop_evt_afe)
);
async_fifo #(.AS(9), .DS(512), .RSTEN(0), .WC(0), .RC(0)) async_fifo_fwft(
    .wclk(afe_clk), .rclk(adc_clk), .wclr(1'b0), .rclr(1'b0), .rst_n(fifo_rst_n),
    .winc(fifo_wr_valid), .rinc(fifo_rd_inc), .wdata(fifo_wr_data), .rdata(fifo_rd_data),
    .full(fifo_full_afe), .empty(fifo_rd_empty), .overflow(fifo_overflow_evt_afe), .underflow(),
    .wlevel(fifo_wr_level), .rlevel(fifo_rd_level)
);
ADC_PKT adc_pkt(
    .adc_clk(adc_clk), .adc_rst_n(adc_rst_n), .afe_id(afe_id), .afe_en(afe_en),
    .smp_prec(adc_ctl[31:30]), .smp_mode(adc_ctl[27:26]), .dec_m(frame_cfg[7:0]),
    .link_ready(link_ready_adc), .fifo_data(fifo_rd_data), .fifo_empty(fifo_rd_empty),
    .fifo_level(fifo_rd_level), .m_axis_tready(m_axis_tready), .chn_en_eff(chn_en_eff),
    .fifo_rd_inc(fifo_rd_inc), .m_axis_tdata(m_axis_tdata_int), .m_axis_tkeep(m_axis_tkeep_int),
    .m_axis_tvalid(m_axis_tvalid_int), .m_axis_tlast(m_axis_tlast_int), .afe_idle(afe_idle_adc)
);
CHN_SYNC chn_sync(
    .adc_clk(adc_clk), .adc_rst_n(adc_rst_n), .afe_clk(afe_clk), .afe_rst_n(afe_rst_n),
    .jesd_clk(jesd_clk), .jesd_rst_n(jesd_rst_n), .link_ready(link_ready_jesd),
    .lane_ready(lane_ready_jesd), .byte_aligned(phy_byte_aligned), .comma_detected(comma_detected_jesd),
    .pll_lock(phy_pll_lock), .rx_reset_done(phy_rx_reset_done), .link_error_evt(link_error_evt_jesd),
    .sysref_error_evt(sysref_error_evt_afe), .sysref_seen_evt(sysref_seen_evt_afe),
    .disparity_evt(disparity_evt_jesd), .notintable_evt(notintable_evt_jesd), .fifo_full_afe(fifo_full_afe),
    .data_drop_evt_afe(data_drop_evt_afe), .link_ready_adc(link_ready_adc), .lane_ready_adc(lane_ready_adc),
    .byte_aligned_adc(byte_aligned_adc), .comma_detected_adc(comma_detected_adc), .pll_lock_adc(pll_lock_adc),
    .rx_reset_done_adc(rx_reset_done_adc), .link_error_evt_adc(link_error_evt_adc),
    .sysref_seen_evt_adc(sysref_seen_evt_adc), .disparity_evt_adc(disparity_evt_adc),
    .notintable_evt_adc(notintable_evt_adc), .fifo_full_adc(fifo_full_adc), .data_drop_evt_adc(data_drop_evt_adc)
);
endmodule
