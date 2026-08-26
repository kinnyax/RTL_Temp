`timescale 1ns / 1ps

module ADC_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [15:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    wire                          s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    wire                          s_axi_wready                                   ,
    output    wire      [ 1:0]              s_axi_bresp                                    ,
    output    wire                          s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,
    input               [15:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    wire                          s_axi_arready                                  ,
    output    wire      [31:0]              s_axi_rdata                                    ,
    output    wire      [ 1:0]              s_axi_rresp                                    ,
    output    wire                          s_axi_rvalid                                   ,
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
    input               [ 7:0]              fifo_overflow_evt                              ,
    input               [ 7:0]              data_error_evt                                 ,
    input               [ 7:0]              link_error_evt                                 ,
    input               [ 7:0]              sysref_seen_evt                                ,
    input               [15:0]              disparity_evt                                  ,
    input               [15:0]              notintable_evt                                 ,
    input               [ 7:0]              tgc_done_evt                                   ,

    output    wire      [31:0]              adc_ctl                                        ,
    output    wire      [31:0]              frm_cfg                                        ,
    output    reg       [ 7:0]              tgc_cmd_evt                                    ,
    output    wire      [15:0]              tgc_profile                                    ,
    output    wire      [ 7:0]              tgc_up_dn
);

parameter                                   UDLY                     = 1                   ;

wire                                        clk                                            ;
wire                                        rst_n                                          ;
wire                    [15:0]              axi_awaddr                                     ;
wire                                        axi_awvalid                                    ;
wire                    [31:0]              axi_wdata                                      ;
wire                    [ 3:0]              axi_wstrb                                      ;
wire                                        axi_wvalid                                     ;
wire                                        axi_bready                                     ;
wire                    [15:0]              axi_araddr                                     ;
wire                                        axi_arvalid                                    ;
wire                                        axi_rready                                     ;
wire                    [31:0]              io_rdata                                       ;
wire                                        wr_access                                      ;
wire                                        wr_addr                                        ;
wire                                        wr_data                                        ;
wire                                        wr_done                                        ;
wire                                        data_accept                                    ;
wire                                        rd_access                                      ;
wire                                        ar_ready_en                                    ;
wire                                        static_write_en                                ;

reg                                         axi_awready                                    ;
reg                                         axi_wready                                     ;
reg                     [ 1:0]              axi_bresp                                      ;
reg                                         axi_bvalid                                     ;
reg                                         axi_arready                                    ;
reg                     [31:0]              axi_rdata                                      ;
reg                     [ 1:0]              axi_rresp                                      ;
reg                                         axi_rvalid                                     ;
reg                     [15:0]              axi_awaddr_r                                   ;
reg                     [15:0]              axi_araddr_r                                   ;
reg                                         aw_en                                          ;
reg                                         wait_data                                      ;
reg                     [ 7:0]              afe_en                                         ;
reg                     [ 7:0]              fifo_clr                                       ;
reg                                         frame_fmt                                      ;
reg                     [ 1:0]              smp_mode                                       ;
reg                     [ 1:0]              smp_prec                                       ;
reg                     [ 7:0]              dec_m                                          ;
reg                     [ 1:0]              dec_del_mode                                   ;
reg                     [ 7:0]              tgc_run                                        ;
reg                     [15:0]              tgc_profile_r                                  ;
reg                     [ 7:0]              tgc_up_dn_r                                    ;
reg                     [ 7:0]              fifo_overflow                                  ;
reg                     [ 7:0]              data_error                                     ;
reg                     [ 7:0]              link_error                                     ;
reg                     [ 7:0]              sysref_seen                                    ;
reg                     [15:0]              sysref_count                                   ;
reg                     [15:0]              disparity                                      ;
reg                     [15:0]              notintable                                     ;

integer i;


assign clk           = sys_clk;
assign rst_n         = sys_rst_n;
assign axi_awaddr    = s_axi_awaddr;
assign axi_awvalid   = s_axi_awvalid;
assign axi_wdata     = s_axi_wdata;
assign axi_wstrb     = s_axi_wstrb;
assign axi_wvalid    = s_axi_wvalid;
assign axi_bready    = s_axi_bready;
assign axi_araddr    = s_axi_araddr;
assign axi_arvalid   = s_axi_arvalid;
assign axi_rready    = s_axi_rready;
assign s_axi_awready = axi_awready;
assign s_axi_wready  = axi_wready;
assign s_axi_bresp   = axi_bresp;
assign s_axi_bvalid  = axi_bvalid;
assign s_axi_arready = axi_arready;
assign s_axi_rdata   = axi_rdata;
assign s_axi_rresp   = axi_rresp;
assign s_axi_rvalid  = axi_rvalid;


/* verilator lint_off WIDTHEXPAND */
//////////////////////////////////////////////////
//1. AXI Protocol
//////////////////////////////////////////////////
assign wr_access = axi_wready & axi_wvalid;

assign wr_addr = ~axi_awready & axi_awvalid & ~aw_en;
assign wr_data = wr_access & ~axi_bvalid;
assign wr_done = axi_bready & axi_bvalid;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_awready <= #UDLY 1'd0;
        aw_en       <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        axi_awready <= #UDLY 1'd1;
        aw_en       <= #UDLY 1'd1;
    end
    else if(wr_done) begin
        axi_awready <= #UDLY 1'd0;
        aw_en       <= #UDLY 1'd0;
    end
    else
        axi_awready <= #UDLY 1'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        axi_awaddr_r <= #UDLY 8'd0;
    else if(wr_addr)
        axi_awaddr_r <= #UDLY axi_awaddr;
end

assign data_accept = ~axi_wready & axi_wvalid & (wait_data | wr_addr);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_wready <= #UDLY 1'd0;
        wait_data  <= #UDLY 1'd0;
    end
    else if(data_accept) begin
        axi_wready <= #UDLY 1'd1;
        wait_data  <= #UDLY 1'd0;
    end
    else if(wr_addr) begin
        wait_data <= #UDLY 1'd1;
    end
    else begin
        axi_wready <= #UDLY 1'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_bvalid <= #UDLY 1'd0;
        axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_data) begin
        axi_bvalid <= #UDLY 1'd1;
        axi_bresp  <= #UDLY 2'd0;
    end
    else if(wr_done)
        axi_bvalid <= #UDLY 1'd0;
end

assign ar_ready_en = ~axi_rvalid | (axi_rvalid & axi_rready);
assign rd_access   = axi_arready & axi_arvalid;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_arready  <= #UDLY 1'd0;
        axi_araddr_r <= #UDLY 8'd0;
    end
    else if(~axi_arready & axi_arvalid & ar_ready_en) begin
        axi_arready  <= #UDLY 1'd1;
        axi_araddr_r <= #UDLY axi_araddr;
    end
    else
        axi_arready <= #UDLY 1'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        axi_rvalid <= #UDLY 1'd0;
        axi_rdata  <= #UDLY 32'd0;
        axi_rresp  <= #UDLY 2'd0;
    end
    else if(rd_access) begin
        axi_rvalid <= #UDLY 1'd1;
        axi_rdata  <= #UDLY io_rdata;
        axi_rresp  <= #UDLY 2'd0;
    end
    else if(axi_rready & axi_rvalid)
        axi_rvalid <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
/* verilator lint_on WIDTHEXPAND */
wire  reg_0000h_wr = (axi_awaddr_r==16'h0000) & wr_access;
wire  reg_0004h_wr = (axi_awaddr_r==16'h0004) & wr_access;
wire  reg_0008h_wr = (axi_awaddr_r==16'h0008) & wr_access;
wire  reg_000ch_wr = (axi_awaddr_r==16'h000c) & wr_access;
wire  reg_0010h_wr = (axi_awaddr_r==16'h0010) & wr_access;
wire  reg_0014h_wr = (axi_awaddr_r==16'h0014) & wr_access;
wire  reg_0018h_wr = (axi_awaddr_r==16'h0018) & wr_access;
wire  reg_001ch_wr = (axi_awaddr_r==16'h001c) & wr_access;
wire  reg_0020h_wr = (axi_awaddr_r==16'h0020) & wr_access;
wire  reg_0024h_wr = (axi_awaddr_r==16'h0024) & wr_access;
wire  reg_002ch_wr = (axi_awaddr_r==16'h002c) & wr_access;
wire  reg_0034h_wr = (axi_awaddr_r==16'h0034) & wr_access;
wire  reg_0040h_wr = (axi_awaddr_r==16'h0040) & wr_access;

wire  reg_0000h_rd = (axi_araddr_r==16'h0000) & rd_access;
wire  reg_0004h_rd = (axi_araddr_r==16'h0004) & rd_access;
wire  reg_0008h_rd = (axi_araddr_r==16'h0008) & rd_access;
wire  reg_000ch_rd = (axi_araddr_r==16'h000c) & rd_access;
wire  reg_0010h_rd = (axi_araddr_r==16'h0010) & rd_access;
wire  reg_0014h_rd = (axi_araddr_r==16'h0014) & rd_access;
wire  reg_0018h_rd = (axi_araddr_r==16'h0018) & rd_access;
wire  reg_001ch_rd = (axi_araddr_r==16'h001c) & rd_access;
wire  reg_0020h_rd = (axi_araddr_r==16'h0020) & rd_access;
wire  reg_0024h_rd = (axi_araddr_r==16'h0024) & rd_access;
wire  reg_0028h_rd = (axi_araddr_r==16'h0028) & rd_access;
wire  reg_002ch_rd = (axi_araddr_r==16'h002c) & rd_access;
wire  reg_0030h_rd = (axi_araddr_r==16'h0030) & rd_access;
wire  reg_0034h_rd = (axi_araddr_r==16'h0034) & rd_access;
wire  reg_0038h_rd = (axi_araddr_r==16'h0038) & rd_access;
wire  reg_003ch_rd = (axi_araddr_r==16'h003c) & rd_access;
wire  reg_0040h_rd = (axi_araddr_r==16'h0040) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
// s_axi_wstrb is intentionally ignored; every register write updates all 32 bits.
assign static_write_en = (afe_en==8'd0) && (chn_idle==8'hff) &&
                         ((|axi_wstrb) || !(|axi_wstrb));

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        afe_en       <= #UDLY 8'd0;
        fifo_clr     <= #UDLY 8'd0;
        frame_fmt    <= #UDLY 1'b0;
        smp_mode     <= #UDLY 2'd0;
        smp_prec     <= #UDLY 2'd0;
        dec_m        <= #UDLY 8'd0;
        dec_del_mode <= #UDLY 2'd0;
    end
    else begin
        if(reg_0000h_wr) begin
            afe_en   <= #UDLY axi_wdata[7:0];
            fifo_clr <= #UDLY axi_wdata[15:8];
            if(static_write_en) begin
                frame_fmt <= #UDLY axi_wdata[25];
                smp_mode  <= #UDLY (axi_wdata[27:26]==2'd3) ? 2'd0 : axi_wdata[27:26];
                smp_prec  <= #UDLY (axi_wdata[31:30]==2'd3) ? 2'd0 : axi_wdata[31:30];
            end
        end
        if(reg_0004h_wr && static_write_en) begin
            dec_m        <= #UDLY axi_wdata[7:0];
            dec_del_mode <= #UDLY (axi_wdata[9:8]==2'd3) ? 2'd0 : axi_wdata[9:8];
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        tgc_run       <= #UDLY 8'd0;
        tgc_profile_r <= #UDLY 16'd0;
        tgc_up_dn_r   <= #UDLY 8'd0;
        tgc_cmd_evt   <= #UDLY 8'd0;
    end
    else begin
        tgc_cmd_evt <= #UDLY 8'd0;
        for(i=0;i<8;i=i+1) begin
            if(!afe_en[i])
                tgc_run[i] <= #UDLY 1'b0;
            else if(tgc_done_evt[i])
                tgc_run[i] <= #UDLY 1'b0;
        end
        if(reg_0008h_wr && !tgc_run[0]) begin
            tgc_profile_r[1:0] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[0]     <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[0]) begin
                tgc_run[0]     <= #UDLY 1'b1;
                tgc_cmd_evt[0] <= #UDLY 1'b1;
            end
        end
        if(reg_000ch_wr && !tgc_run[1]) begin
            tgc_profile_r[3:2] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[1]     <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[1]) begin
                tgc_run[1]     <= #UDLY 1'b1;
                tgc_cmd_evt[1] <= #UDLY 1'b1;
            end
        end
        if(reg_0010h_wr && !tgc_run[2]) begin
            tgc_profile_r[5:4] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[2]     <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[2]) begin
                tgc_run[2]     <= #UDLY 1'b1;
                tgc_cmd_evt[2] <= #UDLY 1'b1;
            end
        end
        if(reg_0014h_wr && !tgc_run[3]) begin
            tgc_profile_r[7:6] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[3]     <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[3]) begin
                tgc_run[3]     <= #UDLY 1'b1;
                tgc_cmd_evt[3] <= #UDLY 1'b1;
            end
        end
        if(reg_0018h_wr && !tgc_run[4]) begin
            tgc_profile_r[9:8] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[4]     <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[4]) begin
                tgc_run[4]     <= #UDLY 1'b1;
                tgc_cmd_evt[4] <= #UDLY 1'b1;
            end
        end
        if(reg_001ch_wr && !tgc_run[5]) begin
            tgc_profile_r[11:10] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[5]       <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[5]) begin
                tgc_run[5]     <= #UDLY 1'b1;
                tgc_cmd_evt[5] <= #UDLY 1'b1;
            end
        end
        if(reg_0020h_wr && !tgc_run[6]) begin
            tgc_profile_r[13:12] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[6]       <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[6]) begin
                tgc_run[6]     <= #UDLY 1'b1;
                tgc_cmd_evt[6] <= #UDLY 1'b1;
            end
        end
        if(reg_0024h_wr && !tgc_run[7]) begin
            tgc_profile_r[15:14] <= #UDLY axi_wdata[2:1];
            tgc_up_dn_r[7]       <= #UDLY axi_wdata[3];
            if(axi_wdata[0] && afe_en[7]) begin
                tgc_run[7]     <= #UDLY 1'b1;
                tgc_cmd_evt[7] <= #UDLY 1'b1;
            end
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        fifo_overflow <= #UDLY 8'd0;
        data_error    <= #UDLY 8'd0;
        link_error    <= #UDLY 8'd0;
    end
    else begin
        if(reg_002ch_wr) begin
            fifo_overflow <= #UDLY (fifo_overflow & ~axi_wdata[7:0]) | fifo_overflow_evt;
            data_error    <= #UDLY (data_error & ~axi_wdata[15:8]) | data_error_evt;
            link_error    <= #UDLY (link_error & ~axi_wdata[23:16]) | link_error_evt;
        end
        else begin
            fifo_overflow <= #UDLY fifo_overflow | fifo_overflow_evt;
            data_error    <= #UDLY data_error | data_error_evt;
            link_error    <= #UDLY link_error | link_error_evt;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        sysref_seen  <= #UDLY 8'd0;
        sysref_count <= #UDLY 16'd0;
    end
    else begin
        if(reg_0034h_wr)
            sysref_seen <= #UDLY (sysref_seen & ~axi_wdata[7:0]) | sysref_seen_evt;
        else
            sysref_seen <= #UDLY sysref_seen | sysref_seen_evt;
        if(|sysref_seen_evt)
            sysref_count <= #UDLY sysref_count + 16'd1;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        disparity  <= #UDLY 16'd0;
        notintable <= #UDLY 16'd0;
    end
    else begin
        if(reg_0040h_wr) begin
            disparity  <= #UDLY (disparity & ~axi_wdata[15:0]) | disparity_evt;
            notintable <= #UDLY (notintable & ~axi_wdata[31:16]) | notintable_evt;
        end
        else begin
            disparity  <= #UDLY disparity | disparity_evt;
            notintable <= #UDLY notintable | notintable_evt;
        end
    end
end

assign adc_ctl     = {smp_prec,2'd0,smp_mode,frame_fmt,9'd0,fifo_clr,afe_en};
assign frm_cfg     = {22'd0,dec_del_mode,dec_m};
assign tgc_profile = tgc_profile_r;
assign tgc_up_dn   = tgc_up_dn_r;

wire [31:0] reg_0000h = adc_ctl;
wire [31:0] reg_0004h = frm_cfg;
wire [31:0] reg_0008h = {28'd0,tgc_up_dn_r[0],tgc_profile_r[1:0],tgc_run[0]};
wire [31:0] reg_000ch = {28'd0,tgc_up_dn_r[1],tgc_profile_r[3:2],tgc_run[1]};
wire [31:0] reg_0010h = {28'd0,tgc_up_dn_r[2],tgc_profile_r[5:4],tgc_run[2]};
wire [31:0] reg_0014h = {28'd0,tgc_up_dn_r[3],tgc_profile_r[7:6],tgc_run[3]};
wire [31:0] reg_0018h = {28'd0,tgc_up_dn_r[4],tgc_profile_r[9:8],tgc_run[4]};
wire [31:0] reg_001ch = {28'd0,tgc_up_dn_r[5],tgc_profile_r[11:10],tgc_run[5]};
wire [31:0] reg_0020h = {28'd0,tgc_up_dn_r[6],tgc_profile_r[13:12],tgc_run[6]};
wire [31:0] reg_0024h = {28'd0,tgc_up_dn_r[7],tgc_profile_r[15:14],tgc_run[7]};
wire [31:0] reg_0028h = {chn_idle,fifo_full,fifo_empty,link_ready};
wire [31:0] reg_002ch = {8'd0,link_error,data_error,fifo_overflow};
wire [31:0] reg_0030h = {rx_reset_done,pll_lock,8'd0,link_ready};
wire [31:0] reg_0034h = {sysref_count,7'd0,sysref_level,sysref_seen};
wire [31:0] reg_0038h = {byte_aligned,lane_ready};
wire [31:0] reg_003ch = {16'd0,comma_detected};
wire [31:0] reg_0040h = {notintable,disparity};

assign io_rdata = ({32{reg_0000h_rd}} & reg_0000h)|
                  ({32{reg_0004h_rd}} & reg_0004h)|
                  ({32{reg_0008h_rd}} & reg_0008h)|
                  ({32{reg_000ch_rd}} & reg_000ch)|
                  ({32{reg_0010h_rd}} & reg_0010h)|
                  ({32{reg_0014h_rd}} & reg_0014h)|
                  ({32{reg_0018h_rd}} & reg_0018h)|
                  ({32{reg_001ch_rd}} & reg_001ch)|
                  ({32{reg_0020h_rd}} & reg_0020h)|
                  ({32{reg_0024h_rd}} & reg_0024h)|
                  ({32{reg_0028h_rd}} & reg_0028h)|
                  ({32{reg_002ch_rd}} & reg_002ch)|
                  ({32{reg_0030h_rd}} & reg_0030h)|
                  ({32{reg_0034h_rd}} & reg_0034h)|
                  ({32{reg_0038h_rd}} & reg_0038h)|
                  ({32{reg_003ch_rd}} & reg_003ch)|
                  ({32{reg_0040h_rd}} & reg_0040h);

endmodule

