`timescale 1ns / 1ps
`default_nettype none

// Integration-only flat-vector adapter for the official SmartConnect BDC.
// The BDC has one AXI4 write-only interface per DMA_CHN.  This module only
// slices/concatenates the accepted DMA_TOP flat ports; it has no state.
module DMA_SMARTCONNECT_8X1 (
    input wire aclk, input wire aresetn,
    input wire [255:0] s_axi_awaddr, input wire [63:0] s_axi_awlen,
    input wire [23:0] s_axi_awsize, input wire [15:0] s_axi_awburst,
    input wire [7:0] s_axi_awlock, input wire [31:0] s_axi_awcache,
    input wire [23:0] s_axi_awprot, input wire [31:0] s_axi_awqos,
    input wire [31:0] s_axi_awregion, input wire [7:0] s_axi_awvalid,
    output wire [7:0] s_axi_awready, input wire [4095:0] s_axi_wdata,
    input wire [511:0] s_axi_wstrb, input wire [7:0] s_axi_wlast,
    input wire [7:0] s_axi_wvalid, output wire [7:0] s_axi_wready,
    output wire [15:0] s_axi_bresp, output wire [7:0] s_axi_bvalid,
    input wire [7:0] s_axi_bready,
    output wire [31:0] m_axi_awaddr, output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize, output wire [1:0] m_axi_awburst,
    output wire m_axi_awlock, output wire [3:0] m_axi_awcache,
    output wire [2:0] m_axi_awprot, output wire [3:0] m_axi_awqos,
    output wire [3:0] m_axi_awregion, output wire m_axi_awvalid,
    input wire m_axi_awready, output wire [511:0] m_axi_wdata,
    output wire [63:0] m_axi_wstrb, output wire m_axi_wlast,
    output wire m_axi_wvalid, input wire m_axi_wready,
    input wire [1:0] m_axi_bresp, input wire m_axi_bvalid,
    output wire m_axi_bready
);
`define DMA_SC_CH(CH) \
 .S_AXI_CH``CH``_awaddr(s_axi_awaddr[CH*32 +: 32]), .S_AXI_CH``CH``_awlen(s_axi_awlen[CH*8 +: 8]), .S_AXI_CH``CH``_awsize(s_axi_awsize[CH*3 +: 3]), .S_AXI_CH``CH``_awburst(s_axi_awburst[CH*2 +: 2]), .S_AXI_CH``CH``_awlock(s_axi_awlock[CH]), .S_AXI_CH``CH``_awcache(s_axi_awcache[CH*4 +: 4]), .S_AXI_CH``CH``_awprot(s_axi_awprot[CH*3 +: 3]), .S_AXI_CH``CH``_awqos(s_axi_awqos[CH*4 +: 4]), .S_AXI_CH``CH``_awvalid(s_axi_awvalid[CH]), .S_AXI_CH``CH``_awready(s_axi_awready[CH]), .S_AXI_CH``CH``_wdata(s_axi_wdata[CH*512 +: 512]), .S_AXI_CH``CH``_wstrb(s_axi_wstrb[CH*64 +: 64]), .S_AXI_CH``CH``_wlast(s_axi_wlast[CH]), .S_AXI_CH``CH``_wvalid(s_axi_wvalid[CH]), .S_AXI_CH``CH``_wready(s_axi_wready[CH]), .S_AXI_CH``CH``_bresp(s_axi_bresp[CH*2 +: 2]), .S_AXI_CH``CH``_bvalid(s_axi_bvalid[CH]), .S_AXI_CH``CH``_bready(s_axi_bready[CH])

    // SmartConnect's standard AXI boundary has no AWREGION output. DMA_CHN
    // fixes that field to zero, so dropping it is an exact representation.
    assign m_axi_awregion = 4'd0;
    DMA_TOP_BD_wrapper u_smartconnect (
        .M_AXI_ACLK(aclk), .DMA_RST_N(aresetn),
        .M_AXI_DDR_awaddr(m_axi_awaddr), .M_AXI_DDR_awlen(m_axi_awlen),
        .M_AXI_DDR_awsize(m_axi_awsize), .M_AXI_DDR_awburst(m_axi_awburst),
        .M_AXI_DDR_awlock(m_axi_awlock), .M_AXI_DDR_awcache(m_axi_awcache),
        .M_AXI_DDR_awprot(m_axi_awprot), .M_AXI_DDR_awqos(m_axi_awqos),
        .M_AXI_DDR_awvalid(m_axi_awvalid), .M_AXI_DDR_awready(m_axi_awready),
        .M_AXI_DDR_wdata(m_axi_wdata), .M_AXI_DDR_wstrb(m_axi_wstrb),
        .M_AXI_DDR_wlast(m_axi_wlast), .M_AXI_DDR_wvalid(m_axi_wvalid),
        .M_AXI_DDR_wready(m_axi_wready), .M_AXI_DDR_bresp(m_axi_bresp),
        .M_AXI_DDR_bvalid(m_axi_bvalid), .M_AXI_DDR_bready(m_axi_bready),
        `DMA_SC_CH(0), `DMA_SC_CH(1), `DMA_SC_CH(2), `DMA_SC_CH(3),
        `DMA_SC_CH(4), `DMA_SC_CH(5), `DMA_SC_CH(6), `DMA_SC_CH(7)
    );
`undef DMA_SC_CH
endmodule

`default_nettype wire
