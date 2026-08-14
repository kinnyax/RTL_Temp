`timescale 1ns / 1ps
`default_nettype none

module sim_top;

reg                                         sys_clk;
reg                                         adc_clk;
reg                                         afe_clk;
reg  [7:0]                                  jesd_clk;
reg                                         sys_rst_n;
reg                                         adc_rst_n;
reg                                         afe_rst_n;
reg  [7:0]                                  jesd_rst_n;
reg                                         sysref_in;
reg  [7:0]                                  afe_model_en;
reg  [7:0]                                  axis_ready;

wire [15:0]                                 s_axi_awaddr;
wire                                        s_axi_awvalid;
wire                                        s_axi_awready;
wire [31:0]                                 s_axi_wdata;
wire [3:0]                                  s_axi_wstrb;
wire                                        s_axi_wvalid;
wire                                        s_axi_wready;
wire [1:0]                                  s_axi_bresp;
wire                                        s_axi_bvalid;
wire                                        s_axi_bready;
wire [15:0]                                 s_axi_araddr;
wire                                        s_axi_arvalid;
wire                                        s_axi_arready;
wire [31:0]                                 s_axi_rdata;
wire [1:0]                                  s_axi_rresp;
wire                                        s_axi_rvalid;
wire                                        s_axi_rready;

wire [63:0]                                 afe_rx_data       [0:7];
wire [7:0]                                  afe_rx_charisk    [0:7];
wire [7:0]                                  afe_rx_disperr    [0:7];
wire [7:0]                                  afe_rx_notintable [0:7];
wire [7:0]                                  afe_rx_reset_done;
wire [7:0]                                  afe_pll_lock;
wire [1:0]                                  afe_byte_aligned  [0:7];
wire [7:0]                                  afe_rx_encommalign;
wire [7:0]                                  afe_sync_n;
wire [2:0]                                  afe_model_phase   [0:7];

wire [511:0]                                m_axis_tdata      [0:7];
wire [63:0]                                 m_axis_tkeep      [0:7];
wire [7:0]                                  m_axis_tvalid;
wire [7:0]                                  m_axis_tlast;
wire [7:0]                                  tgc_slope;
wire [7:0]                                  tgc_up_dn;
wire [7:0]                                  tgc_prof1;
wire [7:0]                                  tgc_prof2;

initial begin
    sys_clk = 1'b0;
    forever #5 sys_clk = ~sys_clk;              // 100 MHz
end

initial begin
    adc_clk = 1'b0;
    forever #2.5 adc_clk = ~adc_clk;            // 200 MHz
end

initial begin
    afe_clk = 1'b0;
    forever #12.5 afe_clk = ~afe_clk;           // 40 MHz
end

initial begin
    jesd_clk = 8'h00;
    forever #3.125 jesd_clk = ~jesd_clk;        // 8 x 160 MHz, common phase
end

initial begin
    sys_rst_n    = 1'b0;
    adc_rst_n    = 1'b0;
    afe_rst_n    = 1'b0;
    jesd_rst_n   = 8'h00;
    sysref_in    = 1'b0;
    afe_model_en = 8'h00;
    axis_ready   = 8'hff;
    repeat(20) @(posedge sys_clk);
    sys_rst_n    = 1'b1;
    adc_rst_n    = 1'b1;
    afe_rst_n    = 1'b1;
    jesd_rst_n   = 8'hff;
end

task pulse_sysref;
    begin
        @(negedge afe_clk);
        sysref_in = 1'b1;
        repeat(3) @(posedge afe_clk);
        @(negedge afe_clk);
        sysref_in = 1'b0;
    end
endtask

task wait_afe0_axis_beat;
    output [511:0] data;
    output         last;
    begin : wait_axis_loop
        forever begin
            @(posedge adc_clk);
            if(m_axis_tvalid[0] && axis_ready[0]) begin
                data = m_axis_tdata[0];
                last = m_axis_tlast[0];
                disable wait_axis_loop;
            end
        end
    end
endtask

AXI_MASTER #(
    .ADDR_WIDTH                            (16                                           ),
    .DATA_WIDTH                            (32                                           )
) axi_master (
    .aclk                                  (sys_clk                                      ),
    .aresetn                               (sys_rst_n                                    ),
    .awvalid                               (s_axi_awvalid                                ),
    .awready                               (s_axi_awready                                ),
    .awaddr                                (s_axi_awaddr                                 ),
    .awprot                                (                                             ),
    .wvalid                                (s_axi_wvalid                                 ),
    .wready                                (s_axi_wready                                 ),
    .wdata                                 (s_axi_wdata                                  ),
    .wstrb                                 (s_axi_wstrb                                  ),
    .bvalid                                (s_axi_bvalid                                 ),
    .bready                                (s_axi_bready                                 ),
    .bresp                                 (s_axi_bresp                                  ),
    .arvalid                               (s_axi_arvalid                                ),
    .arready                               (s_axi_arready                                ),
    .araddr                                (s_axi_araddr                                 ),
    .arprot                                (                                             ),
    .rvalid                                (s_axi_rvalid                                 ),
    .rready                                (s_axi_rready                                 ),
    .rdata                                 (s_axi_rdata                                  ),
    .rresp                                 (s_axi_rresp                                  )
);

AC9810_MASTER afe0_model(
    .jesd_clk                              (jesd_clk[0]                                  ),
    .jesd_rst_n                            (jesd_rst_n[0]                                ),
    .model_enable                          (afe_model_en[0]                              ),
    .sysref                                (sysref_in                                    ),
    .sync_n                                (afe_sync_n[0]                                ),
    .rx_encommalign                        (afe_rx_encommalign[0]                        ),
    .rx_data                               (afe_rx_data[0]                               ),
    .rx_charisk                            (afe_rx_charisk[0]                            ),
    .rx_disperr                            (afe_rx_disperr[0]                            ),
    .rx_notintable                         (afe_rx_notintable[0]                         ),
    .rx_reset_done                         (afe_rx_reset_done[0]                         ),
    .pll_lock                              (afe_pll_lock[0]                              ),
    .byte_aligned                          (afe_byte_aligned[0]                          ),
    .model_phase                           (afe_model_phase[0]                           )
);

AC9810_MASTER afe1_model(
    .jesd_clk(jesd_clk[1]), .jesd_rst_n(jesd_rst_n[1]), .model_enable(afe_model_en[1]),
    .sysref(sysref_in), .sync_n(afe_sync_n[1]), .rx_encommalign(afe_rx_encommalign[1]),
    .rx_data(afe_rx_data[1]), .rx_charisk(afe_rx_charisk[1]), .rx_disperr(afe_rx_disperr[1]),
    .rx_notintable(afe_rx_notintable[1]), .rx_reset_done(afe_rx_reset_done[1]),
    .pll_lock(afe_pll_lock[1]), .byte_aligned(afe_byte_aligned[1]), .model_phase(afe_model_phase[1])
);

AC9810_MASTER afe2_model(
    .jesd_clk(jesd_clk[2]), .jesd_rst_n(jesd_rst_n[2]), .model_enable(afe_model_en[2]),
    .sysref(sysref_in), .sync_n(afe_sync_n[2]), .rx_encommalign(afe_rx_encommalign[2]),
    .rx_data(afe_rx_data[2]), .rx_charisk(afe_rx_charisk[2]), .rx_disperr(afe_rx_disperr[2]),
    .rx_notintable(afe_rx_notintable[2]), .rx_reset_done(afe_rx_reset_done[2]),
    .pll_lock(afe_pll_lock[2]), .byte_aligned(afe_byte_aligned[2]), .model_phase(afe_model_phase[2])
);

AC9810_MASTER afe3_model(
    .jesd_clk(jesd_clk[3]), .jesd_rst_n(jesd_rst_n[3]), .model_enable(afe_model_en[3]),
    .sysref(sysref_in), .sync_n(afe_sync_n[3]), .rx_encommalign(afe_rx_encommalign[3]),
    .rx_data(afe_rx_data[3]), .rx_charisk(afe_rx_charisk[3]), .rx_disperr(afe_rx_disperr[3]),
    .rx_notintable(afe_rx_notintable[3]), .rx_reset_done(afe_rx_reset_done[3]),
    .pll_lock(afe_pll_lock[3]), .byte_aligned(afe_byte_aligned[3]), .model_phase(afe_model_phase[3])
);

AC9810_MASTER afe4_model(
    .jesd_clk(jesd_clk[4]), .jesd_rst_n(jesd_rst_n[4]), .model_enable(afe_model_en[4]),
    .sysref(sysref_in), .sync_n(afe_sync_n[4]), .rx_encommalign(afe_rx_encommalign[4]),
    .rx_data(afe_rx_data[4]), .rx_charisk(afe_rx_charisk[4]), .rx_disperr(afe_rx_disperr[4]),
    .rx_notintable(afe_rx_notintable[4]), .rx_reset_done(afe_rx_reset_done[4]),
    .pll_lock(afe_pll_lock[4]), .byte_aligned(afe_byte_aligned[4]), .model_phase(afe_model_phase[4])
);

AC9810_MASTER afe5_model(
    .jesd_clk(jesd_clk[5]), .jesd_rst_n(jesd_rst_n[5]), .model_enable(afe_model_en[5]),
    .sysref(sysref_in), .sync_n(afe_sync_n[5]), .rx_encommalign(afe_rx_encommalign[5]),
    .rx_data(afe_rx_data[5]), .rx_charisk(afe_rx_charisk[5]), .rx_disperr(afe_rx_disperr[5]),
    .rx_notintable(afe_rx_notintable[5]), .rx_reset_done(afe_rx_reset_done[5]),
    .pll_lock(afe_pll_lock[5]), .byte_aligned(afe_byte_aligned[5]), .model_phase(afe_model_phase[5])
);

AC9810_MASTER afe6_model(
    .jesd_clk(jesd_clk[6]), .jesd_rst_n(jesd_rst_n[6]), .model_enable(afe_model_en[6]),
    .sysref(sysref_in), .sync_n(afe_sync_n[6]), .rx_encommalign(afe_rx_encommalign[6]),
    .rx_data(afe_rx_data[6]), .rx_charisk(afe_rx_charisk[6]), .rx_disperr(afe_rx_disperr[6]),
    .rx_notintable(afe_rx_notintable[6]), .rx_reset_done(afe_rx_reset_done[6]),
    .pll_lock(afe_pll_lock[6]), .byte_aligned(afe_byte_aligned[6]), .model_phase(afe_model_phase[6])
);

AC9810_MASTER afe7_model(
    .jesd_clk(jesd_clk[7]), .jesd_rst_n(jesd_rst_n[7]), .model_enable(afe_model_en[7]),
    .sysref(sysref_in), .sync_n(afe_sync_n[7]), .rx_encommalign(afe_rx_encommalign[7]),
    .rx_data(afe_rx_data[7]), .rx_charisk(afe_rx_charisk[7]), .rx_disperr(afe_rx_disperr[7]),
    .rx_notintable(afe_rx_notintable[7]), .rx_reset_done(afe_rx_reset_done[7]),
    .pll_lock(afe_pll_lock[7]), .byte_aligned(afe_byte_aligned[7]), .model_phase(afe_model_phase[7])
);

ADC_TOP dut(
    .sys_clk                               (sys_clk                                      ),
    .adc_clk                               (adc_clk                                      ),
    .afe_clk                               (afe_clk                                      ),
    .jesd_clk                              (jesd_clk                                     ),
    .sys_rst_n                             (sys_rst_n                                    ),
    .adc_rst_n                             (adc_rst_n                                    ),
    .afe_rst_n                             (afe_rst_n                                    ),
    .jesd_rst_n                            (jesd_rst_n                                   ),
    .sysref_in                             (sysref_in                                    ),
    .s_axi_awaddr                          (s_axi_awaddr                                 ),
    .s_axi_awvalid                         (s_axi_awvalid                                ),
    .s_axi_awready                         (s_axi_awready                                ),
    .s_axi_wdata                           (s_axi_wdata                                  ),
    .s_axi_wstrb                           (s_axi_wstrb                                  ),
    .s_axi_wvalid                          (s_axi_wvalid                                 ),
    .s_axi_wready                          (s_axi_wready                                 ),
    .s_axi_bresp                           (s_axi_bresp                                  ),
    .s_axi_bvalid                          (s_axi_bvalid                                 ),
    .s_axi_bready                          (s_axi_bready                                 ),
    .s_axi_araddr                          (s_axi_araddr                                 ),
    .s_axi_arvalid                         (s_axi_arvalid                                ),
    .s_axi_arready                         (s_axi_arready                                ),
    .s_axi_rdata                           (s_axi_rdata                                  ),
    .s_axi_rresp                           (s_axi_rresp                                  ),
    .s_axi_rvalid                          (s_axi_rvalid                                 ),
    .s_axi_rready                          (s_axi_rready                                 ),
    .afe0_rx_data                          (afe_rx_data[0]                               ),
    .afe0_rx_charisk                       (afe_rx_charisk[0]                            ),
    .afe0_rx_disperr                       (afe_rx_disperr[0]                            ),
    .afe0_rx_notintable                    (afe_rx_notintable[0]                         ),
    .afe0_rx_reset_done                    (afe_rx_reset_done[0]                         ),
    .afe0_pll_lock                         (afe_pll_lock[0]                              ),
    .afe0_byte_aligned                     (afe_byte_aligned[0]                          ),
    .afe0_rx_encommalign                   (afe_rx_encommalign[0]                        ),
    .afe0_sync_n                           (afe_sync_n[0]                                ),
    .afe1_rx_data                          (afe_rx_data[1]                               ),
    .afe1_rx_charisk                       (afe_rx_charisk[1]                            ),
    .afe1_rx_disperr                       (afe_rx_disperr[1]                            ),
    .afe1_rx_notintable                    (afe_rx_notintable[1]                         ),
    .afe1_rx_reset_done                    (afe_rx_reset_done[1]                         ),
    .afe1_pll_lock                         (afe_pll_lock[1]                              ),
    .afe1_byte_aligned                     (afe_byte_aligned[1]                          ),
    .afe1_rx_encommalign                   (afe_rx_encommalign[1]                        ),
    .afe1_sync_n                           (afe_sync_n[1]                                ),
    .afe2_rx_data                          (afe_rx_data[2]                               ),
    .afe2_rx_charisk                       (afe_rx_charisk[2]                            ),
    .afe2_rx_disperr                       (afe_rx_disperr[2]                            ),
    .afe2_rx_notintable                    (afe_rx_notintable[2]                         ),
    .afe2_rx_reset_done                    (afe_rx_reset_done[2]                         ),
    .afe2_pll_lock                         (afe_pll_lock[2]                              ),
    .afe2_byte_aligned                     (afe_byte_aligned[2]                          ),
    .afe2_rx_encommalign                   (afe_rx_encommalign[2]                        ),
    .afe2_sync_n                           (afe_sync_n[2]                                ),
    .afe3_rx_data                          (afe_rx_data[3]                               ),
    .afe3_rx_charisk                       (afe_rx_charisk[3]                            ),
    .afe3_rx_disperr                       (afe_rx_disperr[3]                            ),
    .afe3_rx_notintable                    (afe_rx_notintable[3]                         ),
    .afe3_rx_reset_done                    (afe_rx_reset_done[3]                         ),
    .afe3_pll_lock                         (afe_pll_lock[3]                              ),
    .afe3_byte_aligned                     (afe_byte_aligned[3]                          ),
    .afe3_rx_encommalign                   (afe_rx_encommalign[3]                        ),
    .afe3_sync_n                           (afe_sync_n[3]                                ),
    .afe4_rx_data                          (afe_rx_data[4]                               ),
    .afe4_rx_charisk                       (afe_rx_charisk[4]                            ),
    .afe4_rx_disperr                       (afe_rx_disperr[4]                            ),
    .afe4_rx_notintable                    (afe_rx_notintable[4]                         ),
    .afe4_rx_reset_done                    (afe_rx_reset_done[4]                         ),
    .afe4_pll_lock                         (afe_pll_lock[4]                              ),
    .afe4_byte_aligned                     (afe_byte_aligned[4]                          ),
    .afe4_rx_encommalign                   (afe_rx_encommalign[4]                        ),
    .afe4_sync_n                           (afe_sync_n[4]                                ),
    .afe5_rx_data                          (afe_rx_data[5]                               ),
    .afe5_rx_charisk                       (afe_rx_charisk[5]                            ),
    .afe5_rx_disperr                       (afe_rx_disperr[5]                            ),
    .afe5_rx_notintable                    (afe_rx_notintable[5]                         ),
    .afe5_rx_reset_done                    (afe_rx_reset_done[5]                         ),
    .afe5_pll_lock                         (afe_pll_lock[5]                              ),
    .afe5_byte_aligned                     (afe_byte_aligned[5]                          ),
    .afe5_rx_encommalign                   (afe_rx_encommalign[5]                        ),
    .afe5_sync_n                           (afe_sync_n[5]                                ),
    .afe6_rx_data                          (afe_rx_data[6]                               ),
    .afe6_rx_charisk                       (afe_rx_charisk[6]                            ),
    .afe6_rx_disperr                       (afe_rx_disperr[6]                            ),
    .afe6_rx_notintable                    (afe_rx_notintable[6]                         ),
    .afe6_rx_reset_done                    (afe_rx_reset_done[6]                         ),
    .afe6_pll_lock                         (afe_pll_lock[6]                              ),
    .afe6_byte_aligned                     (afe_byte_aligned[6]                          ),
    .afe6_rx_encommalign                   (afe_rx_encommalign[6]                        ),
    .afe6_sync_n                           (afe_sync_n[6]                                ),
    .afe7_rx_data                          (afe_rx_data[7]                               ),
    .afe7_rx_charisk                       (afe_rx_charisk[7]                            ),
    .afe7_rx_disperr                       (afe_rx_disperr[7]                            ),
    .afe7_rx_notintable                    (afe_rx_notintable[7]                         ),
    .afe7_rx_reset_done                    (afe_rx_reset_done[7]                         ),
    .afe7_pll_lock                         (afe_pll_lock[7]                              ),
    .afe7_byte_aligned                     (afe_byte_aligned[7]                          ),
    .afe7_rx_encommalign                   (afe_rx_encommalign[7]                        ),
    .afe7_sync_n                           (afe_sync_n[7]                                ),
    .m_axis_afe0_tdata                     (m_axis_tdata[0]                              ),
    .m_axis_afe0_tkeep                     (m_axis_tkeep[0]                              ),
    .m_axis_afe0_tvalid                    (m_axis_tvalid[0]                             ),
    .m_axis_afe0_tlast                     (m_axis_tlast[0]                              ),
    .m_axis_afe0_tready                    (axis_ready[0]                                ),
    .tgc0_slope                            (tgc_slope[0]                                 ),
    .tgc0_up_dn                            (tgc_up_dn[0]                                 ),
    .tgc0_prof1                            (tgc_prof1[0]                                 ),
    .tgc0_prof2                            (tgc_prof2[0]                                 ),
    .m_axis_afe1_tdata                     (m_axis_tdata[1]                              ),
    .m_axis_afe1_tkeep                     (m_axis_tkeep[1]                              ),
    .m_axis_afe1_tvalid                    (m_axis_tvalid[1]                             ),
    .m_axis_afe1_tlast                     (m_axis_tlast[1]                              ),
    .m_axis_afe1_tready                    (axis_ready[1]                                ),
    .tgc1_slope                            (tgc_slope[1]                                 ),
    .tgc1_up_dn                            (tgc_up_dn[1]                                 ),
    .tgc1_prof1                            (tgc_prof1[1]                                 ),
    .tgc1_prof2                            (tgc_prof2[1]                                 ),
    .m_axis_afe2_tdata                     (m_axis_tdata[2]                              ),
    .m_axis_afe2_tkeep                     (m_axis_tkeep[2]                              ),
    .m_axis_afe2_tvalid                    (m_axis_tvalid[2]                             ),
    .m_axis_afe2_tlast                     (m_axis_tlast[2]                              ),
    .m_axis_afe2_tready                    (axis_ready[2]                                ),
    .tgc2_slope                            (tgc_slope[2]                                 ),
    .tgc2_up_dn                            (tgc_up_dn[2]                                 ),
    .tgc2_prof1                            (tgc_prof1[2]                                 ),
    .tgc2_prof2                            (tgc_prof2[2]                                 ),
    .m_axis_afe3_tdata                     (m_axis_tdata[3]                              ),
    .m_axis_afe3_tkeep                     (m_axis_tkeep[3]                              ),
    .m_axis_afe3_tvalid                    (m_axis_tvalid[3]                             ),
    .m_axis_afe3_tlast                     (m_axis_tlast[3]                              ),
    .m_axis_afe3_tready                    (axis_ready[3]                                ),
    .tgc3_slope                            (tgc_slope[3]                                 ),
    .tgc3_up_dn                            (tgc_up_dn[3]                                 ),
    .tgc3_prof1                            (tgc_prof1[3]                                 ),
    .tgc3_prof2                            (tgc_prof2[3]                                 ),
    .m_axis_afe4_tdata                     (m_axis_tdata[4]                              ),
    .m_axis_afe4_tkeep                     (m_axis_tkeep[4]                              ),
    .m_axis_afe4_tvalid                    (m_axis_tvalid[4]                             ),
    .m_axis_afe4_tlast                     (m_axis_tlast[4]                              ),
    .m_axis_afe4_tready                    (axis_ready[4]                                ),
    .tgc4_slope                            (tgc_slope[4]                                 ),
    .tgc4_up_dn                            (tgc_up_dn[4]                                 ),
    .tgc4_prof1                            (tgc_prof1[4]                                 ),
    .tgc4_prof2                            (tgc_prof2[4]                                 ),
    .m_axis_afe5_tdata                     (m_axis_tdata[5]                              ),
    .m_axis_afe5_tkeep                     (m_axis_tkeep[5]                              ),
    .m_axis_afe5_tvalid                    (m_axis_tvalid[5]                             ),
    .m_axis_afe5_tlast                     (m_axis_tlast[5]                              ),
    .m_axis_afe5_tready                    (axis_ready[5]                                ),
    .tgc5_slope                            (tgc_slope[5]                                 ),
    .tgc5_up_dn                            (tgc_up_dn[5]                                 ),
    .tgc5_prof1                            (tgc_prof1[5]                                 ),
    .tgc5_prof2                            (tgc_prof2[5]                                 ),
    .m_axis_afe6_tdata                     (m_axis_tdata[6]                              ),
    .m_axis_afe6_tkeep                     (m_axis_tkeep[6]                              ),
    .m_axis_afe6_tvalid                    (m_axis_tvalid[6]                             ),
    .m_axis_afe6_tlast                     (m_axis_tlast[6]                              ),
    .m_axis_afe6_tready                    (axis_ready[6]                                ),
    .tgc6_slope                            (tgc_slope[6]                                 ),
    .tgc6_up_dn                            (tgc_up_dn[6]                                 ),
    .tgc6_prof1                            (tgc_prof1[6]                                 ),
    .tgc6_prof2                            (tgc_prof2[6]                                 ),
    .m_axis_afe7_tdata                     (m_axis_tdata[7]                              ),
    .m_axis_afe7_tkeep                     (m_axis_tkeep[7]                              ),
    .m_axis_afe7_tvalid                    (m_axis_tvalid[7]                             ),
    .m_axis_afe7_tlast                     (m_axis_tlast[7]                              ),
    .m_axis_afe7_tready                    (axis_ready[7]                                ),
    .tgc7_slope                            (tgc_slope[7]                                 ),
    .tgc7_up_dn                            (tgc_up_dn[7]                                 ),
    .tgc7_prof1                            (tgc_prof1[7]                                 ),
    .tgc7_prof2                            (tgc_prof2[7]                                 )
);

integer sim_timeout_ms;
initial begin
    if($test$plusargs("DUMP_FSDB")) begin
        $fsdbDumpfile("sim.fsdb");
        $fsdbDumpvars(0, sim_top, "+all");
    end
end

initial begin
    if($value$plusargs("SIM_TIMEOUT_MS=%d", sim_timeout_ms)) begin
        #(sim_timeout_ms * 1ms);
        $display("[TIMEOUT] Simulation reached %0d ms", sim_timeout_ms);
        fail();
    end
end

`include "sim_common.vh"
`include "pattern.vh"

endmodule

`default_nettype wire
