`timescale 1ns / 1ps

// ADI jesd204_rx adapter. The GPLv2 source and notices remain in ADI_JESD204.
module ADC_RXD(
    // Clock and reset
    input  wire                             afe_clk                                      ,
    input  wire                             afe_rst_n                                    ,
    input  wire                             jesd_clk                                     ,
    input  wire                             jesd_rst_n                                   ,

    // Enable and control
    input  wire                             chn_en_adc                                   ,
    input  wire                             sysref                                       ,

    // JESD PHY input
    input  wire [63:0]                      phy_rx_data                                  ,
    input  wire [7:0]                       phy_rx_charisk                               ,
    input  wire [7:0]                       phy_rx_disperr                               ,
    input  wire [7:0]                       phy_rx_notintable                            ,
    input  wire                             phy_rx_reset_done                            ,
    input  wire                             phy_pll_lock                                 ,

    // Clock-domain enables and PHY control
    output wire                             chn_en_afe                                   ,
    output wire                             chn_en_jesd                                  ,
    output wire                             phy_rx_encommalign                           ,
    output wire                             phy_sync_n                                   ,

    // AFE receive tuple
    output wire [255:0]                     rxd_data                                     ,
    output wire [15:0]                      rxd_somf                                     ,
    output wire                             link_ready_afe                               ,

    // Link status and events
    output wire                             link_ready                                   ,
    output wire [1:0]                       lane_ready                                   ,
    output wire [1:0]                       comma_detected                               ,
    output wire                             link_error_evt                               ,
    output wire                             sysref_error_evt                             ,
    output wire                             sysref_seen_evt                              ,
    output wire [1:0]                       disparity_evt                                ,
    output wire [1:0]                       notintable_evt
);

wire                                        jesd_core_reset                              ;
wire                                        device_core_reset                            ;
wire                                        link_ready_sync                              ;
wire                                        adi_rx_valid                                 ;
wire                                        adi_sync_n                                   ;
wire                                        adi_encommalign                              ;
wire     [1:0]                              adi_lane_ifs_ready                           ;
wire     [3:0]                              adi_lane_cgs_state                           ;
wire     [1:0]                              adi_status_state                             ;
wire                                        adi_frame_error                              ;
wire                                        adi_unexpected_lane_error                    ;
wire                                        adi_sysref_error                             ;
wire                                        adi_sysref_seen                              ;
wire     [1:0]                              phy_disparity_level                          ;
wire     [1:0]                              phy_notintable_level                         ;
wire                                        link_error_level                             ;
reg      [1:0]                              phy_disparity_r                              ;
reg      [1:0]                              phy_notintable_r                             ;
reg                                         link_error_r                                 ;

// Enable synchronization.
level_sync en_to_afe(.clk(afe_clk), .rst_n(afe_rst_n), .in(chn_en_adc), .out(chn_en_afe));
level_sync en_to_jesd(.clk(jesd_clk), .rst_n(jesd_rst_n), .in(chn_en_adc), .out(chn_en_jesd));

// ADI JESD204 RX.
assign jesd_core_reset   = ~jesd_rst_n | ~chn_en_jesd | ~phy_rx_reset_done | ~phy_pll_lock;
assign device_core_reset = ~afe_rst_n | ~chn_en_afe;

jesd204_rx #(
    .NUM_LANES                          (2                                             ),
    .NUM_LINKS                          (1                                             ),
    .LINK_MODE                          (1                                             ),
    .DATA_PATH_WIDTH                    (4                                             ),
    .TPL_DATA_PATH_WIDTH                (16                                            ),
    .ASYNC_CLK                          (1                                             ),
    .ENABLE_FRAME_ALIGN_CHECK           (1                                             ),
    .ENABLE_FRAME_ALIGN_ERR_RESET       (1                                             ),
    .ENABLE_CHAR_REPLACE                (1                                             )
) adi_jesd204_rx(
    .clk                                (jesd_clk                                      ),
    .reset                              (jesd_core_reset                               ),
    .device_clk                         (afe_clk                                       ),
    .device_reset                       (device_core_reset                             ),
    .phy_data                           (phy_rx_data                                   ),
    .phy_header                         (4'd0                                          ),
    .phy_charisk                        (phy_rx_charisk                                ),
    .phy_notintable                     (phy_rx_notintable                             ),
    .phy_disperr                        (phy_rx_disperr                                ),
    .phy_block_sync                     (2'b00                                         ),
    .sysref                             (sysref                                        ),
    .lmfc_edge                          (                                              ),
    .lmfc_clk                           (                                              ),
    .device_event_sysref_alignment_error(adi_sysref_error                              ),
    .device_event_sysref_edge           (adi_sysref_seen                               ),
    .event_frame_alignment_error        (adi_frame_error                               ),
    .event_unexpected_lane_state_error  (adi_unexpected_lane_error                     ),
    .sync                               (adi_sync_n                                    ),
    .phy_en_char_align                  (adi_encommalign                               ),
    .rx_data                            (rxd_data                                      ),
    .rx_valid                           (adi_rx_valid                                  ),
    .rx_eof                             (                                              ),
    .rx_sof                             (                                              ),
    .rx_eomf                            (                                              ),
    .rx_somf                            (rxd_somf                                      ),
    .cfg_lanes_disable                  (2'b00                                         ),
    .cfg_links_disable                  (1'b0                                          ),
    .cfg_octets_per_multiframe          (10'd255                                       ),
    .cfg_octets_per_frame               (8'd15                                         ),
    .cfg_disable_scrambler              (1'b1                                          ),
    .cfg_disable_char_replacement       (1'b0                                          ),
    .cfg_frame_align_err_threshold      (8'd1                                          ),
    .device_cfg_octets_per_multiframe   (10'd255                                       ),
    .device_cfg_octets_per_frame        (8'd15                                         ),
    .device_cfg_beats_per_multiframe    (8'd15                                         ),
    .device_cfg_lmfc_offset             (8'd0                                          ),
    .device_cfg_sysref_oneshot          (1'b1                                          ),
    .device_cfg_sysref_disable          (1'b0                                          ),
    .device_cfg_buffer_early_release    (1'b0                                          ),
    .device_cfg_buffer_delay            (8'd0                                          ),
    .ctrl_err_statistics_reset          (1'b0                                          ),
    .ctrl_err_statistics_mask           (7'd0                                          ),
    .status_err_statistics_cnt          (                                              ),
    .ilas_config_valid                  (                                              ),
    .ilas_config_addr                   (                                              ),
    .ilas_config_data                   (                                              ),
    .status_ctrl_state                  (adi_status_state                              ),
    .status_lane_cgs_state              (adi_lane_cgs_state                            ),
    .status_lane_ifs_ready              (adi_lane_ifs_ready                            ),
    .status_lane_latency                (                                              ),
    .status_lane_emb_state              (                                              ),
    .status_lane_frame_align_err_cnt    (                                              ),
    .status_synth_params0               (                                              ),
    .status_synth_params1               (                                              ),
    .status_synth_params2               (                                              )
);

// Link status and event extraction.
assign link_ready           = chn_en_jesd && phy_rx_reset_done && phy_pll_lock &&
                              (adi_status_state == 2'd3) && (&adi_lane_ifs_ready);
assign lane_ready           = adi_lane_ifs_ready;
assign comma_detected       = {adi_lane_cgs_state[2],adi_lane_cgs_state[0]};
assign phy_disparity_level  = {|phy_rx_disperr[7:4],|phy_rx_disperr[3:0]};
assign phy_notintable_level = {|phy_rx_notintable[7:4],|phy_rx_notintable[3:0]};
assign link_error_level     = adi_frame_error || adi_unexpected_lane_error ||
                              (|phy_disparity_level) || (|phy_notintable_level);
assign link_error_evt       = chn_en_jesd && link_error_level && !link_error_r;
assign sysref_error_evt     = adi_sysref_error;
assign sysref_seen_evt      = adi_sysref_seen;
assign disparity_evt        = {2{chn_en_jesd}} & phy_disparity_level & ~phy_disparity_r;
assign notintable_evt       = {2{chn_en_jesd}} & phy_notintable_level & ~phy_notintable_r;
assign phy_rx_encommalign   = adi_encommalign;
assign phy_sync_n           = adi_sync_n;

level_sync link_ready_to_afe(.clk(afe_clk), .rst_n(afe_rst_n), .in(link_ready), .out(link_ready_sync));

assign link_ready_afe = link_ready_sync & adi_rx_valid;

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if (!jesd_rst_n) begin
        phy_disparity_r  <= 2'd0;
        phy_notintable_r <= 2'd0;
        link_error_r     <= 1'b0;
    end else if (!chn_en_jesd) begin
        phy_disparity_r  <= 2'd0;
        phy_notintable_r <= 2'd0;
        link_error_r     <= 1'b0;
    end else begin
        phy_disparity_r  <= phy_disparity_level;
        phy_notintable_r <= phy_notintable_level;
        link_error_r     <= link_error_level;
    end
end

endmodule
