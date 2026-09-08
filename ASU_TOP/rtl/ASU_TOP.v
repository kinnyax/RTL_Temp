`timescale 1ns / 1ps

module ASU_TOP(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   SPI_SCK                                        ,
    input                                   SPI_CS                                         ,
    input                                   SPI_MOSI                                       ,
    output    wire                          SPI_MISO                                       ,

    output    wire      [31:0]              m_axi_awaddr                                   ,
    output    wire      [ 2:0]              m_axi_awprot                                   ,
    output    wire                          m_axi_awvalid                                  ,
    input                                   m_axi_awready                                  ,
    output    wire      [31:0]              m_axi_wdata                                    ,
    output    wire      [ 3:0]              m_axi_wstrb                                    ,
    output    wire                          m_axi_wvalid                                   ,
    input                                   m_axi_wready                                   ,
    input               [ 1:0]              m_axi_bresp                                    ,
    input                                   m_axi_bvalid                                   ,
    output    wire                          m_axi_bready                                   ,

    output    wire      [31:0]              m_axi_araddr                                   ,
    output    wire      [ 2:0]              m_axi_arprot                                   ,
    output    wire                          m_axi_arvalid                                  ,
    input                                   m_axi_arready                                  ,
    input               [31:0]              m_axi_rdata                                    ,
    input               [ 1:0]              m_axi_rresp                                    ,
    input                                   m_axi_rvalid                                   ,
    output    wire                          m_axi_rready
);

parameter                                   UDLY                     = 1                   ;

wire                                        rxd_req                                        ;
wire                                        rxd_write                                      ;
wire                    [31:0]              rxd_addr                                       ;
wire                    [31:0]              rxd_wdata                                      ;
wire                                        txd_rdy                                        ;
wire                                        txd_timeout                                    ;
wire                    [31:0]              txd_rdata                                      ;

//////////////////////////////////////////////////
//1. Module Connections
//////////////////////////////////////////////////
ASU_RXD asu_rxd(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .SPI_SCK                             (SPI_SCK                                      ),
    .SPI_CS                              (SPI_CS                                       ),
    .SPI_MOSI                            (SPI_MOSI                                     ),
    .SPI_MISO                            (SPI_MISO                                     ),
    .rxd_req                             (rxd_req                                      ),
    .rxd_write                           (rxd_write                                    ),
    .rxd_addr                            (rxd_addr                                     ),
    .rxd_wdata                           (rxd_wdata                                    ),
    .txd_rdy                             (txd_rdy                                      ),
    .txd_timeout                         (txd_timeout                                  ),
    .txd_rdata                           (txd_rdata                                    )
);

ASU_TXD asu_txd(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .rxd_req                             (rxd_req                                      ),
    .rxd_write                           (rxd_write                                    ),
    .rxd_addr                            (rxd_addr                                     ),
    .rxd_wdata                           (rxd_wdata                                    ),
    .txd_rdy                             (txd_rdy                                      ),
    .txd_timeout                         (txd_timeout                                  ),
    .txd_rdata                           (txd_rdata                                    ),
    .m_axi_awaddr                        (m_axi_awaddr                                 ),
    .m_axi_awprot                        (m_axi_awprot                                 ),
    .m_axi_awvalid                       (m_axi_awvalid                                ),
    .m_axi_awready                       (m_axi_awready                                ),
    .m_axi_wdata                         (m_axi_wdata                                  ),
    .m_axi_wstrb                         (m_axi_wstrb                                  ),
    .m_axi_wvalid                        (m_axi_wvalid                                 ),
    .m_axi_wready                        (m_axi_wready                                 ),
    .m_axi_bresp                         (m_axi_bresp                                  ),
    .m_axi_bvalid                        (m_axi_bvalid                                 ),
    .m_axi_bready                        (m_axi_bready                                 ),
    .m_axi_araddr                        (m_axi_araddr                                 ),
    .m_axi_arprot                        (m_axi_arprot                                 ),
    .m_axi_arvalid                       (m_axi_arvalid                                ),
    .m_axi_arready                       (m_axi_arready                                ),
    .m_axi_rdata                         (m_axi_rdata                                  ),
    .m_axi_rresp                         (m_axi_rresp                                  ),
    .m_axi_rvalid                        (m_axi_rvalid                                 ),
    .m_axi_rready                        (m_axi_rready                                 )
);

endmodule
