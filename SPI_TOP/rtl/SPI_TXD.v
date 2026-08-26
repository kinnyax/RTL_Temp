`timescale 1ns / 1ps
`default_nettype none

module SPI_TXD #(
    parameter integer       UDLY                        = 1
)(
    input   wire            SPI_CLK                                     ,
    input   wire            SPI_RST_N                                   ,
    input   wire            pack_reset                                  ,
    input   wire            unit_is_16bit                               ,
    input   wire            unit_take                                   ,
    input   wire            fifo_empty                                  ,
    input   wire    [31:0]  fifo_rdata                                  ,
    output  wire            fifo_ren                                    ,
    output  wire    [15:0]  unit_data                                   ,
    output  reg             underflow_pulse
);

reg         [31:0]          held_word                                   ;
reg         [1:0]           unit_index                                  ;

wire                        first_unit                                  ;

assign first_unit = (unit_index == 2'd0);

assign unit_data = unit_is_16bit ?
                   (first_unit ?
                    (fifo_empty ? 16'h0000 : fifo_rdata[31:16]) :
                    held_word[15:0]) :
                   ((unit_index == 2'd0) ?
                    (fifo_empty ? 16'h0000 :
                                  {8'h00, fifo_rdata[31:24]}) :
                    (unit_index == 2'd1) ?
                    {8'h00, held_word[23:16]} :
                    (unit_index == 2'd2) ?
                    {8'h00, held_word[15:8]} :
                    {8'h00, held_word[7:0]});

assign fifo_ren = unit_take & first_unit & ~fifo_empty;

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        held_word  <= #UDLY 32'h0000_0000;
        unit_index <= #UDLY 2'd0;
    end
    else if(pack_reset) begin
        held_word  <= #UDLY 32'h0000_0000;
        unit_index <= #UDLY 2'd0;
    end
    else if(unit_take) begin
        if(first_unit)
            held_word <= #UDLY
                         (fifo_empty ? 32'h0000_0000 : fifo_rdata);
        if(unit_is_16bit)
            unit_index <= #UDLY first_unit ? 2'd1 : 2'd0;
        else
            unit_index <= #UDLY
                          (unit_index == 2'd3) ?
                          2'd0 : (unit_index + 2'd1);
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N)
        underflow_pulse <= #UDLY 1'b0;
    else begin
        underflow_pulse <= #UDLY 1'b0;
        if(unit_take & first_unit & fifo_empty)
            underflow_pulse <= #UDLY 1'b1;
    end
end

endmodule

`default_nettype wire
