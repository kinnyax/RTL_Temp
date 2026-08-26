`timescale 1ns / 1ps
`default_nettype none

// RMU-local name adaptation of the verified level_sync implementation from:
// D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
// 7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// The behavior is unchanged; the module name is scoped to avoid duplicate
// global definitions when Detector components are assembled together.
module RMU_LEVEL_SYNC #(
    parameter integer       UDLY                        = 1             ,
    parameter integer       DS                          = 2             ,
    parameter               RV                          = 1'b0
)(
    input   wire            clk                                         ,
    input   wire            rst_n                                       ,
    input   wire            in                                          ,
    output  wire            out
);

reg         [DS-1:0]        xxr                                         ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        xxr <= #UDLY {DS{RV}};
    else
        xxr <= #UDLY {xxr[DS-2:0], in};
end

assign out = xxr[DS-1];

endmodule

`default_nettype wire
