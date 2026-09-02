`timescale 1ns / 1ps

module RMU_CTL(
    input                                   SYS_RST_N                                      ,
    input               [ 4:0]              rst_enable                                     ,

    output    wire                          SPI_RST_N                                      ,
    output    wire                          ADC_RST_N                                      ,
    output    wire                          PCIE_RST_N                                     ,
    output    wire                          MIG_RST_N                                      ,
    output    wire                          DMA_RST_N
);

parameter                                   UDLY                     = 1                   ;

wire                                        spi_rst_en                                     ;
wire                                        adc_rst_en                                     ;
wire                                        pcie_rst_en                                    ;
wire                                        mig_rst_en                                     ;
wire                                        dma_rst_en                                     ;

//////////////////////////////////////////////////
//1. Device Reset Qualification
//////////////////////////////////////////////////
assign spi_rst_en  = rst_enable[0];
assign adc_rst_en  = rst_enable[1];
assign pcie_rst_en = rst_enable[2];
assign mig_rst_en  = rst_enable[3];
assign dma_rst_en  = rst_enable[4];

assign SPI_RST_N  = SYS_RST_N & spi_rst_en;
assign ADC_RST_N  = SYS_RST_N & adc_rst_en;
assign PCIE_RST_N = SYS_RST_N & pcie_rst_en;
assign MIG_RST_N  = SYS_RST_N & mig_rst_en;
assign DMA_RST_N  = SYS_RST_N & dma_rst_en;

endmodule
