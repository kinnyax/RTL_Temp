`timescale 1ns / 1ps

module MIG_SYNC #(
    parameter integer                       UDLY                        = 1
)(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             MIG_CLK                                     ,
    input  wire                             MIG_RST_N                                   ,
    input  wire                             MIG_RST_EN                                  ,
    input  wire                             INIT_CALIB_COMPLETE                         ,
    input  wire                             UI_RST_ACTIVE                               ,
    output wire                             INIT_CALIB_COMPLETE_SYNC                    ,
    output wire                             UI_RST_ACTIVE_SYNC                          ,
    output wire                             MIG_READY                                   ,
    output wire                             MIG_MEM_RST_N                               ,
    output wire                             MIG_MEM_SYS_RST_N
);

wire                                     mig_mem_release_n                              ;

assign mig_mem_release_n  = MIG_RST_N
                          & INIT_CALIB_COMPLETE
                          & ~UI_RST_ACTIVE;

assign MIG_READY          = INIT_CALIB_COMPLETE_SYNC
                          & ~UI_RST_ACTIVE_SYNC
                          & MIG_RST_EN;

assign MIG_MEM_SYS_RST_N  = SYS_RST_N
                          & MIG_RST_EN
                          & MIG_READY;

MIG_LEVEL_SYNC #(
    .UDLY                                (UDLY                           ),
    .DS                                  (2                              ),
    .RV                                  (1'b0                           )
) init_calib_complete_sync_inst (
    .clk                                 (SYS_CLK                        ),
    .rst_n                               (SYS_RST_N                      ),
    .in                                  (INIT_CALIB_COMPLETE            ),
    .out                                 (INIT_CALIB_COMPLETE_SYNC       )
);

MIG_LEVEL_SYNC #(
    .UDLY                                (UDLY                           ),
    .DS                                  (2                              ),
    .RV                                  (1'b0                           )
) ui_rst_active_sync_inst (
    .clk                                 (SYS_CLK                        ),
    .rst_n                               (SYS_RST_N                      ),
    .in                                  (UI_RST_ACTIVE                  ),
    .out                                 (UI_RST_ACTIVE_SYNC             )
);

// Reset is asserted asynchronously by any unsafe MIG condition and released
// only after two MIG_CLK edges with all three release conditions stable.
MIG_LEVEL_SYNC #(
    .UDLY                                (UDLY                           ),
    .DS                                  (2                              ),
    .RV                                  (1'b0                           )
) mig_mem_reset_release_inst (
    .clk                                 (MIG_CLK                        ),
    .rst_n                               (mig_mem_release_n              ),
    .in                                  (1'b1                           ),
    .out                                 (MIG_MEM_RST_N                  )
);

endmodule
