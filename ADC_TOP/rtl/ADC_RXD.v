`timescale 1ns / 1ps

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

    output    wire      [127:0]             rxd_data                                       ,
    output    wire                          rxd_data_vld                                   ,
    output    wire                          rxd_ready                                      ,
    output    wire                          adi_sysref_error                               ,
    output    wire                          adi_sysref_seen                                ,
    output    wire                          adi_link_ready                                 ,
    output    wire      [ 1:0]              adi_lane_ready                                 ,
    output    wire      [ 1:0]              adi_cgs_ready                                  ,
    output    reg       [ 1:0]              phy_disparity                                  ,
    output    reg       [ 1:0]              phy_notintable                                 ,
    output    reg                           link_error
);

parameter                                   UDLY                     = 1                   ;

wire                                        jesd_core_reset                                ;
wire                                        afe_core_reset                                 ;
wire                    [ 0:0]              adi_sync                                       ;
wire                                        phy_en_char_align                              ;
wire                    [127:0]             adi_rx_data                                    ;
wire                                        adi_rx_valid                                   ;
wire                    [ 1:0]              status_ctrl_state                              ;
wire                    [ 3:0]              status_lane_cgs_state                          ;
wire                    [ 1:0]              status_lane_ifs_ready                          ;
wire                                        frame_align_error                              ;
wire                                        lane_state_error                               ;
wire                                        sysref_align_error                             ;
wire                                        sysref_edge                                    ;
wire                    [ 1:0]              disparity_level                                ;
wire                    [ 1:0]              notintable_level                               ;

reg                     [ 1:0]              disparity_d                                    ;
reg                     [ 1:0]              notintable_d                                   ;

//////////////////////////////////////////////////
//1. Functional And Diagnostic Mapping
//////////////////////////////////////////////////
assign jesd_core_reset   = ~jesd_rst_n | ~phy_rx_reset_done | ~phy_pll_lock;
assign afe_core_reset    = ~afe_rst_n;
assign adi_link_ready    = jesd_rst_n & (status_ctrl_state == 2'b11);
assign adi_lane_ready    = {2{jesd_rst_n}} & status_lane_ifs_ready;
assign adi_cgs_ready     = {2{jesd_rst_n}} &
                           {(status_lane_cgs_state[3:2] == 2'b11),
                            (status_lane_cgs_state[1:0] == 2'b11)};
assign disparity_level   = {|phy_rx_disperr[7:4],|phy_rx_disperr[3:0]};
assign notintable_level  = {|phy_rx_notintable[7:4],|phy_rx_notintable[3:0]};
assign rxd_data          = afe_rst_n ? adi_rx_data : 128'd0;
assign rxd_data_vld      = afe_rst_n & chn_en & adi_rx_valid;
assign adi_sysref_error  = afe_rst_n & sysref_align_error;
assign adi_sysref_seen   = afe_rst_n & sysref_edge;
assign phy_rx_encommalign = jesd_rst_n & phy_en_char_align;
assign phy_sync_n         = jesd_rst_n & adi_sync[0];

level_sync link_ready_level_sync(.clk(afe_clk),.rst_n(afe_rst_n),.in(adi_link_ready),.out(rxd_ready));

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if(~jesd_rst_n) begin
        disparity_d    <= #UDLY 2'd0;
        notintable_d   <= #UDLY 2'd0;
        phy_disparity  <= #UDLY 2'd0;
        phy_notintable <= #UDLY 2'd0;
        link_error     <= #UDLY 1'd0;
    end
    else begin
        disparity_d    <= #UDLY disparity_level;
        notintable_d   <= #UDLY notintable_level;
        phy_disparity  <= #UDLY disparity_level & ~disparity_d;
        phy_notintable <= #UDLY notintable_level & ~notintable_d;
        link_error     <= #UDLY frame_align_error | lane_state_error |
                         (|phy_disparity) | (|phy_notintable);
    end
end

//////////////////////////////////////////////////
//2. ADI JESD204 Receive Core
//////////////////////////////////////////////////
jesd204_rx #(
    .NUM_LANES                           (2                                            ),
    .NUM_LINKS                           (1                                            ),
    .LINK_MODE                           (1                                            ),
    .DATA_PATH_WIDTH                     (4                                            ),
    .ENABLE_FRAME_ALIGN_CHECK            (1                                            ),
    .ENABLE_FRAME_ALIGN_ERR_RESET        (1                                            ),
    .ENABLE_CHAR_REPLACE                 (1                                            ),
    .ASYNC_CLK                           (1                                            ),
    .TPL_DATA_PATH_WIDTH                 (8                                            )
) jesd204_rx_core(
    .clk                                 (jesd_clk                                     ),
    .reset                               (jesd_core_reset                              ),
    .device_clk                          (afe_clk                                      ),
    .device_reset                        (afe_core_reset                               ),
    .phy_data                            (phy_rx_data                                  ),
    .phy_header                          (4'd0                                         ),
    .phy_charisk                         (phy_rx_charisk                               ),
    .phy_notintable                      (phy_rx_notintable                            ),
    .phy_disperr                         (phy_rx_disperr                               ),
    .phy_block_sync                      (2'd0                                         ),
    .sysref                              (sysref                                       ),
    .lmfc_edge                           (                                             ),
    .lmfc_clk                            (                                             ),
    .device_event_sysref_alignment_error (sysref_align_error                           ),
    .device_event_sysref_edge            (sysref_edge                                  ),
    .event_frame_alignment_error         (frame_align_error                            ),
    .event_unexpected_lane_state_error   (lane_state_error                             ),
    .sync                                (adi_sync                                     ),
    .phy_en_char_align                   (phy_en_char_align                            ),
    .rx_data                             (adi_rx_data                                  ),
    .rx_valid                            (adi_rx_valid                                 ),
    .rx_eof                              (                                             ),
    .rx_sof                              (                                             ),
    .rx_eomf                             (                                             ),
    .rx_somf                             (                                             ),
    .cfg_lanes_disable                   (2'd0                                         ),
    .cfg_links_disable                   (1'd0                                         ),
    .cfg_octets_per_multiframe           (10'd256                                      ),
    .cfg_octets_per_frame                (8'd16                                        ),
    .cfg_disable_scrambler               (1'd1                                         ),
    .cfg_disable_char_replacement        (1'd0                                         ),
    .cfg_frame_align_err_threshold       (8'd1                                         ),
    .device_cfg_octets_per_multiframe    (10'd256                                      ),
    .device_cfg_octets_per_frame         (8'd16                                        ),
    .device_cfg_beats_per_multiframe     (8'd32                                        ),
    .device_cfg_lmfc_offset              (8'd0                                         ),
    .device_cfg_sysref_oneshot           (1'd0                                         ),
    .device_cfg_sysref_disable           (1'd0                                         ),
    .device_cfg_buffer_early_release     (1'd0                                         ),
    .device_cfg_buffer_delay             (8'd0                                         ),
    .ctrl_err_statistics_reset           (1'd0                                         ),
    .ctrl_err_statistics_mask            (7'd0                                         ),
    .status_err_statistics_cnt           (                                             ),
    .ilas_config_valid                   (                                             ),
    .ilas_config_addr                    (                                             ),
    .ilas_config_data                    (                                             ),
    .status_ctrl_state                   (status_ctrl_state                            ),
    .status_lane_cgs_state               (status_lane_cgs_state                        ),
    .status_lane_ifs_ready               (status_lane_ifs_ready                        ),
    .status_lane_latency                 (                                             ),
    .status_lane_emb_state               (                                             ),
    .status_lane_frame_align_err_cnt     (                                             ),
    .status_synth_params0                (                                             ),
    .status_synth_params1                (                                             ),
    .status_synth_params2                (                                             )
);

endmodule
