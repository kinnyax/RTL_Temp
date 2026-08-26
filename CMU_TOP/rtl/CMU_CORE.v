`timescale 1ns / 1ps
`default_nettype none

// Pure RTL CMU core used inside the production CMU_TOP block design.
// Clocking Wizard and external differential-clock primitive wrappers remain
// explicit BDC siblings so CMU_TOP.bd can own the vendor IP configuration.
module CMU_CORE(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 SYS_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME SYS_CLK, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET SYS_RST_N, FREQ_HZ 200000000" *)
    input   wire                            SYS_CLK                     ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ADC_CLK_SRC CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ADC_CLK_SRC, FREQ_HZ 100000000" *)
    input   wire                            ADC_CLK_SRC                 ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 JESD_DRP_CLK_SRC CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME JESD_DRP_CLK_SRC, FREQ_HZ 25000000" *)
    input   wire                            JESD_DRP_CLK_SRC            ,
    input   wire                            EXT_RST_N                   ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 SYS_RST_N RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME SYS_RST_N, POLARITY ACTIVE_LOW" *)
    input   wire                            SYS_RST_N                   ,
    input   wire                            MMCM_LOCKED                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 15, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1" *)
    input   wire        [14:0]              S_AXI_AWADDR                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input   wire                            S_AXI_AWVALID               ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output  wire                            S_AXI_AWREADY               ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input   wire        [31:0]              S_AXI_WDATA                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input   wire        [3:0]               S_AXI_WSTRB                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input   wire                            S_AXI_WVALID                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output  wire                            S_AXI_WREADY                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output  wire        [1:0]               S_AXI_BRESP                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output  wire                            S_AXI_BVALID                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input   wire                            S_AXI_BREADY                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input   wire        [14:0]              S_AXI_ARADDR                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input   wire                            S_AXI_ARVALID               ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output  wire                            S_AXI_ARREADY               ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output  wire        [31:0]              S_AXI_RDATA                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output  wire        [1:0]               S_AXI_RRESP                 ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output  wire                            S_AXI_RVALID                ,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input   wire                            S_AXI_RREADY                ,
    output  wire                            SYS_CLK_READY               ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 SPI_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME SPI_CLK, FREQ_HZ 200000000" *)
    output  wire                            SPI_CLK                     ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ADC_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ADC_CLK, FREQ_HZ 100000000" *)
    output  wire                            ADC_CLK                     ,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 JESD_DRP_CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME JESD_DRP_CLK, FREQ_HZ 25000000" *)
    output  wire                            JESD_DRP_CLK
);

parameter               READY_STABLE_CYC    = 16                        ;
parameter               READY_CNT_W         = 5                         ;
parameter               UDLY                = 1                         ;

wire                                mmcm_locked_sync                  ;
wire                                spi_clk_en                       ;
wire                                adc_clk_en                       ;

CMU_READY #(
    .READY_STABLE_CYC    (READY_STABLE_CYC              ),
    .READY_CNT_W         (READY_CNT_W                   ),
    .UDLY                (UDLY                          )
) cmu_ready_inst(
    .SYS_CLK             (SYS_CLK                       ),
    .EXT_RST_N           (EXT_RST_N                     ),
    .MMCM_LOCKED         (MMCM_LOCKED                   ),
    .MMCM_LOCKED_SYNC    (mmcm_locked_sync              ),
    .SYS_CLK_READY       (SYS_CLK_READY                 )
);

CMU_REG #(
    .UDLY                (UDLY                          )
) cmu_reg_inst(
    .SYS_CLK             (SYS_CLK                       ),
    .SYS_RST_N           (SYS_RST_N                     ),
    .SYS_CLK_READY       (SYS_CLK_READY                 ),
    .MMCM_LOCKED         (mmcm_locked_sync              ),
    .S_AXI_AWADDR        (S_AXI_AWADDR                  ),
    .S_AXI_AWVALID       (S_AXI_AWVALID                 ),
    .S_AXI_AWREADY       (S_AXI_AWREADY                 ),
    .S_AXI_WDATA         (S_AXI_WDATA                   ),
    .S_AXI_WSTRB         (S_AXI_WSTRB                   ),
    .S_AXI_WVALID        (S_AXI_WVALID                  ),
    .S_AXI_WREADY        (S_AXI_WREADY                  ),
    .S_AXI_BRESP         (S_AXI_BRESP                   ),
    .S_AXI_BVALID        (S_AXI_BVALID                  ),
    .S_AXI_BREADY        (S_AXI_BREADY                  ),
    .S_AXI_ARADDR        (S_AXI_ARADDR                  ),
    .S_AXI_ARVALID       (S_AXI_ARVALID                 ),
    .S_AXI_ARREADY       (S_AXI_ARREADY                 ),
    .S_AXI_RDATA         (S_AXI_RDATA                   ),
    .S_AXI_RRESP         (S_AXI_RRESP                   ),
    .S_AXI_RVALID        (S_AXI_RVALID                  ),
    .S_AXI_RREADY        (S_AXI_RREADY                  ),
    .spi_clk_en          (spi_clk_en                    ),
    .adc_clk_en          (adc_clk_en                    )
);

CMU_CLK spi_clk_gate_inst(
    .clk_src             (SYS_CLK                       ),
    .sys_rst_n           (SYS_RST_N                     ),
    .clk_safe            (SYS_CLK_READY                 ),
    .clk_en              (spi_clk_en                    ),
    .clk_out             (SPI_CLK                       )
);

CMU_CLK adc_clk_gate_inst(
    .clk_src             (ADC_CLK_SRC                   ),
    .sys_rst_n           (SYS_RST_N                     ),
    .clk_safe            (SYS_CLK_READY                 ),
    .clk_en              (adc_clk_en                    ),
    .clk_out             (ADC_CLK                       )
);

CMU_CLK jesd_drp_clk_gate_inst(
    .clk_src             (JESD_DRP_CLK_SRC              ),
    .sys_rst_n           (SYS_RST_N                     ),
    .clk_safe            (SYS_CLK_READY                 ),
    .clk_en              (adc_clk_en                    ),
    .clk_out             (JESD_DRP_CLK                  )
);

endmodule
