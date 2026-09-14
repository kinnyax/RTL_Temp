`timescale 1ns / 1ps

module DEV_BUS(
    input                                   aclk                                           ,
    input                                   aresetn                                        ,

    input               [31:0]              s00_axi_awaddr                                 ,
    input               [ 2:0]              s00_axi_awprot                                 ,
    input                                   s00_axi_awvalid                                ,
    output    wire                          s00_axi_awready                                ,
    input               [31:0]              s00_axi_wdata                                  ,
    input               [ 3:0]              s00_axi_wstrb                                  ,
    input                                   s00_axi_wvalid                                 ,
    output    wire                          s00_axi_wready                                 ,
    output    wire      [ 1:0]              s00_axi_bresp                                  ,
    output    wire                          s00_axi_bvalid                                 ,
    input                                   s00_axi_bready                                 ,
    input               [31:0]              s00_axi_araddr                                 ,
    input               [ 2:0]              s00_axi_arprot                                 ,
    input                                   s00_axi_arvalid                                ,
    output    wire                          s00_axi_arready                                ,
    output    wire      [31:0]              s00_axi_rdata                                  ,
    output    wire      [ 1:0]              s00_axi_rresp                                  ,
    output    wire                          s00_axi_rvalid                                 ,
    input                                   s00_axi_rready                                 ,

    output    wire      [31:0]              m00_axi_awaddr                                 ,
    output    wire      [ 2:0]              m00_axi_awprot                                 ,
    output    wire                          m00_axi_awvalid                                ,
    input                                   m00_axi_awready                                ,
    output    wire      [31:0]              m00_axi_wdata                                  ,
    output    wire      [ 3:0]              m00_axi_wstrb                                  ,
    output    wire                          m00_axi_wvalid                                 ,
    input                                   m00_axi_wready                                 ,
    input               [ 1:0]              m00_axi_bresp                                  ,
    input                                   m00_axi_bvalid                                 ,
    output    wire                          m00_axi_bready                                 ,
    output    wire      [31:0]              m00_axi_araddr                                 ,
    output    wire      [ 2:0]              m00_axi_arprot                                 ,
    output    wire                          m00_axi_arvalid                                ,
    input                                   m00_axi_arready                                ,
    input               [31:0]              m00_axi_rdata                                  ,
    input               [ 1:0]              m00_axi_rresp                                  ,
    input                                   m00_axi_rvalid                                 ,
    output    wire                          m00_axi_rready                                 ,

    output    wire      [31:0]              m01_axi_awaddr                                 ,
    output    wire      [ 2:0]              m01_axi_awprot                                 ,
    output    wire                          m01_axi_awvalid                                ,
    input                                   m01_axi_awready                                ,
    output    wire      [31:0]              m01_axi_wdata                                  ,
    output    wire      [ 3:0]              m01_axi_wstrb                                  ,
    output    wire                          m01_axi_wvalid                                 ,
    input                                   m01_axi_wready                                 ,
    input               [ 1:0]              m01_axi_bresp                                  ,
    input                                   m01_axi_bvalid                                 ,
    output    wire                          m01_axi_bready                                 ,
    output    wire      [31:0]              m01_axi_araddr                                 ,
    output    wire      [ 2:0]              m01_axi_arprot                                 ,
    output    wire                          m01_axi_arvalid                                ,
    input                                   m01_axi_arready                                ,
    input               [31:0]              m01_axi_rdata                                  ,
    input               [ 1:0]              m01_axi_rresp                                  ,
    input                                   m01_axi_rvalid                                 ,
    output    wire                          m01_axi_rready                                 ,

    output    wire      [31:0]              m02_axi_awaddr                                 ,
    output    wire      [ 2:0]              m02_axi_awprot                                 ,
    output    wire                          m02_axi_awvalid                                ,
    input                                   m02_axi_awready                                ,
    output    wire      [31:0]              m02_axi_wdata                                  ,
    output    wire      [ 3:0]              m02_axi_wstrb                                  ,
    output    wire                          m02_axi_wvalid                                 ,
    input                                   m02_axi_wready                                 ,
    input               [ 1:0]              m02_axi_bresp                                  ,
    input                                   m02_axi_bvalid                                 ,
    output    wire                          m02_axi_bready                                 ,
    output    wire      [31:0]              m02_axi_araddr                                 ,
    output    wire      [ 2:0]              m02_axi_arprot                                 ,
    output    wire                          m02_axi_arvalid                                ,
    input                                   m02_axi_arready                                ,
    input               [31:0]              m02_axi_rdata                                  ,
    input               [ 1:0]              m02_axi_rresp                                  ,
    input                                   m02_axi_rvalid                                 ,
    output    wire                          m02_axi_rready                                 ,

    output    wire      [31:0]              m03_axi_awaddr                                 ,
    output    wire      [ 2:0]              m03_axi_awprot                                 ,
    output    wire                          m03_axi_awvalid                                ,
    input                                   m03_axi_awready                                ,
    output    wire      [31:0]              m03_axi_wdata                                  ,
    output    wire      [ 3:0]              m03_axi_wstrb                                  ,
    output    wire                          m03_axi_wvalid                                 ,
    input                                   m03_axi_wready                                 ,
    input               [ 1:0]              m03_axi_bresp                                  ,
    input                                   m03_axi_bvalid                                 ,
    output    wire                          m03_axi_bready                                 ,
    output    wire      [31:0]              m03_axi_araddr                                 ,
    output    wire      [ 2:0]              m03_axi_arprot                                 ,
    output    wire                          m03_axi_arvalid                                ,
    input                                   m03_axi_arready                                ,
    input               [31:0]              m03_axi_rdata                                  ,
    input               [ 1:0]              m03_axi_rresp                                  ,
    input                                   m03_axi_rvalid                                 ,
    output    wire                          m03_axi_rready                                 ,

    output    wire      [31:0]              m04_axi_awaddr                                 ,
    output    wire      [ 2:0]              m04_axi_awprot                                 ,
    output    wire                          m04_axi_awvalid                                ,
    input                                   m04_axi_awready                                ,
    output    wire      [31:0]              m04_axi_wdata                                  ,
    output    wire      [ 3:0]              m04_axi_wstrb                                  ,
    output    wire                          m04_axi_wvalid                                 ,
    input                                   m04_axi_wready                                 ,
    input               [ 1:0]              m04_axi_bresp                                  ,
    input                                   m04_axi_bvalid                                 ,
    output    wire                          m04_axi_bready                                 ,
    output    wire      [31:0]              m04_axi_araddr                                 ,
    output    wire      [ 2:0]              m04_axi_arprot                                 ,
    output    wire                          m04_axi_arvalid                                ,
    input                                   m04_axi_arready                                ,
    input               [31:0]              m04_axi_rdata                                  ,
    input               [ 1:0]              m04_axi_rresp                                  ,
    input                                   m04_axi_rvalid                                 ,
    output    wire                          m04_axi_rready                                 ,

    output    wire      [31:0]              m05_axi_awaddr                                 ,
    output    wire      [ 2:0]              m05_axi_awprot                                 ,
    output    wire                          m05_axi_awvalid                                ,
    input                                   m05_axi_awready                                ,
    output    wire      [31:0]              m05_axi_wdata                                  ,
    output    wire      [ 3:0]              m05_axi_wstrb                                  ,
    output    wire                          m05_axi_wvalid                                 ,
    input                                   m05_axi_wready                                 ,
    input               [ 1:0]              m05_axi_bresp                                  ,
    input                                   m05_axi_bvalid                                 ,
    output    wire                          m05_axi_bready                                 ,
    output    wire      [31:0]              m05_axi_araddr                                 ,
    output    wire      [ 2:0]              m05_axi_arprot                                 ,
    output    wire                          m05_axi_arvalid                                ,
    input                                   m05_axi_arready                                ,
    input               [31:0]              m05_axi_rdata                                  ,
    input               [ 1:0]              m05_axi_rresp                                  ,
    input                                   m05_axi_rvalid                                 ,
    output    wire                          m05_axi_rready                                 ,

    output    wire      [31:0]              m06_axi_awaddr                                 ,
    output    wire      [ 2:0]              m06_axi_awprot                                 ,
    output    wire                          m06_axi_awvalid                                ,
    input                                   m06_axi_awready                                ,
    output    wire      [31:0]              m06_axi_wdata                                  ,
    output    wire      [ 3:0]              m06_axi_wstrb                                  ,
    output    wire                          m06_axi_wvalid                                 ,
    input                                   m06_axi_wready                                 ,
    input               [ 1:0]              m06_axi_bresp                                  ,
    input                                   m06_axi_bvalid                                 ,
    output    wire                          m06_axi_bready                                 ,
    output    wire      [31:0]              m06_axi_araddr                                 ,
    output    wire      [ 2:0]              m06_axi_arprot                                 ,
    output    wire                          m06_axi_arvalid                                ,
    input                                   m06_axi_arready                                ,
    input               [31:0]              m06_axi_rdata                                  ,
    input               [ 1:0]              m06_axi_rresp                                  ,
    input                                   m06_axi_rvalid                                 ,
    output    wire                          m06_axi_rready
);

wire                    [223:0]             m_axi_awaddr                                   ;
wire                    [20:0]              m_axi_awprot                                   ;
wire                    [ 6:0]              m_axi_awvalid                                  ;
wire                    [ 6:0]              m_axi_awready                                  ;
wire                    [223:0]             m_axi_wdata                                    ;
wire                    [27:0]              m_axi_wstrb                                    ;
wire                    [ 6:0]              m_axi_wvalid                                   ;
wire                    [ 6:0]              m_axi_wready                                   ;
wire                    [13:0]              m_axi_bresp                                    ;
wire                    [ 6:0]              m_axi_bvalid                                   ;
wire                    [ 6:0]              m_axi_bready                                   ;
wire                    [223:0]             m_axi_araddr                                   ;
wire                    [20:0]              m_axi_arprot                                   ;
wire                    [ 6:0]              m_axi_arvalid                                  ;
wire                    [ 6:0]              m_axi_arready                                  ;
wire                    [223:0]             m_axi_rdata                                    ;
wire                    [13:0]              m_axi_rresp                                    ;
wire                    [ 6:0]              m_axi_rvalid                                   ;
wire                    [ 6:0]              m_axi_rready                                   ;

//////////////////////////////////////////////////
//1. Master Port Packing
//////////////////////////////////////////////////
assign m00_axi_awaddr = m_axi_awaddr[31:0];
assign m01_axi_awaddr = m_axi_awaddr[63:32];
assign m02_axi_awaddr = m_axi_awaddr[95:64];
assign m03_axi_awaddr = m_axi_awaddr[127:96];
assign m04_axi_awaddr = m_axi_awaddr[159:128];
assign m05_axi_awaddr = m_axi_awaddr[191:160];
assign m06_axi_awaddr = m_axi_awaddr[223:192];
assign m00_axi_awprot = m_axi_awprot[2:0];
assign m01_axi_awprot = m_axi_awprot[5:3];
assign m02_axi_awprot = m_axi_awprot[8:6];
assign m03_axi_awprot = m_axi_awprot[11:9];
assign m04_axi_awprot = m_axi_awprot[14:12];
assign m05_axi_awprot = m_axi_awprot[17:15];
assign m06_axi_awprot = m_axi_awprot[20:18];
assign m00_axi_awvalid = m_axi_awvalid[0];
assign m01_axi_awvalid = m_axi_awvalid[1];
assign m02_axi_awvalid = m_axi_awvalid[2];
assign m03_axi_awvalid = m_axi_awvalid[3];
assign m04_axi_awvalid = m_axi_awvalid[4];
assign m05_axi_awvalid = m_axi_awvalid[5];
assign m06_axi_awvalid = m_axi_awvalid[6];
assign m_axi_awready = {m06_axi_awready, m05_axi_awready, m04_axi_awready, m03_axi_awready, m02_axi_awready, m01_axi_awready, m00_axi_awready};
assign m00_axi_wdata = m_axi_wdata[31:0];
assign m01_axi_wdata = m_axi_wdata[63:32];
assign m02_axi_wdata = m_axi_wdata[95:64];
assign m03_axi_wdata = m_axi_wdata[127:96];
assign m04_axi_wdata = m_axi_wdata[159:128];
assign m05_axi_wdata = m_axi_wdata[191:160];
assign m06_axi_wdata = m_axi_wdata[223:192];
assign m00_axi_wstrb = m_axi_wstrb[3:0];
assign m01_axi_wstrb = m_axi_wstrb[7:4];
assign m02_axi_wstrb = m_axi_wstrb[11:8];
assign m03_axi_wstrb = m_axi_wstrb[15:12];
assign m04_axi_wstrb = m_axi_wstrb[19:16];
assign m05_axi_wstrb = m_axi_wstrb[23:20];
assign m06_axi_wstrb = m_axi_wstrb[27:24];
assign m00_axi_wvalid = m_axi_wvalid[0];
assign m01_axi_wvalid = m_axi_wvalid[1];
assign m02_axi_wvalid = m_axi_wvalid[2];
assign m03_axi_wvalid = m_axi_wvalid[3];
assign m04_axi_wvalid = m_axi_wvalid[4];
assign m05_axi_wvalid = m_axi_wvalid[5];
assign m06_axi_wvalid = m_axi_wvalid[6];
assign m_axi_wready = {m06_axi_wready, m05_axi_wready, m04_axi_wready, m03_axi_wready, m02_axi_wready, m01_axi_wready, m00_axi_wready};
assign m_axi_bresp = {m06_axi_bresp, m05_axi_bresp, m04_axi_bresp, m03_axi_bresp, m02_axi_bresp, m01_axi_bresp, m00_axi_bresp};
assign m_axi_bvalid = {m06_axi_bvalid, m05_axi_bvalid, m04_axi_bvalid, m03_axi_bvalid, m02_axi_bvalid, m01_axi_bvalid, m00_axi_bvalid};
assign m00_axi_bready = m_axi_bready[0];
assign m01_axi_bready = m_axi_bready[1];
assign m02_axi_bready = m_axi_bready[2];
assign m03_axi_bready = m_axi_bready[3];
assign m04_axi_bready = m_axi_bready[4];
assign m05_axi_bready = m_axi_bready[5];
assign m06_axi_bready = m_axi_bready[6];
assign m00_axi_araddr = m_axi_araddr[31:0];
assign m01_axi_araddr = m_axi_araddr[63:32];
assign m02_axi_araddr = m_axi_araddr[95:64];
assign m03_axi_araddr = m_axi_araddr[127:96];
assign m04_axi_araddr = m_axi_araddr[159:128];
assign m05_axi_araddr = m_axi_araddr[191:160];
assign m06_axi_araddr = m_axi_araddr[223:192];
assign m00_axi_arprot = m_axi_arprot[2:0];
assign m01_axi_arprot = m_axi_arprot[5:3];
assign m02_axi_arprot = m_axi_arprot[8:6];
assign m03_axi_arprot = m_axi_arprot[11:9];
assign m04_axi_arprot = m_axi_arprot[14:12];
assign m05_axi_arprot = m_axi_arprot[17:15];
assign m06_axi_arprot = m_axi_arprot[20:18];
assign m00_axi_arvalid = m_axi_arvalid[0];
assign m01_axi_arvalid = m_axi_arvalid[1];
assign m02_axi_arvalid = m_axi_arvalid[2];
assign m03_axi_arvalid = m_axi_arvalid[3];
assign m04_axi_arvalid = m_axi_arvalid[4];
assign m05_axi_arvalid = m_axi_arvalid[5];
assign m06_axi_arvalid = m_axi_arvalid[6];
assign m_axi_arready = {m06_axi_arready, m05_axi_arready, m04_axi_arready, m03_axi_arready, m02_axi_arready, m01_axi_arready, m00_axi_arready};
assign m_axi_rdata = {m06_axi_rdata, m05_axi_rdata, m04_axi_rdata, m03_axi_rdata, m02_axi_rdata, m01_axi_rdata, m00_axi_rdata};
assign m_axi_rresp = {m06_axi_rresp, m05_axi_rresp, m04_axi_rresp, m03_axi_rresp, m02_axi_rresp, m01_axi_rresp, m00_axi_rresp};
assign m_axi_rvalid = {m06_axi_rvalid, m05_axi_rvalid, m04_axi_rvalid, m03_axi_rvalid, m02_axi_rvalid, m01_axi_rvalid, m00_axi_rvalid};
assign m00_axi_rready = m_axi_rready[0];
assign m01_axi_rready = m_axi_rready[1];
assign m02_axi_rready = m_axi_rready[2];
assign m03_axi_rready = m_axi_rready[3];
assign m04_axi_rready = m_axi_rready[4];
assign m05_axi_rready = m_axi_rready[5];
assign m06_axi_rready = m_axi_rready[6];

//////////////////////////////////////////////////
//2. AXI Routing
//////////////////////////////////////////////////
DEV_ARB dev_arb(
    .aclk                                (aclk                                         ),
    .aresetn                             (aresetn                                      ),
    .s_axi_awaddr                        (s00_axi_awaddr                               ),
    .s_axi_awprot                        (s00_axi_awprot                               ),
    .s_axi_awvalid                       (s00_axi_awvalid                              ),
    .s_axi_awready                       (s00_axi_awready                              ),
    .s_axi_wdata                         (s00_axi_wdata                                ),
    .s_axi_wstrb                         (s00_axi_wstrb                                ),
    .s_axi_wvalid                        (s00_axi_wvalid                               ),
    .s_axi_wready                        (s00_axi_wready                               ),
    .s_axi_bresp                         (s00_axi_bresp                                ),
    .s_axi_bvalid                        (s00_axi_bvalid                               ),
    .s_axi_bready                        (s00_axi_bready                               ),
    .s_axi_araddr                        (s00_axi_araddr                               ),
    .s_axi_arprot                        (s00_axi_arprot                               ),
    .s_axi_arvalid                       (s00_axi_arvalid                              ),
    .s_axi_arready                       (s00_axi_arready                              ),
    .s_axi_rdata                         (s00_axi_rdata                                ),
    .s_axi_rresp                         (s00_axi_rresp                                ),
    .s_axi_rvalid                        (s00_axi_rvalid                               ),
    .s_axi_rready                        (s00_axi_rready                               ),
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
