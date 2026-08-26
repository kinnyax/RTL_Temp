`timescale 1ns / 1ps
`default_nettype none

// MIG-local name adaptation extracted from:
//   D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
//   7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// Only the module name is scoped for final Detector integration. Parameters,
// ports and synchronization logic are unchanged.

module MIG_LEVEL_SYNC
(
    input  wire         clk                                                                ,
    input  wire         rst_n                                                              ,
    input  wire         in                                                                 ,
    output wire         out
);

parameter               UDLY                = 1                                            ;
parameter               DS                  = 2                                            ;
parameter               RV                  = 1'd0                                         ;
reg             [DS-1:0]                xxr                                                ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        xxr <= #UDLY {DS{RV[0]}};
    else
        xxr <= #UDLY {xxr[DS-2:0],in};
end

assign out = xxr[DS-1];

endmodule

`default_nettype wire
