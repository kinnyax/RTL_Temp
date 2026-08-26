`timescale 1ns / 1ps
`default_nettype none

// Fixed-frequency glitchless clock gate. Frequency generation is owned by the
// Clocking Wizard; this module only synchronizes the request and drives BUFGCE.
module CMU_CLK(
    input   wire                            clk_src                     ,
    input   wire                            sys_rst_n                   ,
    input   wire                            clk_safe                    ,
    input   wire                            clk_en                      ,
    output  wire                            clk_out
);

parameter               UDLY                = 1                         ;

wire                                gate_async_rst_n                  ;
wire                                gate_rst_n                        ;
(* ASYNC_REG = "TRUE" *)
reg         [1:0]                   gate_rst_sync_r                  ;

// SYS_RST_N and CLK_SAFE are generated in the SYS_CLK domain, while CLK_SRC
// may be the independent 100 MHz ADC clock.  Assert the safety reset
// asynchronously, then release it through two CLK_SRC-domain stages before it
// reaches the archived clk_sgat synchronizer.
assign gate_async_rst_n = sys_rst_n & clk_safe;

always @(posedge clk_src or negedge gate_async_rst_n) begin
    if(!gate_async_rst_n)
        gate_rst_sync_r <= #UDLY 2'b00;
    else
        gate_rst_sync_r <= #UDLY {gate_rst_sync_r[0], 1'b1};
end

assign gate_rst_n = gate_rst_sync_r[1];

clk_sgat clk_sgat_inst(
    .in                     (clk_src                     ),
    .rst_n                  (gate_rst_n                  ),
    .en                     (clk_en                      ),
    .te                     (1'b0                        ),
    .out                    (clk_out                     )
);

endmodule

`default_nettype wire
