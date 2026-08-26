`timescale 1ns / 1ps
`default_nettype none

// Stable SPI component boundary used by DETECTOR_TOP.
module SPI_TOP_WRAPPER #(
    parameter integer       AXI_ADDR_WIDTH = 15,
    parameter integer       UDLY           = 1
)(
    input   wire                            SYS_CLK,
    input   wire                            SYS_RST_N,
    input   wire                            SPI_RST_EN,
    input   wire                            SPI_CLK,
    input   wire                            SPI_RST_N,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input   wire        [2:0]               S_AXI_AWPROT,
    input   wire                            S_AXI_AWVALID,
    output  wire                            S_AXI_AWREADY,
    input   wire        [31:0]              S_AXI_WDATA,
    input   wire        [3:0]               S_AXI_WSTRB,
    input   wire                            S_AXI_WVALID,
    output  wire                            S_AXI_WREADY,
    output  wire        [1:0]               S_AXI_BRESP,
    output  wire                            S_AXI_BVALID,
    input   wire                            S_AXI_BREADY,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input   wire        [2:0]               S_AXI_ARPROT,
    input   wire                            S_AXI_ARVALID,
    output  wire                            S_AXI_ARREADY,
    output  wire        [31:0]              S_AXI_RDATA,
    output  wire        [1:0]               S_AXI_RRESP,
    output  wire                            S_AXI_RVALID,
    input   wire                            S_AXI_RREADY,
    input   wire                            spi_miso_i,
    output  wire                            spi_mosi_o,
    output  wire                            spi_sck_o,
    output  wire        [3:0]               spi_nss_code_o,
    output  wire                            busy_o
);

SPI_TOP #(
    .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
    .UDLY                   (UDLY)
) spi_top (
    .SYS_CLK                (SYS_CLK),
    .SYS_RST_N              (SYS_RST_N),
    .SPI_RST_EN             (SPI_RST_EN),
    .SPI_CLK                (SPI_CLK),
    .SPI_RST_N              (SPI_RST_N),
    .S_AXI_AWADDR           (S_AXI_AWADDR),
    .S_AXI_AWPROT           (S_AXI_AWPROT),
    .S_AXI_AWVALID          (S_AXI_AWVALID),
    .S_AXI_AWREADY          (S_AXI_AWREADY),
    .S_AXI_WDATA            (S_AXI_WDATA),
    .S_AXI_WSTRB            (S_AXI_WSTRB),
    .S_AXI_WVALID           (S_AXI_WVALID),
    .S_AXI_WREADY           (S_AXI_WREADY),
    .S_AXI_BRESP            (S_AXI_BRESP),
    .S_AXI_BVALID           (S_AXI_BVALID),
    .S_AXI_BREADY           (S_AXI_BREADY),
    .S_AXI_ARADDR           (S_AXI_ARADDR),
    .S_AXI_ARPROT           (S_AXI_ARPROT),
    .S_AXI_ARVALID          (S_AXI_ARVALID),
    .S_AXI_ARREADY          (S_AXI_ARREADY),
    .S_AXI_RDATA            (S_AXI_RDATA),
    .S_AXI_RRESP            (S_AXI_RRESP),
    .S_AXI_RVALID           (S_AXI_RVALID),
    .S_AXI_RREADY           (S_AXI_RREADY),
    .spi_miso_i             (spi_miso_i),
    .spi_mosi_o             (spi_mosi_o),
    .spi_sck_o              (spi_sck_o),
    .spi_nss_code_o         (spi_nss_code_o),
    .busy_o                 (busy_o)
);

endmodule

`default_nettype wire
