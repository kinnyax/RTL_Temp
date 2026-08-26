`timescale 1ns / 1ps
`default_nettype none

// AXI4-Lite register bank for the CMU always-on SYS_CLK domain.
// Only full 32-bit writes are accepted. All responses are AXI OKAY.
module CMU_REG(
    input   wire                            SYS_CLK                     ,
    input   wire                            SYS_RST_N                   ,
    input   wire                            SYS_CLK_READY               ,
    input   wire                            MMCM_LOCKED                 ,
    input   wire        [14:0]              S_AXI_AWADDR                ,
    input   wire                            S_AXI_AWVALID               ,
    output  wire                            S_AXI_AWREADY               ,
    input   wire        [31:0]              S_AXI_WDATA                 ,
    input   wire        [3:0]               S_AXI_WSTRB                 ,
    input   wire                            S_AXI_WVALID                ,
    output  wire                            S_AXI_WREADY                ,
    output  reg         [1:0]               S_AXI_BRESP                 ,
    output  reg                             S_AXI_BVALID                ,
    input   wire                            S_AXI_BREADY                ,
    input   wire        [14:0]              S_AXI_ARADDR                ,
    input   wire                            S_AXI_ARVALID               ,
    output  wire                            S_AXI_ARREADY               ,
    output  reg         [31:0]              S_AXI_RDATA                 ,
    output  reg         [1:0]               S_AXI_RRESP                 ,
    output  reg                             S_AXI_RVALID                ,
    input   wire                            S_AXI_RREADY                ,
    output  wire                            spi_clk_en                  ,
    output  wire                            adc_clk_en
);

parameter               UDLY                = 1                         ;

localparam  [1:0]       AXI_OKAY            = 2'b00                     ;
localparam  [14:0]      ADDR_CMU_STA        = 15'h0000                  ;
localparam  [14:0]      ADDR_SPI_CLK        = 15'h0004                  ;
localparam  [14:0]      ADDR_ADC_CLK        = 15'h0008                  ;

reg         [14:0]                  axi_awaddr_r                     ;
reg         [14:0]                  axi_araddr_r                     ;
reg         [31:0]                  axi_wdata_r                      ;
reg         [3:0]                   axi_wstrb_r                      ;
reg                                 aw_pending                       ;
reg                                 w_pending                        ;
reg                                 ar_pending                       ;
reg                                 spi_clk_en_r                     ;
reg                                 adc_clk_en_r                     ;

wire                                aw_accept                        ;
wire                                w_accept                         ;
wire                                ar_accept                        ;
wire                                wr_access                        ;
wire                                rd_access                        ;
wire                                full_word_write                  ;
wire                                aligned_write                    ;
wire                                aligned_read                     ;
wire                                reg_0000h_rd                     ;
wire                                reg_0004h_wr                     ;
wire                                reg_0004h_rd                     ;
wire                                reg_0008h_wr                     ;
wire                                reg_0008h_rd                     ;
wire        [31:0]                  reg_0000h                        ;
wire        [31:0]                  reg_0004h                        ;
wire        [31:0]                  reg_0008h                        ;
wire        [31:0]                  io_rdata                         ;
wire                                gate_req_rst_n                   ;

//////////////////////////////////////////////////
// 1. AXI4-Lite Protocol
//////////////////////////////////////////////////
assign S_AXI_AWREADY = SYS_RST_N & ~aw_pending & ~S_AXI_BVALID;
assign S_AXI_WREADY  = SYS_RST_N & ~w_pending  & ~S_AXI_BVALID;
assign S_AXI_ARREADY = SYS_RST_N & ~ar_pending & ~S_AXI_RVALID;

assign aw_accept = S_AXI_AWREADY & S_AXI_AWVALID;
assign w_accept  = S_AXI_WREADY  & S_AXI_WVALID;
assign ar_accept = S_AXI_ARREADY & S_AXI_ARVALID;
assign wr_access = aw_pending & w_pending & ~S_AXI_BVALID;
assign rd_access = ar_pending & ~S_AXI_RVALID;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        axi_awaddr_r <= #UDLY 15'h0000;
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
        axi_araddr_r <= #UDLY 15'h0000;
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
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(S_AXI_BVALID & S_AXI_BREADY)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(wr_access)
        S_AXI_BVALID <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_BRESP <= #UDLY AXI_OKAY;
    else if(wr_access)
        S_AXI_BRESP <= #UDLY AXI_OKAY;
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
    if(!SYS_RST_N) begin
        S_AXI_RDATA <= #UDLY 32'h0000_0000;
        S_AXI_RRESP <= #UDLY AXI_OKAY;
    end else if(rd_access) begin
        S_AXI_RDATA <= #UDLY io_rdata;
        S_AXI_RRESP <= #UDLY AXI_OKAY;
    end
end

//////////////////////////////////////////////////
// 2. Address Decode
//////////////////////////////////////////////////
assign full_word_write = (axi_wstrb_r == 4'b1111);
assign aligned_write   = (axi_awaddr_r[1:0] == 2'b00);
assign aligned_read    = (axi_araddr_r[1:0] == 2'b00);

assign reg_0000h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_CMU_STA);
assign reg_0004h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_SPI_CLK);
assign reg_0004h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_SPI_CLK);
assign reg_0008h_wr = wr_access & full_word_write & aligned_write &
                      (axi_awaddr_r == ADDR_ADC_CLK);
assign reg_0008h_rd = rd_access & aligned_read &
                      (axi_araddr_r == ADDR_ADC_CLK);

//////////////////////////////////////////////////
// 3. Register Encode
//////////////////////////////////////////////////
assign gate_req_rst_n = SYS_RST_N & SYS_CLK_READY;

// SYS_CLK_READY is an additional asynchronous safety clear. Its assertion is
// synchronized by CMU_READY; software writes cannot occur until RMU releases
// SYS_RST_N after the clock is ready.
always @(posedge SYS_CLK or negedge gate_req_rst_n) begin
    if(!gate_req_rst_n)
        spi_clk_en_r <= #UDLY 1'b0;
    else if(reg_0004h_wr)
        spi_clk_en_r <= #UDLY axi_wdata_r[0];
end

always @(posedge SYS_CLK or negedge gate_req_rst_n) begin
    if(!gate_req_rst_n)
        adc_clk_en_r <= #UDLY 1'b0;
    else if(reg_0008h_wr)
        adc_clk_en_r <= #UDLY axi_wdata_r[0];
end

assign spi_clk_en = spi_clk_en_r;
assign adc_clk_en = adc_clk_en_r;

assign reg_0000h = {30'h0000_0000, SYS_CLK_READY, MMCM_LOCKED};
assign reg_0004h = {31'h0000_0000, spi_clk_en_r};
assign reg_0008h = {31'h0000_0000, adc_clk_en_r};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h);

endmodule

`default_nettype wire
