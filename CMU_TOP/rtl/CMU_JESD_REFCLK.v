`timescale 1ns / 1ps
`default_nettype none

// One GTH reference-clock pair. The BDC explicitly instantiates one copy per
// selected GTH Quad; the provisional integration profile uses four copies.
module CMU_JESD_REFCLK(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 JESD_REFCLK_P CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME JESD_REFCLK_P, FREQ_HZ 160000000" *)
    input   wire                            JESD_REFCLK_P               ,
    input   wire                            JESD_REFCLK_N               ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 JESD_REFCLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME JESD_REFCLK, FREQ_HZ 160000000" *)
    output  wire                            JESD_REFCLK
);

IBUFDS_GTE3 #(
    .REFCLK_EN_TX_PATH    (1'b0                         ),
    .REFCLK_HROW_CK_SEL   (2'b00                        ),
    .REFCLK_ICNTL_RX      (2'b00                        )
) jesd_refclk_ibufds_inst(
    .I                    (JESD_REFCLK_P                 ),
    .IB                   (JESD_REFCLK_N                 ),
    .CEB                  (1'b0                          ),
    .O                    (JESD_REFCLK                   ),
    .ODIV2                (                              )
);

endmodule

`default_nettype wire
