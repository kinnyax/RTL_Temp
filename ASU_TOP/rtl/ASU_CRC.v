`timescale 1ns / 1ps

module ASU_CRC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   crc_init                                       ,
    input                                   crc_valid                                      ,
    input                                   crc_data                                       ,
    output    reg       [15:0]              crc_value
);

parameter                                   UDLY                     = 1                   ;

wire                    [15:0]              crc_base                                       ;
wire                                        crc_feedback                                   ;
wire                    [15:0]              crc_next                                       ;

//////////////////////////////////////////////////
//1. CRC Update
//////////////////////////////////////////////////
assign crc_base     = crc_init ? 16'hFFFF : crc_value;
assign crc_feedback = crc_base[15] ^ crc_data;
assign crc_next     = {crc_base[14:0], 1'd0} ^
                      ({16{crc_feedback}} & 16'h1021);

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        crc_value <= #UDLY 16'hFFFF;
    else if(crc_valid)
        crc_value <= #UDLY crc_next;
    else if(crc_init)
        crc_value <= #UDLY 16'hFFFF;
end

endmodule

