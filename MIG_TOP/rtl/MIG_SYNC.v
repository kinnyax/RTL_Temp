`timescale 1ns / 1ps

module MIG_SYNC(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   calib_complete                                 ,
    output    wire                          calib_complete_sync
);

//////////////////////////////////////////////////
//1. Level Synchronizer
//////////////////////////////////////////////////
level_sync calib_complete_level_sync(.clk(sys_clk),.rst_n(sys_rst_n),.in(calib_complete),.out(calib_complete_sync));

endmodule
