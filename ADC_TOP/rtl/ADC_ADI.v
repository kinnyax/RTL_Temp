`timescale 1ns / 1ps

module ADC_ADI(
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,
    input                                   jesd_clk                                       ,
    input                                   jesd_rst_n                                     ,

    input                                   sysref                                         ,
    input               [63:0]              phy_rx_data                                    ,
    input               [ 7:0]              phy_rx_charisk                                 ,
    input               [ 7:0]              phy_rx_disperr                                 ,
    input               [ 7:0]              phy_rx_notintable                              ,
    input                                   rx_reset_done                                  ,
    input                                   pll_lock                                       ,
    input               [ 1:0]              byte_aligned                                   ,
    output    wire                          phy_rx_encommalign                             ,
    output    wire                          phy_sync_n                                     ,

    output    wire      [127:0]             adi_data                                       ,
    output    wire                          adi_data_vld                                   ,
    output    wire                          adi_link_qual                                  ,
    output    wire                          adi_sysref_error                               ,
    output    wire                          adi_sysref_seen                                ,
    output    reg                           adi_link_ready                                 ,
    output    wire      [ 1:0]              adi_lane_ready                                 ,
    output    wire      [ 1:0]              adi_cgs_ready                                  ,
    output    wire                          phy_rx_reset_done                              ,
    output    wire                          phy_pll_lock                                   ,
    output    wire      [ 1:0]              phy_byte_aligned                               ,
    output    reg       [ 1:0]              phy_disparity                                  ,
    output    reg       [ 1:0]              phy_notintable                                 ,
    output    reg                           jesd_link_error
);

wire                                        core_active                                    ;
wire                                        jesd_core_reset                                ;
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
wire                                        jesd_link_error_set                            ;

reg                     [ 1:0]              disparity_r                                    ;
reg                     [ 1:0]              notintable_r                                   ;

//////////////////////////////////////////////////
//1. ADI JESD204 Receive Core
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
    .device_reset                        (~afe_rst_n                                   ),
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

//////////////////////////////////////////////////
//2. Functional Mapping
//////////////////////////////////////////////////
assign core_active       = jesd_rst_n & rx_reset_done & pll_lock;
assign jesd_core_reset   = ~core_active;
assign adi_lane_ready    = status_lane_ifs_ready;
assign adi_cgs_ready     = {(status_lane_cgs_state[3:2] == 2'b11),
                            (status_lane_cgs_state[1:0] == 2'b11)};
assign adi_data          = adi_rx_data;
assign adi_data_vld      = adi_rx_valid;
assign adi_sysref_error  = sysref_align_error;
assign adi_sysref_seen   = sysref_edge;
assign phy_rx_reset_done = rx_reset_done;
assign phy_pll_lock      = pll_lock;
assign phy_byte_aligned  = byte_aligned;
assign phy_rx_encommalign = core_active & phy_en_char_align;
assign phy_sync_n         = core_active & adi_sync[0];

always @(posedge jesd_clk or negedge core_active) begin
    if(~core_active)
        adi_link_ready <= 1'd0;
    else
        adi_link_ready <= adi_sync[0] & (status_ctrl_state == 2'b11);
end

level_sync link_qual_level_sync(.clk(afe_clk),.rst_n(afe_rst_n),.in(adi_link_ready),.out(adi_link_qual));

//////////////////////////////////////////////////
//3. Diagnostic Events
//////////////////////////////////////////////////
assign disparity_level     = {|phy_rx_disperr[7:4],|phy_rx_disperr[3:0]};
assign notintable_level    = {|phy_rx_notintable[7:4],|phy_rx_notintable[3:0]};
assign jesd_link_error_set = frame_align_error | lane_state_error |
                             (|phy_disparity) | (|phy_notintable);

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if(~jesd_rst_n) begin
        disparity_r  <= 2'd0;
        notintable_r <= 2'd0;
    end
    else begin
        disparity_r  <= disparity_level;
        notintable_r <= notintable_level;
    end
end

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if(~jesd_rst_n) begin
        phy_disparity  <= 2'd0;
        phy_notintable <= 2'd0;
    end
    else begin
        phy_disparity  <= disparity_level & ~disparity_r;
        phy_notintable <= notintable_level & ~notintable_r;
    end
end

always @(posedge jesd_clk or negedge jesd_rst_n) begin
    if(~jesd_rst_n)
        jesd_link_error <= 1'd0;
    else
        jesd_link_error <= jesd_link_error_set;
end

endmodule
