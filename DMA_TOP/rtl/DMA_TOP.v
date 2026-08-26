`timescale 1ns / 1ps

module DMA_TOP #(
    parameter integer                       AXI_ADDR_WIDTH              = 15            ,
    parameter integer                       UDLY                        = 1
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 SYS_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME SYS_CLK, FREQ_HZ 200000000, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET SYS_RST_N:DMA_AXIS_RST_N" *)
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             DMA_AXIS_RST_N                              ,
    input  wire                             M_AXI_ACLK                                  ,
    input  wire                             DMA_RST_N                                   ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_AWADDR                               ,
    input  wire [2:0]                       S_AXI_AWPROT                               ,
    input  wire                             S_AXI_AWVALID                              ,
    output wire                             S_AXI_AWREADY                              ,
    input  wire [31:0]                      S_AXI_WDATA                                ,
    input  wire [3:0]                       S_AXI_WSTRB                                ,
    input  wire                             S_AXI_WVALID                               ,
    output wire                             S_AXI_WREADY                               ,
    output wire [1:0]                       S_AXI_BRESP                                ,
    output wire                             S_AXI_BVALID                               ,
    input  wire                             S_AXI_BREADY                               ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_ARADDR                               ,
    input  wire [2:0]                       S_AXI_ARPROT                               ,
    input  wire                             S_AXI_ARVALID                              ,
    output wire                             S_AXI_ARREADY                              ,
    output wire [31:0]                      S_AXI_RDATA                                ,
    output wire [1:0]                       S_AXI_RRESP                                ,
    output wire                             S_AXI_RVALID                               ,
    input  wire                             S_AXI_RREADY                               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    FIFO_S_TREADY              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    FIFO_S_ACCEPT_EN           ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    FIFO_ARESETN               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [4095:0] FIFO_M_TDATA               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [511:0]  FIFO_M_TKEEP               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    FIFO_M_TLAST               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    FIFO_M_TVALID              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    FIFO_M_TREADY              ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [79:0]   FIFO_RD_DATA_COUNT         ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [255:0]  CH_AXI_AWADDR              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [63:0]   CH_AXI_AWLEN               ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [23:0]   CH_AXI_AWSIZE              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [15:0]   CH_AXI_AWBURST             ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    CH_AXI_AWLOCK              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0]   CH_AXI_AWCACHE             ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [23:0]   CH_AXI_AWPROT              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0]   CH_AXI_AWQOS               ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    CH_AXI_AWVALID             ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    CH_AXI_AWREADY             ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [4095:0] CH_AXI_WDATA               ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [511:0]  CH_AXI_WSTRB               ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    CH_AXI_WLAST               ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    CH_AXI_WVALID              ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    CH_AXI_WREADY              ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [15:0]   CH_AXI_BRESP               ,
    (* X_INTERFACE_IGNORE = "true" *) input  wire [7:0]    CH_AXI_BVALID              ,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0]    CH_AXI_BREADY              ,
    output wire                             DMA_IRQ
);

wire [255:0]                             ch_addr_shadow                                ;
wire [255:0]                             ch_num_shadow                                 ;
wire [71:0]                              ch_ctl_shadow                                 ;
wire [7:0]                               ch_en_sys                                     ;
wire [7:0]                               fifo_clr_sys                                  ;
wire [7:0]                               ch_en_m                                       ;
wire [255:0]                             ch_addr_active                                ;
wire [255:0]                             ch_num_active                                 ;
wire [71:0]                              ch_ctl_active                                 ;
wire [7:0]                               half_event_m                                  ;
wire [7:0]                               full_event_m                                  ;
wire [7:0]                               error_event_m                                 ;
wire [7:0]                               stop_event_m                                  ;
wire [7:0]                               half_event_sys                                ;
wire [7:0]                               full_event_sys                                ;
wire [7:0]                               error_event_sys                               ;
wire [7:0]                               stop_event_sys                                ;
wire [7:0]                               ch_busy_m                                     ;
wire [7:0]                               axi_busy_m                                    ;
wire [7:0]                               ch_busy_sys                                   ;
wire [7:0]                               axi_busy_sys                                  ;
wire [7:0]                               fifo_empty_sys                                ;
wire [7:0]                               fifo_ready_sys                                ;

wire [4095:0]                            fifo_tdata_m                                  ;
wire [511:0]                             fifo_tkeep_m                                  ;
wire [7:0]                               fifo_tlast_m                                  ;
wire [7:0]                               fifo_tvalid_m                                 ;
wire [7:0]                               fifo_tready_m                                 ;
wire [79:0]                              fifo_data_count_m                             ;

wire [255:0]                             channel_awaddr                                ;
wire [63:0]                              channel_awlen                                 ;
wire [23:0]                              channel_awsize                                ;
wire [15:0]                              channel_awburst                               ;
wire [7:0]                               channel_awlock                                ;
wire [31:0]                              channel_awcache                               ;
wire [23:0]                              channel_awprot                                ;
wire [31:0]                              channel_awqos                                 ;
wire [31:0]                              channel_awregion                              ;
wire [7:0]                               channel_awvalid                               ;
wire [7:0]                               channel_awready                               ;
wire [4095:0]                            channel_wdata                                 ;
wire [511:0]                             channel_wstrb                                 ;
wire [7:0]                               channel_wlast                                 ;
wire [7:0]                               channel_wvalid                                ;
wire [7:0]                               channel_wready                                ;
wire [15:0]                              channel_bresp                                 ;
wire [7:0]                               channel_bvalid                                ;
wire [7:0]                               channel_bready                                ;

DMA_REG #(
    .AXI_ADDR_WIDTH                      (AXI_ADDR_WIDTH                 ),
    .UDLY                                (UDLY                           )
) dma_reg_inst (
    .SYS_CLK                             (SYS_CLK                        ),
    .SYS_RST_N                           (SYS_RST_N                      ),
    .DMA_AXIS_RST_N                      (DMA_AXIS_RST_N                 ),
    .S_AXI_AWADDR                        (S_AXI_AWADDR                   ),
    .S_AXI_AWPROT                        (S_AXI_AWPROT                   ),
    .S_AXI_AWVALID                       (S_AXI_AWVALID                  ),
    .S_AXI_AWREADY                       (S_AXI_AWREADY                  ),
    .S_AXI_WDATA                         (S_AXI_WDATA                    ),
    .S_AXI_WSTRB                         (S_AXI_WSTRB                    ),
    .S_AXI_WVALID                        (S_AXI_WVALID                   ),
    .S_AXI_WREADY                        (S_AXI_WREADY                   ),
    .S_AXI_BRESP                         (S_AXI_BRESP                    ),
    .S_AXI_BVALID                        (S_AXI_BVALID                   ),
    .S_AXI_BREADY                        (S_AXI_BREADY                   ),
    .S_AXI_ARADDR                        (S_AXI_ARADDR                   ),
    .S_AXI_ARPROT                        (S_AXI_ARPROT                   ),
    .S_AXI_ARVALID                       (S_AXI_ARVALID                  ),
    .S_AXI_ARREADY                       (S_AXI_ARREADY                  ),
    .S_AXI_RDATA                         (S_AXI_RDATA                    ),
    .S_AXI_RRESP                         (S_AXI_RRESP                    ),
    .S_AXI_RVALID                        (S_AXI_RVALID                   ),
    .S_AXI_RREADY                        (S_AXI_RREADY                   ),
    .ch_busy_sys                         (ch_busy_sys                    ),
    .fifo_empty_sys                      (fifo_empty_sys                 ),
    .fifo_ready_sys                      (fifo_ready_sys                 ),
    .axi_busy_sys                        (axi_busy_sys                   ),
    .half_event_sys                      (half_event_sys                 ),
    .full_event_sys                      (full_event_sys                 ),
    .error_event_sys                     (error_event_sys                ),
    .stop_event_sys                      (stop_event_sys                 ),
    .ch_addr_shadow                      (ch_addr_shadow                 ),
    .ch_num_shadow                       (ch_num_shadow                  ),
    .ch_ctl_shadow                       (ch_ctl_shadow                  ),
    .ch_en_sys                           (ch_en_sys                      ),
    .fifo_clr_sys                        (fifo_clr_sys                   ),
    .axis_ready_sys                      (FIFO_S_ACCEPT_EN               ),
    .DMA_IRQ                             (DMA_IRQ                        )
);

DMA_SYNC #(
    .UDLY                                (UDLY                           )
) dma_sync_inst (
    .SYS_CLK                             (SYS_CLK                        ),
    .DMA_AXIS_RST_N                      (DMA_AXIS_RST_N                 ),
    .M_AXI_ACLK                          (M_AXI_ACLK                     ),
    .DMA_RST_N                           (DMA_RST_N                      ),
    .ch_en_sys                           (ch_en_sys                      ),
    .ch_addr_shadow                      (ch_addr_shadow                 ),
    .ch_num_shadow                       (ch_num_shadow                  ),
    .ch_ctl_shadow                       (ch_ctl_shadow                  ),
    .half_event_m                        (half_event_m                   ),
    .full_event_m                        (full_event_m                   ),
    .error_event_m                       (error_event_m                  ),
    .stop_event_m                        (stop_event_m                   ),
    .ch_busy_m                           (ch_busy_m                      ),
    .axi_busy_m                          (axi_busy_m                     ),
    .fifo_empty_m                        (~fifo_tvalid_m                 ),
    .ch_en_m                             (ch_en_m                        ),
    .ch_addr_active                      (ch_addr_active                 ),
    .ch_num_active                       (ch_num_active                  ),
    .ch_ctl_active                       (ch_ctl_active                  ),
    .half_event_sys                      (half_event_sys                 ),
    .full_event_sys                      (full_event_sys                 ),
    .error_event_sys                     (error_event_sys                ),
    .stop_event_sys                      (stop_event_sys                 ),
    .ch_busy_sys                         (ch_busy_sys                    ),
    .axi_busy_sys                        (axi_busy_sys                   ),
    .fifo_empty_sys                      (fifo_empty_sys                 )
);

assign fifo_ready_sys    = FIFO_S_TREADY;
assign FIFO_ARESETN     = {8{DMA_AXIS_RST_N}} & ~fifo_clr_sys;
assign fifo_tdata_m     = FIFO_M_TDATA;
assign fifo_tkeep_m     = FIFO_M_TKEEP;
assign fifo_tlast_m     = FIFO_M_TLAST;
assign fifo_tvalid_m    = FIFO_M_TVALID;
assign FIFO_M_TREADY    = fifo_tready_m;
assign fifo_data_count_m = FIFO_RD_DATA_COUNT;

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel0_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[0]                     ),
    .cfg_addr                            (ch_addr_active[31:0]           ),
    .cfg_num                             (ch_num_active[31:0]            ),
    .cfg_loop                            (ch_ctl_active[1]               ),
    .cfg_wrap                            (ch_ctl_active[2]               ),
    .cfg_burst_len                       (ch_ctl_active[4:3]             ),
    .cfg_data_width                      (ch_ctl_active[8:6]             ),
    .fifo_data_count                     (fifo_data_count_m[9:0]         ),
    .fifo_tdata                          (fifo_tdata_m[511:0]            ),
    .fifo_tkeep                          (fifo_tkeep_m[63:0]             ),
    .fifo_tlast                          (fifo_tlast_m[0]                ),
    .fifo_tvalid                         (fifo_tvalid_m[0]               ),
    .fifo_tready                         (fifo_tready_m[0]               ),
    .M_AXI_AWADDR                        (channel_awaddr[31:0]           ),
    .M_AXI_AWLEN                         (channel_awlen[7:0]             ),
    .M_AXI_AWSIZE                        (channel_awsize[2:0]            ),
    .M_AXI_AWBURST                       (channel_awburst[1:0]           ),
    .M_AXI_AWLOCK                        (channel_awlock[0]              ),
    .M_AXI_AWCACHE                       (channel_awcache[3:0]           ),
    .M_AXI_AWPROT                        (channel_awprot[2:0]            ),
    .M_AXI_AWQOS                         (channel_awqos[3:0]             ),
    .M_AXI_AWREGION                      (channel_awregion[3:0]          ),
    .M_AXI_AWVALID                       (channel_awvalid[0]             ),
    .M_AXI_AWREADY                       (channel_awready[0]             ),
    .M_AXI_WDATA                         (channel_wdata[511:0]           ),
    .M_AXI_WSTRB                         (channel_wstrb[63:0]            ),
    .M_AXI_WLAST                         (channel_wlast[0]               ),
    .M_AXI_WVALID                        (channel_wvalid[0]              ),
    .M_AXI_WREADY                        (channel_wready[0]              ),
    .M_AXI_BRESP                         (channel_bresp[1:0]             ),
    .M_AXI_BVALID                        (channel_bvalid[0]              ),
    .M_AXI_BREADY                        (channel_bready[0]              ),
    .half_event                          (half_event_m[0]                ),
    .full_event                          (full_event_m[0]                ),
    .error_event                         (error_event_m[0]               ),
    .stop_event                          (stop_event_m[0]                ),
    .ch_busy                             (ch_busy_m[0]                   ),
    .axi_busy                            (axi_busy_m[0]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel1_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[1]                     ),
    .cfg_addr                            (ch_addr_active[63:32]          ),
    .cfg_num                             (ch_num_active[63:32]           ),
    .cfg_loop                            (ch_ctl_active[10]              ),
    .cfg_wrap                            (ch_ctl_active[11]              ),
    .cfg_burst_len                       (ch_ctl_active[13:12]           ),
    .cfg_data_width                      (ch_ctl_active[17:15]           ),
    .fifo_data_count                     (fifo_data_count_m[19:10]       ),
    .fifo_tdata                          (fifo_tdata_m[1023:512]         ),
    .fifo_tkeep                          (fifo_tkeep_m[127:64]           ),
    .fifo_tlast                          (fifo_tlast_m[1]                ),
    .fifo_tvalid                         (fifo_tvalid_m[1]               ),
    .fifo_tready                         (fifo_tready_m[1]               ),
    .M_AXI_AWADDR                        (channel_awaddr[63:32]          ),
    .M_AXI_AWLEN                         (channel_awlen[15:8]            ),
    .M_AXI_AWSIZE                        (channel_awsize[5:3]            ),
    .M_AXI_AWBURST                       (channel_awburst[3:2]           ),
    .M_AXI_AWLOCK                        (channel_awlock[1]              ),
    .M_AXI_AWCACHE                       (channel_awcache[7:4]           ),
    .M_AXI_AWPROT                        (channel_awprot[5:3]            ),
    .M_AXI_AWQOS                         (channel_awqos[7:4]             ),
    .M_AXI_AWREGION                      (channel_awregion[7:4]          ),
    .M_AXI_AWVALID                       (channel_awvalid[1]             ),
    .M_AXI_AWREADY                       (channel_awready[1]             ),
    .M_AXI_WDATA                         (channel_wdata[1023:512]        ),
    .M_AXI_WSTRB                         (channel_wstrb[127:64]          ),
    .M_AXI_WLAST                         (channel_wlast[1]               ),
    .M_AXI_WVALID                        (channel_wvalid[1]              ),
    .M_AXI_WREADY                        (channel_wready[1]              ),
    .M_AXI_BRESP                         (channel_bresp[3:2]             ),
    .M_AXI_BVALID                        (channel_bvalid[1]              ),
    .M_AXI_BREADY                        (channel_bready[1]              ),
    .half_event                          (half_event_m[1]                ),
    .full_event                          (full_event_m[1]                ),
    .error_event                         (error_event_m[1]               ),
    .stop_event                          (stop_event_m[1]                ),
    .ch_busy                             (ch_busy_m[1]                   ),
    .axi_busy                            (axi_busy_m[1]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel2_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[2]                     ),
    .cfg_addr                            (ch_addr_active[95:64]          ),
    .cfg_num                             (ch_num_active[95:64]           ),
    .cfg_loop                            (ch_ctl_active[19]              ),
    .cfg_wrap                            (ch_ctl_active[20]              ),
    .cfg_burst_len                       (ch_ctl_active[22:21]           ),
    .cfg_data_width                      (ch_ctl_active[26:24]           ),
    .fifo_data_count                     (fifo_data_count_m[29:20]       ),
    .fifo_tdata                          (fifo_tdata_m[1535:1024]        ),
    .fifo_tkeep                          (fifo_tkeep_m[191:128]          ),
    .fifo_tlast                          (fifo_tlast_m[2]                ),
    .fifo_tvalid                         (fifo_tvalid_m[2]               ),
    .fifo_tready                         (fifo_tready_m[2]               ),
    .M_AXI_AWADDR                        (channel_awaddr[95:64]          ),
    .M_AXI_AWLEN                         (channel_awlen[23:16]           ),
    .M_AXI_AWSIZE                        (channel_awsize[8:6]            ),
    .M_AXI_AWBURST                       (channel_awburst[5:4]           ),
    .M_AXI_AWLOCK                        (channel_awlock[2]              ),
    .M_AXI_AWCACHE                       (channel_awcache[11:8]          ),
    .M_AXI_AWPROT                        (channel_awprot[8:6]            ),
    .M_AXI_AWQOS                         (channel_awqos[11:8]            ),
    .M_AXI_AWREGION                      (channel_awregion[11:8]         ),
    .M_AXI_AWVALID                       (channel_awvalid[2]             ),
    .M_AXI_AWREADY                       (channel_awready[2]             ),
    .M_AXI_WDATA                         (channel_wdata[1535:1024]       ),
    .M_AXI_WSTRB                         (channel_wstrb[191:128]         ),
    .M_AXI_WLAST                         (channel_wlast[2]               ),
    .M_AXI_WVALID                        (channel_wvalid[2]              ),
    .M_AXI_WREADY                        (channel_wready[2]              ),
    .M_AXI_BRESP                         (channel_bresp[5:4]             ),
    .M_AXI_BVALID                        (channel_bvalid[2]              ),
    .M_AXI_BREADY                        (channel_bready[2]              ),
    .half_event                          (half_event_m[2]                ),
    .full_event                          (full_event_m[2]                ),
    .error_event                         (error_event_m[2]               ),
    .stop_event                          (stop_event_m[2]                ),
    .ch_busy                             (ch_busy_m[2]                   ),
    .axi_busy                            (axi_busy_m[2]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel3_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[3]                     ),
    .cfg_addr                            (ch_addr_active[127:96]         ),
    .cfg_num                             (ch_num_active[127:96]          ),
    .cfg_loop                            (ch_ctl_active[28]              ),
    .cfg_wrap                            (ch_ctl_active[29]              ),
    .cfg_burst_len                       (ch_ctl_active[31:30]           ),
    .cfg_data_width                      (ch_ctl_active[35:33]           ),
    .fifo_data_count                     (fifo_data_count_m[39:30]       ),
    .fifo_tdata                          (fifo_tdata_m[2047:1536]        ),
    .fifo_tkeep                          (fifo_tkeep_m[255:192]          ),
    .fifo_tlast                          (fifo_tlast_m[3]                ),
    .fifo_tvalid                         (fifo_tvalid_m[3]               ),
    .fifo_tready                         (fifo_tready_m[3]               ),
    .M_AXI_AWADDR                        (channel_awaddr[127:96]         ),
    .M_AXI_AWLEN                         (channel_awlen[31:24]           ),
    .M_AXI_AWSIZE                        (channel_awsize[11:9]           ),
    .M_AXI_AWBURST                       (channel_awburst[7:6]           ),
    .M_AXI_AWLOCK                        (channel_awlock[3]              ),
    .M_AXI_AWCACHE                       (channel_awcache[15:12]         ),
    .M_AXI_AWPROT                        (channel_awprot[11:9]           ),
    .M_AXI_AWQOS                         (channel_awqos[15:12]           ),
    .M_AXI_AWREGION                      (channel_awregion[15:12]        ),
    .M_AXI_AWVALID                       (channel_awvalid[3]             ),
    .M_AXI_AWREADY                       (channel_awready[3]             ),
    .M_AXI_WDATA                         (channel_wdata[2047:1536]       ),
    .M_AXI_WSTRB                         (channel_wstrb[255:192]         ),
    .M_AXI_WLAST                         (channel_wlast[3]               ),
    .M_AXI_WVALID                        (channel_wvalid[3]              ),
    .M_AXI_WREADY                        (channel_wready[3]              ),
    .M_AXI_BRESP                         (channel_bresp[7:6]             ),
    .M_AXI_BVALID                        (channel_bvalid[3]              ),
    .M_AXI_BREADY                        (channel_bready[3]              ),
    .half_event                          (half_event_m[3]                ),
    .full_event                          (full_event_m[3]                ),
    .error_event                         (error_event_m[3]               ),
    .stop_event                          (stop_event_m[3]                ),
    .ch_busy                             (ch_busy_m[3]                   ),
    .axi_busy                            (axi_busy_m[3]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel4_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[4]                     ),
    .cfg_addr                            (ch_addr_active[159:128]        ),
    .cfg_num                             (ch_num_active[159:128]         ),
    .cfg_loop                            (ch_ctl_active[37]              ),
    .cfg_wrap                            (ch_ctl_active[38]              ),
    .cfg_burst_len                       (ch_ctl_active[40:39]           ),
    .cfg_data_width                      (ch_ctl_active[44:42]           ),
    .fifo_data_count                     (fifo_data_count_m[49:40]       ),
    .fifo_tdata                          (fifo_tdata_m[2559:2048]        ),
    .fifo_tkeep                          (fifo_tkeep_m[319:256]          ),
    .fifo_tlast                          (fifo_tlast_m[4]                ),
    .fifo_tvalid                         (fifo_tvalid_m[4]               ),
    .fifo_tready                         (fifo_tready_m[4]               ),
    .M_AXI_AWADDR                        (channel_awaddr[159:128]        ),
    .M_AXI_AWLEN                         (channel_awlen[39:32]           ),
    .M_AXI_AWSIZE                        (channel_awsize[14:12]          ),
    .M_AXI_AWBURST                       (channel_awburst[9:8]           ),
    .M_AXI_AWLOCK                        (channel_awlock[4]              ),
    .M_AXI_AWCACHE                       (channel_awcache[19:16]         ),
    .M_AXI_AWPROT                        (channel_awprot[14:12]          ),
    .M_AXI_AWQOS                         (channel_awqos[19:16]           ),
    .M_AXI_AWREGION                      (channel_awregion[19:16]        ),
    .M_AXI_AWVALID                       (channel_awvalid[4]             ),
    .M_AXI_AWREADY                       (channel_awready[4]             ),
    .M_AXI_WDATA                         (channel_wdata[2559:2048]       ),
    .M_AXI_WSTRB                         (channel_wstrb[319:256]         ),
    .M_AXI_WLAST                         (channel_wlast[4]               ),
    .M_AXI_WVALID                        (channel_wvalid[4]              ),
    .M_AXI_WREADY                        (channel_wready[4]              ),
    .M_AXI_BRESP                         (channel_bresp[9:8]             ),
    .M_AXI_BVALID                        (channel_bvalid[4]              ),
    .M_AXI_BREADY                        (channel_bready[4]              ),
    .half_event                          (half_event_m[4]                ),
    .full_event                          (full_event_m[4]                ),
    .error_event                         (error_event_m[4]               ),
    .stop_event                          (stop_event_m[4]                ),
    .ch_busy                             (ch_busy_m[4]                   ),
    .axi_busy                            (axi_busy_m[4]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel5_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[5]                     ),
    .cfg_addr                            (ch_addr_active[191:160]        ),
    .cfg_num                             (ch_num_active[191:160]         ),
    .cfg_loop                            (ch_ctl_active[46]              ),
    .cfg_wrap                            (ch_ctl_active[47]              ),
    .cfg_burst_len                       (ch_ctl_active[49:48]           ),
    .cfg_data_width                      (ch_ctl_active[53:51]           ),
    .fifo_data_count                     (fifo_data_count_m[59:50]       ),
    .fifo_tdata                          (fifo_tdata_m[3071:2560]        ),
    .fifo_tkeep                          (fifo_tkeep_m[383:320]          ),
    .fifo_tlast                          (fifo_tlast_m[5]                ),
    .fifo_tvalid                         (fifo_tvalid_m[5]               ),
    .fifo_tready                         (fifo_tready_m[5]               ),
    .M_AXI_AWADDR                        (channel_awaddr[191:160]        ),
    .M_AXI_AWLEN                         (channel_awlen[47:40]           ),
    .M_AXI_AWSIZE                        (channel_awsize[17:15]          ),
    .M_AXI_AWBURST                       (channel_awburst[11:10]         ),
    .M_AXI_AWLOCK                        (channel_awlock[5]              ),
    .M_AXI_AWCACHE                       (channel_awcache[23:20]         ),
    .M_AXI_AWPROT                        (channel_awprot[17:15]          ),
    .M_AXI_AWQOS                         (channel_awqos[23:20]           ),
    .M_AXI_AWREGION                      (channel_awregion[23:20]        ),
    .M_AXI_AWVALID                       (channel_awvalid[5]             ),
    .M_AXI_AWREADY                       (channel_awready[5]             ),
    .M_AXI_WDATA                         (channel_wdata[3071:2560]       ),
    .M_AXI_WSTRB                         (channel_wstrb[383:320]         ),
    .M_AXI_WLAST                         (channel_wlast[5]               ),
    .M_AXI_WVALID                        (channel_wvalid[5]              ),
    .M_AXI_WREADY                        (channel_wready[5]              ),
    .M_AXI_BRESP                         (channel_bresp[11:10]           ),
    .M_AXI_BVALID                        (channel_bvalid[5]              ),
    .M_AXI_BREADY                        (channel_bready[5]              ),
    .half_event                          (half_event_m[5]                ),
    .full_event                          (full_event_m[5]                ),
    .error_event                         (error_event_m[5]               ),
    .stop_event                          (stop_event_m[5]                ),
    .ch_busy                             (ch_busy_m[5]                   ),
    .axi_busy                            (axi_busy_m[5]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel6_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[6]                     ),
    .cfg_addr                            (ch_addr_active[223:192]        ),
    .cfg_num                             (ch_num_active[223:192]         ),
    .cfg_loop                            (ch_ctl_active[55]              ),
    .cfg_wrap                            (ch_ctl_active[56]              ),
    .cfg_burst_len                       (ch_ctl_active[58:57]           ),
    .cfg_data_width                      (ch_ctl_active[62:60]           ),
    .fifo_data_count                     (fifo_data_count_m[69:60]       ),
    .fifo_tdata                          (fifo_tdata_m[3583:3072]        ),
    .fifo_tkeep                          (fifo_tkeep_m[447:384]          ),
    .fifo_tlast                          (fifo_tlast_m[6]                ),
    .fifo_tvalid                         (fifo_tvalid_m[6]               ),
    .fifo_tready                         (fifo_tready_m[6]               ),
    .M_AXI_AWADDR                        (channel_awaddr[223:192]        ),
    .M_AXI_AWLEN                         (channel_awlen[55:48]           ),
    .M_AXI_AWSIZE                        (channel_awsize[20:18]          ),
    .M_AXI_AWBURST                       (channel_awburst[13:12]         ),
    .M_AXI_AWLOCK                        (channel_awlock[6]              ),
    .M_AXI_AWCACHE                       (channel_awcache[27:24]         ),
    .M_AXI_AWPROT                        (channel_awprot[20:18]          ),
    .M_AXI_AWQOS                         (channel_awqos[27:24]           ),
    .M_AXI_AWREGION                      (channel_awregion[27:24]        ),
    .M_AXI_AWVALID                       (channel_awvalid[6]             ),
    .M_AXI_AWREADY                       (channel_awready[6]             ),
    .M_AXI_WDATA                         (channel_wdata[3583:3072]       ),
    .M_AXI_WSTRB                         (channel_wstrb[447:384]         ),
    .M_AXI_WLAST                         (channel_wlast[6]               ),
    .M_AXI_WVALID                        (channel_wvalid[6]              ),
    .M_AXI_WREADY                        (channel_wready[6]              ),
    .M_AXI_BRESP                         (channel_bresp[13:12]           ),
    .M_AXI_BVALID                        (channel_bvalid[6]              ),
    .M_AXI_BREADY                        (channel_bready[6]              ),
    .half_event                          (half_event_m[6]                ),
    .full_event                          (full_event_m[6]                ),
    .error_event                         (error_event_m[6]               ),
    .stop_event                          (stop_event_m[6]                ),
    .ch_busy                             (ch_busy_m[6]                   ),
    .axi_busy                            (axi_busy_m[6]                  )
);

DMA_CHN #(
    .UDLY                                (UDLY                           )
) dma_channel7_inst (
    .clk                                 (M_AXI_ACLK                     ),
    .rst_n                               (DMA_RST_N                      ),
    .ch_en                               (ch_en_m[7]                     ),
    .cfg_addr                            (ch_addr_active[255:224]        ),
    .cfg_num                             (ch_num_active[255:224]         ),
    .cfg_loop                            (ch_ctl_active[64]              ),
    .cfg_wrap                            (ch_ctl_active[65]              ),
    .cfg_burst_len                       (ch_ctl_active[67:66]           ),
    .cfg_data_width                      (ch_ctl_active[71:69]           ),
    .fifo_data_count                     (fifo_data_count_m[79:70]       ),
    .fifo_tdata                          (fifo_tdata_m[4095:3584]        ),
    .fifo_tkeep                          (fifo_tkeep_m[511:448]          ),
    .fifo_tlast                          (fifo_tlast_m[7]                ),
    .fifo_tvalid                         (fifo_tvalid_m[7]               ),
    .fifo_tready                         (fifo_tready_m[7]               ),
    .M_AXI_AWADDR                        (channel_awaddr[255:224]        ),
    .M_AXI_AWLEN                         (channel_awlen[63:56]           ),
    .M_AXI_AWSIZE                        (channel_awsize[23:21]          ),
    .M_AXI_AWBURST                       (channel_awburst[15:14]         ),
    .M_AXI_AWLOCK                        (channel_awlock[7]              ),
    .M_AXI_AWCACHE                       (channel_awcache[31:28]         ),
    .M_AXI_AWPROT                        (channel_awprot[23:21]          ),
    .M_AXI_AWQOS                         (channel_awqos[31:28]           ),
    .M_AXI_AWREGION                      (channel_awregion[31:28]        ),
    .M_AXI_AWVALID                       (channel_awvalid[7]             ),
    .M_AXI_AWREADY                       (channel_awready[7]             ),
    .M_AXI_WDATA                         (channel_wdata[4095:3584]       ),
    .M_AXI_WSTRB                         (channel_wstrb[511:448]         ),
    .M_AXI_WLAST                         (channel_wlast[7]               ),
    .M_AXI_WVALID                        (channel_wvalid[7]              ),
    .M_AXI_WREADY                        (channel_wready[7]              ),
    .M_AXI_BRESP                         (channel_bresp[15:14]           ),
    .M_AXI_BVALID                        (channel_bvalid[7]              ),
    .M_AXI_BREADY                        (channel_bready[7]              ),
    .half_event                          (half_event_m[7]                ),
    .full_event                          (full_event_m[7]                ),
    .error_event                         (error_event_m[7]               ),
    .stop_event                          (stop_event_m[7]                ),
    .ch_busy                             (ch_busy_m[7]                   ),
    .axi_busy                            (axi_busy_m[7]                  )
);

assign CH_AXI_AWADDR    = channel_awaddr;
assign CH_AXI_AWLEN     = channel_awlen;
assign CH_AXI_AWSIZE    = channel_awsize;
assign CH_AXI_AWBURST   = channel_awburst;
assign CH_AXI_AWLOCK    = channel_awlock;
assign CH_AXI_AWCACHE   = channel_awcache;
assign CH_AXI_AWPROT    = channel_awprot;
assign CH_AXI_AWQOS     = channel_awqos;
assign CH_AXI_AWVALID   = channel_awvalid;
assign channel_awready  = CH_AXI_AWREADY;
assign CH_AXI_WDATA     = channel_wdata;
assign CH_AXI_WSTRB     = channel_wstrb;
assign CH_AXI_WLAST     = channel_wlast;
assign CH_AXI_WVALID    = channel_wvalid;
assign channel_wready   = CH_AXI_WREADY;
assign channel_bresp    = CH_AXI_BRESP;
assign channel_bvalid   = CH_AXI_BVALID;
assign CH_AXI_BREADY    = channel_bready;

endmodule
