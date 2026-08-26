`timescale 1ns / 1ps

module DMA_REG #(
    parameter integer                       AXI_ADDR_WIDTH              = 15            ,
    parameter integer                       UDLY                        = 1
)(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             DMA_AXIS_RST_N                              ,
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
    input  wire [7:0]                       ch_busy_sys                                 ,
    input  wire [7:0]                       fifo_empty_sys                              ,
    input  wire [7:0]                       fifo_ready_sys                              ,
    input  wire [7:0]                       axi_busy_sys                                ,
    input  wire [7:0]                       half_event_sys                              ,
    input  wire [7:0]                       full_event_sys                              ,
    input  wire [7:0]                       error_event_sys                             ,
    input  wire [7:0]                       stop_event_sys                              ,
    output reg  [255:0]                     ch_addr_shadow                              ,
    output reg  [255:0]                     ch_num_shadow                               ,
    output reg  [71:0]                      ch_ctl_shadow                               ,
    output wire [7:0]                       ch_en_sys                                   ,
    output wire [7:0]                       fifo_clr_sys                                ,
    output wire [7:0]                       axis_ready_sys                              ,
    output wire                             DMA_IRQ
);

localparam [1:0]                         AXI_OKAY                    = 2'b00             ;

reg                                      aw_pending                                     ;
reg  [AXI_ADDR_WIDTH-1:0]               awaddr_hold                                    ;
reg                                      w_pending                                      ;
reg  [31:0]                              wdata_hold                                     ;
reg  [3:0]                               wstrb_hold                                     ;
reg  [23:0]                              dma_ie                                         ;
reg  [7:0]                               half_pd                                        ;
reg  [7:0]                               full_pd                                        ;
reg  [7:0]                               error_pd                                       ;

wire                                     aw_accept                                      ;
wire                                     w_accept                                       ;
wire                                     wr_complete                                    ;
wire                                     wr_access                                      ;
wire                                     rd_access                                      ;
wire [AXI_ADDR_WIDTH-1:0]                write_addr                                     ;
wire [31:0]                              write_data                                     ;
wire [3:0]                               write_strb                                     ;
wire [31:0]                              io_rdata                                       ;

wire                                     reg_0000h_wr                                   ;
wire                                     reg_0004h_wr                                   ;
wire                                     reg_0008h_wr                                   ;
wire                                     reg_0010h_wr                                   ;
wire                                     reg_0014h_wr                                   ;
wire                                     reg_0018h_wr                                   ;
wire                                     reg_0020h_wr                                   ;
wire                                     reg_0024h_wr                                   ;
wire                                     reg_0028h_wr                                   ;
wire                                     reg_0030h_wr                                   ;
wire                                     reg_0034h_wr                                   ;
wire                                     reg_0038h_wr                                   ;
wire                                     reg_0040h_wr                                   ;
wire                                     reg_0044h_wr                                   ;
wire                                     reg_0048h_wr                                   ;
wire                                     reg_0050h_wr                                   ;
wire                                     reg_0054h_wr                                   ;
wire                                     reg_0058h_wr                                   ;
wire                                     reg_0060h_wr                                   ;
wire                                     reg_0064h_wr                                   ;
wire                                     reg_0068h_wr                                   ;
wire                                     reg_0070h_wr                                   ;
wire                                     reg_0074h_wr                                   ;
wire                                     reg_0078h_wr                                   ;
wire                                     reg_0084h_wr                                   ;
wire                                     reg_0088h_wr                                   ;

wire                                     reg_0000h_rd                                   ;
wire                                     reg_0004h_rd                                   ;
wire                                     reg_0008h_rd                                   ;
wire                                     reg_0010h_rd                                   ;
wire                                     reg_0014h_rd                                   ;
wire                                     reg_0018h_rd                                   ;
wire                                     reg_0020h_rd                                   ;
wire                                     reg_0024h_rd                                   ;
wire                                     reg_0028h_rd                                   ;
wire                                     reg_0030h_rd                                   ;
wire                                     reg_0034h_rd                                   ;
wire                                     reg_0038h_rd                                   ;
wire                                     reg_0040h_rd                                   ;
wire                                     reg_0044h_rd                                   ;
wire                                     reg_0048h_rd                                   ;
wire                                     reg_0050h_rd                                   ;
wire                                     reg_0054h_rd                                   ;
wire                                     reg_0058h_rd                                   ;
wire                                     reg_0060h_rd                                   ;
wire                                     reg_0064h_rd                                   ;
wire                                     reg_0068h_rd                                   ;
wire                                     reg_0070h_rd                                   ;
wire                                     reg_0074h_rd                                   ;
wire                                     reg_0078h_rd                                   ;
wire                                     reg_0080h_rd                                   ;
wire                                     reg_0084h_rd                                   ;
wire                                     reg_0088h_rd                                   ;

wire [31:0]                              reg_0000h                                      ;
wire [31:0]                              reg_0004h                                      ;
wire [31:0]                              reg_0008h                                      ;
wire [31:0]                              reg_0010h                                      ;
wire [31:0]                              reg_0014h                                      ;
wire [31:0]                              reg_0018h                                      ;
wire [31:0]                              reg_0020h                                      ;
wire [31:0]                              reg_0024h                                      ;
wire [31:0]                              reg_0028h                                      ;
wire [31:0]                              reg_0030h                                      ;
wire [31:0]                              reg_0034h                                      ;
wire [31:0]                              reg_0038h                                      ;
wire [31:0]                              reg_0040h                                      ;
wire [31:0]                              reg_0044h                                      ;
wire [31:0]                              reg_0048h                                      ;
wire [31:0]                              reg_0050h                                      ;
wire [31:0]                              reg_0054h                                      ;
wire [31:0]                              reg_0058h                                      ;
wire [31:0]                              reg_0060h                                      ;
wire [31:0]                              reg_0064h                                      ;
wire [31:0]                              reg_0068h                                      ;
wire [31:0]                              reg_0070h                                      ;
wire [31:0]                              reg_0074h                                      ;
wire [31:0]                              reg_0078h                                      ;
wire [31:0]                              reg_0080h                                      ;
wire [31:0]                              reg_0084h                                      ;
wire [31:0]                              reg_0088h                                      ;

//////////////////////////////////////////////////
//1. AXI4-Lite Protocol
//////////////////////////////////////////////////

assign S_AXI_AWREADY = ~aw_pending & ~S_AXI_BVALID;
assign S_AXI_WREADY  = ~w_pending  & ~S_AXI_BVALID;
assign S_AXI_BRESP   = AXI_OKAY;
assign S_AXI_ARREADY = ~S_AXI_RVALID;
assign S_AXI_RRESP   = AXI_OKAY;

assign aw_accept   = S_AXI_AWVALID & S_AXI_AWREADY;
assign w_accept    = S_AXI_WVALID  & S_AXI_WREADY;
assign wr_complete = ~S_AXI_BVALID
                   & (aw_pending | aw_accept)
                   & (w_pending  | w_accept);
assign rd_access   = S_AXI_ARVALID & S_AXI_ARREADY;

assign write_addr  = aw_pending ? awaddr_hold : S_AXI_AWADDR;
assign write_data  = w_pending  ? wdata_hold  : S_AXI_WDATA;
assign write_strb  = w_pending  ? wstrb_hold  : S_AXI_WSTRB;
assign wr_access   = wr_complete
                   & (write_addr[1:0] == 2'b00)
                   & (write_strb == 4'b1111);

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        aw_pending <= #UDLY 1'b0;
    else if(wr_complete)
        aw_pending <= #UDLY 1'b0;
    else if(aw_accept)
        aw_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        awaddr_hold <= #UDLY {AXI_ADDR_WIDTH{1'b0}};
    else if(aw_accept)
        awaddr_hold <= #UDLY S_AXI_AWADDR;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        w_pending <= #UDLY 1'b0;
    else if(wr_complete)
        w_pending <= #UDLY 1'b0;
    else if(w_accept)
        w_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        wdata_hold <= #UDLY 32'd0;
        wstrb_hold <= #UDLY 4'd0;
    end
    else if(w_accept) begin
        wdata_hold <= #UDLY S_AXI_WDATA;
        wstrb_hold <= #UDLY S_AXI_WSTRB;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(wr_complete)
        S_AXI_BVALID <= #UDLY 1'b1;
    else if(S_AXI_BVALID & S_AXI_BREADY)
        S_AXI_BVALID <= #UDLY 1'b0;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        S_AXI_RDATA  <= #UDLY 32'd0;
        S_AXI_RVALID <= #UDLY 1'b0;
    end
    else if(rd_access) begin
        S_AXI_RDATA  <= #UDLY io_rdata;
        S_AXI_RVALID <= #UDLY 1'b1;
    end
    else if(S_AXI_RVALID & S_AXI_RREADY) begin
        S_AXI_RVALID <= #UDLY 1'b0;
    end
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////

assign reg_0000h_wr = wr_access & (write_addr == 15'h0000);
assign reg_0004h_wr = wr_access & (write_addr == 15'h0004);
assign reg_0008h_wr = wr_access & (write_addr == 15'h0008);
assign reg_0010h_wr = wr_access & (write_addr == 15'h0010);
assign reg_0014h_wr = wr_access & (write_addr == 15'h0014);
assign reg_0018h_wr = wr_access & (write_addr == 15'h0018);
assign reg_0020h_wr = wr_access & (write_addr == 15'h0020);
assign reg_0024h_wr = wr_access & (write_addr == 15'h0024);
assign reg_0028h_wr = wr_access & (write_addr == 15'h0028);
assign reg_0030h_wr = wr_access & (write_addr == 15'h0030);
assign reg_0034h_wr = wr_access & (write_addr == 15'h0034);
assign reg_0038h_wr = wr_access & (write_addr == 15'h0038);
assign reg_0040h_wr = wr_access & (write_addr == 15'h0040);
assign reg_0044h_wr = wr_access & (write_addr == 15'h0044);
assign reg_0048h_wr = wr_access & (write_addr == 15'h0048);
assign reg_0050h_wr = wr_access & (write_addr == 15'h0050);
assign reg_0054h_wr = wr_access & (write_addr == 15'h0054);
assign reg_0058h_wr = wr_access & (write_addr == 15'h0058);
assign reg_0060h_wr = wr_access & (write_addr == 15'h0060);
assign reg_0064h_wr = wr_access & (write_addr == 15'h0064);
assign reg_0068h_wr = wr_access & (write_addr == 15'h0068);
assign reg_0070h_wr = wr_access & (write_addr == 15'h0070);
assign reg_0074h_wr = wr_access & (write_addr == 15'h0074);
assign reg_0078h_wr = wr_access & (write_addr == 15'h0078);
assign reg_0084h_wr = wr_access & (write_addr == 15'h0084);
assign reg_0088h_wr = wr_access & (write_addr == 15'h0088);

assign reg_0000h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0000);
assign reg_0004h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0004);
assign reg_0008h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0008);
assign reg_0010h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0010);
assign reg_0014h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0014);
assign reg_0018h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0018);
assign reg_0020h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0020);
assign reg_0024h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0024);
assign reg_0028h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0028);
assign reg_0030h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0030);
assign reg_0034h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0034);
assign reg_0038h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0038);
assign reg_0040h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0040);
assign reg_0044h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0044);
assign reg_0048h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0048);
assign reg_0050h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0050);
assign reg_0054h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0054);
assign reg_0058h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0058);
assign reg_0060h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0060);
assign reg_0064h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0064);
assign reg_0068h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0068);
assign reg_0070h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0070);
assign reg_0074h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0074);
assign reg_0078h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0078);
assign reg_0080h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0080);
assign reg_0084h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0084);
assign reg_0088h_rd = rd_access & (S_AXI_ARADDR[1:0] == 2'b00) & (S_AXI_ARADDR == 15'h0088);

//////////////////////////////////////////////////
//3. Register Encode
//////////////////////////////////////////////////

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        ch_addr_shadow <= #UDLY 256'd0;
    else begin
        if(reg_0000h_wr) ch_addr_shadow[31:0]    <= #UDLY write_data;
        if(reg_0010h_wr) ch_addr_shadow[63:32]   <= #UDLY write_data;
        if(reg_0020h_wr) ch_addr_shadow[95:64]   <= #UDLY write_data;
        if(reg_0030h_wr) ch_addr_shadow[127:96]  <= #UDLY write_data;
        if(reg_0040h_wr) ch_addr_shadow[159:128] <= #UDLY write_data;
        if(reg_0050h_wr) ch_addr_shadow[191:160] <= #UDLY write_data;
        if(reg_0060h_wr) ch_addr_shadow[223:192] <= #UDLY write_data;
        if(reg_0070h_wr) ch_addr_shadow[255:224] <= #UDLY write_data;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        ch_num_shadow <= #UDLY 256'd0;
    else begin
        if(reg_0004h_wr) ch_num_shadow[31:0]    <= #UDLY write_data;
        if(reg_0014h_wr) ch_num_shadow[63:32]   <= #UDLY write_data;
        if(reg_0024h_wr) ch_num_shadow[95:64]   <= #UDLY write_data;
        if(reg_0034h_wr) ch_num_shadow[127:96]  <= #UDLY write_data;
        if(reg_0044h_wr) ch_num_shadow[159:128] <= #UDLY write_data;
        if(reg_0054h_wr) ch_num_shadow[191:160] <= #UDLY write_data;
        if(reg_0064h_wr) ch_num_shadow[223:192] <= #UDLY write_data;
        if(reg_0074h_wr) ch_num_shadow[255:224] <= #UDLY write_data;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        ch_ctl_shadow <= #UDLY 72'd0;
    else begin
        if(reg_0008h_wr) begin
            ch_ctl_shadow[8:0] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[31:0] == 32'd0))
                ch_ctl_shadow[0] <= #UDLY 1'b0;
        end
        if(reg_0018h_wr) begin
            ch_ctl_shadow[17:9] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[63:32] == 32'd0))
                ch_ctl_shadow[9] <= #UDLY 1'b0;
        end
        if(reg_0028h_wr) begin
            ch_ctl_shadow[26:18] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[95:64] == 32'd0))
                ch_ctl_shadow[18] <= #UDLY 1'b0;
        end
        if(reg_0038h_wr) begin
            ch_ctl_shadow[35:27] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[127:96] == 32'd0))
                ch_ctl_shadow[27] <= #UDLY 1'b0;
        end
        if(reg_0048h_wr) begin
            ch_ctl_shadow[44:36] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[159:128] == 32'd0))
                ch_ctl_shadow[36] <= #UDLY 1'b0;
        end
        if(reg_0058h_wr) begin
            ch_ctl_shadow[53:45] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[191:160] == 32'd0))
                ch_ctl_shadow[45] <= #UDLY 1'b0;
        end
        if(reg_0068h_wr) begin
            ch_ctl_shadow[62:54] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[223:192] == 32'd0))
                ch_ctl_shadow[54] <= #UDLY 1'b0;
        end
        if(reg_0078h_wr) begin
            ch_ctl_shadow[71:63] <= #UDLY write_data[8:0];
            if(write_data[0] & (ch_num_shadow[255:224] == 32'd0))
                ch_ctl_shadow[63] <= #UDLY 1'b0;
        end
        if(stop_event_sys[0]) ch_ctl_shadow[0]  <= #UDLY 1'b0;
        if(stop_event_sys[1]) ch_ctl_shadow[9]  <= #UDLY 1'b0;
        if(stop_event_sys[2]) ch_ctl_shadow[18] <= #UDLY 1'b0;
        if(stop_event_sys[3]) ch_ctl_shadow[27] <= #UDLY 1'b0;
        if(stop_event_sys[4]) ch_ctl_shadow[36] <= #UDLY 1'b0;
        if(stop_event_sys[5]) ch_ctl_shadow[45] <= #UDLY 1'b0;
        if(stop_event_sys[6]) ch_ctl_shadow[54] <= #UDLY 1'b0;
        if(stop_event_sys[7]) ch_ctl_shadow[63] <= #UDLY 1'b0;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        dma_ie <= #UDLY 24'd0;
    else if(reg_0084h_wr)
        dma_ie <= #UDLY write_data[23:0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        half_pd <= #UDLY 8'd0;
    else if(reg_0088h_wr)
        half_pd <= #UDLY (half_pd & ~write_data[7:0]) | half_event_sys;
    else
        half_pd <= #UDLY half_pd | half_event_sys;
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        full_pd <= #UDLY 8'd0;
    else if(reg_0088h_wr)
        full_pd <= #UDLY (full_pd & ~write_data[15:8]) | full_event_sys;
    else
        full_pd <= #UDLY full_pd | full_event_sys;
end

always @(posedge SYS_CLK or negedge SYS_RST_N or negedge DMA_AXIS_RST_N) begin
    if(!SYS_RST_N || !DMA_AXIS_RST_N)
        error_pd <= #UDLY 8'd0;
    else if(reg_0088h_wr)
        error_pd <= #UDLY (error_pd & ~write_data[23:16]) | error_event_sys;
    else
        error_pd <= #UDLY error_pd | error_event_sys;
end

assign ch_en_sys = {
    ch_ctl_shadow[63] ,
    ch_ctl_shadow[54] ,
    ch_ctl_shadow[45] ,
    ch_ctl_shadow[36] ,
    ch_ctl_shadow[27] ,
    ch_ctl_shadow[18] ,
    ch_ctl_shadow[9]  ,
    ch_ctl_shadow[0]
};

assign fifo_clr_sys = {
    ch_ctl_shadow[68] ,
    ch_ctl_shadow[59] ,
    ch_ctl_shadow[50] ,
    ch_ctl_shadow[41] ,
    ch_ctl_shadow[32] ,
    ch_ctl_shadow[23] ,
    ch_ctl_shadow[14] ,
    ch_ctl_shadow[5]
};

assign axis_ready_sys = fifo_ready_sys
                      & ch_en_sys
                      & {8{DMA_AXIS_RST_N}};

assign DMA_IRQ = |(dma_ie & {error_pd, full_pd, half_pd});

assign reg_0000h = ch_addr_shadow[31:0];
assign reg_0004h = ch_num_shadow[31:0];
assign reg_0008h = {23'd0, ch_ctl_shadow[8:0]};
assign reg_0010h = ch_addr_shadow[63:32];
assign reg_0014h = ch_num_shadow[63:32];
assign reg_0018h = {23'd0, ch_ctl_shadow[17:9]};
assign reg_0020h = ch_addr_shadow[95:64];
assign reg_0024h = ch_num_shadow[95:64];
assign reg_0028h = {23'd0, ch_ctl_shadow[26:18]};
assign reg_0030h = ch_addr_shadow[127:96];
assign reg_0034h = ch_num_shadow[127:96];
assign reg_0038h = {23'd0, ch_ctl_shadow[35:27]};
assign reg_0040h = ch_addr_shadow[159:128];
assign reg_0044h = ch_num_shadow[159:128];
assign reg_0048h = {23'd0, ch_ctl_shadow[44:36]};
assign reg_0050h = ch_addr_shadow[191:160];
assign reg_0054h = ch_num_shadow[191:160];
assign reg_0058h = {23'd0, ch_ctl_shadow[53:45]};
assign reg_0060h = ch_addr_shadow[223:192];
assign reg_0064h = ch_num_shadow[223:192];
assign reg_0068h = {23'd0, ch_ctl_shadow[62:54]};
assign reg_0070h = ch_addr_shadow[255:224];
assign reg_0074h = ch_num_shadow[255:224];
assign reg_0078h = {23'd0, ch_ctl_shadow[71:63]};
assign reg_0080h = DMA_AXIS_RST_N
                 ? {axi_busy_sys, ~fifo_ready_sys, fifo_empty_sys, ch_busy_sys}
                 : 32'd0;
assign reg_0084h = {8'd0, dma_ie};
assign reg_0088h = {8'd0, error_pd, full_pd, half_pd};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h)
                | ({32{reg_0004h_rd}} & reg_0004h)
                | ({32{reg_0008h_rd}} & reg_0008h)
                | ({32{reg_0010h_rd}} & reg_0010h)
                | ({32{reg_0014h_rd}} & reg_0014h)
                | ({32{reg_0018h_rd}} & reg_0018h)
                | ({32{reg_0020h_rd}} & reg_0020h)
                | ({32{reg_0024h_rd}} & reg_0024h)
                | ({32{reg_0028h_rd}} & reg_0028h)
                | ({32{reg_0030h_rd}} & reg_0030h)
                | ({32{reg_0034h_rd}} & reg_0034h)
                | ({32{reg_0038h_rd}} & reg_0038h)
                | ({32{reg_0040h_rd}} & reg_0040h)
                | ({32{reg_0044h_rd}} & reg_0044h)
                | ({32{reg_0048h_rd}} & reg_0048h)
                | ({32{reg_0050h_rd}} & reg_0050h)
                | ({32{reg_0054h_rd}} & reg_0054h)
                | ({32{reg_0058h_rd}} & reg_0058h)
                | ({32{reg_0060h_rd}} & reg_0060h)
                | ({32{reg_0064h_rd}} & reg_0064h)
                | ({32{reg_0068h_rd}} & reg_0068h)
                | ({32{reg_0070h_rd}} & reg_0070h)
                | ({32{reg_0074h_rd}} & reg_0074h)
                | ({32{reg_0078h_rd}} & reg_0078h)
                | ({32{reg_0080h_rd}} & reg_0080h)
                | ({32{reg_0084h_rd}} & reg_0084h)
                | ({32{reg_0088h_rd}} & reg_0088h);

endmodule
