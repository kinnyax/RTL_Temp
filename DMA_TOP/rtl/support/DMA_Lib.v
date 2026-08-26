// Minimal DMA subset extracted without functional modification from:
//   D:\Codex\RTL\PUB\Lib.V
// Source SHA256:
//   7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// Included modules are exactly the DMA dependencies:
//   levels_sync  - independent single-bit level synchronization bus
//   pulse_sync2  - source-toggle event transfer with independent resets

module levels_sync#(
    parameter               DS                  = 2                                        ,
    parameter               RV                  = 1'd0
)(
    input                                       clk                                        ,
    input                                       rst_n                                      ,
    input               [DS-1:0]                in                                         ,
    output              [DS-1:0]                out
);

    localparam              UDLY                = 1                                        ;
reg             [DS-1:0]                xxr0                                               ;
reg             [DS-1:0]                xxr1                                               ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
       xxr0 <= #UDLY {DS{RV[0]}};
    else
        xxr0 <= #UDLY in;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
       xxr1 <= #UDLY {DS{RV[0]}};
    else
       xxr1 <= #UDLY xxr0;
end

assign out = xxr1;

endmodule

module pulse_sync2
(
    input               clka                                                               ,
    input               clkb                                                               ,
    input               rst_n_a                                                            ,
    input               rst_n_b                                                            ,
    input               in                                                                 ,
    output              out
);

parameter               UDLY                = 1                                            ;
reg                                 a_lvl                                                  ;
reg             [2:0]               b_xxr                                                  ;


always @(posedge clka or negedge rst_n_a) begin
    if(!rst_n_a)
       a_lvl <= #UDLY 1'd0;
    else if(in)
       a_lvl <= #UDLY ~a_lvl;
end

always @(posedge clkb or negedge rst_n_b) begin
    if(!rst_n_b)
       b_xxr <= #UDLY 3'd0;
    else
       b_xxr <= #UDLY {b_xxr[1:0],a_lvl};
end

assign out = b_xxr[1] ^ b_xxr[2];

endmodule
