// Extracted without functional changes from:
// D:\Codex\RTL\PUB\Lib.V
// Source SHA256: 7032C3F7B95BB7CF8652BDA948C944BED35C7A72C605B3C8DEE5C19D544E894C
// Only the CMU-used synchronization and safe-gate cells are archived here.

module level_sync
(
    input               clk                                                                ,
    input               rst_n                                                              ,
    input               in                                                                 ,
    output              out
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

module clk_sgat
(
    input               in                                                                 ,
    input               rst_n                                                              ,
    input               en                                                                 ,
    input               te                                                                 ,
    output              out
);

wire                                en_r                                                   ;

level_sync en_lvl_sync(.clk(in),.rst_n(rst_n),.in(en),.out(en_r));
clk_gat clk_gat(.in(in),.out(out),.en(en_r));

endmodule
