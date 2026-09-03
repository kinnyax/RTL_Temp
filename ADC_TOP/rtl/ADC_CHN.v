`timescale 1ns / 1ps

module ADC_CHN(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,
    input                                   jesd_clk                                       ,
    input                                   jesd_rst_n                                     ,

    input                                   chn_en                                         ,
    input                                   fifo_clr                                       ,
    input                                   sysref                                         ,
    input               [31:0]              adc_ctl                                        ,
    input               [31:0]              frm_cfg                                        ,
    input               [63:0]              phy_rx_data                                    ,
    input               [ 7:0]              phy_rx_charisk                                 ,
    input               [ 7:0]              phy_rx_disperr                                 ,
    input               [ 7:0]              phy_rx_notintable                              ,
    input                                   phy_rx_reset_done                              ,
    input                                   phy_pll_lock                                   ,
    input               [ 1:0]              phy_byte_aligned                               ,
    output    wire                          phy_rx_encommalign                             ,
    output    wire                          phy_sync_n                                     ,

    output    wire      [511:0]             m_axis_tdata                                   ,
    output    wire      [63:0]              m_axis_tkeep                                   ,
    output    wire                          m_axis_tvalid                                  ,
    output    wire                          m_axis_tlast                                   ,
    input                                   m_axis_tready                                  ,

    output    wire                          link_ready_sync                                ,
    output    wire                          rx_fifo_empt                                   ,
    output    wire                          chn_idle                                       ,
    output    wire                          phy_pll_lock_sync                              ,
    output    wire                          phy_rx_reset_done_sync                         ,
    output    wire      [ 1:0]              lane_ready_sync                                ,
    output    wire      [ 1:0]              phy_byte_aligned_sync                          ,
    output    wire      [ 1:0]              cgs_ready_sync                                 ,
    output    wire                          fifo_overflow                                  ,
    output    wire                          link_error_sync                                ,
    output    wire                          sysref_seen_sync                               ,
    output    wire      [ 1:0]              phy_disparity_sync                             ,
    output    wire      [ 1:0]              phy_notintable_sync                            ,

    input               [ 3:0]              chn_tgc                                        ,
    output    wire                          tgc_done                                       ,
    output    wire                          tgc_slope                                      ,
    output    wire                          tgc_up_dn                                      ,
    output    wire                          tgc_prof1                                      ,
    output    wire                          tgc_prof2                                      ,
    output    wire                          fifo_full                                      ,
    output    wire                          data_error
);

parameter                                   UDLY                     = 1                   ;

wire                                        pkt_en                                         ;
wire                                        upk_en                                         ;
wire                    [127:0]             rxd_data                                       ;
wire                                        rxd_data_vld                                   ;
wire                                        rxd_ready                                      ;
wire                                        adi_sysref_error                               ;
wire                                        adi_sysref_seen                                ;
wire                                        adi_link_ready                                 ;
wire                    [ 1:0]              adi_lane_ready                                 ;
wire                    [ 1:0]              adi_cgs_ready                                  ;
wire                    [ 1:0]              phy_disparity                                  ;
wire                    [ 1:0]              phy_notintable                                 ;
wire                                        link_error                                     ;
wire                    [511:0]             rx_fifo_wdat                                   ;
wire                                        rx_fifo_winc                                   ;
wire                    [511:0]             rx_fifo_rdat                                   ;
wire                                        rx_fifo_rinc                                   ;
wire                    [ 9:0]              rx_fifo_rlevel                                 ;
wire                                        upk_idle                                       ;
wire                                        pkt_idle                                       ;
wire                                        tgc_sta_idle                                   ;
wire                                        afe_idle                                       ;
wire                                        afe_idle_sync                                  ;
wire                                        fifo_rst_n                                     ;

//////////////////////////////////////////////////
//1. Local Control And CDC
//////////////////////////////////////////////////
assign afe_idle = upk_idle & tgc_sta_idle;
assign chn_idle = pkt_idle & afe_idle_sync;

level_sync packet_enable_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(chn_en),.out(pkt_en));
level_sync unpack_enable_level_sync(.clk(afe_clk),.rst_n(afe_rst_n),.in(chn_en),.out(upk_en));

//////////////////////////////////////////////////
//2. Receive And Unpack
//////////////////////////////////////////////////
ADC_RXD adc_rxd(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .jesd_clk                            (jesd_clk                                     ),
    .jesd_rst_n                          (jesd_rst_n                                   ),
    .chn_en                              (upk_en                                       ),
    .sysref                              (sysref                                       ),
    .phy_rx_data                         (phy_rx_data                                  ),
    .phy_rx_charisk                      (phy_rx_charisk                               ),
    .phy_rx_disperr                      (phy_rx_disperr                               ),
    .phy_rx_notintable                   (phy_rx_notintable                            ),
    .phy_rx_reset_done                   (phy_rx_reset_done                            ),
    .phy_pll_lock                        (phy_pll_lock                                 ),
    .phy_rx_encommalign                  (phy_rx_encommalign                           ),
    .phy_sync_n                          (phy_sync_n                                   ),
    .rxd_data                            (rxd_data                                     ),
    .rxd_data_vld                        (rxd_data_vld                                 ),
    .rxd_ready                           (rxd_ready                                    ),
    .adi_sysref_error                    (adi_sysref_error                             ),
    .adi_sysref_seen                     (adi_sysref_seen                              ),
    .adi_link_ready                      (adi_link_ready                               ),
    .adi_lane_ready                      (adi_lane_ready                               ),
    .adi_cgs_ready                       (adi_cgs_ready                                ),
    .phy_disparity                       (phy_disparity                                ),
    .phy_notintable                      (phy_notintable                               ),
    .link_error                          (link_error                                   )
);

ADC_UPK adc_upk(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (upk_en                                       ),
    .rxd_data                            (rxd_data                                     ),
    .rxd_data_vld                        (rxd_data_vld                                 ),
    .rxd_ready                           (rxd_ready                                    ),
    .adc_ctl                             (adc_ctl                                      ),
    .frm_cfg                             (frm_cfg                                      ),
    .rx_fifo_wdat                        (rx_fifo_wdat                                 ),
    .rx_fifo_winc                        (rx_fifo_winc                                 ),
    .data_error                          (data_error                                   ),
    .upk_idle                            (upk_idle                                     )
);

//////////////////////////////////////////////////
//3. FIFO And Packet
//////////////////////////////////////////////////
assign fifo_rst_n = ~fifo_clr & afe_rst_n & adc_rst_n;

async_fifo #(
    .AS                                  (9                                            ),
    .DS                                  (512                                          ),
    .RSTEN                               (0                                            ),
    .WC                                  (0                                            ),
    .RC                                  (0                                            )
) rx_fifo(
    .wclk                                (afe_clk                                      ),
    .rclk                                (adc_clk                                      ),
    .wclr                                (1'd0                                         ),
    .rclr                                (1'd0                                         ),
    .rst_n                               (fifo_rst_n                                   ),
    .winc                                (rx_fifo_winc                                 ),
    .rinc                                (rx_fifo_rinc                                 ),
    .wdata                               (rx_fifo_wdat                                 ),
    .rdata                               (rx_fifo_rdat                                 ),
    .full                                (fifo_full                                    ),
    .empty                               (rx_fifo_empt                                 ),
    .overflow                            (fifo_overflow                                ),
    .underflow                           (                                             ),
    .wlevel                              (                                             ),
    .rlevel                              (rx_fifo_rlevel                               )
);

ADC_PKT adc_pkt(
    .adc_clk                             (adc_clk                                      ),
    .adc_rst_n                           (adc_rst_n                                    ),
    .chn_en                              (pkt_en                                       ),
    .rx_fifo_rdat                        (rx_fifo_rdat                                 ),
    .rx_fifo_empty                       (rx_fifo_empt                                 ),
    .rx_fifo_rlevel                      (rx_fifo_rlevel                               ),
    .rx_fifo_rinc                        (rx_fifo_rinc                                 ),
    .m_axis_tdata                        (m_axis_tdata                                 ),
    .m_axis_tkeep                        (m_axis_tkeep                                 ),
    .m_axis_tvalid                       (m_axis_tvalid                                ),
    .m_axis_tlast                        (m_axis_tlast                                 ),
    .m_axis_tready                       (m_axis_tready                                ),
    .pkt_idle                            (pkt_idle                                     )
);

//////////////////////////////////////////////////
//4. Status CDC
//////////////////////////////////////////////////
CHN_SYNC chn_sync(
    .adc_clk                             (adc_clk                                      ),
    .adc_rst_n                           (adc_rst_n                                    ),
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .jesd_clk                            (jesd_clk                                     ),
    .jesd_rst_n                          (jesd_rst_n                                   ),
    .phy_rx_reset_done                   (phy_rx_reset_done                            ),
    .phy_rx_reset_done_sync              (phy_rx_reset_done_sync                       ),
    .phy_pll_lock                        (phy_pll_lock                                 ),
    .phy_pll_lock_sync                   (phy_pll_lock_sync                            ),
    .phy_byte_aligned                    (phy_byte_aligned                             ),
    .phy_byte_align_sync                 (phy_byte_aligned_sync                        ),
    .sysref_error                        (adi_sysref_error                             ),
    .sysref_seen                         (adi_sysref_seen                              ),
    .sysref_seen_sync                    (sysref_seen_sync                             ),
    .link_ready                          (adi_link_ready                               ),
    .link_ready_sync                     (link_ready_sync                              ),
    .lane_ready                          (adi_lane_ready                               ),
    .lane_ready_sync                     (lane_ready_sync                              ),
    .cgs_ready                           (adi_cgs_ready                                ),
    .cgs_ready_sync                      (cgs_ready_sync                               ),
    .phy_disparity                       (phy_disparity                                ),
    .phy_disparity_sync                  (phy_disparity_sync                           ),
    .phy_notintable                      (phy_notintable                               ),
    .phy_notintable_sync                 (phy_notintable_sync                          ),
    .link_error                          (link_error                                   ),
    .link_error_sync                     (link_error_sync                              ),
    .afe_idle                            (afe_idle                                     ),
    .afe_idle_sync                       (afe_idle_sync                                )
);

//////////////////////////////////////////////////
//5. TGC Action
//////////////////////////////////////////////////
ADC_TGC adc_tgc(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (upk_en                                       ),
    .chn_tgc                             (chn_tgc                                      ),
    .tgc_done                            (tgc_done                                     ),
    .tgc_sta_idle                        (tgc_sta_idle                                 ),
    .tgc_slope                           (tgc_slope                                    ),
    .tgc_up_dn                           (tgc_up_dn                                    ),
    .tgc_prof1                           (tgc_prof1                                    ),
    .tgc_prof2                           (tgc_prof2                                    )
);

endmodule
