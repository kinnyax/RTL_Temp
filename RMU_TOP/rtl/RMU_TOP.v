`timescale 1ns / 1ps

module RMU_TOP(
    input                                   SYS_CLK                                        ,
    input                                   EXT_RST_N                                      ,
    input                                   SYS_CLK_READY                                  ,

    input               [ 7:0]              s_axi_awaddr                                   ,
    input               [ 2:0]              s_axi_awprot                                   ,
    input                                   s_axi_awvalid                                  ,
    output    wire                          s_axi_awready                                  ,

    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    wire                          s_axi_wready                                   ,

    output    wire      [ 1:0]              s_axi_bresp                                    ,
    output    wire                          s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,

    input               [ 7:0]              s_axi_araddr                                   ,
    input               [ 2:0]              s_axi_arprot                                   ,
    input                                   s_axi_arvalid                                  ,
    output    wire                          s_axi_arready                                  ,

    output    wire      [31:0]              s_axi_rdata                                    ,
    output    wire      [ 1:0]              s_axi_rresp                                    ,
    output    wire                          s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    output    wire                          SYS_RST_N                                      ,
    output    wire                          SPI_RST_N                                      ,
    output    wire                          ADC_RST_N                                      ,
    output    wire                          PCIE_RST_N                                     ,
    output    wire                          MIG_RST_N                                      ,
    output    wire                          DMA_RST_N
);

parameter                                   UDLY                     = 1                   ;

wire                    [ 4:0]              rst_enable                                     ;

//////////////////////////////////////////////////
//1. System Reset
//////////////////////////////////////////////////
RMU_SYS rmu_sys(
    .SYS_CLK                             (SYS_CLK                                      ),
    .EXT_RST_N                           (EXT_RST_N                                    ),
    .SYS_CLK_READY                       (SYS_CLK_READY                                ),
    .SYS_RST_N                           (SYS_RST_N                                    )
);

//////////////////////////////////////////////////
//2. Register Interface
//////////////////////////////////////////////////
RMU_REG rmu_reg(
    .sys_clk                             (SYS_CLK                                      ),
    .sys_rst_n                           (SYS_RST_N                                    ),
    .s_axi_awaddr                        (s_axi_awaddr                                 ),
    .s_axi_awprot                        (s_axi_awprot                                 ),
    .s_axi_awvalid                       (s_axi_awvalid                                ),
    .s_axi_awready                       (s_axi_awready                                ),
    .s_axi_wdata                         (s_axi_wdata                                  ),
    .s_axi_wstrb                         (s_axi_wstrb                                  ),
    .s_axi_wvalid                        (s_axi_wvalid                                 ),
    .s_axi_wready                        (s_axi_wready                                 ),
    .s_axi_bresp                         (s_axi_bresp                                  ),
    .s_axi_bvalid                        (s_axi_bvalid                                 ),
    .s_axi_bready                        (s_axi_bready                                 ),
    .s_axi_araddr                        (s_axi_araddr                                 ),
    .s_axi_arprot                        (s_axi_arprot                                 ),
    .s_axi_arvalid                       (s_axi_arvalid                                ),
    .s_axi_arready                       (s_axi_arready                                ),
    .s_axi_rdata                         (s_axi_rdata                                  ),
    .s_axi_rresp                         (s_axi_rresp                                  ),
    .s_axi_rvalid                        (s_axi_rvalid                                 ),
    .s_axi_rready                        (s_axi_rready                                 ),
    .rst_enable                          (rst_enable                                   )
);

//////////////////////////////////////////////////
//3. Device Reset Qualification
//////////////////////////////////////////////////
RMU_CTL rmu_ctl(
    .SYS_RST_N                           (SYS_RST_N                                    ),
    .rst_enable                          (rst_enable                                   ),
    .SPI_RST_N                           (SPI_RST_N                                    ),
    .ADC_RST_N                           (ADC_RST_N                                    ),
    .PCIE_RST_N                          (PCIE_RST_N                                   ),
    .MIG_RST_N                           (MIG_RST_N                                    ),
    .DMA_RST_N                           (DMA_RST_N                                    )
);

endmodule
