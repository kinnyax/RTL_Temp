`timescale 1ns / 1ps

module ADC_REG(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input               [15:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    wire                          s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    /* verilator lint_off UNUSEDSIGNAL */
    input               [ 3:0]              s_axi_wstrb                                    ,
    /* verilator lint_on UNUSEDSIGNAL */
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

    output    reg       [31:0]              adc_ctl                                        ,
    output    reg       [31:0]              frm_cfg                                        ,
    output    reg       [ 7:0]              tgc_cmd_evt                                    ,
    output    reg       [15:0]              tgc_profile                                    ,
    output    reg       [ 7:0]              tgc_up_dn
);

parameter                                   UDLY                     = 1                   ;

wire                                        clk                                            ;
wire                                        rst_n                                          ;
wire                    [ 7:0]              axi_awaddr                                     ;
wire                                        axi_awvalid                                    ;
wire                    [31:0]              axi_wdata                                      ;
wire                                        axi_wvalid                                     ;
wire                                        axi_bready                                     ;
wire                    [ 7:0]              axi_araddr                                     ;
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

reg                     [ 7:0]              axi_awaddr_r                                   ;
reg                     [ 7:0]              axi_araddr_r                                   ;
reg                                         aw_en                                          ;
reg                                         wait_data                                      ;
reg                                         axi_awready                                    ;
reg                                         axi_wready                                     ;
reg                     [ 1:0]              axi_bresp                                      ;
reg                                         axi_bvalid                                     ;
reg                                         axi_arready                                    ;
reg                     [31:0]              axi_rdata                                      ;
reg                     [ 1:0]              axi_rresp                                      ;
reg                                         axi_rvalid                                     ;

reg                     [ 7:0]              fifo_of_sta                                    ;
reg                     [ 7:0]              data_error_sta                                 ;
reg                     [ 7:0]              link_error_sta                                 ;
reg                     [ 7:0]              sysref_sta                                     ;
reg                     [15:0]              disparity_sta                                  ;
reg                     [15:0]              notintable_sta                                 ;
reg                                         sysref_level_r                                 ;
reg                     [15:0]              sysref_cnt                                     ;
reg                     [ 7:0]              tgc_run                                        ;
wire                                        write_adc_ctl                                  ;
wire                                        write_frm_cfg                                  ;
wire                                        write_tgc                                      ;
/* verilator lint_off UNUSEDSIGNAL */
wire                    [3:0]               write_tgc_word                                 ;
/* verilator lint_on UNUSEDSIGNAL */
wire                    [2:0]               write_tgc_idx                                  ;
wire                                        static_write_safe                              ;
wire                                        write_adc_pd                                   ;
wire                                        write_sysref_sta                               ;
wire                                        write_lane_pd                                  ;
wire                                        sysref_rise                                    ;

assign clk         = sys_clk;
assign rst_n       = sys_rst_n;
// Fold every nonzero upper byte onto one unmapped address without aliasing.
assign axi_awaddr  = (s_axi_awaddr[15:8]==8'd0) ? s_axi_awaddr[7:0] : 8'hff;
assign axi_awvalid = s_axi_awvalid;
assign axi_wdata   = s_axi_wdata;
assign axi_wvalid  = s_axi_wvalid;
assign axi_bready  = s_axi_bready;
assign axi_araddr  = (s_axi_araddr[15:8]==8'd0) ? s_axi_araddr[7:0] : 8'hff;
assign axi_arvalid = s_axi_arvalid;
assign axi_rready  = s_axi_rready;

assign s_axi_awready = axi_awready;
assign s_axi_wready  = axi_wready;
assign s_axi_bresp   = axi_bresp;
assign s_axi_bvalid  = axi_bvalid;
assign s_axi_arready = axi_arready;
assign s_axi_rdata   = rst_n ? axi_rdata : 32'd0;
assign s_axi_rresp   = axi_rresp;
assign s_axi_rvalid  = axi_rvalid;


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
wire  reg_0000h_wr = (axi_awaddr_r==8'h00) & wr_access;
wire  reg_0004h_wr = (axi_awaddr_r==8'h04) & wr_access;
wire  reg_0008h_wr = (axi_awaddr_r==8'h08) & wr_access;
wire  reg_000ch_wr = (axi_awaddr_r==8'h0c) & wr_access;
wire  reg_0010h_wr = (axi_awaddr_r==8'h10) & wr_access;
wire  reg_0014h_wr = (axi_awaddr_r==8'h14) & wr_access;
wire  reg_0018h_wr = (axi_awaddr_r==8'h18) & wr_access;
wire  reg_001ch_wr = (axi_awaddr_r==8'h1c) & wr_access;
wire  reg_0020h_wr = (axi_awaddr_r==8'h20) & wr_access;
wire  reg_0024h_wr = (axi_awaddr_r==8'h24) & wr_access;
wire  reg_002ch_wr = (axi_awaddr_r==8'h2c) & wr_access;
wire  reg_0034h_wr = (axi_awaddr_r==8'h34) & wr_access;
wire  reg_0040h_wr = (axi_awaddr_r==8'h40) & wr_access;

wire  reg_0000h_rd = (axi_araddr_r==8'h00) & rd_access;
wire  reg_0004h_rd = (axi_araddr_r==8'h04) & rd_access;
wire  reg_0008h_rd = (axi_araddr_r==8'h08) & rd_access;
wire  reg_000ch_rd = (axi_araddr_r==8'h0c) & rd_access;
wire  reg_0010h_rd = (axi_araddr_r==8'h10) & rd_access;
wire  reg_0014h_rd = (axi_araddr_r==8'h14) & rd_access;
wire  reg_0018h_rd = (axi_araddr_r==8'h18) & rd_access;
wire  reg_001ch_rd = (axi_araddr_r==8'h1c) & rd_access;
wire  reg_0020h_rd = (axi_araddr_r==8'h20) & rd_access;
wire  reg_0024h_rd = (axi_araddr_r==8'h24) & rd_access;
wire  reg_0028h_rd = (axi_araddr_r==8'h28) & rd_access;
wire  reg_002ch_rd = (axi_araddr_r==8'h2c) & rd_access;
wire  reg_0030h_rd = (axi_araddr_r==8'h30) & rd_access;
wire  reg_0034h_rd = (axi_araddr_r==8'h34) & rd_access;
wire  reg_0038h_rd = (axi_araddr_r==8'h38) & rd_access;
wire  reg_003ch_rd = (axi_araddr_r==8'h3c) & rd_access;
wire  reg_0040h_rd = (axi_araddr_r==8'h40) & rd_access;

//////////////////////////////////////////////////
//3. Write & Read REG
//////////////////////////////////////////////////
assign write_adc_ctl     = reg_0000h_wr;
assign write_frm_cfg     = reg_0004h_wr;
assign write_adc_pd      = reg_002ch_wr;
assign write_sysref_sta  = reg_0034h_wr;
assign write_lane_pd     = reg_0040h_wr;
assign write_tgc         = reg_0008h_wr | reg_000ch_wr | reg_0010h_wr | reg_0014h_wr |
                           reg_0018h_wr | reg_001ch_wr | reg_0020h_wr | reg_0024h_wr;
assign write_tgc_word   = axi_awaddr_r[5:2] - 4'd2;
assign write_tgc_idx    = write_tgc_word[2:0];
assign static_write_safe = (adc_ctl[7:0] == 8'd0) & (chn_idle == 8'hff);
assign sysref_rise       = sysref_level & ~sysref_level_r;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        adc_ctl <= #UDLY 32'd0;
        frm_cfg <= #UDLY 32'd0;
    end
    else begin
        if(write_adc_ctl) begin
            adc_ctl[15:0] <= #UDLY axi_wdata[15:0];

            if(static_write_safe) begin
                adc_ctl[31:30] <= #UDLY axi_wdata[31:30];
                adc_ctl[29:28] <= #UDLY 2'd0;
                adc_ctl[27:26] <= #UDLY axi_wdata[27:26];
                adc_ctl[25]    <= #UDLY axi_wdata[25];
                adc_ctl[24:16] <= #UDLY 9'd0;
            end
        end

        if(write_frm_cfg & static_write_safe)
            frm_cfg <= #UDLY {22'd0, axi_wdata[9:0]};
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        tgc_run     <= #UDLY 8'd0;
        tgc_profile <= #UDLY 16'd0;
        tgc_up_dn   <= #UDLY 8'd0;
        tgc_cmd_evt <= #UDLY 8'd0;
    end
    else begin
        tgc_cmd_evt <= #UDLY 8'd0;
        tgc_run     <= #UDLY tgc_run & ~tgc_done_evt;

        if(write_tgc & ~tgc_run[write_tgc_idx]) begin
            tgc_profile[write_tgc_idx*2 +: 2] <= #UDLY axi_wdata[2:1];
            tgc_up_dn[write_tgc_idx]          <= #UDLY axi_wdata[3];

            if(axi_wdata[0] & adc_ctl[{2'd0, write_tgc_idx}]) begin
                tgc_run[write_tgc_idx]     <= #UDLY 1'b1;
                tgc_cmd_evt[write_tgc_idx] <= #UDLY 1'b1;
            end
        end
    end
end

// Hardware events set after W1C evaluation, so set wins a same-cycle clear.
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        fifo_of_sta    <= #UDLY 8'd0;
        data_error_sta <= #UDLY 8'd0;
        link_error_sta <= #UDLY 8'd0;
        sysref_sta     <= #UDLY 8'd0;
        disparity_sta  <= #UDLY 16'd0;
        notintable_sta <= #UDLY 16'd0;
    end
    else begin
        fifo_of_sta    <= #UDLY (fifo_of_sta & ~(axi_wdata[7:0]   & {8{write_adc_pd}})) | fifo_overflow_evt;
        data_error_sta <= #UDLY (data_error_sta & ~(axi_wdata[15:8]  & {8{write_adc_pd}})) | data_error_evt;
        link_error_sta <= #UDLY (link_error_sta & ~(axi_wdata[23:16] & {8{write_adc_pd}})) | link_error_evt;
        sysref_sta     <= #UDLY (sysref_sta & ~(axi_wdata[7:0] & {8{write_sysref_sta}})) | sysref_seen_evt;
        disparity_sta  <= #UDLY (disparity_sta & ~(axi_wdata[15:0] & {16{write_lane_pd}})) | disparity_evt;
        notintable_sta <= #UDLY (notintable_sta & ~(axi_wdata[31:16] & {16{write_lane_pd}})) | notintable_evt;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        sysref_level_r <= #UDLY 1'b0;
        sysref_cnt     <= #UDLY 16'd0;
    end
    else begin
        sysref_level_r <= #UDLY sysref_level;

        if(sysref_rise & (sysref_cnt != 16'hffff))
            sysref_cnt <= #UDLY sysref_cnt + 16'd1;
    end
end

wire [31:0] reg_0000h = adc_ctl;
wire [31:0] reg_0004h = frm_cfg;
wire [31:0] reg_0008h = {28'd0, tgc_up_dn[0], tgc_profile[1:0],   tgc_run[0]};
wire [31:0] reg_000ch = {28'd0, tgc_up_dn[1], tgc_profile[3:2],   tgc_run[1]};
wire [31:0] reg_0010h = {28'd0, tgc_up_dn[2], tgc_profile[5:4],   tgc_run[2]};
wire [31:0] reg_0014h = {28'd0, tgc_up_dn[3], tgc_profile[7:6],   tgc_run[3]};
wire [31:0] reg_0018h = {28'd0, tgc_up_dn[4], tgc_profile[9:8],   tgc_run[4]};
wire [31:0] reg_001ch = {28'd0, tgc_up_dn[5], tgc_profile[11:10], tgc_run[5]};
wire [31:0] reg_0020h = {28'd0, tgc_up_dn[6], tgc_profile[13:12], tgc_run[6]};
wire [31:0] reg_0024h = {28'd0, tgc_up_dn[7], tgc_profile[15:14], tgc_run[7]};
wire [31:0] reg_0028h = {chn_idle, fifo_full, fifo_empty, link_ready};
wire [31:0] reg_002ch = {8'd0, link_error_sta, data_error_sta, fifo_of_sta};
wire [31:0] reg_0030h = {rx_reset_done, pll_lock, 8'd0, link_ready};
wire [31:0] reg_0034h = {sysref_cnt, 7'd0, sysref_level, sysref_sta};
wire [31:0] reg_0038h = {byte_aligned, lane_ready};
wire [31:0] reg_003ch = {16'd0, comma_detected};
wire [31:0] reg_0040h = {notintable_sta, disparity_sta};

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
