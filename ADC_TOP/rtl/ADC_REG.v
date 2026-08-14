`timescale 1ns / 1ps

// =====
// 1. AXI Register Control
// =====
module ADC_REG(
    input  wire                             sys_clk                                     ,
    input  wire                             sys_rst_n                                   ,
    input  wire [15:0]                      s_axi_awaddr                                ,
    input  wire                             s_axi_awvalid                               ,
    output wire                             s_axi_awready                               ,
    input  wire [31:0]                      s_axi_wdata                                 ,
    input  wire [3:0]                       s_axi_wstrb                                 ,
    input  wire                             s_axi_wvalid                                ,
    output wire                             s_axi_wready                                ,
    output wire [1:0]                       s_axi_bresp                                 ,
    output reg                              s_axi_bvalid                                ,
    input  wire                             s_axi_bready                                ,
    input  wire [15:0]                      s_axi_araddr                                ,
    input  wire                             s_axi_arvalid                               ,
    output wire                             s_axi_arready                               ,
    output reg [31:0]                       s_axi_rdata                                 ,
    output wire [1:0]                       s_axi_rresp                                 ,
    output reg                              s_axi_rvalid                                ,
    input  wire                             s_axi_rready                                ,
    input  wire [7:0]                       link_ready                                  ,
    input  wire [7:0]                       fifo_empty                                  ,
    input  wire [7:0]                       fifo_full                                   ,
    input  wire [7:0]                       afe_idle                                    ,
    input  wire [15:0]                      jesd_state                                  ,
    input  wire [7:0]                       pll_lock                                    ,
    input  wire [7:0]                       rx_reset_done                               ,
    input  wire [15:0]                      lane_ready                                  ,
    input  wire [15:0]                      byte_aligned                                ,
    input  wire [15:0]                      comma_detected                              ,
    input  wire                             sysref_level                                ,
    input  wire [7:0]                       fifo_overflow_evt                           ,
    input  wire [7:0]                       data_drop_evt                               ,
    input  wire [7:0]                       link_error_evt                              ,
    input  wire [7:0]                       sysref_seen_evt                             ,
    input  wire [15:0]                      disparity_evt                               ,
    input  wire [15:0]                      notintable_evt                              ,
    input  wire                             tgc_busy                                    ,
    input  wire                             tgc_done                                    ,
    output wire [7:0]                       afe_en                                      ,
    output wire [7:0]                       fifo_clr                                    ,
    output wire [1:0]                       smp_prec                                    ,
    output wire [1:0]                       smp_mode                                    ,
    output wire                             frame_fmt                                   ,
    output wire [1:0]                       dec_del_mode                                ,
    output wire [7:0]                       dec_m                                       ,
    output wire [7:0]                       tgc_mask                                    ,
    output wire [1:0]                       tgc_profile_sel                             ,
    output wire                             tgc_up_dn                                   ,
    output wire                             tgc_slope_trig                              ,
    output reg                              tgc_req
);

parameter                                  UDLY         = 1                             ;
localparam [31:0]                          ADC_CTL_MASK = 32'hce00_ffff                 ;

reg [15:0]                                  axi_awaddr_r                                ;
reg                                         axi_aw_hold                                 ;
reg [31:0]                                  axi_wdata_r                                 ;
reg                                         axi_w_hold                                  ;
reg [31:0]                                  adc_ctl                                     ;
reg [31:0]                                  adc_tgc                                     ;
reg [31:0]                                  frame_cfg                                   ;
reg [25:0]                                  adc_pd                                      ;
reg [7:0]                                   sysref_pd                                   ;
reg [31:0]                                  lane_pd                                     ;
reg                                         sysref_r                                    ;
reg [15:0]                                  sysref_cnt                                  ;

wire                                        wr_access                                   ;
wire                                        rd_access                                   ;
wire                                        reg_0000_wr                                 ;
wire                                        reg_0004_wr                                 ;
wire                                        reg_0008_wr                                 ;
wire                                        reg_0010_wr                                 ;
wire                                        reg_0018_wr                                 ;
wire                                        reg_0024_wr                                 ;
wire                                        reg_0000_rd                                 ;
wire                                        reg_0004_rd                                 ;
wire                                        reg_0008_rd                                 ;
wire                                        reg_000c_rd                                 ;
wire                                        reg_0010_rd                                 ;
wire                                        reg_0014_rd                                 ;
wire                                        reg_0018_rd                                 ;
wire                                        reg_001c_rd                                 ;
wire                                        reg_0020_rd                                 ;
wire                                        reg_0024_rd                                 ;
wire                                        sysref_rise                                 ;
wire                                        tgc_target_err                              ;
wire                                        tgc_reentry_err                             ;
wire [31:0]                                 reg_0000                                    ;
wire [31:0]                                 reg_0004                                    ;
wire [31:0]                                 reg_0008                                    ;
wire [31:0]                                 reg_000c                                    ;
wire [31:0]                                 reg_0010                                    ;
wire [31:0]                                 reg_0014                                    ;
wire [31:0]                                 reg_0018                                    ;
wire [31:0]                                 reg_001c                                    ;
wire [31:0]                                 reg_0020                                    ;
wire [31:0]                                 reg_0024                                    ;
wire [31:0]                                 reg_rdata                                   ;
wire [3:0]                                  unused_wstrb                                ;

integer                                     adc_pd_i                                    ;
integer                                     sysref_pd_i                                 ;
integer                                     lane_pd_i                                   ;

assign s_axi_awready = sys_rst_n && !axi_aw_hold && !s_axi_bvalid;
assign s_axi_wready  = sys_rst_n && !axi_w_hold  && !s_axi_bvalid;
assign s_axi_bresp   = 2'b00;
assign s_axi_arready = sys_rst_n && !s_axi_rvalid;
assign s_axi_rresp   = 2'b00;
assign wr_access     = axi_aw_hold && axi_w_hold && !s_axi_bvalid;
assign rd_access     = s_axi_arvalid && s_axi_arready;
assign unused_wstrb  = s_axi_wstrb;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        axi_awaddr_r <= #UDLY 16'd0;
        axi_aw_hold  <= #UDLY 1'b0;
    end else if (s_axi_awvalid && s_axi_awready) begin
        axi_awaddr_r <= #UDLY s_axi_awaddr;
        axi_aw_hold  <= #UDLY 1'b1;
    end else if (wr_access) begin
        axi_aw_hold  <= #UDLY 1'b0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        axi_wdata_r <= #UDLY 32'd0;
        axi_w_hold  <= #UDLY 1'b0;
    end else if (s_axi_wvalid && s_axi_wready) begin
        axi_wdata_r <= #UDLY s_axi_wdata;
        axi_w_hold  <= #UDLY 1'b1;
    end else if (wr_access) begin
        axi_w_hold  <= #UDLY 1'b0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        s_axi_bvalid <= #UDLY 1'b0;
    else if (wr_access)
        s_axi_bvalid <= #UDLY 1'b1;
    else if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= #UDLY 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        s_axi_rvalid <= #UDLY 1'b0;
        s_axi_rdata  <= #UDLY 32'd0;
    end else if (rd_access) begin
        s_axi_rvalid <= #UDLY 1'b1;
        s_axi_rdata  <= #UDLY reg_rdata;
    end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= #UDLY 1'b0;
    end
end

assign reg_0000_wr = wr_access && (axi_awaddr_r == 16'h0000);
assign reg_0004_wr = wr_access && (axi_awaddr_r == 16'h0004);
assign reg_0008_wr = wr_access && (axi_awaddr_r == 16'h0008);
assign reg_0010_wr = wr_access && (axi_awaddr_r == 16'h0010);
assign reg_0018_wr = wr_access && (axi_awaddr_r == 16'h0018);
assign reg_0024_wr = wr_access && (axi_awaddr_r == 16'h0024);

assign reg_0000_rd = rd_access && (s_axi_araddr == 16'h0000);
assign reg_0004_rd = rd_access && (s_axi_araddr == 16'h0004);
assign reg_0008_rd = rd_access && (s_axi_araddr == 16'h0008);
assign reg_000c_rd = rd_access && (s_axi_araddr == 16'h000c);
assign reg_0010_rd = rd_access && (s_axi_araddr == 16'h0010);
assign reg_0014_rd = rd_access && (s_axi_araddr == 16'h0014);
assign reg_0018_rd = rd_access && (s_axi_araddr == 16'h0018);
assign reg_001c_rd = rd_access && (s_axi_araddr == 16'h001c);
assign reg_0020_rd = rd_access && (s_axi_araddr == 16'h0020);
assign reg_0024_rd = rd_access && (s_axi_araddr == 16'h0024);

assign afe_en          = adc_ctl[7:0];
assign fifo_clr        = adc_ctl[15:8];
assign frame_fmt       = adc_ctl[25];
assign smp_mode        = adc_ctl[27:26];
assign smp_prec        = adc_ctl[31:30];
assign tgc_mask        = adc_tgc[8:1];
assign tgc_profile_sel = adc_tgc[10:9];
assign tgc_up_dn       = adc_tgc[11];
assign tgc_slope_trig  = adc_tgc[12];
assign dec_m           = frame_cfg[7:0];
assign dec_del_mode    = frame_cfg[9:8];

assign sysref_rise     = sysref_level && !sysref_r;
assign tgc_target_err  = reg_0004_wr && axi_wdata_r[0] && (axi_wdata_r[8:1] == 8'd0);
assign tgc_reentry_err = reg_0004_wr && axi_wdata_r[0] && (adc_tgc[0] || tgc_busy);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        adc_ctl   <= #UDLY 32'd0;
        frame_cfg <= #UDLY 32'd0;
    end else begin
        if (reg_0000_wr)
            adc_ctl <= #UDLY axi_wdata_r & ADC_CTL_MASK;
        if (reg_0008_wr)
            frame_cfg <= #UDLY axi_wdata_r & 32'h0000_03ff;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        adc_tgc   <= #UDLY 32'd0;
        tgc_req <= #UDLY 1'b0;
    end else begin
        tgc_req <= #UDLY 1'b0;
        if (tgc_done)
            adc_tgc[0] <= #UDLY 1'b0;
        if (reg_0004_wr && !adc_tgc[0] && !tgc_busy) begin
            adc_tgc <= #UDLY {19'd0,axi_wdata_r[12:1],1'b0};
            if (axi_wdata_r[0] && (axi_wdata_r[8:1] != 8'd0)) begin
                adc_tgc[0] <= #UDLY 1'b1;
                tgc_req  <= #UDLY 1'b1;
            end
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        adc_pd <= #UDLY 26'd0;
    end else begin
        for (adc_pd_i=0; adc_pd_i<26; adc_pd_i=adc_pd_i+1) begin
            if (reg_0010_wr && axi_wdata_r[adc_pd_i])
                adc_pd[adc_pd_i] <= #UDLY 1'b0;
        end
        if (fifo_overflow_evt[0]) adc_pd[0]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[1]) adc_pd[1]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[2]) adc_pd[2]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[3]) adc_pd[3]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[4]) adc_pd[4]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[5]) adc_pd[5]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[6]) adc_pd[6]  <= #UDLY 1'b1;
        if (fifo_overflow_evt[7]) adc_pd[7]  <= #UDLY 1'b1;
        if (data_drop_evt[0])     adc_pd[8]  <= #UDLY 1'b1;
        if (data_drop_evt[1])     adc_pd[9]  <= #UDLY 1'b1;
        if (data_drop_evt[2])     adc_pd[10] <= #UDLY 1'b1;
        if (data_drop_evt[3])     adc_pd[11] <= #UDLY 1'b1;
        if (data_drop_evt[4])     adc_pd[12] <= #UDLY 1'b1;
        if (data_drop_evt[5])     adc_pd[13] <= #UDLY 1'b1;
        if (data_drop_evt[6])     adc_pd[14] <= #UDLY 1'b1;
        if (data_drop_evt[7])     adc_pd[15] <= #UDLY 1'b1;
        if (link_error_evt[0])    adc_pd[16] <= #UDLY 1'b1;
        if (link_error_evt[1])    adc_pd[17] <= #UDLY 1'b1;
        if (link_error_evt[2])    adc_pd[18] <= #UDLY 1'b1;
        if (link_error_evt[3])    adc_pd[19] <= #UDLY 1'b1;
        if (link_error_evt[4])    adc_pd[20] <= #UDLY 1'b1;
        if (link_error_evt[5])    adc_pd[21] <= #UDLY 1'b1;
        if (link_error_evt[6])    adc_pd[22] <= #UDLY 1'b1;
        if (link_error_evt[7])    adc_pd[23] <= #UDLY 1'b1;
        if (tgc_target_err)         adc_pd[24] <= #UDLY 1'b1;
        if (tgc_reentry_err)        adc_pd[25] <= #UDLY 1'b1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sysref_pd <= #UDLY 8'd0;
    end else begin
        for (sysref_pd_i=0; sysref_pd_i<8; sysref_pd_i=sysref_pd_i+1) begin
            if (reg_0018_wr && axi_wdata_r[sysref_pd_i])
                sysref_pd[sysref_pd_i] <= #UDLY 1'b0;
        end
        if (sysref_seen_evt[0]) sysref_pd[0] <= #UDLY 1'b1;
        if (sysref_seen_evt[1]) sysref_pd[1] <= #UDLY 1'b1;
        if (sysref_seen_evt[2]) sysref_pd[2] <= #UDLY 1'b1;
        if (sysref_seen_evt[3]) sysref_pd[3] <= #UDLY 1'b1;
        if (sysref_seen_evt[4]) sysref_pd[4] <= #UDLY 1'b1;
        if (sysref_seen_evt[5]) sysref_pd[5] <= #UDLY 1'b1;
        if (sysref_seen_evt[6]) sysref_pd[6] <= #UDLY 1'b1;
        if (sysref_seen_evt[7]) sysref_pd[7] <= #UDLY 1'b1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        lane_pd <= #UDLY 32'd0;
    end else begin
        for (lane_pd_i=0; lane_pd_i<32; lane_pd_i=lane_pd_i+1) begin
            if (reg_0024_wr && axi_wdata_r[lane_pd_i])
                lane_pd[lane_pd_i] <= #UDLY 1'b0;
        end
        if (disparity_evt[0])   lane_pd[0]  <= #UDLY 1'b1;
        if (disparity_evt[1])   lane_pd[1]  <= #UDLY 1'b1;
        if (disparity_evt[2])   lane_pd[2]  <= #UDLY 1'b1;
        if (disparity_evt[3])   lane_pd[3]  <= #UDLY 1'b1;
        if (disparity_evt[4])   lane_pd[4]  <= #UDLY 1'b1;
        if (disparity_evt[5])   lane_pd[5]  <= #UDLY 1'b1;
        if (disparity_evt[6])   lane_pd[6]  <= #UDLY 1'b1;
        if (disparity_evt[7])   lane_pd[7]  <= #UDLY 1'b1;
        if (disparity_evt[8])   lane_pd[8]  <= #UDLY 1'b1;
        if (disparity_evt[9])   lane_pd[9]  <= #UDLY 1'b1;
        if (disparity_evt[10])  lane_pd[10] <= #UDLY 1'b1;
        if (disparity_evt[11])  lane_pd[11] <= #UDLY 1'b1;
        if (disparity_evt[12])  lane_pd[12] <= #UDLY 1'b1;
        if (disparity_evt[13])  lane_pd[13] <= #UDLY 1'b1;
        if (disparity_evt[14])  lane_pd[14] <= #UDLY 1'b1;
        if (disparity_evt[15])  lane_pd[15] <= #UDLY 1'b1;
        if (notintable_evt[0])  lane_pd[16] <= #UDLY 1'b1;
        if (notintable_evt[1])  lane_pd[17] <= #UDLY 1'b1;
        if (notintable_evt[2])  lane_pd[18] <= #UDLY 1'b1;
        if (notintable_evt[3])  lane_pd[19] <= #UDLY 1'b1;
        if (notintable_evt[4])  lane_pd[20] <= #UDLY 1'b1;
        if (notintable_evt[5])  lane_pd[21] <= #UDLY 1'b1;
        if (notintable_evt[6])  lane_pd[22] <= #UDLY 1'b1;
        if (notintable_evt[7])  lane_pd[23] <= #UDLY 1'b1;
        if (notintable_evt[8])  lane_pd[24] <= #UDLY 1'b1;
        if (notintable_evt[9])  lane_pd[25] <= #UDLY 1'b1;
        if (notintable_evt[10]) lane_pd[26] <= #UDLY 1'b1;
        if (notintable_evt[11]) lane_pd[27] <= #UDLY 1'b1;
        if (notintable_evt[12]) lane_pd[28] <= #UDLY 1'b1;
        if (notintable_evt[13]) lane_pd[29] <= #UDLY 1'b1;
        if (notintable_evt[14]) lane_pd[30] <= #UDLY 1'b1;
        if (notintable_evt[15]) lane_pd[31] <= #UDLY 1'b1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sysref_r   <= #UDLY 1'b0;
        sysref_cnt <= #UDLY 16'd0;
    end else begin
        sysref_r <= #UDLY sysref_level;
        if (sysref_rise && (sysref_cnt != 16'hffff))
            sysref_cnt <= #UDLY sysref_cnt + 16'd1;
    end
end

assign reg_0000 = adc_ctl;
assign reg_0004 = adc_tgc;
assign reg_0008 = frame_cfg;
assign reg_000c = {afe_idle,fifo_full,fifo_empty,link_ready};
assign reg_0010 = {6'd0,adc_pd};
assign reg_0014 = {rx_reset_done,pll_lock,jesd_state};
assign reg_0018 = {sysref_cnt,7'd0,sysref_level,sysref_pd};
assign reg_001c = {byte_aligned,lane_ready};
assign reg_0020 = {16'd0,comma_detected};
assign reg_0024 = lane_pd;

assign reg_rdata = ({32{reg_0000_rd}} & reg_0000) |
                   ({32{reg_0004_rd}} & reg_0004) |
                   ({32{reg_0008_rd}} & reg_0008) |
                   ({32{reg_000c_rd}} & reg_000c) |
                   ({32{reg_0010_rd}} & reg_0010) |
                   ({32{reg_0014_rd}} & reg_0014) |
                   ({32{reg_0018_rd}} & reg_0018) |
                   ({32{reg_001c_rd}} & reg_001c) |
                   ({32{reg_0020_rd}} & reg_0020) |
                   ({32{reg_0024_rd}} & reg_0024);

endmodule

