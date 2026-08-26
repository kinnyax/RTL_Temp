`timescale 1ns / 1ps
`default_nettype none

// Dedicated Jetson-to-XDMA PCIe reference-clock input boundary.
module CMU_PCIE_REFCLK(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PCIE_REFCLK_P CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PCIE_REFCLK_P, FREQ_HZ 100000000" *)
    input   wire                            PCIE_REFCLK_P               ,
    input   wire                            PCIE_REFCLK_N               ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PCIE_REFCLK_GT CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PCIE_REFCLK_GT, FREQ_HZ 100000000" *)
    output  wire                            PCIE_REFCLK_GT              ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PCIE_REFCLK_DIV2 CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PCIE_REFCLK_DIV2, FREQ_HZ 100000000" *)
    output  wire                            PCIE_REFCLK_DIV2
);

IBUFDS_GTE3 #(
    .REFCLK_EN_TX_PATH    (1'b0                         ),
    .REFCLK_HROW_CK_SEL   (2'b00                        ),
    .REFCLK_ICNTL_RX      (2'b00                        )
) pcie_refclk_ibufds_inst(
    .I                    (PCIE_REFCLK_P                 ),
    .IB                   (PCIE_REFCLK_N                 ),
    .CEB                  (1'b0                          ),
    .O                    (PCIE_REFCLK_GT                ),
    .ODIV2                (PCIE_REFCLK_DIV2              )
);

endmodule

`default_nettype wire
