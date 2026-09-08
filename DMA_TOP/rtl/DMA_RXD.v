`timescale 1ns / 1ps

module DMA_RXD(
    input                                   dma_clk                                        ,
    input                                   dma_rst_n                                      ,

    input               [31:0]              s_axis_tdata                                   ,
    input                                   s_axis_tlast                                   ,
    input                                   s_axis_tvalid                                  ,
    output    wire                          s_axis_tready                                  ,

    input               [31:0]              chn_ctl                                        ,
    input                                   chn_en                                         ,

    input                                   fifo_full                                      ,
    output    wire      [255:0]             fifo_wdat                                      ,
    output    wire                          fifo_winc
);

parameter                                   UDLY                     = 1                   ;

wire                    [ 1:0]              width                                          ;
wire                                        axis_handshake                                 ;
wire                                        beat_full                                      ;
wire                                        beat_done                                      ;
wire                                        beat_load                                      ;
wire                                        write_ready                                    ;
wire                    [ 7:0]              slot_shift                                     ;
wire                    [255:0]             axis_data                                      ;
wire                    [255:0]             beat_data_merge                                ;

reg                     [ 5:0]              slot_max                                       ;
reg                     [ 5:0]              slot_cnt                                       ;
reg                     [255:0]             beat_data_next                                 ;
reg                     [255:0]             beat_data                                      ;
reg                                         fifo_valid                                     ;

//////////////////////////////////////////////////
//1. Slot Control
//////////////////////////////////////////////////
assign width = chn_ctl[3:2];

always @(*) begin
    case(width)
        2'b00   : slot_max = 6'd31;
        2'b01   : slot_max = 6'd15;
        2'b10   : slot_max = 6'd7;
        2'b11   : slot_max = 6'd7;
        default : slot_max = 6'd31;
    endcase
end

assign beat_full      = (slot_cnt == slot_max);
assign beat_done      = s_axis_tlast | beat_full;
assign write_ready    = ~fifo_valid | ~fifo_full;
assign s_axis_tready  = chn_en & (~beat_done | write_ready);
assign axis_handshake = s_axis_tvalid & s_axis_tready;
assign beat_load      = axis_handshake & beat_done;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        slot_cnt <= #UDLY 6'd0;
    else if(~chn_en)
        slot_cnt <= #UDLY 6'd0;
    else if(beat_load)
        slot_cnt <= #UDLY 6'd0;
    else if(axis_handshake)
        slot_cnt <= #UDLY slot_cnt + 6'd1;
end

//////////////////////////////////////////////////
//2. Beat Packing
//////////////////////////////////////////////////
assign slot_shift = (width == 2'b00) ? {slot_cnt[4:0], 3'd0} :
                    (width == 2'b01) ? {slot_cnt[3:0], 4'd0} :
                                                        {slot_cnt[2:0], 5'd0};
assign axis_data = (width == 2'b00) ? {248'd0, s_axis_tdata[7:0]} :
                   (width == 2'b01) ? {240'd0, s_axis_tdata[15:0]} :
                   (width == 2'b10) ? {224'd0, 8'd0, s_axis_tdata[23:0]} :
                                                        {224'd0, s_axis_tdata};
assign beat_data_merge = beat_data_next | (axis_data << slot_shift);

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n)
        beat_data_next <= #UDLY 256'd0;
    else if(~chn_en)
        beat_data_next <= #UDLY 256'd0;
    else if(beat_load)
        beat_data_next <= #UDLY 256'd0;
    else if(axis_handshake)
        beat_data_next <= #UDLY beat_data_merge;
end

//////////////////////////////////////////////////
//3. FIFO Write
//////////////////////////////////////////////////
assign fifo_wdat = beat_data;
assign fifo_winc = fifo_valid & chn_en & ~fifo_full;

always @(posedge dma_clk or negedge dma_rst_n) begin
    if(~dma_rst_n) begin
        beat_data  <= #UDLY 256'd0;
        fifo_valid <= #UDLY 1'd0;
    end
    else if(~chn_en) begin
        beat_data  <= #UDLY 256'd0;
        fifo_valid <= #UDLY 1'd0;
    end
    else if(beat_load) begin
        beat_data  <= #UDLY beat_data_merge;
        fifo_valid <= #UDLY 1'd1;
    end
    else if(fifo_winc)
        fifo_valid <= #UDLY 1'd0;
end

endmodule
