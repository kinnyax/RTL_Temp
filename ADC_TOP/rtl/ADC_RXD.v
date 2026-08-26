`timescale 1ns / 1ps

// Adapter only; the licensed ADI source remains an immutable black box.
module ADC_RXD(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,
    input                                   jesd_clk                                       ,
    input                                   jesd_rst_n                                     ,

    input                                   chn_en                                         ,
    input                                   sysref                                         ,
    input               [63:0]              phy_rx_data                                    ,
    input               [ 7:0]              phy_rx_charisk                                 ,
    input               [ 7:0]              phy_rx_disperr                                 ,
    input               [ 7:0]              phy_rx_notintable                              ,
    input                                   phy_rx_reset_done                              ,
    input                                   phy_pll_lock                                   ,

    output    wire                          phy_rx_encommalign                             ,
    output    wire                          phy_sync_n                                     ,
    output    wire      [255:0]             adi_rxd_data                                   ,
    output    wire      [15:0]              adi_rxd_somf                                   ,
    output    wire                          adi_rxd_vld                                    ,
    output    wire                          adi_sysref_error                               ,
    output    wire                          adi_sysref_seen                                ,
    output    wire                          adi_link_ready                                 ,
    output    wire      [ 1:0]              adi_lane_ready                                 ,
    output    wire      [ 1:0]              adi_cgs_ready                                  ,
    output    wire      [ 1:0]              phy_disparity                                  ,
    output    wire      [ 1:0]              phy_notintable                                 ,
    output    wire                          link_error
);

parameter                                   UDLY                     = 1                   ;

wire                                        jesd_reset                                     ;
wire                                        device_reset                                   ;

wire                                        adi_en_align_i                                 ;
wire                                        adi_sync_n_i                                   ;
wire                    [255:0]             adi_rxd_data_i                                 ;
wire                    [15:0]              adi_rxd_somf_i                                 ;
wire                                        adi_rxd_valid_i                                ;
wire                                        adi_sysref_error_i                             ;
wire                                        adi_sysref_seen_i                              ;
wire                                        adi_frame_error_i                              ;
wire                                        adi_lane_error_i                               ;
wire                    [ 1:0]              adi_ctrl_state_i                               ;
/* verilator lint_off UNUSEDSIGNAL */
wire                    [ 3:0]              adi_cgs_state_i                                ;
wire                                        unused_lmfc_edge_i                             ;
wire                                        unused_lmfc_clk_i                              ;
wire                    [15:0]              unused_rx_eof_i                                ;
wire                    [15:0]              unused_rx_sof_i                                ;
wire                    [15:0]              unused_rx_eomf_i                               ;
wire                    [63:0]              unused_err_statistics_i                        ;
wire                    [ 1:0]              unused_ilas_valid_i                            ;
wire                    [ 3:0]              unused_ilas_addr_i                             ;
wire                    [63:0]              unused_ilas_data_i                             ;
wire                    [27:0]              unused_lane_latency_i                          ;
wire                    [ 5:0]              unused_lane_emb_state_i                        ;
wire                    [15:0]              unused_lane_align_err_i                        ;
wire                    [31:0]              unused_synth_params0_i                         ;
wire                    [31:0]              unused_synth_params1_i                         ;
wire                    [31:0]              unused_synth_params2_i                         ;
/* verilator lint_on UNUSEDSIGNAL */
wire                    [ 1:0]              adi_lane_ready_i                               ;

wire                    [ 1:0]              disparity_level                                ;
wire                    [ 1:0]              notintable_level                               ;
wire                                        link_error_level                               ;
wire                                        link_ready_level                               ;
wire                                        link_ready_afe                                 ;

reg                     [ 1:0]              disparity_level_r                              ;
reg                     [ 1:0]              notintable_level_r                             ;
reg                                         link_error_level_r                             ;

assign jesd_reset   = ~jesd_rst_n | ~phy_rx_reset_done | ~phy_pll_lock;
assign device_reset = ~afe_rst_n;

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
    .reset                              (jesd_reset                                    ),
    .device_clk                         (afe_clk                                       ),
    .device_reset                       (device_reset                                  ),
    .phy_data                           (phy_rx_data                                   ),
    .phy_header                         (4'd0                                          ),
    .phy_charisk                        (phy_rx_charisk                                ),
    .phy_notintable                     (phy_rx_notintable                             ),
    .phy_disperr                        (phy_rx_disperr                                ),
    .phy_block_sync                     (2'b00                                         ),
    .sysref                             (sysref                                        ),
    .lmfc_edge                          (unused_lmfc_edge_i                            ),
    .lmfc_clk                           (unused_lmfc_clk_i                             ),
    .device_event_sysref_alignment_error(adi_sysref_error_i                            ),
    .device_event_sysref_edge           (adi_sysref_seen_i                             ),
    .event_frame_alignment_error        (adi_frame_error_i                             ),
    .event_unexpected_lane_state_error  (adi_lane_error_i                              ),
    .sync                               (adi_sync_n_i                                  ),
    .phy_en_char_align                  (adi_en_align_i                                ),
    .rx_data                            (adi_rxd_data_i                                ),
    .rx_valid                           (adi_rxd_valid_i                               ),
    .rx_eof                             (unused_rx_eof_i                               ),
    .rx_sof                             (unused_rx_sof_i                               ),
    .rx_eomf                            (unused_rx_eomf_i                              ),
    .rx_somf                            (adi_rxd_somf_i                                ),
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
    .status_err_statistics_cnt          (unused_err_statistics_i                       ),
    .ilas_config_valid                  (unused_ilas_valid_i                           ),
    .ilas_config_addr                   (unused_ilas_addr_i                            ),
    .ilas_config_data                   (unused_ilas_data_i                            ),
    .status_ctrl_state                  (adi_ctrl_state_i                              ),
    .status_lane_cgs_state              (adi_cgs_state_i                               ),
    .status_lane_ifs_ready              (adi_lane_ready_i                              ),
    .status_lane_latency                (unused_lane_latency_i                         ),
    .status_lane_emb_state              (unused_lane_emb_state_i                       ),
    .status_lane_frame_align_err_cnt    (unused_lane_align_err_i                       ),
    .status_synth_params0               (unused_synth_params0_i                        ),
    .status_synth_params1               (unused_synth_params1_i                        ),
    .status_synth_params2               (unused_synth_params2_i                        )
);

assign link_ready_level = phy_rx_reset_done & phy_pll_lock &
                          (adi_ctrl_state_i == 2'd3) & (&adi_lane_ready_i);
assign disparity_level  = {|phy_rx_disperr[7:4], |phy_rx_disperr[3:0]};
assign notintable_level = {|phy_rx_notintable[7:4], |phy_rx_notintable[3:0]};
assign link_error_level = adi_frame_error_i | adi_lane_error_i |
                          (|disparity_level) | (|notintable_level);

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if(!jesd_rst_n) begin
        disparity_level_r  <= #UDLY 2'd0;
        notintable_level_r <= #UDLY 2'd0;
        link_error_level_r <= #UDLY 1'b0;
    end
    else if(!phy_rx_reset_done | !phy_pll_lock) begin
        disparity_level_r  <= #UDLY 2'd0;
        notintable_level_r <= #UDLY 2'd0;
        link_error_level_r <= #UDLY 1'b0;
    end
    else begin
        disparity_level_r  <= #UDLY disparity_level;
        notintable_level_r <= #UDLY notintable_level;
        link_error_level_r <= #UDLY link_error_level;
    end
end

level_sync link_ready_cdc(.clk(afe_clk), .rst_n(afe_rst_n), .in(link_ready_level), .out(link_ready_afe));

assign phy_rx_encommalign = ~jesd_reset ? adi_en_align_i : 1'b0;
assign phy_sync_n         = ~jesd_reset ? adi_sync_n_i   : 1'b0;
assign adi_rxd_data       = afe_rst_n  ? adi_rxd_data_i : 256'd0;
assign adi_rxd_somf       = afe_rst_n  ? adi_rxd_somf_i : 16'd0;
assign adi_rxd_vld        = afe_rst_n & chn_en & link_ready_afe & adi_rxd_valid_i;
assign adi_sysref_error   = afe_rst_n ? adi_sysref_error_i : 1'b0;
assign adi_sysref_seen    = afe_rst_n ? adi_sysref_seen_i  : 1'b0;
assign adi_link_ready     = ~jesd_reset ? link_ready_level : 1'b0;
assign adi_lane_ready     = ~jesd_reset ? adi_lane_ready_i : 2'd0;
assign adi_cgs_ready      = ~jesd_reset ? {adi_cgs_state_i[3], adi_cgs_state_i[1]} : 2'd0;
assign phy_disparity      = {2{~jesd_reset}} & disparity_level & ~disparity_level_r;
assign phy_notintable     = {2{~jesd_reset}} & notintable_level & ~notintable_level_r;
assign link_error         = ~jesd_reset & link_error_level & ~link_error_level_r;

endmodule
