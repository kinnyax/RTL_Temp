`timescale 1ns / 1ps
`default_nettype none

// Unique differential input-buffer owner for the board 200 MHz oscillator.
// MIG_REF_CLK is the raw IBUFDS output, before any MMCM, BUFG or clock gate.
module CMU_SYS_REFCLK (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 EXT_CLK_P CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME EXT_CLK_P, FREQ_HZ 200000000" *)
    input  wire EXT_CLK_P,
    input  wire EXT_CLK_N,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 MIG_REF_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME MIG_REF_CLK, FREQ_HZ 200000000" *)
    output wire MIG_REF_CLK
);

IBUFDS u_ext_clk_ibufds (
    .I (EXT_CLK_P),
    .IB(EXT_CLK_N),
    .O (MIG_REF_CLK)
);

endmodule

`default_nettype wire
