`timescale 1ns / 1ps

module ADC_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [15:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    reg                           s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    reg                           s_axi_wready                                   ,
    output    reg       [ 1:0]              s_axi_bresp                                    ,
    output    reg                           s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,
    input               [15:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    reg                           s_axi_arready                                  ,
    output    reg       [31:0]              s_axi_rdata                                    ,
    output    reg       [ 1:0]              s_axi_rresp                                    ,
    output    reg                           s_axi_rvalid                                   ,
    input                                   s_axi_rready                                   ,

    input               [ 7:0]              link_ready                                     ,
    input               [ 7:0]              fifo_empty                                     ,
    input               [ 7:0]              fifo_full                                      ,
    input               [ 7:0]              chn_idle                                       ,
    input               [ 7:0]              pll_lock                                       ,
    input               [ 7:0]              rx_reset_done                                  ,
    input               [15:0]              lane_ready                                     ,
    input               [15:0]              byte_aligned                                   ,
    input               [15:0]              comma_detected                                 ,
    input                                   sysref_level                                   ,
    input               [ 7:0]              fifo_overflow_sync                             ,
    input               [ 7:0]              data_error_sync                                ,
    input               [ 7:0]              link_error_sync                                ,
    input               [ 7:0]              sysref_seen_sync                               ,
    input               [15:0]              disparity_sync                                 ,
    input               [15:0]              notintable_sync                                ,
    input               [ 7:0]              tgc_done                                       ,

    output    reg       [31:0]              adc_ctl                                        ,
    output    reg       [31:0]              frm_cfg                                        ,
    output    reg       [ 3:0]              chn0_tgc                                       ,
    output    reg       [ 3:0]              chn1_tgc                                       ,
    output    reg       [ 3:0]              chn2_tgc                                       ,
    output    reg       [ 3:0]              chn3_tgc                                       ,
    output    reg       [ 3:0]              chn4_tgc                                       ,
    output    reg       [ 3:0]              chn5_tgc                                       ,
    output    reg       [ 3:0]              chn6_tgc                                       ,
    output    reg       [ 3:0]              chn7_tgc
);

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
wire                                        reg_000ch_wr                                   ;
wire                                        reg_0010h_wr                                   ;
wire                                        reg_0014h_wr                                   ;
wire                                        reg_0018h_wr                                   ;
wire                                        reg_001ch_wr                                   ;
wire                                        reg_0020h_wr                                   ;
wire                                        reg_0024h_wr                                   ;
wire                                        reg_002ch_wr                                   ;
wire                                        reg_0034h_wr                                   ;
wire                                        reg_0040h_wr                                   ;
wire                                        reg_0000h_rd                                   ;
wire                                        reg_0004h_rd                                   ;
wire                                        reg_0008h_rd                                   ;
wire                                        reg_000ch_rd                                   ;
wire                                        reg_0010h_rd                                   ;
wire                                        reg_0014h_rd                                   ;
wire                                        reg_0018h_rd                                   ;
wire                                        reg_001ch_rd                                   ;
wire                                        reg_0020h_rd                                   ;
wire                                        reg_0024h_rd                                   ;
wire                                        reg_0028h_rd                                   ;
wire                                        reg_002ch_rd                                   ;
wire                                        reg_0030h_rd                                   ;
wire                                        reg_0034h_rd                                   ;
wire                                        reg_0038h_rd                                   ;
wire                                        reg_003ch_rd                                   ;
wire                                        reg_0040h_rd                                   ;
wire                    [31:0]              reg_0000h                                      ;
wire                    [31:0]              reg_0004h                                      ;
wire                    [31:0]              reg_0008h                                      ;
wire                    [31:0]              reg_000ch                                      ;
wire                    [31:0]              reg_0010h                                      ;
wire                    [31:0]              reg_0014h                                      ;
wire                    [31:0]              reg_0018h                                      ;
wire                    [31:0]              reg_001ch                                      ;
wire                    [31:0]              reg_0020h                                      ;
wire                    [31:0]              reg_0024h                                      ;
wire                    [31:0]              reg_0028h                                      ;
wire                    [31:0]              reg_002ch                                      ;
wire                    [31:0]              reg_0030h                                      ;
wire                    [31:0]              reg_0034h                                      ;
wire                    [31:0]              reg_0038h                                      ;
wire                    [31:0]              reg_003ch                                      ;
wire                    [31:0]              reg_0040h                                      ;

reg                     [15:0]              axi_awaddr_r                                   ;
reg                     [15:0]              axi_araddr_r                                   ;
reg                                         aw_busy                                        ;
reg                                         wait_data                                      ;
reg                     [23:0]              adc_pd                                         ;
reg                     [ 7:0]              sysref_seen                                    ;
reg                     [31:0]              lane_pd                                        ;

integer i;
integer j;
integer k;

//////////////////////////////////////////////////
//1. AXI Protocol
//////////////////////////////////////////////////
assign wr_access = s_axi_wready & s_axi_wvalid;
assign wr_addr   = ~s_axi_awready & s_axi_awvalid & ~aw_busy;
assign wr_data   = wr_access & ~s_axi_bvalid;
assign wr_done   = s_axi_bready & s_axi_bvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_awready <= 1'd0;
        aw_busy       <= 1'd0;
    end
    else if(wr_addr) begin
        s_axi_awready <= 1'd1;
        aw_busy       <= 1'd1;
    end
    else if(wr_done) begin
        s_axi_awready <= 1'd0;
        aw_busy       <= 1'd0;
    end
    else
        s_axi_awready <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        axi_awaddr_r <= 16'd0;
    else if(wr_addr)
        axi_awaddr_r <= s_axi_awaddr;
end

assign w_ready = ~s_axi_wready & s_axi_wvalid & (wait_data | wr_addr);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_wready <= 1'd0;
        wait_data    <= 1'd0;
    end
    else if(w_ready) begin
        s_axi_wready <= 1'd1;
        wait_data    <= 1'd0;
    end
    else if(wr_addr) begin
        wait_data <= 1'd1;
    end
    else begin
        s_axi_wready <= 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_bvalid <= 1'd0;
        s_axi_bresp  <= 2'd0;
    end
    else if(wr_data) begin
        s_axi_bvalid <= 1'd1;
        s_axi_bresp  <= 2'd0;
    end
    else if(wr_done)
        s_axi_bvalid <= 1'd0;
end

assign ar_idle   = ~s_axi_rvalid | (s_axi_rvalid & s_axi_rready);
assign rd_access = s_axi_arready & s_axi_arvalid;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_arready <= 1'd0;
        axi_araddr_r  <= 16'd0;
    end
    else if(~s_axi_arready & s_axi_arvalid & ar_idle) begin
        s_axi_arready <= 1'd1;
        axi_araddr_r  <= s_axi_araddr;
    end
    else
        s_axi_arready <= 1'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        s_axi_rvalid <= 1'd0;
        s_axi_rdata  <= 32'd0;
        s_axi_rresp  <= 2'd0;
    end
    else if(rd_access) begin
        s_axi_rvalid <= 1'd1;
        s_axi_rdata  <= io_rdata;
        s_axi_rresp  <= 2'd0;
    end
    else if(s_axi_rready & s_axi_rvalid)
        s_axi_rvalid <= 1'd0;
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
assign reg_0000h_wr = (axi_awaddr_r == 16'h0000) & wr_access;
assign reg_0004h_wr = (axi_awaddr_r == 16'h0004) & wr_access;
assign reg_0008h_wr = (axi_awaddr_r == 16'h0008) & wr_access;
assign reg_000ch_wr = (axi_awaddr_r == 16'h000c) & wr_access;
assign reg_0010h_wr = (axi_awaddr_r == 16'h0010) & wr_access;
assign reg_0014h_wr = (axi_awaddr_r == 16'h0014) & wr_access;
assign reg_0018h_wr = (axi_awaddr_r == 16'h0018) & wr_access;
assign reg_001ch_wr = (axi_awaddr_r == 16'h001c) & wr_access;
assign reg_0020h_wr = (axi_awaddr_r == 16'h0020) & wr_access;
assign reg_0024h_wr = (axi_awaddr_r == 16'h0024) & wr_access;
assign reg_002ch_wr = (axi_awaddr_r == 16'h002c) & wr_access;
assign reg_0034h_wr = (axi_awaddr_r == 16'h0034) & wr_access;
assign reg_0040h_wr = (axi_awaddr_r == 16'h0040) & wr_access;

assign reg_0000h_rd = (axi_araddr_r == 16'h0000) & rd_access;
assign reg_0004h_rd = (axi_araddr_r == 16'h0004) & rd_access;
assign reg_0008h_rd = (axi_araddr_r == 16'h0008) & rd_access;
assign reg_000ch_rd = (axi_araddr_r == 16'h000c) & rd_access;
assign reg_0010h_rd = (axi_araddr_r == 16'h0010) & rd_access;
assign reg_0014h_rd = (axi_araddr_r == 16'h0014) & rd_access;
assign reg_0018h_rd = (axi_araddr_r == 16'h0018) & rd_access;
assign reg_001ch_rd = (axi_araddr_r == 16'h001c) & rd_access;
assign reg_0020h_rd = (axi_araddr_r == 16'h0020) & rd_access;
assign reg_0024h_rd = (axi_araddr_r == 16'h0024) & rd_access;
assign reg_0028h_rd = (axi_araddr_r == 16'h0028) & rd_access;
assign reg_002ch_rd = (axi_araddr_r == 16'h002c) & rd_access;
assign reg_0030h_rd = (axi_araddr_r == 16'h0030) & rd_access;
assign reg_0034h_rd = (axi_araddr_r == 16'h0034) & rd_access;
assign reg_0038h_rd = (axi_araddr_r == 16'h0038) & rd_access;
assign reg_003ch_rd = (axi_araddr_r == 16'h003c) & rd_access;
assign reg_0040h_rd = (axi_araddr_r == 16'h0040) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        adc_ctl <= 32'd0;
        frm_cfg <= 32'd0;
    end
    else begin
        if(reg_0000h_wr)
            adc_ctl <= s_axi_wdata & 32'hce00ffff;
        if(reg_0004h_wr)
            frm_cfg <= s_axi_wdata & 32'h000003ff;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        chn0_tgc <= 4'd0;
        chn1_tgc <= 4'd0;
        chn2_tgc <= 4'd0;
        chn3_tgc <= 4'd0;
        chn4_tgc <= 4'd0;
        chn5_tgc <= 4'd0;
        chn6_tgc <= 4'd0;
        chn7_tgc <= 4'd0;
    end
    else begin
        if(reg_0008h_wr) chn0_tgc <= s_axi_wdata[3:0];
        if(reg_000ch_wr) chn1_tgc <= s_axi_wdata[3:0];
        if(reg_0010h_wr) chn2_tgc <= s_axi_wdata[3:0];
        if(reg_0014h_wr) chn3_tgc <= s_axi_wdata[3:0];
        if(reg_0018h_wr) chn4_tgc <= s_axi_wdata[3:0];
        if(reg_001ch_wr) chn5_tgc <= s_axi_wdata[3:0];
        if(reg_0020h_wr) chn6_tgc <= s_axi_wdata[3:0];
        if(reg_0024h_wr) chn7_tgc <= s_axi_wdata[3:0];
        if(tgc_done[0]) chn0_tgc[0] <= 1'd0;
        if(tgc_done[1]) chn1_tgc[0] <= 1'd0;
        if(tgc_done[2]) chn2_tgc[0] <= 1'd0;
        if(tgc_done[3]) chn3_tgc[0] <= 1'd0;
        if(tgc_done[4]) chn4_tgc[0] <= 1'd0;
        if(tgc_done[5]) chn5_tgc[0] <= 1'd0;
        if(tgc_done[6]) chn6_tgc[0] <= 1'd0;
        if(tgc_done[7]) chn7_tgc[0] <= 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        adc_pd <= 24'd0;
    else begin
        if(fifo_overflow_sync[0]) adc_pd[0]  <= 1'd1;
        if(fifo_overflow_sync[1]) adc_pd[1]  <= 1'd1;
        if(fifo_overflow_sync[2]) adc_pd[2]  <= 1'd1;
        if(fifo_overflow_sync[3]) adc_pd[3]  <= 1'd1;
        if(fifo_overflow_sync[4]) adc_pd[4]  <= 1'd1;
        if(fifo_overflow_sync[5]) adc_pd[5]  <= 1'd1;
        if(fifo_overflow_sync[6]) adc_pd[6]  <= 1'd1;
        if(fifo_overflow_sync[7]) adc_pd[7]  <= 1'd1;
        if(data_error_sync[0])    adc_pd[8]  <= 1'd1;
        if(data_error_sync[1])    adc_pd[9]  <= 1'd1;
        if(data_error_sync[2])    adc_pd[10] <= 1'd1;
        if(data_error_sync[3])    adc_pd[11] <= 1'd1;
        if(data_error_sync[4])    adc_pd[12] <= 1'd1;
        if(data_error_sync[5])    adc_pd[13] <= 1'd1;
        if(data_error_sync[6])    adc_pd[14] <= 1'd1;
        if(data_error_sync[7])    adc_pd[15] <= 1'd1;
        if(link_error_sync[0])    adc_pd[16] <= 1'd1;
        if(link_error_sync[1])    adc_pd[17] <= 1'd1;
        if(link_error_sync[2])    adc_pd[18] <= 1'd1;
        if(link_error_sync[3])    adc_pd[19] <= 1'd1;
        if(link_error_sync[4])    adc_pd[20] <= 1'd1;
        if(link_error_sync[5])    adc_pd[21] <= 1'd1;
        if(link_error_sync[6])    adc_pd[22] <= 1'd1;
        if(link_error_sync[7])    adc_pd[23] <= 1'd1;
        for(i=0;i<24;i=i+1) begin
            if(reg_002ch_wr & s_axi_wdata[i])
                adc_pd[i] <= 1'd0;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        sysref_seen <= 8'd0;
    else begin
        if(sysref_seen_sync[0]) sysref_seen[0] <= 1'd1;
        if(sysref_seen_sync[1]) sysref_seen[1] <= 1'd1;
        if(sysref_seen_sync[2]) sysref_seen[2] <= 1'd1;
        if(sysref_seen_sync[3]) sysref_seen[3] <= 1'd1;
        if(sysref_seen_sync[4]) sysref_seen[4] <= 1'd1;
        if(sysref_seen_sync[5]) sysref_seen[5] <= 1'd1;
        if(sysref_seen_sync[6]) sysref_seen[6] <= 1'd1;
        if(sysref_seen_sync[7]) sysref_seen[7] <= 1'd1;
        for(j=0;j<8;j=j+1) begin
            if(reg_0034h_wr & s_axi_wdata[j])
                sysref_seen[j] <= 1'd0;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        lane_pd <= 32'd0;
    else begin
        if(disparity_sync[0])   lane_pd[0]  <= 1'd1;
        if(disparity_sync[1])   lane_pd[1]  <= 1'd1;
        if(disparity_sync[2])   lane_pd[2]  <= 1'd1;
        if(disparity_sync[3])   lane_pd[3]  <= 1'd1;
        if(disparity_sync[4])   lane_pd[4]  <= 1'd1;
        if(disparity_sync[5])   lane_pd[5]  <= 1'd1;
        if(disparity_sync[6])   lane_pd[6]  <= 1'd1;
        if(disparity_sync[7])   lane_pd[7]  <= 1'd1;
        if(disparity_sync[8])   lane_pd[8]  <= 1'd1;
        if(disparity_sync[9])   lane_pd[9]  <= 1'd1;
        if(disparity_sync[10])  lane_pd[10] <= 1'd1;
        if(disparity_sync[11])  lane_pd[11] <= 1'd1;
        if(disparity_sync[12])  lane_pd[12] <= 1'd1;
        if(disparity_sync[13])  lane_pd[13] <= 1'd1;
        if(disparity_sync[14])  lane_pd[14] <= 1'd1;
        if(disparity_sync[15])  lane_pd[15] <= 1'd1;
        if(notintable_sync[0])  lane_pd[16] <= 1'd1;
        if(notintable_sync[1])  lane_pd[17] <= 1'd1;
        if(notintable_sync[2])  lane_pd[18] <= 1'd1;
        if(notintable_sync[3])  lane_pd[19] <= 1'd1;
        if(notintable_sync[4])  lane_pd[20] <= 1'd1;
        if(notintable_sync[5])  lane_pd[21] <= 1'd1;
        if(notintable_sync[6])  lane_pd[22] <= 1'd1;
        if(notintable_sync[7])  lane_pd[23] <= 1'd1;
        if(notintable_sync[8])  lane_pd[24] <= 1'd1;
        if(notintable_sync[9])  lane_pd[25] <= 1'd1;
        if(notintable_sync[10]) lane_pd[26] <= 1'd1;
        if(notintable_sync[11]) lane_pd[27] <= 1'd1;
        if(notintable_sync[12]) lane_pd[28] <= 1'd1;
        if(notintable_sync[13]) lane_pd[29] <= 1'd1;
        if(notintable_sync[14]) lane_pd[30] <= 1'd1;
        if(notintable_sync[15]) lane_pd[31] <= 1'd1;
        for(k=0;k<32;k=k+1) begin
            if(reg_0040h_wr & s_axi_wdata[k])
                lane_pd[k] <= 1'd0;
        end
    end
end

assign reg_0000h = adc_ctl;
assign reg_0004h = frm_cfg;
assign reg_0008h = {28'd0,chn0_tgc};
assign reg_000ch = {28'd0,chn1_tgc};
assign reg_0010h = {28'd0,chn2_tgc};
assign reg_0014h = {28'd0,chn3_tgc};
assign reg_0018h = {28'd0,chn4_tgc};
assign reg_001ch = {28'd0,chn5_tgc};
assign reg_0020h = {28'd0,chn6_tgc};
assign reg_0024h = {28'd0,chn7_tgc};
assign reg_0028h = {chn_idle,fifo_full,fifo_empty,link_ready};
assign reg_002ch = {8'd0,adc_pd};
assign reg_0030h = {rx_reset_done,pll_lock,8'd0,link_ready};
assign reg_0034h = {23'd0,sysref_level,sysref_seen};
assign reg_0038h = {byte_aligned,lane_ready};
assign reg_003ch = {16'd0,comma_detected};
assign reg_0040h = lane_pd;

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h) |
                  ({32{reg_0004h_rd}} & reg_0004h) |
                  ({32{reg_0008h_rd}} & reg_0008h) |
                  ({32{reg_000ch_rd}} & reg_000ch) |
                  ({32{reg_0010h_rd}} & reg_0010h) |
                  ({32{reg_0014h_rd}} & reg_0014h) |
                  ({32{reg_0018h_rd}} & reg_0018h) |
                  ({32{reg_001ch_rd}} & reg_001ch) |
                  ({32{reg_0020h_rd}} & reg_0020h) |
                  ({32{reg_0024h_rd}} & reg_0024h) |
                  ({32{reg_0028h_rd}} & reg_0028h) |
                  ({32{reg_002ch_rd}} & reg_002ch) |
                  ({32{reg_0030h_rd}} & reg_0030h) |
                  ({32{reg_0034h_rd}} & reg_0034h) |
                  ({32{reg_0038h_rd}} & reg_0038h) |
                  ({32{reg_003ch_rd}} & reg_003ch) |
                  ({32{reg_0040h_rd}} & reg_0040h);

endmodule
