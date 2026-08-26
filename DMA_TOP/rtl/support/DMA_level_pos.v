`timescale 1ns / 1ps
`default_nettype none

// DMA-local name adaptation of the verified level_pos implementation from:
// D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
// 7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// The three-sample synchronizer and rising-edge equation are unchanged.  The
// module name is scoped to avoid duplicate global definitions in Detector.
module DMA_LEVEL_POS #(
    parameter integer       UDLY                        = 1
)(
    input   wire            clk                                         ,
    input   wire            rst_n                                       ,
    input   wire            in                                          ,
    output  wire            out
);

reg         [2:0]           xxr                                         ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        xxr <= #UDLY 3'd0;
    else
        xxr <= #UDLY {xxr[1:0], in};
end

assign out = xxr[1] & ~xxr[2];

endmodule

`default_nettype wire
