`timescale 1ns / 1ps
`default_nettype none

// Ordinary differential clock input for the 40 MHz ADC TGC clock domain.
module CMU_AFE_CLK(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 AFE_CLK_P CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AFE_CLK_P, FREQ_HZ 40000000" *)
    input   wire                            AFE_CLK_P                   ,
    input   wire                            AFE_CLK_N                   ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 AFE_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME AFE_CLK, FREQ_HZ 40000000" *)
    output  wire                            AFE_CLK
);

wire                                afe_clk_ibuf                     ;

IBUFDS #(
    .DIFF_TERM            ("TRUE"                        ),
    .IBUF_LOW_PWR         ("FALSE"                       )
) afe_clk_ibufds_inst(
    .I                    (AFE_CLK_P                     ),
    .IB                   (AFE_CLK_N                     ),
    .O                    (afe_clk_ibuf                  )
);

clk_buf afe_clk_buf_inst(
    .in                   (afe_clk_ibuf                  ),
    .out                  (AFE_CLK                       )
);

endmodule

`default_nettype wire
