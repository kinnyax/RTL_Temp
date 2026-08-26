`timescale 1ns / 1ps
`default_nettype none

// RMU always-on AXI4-Lite register bank.
//
// The implementation is intentionally divided into the three mandatory
// regions used by Detector register banks:
//   1. AXI4-Lite Protocol
//   2. Address Decode
//   3. Register Encode
//
// AW and W are captured independently.  A write is committed only after both
// captured channels are present, so either arrival order is legal.
// Structural reference only:
//   D:\Codex\RTL\AXI\DMA\DMA_REG.v
//   SHA256 60D69697CB7A850E364D77E7192B88006F7CAD3A9D2D88B57F9F6E18A42BA540
module RMU_REG #(
    parameter integer                       AXI_ADDR_WIDTH              = 15            ,
    parameter integer                       UDLY                        = 1
)(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_AWADDR                               ,
    input  wire [2:0]                       S_AXI_AWPROT                               ,
    input  wire                             S_AXI_AWVALID                              ,
    output wire                             S_AXI_AWREADY                              ,
    input  wire [31:0]                      S_AXI_WDATA                                ,
    input  wire [3:0]                       S_AXI_WSTRB                                ,
    input  wire                             S_AXI_WVALID                               ,
    output wire                             S_AXI_WREADY                               ,
    output wire [1:0]                       S_AXI_BRESP                                ,
    output reg                              S_AXI_BVALID                               ,
    input  wire                             S_AXI_BREADY                               ,
    input  wire [AXI_ADDR_WIDTH-1:0]        S_AXI_ARADDR                               ,
    input  wire [2:0]                       S_AXI_ARPROT                               ,
    input  wire                             S_AXI_ARVALID                              ,
    output wire                             S_AXI_ARREADY                              ,
    output reg  [31:0]                      S_AXI_RDATA                                ,
    output wire [1:0]                       S_AXI_RRESP                                ,
    output reg                              S_AXI_RVALID                               ,
    input  wire                             S_AXI_RREADY                               ,
    input  wire                             PCIE_LINK_UP_SYS                           ,
    output wire                             SPI_RST_EN                                 ,
    output wire                             ADC_RST_EN                                 ,
    output wire                             PCIE_RST_EN                                ,
    output wire                             MIG_RST_EN                                 ,
    output wire                             DMA_RST_EN
);

localparam [1:0]                         AXI_OKAY                    = 2'b00              ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_ASU_RST               = 15'h0000           ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_SPI_RST               = 15'h0004           ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_ADC_RST               = 15'h0008           ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_PCIE_RST              = 15'h000C           ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_MIG_RST               = 15'h0010           ;
localparam [AXI_ADDR_WIDTH-1:0]          ADDR_DMA_RST               = 15'h0014           ;

reg  [AXI_ADDR_WIDTH-1:0]                axi_awaddr_r                                    ;
reg  [AXI_ADDR_WIDTH-1:0]                axi_araddr_r                                    ;
reg  [31:0]                              axi_wdata_r                                     ;
reg  [3:0]                               axi_wstrb_r                                     ;
reg                                      aw_pending                                      ;
reg                                      w_pending                                       ;
reg                                      ar_pending                                      ;
reg                                      spi_rst_en_r                                    ;
reg                                      adc_rst_en_r                                    ;
reg                                      pcie_rst_en_r                                   ;
reg                                      mig_rst_en_r                                    ;
reg                                      dma_rst_en_r                                    ;

wire                                     aw_accept                                       ;
wire                                     w_accept                                        ;
wire                                     ar_accept                                       ;
wire                                     wr_access                                       ;
wire                                     rd_access                                       ;
wire                                     full_word_write                                 ;
wire                                     aligned_write                                   ;
wire                                     aligned_read                                    ;
wire                                     reg_0000h_rd                                    ;
wire                                     reg_0004h_wr                                    ;
wire                                     reg_0004h_rd                                    ;
wire                                     reg_0008h_wr                                    ;
wire                                     reg_0008h_rd                                    ;
wire                                     reg_000ch_wr                                    ;
wire                                     reg_000ch_rd                                    ;
wire                                     reg_0010h_wr                                    ;
wire                                     reg_0010h_rd                                    ;
wire                                     reg_0014h_wr                                    ;
wire                                     reg_0014h_rd                                    ;
wire [31:0]                              reg_0000h                                       ;
wire [31:0]                              reg_0004h                                       ;
wire [31:0]                              reg_0008h                                       ;
wire [31:0]                              reg_000ch                                       ;
wire [31:0]                              reg_0010h                                       ;
wire [31:0]                              reg_0014h                                       ;
wire [31:0]                              io_rdata                                        ;

//////////////////////////////////////////////////
// 1. AXI4-Lite Protocol
//////////////////////////////////////////////////
assign S_AXI_AWREADY = SYS_RST_N & ~aw_pending & ~S_AXI_BVALID;
assign S_AXI_WREADY  = SYS_RST_N & ~w_pending  & ~S_AXI_BVALID;
assign S_AXI_ARREADY = SYS_RST_N & ~ar_pending & ~S_AXI_RVALID;
assign S_AXI_BRESP   = AXI_OKAY;
assign S_AXI_RRESP   = AXI_OKAY;

assign aw_accept = S_AXI_AWREADY & S_AXI_AWVALID;
assign w_accept  = S_AXI_WREADY  & S_AXI_WVALID;
assign ar_accept = S_AXI_ARREADY & S_AXI_ARVALID;

// Latched channels are consumed together on the cycle after the later
// channel arrives.  This prevents same-cycle nonblocking-assignment ordering
// from selecting stale address or data.
assign wr_access = aw_pending & w_pending & ~S_AXI_BVALID;
assign rd_access = ar_pending & ~S_AXI_RVALID;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        axi_awaddr_r <= #UDLY {AXI_ADDR_WIDTH{1'b0}};
    else if(aw_accept)
        axi_awaddr_r <= #UDLY S_AXI_AWADDR;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        aw_pending <= #UDLY 1'b0;
    else if(wr_access)
        aw_pending <= #UDLY 1'b0;
    else if(aw_accept)
        aw_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        axi_wdata_r <= #UDLY 32'h0000_0000;
        axi_wstrb_r <= #UDLY 4'b0000;
    end else if(w_accept) begin
        axi_wdata_r <= #UDLY S_AXI_WDATA;
        axi_wstrb_r <= #UDLY S_AXI_WSTRB;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        w_pending <= #UDLY 1'b0;
    else if(wr_access)
        w_pending <= #UDLY 1'b0;
    else if(w_accept)
        w_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(S_AXI_BVALID & S_AXI_BREADY)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(wr_access)
        S_AXI_BVALID <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        axi_araddr_r <= #UDLY {AXI_ADDR_WIDTH{1'b0}};
    else if(ar_accept)
        axi_araddr_r <= #UDLY S_AXI_ARADDR;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        ar_pending <= #UDLY 1'b0;
    else if(rd_access)
        ar_pending <= #UDLY 1'b0;
    else if(ar_accept)
        ar_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_RVALID <= #UDLY 1'b0;
    else if(S_AXI_RVALID & S_AXI_RREADY)
        S_AXI_RVALID <= #UDLY 1'b0;
    else if(rd_access)
        S_AXI_RVALID <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_RDATA <= #UDLY 32'h0000_0000;
    else if(rd_access)
        S_AXI_RDATA <= #UDLY io_rdata;
end

//////////////////////////////////////////////////
// 2. Address Decode
//////////////////////////////////////////////////
// Detector control registers accept complete, aligned 32-bit writes only.
// Unsupported writes still complete with OKAY but have no register effect.
assign full_word_write = (axi_wstrb_r == 4'b1111);
assign aligned_write   = (axi_awaddr_r[1:0] == 2'b00);
assign aligned_read    = (axi_araddr_r[1:0] == 2'b00);

assign reg_0000h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_ASU_RST);
assign reg_0004h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_SPI_RST);
assign reg_0004h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_SPI_RST);
assign reg_0008h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_ADC_RST);
assign reg_0008h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_ADC_RST);
assign reg_000ch_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_PCIE_RST);
assign reg_000ch_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_PCIE_RST);
assign reg_0010h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_MIG_RST);
assign reg_0010h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_MIG_RST);
assign reg_0014h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_DMA_RST);
assign reg_0014h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_DMA_RST);

//////////////////////////////////////////////////
// 3. Register Encode
//////////////////////////////////////////////////
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        spi_rst_en_r <= #UDLY 1'b0;
    else if(reg_0004h_wr)
        spi_rst_en_r <= #UDLY axi_wdata_r[0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        adc_rst_en_r <= #UDLY 1'b0;
    else if(reg_0008h_wr)
        adc_rst_en_r <= #UDLY axi_wdata_r[0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        pcie_rst_en_r <= #UDLY 1'b0;
    else if(reg_000ch_wr)
        pcie_rst_en_r <= #UDLY axi_wdata_r[0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        mig_rst_en_r <= #UDLY 1'b0;
    else if(reg_0010h_wr)
        mig_rst_en_r <= #UDLY axi_wdata_r[0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        dma_rst_en_r <= #UDLY 1'b0;
    else if(reg_0014h_wr)
        dma_rst_en_r <= #UDLY axi_wdata_r[0];
end

assign reg_0000h = 32'h0000_0001;
assign reg_0004h = {31'h0000_0000, spi_rst_en_r};
assign reg_0008h = {31'h0000_0000, adc_rst_en_r};
assign reg_000ch = {29'h0000_0000, PCIE_LINK_UP_SYS, 1'b0, pcie_rst_en_r};
assign reg_0010h = {31'h0000_0000, mig_rst_en_r};
assign reg_0014h = {31'h0000_0000, dma_rst_en_r};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h) |
                  ({32{reg_000ch_rd}} & reg_000ch) |
                  ({32{reg_0010h_rd}} & reg_0010h) |
                  ({32{reg_0014h_rd}} & reg_0014h);

assign SPI_RST_EN  = spi_rst_en_r;
assign ADC_RST_EN  = adc_rst_en_r;
assign PCIE_RST_EN = pcie_rst_en_r;
assign MIG_RST_EN  = mig_rst_en_r;
assign DMA_RST_EN  = dma_rst_en_r;

endmodule

`default_nettype wire
