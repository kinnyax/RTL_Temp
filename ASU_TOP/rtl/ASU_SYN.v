`timescale 1ns / 1ps
`default_nettype none

// ASU-local adaptation of PUB levels_sync.  Keeping only this dependency in a
// dedicated file gives #UDLY an explicit simulation time scale and avoids
// compiling unrelated public helper modules into the ASU verification top.
module ASU_LEVELS_SYNC #(
    parameter integer                       UDLY                        = 1              ,
    parameter integer                       DS                          = 3              ,
    parameter integer                       RV                          = 0
)(
    input  wire                             clk                                         ,
    input  wire                             rst_n                                       ,
    input  wire [DS-1:0]                    in                                          ,
    output wire [DS-1:0]                    out
);

reg  [DS-1:0]                               sync_stage0                                  ;
reg  [DS-1:0]                               sync_stage1                                  ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_stage0 <= #UDLY {DS{RV[0]}};
    else
        sync_stage0 <= #UDLY in;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_stage1 <= #UDLY {DS{RV[0]}};
    else
        sync_stage1 <= #UDLY sync_stage0;
end

assign out = sync_stage1;

endmodule

`default_nettype wire
