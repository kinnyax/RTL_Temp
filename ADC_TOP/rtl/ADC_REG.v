`timescale 1ns / 1ps

// AXI4-Lite register control and software-visible status owner.
module ADC_REG(
    // System clock domain
    input  wire                             sys_clk                                      ,
    input  wire                             sys_rst_n                                    ,

    // AXI-Lite write address channel
    input  wire [15:0]                      s_axi_awaddr                                 ,
    input  wire                             s_axi_awvalid                                ,
    output wire                             s_axi_awready                                ,

    // AXI-Lite write data and response channels
    input  wire [31:0]                      s_axi_wdata                                  ,
    input  wire [3:0]                       s_axi_wstrb                                  ,
    input  wire                             s_axi_wvalid                                 ,
    output wire                             s_axi_wready                                 ,
    output wire [1:0]                       s_axi_bresp                                  ,
    output reg                              s_axi_bvalid                                 ,
    input  wire                             s_axi_bready                                 ,

    // AXI-Lite read address and data channels
    input  wire [15:0]                      s_axi_araddr                                 ,
    input  wire                             s_axi_arvalid                                ,
    output wire                             s_axi_arready                                ,
    output reg  [31:0]                      s_axi_rdata                                  ,
    output wire [1:0]                       s_axi_rresp                                  ,
    output reg                              s_axi_rvalid                                 ,
    input  wire                             s_axi_rready                                 ,

    // Synchronized ADC and AFE status
    input  wire [7:0]                       link_ready                                   ,
    input  wire [7:0]                       fifo_empty                                   ,
    input  wire [7:0]                       fifo_full                                    ,
    input  wire [7:0]                       afe_idle                                     ,
    input  wire [7:0]                       pll_lock                                     ,
    input  wire [7:0]                       rx_reset_done                                ,
    input  wire [15:0]                      lane_ready                                   ,
    input  wire [15:0]                      byte_aligned                                 ,
    input  wire [15:0]                      comma_detected                               ,
    input  wire                             sysref_level                                 ,
    input  wire [7:0]                       fifo_overflow_evt                            ,
    input  wire [7:0]                       data_drop_evt                                ,
    input  wire [7:0]                       link_error_evt                               ,
    input  wire [7:0]                       sysref_seen_evt                              ,
    input  wire [15:0]                      disparity_evt                                ,
    input  wire [15:0]                      notintable_evt                               ,
    input  wire                             tgc_busy                                     ,
    input  wire                             tgc_done                                     ,

    // Register control outputs
    output reg  [31:0]                      adc_ctl                                      ,
    output reg  [31:0]                      adc_tgc                                      ,
    output reg  [31:0]                      frame_cfg                                    ,
    output reg                              tgc_req
);

parameter                                   UDLY                                         = 1            ;
localparam [31:0]                           ADC_CTL_MASK                                 = 32'hce00_ffff;

reg      [15:0]                             axi_awaddr_r                                 ;
reg                                         axi_aw_hold                                  ;
reg      [31:0]                             axi_wdata_r                                  ;
reg                                         axi_w_hold                                   ;
reg      [25:0]                             adc_pd                                       ;
reg      [7:0]                              sysref_pd                                    ;
reg      [31:0]                             lane_pd                                      ;
reg                                         sysref_r                                     ;
reg      [15:0]                             sysref_cnt                                   ;

wire                                        wr_access                                    ;
wire                                        rd_access                                    ;
wire                                        reg_0000_wr                                  ;
wire                                        reg_0004_wr                                  ;
wire                                        reg_0008_wr                                  ;
wire                                        reg_0010_wr                                  ;
wire                                        reg_0018_wr                                  ;
wire                                        reg_0024_wr                                  ;
wire                                        reg_0000_rd                                  ;
wire                                        reg_0004_rd                                  ;
wire                                        reg_0008_rd                                  ;
wire                                        reg_000c_rd                                  ;
wire                                        reg_0010_rd                                  ;
wire                                        reg_0014_rd                                  ;
wire                                        reg_0018_rd                                  ;
wire                                        reg_001c_rd                                  ;
wire                                        reg_0020_rd                                  ;
wire                                        reg_0024_rd                                  ;
wire                                        sysref_rise                                  ;
wire                                        tgc_target_err                               ;
wire                                        tgc_reentry_err                              ;
wire                                        tgc_cmd_accept                               ;
wire                                        tgc_req_set                                  ;
wire                                        cfg_wr_safe                                  ;
wire     [25:0]                             adc_pd_set                                   ;
wire     [25:0]                             adc_pd_clr                                   ;
wire     [7:0]                              sysref_pd_set                                ;
wire     [7:0]                              sysref_pd_clr                                ;
wire     [31:0]                             lane_pd_set                                  ;
wire     [31:0]                             lane_pd_clr                                  ;
wire                                        sysref_cnt_inc                               ;
wire     [31:0]                             reg_0000                                     ;
wire     [31:0]                             reg_0004                                     ;
wire     [31:0]                             reg_0008                                     ;
wire     [31:0]                             reg_000c                                     ;
wire     [31:0]                             reg_0010                                     ;
wire     [31:0]                             reg_0014                                     ;
wire     [31:0]                             reg_0018                                     ;
wire     [31:0]                             reg_001c                                     ;
wire     [31:0]                             reg_0020                                     ;
wire     [31:0]                             reg_0024                                     ;
wire     [31:0]                             reg_rdata                                    ;
wire     [3:0]                              unused_wstrb                                 ;

// AXI write address and data are captured independently.
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

// Register address decode.
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

assign sysref_rise      = sysref_level && !sysref_r;
assign tgc_cmd_accept   = reg_0004_wr && !adc_tgc[0] && !tgc_busy;
assign tgc_req_set      = tgc_cmd_accept && axi_wdata_r[0] && (axi_wdata_r[8:1] != 8'd0);
assign tgc_target_err   = tgc_cmd_accept && axi_wdata_r[0] && (axi_wdata_r[8:1] == 8'd0);
assign tgc_reentry_err  = reg_0004_wr && axi_wdata_r[0] && (adc_tgc[0] || tgc_busy);
assign cfg_wr_safe      = (adc_ctl[7:0] == 8'h00) && (afe_idle == 8'hff);
assign adc_pd_set       = {tgc_reentry_err,tgc_target_err,link_error_evt,
                           data_drop_evt,fifo_overflow_evt};
assign adc_pd_clr       = {26{reg_0010_wr}} & axi_wdata_r[25:0];
assign sysref_pd_set    = sysref_seen_evt;
assign sysref_pd_clr    = {8{reg_0018_wr}} & axi_wdata_r[7:0];
assign lane_pd_set      = {notintable_evt,disparity_evt};
assign lane_pd_clr      = {32{reg_0024_wr}} & axi_wdata_r;
assign sysref_cnt_inc   = sysref_rise && (sysref_cnt != 16'hffff);

// Static configuration changes only while all channels are disabled and idle.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        adc_ctl   <= #UDLY 32'd0;
        frame_cfg <= #UDLY 32'd0;
    end else begin
        if (reg_0000_wr) begin
            adc_ctl[15:0] <= #UDLY axi_wdata_r[15:0];
            if (cfg_wr_safe)
                adc_ctl[31:16] <= #UDLY axi_wdata_r[31:16] & ADC_CTL_MASK[31:16];
        end
        if (reg_0008_wr && cfg_wr_safe)
            frame_cfg <= #UDLY axi_wdata_r & 32'h0000_03ff;
    end
end

// TGC configuration and request lifetime.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        adc_tgc <= #UDLY 32'd0;
        tgc_req <= #UDLY 1'b0;
    end else begin
        tgc_req <= #UDLY 1'b0;
        if (tgc_done)
            adc_tgc[0] <= #UDLY 1'b0;
        if (tgc_cmd_accept) begin
            adc_tgc <= #UDLY {19'd0,axi_wdata_r[12:1],1'b0};
            if (tgc_req_set) begin
                adc_tgc[0] <= #UDLY 1'b1;
                tgc_req    <= #UDLY 1'b1;
            end
        end
    end
end

// Hardware event set has priority over a same-cycle software W1C request.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        adc_pd <= #UDLY 26'd0;
    else
        adc_pd <= #UDLY (adc_pd & ~adc_pd_clr) | adc_pd_set;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        sysref_pd <= #UDLY 8'd0;
    else
        sysref_pd <= #UDLY (sysref_pd & ~sysref_pd_clr) | sysref_pd_set;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        lane_pd <= #UDLY 32'd0;
    else
        lane_pd <= #UDLY (lane_pd & ~lane_pd_clr) | lane_pd_set;
end

// SYSREF live edge history and saturating event count.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sysref_r   <= #UDLY 1'b0;
        sysref_cnt <= #UDLY 16'd0;
    end else begin
        sysref_r <= #UDLY sysref_level;
        if (sysref_cnt_inc)
            sysref_cnt <= #UDLY sysref_cnt + 16'd1;
    end
end

// Software readback map; reserved addresses return zero.
assign reg_0000 = adc_ctl;
assign reg_0004 = adc_tgc;
assign reg_0008 = frame_cfg;
assign reg_000c = {afe_idle,fifo_full,fifo_empty,link_ready};
assign reg_0010 = {6'd0,adc_pd};
assign reg_0014 = {rx_reset_done,pll_lock,8'd0,link_ready};
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

