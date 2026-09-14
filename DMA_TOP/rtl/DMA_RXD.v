`timescale 1ns / 1ps

module DMA_RXD(
    input                                   src_clk                                        ,
    input                                   src_rst_n                                      ,

    input               [31:0]              s_axis_tdata                                   ,
    input                                   s_axis_tlast                                   ,
    input                                   s_axis_tvalid                                  ,
    output    wire                          s_axis_tready                                  ,

    input               [31:0]              chn_ctl                                        ,
    input                                   chn_en                                         ,

    input                                   fifo_full                                      ,
    input                                   fifo_wr_ready                                  ,
    output    wire      [255:0]             fifo_wdat                                      ,
    output    wire                          fifo_winc
);

wire                    [ 1:0]              width                                          ;
wire                                        axis_handshake                                 ;
wire                                        beat_full                                      ;
wire                                        beat_complete                                  ;
wire                                        beat_capture                                   ;
wire                                        beat_hold_ready                                ;
wire                    [ 7:0]              slot_shift                                     ;
wire                    [255:0]             item_data                                      ;
wire                    [255:0]             pack_data_next                                 ;

reg                     [ 5:0]              slot_last                                      ;
reg                     [ 5:0]              slot_cnt                                       ;
reg                     [255:0]             pack_data                                      ;
reg                     [255:0]             fifo_data_hold                                 ;
reg                                         fifo_data_vld                                  ;

//////////////////////////////////////////////////
//1. AXI4-Stream Control
//////////////////////////////////////////////////
assign width = chn_ctl[3:2];

always @(*) begin
    case(width)
        2'b00   : slot_last = 6'd31;
        2'b01   : slot_last = 6'd15;
        2'b10   : slot_last = 6'd7;
        2'b11   : slot_last = 6'd7;
        default : slot_last = 6'd31;
    endcase
end

assign beat_full       = (slot_cnt == slot_last);
assign beat_complete   = s_axis_tlast | beat_full;
assign beat_hold_ready = ~fifo_data_vld | ~fifo_full;
assign s_axis_tready   = chn_en & fifo_wr_ready & (~beat_complete | beat_hold_ready);
assign axis_handshake  = s_axis_tvalid & s_axis_tready;
assign beat_capture    = axis_handshake & beat_complete;

//////////////////////////////////////////////////
//2. Beat Packing
//////////////////////////////////////////////////
assign slot_shift = (width == 2'b00) ? {slot_cnt[4:0], 3'd0} :
                    (width == 2'b01) ? {slot_cnt[3:0], 4'd0} :
                                                        {slot_cnt[2:0], 5'd0};
assign item_data = (width == 2'b00) ? {248'd0, s_axis_tdata[7:0]} :
                   (width == 2'b01) ? {240'd0, s_axis_tdata[15:0]} :
                   (width == 2'b10) ? {224'd0, 8'd0, s_axis_tdata[23:0]} :
                                                        {224'd0, s_axis_tdata};
assign pack_data_next = pack_data | (item_data << slot_shift);

always @(posedge src_clk or negedge src_rst_n) begin
    if(~src_rst_n) begin
        slot_cnt  <= 6'd0;
        pack_data <= 256'd0;
    end
    else if(~chn_en) begin
        slot_cnt  <= 6'd0;
        pack_data <= 256'd0;
    end
    else if(beat_capture) begin
        slot_cnt  <= 6'd0;
        pack_data <= 256'd0;
    end
    else if(axis_handshake) begin
        slot_cnt  <= slot_cnt + 6'd1;
        pack_data <= pack_data_next;
    end
end

//////////////////////////////////////////////////
//3. FIFO Write
//////////////////////////////////////////////////
assign fifo_wdat = fifo_data_hold;
assign fifo_winc = fifo_data_vld & chn_en & fifo_wr_ready & ~fifo_full;

always @(posedge src_clk or negedge src_rst_n) begin
    if(~src_rst_n) begin
        fifo_data_hold <= 256'd0;
        fifo_data_vld  <= 1'd0;
    end
    else if(~chn_en) begin
        fifo_data_hold <= 256'd0;
        fifo_data_vld  <= 1'd0;
    end
    else if(beat_capture) begin
        fifo_data_hold <= pack_data_next;
        fifo_data_vld  <= 1'd1;
    end
    else if(fifo_winc)
        fifo_data_vld <= 1'd0;
end

endmodule
