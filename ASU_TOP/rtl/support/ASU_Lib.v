`timescale 1ns / 1ps
`default_nettype none

// ASU-local name adaptations extracted from:
//   D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
//   7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// Adaptations are limited to the module names, explicit Verilog net types for
// Vivado 2020.2 compatibility under `default_nettype none, and correction of
// event_det.sel from one bit to the three-bit width explicitly required by its
// 3'd0..3'd5 case decode.  Sequential/combinational behavior is unchanged.

module ASU_EVENT_DET
(
    input       wire    clk                                                                ,
    input       wire    rst_n                                                              ,
    input       wire    in                                                                 ,
    input       wire    [2:0]   sel                                                        ,
    output      reg     out
);

parameter               UDLY                = 1                                            ;
parameter               DS                  = 2                                            ;
parameter               RV                  = 1'd0                                         ;
reg             inr                                                                        ;
wire            rise                                                                       ;
wire            fall                                                                       ;
wire            high                                                                       ;
wire            low                                                                        ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
       inr <= #UDLY 1'd0;
    else
       inr <= #UDLY in;
end

assign rise = in & ~inr;
assign fall = ~in & inr;
assign high = inr;
assign low  = ~inr;

always @(*) begin
    case(sel)
        3'd0 : out = 1'd0        ;
        3'd1 : out = rise        ;
        3'd2 : out = fall        ;
        3'd3 : out = rise | fall ;
        3'd4 : out = high        ;
        3'd5 : out = low         ;
        default : out = 1'd0     ;
    endcase
end

endmodule

module ASU_LEVEL_SYNC
(
    input       wire    clk                                                                ,
    input       wire    rst_n                                                              ,
    input       wire    in                                                                 ,
    output      wire    out
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
