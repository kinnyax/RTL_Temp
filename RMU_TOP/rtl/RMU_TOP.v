`timescale 1ns / 1ps
`default_nettype none

// Detector reset-management integration boundary.
//
// This top level contains only ports, wires and explicit instances.  The two
// Processor System Reset instances remain vendor-IP boundaries.  Per-domain
// reset release uses the project-local extraction of verified PUB level_sync.
module RMU_TOP #(
    parameter integer                       AXI_ADDR_WIDTH              = 15            ,
    parameter integer                       RST_SYNC_STAGES             = 2             ,
    parameter integer                       UDLY                        = 1
)(
    input  wire                             EXT_RST_N                                   ,
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_CLK_READY                               ,
    input  wire                             SPI_CLK                                     ,
    input  wire                             ADC_CLK                                     ,
    input  wire                             AFE_CLK                                     ,
    input  wire [7:0]                       JESD_CLK                                    ,
    input  wire                             PCIE_CLK                                    ,
    input  wire                             MIG_CLK                                     ,
    input  wire                             XDMA_USER_RST_N                             ,
    input  wire                             PCIE_LINK_UP                                ,
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
    output wire                             SYS_AXI_RST_N                              ,
    output wire                             SYS_RST_N                                  ,
    output wire                             SPI_RST_N                                  ,
    output wire                             ADC_RST_N                                  ,
    output wire                             ADC_AFE_RST_N                              ,
    output wire [7:0]                       ADC_JESD_RST_N                             ,
    output wire                             ADC_AXIS_RST_N                             ,
    output wire                             PCIE_AXIS_RST_N                            ,
    output wire                             PCIE_RST_N                                 ,
    output wire                             MIG_RST_N                                  ,
    output wire                             DMA_AXIS_RST_N                             ,
    output wire                             DMA_RST_N                                  ,
    output wire                             SPI_RST_EN                                 ,
    output wire                             ADC_RST_EN                                 ,
    output wire                             PCIE_RST_EN                                ,
    output wire                             MIG_RST_EN                                 ,
    output wire                             DMA_RST_EN
);

wire                                     device_base_rst_n                              ;
wire                                     pcie_link_up_sys                               ;

//////////////////////////////////////////////////
// 1. Official Processor System Reset boundaries
//////////////////////////////////////////////////
RMU_SYSTEM_RESET_IP system_reset_ip_inst(
    .slowest_sync_clk                    (SYS_CLK                                     ),
    .ext_reset_in                        (~EXT_RST_N                                  ),
    .aux_reset_in                        (1'b0                                        ),
    .mb_debug_sys_rst                    (1'b0                                        ),
    .dcm_locked                          (SYS_CLK_READY                               ),
    .mb_reset                            (                                            ),
    .bus_struct_reset                    (                                            ),
    .peripheral_reset                    (                                            ),
    .interconnect_aresetn                (SYS_AXI_RST_N                              ),
    .peripheral_aresetn                  (SYS_RST_N                                  )
);

RMU_DEVICE_RESET_IP device_reset_ip_inst(
    .slowest_sync_clk                    (SYS_CLK                                     ),
    .ext_reset_in                        (~EXT_RST_N                                  ),
    .aux_reset_in                        (1'b0                                        ),
    .mb_debug_sys_rst                    (1'b0                                        ),
    .dcm_locked                          (SYS_CLK_READY                               ),
    .mb_reset                            (                                            ),
    .bus_struct_reset                    (                                            ),
    .peripheral_reset                    (                                            ),
    .interconnect_aresetn                (                                            ),
    .peripheral_aresetn                  (device_base_rst_n                           )
);

//////////////////////////////////////////////////
// 2. Register interface and live status
//////////////////////////////////////////////////
RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) pcie_link_up_sync_inst(
    .clk                                 (SYS_CLK                                     ),
    .rst_n                               (SYS_RST_N                                   ),
    .in                                  (PCIE_LINK_UP                                ),
    .out                                 (pcie_link_up_sys                            )
);

RMU_REG #(
    .AXI_ADDR_WIDTH                      (AXI_ADDR_WIDTH                              ),
    .UDLY                                (UDLY                                        )
) rmu_reg_inst(
    .SYS_CLK                             (SYS_CLK                                     ),
    .SYS_RST_N                           (SYS_RST_N                                   ),
    .S_AXI_AWADDR                        (S_AXI_AWADDR                                ),
    .S_AXI_AWPROT                        (S_AXI_AWPROT                                ),
    .S_AXI_AWVALID                       (S_AXI_AWVALID                               ),
    .S_AXI_AWREADY                       (S_AXI_AWREADY                               ),
    .S_AXI_WDATA                         (S_AXI_WDATA                                 ),
    .S_AXI_WSTRB                         (S_AXI_WSTRB                                 ),
    .S_AXI_WVALID                        (S_AXI_WVALID                                ),
    .S_AXI_WREADY                        (S_AXI_WREADY                                ),
    .S_AXI_BRESP                         (S_AXI_BRESP                                 ),
    .S_AXI_BVALID                        (S_AXI_BVALID                                ),
    .S_AXI_BREADY                        (S_AXI_BREADY                                ),
    .S_AXI_ARADDR                        (S_AXI_ARADDR                                ),
    .S_AXI_ARPROT                        (S_AXI_ARPROT                                ),
    .S_AXI_ARVALID                       (S_AXI_ARVALID                               ),
    .S_AXI_ARREADY                       (S_AXI_ARREADY                               ),
    .S_AXI_RDATA                         (S_AXI_RDATA                                 ),
    .S_AXI_RRESP                         (S_AXI_RRESP                                 ),
    .S_AXI_RVALID                        (S_AXI_RVALID                                ),
    .S_AXI_RREADY                        (S_AXI_RREADY                                ),
    .PCIE_LINK_UP_SYS                    (pcie_link_up_sys                            ),
    .SPI_RST_EN                          (SPI_RST_EN                                  ),
    .ADC_RST_EN                          (ADC_RST_EN                                  ),
    .PCIE_RST_EN                         (PCIE_RST_EN                                 ),
    .MIG_RST_EN                          (MIG_RST_EN                                  ),
    .DMA_RST_EN                          (DMA_RST_EN                                  )
);

//////////////////////////////////////////////////
// 3. Asynchronous assertion and synchronous release
//////////////////////////////////////////////////
RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) spi_reset_sync_inst(
    .clk                                 (SPI_CLK                                     ),
    .rst_n                               (device_base_rst_n & SPI_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (SPI_RST_N                                   )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_reset_sync_inst(
    .clk                                 (ADC_CLK                                     ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_RST_N                                   )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_afe_reset_sync_inst(
    .clk                                 (AFE_CLK                                     ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_AFE_RST_N                               )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd0_reset_sync_inst(
    .clk                                 (JESD_CLK[0]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[0]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd1_reset_sync_inst(
    .clk                                 (JESD_CLK[1]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[1]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd2_reset_sync_inst(
    .clk                                 (JESD_CLK[2]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[2]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd3_reset_sync_inst(
    .clk                                 (JESD_CLK[3]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[3]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd4_reset_sync_inst(
    .clk                                 (JESD_CLK[4]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[4]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd5_reset_sync_inst(
    .clk                                 (JESD_CLK[5]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[5]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd6_reset_sync_inst(
    .clk                                 (JESD_CLK[6]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[6]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_jesd7_reset_sync_inst(
    .clk                                 (JESD_CLK[7]                                 ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_JESD_RST_N[7]                           )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) adc_axis_reset_sync_inst(
    .clk                                 (SYS_CLK                                     ),
    .rst_n                               (device_base_rst_n & ADC_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (ADC_AXIS_RST_N                              )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) pcie_axis_reset_sync_inst(
    .clk                                 (SYS_CLK                                     ),
    .rst_n                               (device_base_rst_n & PCIE_RST_EN &
                                          XDMA_USER_RST_N                             ),
    .in                                  (1'b1                                        ),
    .out                                 (PCIE_AXIS_RST_N                             )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) pcie_reset_sync_inst(
    .clk                                 (PCIE_CLK                                    ),
    .rst_n                               (device_base_rst_n & PCIE_RST_EN &
                                          XDMA_USER_RST_N                             ),
    .in                                  (1'b1                                        ),
    .out                                 (PCIE_RST_N                                  )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) mig_reset_sync_inst(
    .clk                                 (MIG_CLK                                     ),
    .rst_n                               (device_base_rst_n & MIG_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (MIG_RST_N                                   )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) dma_axis_reset_sync_inst(
    .clk                                 (SYS_CLK                                     ),
    .rst_n                               (device_base_rst_n & DMA_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (DMA_AXIS_RST_N                              )
);

RMU_LEVEL_SYNC #(
    .UDLY                                (UDLY                                        ),
    .DS                                  (RST_SYNC_STAGES                             ),
    .RV                                  (1'b0                                        )
) dma_reset_sync_inst(
    .clk                                 (MIG_CLK                                     ),
    .rst_n                               (device_base_rst_n & DMA_RST_EN              ),
    .in                                  (1'b1                                        ),
    .out                                 (DMA_RST_N                                   )
);

endmodule

`default_nettype wire
