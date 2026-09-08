`timescale 1ns / 1ps

module DMA_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [ 7:0]              s_axi_awaddr                                   ,
    input               [ 2:0]              s_axi_awprot                                   ,
    input                                   s_axi_awvalid                                  ,
    output    reg                           s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    reg                           s_axi_wready                                   ,
    output    reg       [ 1:0]              s_axi_bresp                                    ,
    output    reg                           s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,
    input               [ 7:0]              s_axi_araddr                                   ,
    input               [ 2:0]              s_axi_arprot                                   ,
    input                                   s_axi_arvalid                                  ,
    output    reg                           s_axi_arready                                  ,
    output    reg       [31:0]              s_axi_rdata                                    ,
    output    reg       [ 1:0]              s_axi_rresp                                    ,
    output    reg                           s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    output    reg       [31:0]              ch0_addr                                       ,
    output    reg       [31:0]              ch0_num                                        ,
    output    reg       [31:0]              ch0_ctl                                        ,
    output    reg       [31:0]              ch1_addr                                       ,
    output    reg       [31:0]              ch1_num                                        ,
    output    reg       [31:0]              ch1_ctl                                        ,
    output    reg       [31:0]              ch2_addr                                       ,
    output    reg       [31:0]              ch2_num                                        ,
    output    reg       [31:0]              ch2_ctl                                        ,
    output    reg       [31:0]              ch3_addr                                       ,
    output    reg       [31:0]              ch3_num                                        ,
    output    reg       [31:0]              ch3_ctl                                        ,
    output    reg       [31:0]              ch4_addr                                       ,
    output    reg       [31:0]              ch4_num                                        ,
    output    reg       [31:0]              ch4_ctl                                        ,
    output    reg       [31:0]              ch5_addr                                       ,
    output    reg       [31:0]              ch5_num                                        ,
    output    reg       [31:0]              ch5_ctl                                        ,
    output    reg       [31:0]              ch6_addr                                       ,
    output    reg       [31:0]              ch6_num                                        ,
    output    reg       [31:0]              ch6_ctl                                        ,
    output    reg       [31:0]              ch7_addr                                       ,
    output    reg       [31:0]              ch7_num                                        ,
    output    reg       [31:0]              ch7_ctl                                        ,

    input               [ 7:0]              chn_busy_sync                                  ,
    input               [ 7:0]              fifo_empty_sync                                ,
    input               [ 7:0]              fifo_full_sync                                 ,
    input               [ 7:0]              half_trans_sync                                ,
    input               [ 7:0]              trans_comp_sync                                ,
    input               [ 7:0]              axi_error_sync                                 ,
    output    reg                           dma_irq
);

parameter                                   UDLY                     = 1                   ;

wire                    [31:0]              io_rdata                                       ;
wire                                        wr_access                                      ;
wire                                        wr_addr                                        ;
wire                                        wr_data                                        ;
wire                                        wr_done                                        ;
wire                                        w_ready                                        ;
wire                                        rd_access                                      ;
wire                                        ar_idle                                        ;
wire                                        reg_0000h_wr                                   ;
wire                                        reg_0004h_wr                                   ;
wire                                        reg_0008h_wr                                   ;
wire                                        reg_0010h_wr                                   ;
wire                                        reg_0014h_wr                                   ;
wire                                        reg_0018h_wr                                   ;
wire                                        reg_0020h_wr                                   ;
wire                                        reg_0024h_wr                                   ;
wire                                        reg_0028h_wr                                   ;
wire                                        reg_0030h_wr                                   ;
wire                                        reg_0034h_wr                                   ;
wire                                        reg_0038h_wr                                   ;
wire                                        reg_0040h_wr                                   ;
wire                                        reg_0044h_wr                                   ;
wire                                        reg_0048h_wr                                   ;
wire                                        reg_0050h_wr                                   ;
wire                                        reg_0054h_wr                                   ;
wire                                        reg_0058h_wr                                   ;
wire                                        reg_0060h_wr                                   ;
wire                                        reg_0064h_wr                                   ;
wire                                        reg_0068h_wr                                   ;
wire                                        reg_0070h_wr                                   ;
wire                                        reg_0074h_wr                                   ;
wire                                        reg_0078h_wr                                   ;
wire                                        reg_0084h_wr                                   ;
wire                                        reg_0088h_wr                                   ;
wire                                        reg_0000h_rd                                   ;
wire                                        reg_0004h_rd                                   ;
wire                                        reg_0008h_rd                                   ;
wire                                        reg_0010h_rd                                   ;
wire                                        reg_0014h_rd                                   ;
wire                                        reg_0018h_rd                                   ;
wire                                        reg_0020h_rd                                   ;
wire                                        reg_0024h_rd                                   ;
wire                                        reg_0028h_rd                                   ;
wire                                        reg_0030h_rd                                   ;
wire                                        reg_0034h_rd                                   ;
wire                                        reg_0038h_rd                                   ;
wire                                        reg_0040h_rd                                   ;
wire                                        reg_0044h_rd                                   ;
wire                                        reg_0048h_rd                                   ;
wire                                        reg_0050h_rd                                   ;
wire                                        reg_0054h_rd                                   ;
wire                                        reg_0058h_rd                                   ;
wire                                        reg_0060h_rd                                   ;
wire                                        reg_0064h_rd                                   ;
wire                                        reg_0068h_rd                                   ;
wire                                        reg_0070h_rd                                   ;
wire                                        reg_0074h_rd                                   ;
wire                                        reg_0078h_rd                                   ;
wire                                        reg_0080h_rd                                   ;
wire                                        reg_0084h_rd                                   ;
wire                                        reg_0088h_rd                                   ;
wire                    [31:0]              reg_0000h                                      ;
wire                    [31:0]              reg_0004h                                      ;
wire                    [31:0]              reg_0008h                                      ;
wire                    [31:0]              reg_0010h                                      ;
wire                    [31:0]              reg_0014h                                      ;
wire                    [31:0]              reg_0018h                                      ;
wire                    [31:0]              reg_0020h                                      ;
wire                    [31:0]              reg_0024h                                      ;
wire                    [31:0]              reg_0028h                                      ;
wire                    [31:0]              reg_0030h                                      ;
wire                    [31:0]              reg_0034h                                      ;
wire                    [31:0]              reg_0038h                                      ;
wire                    [31:0]              reg_0040h                                      ;
wire                    [31:0]              reg_0044h                                      ;
wire                    [31:0]              reg_0048h                                      ;
wire                    [31:0]              reg_0050h                                      ;
wire                    [31:0]              reg_0054h                                      ;
wire                    [31:0]              reg_0058h                                      ;
wire                    [31:0]              reg_0060h                                      ;
wire                    [31:0]              reg_0064h                                      ;
wire                    [31:0]              reg_0068h                                      ;
wire                    [31:0]              reg_0070h                                      ;
wire                    [31:0]              reg_0074h                                      ;
wire                    [31:0]              reg_0078h                                      ;
wire                    [31:0]              reg_0080h                                      ;
wire                    [31:0]              reg_0084h                                      ;
wire                    [31:0]              reg_0088h                                      ;

reg                     [ 7:0]              axi_awaddr_r                                   ;
reg                     [ 7:0]              axi_araddr_r                                   ;
reg                                         aw_busy                                        ;
reg                                         wait_data                                      ;
reg                     [23:0]              dma_ie                                         ;
reg                     [23:0]              dma_pd                                         ;

integer i;

//////////////////////////////////////////////////
//1. AXI Protocol
//////////////////////////////////////////////////
assign wr_access = s_axi_wready & s_axi_wvalid;
assign wr_addr   = ~s_axi_awready & s_axi_awvalid & ~aw_busy;
assign wr_data   = wr_access & ~s_axi_bvalid;
assign wr_done   = s_axi_bready & s_axi_bvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_awready <= #UDLY 1'd0;
        aw_busy       <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        s_axi_awready <= #UDLY 1'd1;
        aw_busy       <= #UDLY 1'd1;
    end
    else if(wr_done) begin
        s_axi_awready <= #UDLY 1'd0;
        aw_busy       <= #UDLY 1'd0;
    end
    else
        s_axi_awready <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        axi_awaddr_r <= #UDLY 8'd0;
    else if(wr_addr)
        axi_awaddr_r <= #UDLY s_axi_awaddr;
end

assign w_ready = ~s_axi_wready & s_axi_wvalid & (wait_data | wr_addr);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_wready <= #UDLY 1'd0;
        wait_data    <= #UDLY 1'd0;
    end
    else if(w_ready) begin
        s_axi_wready <= #UDLY 1'd1;
        wait_data    <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        wait_data <= #UDLY 1'd1;
    end
    else begin
        s_axi_wready <= #UDLY 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_bvalid <= #UDLY 1'd0;
        s_axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_data) begin
        s_axi_bvalid <= #UDLY 1'd1;
        s_axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_done)
        s_axi_bvalid <= #UDLY 1'd0;
end

assign ar_idle   = ~s_axi_rvalid | (s_axi_rvalid & s_axi_rready);
assign rd_access = s_axi_arready & s_axi_arvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_arready <= #UDLY 1'd0;
        axi_araddr_r  <= #UDLY 8'd0;
    end
    else if(~s_axi_arready & s_axi_arvalid & ar_idle) begin
        s_axi_arready <= #UDLY 1'd1;
        axi_araddr_r  <= #UDLY s_axi_araddr;
    end
    else
        s_axi_arready <= #UDLY 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_rvalid <= #UDLY 1'd0;
        s_axi_rdata  <= #UDLY 32'd0;
        s_axi_rresp  <= #UDLY 2'd0;
    end
    else if(rd_access) begin
        s_axi_rvalid <= #UDLY 1'd1;
        s_axi_rdata  <= #UDLY io_rdata;
        s_axi_rresp  <= #UDLY 2'd0;
    end
    else if(s_axi_rready & s_axi_rvalid)
        s_axi_rvalid <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
assign reg_0000h_wr = (axi_awaddr_r == 8'h00) & wr_access;
assign reg_0004h_wr = (axi_awaddr_r == 8'h04) & wr_access;
assign reg_0008h_wr = (axi_awaddr_r == 8'h08) & wr_access;
assign reg_0010h_wr = (axi_awaddr_r == 8'h10) & wr_access;
assign reg_0014h_wr = (axi_awaddr_r == 8'h14) & wr_access;
assign reg_0018h_wr = (axi_awaddr_r == 8'h18) & wr_access;
assign reg_0020h_wr = (axi_awaddr_r == 8'h20) & wr_access;
assign reg_0024h_wr = (axi_awaddr_r == 8'h24) & wr_access;
assign reg_0028h_wr = (axi_awaddr_r == 8'h28) & wr_access;
assign reg_0030h_wr = (axi_awaddr_r == 8'h30) & wr_access;
assign reg_0034h_wr = (axi_awaddr_r == 8'h34) & wr_access;
assign reg_0038h_wr = (axi_awaddr_r == 8'h38) & wr_access;
assign reg_0040h_wr = (axi_awaddr_r == 8'h40) & wr_access;
assign reg_0044h_wr = (axi_awaddr_r == 8'h44) & wr_access;
assign reg_0048h_wr = (axi_awaddr_r == 8'h48) & wr_access;
assign reg_0050h_wr = (axi_awaddr_r == 8'h50) & wr_access;
assign reg_0054h_wr = (axi_awaddr_r == 8'h54) & wr_access;
assign reg_0058h_wr = (axi_awaddr_r == 8'h58) & wr_access;
assign reg_0060h_wr = (axi_awaddr_r == 8'h60) & wr_access;
assign reg_0064h_wr = (axi_awaddr_r == 8'h64) & wr_access;
assign reg_0068h_wr = (axi_awaddr_r == 8'h68) & wr_access;
assign reg_0070h_wr = (axi_awaddr_r == 8'h70) & wr_access;
assign reg_0074h_wr = (axi_awaddr_r == 8'h74) & wr_access;
assign reg_0078h_wr = (axi_awaddr_r == 8'h78) & wr_access;
assign reg_0084h_wr = (axi_awaddr_r == 8'h84) & wr_access;
assign reg_0088h_wr = (axi_awaddr_r == 8'h88) & wr_access;

assign reg_0000h_rd = (axi_araddr_r == 8'h00) & rd_access;
assign reg_0004h_rd = (axi_araddr_r == 8'h04) & rd_access;
assign reg_0008h_rd = (axi_araddr_r == 8'h08) & rd_access;
assign reg_0010h_rd = (axi_araddr_r == 8'h10) & rd_access;
assign reg_0014h_rd = (axi_araddr_r == 8'h14) & rd_access;
assign reg_0018h_rd = (axi_araddr_r == 8'h18) & rd_access;
assign reg_0020h_rd = (axi_araddr_r == 8'h20) & rd_access;
assign reg_0024h_rd = (axi_araddr_r == 8'h24) & rd_access;
assign reg_0028h_rd = (axi_araddr_r == 8'h28) & rd_access;
assign reg_0030h_rd = (axi_araddr_r == 8'h30) & rd_access;
assign reg_0034h_rd = (axi_araddr_r == 8'h34) & rd_access;
assign reg_0038h_rd = (axi_araddr_r == 8'h38) & rd_access;
assign reg_0040h_rd = (axi_araddr_r == 8'h40) & rd_access;
assign reg_0044h_rd = (axi_araddr_r == 8'h44) & rd_access;
assign reg_0048h_rd = (axi_araddr_r == 8'h48) & rd_access;
assign reg_0050h_rd = (axi_araddr_r == 8'h50) & rd_access;
assign reg_0054h_rd = (axi_araddr_r == 8'h54) & rd_access;
assign reg_0058h_rd = (axi_araddr_r == 8'h58) & rd_access;
assign reg_0060h_rd = (axi_araddr_r == 8'h60) & rd_access;
assign reg_0064h_rd = (axi_araddr_r == 8'h64) & rd_access;
assign reg_0068h_rd = (axi_araddr_r == 8'h68) & rd_access;
assign reg_0070h_rd = (axi_araddr_r == 8'h70) & rd_access;
assign reg_0074h_rd = (axi_araddr_r == 8'h74) & rd_access;
assign reg_0078h_rd = (axi_araddr_r == 8'h78) & rd_access;
assign reg_0080h_rd = (axi_araddr_r == 8'h80) & rd_access;
assign reg_0084h_rd = (axi_araddr_r == 8'h84) & rd_access;
assign reg_0088h_rd = (axi_araddr_r == 8'h88) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        ch0_addr <= #UDLY 32'd0; ch1_addr <= #UDLY 32'd0;
        ch2_addr <= #UDLY 32'd0; ch3_addr <= #UDLY 32'd0;
        ch4_addr <= #UDLY 32'd0; ch5_addr <= #UDLY 32'd0;
        ch6_addr <= #UDLY 32'd0; ch7_addr <= #UDLY 32'd0;
    end
    else begin
        if(reg_0000h_wr) ch0_addr <= #UDLY s_axi_wdata;
        if(reg_0010h_wr) ch1_addr <= #UDLY s_axi_wdata;
        if(reg_0020h_wr) ch2_addr <= #UDLY s_axi_wdata;
        if(reg_0030h_wr) ch3_addr <= #UDLY s_axi_wdata;
        if(reg_0040h_wr) ch4_addr <= #UDLY s_axi_wdata;
        if(reg_0050h_wr) ch5_addr <= #UDLY s_axi_wdata;
        if(reg_0060h_wr) ch6_addr <= #UDLY s_axi_wdata;
        if(reg_0070h_wr) ch7_addr <= #UDLY s_axi_wdata;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        ch0_num <= #UDLY 32'd0; ch1_num <= #UDLY 32'd0;
        ch2_num <= #UDLY 32'd0; ch3_num <= #UDLY 32'd0;
        ch4_num <= #UDLY 32'd0; ch5_num <= #UDLY 32'd0;
        ch6_num <= #UDLY 32'd0; ch7_num <= #UDLY 32'd0;
    end
    else begin
        if(reg_0004h_wr) ch0_num <= #UDLY s_axi_wdata;
        if(reg_0014h_wr) ch1_num <= #UDLY s_axi_wdata;
        if(reg_0024h_wr) ch2_num <= #UDLY s_axi_wdata;
        if(reg_0034h_wr) ch3_num <= #UDLY s_axi_wdata;
        if(reg_0044h_wr) ch4_num <= #UDLY s_axi_wdata;
        if(reg_0054h_wr) ch5_num <= #UDLY s_axi_wdata;
        if(reg_0064h_wr) ch6_num <= #UDLY s_axi_wdata;
        if(reg_0074h_wr) ch7_num <= #UDLY s_axi_wdata;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        ch0_ctl <= #UDLY 32'd0; ch1_ctl <= #UDLY 32'd0;
        ch2_ctl <= #UDLY 32'd0; ch3_ctl <= #UDLY 32'd0;
        ch4_ctl <= #UDLY 32'd0; ch5_ctl <= #UDLY 32'd0;
        ch6_ctl <= #UDLY 32'd0; ch7_ctl <= #UDLY 32'd0;
    end
    else begin
        if(reg_0008h_wr) ch0_ctl <= #UDLY s_axi_wdata;
        if(reg_0018h_wr) ch1_ctl <= #UDLY s_axi_wdata;
        if(reg_0028h_wr) ch2_ctl <= #UDLY s_axi_wdata;
        if(reg_0038h_wr) ch3_ctl <= #UDLY s_axi_wdata;
        if(reg_0048h_wr) ch4_ctl <= #UDLY s_axi_wdata;
        if(reg_0058h_wr) ch5_ctl <= #UDLY s_axi_wdata;
        if(reg_0068h_wr) ch6_ctl <= #UDLY s_axi_wdata;
        if(reg_0078h_wr) ch7_ctl <= #UDLY s_axi_wdata;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        dma_ie <= #UDLY 24'd0;
    else if(reg_0084h_wr)
        dma_ie <= #UDLY s_axi_wdata[23:0];
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        dma_pd <= #UDLY 24'd0;
    else begin
        if(half_trans_sync[0]) dma_pd[0]  <= #UDLY 1'd1;
        if(half_trans_sync[1]) dma_pd[1]  <= #UDLY 1'd1;
        if(half_trans_sync[2]) dma_pd[2]  <= #UDLY 1'd1;
        if(half_trans_sync[3]) dma_pd[3]  <= #UDLY 1'd1;
        if(half_trans_sync[4]) dma_pd[4]  <= #UDLY 1'd1;
        if(half_trans_sync[5]) dma_pd[5]  <= #UDLY 1'd1;
        if(half_trans_sync[6]) dma_pd[6]  <= #UDLY 1'd1;
        if(half_trans_sync[7]) dma_pd[7]  <= #UDLY 1'd1;
        if(trans_comp_sync[0]) dma_pd[8]  <= #UDLY 1'd1;
        if(trans_comp_sync[1]) dma_pd[9]  <= #UDLY 1'd1;
        if(trans_comp_sync[2]) dma_pd[10] <= #UDLY 1'd1;
        if(trans_comp_sync[3]) dma_pd[11] <= #UDLY 1'd1;
        if(trans_comp_sync[4]) dma_pd[12] <= #UDLY 1'd1;
        if(trans_comp_sync[5]) dma_pd[13] <= #UDLY 1'd1;
        if(trans_comp_sync[6]) dma_pd[14] <= #UDLY 1'd1;
        if(trans_comp_sync[7]) dma_pd[15] <= #UDLY 1'd1;
        if(axi_error_sync[0] ) dma_pd[16] <= #UDLY 1'd1;
        if(axi_error_sync[1] ) dma_pd[17] <= #UDLY 1'd1;
        if(axi_error_sync[2] ) dma_pd[18] <= #UDLY 1'd1;
        if(axi_error_sync[3] ) dma_pd[19] <= #UDLY 1'd1;
        if(axi_error_sync[4] ) dma_pd[20] <= #UDLY 1'd1;
        if(axi_error_sync[5] ) dma_pd[21] <= #UDLY 1'd1;
        if(axi_error_sync[6] ) dma_pd[22] <= #UDLY 1'd1;
        if(axi_error_sync[7] ) dma_pd[23] <= #UDLY 1'd1;
        for(i=0;i<24;i=i+1) begin
            if(reg_0088h_wr & s_axi_wdata[i]) dma_pd[i] <= #UDLY 1'd0;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        dma_irq <= #UDLY 1'd0;
    else
        dma_irq <= #UDLY |(dma_ie & dma_pd);
end

assign reg_0000h = ch0_addr;
assign reg_0004h = {19'd0, ch0_num[12:0]};
assign reg_0008h = {21'd0, ch0_ctl[10], 1'd0, ch0_ctl[8], 1'd0, ch0_ctl[6:2], 1'd0, ch0_ctl[0]};
assign reg_0010h = ch1_addr;
assign reg_0014h = {19'd0, ch1_num[12:0]};
assign reg_0018h = {21'd0, ch1_ctl[10], 1'd0, ch1_ctl[8], 1'd0, ch1_ctl[6:2], 1'd0, ch1_ctl[0]};
assign reg_0020h = ch2_addr;
assign reg_0024h = {19'd0, ch2_num[12:0]};
assign reg_0028h = {21'd0, ch2_ctl[10], 1'd0, ch2_ctl[8], 1'd0, ch2_ctl[6:2], 1'd0, ch2_ctl[0]};
assign reg_0030h = ch3_addr;
assign reg_0034h = {19'd0, ch3_num[12:0]};
assign reg_0038h = {21'd0, ch3_ctl[10], 1'd0, ch3_ctl[8], 1'd0, ch3_ctl[6:2], 1'd0, ch3_ctl[0]};
assign reg_0040h = ch4_addr;
assign reg_0044h = {19'd0, ch4_num[12:0]};
assign reg_0048h = {21'd0, ch4_ctl[10], 1'd0, ch4_ctl[8], 1'd0, ch4_ctl[6:2], 1'd0, ch4_ctl[0]};
assign reg_0050h = ch5_addr;
assign reg_0054h = {19'd0, ch5_num[12:0]};
assign reg_0058h = {21'd0, ch5_ctl[10], 1'd0, ch5_ctl[8], 1'd0, ch5_ctl[6:2], 1'd0, ch5_ctl[0]};
assign reg_0060h = ch6_addr;
assign reg_0064h = {19'd0, ch6_num[12:0]};
assign reg_0068h = {21'd0, ch6_ctl[10], 1'd0, ch6_ctl[8], 1'd0, ch6_ctl[6:2], 1'd0, ch6_ctl[0]};
assign reg_0070h = ch7_addr;
assign reg_0074h = {19'd0, ch7_num[12:0]};
assign reg_0078h = {21'd0, ch7_ctl[10], 1'd0, ch7_ctl[8], 1'd0, ch7_ctl[6:2], 1'd0, ch7_ctl[0]};
assign reg_0080h = {8'd0, fifo_full_sync, fifo_empty_sync, chn_busy_sync};
assign reg_0084h = {8'd0, dma_ie};
assign reg_0088h = {8'd0, dma_pd};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h) |
                  ({32{reg_0010h_rd}} & reg_0010h) |
                  ({32{reg_0014h_rd}} & reg_0014h) |
                  ({32{reg_0018h_rd}} & reg_0018h) |
                  ({32{reg_0020h_rd}} & reg_0020h) |
                  ({32{reg_0024h_rd}} & reg_0024h) |
                  ({32{reg_0028h_rd}} & reg_0028h) |
                  ({32{reg_0030h_rd}} & reg_0030h) |
                  ({32{reg_0034h_rd}} & reg_0034h) |
                  ({32{reg_0038h_rd}} & reg_0038h) |
                  ({32{reg_0040h_rd}} & reg_0040h) |
                  ({32{reg_0044h_rd}} & reg_0044h) |
                  ({32{reg_0048h_rd}} & reg_0048h) |
                  ({32{reg_0050h_rd}} & reg_0050h) |
                  ({32{reg_0054h_rd}} & reg_0054h) |
                  ({32{reg_0058h_rd}} & reg_0058h) |
                  ({32{reg_0060h_rd}} & reg_0060h) |
                  ({32{reg_0064h_rd}} & reg_0064h) |
                  ({32{reg_0068h_rd}} & reg_0068h) |
                  ({32{reg_0070h_rd}} & reg_0070h) |
                  ({32{reg_0074h_rd}} & reg_0074h) |
                  ({32{reg_0078h_rd}} & reg_0078h) |
                  ({32{reg_0080h_rd}} & reg_0080h) |
                  ({32{reg_0084h_rd}} & reg_0084h) |
                  ({32{reg_0088h_rd}} & reg_0088h);

endmodule
