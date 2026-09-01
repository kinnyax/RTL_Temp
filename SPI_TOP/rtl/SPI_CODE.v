`timescale 1ns / 1ps

module SPI_CODE(
    input               [31:0]              spi_ctl                                        ,
    input               [31:0]              cs_cfg                                         ,
    input                                   spi_cs_n                                       ,
    input               [ 3:0]              spi_cs_in                                      ,

    output    wire      [ 3:0]              spi_cs_out                                     ,
    output    wire                          cs_sel
);

parameter                                   UDLY                     = 1                   ;

wire                                        ms_mode                                        ;
wire                    [ 2:0]              cs_addr                                        ;
wire                    [ 3:0]              master_cs                                      ;

//////////////////////////////////////////////////
//1. CS Source Select And Decode
//////////////////////////////////////////////////
assign ms_mode    = spi_ctl[1];
assign cs_addr    = cs_cfg[2:0];
assign master_cs  = {spi_cs_n, cs_addr};
assign spi_cs_out = ms_mode ? master_cs : spi_cs_in;
assign cs_sel     = ~ms_mode & ~spi_cs_in[3] & (spi_cs_in[2:0] == cs_addr);

endmodule
