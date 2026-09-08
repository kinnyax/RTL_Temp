`timescale 1ns / 1ps

module DMA_TXD(
    input                                   dma_clk                                        ,
    input                                   dma_rst_n                                      ,

    input               [31:0]              chn_addr                                       ,
    input               [12:0]              chn_num                                        ,
    input               [31:0]              chn_ctl                                        ,
    input                                   chn_en                                         ,

    input               [255:0]             fifo_rdat                                      ,
    input                                   fifo_empty                                     ,
    input               [ 8:0]              fifo_rlevel                                    ,
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

    output    reg                           chn_busy                                       ,
    output    reg                           half_trans                                     ,
    output    reg                           trans_comp                                     ,
    output    reg                           axi_error
);

parameter                                   UDLY                     = 1                   ;

localparam                                  TXD_IDLE                 = 3'd0                ;
localparam                                  TXD_AW                   = 3'd1                ;
localparam                                  TXD_WDATA                = 3'd2                ;
localparam                                  TXD_BRESP                = 3'd3                ;
localparam                                  TXD_END                  = 3'd4                ;

wire                    [ 1:0]              width                                          ;
wire                    [ 2:0]              burst_size                                     ;
wire                                        loop                                           ;
wire                    [12:0]              remain_data                                    ;
wire                    [12:0]              cnt_next                                       ;
wire                    [12:0]              half_cnt                                       ;
wire                                        start_event                                    ;
wire                                        task_start                                     ;
wire                                        stop_req                                       ;
wire                                        txd_start                                      ;
wire                                        aw_handshake                                   ;
wire                                        w_handshake                                    ;
wire                                        b_handshake                                    ;
wire                                        beat_last                                      ;
wire                                        txd_idle                                       ;
wire                                        txd_aw                                         ;
wire                                        txd_wdata                                      ;
wire                                        txd_bresp                                      ;
wire                                        txd_end                                        ;
wire                                        resp_ok                                        ;
wire                                        burst_commit                                   ;
wire                                        half_done                                      ;
wire                                        trans_done                                     ;
wire                                        burst_last                                     ;
wire                                        fifo_ready                                     ;

reg                     [ 5:0]              pack_num                                       ;
reg                     [ 7:0]              burst_max                                      ;
reg                     [10:0]              beat_num_raw                                   ;
reg                     [ 5:0]              byte_num_raw                                   ;
reg                     [10:0]              beat_num                                       ;
reg                     [12:0]              data_num                                       ;
reg                     [ 5:0]              byte_num                                       ;
reg                     [ 7:0]              beat_max                                       ;
reg                     [12:0]              burst_num                                      ;
reg                     [31:0]              strb_last                                      ;
reg                                         start_armed                                    ;
reg                     [ 2:0]              txd_state                                      ;
reg                     [ 2:0]              txd_state_next                                 ;
reg                     [ 7:0]              beat_cnt                                       ;
reg                     [31:0]              axi_addr                                       ;
reg                     [12:0]              data_cnt                                       ;
reg                     [ 1:0]              bresp                                          ;
reg                                         bid                                            ;
reg                                         stop_pending                                   ;

//////////////////////////////////////////////////
//1. Configuration And Burst Parameters
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

assign remain_data = chn_num - data_cnt;

always @(*) begin
    case(width)
        2'b00 : begin
            pack_num = 6'd32;
            beat_num_raw = {3'd0, remain_data[12:5]} + {10'd0, |remain_data[4:0]};
            byte_num_raw = (remain_data[4:0] == 5'd0) ? 6'd32 : {1'd0, remain_data[4:0]};
        end
        2'b01 : begin
            pack_num = 6'd16;
            beat_num_raw = {2'd0, remain_data[12:4]} + {10'd0, |remain_data[3:0]};
            byte_num_raw = (remain_data[3:0] == 4'd0) ? 6'd32 : {1'd0, remain_data[3:0], 1'd0};
        end
        2'b10, 2'b11 : begin
            pack_num = 6'd8;
            beat_num_raw = {1'd0, remain_data[12:3]} + {10'd0, |remain_data[2:0]};
            byte_num_raw = (remain_data[2:0] == 3'd0) ? 6'd32 : {1'd0, remain_data[2:0], 2'd0};
        end
        default : begin
            pack_num = 6'd32;
            beat_num_raw = {3'd0, remain_data[12:5]} + {10'd0, |remain_data[4:0]};
            byte_num_raw = (remain_data[4:0] == 5'd0) ? 6'd32 : {1'd0, remain_data[4:0]};
        end
    endcase
end

assign burst_last = (beat_num_raw <= {3'd0, burst_max});

always @(*) begin
    beat_num = beat_num_raw;
    data_num = remain_data;
    byte_num = byte_num_raw;
    if(~burst_last) begin
        beat_num = {3'd0, burst_max};
        data_num = {5'd0, burst_max} * pack_num;
        byte_num = 6'd32;
    end
end

assign fifo_ready = (beat_num != 11'd0) & ({2'd0, fifo_rlevel} >= beat_num);
assign stop_req    = ~chn_en | stop_pending;
assign txd_start   = txd_idle & chn_busy & ~stop_req & fifo_ready;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n) begin
        beat_max  <= #UDLY 8'd0;
        burst_num <= #UDLY 13'd0;
        strb_last <= #UDLY 32'd0;
    end
    else if(txd_start) begin
        beat_max  <= #UDLY beat_num[7:0] - 8'd1;
        burst_num <= #UDLY data_num;
        if(byte_num == 6'd32)
            strb_last <= #UDLY 32'hffff_ffff;
        else
            strb_last <= #UDLY 32'hffff_ffff >> (6'd32 - byte_num);
    end
end

assign start_event = chn_en & start_armed;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        start_armed <= #UDLY 1'd0;
    else if(~chn_en)
        start_armed <= #UDLY 1'd1;
    else if(start_event)
        start_armed <= #UDLY 1'd0;
end

//////////////////////////////////////////////////
//2. AXI4-Full Write
//////////////////////////////////////////////////
always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        txd_state <= #UDLY TXD_IDLE;
    else
        txd_state <= #UDLY txd_state_next;
end

assign aw_handshake = m_axi_awvalid & m_axi_awready;
assign w_handshake  = m_axi_wvalid & m_axi_wready;
assign b_handshake  = m_axi_bvalid & m_axi_bready;
assign beat_last    = (beat_cnt == beat_max);

always @(*) begin
    case(txd_state)
        TXD_IDLE : begin
            if(txd_start)
                txd_state_next = TXD_AW;
            else
                txd_state_next = TXD_IDLE;
        end
        TXD_AW : begin
            if(aw_handshake)
                txd_state_next = TXD_WDATA;
            else if(stop_req)
                txd_state_next = TXD_IDLE;
            else
                txd_state_next = TXD_AW;
        end
        TXD_WDATA : begin
            if(w_handshake & beat_last)
                txd_state_next = TXD_BRESP;
            else
                txd_state_next = TXD_WDATA;
        end
        TXD_BRESP : begin
            if(b_handshake)
                txd_state_next = TXD_END;
            else
                txd_state_next = TXD_BRESP;
        end
        TXD_END : begin
            txd_state_next = TXD_IDLE;
        end
        default : begin
            txd_state_next = TXD_IDLE;
        end
    endcase
end

assign txd_idle  = (txd_state == TXD_IDLE);
assign txd_aw    = (txd_state == TXD_AW);
assign txd_wdata = (txd_state == TXD_WDATA);
assign txd_bresp = (txd_state == TXD_BRESP);
assign txd_end   = (txd_state == TXD_END);

assign m_axi_awid    = 1'd0;
assign m_axi_awaddr  = axi_addr;
assign m_axi_awlen   = beat_max;
assign m_axi_awsize  = 3'd5;
assign m_axi_awburst = 2'b01;
assign m_axi_awlock  = 1'd0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot  = 3'b000;
assign m_axi_awqos   = 4'd0;
assign m_axi_awvalid = txd_aw;

assign m_axi_wdata  = fifo_rdat;
assign m_axi_wstrb  = beat_last ? strb_last : 32'hffff_ffff;
assign m_axi_wlast  = m_axi_wvalid & beat_last;
assign m_axi_wvalid = txd_wdata & ~fifo_empty;
assign fifo_rinc    = w_handshake;

assign m_axi_bready = txd_bresp;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        beat_cnt <= #UDLY 8'd0;
    else if(txd_idle)
        beat_cnt <= #UDLY 8'd0;
    else if(w_handshake)
        beat_cnt <= #UDLY beat_cnt + 8'd1;
end

//////////////////////////////////////////////////
//3. Status Errors And Events
//////////////////////////////////////////////////
always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n) begin
        bresp <= #UDLY 2'd0;
        bid   <= #UDLY 1'd0;
    end
    else if(b_handshake) begin
        bresp <= #UDLY m_axi_bresp;
        bid   <= #UDLY m_axi_bid;
    end
end

assign resp_ok = (bresp == 2'b00) & ~bid;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        stop_pending <= #UDLY 1'd0;
    else if(~chn_busy)
        stop_pending <= #UDLY 1'd0;
    else if(~chn_en)
        stop_pending <= #UDLY 1'd1;
end

assign task_start = start_event & ~chn_busy;
assign cnt_next   = data_cnt + burst_num;
assign trans_done = (cnt_next == chn_num);

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        chn_busy <= #UDLY 1'd0;
    else if(txd_end) begin
        if(~resp_ok)
            chn_busy <= #UDLY 1'd0;
        else if(trans_done) begin
            if(~loop | stop_req)
                chn_busy <= #UDLY 1'd0;
        end
        else begin
            if(stop_req)
                chn_busy <= #UDLY 1'd0;
        end
    end
    else if(txd_idle & chn_busy & stop_req)
        chn_busy <= #UDLY 1'd0;
    else if(task_start & (chn_num != 13'd0))
        chn_busy <= #UDLY 1'd1;
end

assign burst_commit = txd_end & resp_ok;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        axi_addr <= #UDLY 32'd0;
    else if(burst_commit) begin
        if(trans_done)
            axi_addr <= #UDLY chn_addr;
        else
            axi_addr <= #UDLY axi_addr + {19'd0, (beat_max + 8'd1), 5'd0};
    end
    else if(task_start)
        axi_addr <= #UDLY chn_addr;
end

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        data_cnt <= #UDLY 13'd0;
    else if(burst_commit) begin
        if(trans_done)
            data_cnt <= #UDLY 13'd0;
        else
            data_cnt <= #UDLY cnt_next;
    end
    else if(task_start)
        data_cnt <= #UDLY 13'd0;
end

assign half_cnt  = chn_num >> 1;
assign half_done = (data_cnt < half_cnt) & (cnt_next >= half_cnt);

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n) begin
        half_trans <= #UDLY 1'd0;
        trans_comp <= #UDLY 1'd0;
    end
    else begin
        half_trans <= #UDLY 1'd0;
        trans_comp <= #UDLY 1'd0;
        if(burst_commit) begin
            if(half_done)
                half_trans <= #UDLY 1'd1;
            if(trans_done)
                trans_comp <= #UDLY 1'd1;
        end
    end
end

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        axi_error <= #UDLY 1'd0;
    else begin
        axi_error <= #UDLY 1'd0;
        if(txd_end & ~resp_ok)
            axi_error <= #UDLY 1'd1;
    end
end

endmodule
