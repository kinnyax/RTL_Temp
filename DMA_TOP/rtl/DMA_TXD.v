`timescale 1ns / 1ps

module DMA_TXD(
    input                                   dev_clk                                        ,
    input                                   dev_rst_n                                      ,

    input               [31:0]              chn_addr                                       ,
    input               [12:0]              chn_num                                        ,
    input               [31:0]              chn_ctl                                        ,
    input                                   chn_en                                         ,
    input                                   chn_run                                        ,

    input               [255:0]             fifo_rdat                                      ,
    input                                   fifo_empty                                     ,
    input               [ 8:0]              fifo_rlevel                                    ,
    input                                   fifo_rd_ready                                  ,
    output    wire                          fifo_rinc                                      ,

    output    wire                          m_axi_awid                                     ,
    output    wire      [31:0]              m_axi_awaddr                                   ,
    output    wire      [ 7:0]              m_axi_awlen                                    ,
    output    wire      [ 2:0]              m_axi_awsize                                   ,
    output    wire      [ 1:0]              m_axi_awburst                                  ,
    output    wire                          m_axi_awlock                                   ,
    output    wire      [ 3:0]              m_axi_awcache                                  ,
    output    wire      [ 2:0]              m_axi_awprot                                   ,
    output    wire      [ 3:0]              m_axi_awqos                                    ,
    output    wire                          m_axi_awvalid                                  ,
    input                                   m_axi_awready                                  ,

    output    wire      [255:0]             m_axi_wdata                                    ,
    output    wire      [31:0]              m_axi_wstrb                                    ,
    output    wire                          m_axi_wlast                                    ,
    output    wire                          m_axi_wvalid                                   ,
    input                                   m_axi_wready                                   ,

    input                                   m_axi_bid                                      ,
    input               [ 1:0]              m_axi_bresp                                    ,
    input                                   m_axi_bvalid                                   ,
    output    wire                          m_axi_bready                                   ,

    output    reg                           txd_busy                                       ,
    output    reg                           half_trans                                     ,
    output    reg                           trans_comp                                     ,
    output    reg                           axi_error                                      ,
    output    reg                           run_clear
);

localparam                                  TXD_IDLE                 = 3'd0                ;
localparam                                  TXD_AW                   = 3'd1                ;
localparam                                  TXD_WDATA                = 3'd2                ;
localparam                                  TXD_BRESP                = 3'd3                ;
localparam                                  TXD_END                  = 3'd4                ;

wire                    [ 1:0]              width                                          ;
wire                    [ 2:0]              burst_size                                     ;
wire                                        loop                                           ;
wire                                        txd_run                                        ;
wire                    [ 5:0]              full_num                                       ;
wire                    [12:0]              data_remain                                    ;
wire                    [10:0]              beat_remain                                    ;
wire                    [ 8:0]              burst_num                                      ;
wire                    [ 5:0]              data_num                                       ;
wire                    [12:0]              data_inc                                       ;
wire                    [ 7:0]              beat_inc                                       ;
wire                                        beat_end                                       ;
wire                    [12:0]              addr_inc                                       ;
wire                                        burst_ready                                    ;
wire                                        task_clr                                       ;
wire                    [12:0]              half_num                                       ;
wire                                        half_end                                       ;
wire                                        data_end                                       ;
wire                                        resp_ok                                        ;
wire                                        resp_end                                       ;
wire                                        resp_err                                       ;
wire                                        trans_end                                      ;
wire                                        loop_end                                       ;
wire                                        half_set                                       ;
wire                                        data_clr                                       ;
wire                                        beat_clr                                       ;
wire                                        half_clr                                       ;
wire                                        addr_clr                                       ;
wire                                        aw_handshake                                   ;
wire                                        w_handshake                                    ;
wire                                        b_handshake                                    ;
wire                                        txd_idle                                       ;
wire                                        txd_aw                                         ;
wire                                        txd_wdata                                      ;
wire                                        txd_bresp                                      ;
wire                                        txd_end                                        ;

reg                                         txd_en                                         ;
reg                     [ 7:0]              burst_max                                      ;
reg                     [31:0]              addr_cnt                                       ;
reg                     [12:0]              data_cnt                                       ;
reg                     [ 7:0]              beat_cnt                                       ;
reg                     [ 7:0]              awlen                                          ;
reg                                         half_flag                                      ;
reg                                         task_end                                       ;
reg                     [ 2:0]              txd_fsm                                        ;
reg                     [ 2:0]              txd_fsm_nx                                     ;

//////////////////////////////////////////////////
//1. Task And Burst Planning
//////////////////////////////////////////////////
assign width      = chn_ctl[3:2];
assign burst_size = chn_ctl[6:4];
assign loop       = chn_ctl[10];

always @(*) begin
    case(burst_size)
        3'd0    : burst_max = 8'd1;
        3'd1    : burst_max = 8'd2;
        3'd2    : burst_max = 8'd4;
        3'd3    : burst_max = 8'd8;
        3'd4    : burst_max = 8'd16;
        3'd5    : burst_max = 8'd32;
        3'd6    : burst_max = 8'd64;
        3'd7    : burst_max = 8'd128;
        default : burst_max = 8'd1;
    endcase
end

assign full_num = width[1] ? 6'd8 :
                  width[0] ? 6'd16 : 6'd32;

assign data_remain = chn_num - data_cnt;
assign beat_remain = width[1] ? {1'd0, data_remain[12:3]} + {10'd0, |data_remain[2:0]} :
                     width[0] ? {2'd0, data_remain[12:4]} + {10'd0, |data_remain[3:0]} :
                                {3'd0, data_remain[12:5]} + {10'd0, |data_remain[4:0]};
assign burst_num   = (beat_remain <= {3'd0, burst_max}) ? beat_remain[8:0] : {1'd0, burst_max};
assign beat_end    = (beat_cnt == awlen);
assign burst_ready = fifo_rd_ready & (fifo_rlevel >= burst_num);

//////////////////////////////////////////////////
//2. AXI4-Full Write
//////////////////////////////////////////////////
assign aw_handshake = m_axi_awvalid & m_axi_awready;
assign w_handshake  = m_axi_wvalid & m_axi_wready;
assign b_handshake  = m_axi_bvalid & m_axi_bready;

assign txd_run   = txd_idle & txd_en & chn_run & (chn_num != 13'd0) & burst_ready;

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        txd_en <= 1'd0;
    else if(txd_idle | txd_end)
        txd_en <= chn_en;
end

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        txd_fsm <= TXD_IDLE;
    else if(~txd_en)
        txd_fsm <= TXD_IDLE;
    else
        txd_fsm <= txd_fsm_nx;
end

always @(*) begin
    case(txd_fsm)
        TXD_IDLE : begin
            if(txd_run)
                txd_fsm_nx = TXD_AW;
            else
                txd_fsm_nx = TXD_IDLE;
        end
        TXD_AW : begin
            if(aw_handshake)
                txd_fsm_nx = TXD_WDATA;
            else
                txd_fsm_nx = TXD_AW;
        end
        TXD_WDATA : begin
            if(w_handshake & beat_end)
                txd_fsm_nx = TXD_BRESP;
            else
                txd_fsm_nx = TXD_WDATA;
        end
        TXD_BRESP : begin
            if(resp_end | resp_err)
                txd_fsm_nx = TXD_END;
            else
                txd_fsm_nx = TXD_BRESP;
        end
        TXD_END : begin
            if(task_end & chn_run)
                txd_fsm_nx = TXD_END;
            else
                txd_fsm_nx = TXD_IDLE;
        end
        default : begin
            txd_fsm_nx = TXD_IDLE;
        end
    endcase
end

assign txd_idle  = (txd_fsm == TXD_IDLE);
assign txd_aw    = (txd_fsm == TXD_AW);
assign txd_wdata = (txd_fsm == TXD_WDATA);
assign txd_bresp = (txd_fsm == TXD_BRESP);
assign txd_end   = (txd_fsm == TXD_END);

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        txd_busy <= 1'd0;
    else if(~txd_en)
        txd_busy <= 1'd0;
    else
        txd_busy <= (txd_fsm_nx == TXD_AW)    |
                    (txd_fsm_nx == TXD_WDATA) |
                    (txd_fsm_nx == TXD_BRESP) |
                    (txd_fsm_nx == TXD_END);
end

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        awlen <= 8'd0;
    else if(~txd_en)
        awlen <= 8'd0;
    else if(task_clr)
        awlen <= 8'd0;
    else if(txd_run)
        awlen <= burst_num[7:0] - 8'd1;
end

assign m_axi_awid    = 1'd0;
assign m_axi_awaddr  = addr_cnt;
assign m_axi_awlen   = awlen;
assign m_axi_awsize  = 3'd5;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock  = 1'd0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot  = 3'b000;
assign m_axi_awqos   = 4'd0;
assign m_axi_awvalid = txd_aw;

assign data_num = (data_remain <= {7'd0, full_num}) ? data_remain[5:0] : full_num;
assign m_axi_wdata  = fifo_rdat;
assign m_axi_wstrb  = width[1] ? 32'hffff_ffff >> (6'd32 - {data_num[3:0], 2'd0}) :
                      width[0] ? 32'hffff_ffff >> (6'd32 - {data_num[4:0], 1'd0}) :
                                 32'hffff_ffff >> (6'd32 - data_num);
assign m_axi_wlast  = m_axi_wvalid & beat_end;
assign m_axi_wvalid = txd_wdata & fifo_rd_ready & ~fifo_empty;
assign fifo_rinc    = w_handshake;

assign m_axi_bready = txd_bresp;

//////////////////////////////////////////////////
//3. Counters And Completion
//////////////////////////////////////////////////
assign resp_ok    = (m_axi_bresp == 2'b00) & ~m_axi_bid;
assign half_num  = chn_num >> 1;
assign half_end  = (data_cnt >= half_num);
assign data_end  = (data_cnt == chn_num);
assign resp_end  = b_handshake & resp_ok;
assign resp_err  = b_handshake & ~resp_ok;
assign trans_end = resp_end & data_end;
assign loop_end  = trans_end & loop & chn_run;
assign half_set  = resp_end & half_end & ~half_flag;
assign task_clr  = (txd_end & ~chn_run) | (txd_idle & (data_cnt != 13'd0) & ~chn_run);

assign addr_clr = task_clr | loop_end | (txd_run & (data_cnt == 13'd0));
assign addr_inc = {awlen + 8'd1, 5'd0};

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        addr_cnt <= 32'd0;
    else if(~txd_en)
        addr_cnt <= chn_addr;
    else if(addr_clr)
        addr_cnt <= chn_addr;
    else if(resp_end)
        addr_cnt <= addr_cnt + {19'd0, addr_inc};
end

assign data_clr = task_clr | loop_end;
assign data_inc = data_cnt + {7'd0, data_num};

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        data_cnt <= 13'd0;
    else if(~txd_en)
        data_cnt <= 13'd0;
    else if(data_clr)
        data_cnt <= 13'd0;
    else if(w_handshake)
        data_cnt <= data_inc;
end

assign beat_clr = task_clr | txd_run;
assign beat_inc = beat_cnt + 8'd1;

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        beat_cnt <= 8'd0;
    else if(~txd_en)
        beat_cnt <= 8'd0;
    else if(beat_clr)
        beat_cnt <= 8'd0;
    else if(w_handshake)
        beat_cnt <= beat_inc;
end

assign half_clr = task_clr | loop_end;

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        half_flag <= 1'd0;
    else if(~txd_en)
        half_flag <= 1'd0;
    else if(half_clr)
        half_flag <= 1'd0;
    else if(half_set)
        half_flag <= 1'd1;
end

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n)
        task_end <= 1'd0;
    else if(~txd_en)
        task_end <= 1'd0;
    else if(task_clr)
        task_end <= 1'd0;
    else if(b_handshake)
        task_end <= resp_err | (resp_end & ~chn_run) | (trans_end & ~loop);
end

always @(posedge dev_clk or negedge dev_rst_n) begin
    if(~dev_rst_n) begin
        half_trans <= 1'd0;
        trans_comp <= 1'd0;
        axi_error  <= 1'd0;
        run_clear  <= 1'd0;
    end
    else if(~txd_en) begin
        half_trans <= 1'd0;
        trans_comp <= 1'd0;
        axi_error  <= 1'd0;
        run_clear  <= 1'd0;
    end
    else begin
        half_trans <= half_set;
        trans_comp <= trans_end;
        axi_error  <= resp_err;
        run_clear  <= resp_err | (trans_end & ~loop);
    end
end

endmodule
