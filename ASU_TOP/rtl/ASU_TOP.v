`timescale 1ns / 1ps
`default_nettype none

// Wiring-only top for the ASU SPI-to-AXI4-Lite bridge.
module ASU_TOP
(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             ASU_SPI_CS_N                                ,
    input  wire                             ASU_SPI_SCK                                 ,
    input  wire                             ASU_SPI_MOSI                                ,
    output wire                             ASU_SPI_MISO                                ,
    output wire [31:0]                      M_AXI_AWADDR                                ,
    output wire [2:0]                       M_AXI_AWPROT                                ,
    output wire                             M_AXI_AWVALID                               ,
    input  wire                             M_AXI_AWREADY                               ,
    output wire [31:0]                      M_AXI_WDATA                                 ,
    output wire [3:0]                       M_AXI_WSTRB                                 ,
    output wire                             M_AXI_WVALID                                ,
    input  wire                             M_AXI_WREADY                                ,
    input  wire [1:0]                       M_AXI_BRESP                                 ,
    input  wire                             M_AXI_BVALID                                ,
    output wire                             M_AXI_BREADY                                ,
    output wire [31:0]                      M_AXI_ARADDR                                ,
    output wire [2:0]                       M_AXI_ARPROT                                ,
    output wire                             M_AXI_ARVALID                               ,
    input  wire                             M_AXI_ARREADY                               ,
    input  wire [31:0]                      M_AXI_RDATA                                 ,
    input  wire [1:0]                       M_AXI_RRESP                                 ,
    input  wire                             M_AXI_RVALID                                ,
    output wire                             M_AXI_RREADY
);

parameter integer                           UDLY                        = 1              ;

wire                                        frt_req_vld                                  ;
wire [127:0]                                frt_req_frame                                ;
wire                                        ctl_req_rdy                                  ;
wire                                        ctl_rsp_vld                                  ;
wire                                        ctl_req_err                                  ;
wire [1:0]                                  ctl_axi_resp                                 ;
wire [31:0]                                 ctl_rdata                                    ;
wire                                        frt_rsp_rdy                                  ;
wire                                        frt_rsp_consumed                             ;
wire                                        crc_start                                    ;
wire [111:0]                                crc_data                                     ;
wire                                        crc_busy                                     ;
wire                                        crc_done                                     ;
wire [15:0]                                 crc_value                                    ;

ASU_FRT asu_frt
(
    .SYS_CLK                              (SYS_CLK                                      ),
    .SYS_RST_N                            (SYS_RST_N                                    ),
    .ASU_SPI_CS_N                         (ASU_SPI_CS_N                                 ),
    .ASU_SPI_SCK                          (ASU_SPI_SCK                                  ),
    .ASU_SPI_MOSI                         (ASU_SPI_MOSI                                 ),
    .ASU_SPI_MISO                         (ASU_SPI_MISO                                 ),
    .FRT_REQ_VLD                          (frt_req_vld                                  ),
    .FRT_REQ_FRAME                        (frt_req_frame                                ),
    .CTL_REQ_RDY                          (ctl_req_rdy                                  ),
    .CTL_RSP_VLD                          (ctl_rsp_vld                                  ),
    .CTL_REQ_ERR                          (ctl_req_err                                  ),
    .CTL_AXI_RESP                         (ctl_axi_resp                                 ),
    .CTL_RDATA                            (ctl_rdata                                    ),
    .FRT_RSP_RDY                          (frt_rsp_rdy                                  ),
    .FRT_RSP_CONSUMED                     (frt_rsp_consumed                             ),
    .CRC_START                            (crc_start                                    ),
    .CRC_DATA                             (crc_data                                     ),
    .CRC_BUSY                             (crc_busy                                     ),
    .CRC_DONE                             (crc_done                                     ),
    .CRC_VALUE                            (crc_value                                    )
);

ASU_CRC asu_crc
(
    .SYS_CLK                              (SYS_CLK                                      ),
    .SYS_RST_N                            (SYS_RST_N                                    ),
    .CRC_START                            (crc_start                                    ),
    .CRC_DATA                             (crc_data                                     ),
    .CRC_BUSY                             (crc_busy                                     ),
    .CRC_DONE                             (crc_done                                     ),
    .CRC_VALUE                            (crc_value                                    )
);

ASU_CTL asu_ctl
(
    .SYS_CLK                              (SYS_CLK                                      ),
    .SYS_RST_N                            (SYS_RST_N                                    ),
    .FRT_REQ_VLD                          (frt_req_vld                                  ),
    .FRT_REQ_FRAME                        (frt_req_frame                                ),
    .CTL_REQ_RDY                          (ctl_req_rdy                                  ),
    .CTL_RSP_VLD                          (ctl_rsp_vld                                  ),
    .CTL_REQ_ERR                          (ctl_req_err                                  ),
    .CTL_AXI_RESP                         (ctl_axi_resp                                 ),
    .CTL_RDATA                            (ctl_rdata                                    ),
    .FRT_RSP_RDY                          (frt_rsp_rdy                                  ),
    .FRT_RSP_CONSUMED                     (frt_rsp_consumed                             ),
    .M_AXI_AWADDR                         (M_AXI_AWADDR                                 ),
    .M_AXI_AWPROT                         (M_AXI_AWPROT                                 ),
    .M_AXI_AWVALID                        (M_AXI_AWVALID                                ),
    .M_AXI_AWREADY                        (M_AXI_AWREADY                                ),
    .M_AXI_WDATA                          (M_AXI_WDATA                                  ),
    .M_AXI_WSTRB                          (M_AXI_WSTRB                                  ),
    .M_AXI_WVALID                         (M_AXI_WVALID                                 ),
    .M_AXI_WREADY                         (M_AXI_WREADY                                 ),
    .M_AXI_BRESP                          (M_AXI_BRESP                                  ),
    .M_AXI_BVALID                         (M_AXI_BVALID                                 ),
    .M_AXI_BREADY                         (M_AXI_BREADY                                 ),
    .M_AXI_ARADDR                         (M_AXI_ARADDR                                 ),
    .M_AXI_ARPROT                         (M_AXI_ARPROT                                 ),
    .M_AXI_ARVALID                        (M_AXI_ARVALID                                ),
    .M_AXI_ARREADY                        (M_AXI_ARREADY                                ),
    .M_AXI_RDATA                          (M_AXI_RDATA                                  ),
    .M_AXI_RRESP                          (M_AXI_RRESP                                  ),
    .M_AXI_RVALID                         (M_AXI_RVALID                                 ),
    .M_AXI_RREADY                         (M_AXI_RREADY                                 )
);

endmodule

`default_nettype wire
