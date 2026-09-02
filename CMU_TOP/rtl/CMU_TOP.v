`timescale 1ns / 1ps

module CMU_TOP(
    input                                   EXT_CLK_P                                      ,
    input                                   EXT_CLK_N                                      ,
    input                                   SYS_RST_N                                      ,
    output    wire                          SYS_CLK                                        ,
    output    wire                          SYS_CLK_READY                                  ,

    output    wire                          SPI_CLK                                        ,
    output    wire                          ADC_CLK                                        ,
    output    wire                          DMA_CLK                                        ,
    output    wire                          JESD_DRP_CLK                                   ,

    input                                   AFE_CLK_P                                      ,
    input                                   AFE_CLK_N                                      ,
    output    wire                          AFE_CLK                                        ,

    input               [ 3:0]              JESD_REFCLK_P                                  ,
    input               [ 3:0]              JESD_REFCLK_N                                  ,
    output    wire      [ 3:0]              JESD_REFCLK                                    ,

    input                                   PCIE_REFCLK_P                                  ,
    input                                   PCIE_REFCLK_N                                  ,
    output    wire                          PCIE_REFCLK_GT                                 ,
    output    wire                          PCIE_REFCLK_DIV2                               ,

    input               [14:0]              S_AXI_AWADDR                                   ,
    input                                   S_AXI_AWVALID                                  ,
    output    wire                          S_AXI_AWREADY                                  ,

    input               [31:0]              S_AXI_WDATA                                    ,
    input               [ 3:0]              S_AXI_WSTRB                                    ,
    input                                   S_AXI_WVALID                                   ,
    output    wire                          S_AXI_WREADY                                   ,

    output    wire      [ 1:0]              S_AXI_BRESP                                    ,
    output    wire                          S_AXI_BVALID                                   ,
    input                                   S_AXI_BREADY                                   ,

    input               [14:0]              S_AXI_ARADDR                                   ,
    input                                   S_AXI_ARVALID                                  ,
    output    wire                          S_AXI_ARREADY                                  ,

    output    wire      [31:0]              S_AXI_RDATA                                    ,
    output    wire      [ 1:0]              S_AXI_RRESP                                    ,
    output    wire                          S_AXI_RVALID                                   ,
    input                                   S_AXI_RREADY
);

parameter                                   UDLY                     = 1                   ;

wire                                        mmcm_locked                                    ;
wire                    [31:0]              cmu_spi                                        ;
wire                    [31:0]              cmu_adc                                        ;
wire                    [31:0]              cmu_dma                                        ;

//////////////////////////////////////////////////
//1. Clock Management Hierarchy
//////////////////////////////////////////////////
CMU_SYS cmu_sys(
    .ext_clk_p                           (EXT_CLK_P                                    ),
    .ext_clk_n                           (EXT_CLK_N                                    ),
    .sys_clk                             (SYS_CLK                                      ),
    .sys_clk_ready                       (SYS_CLK_READY                                ),
    .mmcm_locked                         (mmcm_locked                                  ),
    .jesd_drp_clk                        (JESD_DRP_CLK                                 )
);

CMU_REG cmu_reg(
    .sys_clk                             (SYS_CLK                                      ),
    .sys_rst_n                           (SYS_RST_N                                    ),
    .s_axi_awaddr                        (S_AXI_AWADDR                                 ),
    .s_axi_awprot                        (3'd0                                         ),
    .s_axi_awvalid                       (S_AXI_AWVALID                                ),
    .s_axi_awready                       (S_AXI_AWREADY                                ),
    .s_axi_wdata                         (S_AXI_WDATA                                  ),
    .s_axi_wstrb                         (S_AXI_WSTRB                                  ),
    .s_axi_wvalid                        (S_AXI_WVALID                                 ),
    .s_axi_wready                        (S_AXI_WREADY                                 ),
    .s_axi_bresp                         (S_AXI_BRESP                                  ),
    .s_axi_bvalid                        (S_AXI_BVALID                                 ),
    .s_axi_bready                        (S_AXI_BREADY                                 ),
    .s_axi_araddr                        (S_AXI_ARADDR                                 ),
    .s_axi_arprot                        (3'd0                                         ),
    .s_axi_arvalid                       (S_AXI_ARVALID                                ),
    .s_axi_arready                       (S_AXI_ARREADY                                ),
    .s_axi_rdata                         (S_AXI_RDATA                                  ),
    .s_axi_rresp                         (S_AXI_RRESP                                  ),
    .s_axi_rvalid                        (S_AXI_RVALID                                 ),
    .s_axi_rready                        (S_AXI_RREADY                                 ),
    .mmcm_locked                         (mmcm_locked                                  ),
    .sys_clk_ready                       (SYS_CLK_READY                                ),
    .cmu_spi                             (cmu_spi                                      ),
    .cmu_adc                             (cmu_adc                                      ),
    .cmu_dma                             (cmu_dma                                      )
);

CMU_CTL cmu_ctl(
    .sys_clk                             (SYS_CLK                                      ),
    .sys_rst_n                           (SYS_RST_N                                    ),
    .sys_clk_ready                       (SYS_CLK_READY                                ),
    .cmu_spi                             (cmu_spi                                      ),
    .cmu_adc                             (cmu_adc                                      ),
    .cmu_dma                             (cmu_dma                                      ),
    .spi_clk                             (SPI_CLK                                      ),
    .adc_clk                             (ADC_CLK                                      ),
    .dma_clk                             (DMA_CLK                                      ),
    .afe_clk_p                           (AFE_CLK_P                                    ),
    .afe_clk_n                           (AFE_CLK_N                                    ),
    .afe_clk                             (AFE_CLK                                      ),
    .jesd_refclk_p                       (JESD_REFCLK_P                                ),
    .jesd_refclk_n                       (JESD_REFCLK_N                                ),
    .jesd_refclk                         (JESD_REFCLK                                  ),
    .pcie_refclk_p                       (PCIE_REFCLK_P                                ),
    .pcie_refclk_n                       (PCIE_REFCLK_N                                ),
    .pcie_refclk_gt                      (PCIE_REFCLK_GT                               ),
    .pcie_refclk_div2                    (PCIE_REFCLK_DIV2                             )
);

endmodule
