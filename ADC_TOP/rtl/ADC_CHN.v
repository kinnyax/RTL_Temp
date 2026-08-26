`timescale 1ns / 1ps

module ADC_CHN(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,
    input                                   afe_clk                                        ,
    input                                   afe_rst_n                                      ,
    input                                   jesd_clk                                       ,
    input                                   jesd_rst_n                                     ,
    input               [2:0]               chn_id                                         ,
    input                                   chn_en                                         ,
    input                                   fifo_clr                                       ,
    input                                   sysref                                         ,
    input               [31:0]              adc_ctl                                        ,
    input               [31:0]              frm_cfg                                        ,
    input               [63:0]              phy_rx_data                                    ,
    input               [7:0]               phy_rx_charisk                                 ,
    input               [7:0]               phy_rx_disperr                                 ,
    input               [7:0]               phy_rx_notintable                              ,
    input                                   phy_rx_reset_done                              ,
    input                                   phy_pll_lock                                   ,
    input               [1:0]               phy_byte_aligned                               ,
    output    wire                          phy_rx_encommalign                             ,
    output    wire                          phy_sync_n                                     ,
    output    wire      [511:0]             m_axis_tdata                                   ,
    output    wire      [63:0]              m_axis_tkeep                                   ,
    output    wire                          m_axis_tvalid                                  ,
    output    wire                          m_axis_tlast                                   ,
    input                                   m_axis_tready                                  ,
    output    wire                          link_ready_sync                                ,
    output    wire                          rx_fifo_empt                                   ,
    output    wire                          chn_idle_adc                                   ,
    output    wire                          phy_pll_lock_sync                              ,
    output    wire                          phy_rx_reset_done_sync                         ,
    output    wire      [1:0]               lane_ready_sync                                ,
    output    wire      [1:0]               phy_byte_aligned_sync                          ,
    output    wire      [1:0]               cgs_ready_sync                                 ,
    output    wire                          rx_fifo_of                                     ,
    output    wire                          link_error_sync                                ,
    output    wire                          sysref_seen_sync                               ,
    output    wire      [1:0]               phy_disparity_sync                             ,
    output    wire      [1:0]               phy_notintable_sync                            ,
    input                                   tgc_cmd_evt                                    ,
    input               [1:0]               tgc_profile                                    ,
    input                                   tgc_up_dn                                      ,
    output    wire                          tgc_done_evt                                   ,
    output    wire                          tgc_slope                                      ,
    output    wire                          tgc_up_dn_o                                    ,
    output    wire                          tgc_prof1                                      ,
    output    wire                          tgc_prof2                                      ,
    output    wire                          fifo_full_afe                                  ,
    output    wire                          data_error_evt
);

parameter                                   UDLY                     = 1                   ;

wire                                        chn_en_afe                                     ;
wire                                        chn_en_adc                                     ;
wire                    [255:0]             rxd_data                                       ;
wire                    [15:0]              rxd_somf                                       ;
wire                                        rxd_data_vld                                   ;
wire                                        sysref_error                                   ;
wire                                        sysref_seen                                    ;
wire                                        link_ready                                     ;
wire                    [1:0]               lane_ready                                     ;
wire                    [1:0]               cgs_ready                                      ;
wire                    [1:0]               phy_disparity                                  ;
wire                    [1:0]               phy_notintable                                 ;
wire                                        link_error                                     ;
wire                    [511:0]             rx_fifo_wdat                                   ;
wire                    [511:0]             rx_fifo_rdat                                   ;
wire                                        rx_fifo_winc                                   ;
wire                                        rx_fifo_rinc                                   ;
wire                                        rx_fifo_rst_n                                  ;
wire                                        rx_fifo_empty                                  ;
wire                                        rx_fifo_full                                   ;
/* verilator lint_off UNUSEDSIGNAL */
wire                                        rx_fifo_underflow                              ;
/* verilator lint_on UNUSEDSIGNAL */
wire                    [9:0]               rx_fifo_wlevel                                 ;
wire                    [9:0]               rx_fifo_rlevel                                 ;
wire                                        data_error_evt_afe                             ;

reg                                         fifo_sta                                       ;

wire                                        fifo_sta_sync                                  ;
wire                                        upk_idle                                       ;
wire                                        upk_idle_sync                                  ;
wire                                        tgc_idle                                       ;
wire                                        tgc_idle_sync                                  ;
wire                                        pkt_idle                                       ;
level_sync afe_chn_en_cdc(.clk(afe_clk), .rst_n(afe_rst_n), .in(chn_en), .out(chn_en_afe));
level_sync adc_chn_en_cdc(.clk(adc_clk), .rst_n(adc_rst_n), .in(chn_en), .out(chn_en_adc));

ADC_RXD #(
    .UDLY                               (UDLY                                         )
) adc_rxd(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .jesd_clk                            (jesd_clk                                     ),
    .jesd_rst_n                          (jesd_rst_n                                   ),
    .chn_en                              (chn_en_afe                                   ),
    .sysref                              (sysref                                       ),
    .phy_rx_data                         (phy_rx_data                                  ),
    .phy_rx_charisk                      (phy_rx_charisk                               ),
    .phy_rx_disperr                      (phy_rx_disperr                               ),
    .phy_rx_notintable                   (phy_rx_notintable                            ),
    .phy_rx_reset_done                   (phy_rx_reset_done                            ),
    .phy_pll_lock                        (phy_pll_lock                                 ),
    .phy_rx_encommalign                  (phy_rx_encommalign                           ),
    .phy_sync_n                          (phy_sync_n                                   ),
    .adi_rxd_data                        (rxd_data                                     ),
    .adi_rxd_somf                        (rxd_somf                                     ),
    .adi_rxd_vld                         (rxd_data_vld                                 ),
    .adi_sysref_error                    (sysref_error                                 ),
    .adi_sysref_seen                     (sysref_seen                                  ),
    .adi_link_ready                      (link_ready                                   ),
    .adi_lane_ready                      (lane_ready                                   ),
    .adi_cgs_ready                       (cgs_ready                                    ),
    .phy_disparity                       (phy_disparity                                ),
    .phy_notintable                      (phy_notintable                               ),
    .link_error                          (link_error                                   )
);

ADC_UPK #(
    .UDLY                               (UDLY                                         )
) adc_upk(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (chn_en_afe                                   ),
    .rxd_data_vld                        (rxd_data_vld                                 ),
    .rxd_data                            (rxd_data                                     ),
    .rxd_somf                            (rxd_somf                                     ),
    .adc_ctl                             (adc_ctl                                      ),
    .frm_cfg                             (frm_cfg                                      ),
    .rx_fifo_wlevel                      (rx_fifo_wlevel                               ),
    .rx_fifo_wdat                        (rx_fifo_wdat                                 ),
    .rx_fifo_winc                        (rx_fifo_winc                                 ),
    .data_error_evt                      (data_error_evt_afe                           ),
    .upk_idle                            (upk_idle                                     )
);

assign rx_fifo_rst_n = afe_rst_n & adc_rst_n & ~fifo_clr;

async_fifo #(
    .AS                                  (9                                            ),
    .DS                                  (512                                          ),
    .RSTEN                               (0                                            ),
    .WC                                  (0                                            ),
    .RC                                  (0                                            )
) async_fifo_fwft(
    .wclk                                (afe_clk                                      ),
    .rclk                                (adc_clk                                      ),
    .wclr                                (1'b0                                         ),
    .rclr                                (1'b0                                         ),
    .rst_n                               (rx_fifo_rst_n                                ),
    .winc                                (rx_fifo_winc                                 ),
    .rinc                                (rx_fifo_rinc                                 ),
    .wdata                               (rx_fifo_wdat                                 ),
    .rdata                               (rx_fifo_rdat                                 ),
    .full                                (rx_fifo_full                                 ),
    .empty                               (rx_fifo_empty                                ),
    .overflow                            (rx_fifo_of                                   ),
    .underflow                           (rx_fifo_underflow                             ),
    .wlevel                              (rx_fifo_wlevel                               ),
    .rlevel                              (rx_fifo_rlevel                               )
);

assign rx_fifo_empt  = rx_fifo_empty;
assign fifo_full_afe = rx_fifo_full;

always @(posedge afe_clk or negedge afe_rst_n or negedge adc_rst_n) begin
    if(!afe_rst_n | !adc_rst_n)
        fifo_sta <= #UDLY 1'b0;
    else if(fifo_clr)
        fifo_sta <= #UDLY 1'b0;
    else if(data_error_evt_afe)
        fifo_sta <= #UDLY 1'b1;
end

assign data_error_evt = data_error_evt_afe;

ADC_PKT #(
    .UDLY                               (UDLY                                         )
) adc_pkt(
    .adc_clk                             (adc_clk                                      ),
    .adc_rst_n                           (adc_rst_n                                    ),
    .chn_id                              (chn_id                                       ),
    .chn_en                              (chn_en_adc                                   ),
    .smp_prec                            (adc_ctl[31:30]                               ),
    .smp_mode                            (adc_ctl[27:26]                               ),
    .dec_m                               (frm_cfg[7:0]                                 ),
    .link_ready                          (link_ready_sync                              ),
    .rx_fifo_rdat                        (rx_fifo_rdat                                 ),
    .rx_fifo_empty                       (rx_fifo_empty                                ),
    .rx_fifo_rlevel                      (rx_fifo_rlevel                               ),
    .rx_fifo_rinc                        (rx_fifo_rinc                                 ),
    .m_axis_tdata                        (m_axis_tdata                                 ),
    .m_axis_tkeep                        (m_axis_tkeep                                 ),
    .m_axis_tvalid                       (m_axis_tvalid                                ),
    .m_axis_tlast                        (m_axis_tlast                                 ),
    .m_axis_tready                       (m_axis_tready                                ),
    .chn_idle                            (pkt_idle                                     ),
    .fifo_sta                            (fifo_sta_sync                                )
);

ADC_TGC #(
    .UDLY                               (UDLY                                         )
) adc_tgc(
    .afe_clk                             (afe_clk                                      ),
    .afe_rst_n                           (afe_rst_n                                    ),
    .chn_en                              (chn_en_afe                                   ),
    .tgc_cmd_evt                         (tgc_cmd_evt                                  ),
    .profile_sel                         (tgc_profile                                  ),
    .up_dn                               (tgc_up_dn                                    ),
    .tgc_done_evt                        (tgc_done_evt                                 ),
    .tgc_idle                            (tgc_idle                                     ),
    .tgc_slope                           (tgc_slope                                    ),
    .tgc_up_dn                           (tgc_up_dn_o                                  ),
    .tgc_prof1                           (tgc_prof1                                    ),
    .tgc_prof2                           (tgc_prof2                                    )
);

CHN_SYNC #(
    .UDLY                               (UDLY                                         )
) chn_sync(
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
    .sysref_error                        (sysref_error                                 ),
    .sysref_seen                         (sysref_seen                                  ),
    .sysref_seen_sync                    (sysref_seen_sync                             ),
    .link_ready                          (link_ready                                   ),
    .link_ready_sync                     (link_ready_sync                              ),
    .lane_ready                          (lane_ready                                   ),
    .lane_ready_sync                     (lane_ready_sync                              ),
    .cgs_ready                           (cgs_ready                                    ),
    .cgs_ready_sync                      (cgs_ready_sync                               ),
    .phy_disparity                       (phy_disparity                                ),
    .phy_disparity_sync                  (phy_disparity_sync                           ),
    .phy_notintable                      (phy_notintable                               ),
    .phy_notintable_sync                 (phy_notintable_sync                          ),
    .link_error                          (link_error                                   ),
    .link_error_sync                     (link_error_sync                              ),
    .fifo_sta                            (fifo_sta                                     ),
    .fifo_sta_sync                       (fifo_sta_sync                                ),
    .upk_idle                            (upk_idle                                     ),
    .upk_idle_sync                       (upk_idle_sync                                ),
    .tgc_idle                            (tgc_idle                                     ),
    .tgc_idle_sync                       (tgc_idle_sync                                )
);

assign chn_idle_adc = pkt_idle & upk_idle_sync & tgc_idle_sync;

endmodule
