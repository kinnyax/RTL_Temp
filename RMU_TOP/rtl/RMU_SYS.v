`timescale 1ns / 1ps

module RMU_SYS(
    input                                   SYS_CLK                                        ,
    input                                   EXT_RST_N                                      ,
    input                                   SYS_CLK_READY                                  ,
    output    wire                          SYS_RST_N
);

parameter                                   UDLY                     = 1                   ;

//////////////////////////////////////////////////
//1. Processor System Reset
//////////////////////////////////////////////////
processor processor(
    .slowest_sync_clk                    (SYS_CLK                                      ),
    .ext_reset_in                        (~EXT_RST_N                                   ),
    .aux_reset_in                        (1'd0                                         ),
    .mb_debug_sys_rst                    (1'd0                                         ),
    .dcm_locked                          (SYS_CLK_READY                                ),
    .mb_reset                            (                                             ),
    .bus_struct_reset                    (                                             ),
    .peripheral_reset                    (                                             ),
    .interconnect_aresetn                (                                             ),
    .peripheral_aresetn                  (SYS_RST_N                                    )
);

endmodule
