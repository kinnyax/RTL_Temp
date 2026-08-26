`timescale 1ns / 1ps
`default_nettype none

module SPI_RXD #(
    parameter integer       UDLY                        = 1
)(
    input   wire            SPI_CLK                                     ,
    input   wire            SPI_RST_N                                   ,
    input   wire            pack_reset                                  ,
    input   wire            unit_is_16bit                               ,
    input   wire            unit_valid                                  ,
    input   wire            unit_last                                   ,
    input   wire    [15:0]  unit_data                                   ,
    input   wire            fifo_full                                   ,
    output  reg             fifo_wen                                    ,
    output  reg     [31:0]  fifo_wdata                                  ,
    output  reg             overflow_pulse
);

reg         [31:0]          pack_word                                   ;
reg         [1:0]           unit_index                                  ;
reg         [31:0]          assembled_word                              ;

wire                        word_complete                               ;
wire                        emit_word                                   ;

assign word_complete = unit_is_16bit ?
                       (unit_index == 2'd1) :
                       (unit_index == 2'd3);
assign emit_word = unit_valid & (word_complete | unit_last);

always @(*) begin
    assembled_word = pack_word;
    if(unit_is_16bit) begin
        if(unit_index == 2'd0)
            assembled_word = {unit_data, 16'h0000};
        else
            assembled_word = {pack_word[31:16], unit_data};
    end
    else begin
        if(unit_index == 2'd0)
            assembled_word = {unit_data[7:0], 24'h00_0000};
        else if(unit_index == 2'd1)
            assembled_word = {pack_word[31:24],
                              unit_data[7:0], 16'h0000};
        else if(unit_index == 2'd2)
            assembled_word = {pack_word[31:16],
                              unit_data[7:0], 8'h00};
        else
            assembled_word = {pack_word[31:8], unit_data[7:0]};
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        pack_word  <= #UDLY 32'h0000_0000;
        unit_index <= #UDLY 2'd0;
    end
    else if(pack_reset) begin
        pack_word  <= #UDLY 32'h0000_0000;
        unit_index <= #UDLY 2'd0;
    end
    else if(unit_valid) begin
        if(word_complete | unit_last) begin
            pack_word  <= #UDLY 32'h0000_0000;
            unit_index <= #UDLY 2'd0;
        end
        else begin
            pack_word  <= #UDLY assembled_word;
            unit_index <= #UDLY unit_index + 2'd1;
        end
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        fifo_wen        <= #UDLY 1'b0;
        fifo_wdata      <= #UDLY 32'h0000_0000;
        overflow_pulse  <= #UDLY 1'b0;
    end
    else begin
        fifo_wen       <= #UDLY 1'b0;
        overflow_pulse <= #UDLY 1'b0;
        if(emit_word) begin
            if(fifo_full)
                overflow_pulse <= #UDLY 1'b1;
            else begin
                fifo_wen   <= #UDLY 1'b1;
                fifo_wdata <= #UDLY assembled_word;
            end
        end
    end
end

endmodule

`default_nettype wire
