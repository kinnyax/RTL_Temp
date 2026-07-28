`timescale 1ns / 1ps
`default_nettype none

// One-byte CRC-16/CCITT-FALSE update, MSB first, polynomial 16'h1021.
module CRC16
(
    input  wire [15:0]                      crc_in                                      ,
    input  wire [7:0]                       data_in                                     ,
    output wire [15:0]                      crc_out
);

parameter integer                           UDLY                        = 1              ;

wire [15:0]                                 crc_bit_1                                    ;
wire [15:0]                                 crc_bit_2                                    ;
wire [15:0]                                 crc_bit_3                                    ;
wire [15:0]                                 crc_bit_4                                    ;
wire [15:0]                                 crc_bit_5                                    ;
wire [15:0]                                 crc_bit_6                                    ;
wire [15:0]                                 crc_bit_7                                    ;

assign crc_bit_1 = {crc_in[14:0], 1'b0} ^
                   ({16{crc_in[15] ^ data_in[7]}} & 16'h1021);
assign crc_bit_2 = {crc_bit_1[14:0], 1'b0} ^
                   ({16{crc_bit_1[15] ^ data_in[6]}} & 16'h1021);
assign crc_bit_3 = {crc_bit_2[14:0], 1'b0} ^
                   ({16{crc_bit_2[15] ^ data_in[5]}} & 16'h1021);
assign crc_bit_4 = {crc_bit_3[14:0], 1'b0} ^
                   ({16{crc_bit_3[15] ^ data_in[4]}} & 16'h1021);
assign crc_bit_5 = {crc_bit_4[14:0], 1'b0} ^
                   ({16{crc_bit_4[15] ^ data_in[3]}} & 16'h1021);
assign crc_bit_6 = {crc_bit_5[14:0], 1'b0} ^
                   ({16{crc_bit_5[15] ^ data_in[2]}} & 16'h1021);
assign crc_bit_7 = {crc_bit_6[14:0], 1'b0} ^
                   ({16{crc_bit_6[15] ^ data_in[1]}} & 16'h1021);
assign crc_out   = {crc_bit_7[14:0], 1'b0} ^
                   ({16{crc_bit_7[15] ^ data_in[0]}} & 16'h1021);

endmodule

`default_nettype wire
