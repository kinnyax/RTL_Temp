`timescale 1ns / 1ps
`default_nettype none

// Detector SPI-scoped level synchronizer adapted from the verified structure in:
// D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
// 7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// This scoped derivative preserves the level_sync pipeline semantics; it is not
// a byte-for-byte extraction.

module SPI_LEVEL_SYNC #(
    parameter integer       UDLY                        = 1             ,
    parameter integer       DS                          = 2             ,
    parameter               RV                          = 1'b0
)(
    input   wire            clk                                         ,
    input   wire            rst_n                                       ,
    input   wire            in                                          ,
    output  wire            out
);

(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
reg         [DS-1:0]        sync_pipe                                   ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        sync_pipe <= #UDLY {DS{RV}};
    else
        sync_pipe <= #UDLY {sync_pipe[DS-2:0], in};
end

assign out = sync_pipe[DS-1];

endmodule

`default_nettype wire
