`timescale 1ns / 1ps

module ADC_REG(
    input  wire                             sys_clk                                     ,
    input  wire                             sys_rst_n                                   ,

    input  wire [15:0]                      s_axi_awaddr                                ,
    input  wire                             s_axi_awvalid                               ,
    output wire                             s_axi_awready                               ,
    input  wire [31:0]                      s_axi_wdata                                 ,
    input  wire [ 3:0]                      s_axi_wstrb                                 ,
    input  wire                             s_axi_wvalid                                ,
    output wire                             s_axi_wready                                ,
    output wire [ 1:0]                      s_axi_bresp                                 ,
    output reg                              s_axi_bvalid                                ,
    input  wire                             s_axi_bready                                ,

    input  wire [15:0]                      s_axi_araddr                                ,
    input  wire                             s_axi_arvalid                               ,
    output wire                             s_axi_arready                               ,
    output reg  [31:0]                      s_axi_rdata                                 ,
    output wire [ 1:0]                      s_axi_rresp                                 ,
    output reg                              s_axi_rvalid                                ,
    input  wire                             s_axi_rready                                ,

    input  wire [ 7:0]                      link_ready                                 ,
    input  wire [ 7:0]                      fifo_empty                                 ,
    input  wire [ 7:0]                      fifo_full                                  ,
    input  wire [ 7:0]                      chn_idle                                   ,
    input  wire [ 7:0]                      pll_lock                                   ,
    input  wire [ 7:0]                      rx_reset_done                              ,
    input  wire [15:0]                      lane_ready                                 ,
    input  wire [15:0]                      byte_aligned                               ,
    input  wire [15:0]                      comma_detected                             ,
    input  wire                             sysref_level                               ,
    input  wire [ 7:0]                      fifo_overflow_evt                          ,
    input  wire [ 7:0]                      data_error_evt                             ,
    input  wire [ 7:0]                      link_error_evt                             ,
    input  wire [ 7:0]                      sysref_seen_evt                            ,
    input  wire [15:0]                      disparity_evt                              ,
    input  wire [15:0]                      notintable_evt                             ,
    input  wire [ 7:0]                      tgc_done_evt                               ,

    output reg  [31:0]                      adc_ctl                                     ,
    output reg  [31:0]                      frm_cfg                                     ,
    output reg  [ 7:0]                      tgc_cmd_evt                                 ,
    output reg  [15:0]                      tgc_profile                                 ,
    output reg  [ 7:0]                      tgc_up_dn
);

parameter                                   UDLY                        = 1             ;

localparam [15:0]                           ADDR_ADC_CTL                = 16'h0000      ;
localparam [15:0]                           ADDR_FRM_CFG                = 16'h0004      ;
localparam [15:0]                           ADDR_TGC_FIRST              = 16'h0008      ;
localparam [15:0]                           ADDR_TGC_LAST               = 16'h0024      ;
localparam [15:0]                           ADDR_ADC_STA                = 16'h0028      ;
localparam [15:0]                           ADDR_ADC_PD                 = 16'h002c      ;
localparam [15:0]                           ADDR_PHY_STA                = 16'h0030      ;
localparam [15:0]                           ADDR_SYSREF_STA             = 16'h0034      ;
localparam [15:0]                           ADDR_LANE_STA               = 16'h0038      ;
localparam [15:0]                           ADDR_COMMA_STA              = 16'h003c      ;
localparam [15:0]                           ADDR_LANE_PD                = 16'h0040      ;

reg        [15:0]                           axi_awaddr_r                                ;
reg        [31:0]                           axi_wdata_r                                 ;
reg                                         axi_aw_hold                                 ;
reg                                         axi_w_hold                                  ;

reg        [ 7:0]                           fifo_of_sta                                 ;
reg        [ 7:0]                           data_error_sta                              ;
reg        [ 7:0]                           link_error_sta                              ;
reg        [ 7:0]                           sysref_sta                                  ;
reg        [15:0]                           disparity_sta                               ;
reg        [15:0]                           notintable_sta                              ;
reg                                         sysref_level_r                              ;
reg        [15:0]                           sysref_cnt                                  ;
reg        [ 7:0]                           tgc_run                                     ;
reg        [31:0]                           io_rdata                                    ;

wire                                        write_commit                               ;
wire                                        read_accept                                ;
wire                                        write_adc_ctl                              ;
wire                                        write_frm_cfg                              ;
wire                                        write_tgc                                  ;
wire        [2:0]                           write_tgc_idx                              ;
wire                                        static_write_safe                          ;
wire                                        write_adc_pd                               ;
wire                                        write_sysref_sta                           ;
wire                                        write_lane_pd                              ;
wire                                        sysref_rise                                ;

assign s_axi_awready = sys_rst_n & ~axi_aw_hold & ~s_axi_bvalid;
assign s_axi_wready  = sys_rst_n & ~axi_w_hold  & ~s_axi_bvalid;
assign s_axi_bresp   = 2'b00;
assign s_axi_arready = sys_rst_n & ~s_axi_rvalid;
assign s_axi_rresp   = 2'b00;

assign write_commit     = axi_aw_hold & axi_w_hold & ~s_axi_bvalid;
assign read_accept      = s_axi_arvalid & s_axi_arready;
assign write_adc_ctl    = write_commit & (axi_awaddr_r == ADDR_ADC_CTL);
assign write_frm_cfg    = write_commit & (axi_awaddr_r == ADDR_FRM_CFG);
assign write_adc_pd     = write_commit & (axi_awaddr_r == ADDR_ADC_PD);
assign write_sysref_sta = write_commit & (axi_awaddr_r == ADDR_SYSREF_STA);
assign write_lane_pd    = write_commit & (axi_awaddr_r == ADDR_LANE_PD);
assign write_tgc        = write_commit & (axi_awaddr_r >= ADDR_TGC_FIRST) &
                          (axi_awaddr_r <= ADDR_TGC_LAST) & (axi_awaddr_r[1:0] == 2'b00);
assign write_tgc_idx    = axi_awaddr_r[5:2] - 4'd2;
assign static_write_safe = (adc_ctl[7:0] == 8'd0) & (chn_idle == 8'hff);
assign sysref_rise       = sysref_level & ~sysref_level_r;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        axi_awaddr_r <= #UDLY 16'd0;
        axi_aw_hold  <= #UDLY 1'b0;
    end
    else if(s_axi_awvalid & s_axi_awready) begin
        axi_awaddr_r <= #UDLY s_axi_awaddr;
        axi_aw_hold  <= #UDLY 1'b1;
    end
    else if(write_commit) begin
        axi_aw_hold <= #UDLY 1'b0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        axi_wdata_r <= #UDLY 32'd0;
        axi_w_hold  <= #UDLY 1'b0;
    end
    else if(s_axi_wvalid & s_axi_wready) begin
        axi_wdata_r <= #UDLY s_axi_wdata;
        axi_w_hold  <= #UDLY 1'b1;
    end
    else if(write_commit) begin
        axi_w_hold <= #UDLY 1'b0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        s_axi_bvalid <= #UDLY 1'b0;
    else if(write_commit)
        s_axi_bvalid <= #UDLY 1'b1;
    else if(s_axi_bvalid & s_axi_bready)
        s_axi_bvalid <= #UDLY 1'b0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        s_axi_rdata  <= #UDLY 32'd0;
        s_axi_rvalid <= #UDLY 1'b0;
    end
    else if(read_accept) begin
        s_axi_rdata  <= #UDLY io_rdata;
        s_axi_rvalid <= #UDLY 1'b1;
    end
    else if(s_axi_rvalid & s_axi_rready) begin
        s_axi_rvalid <= #UDLY 1'b0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        adc_ctl <= #UDLY 32'd0;
        frm_cfg <= #UDLY 32'd0;
    end
    else begin
        if(write_adc_ctl) begin
            adc_ctl[15:0] <= #UDLY axi_wdata_r[15:0];

            if(static_write_safe) begin
                adc_ctl[31:30] <= #UDLY axi_wdata_r[31:30];
                adc_ctl[29:28] <= #UDLY 2'd0;
                adc_ctl[27:26] <= #UDLY axi_wdata_r[27:26];
                adc_ctl[25]    <= #UDLY axi_wdata_r[25];
                adc_ctl[24:16] <= #UDLY 9'd0;
            end
        end

        if(write_frm_cfg & static_write_safe)
            frm_cfg <= #UDLY {22'd0, axi_wdata_r[9:0]};
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
            tgc_profile[write_tgc_idx*2 +: 2] <= #UDLY axi_wdata_r[2:1];
            tgc_up_dn[write_tgc_idx]          <= #UDLY axi_wdata_r[3];

            if(axi_wdata_r[0] & adc_ctl[write_tgc_idx]) begin
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
        fifo_of_sta    <= #UDLY (fifo_of_sta & ~(axi_wdata_r[7:0]   & {8{write_adc_pd}})) | fifo_overflow_evt;
        data_error_sta <= #UDLY (data_error_sta & ~(axi_wdata_r[15:8]  & {8{write_adc_pd}})) | data_error_evt;
        link_error_sta <= #UDLY (link_error_sta & ~(axi_wdata_r[23:16] & {8{write_adc_pd}})) | link_error_evt;
        sysref_sta     <= #UDLY (sysref_sta & ~(axi_wdata_r[7:0] & {8{write_sysref_sta}})) | sysref_seen_evt;
        disparity_sta  <= #UDLY (disparity_sta & ~(axi_wdata_r[15:0] & {16{write_lane_pd}})) | disparity_evt;
        notintable_sta <= #UDLY (notintable_sta & ~(axi_wdata_r[31:16] & {16{write_lane_pd}})) | notintable_evt;
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

always @(*) begin
    io_rdata = 32'd0;

    case(s_axi_araddr)
        ADDR_ADC_CTL:    io_rdata = adc_ctl;
        ADDR_FRM_CFG:    io_rdata = frm_cfg;
        16'h0008:        io_rdata = {28'd0, tgc_up_dn[0], tgc_profile[1:0],   tgc_run[0]};
        16'h000c:        io_rdata = {28'd0, tgc_up_dn[1], tgc_profile[3:2],   tgc_run[1]};
        16'h0010:        io_rdata = {28'd0, tgc_up_dn[2], tgc_profile[5:4],   tgc_run[2]};
        16'h0014:        io_rdata = {28'd0, tgc_up_dn[3], tgc_profile[7:6],   tgc_run[3]};
        16'h0018:        io_rdata = {28'd0, tgc_up_dn[4], tgc_profile[9:8],   tgc_run[4]};
        16'h001c:        io_rdata = {28'd0, tgc_up_dn[5], tgc_profile[11:10], tgc_run[5]};
        16'h0020:        io_rdata = {28'd0, tgc_up_dn[6], tgc_profile[13:12], tgc_run[6]};
        16'h0024:        io_rdata = {28'd0, tgc_up_dn[7], tgc_profile[15:14], tgc_run[7]};
        ADDR_ADC_STA:    io_rdata = {chn_idle, fifo_full, fifo_empty, link_ready};
        ADDR_ADC_PD:     io_rdata = {8'd0, link_error_sta, data_error_sta, fifo_of_sta};
        ADDR_PHY_STA:    io_rdata = {rx_reset_done, pll_lock, 8'd0, link_ready};
        ADDR_SYSREF_STA: io_rdata = {sysref_cnt, 7'd0, sysref_level, sysref_sta};
        ADDR_LANE_STA:   io_rdata = {byte_aligned, lane_ready};
        ADDR_COMMA_STA:  io_rdata = {16'd0, comma_detected};
        ADDR_LANE_PD:    io_rdata = {notintable_sta, disparity_sta};
        default:         io_rdata = 32'd0;
    endcase
end

endmodule
