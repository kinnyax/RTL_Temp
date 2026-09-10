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

parameter               [ 7:0]              AFE_ID                   = 8'd0                ;

wire                                        adc_en                                         ;
wire                                        afe_en                                         ;
wire                    [127:0]             adi_data                                       ;
wire                                        adi_data_vld                                   ;
wire                                        adi_link_qual                                  ;
wire                                        adi_sysref_error                               ;
wire                                        adi_sysref_seen                                ;
wire                                        adi_link_ready                                 ;
wire                    [ 1:0]              adi_lane_ready                                 ;
wire                    [ 1:0]              adi_cgs_ready                                  ;
wire                                        adi_phy_rx_reset_done                          ;
wire                                        adi_phy_pll_lock                               ;
wire                    [ 1:0]              adi_phy_byte_aligned                           ;
wire                    [ 1:0]              phy_disparity                                  ;
wire                    [ 1:0]              phy_notintable                                 ;
wire                                        jesd_link_error                                ;
wire                    [511:0]             rx_fifo_wdat                                   ;
wire                                        rx_fifo_winc                                   ;
wire                    [511:0]             rx_fifo_rdat                                   ;
wire                                        rx_fifo_rinc                                   ;
wire                    [ 9:0]              rx_fifo_rlevel                                 ;
wire                                        rxd_idle                                       ;
wire                                        txd_idle                                       ;
wire                                        tgc_sta_idle                                   ;
wire                                        fifo_rst_n                                     ;

//////////////////////////////////////////////////
//1. Local Control And CDC
//////////////////////////////////////////////////
level_sync adc_enable_level_sync(.clk(adc_clk),.rst_n(adc_rst_n),.in(chn_en),.out(adc_en));
level_sync afe_enable_level_sync(.clk(afe_clk),.rst_n(afe_rst_n),.in(chn_en),.out(afe_en));

//////////////////////////////////////////////////
//2. Receive And Decode
//////////////////////////////////////////////////
ADC_ADI adc_adi(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .jesd_clk                            (jesd_clk                                     ),
    .jesd_rst_n                          (jesd_rst_n                                   ),
    .sysref                              (sysref                                       ),
    .phy_rx_data                         (phy_rx_data                                  ),
    .phy_rx_charisk                      (phy_rx_charisk                               ),
    .phy_rx_disperr                      (phy_rx_disperr                               ),
    .phy_rx_notintable                   (phy_rx_notintable                            ),
    .rx_reset_done                       (phy_rx_reset_done                            ),
    .pll_lock                            (phy_pll_lock                                 ),
    .byte_aligned                        (phy_byte_aligned                             ),
    .phy_rx_encommalign                  (phy_rx_encommalign                           ),
    .phy_sync_n                          (phy_sync_n                                   ),
    .adi_data                            (adi_data                                     ),
    .adi_data_vld                        (adi_data_vld                                 ),
    .adi_link_qual                       (adi_link_qual                                ),
    .adi_sysref_error                    (adi_sysref_error                             ),
    .adi_sysref_seen                     (adi_sysref_seen                              ),
    .adi_link_ready                      (adi_link_ready                               ),
    .adi_lane_ready                      (adi_lane_ready                               ),
    .adi_cgs_ready                       (adi_cgs_ready                                ),
    .phy_rx_reset_done                   (adi_phy_rx_reset_done                        ),
    .phy_pll_lock                        (adi_phy_pll_lock                             ),
    .phy_byte_aligned                    (adi_phy_byte_aligned                         ),
    .phy_disparity                       (phy_disparity                                ),
    .phy_notintable                      (phy_notintable                               ),
    .jesd_link_error                     (jesd_link_error                              )
);

ADC_RXD adc_rxd(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (afe_en                                       ),
    .adi_data                            (adi_data                                     ),
    .adi_data_vld                        (adi_data_vld                                 ),
    .adi_link_qual                       (adi_link_qual                                ),
    .adc_ctl                             (adc_ctl                                      ),
    .frm_cfg                             (frm_cfg                                      ),
    .rx_fifo_wdat                        (rx_fifo_wdat                                 ),
    .rx_fifo_winc                        (rx_fifo_winc                                 ),
    .data_error                          (data_error                                   ),
    .rxd_idle                            (rxd_idle                                     )
);

//////////////////////////////////////////////////
//3. FIFO And Transmit
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

ADC_TXD #(
    .AFE_ID                              (AFE_ID                                       )
) adc_txd(
    .adc_clk                             (adc_clk                                      ),
    .adc_rst_n                           (adc_rst_n                                    ),
    .chn_en                              (adc_en                                       ),
    .link_ready_sync                     (link_ready_sync                              ),
    .rx_fifo_rdat                        (rx_fifo_rdat                                 ),
    .rx_fifo_rlevel                      (rx_fifo_rlevel                               ),
    .rx_fifo_rinc                        (rx_fifo_rinc                                 ),
    .m_axis_tdata                        (m_axis_tdata                                 ),
    .m_axis_tkeep                        (m_axis_tkeep                                 ),
    .m_axis_tvalid                       (m_axis_tvalid                                ),
    .m_axis_tlast                        (m_axis_tlast                                 ),
    .m_axis_tready                       (m_axis_tready                                ),
    .txd_idle                            (txd_idle                                     )
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
    .phy_rx_reset_done                   (adi_phy_rx_reset_done                        ),
    .phy_rx_reset_done_sync              (phy_rx_reset_done_sync                       ),
    .phy_pll_lock                        (adi_phy_pll_lock                             ),
    .phy_pll_lock_sync                   (phy_pll_lock_sync                            ),
    .phy_byte_aligned                    (adi_phy_byte_aligned                         ),
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
    .jesd_link_error                     (jesd_link_error                              ),
    .link_error_sync                     (link_error_sync                              ),
    .rxd_idle                            (rxd_idle                                     ),
    .tgc_sta_idle                        (tgc_sta_idle                                 ),
    .txd_idle                            (txd_idle                                     ),
    .chn_idle                            (chn_idle                                     )
);

//////////////////////////////////////////////////
//5. TGC Action
//////////////////////////////////////////////////
ADC_TGC adc_tgc(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (afe_en                                       ),
    .chn_tgc                             (chn_tgc                                      ),
    .tgc_done                            (tgc_done                                     ),
    .tgc_sta_idle                        (tgc_sta_idle                                 ),
    .tgc_slope                           (tgc_slope                                    ),
    .tgc_up_dn                           (tgc_up_dn                                    ),
    .tgc_prof1                           (tgc_prof1                                    ),
    .tgc_prof2                           (tgc_prof2                                    )
);

endmodule
