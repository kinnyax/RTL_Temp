`timescale 1ns / 1ps

module PCIE_TOP(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   data_clk                                       ,
    input                                   data_rst_n                                     ,
    input                                   pcie_rst_n                                     ,
    input                                   pcie_refclk_gt                                 ,
    input                                   pcie_refclk_div2                               ,
    input                                   pcie_perst_n                                   ,

    input               [ 3:0]              pci_exp_rxp                                    ,
    input               [ 3:0]              pci_exp_rxn                                    ,
    output    wire      [ 3:0]              pci_exp_txp                                    ,
    output    wire      [ 3:0]              pci_exp_txn                                    ,

    input               [255:0]             s_axis_tdata                                   ,
    input                                   s_axis_tvalid                                  ,
    output    wire                          s_axis_tready                                  ,

    input               [ 9:0]              s_axi_awaddr                                   ,
    input                                   s_axi_awvalid                                  ,
    output    wire                          s_axi_awready                                  ,
    input               [31:0]              s_axi_wdata                                    ,
    input               [ 3:0]              s_axi_wstrb                                    ,
    input                                   s_axi_wvalid                                   ,
    output    wire                          s_axi_wready                                   ,
    output    wire      [ 1:0]              s_axi_bresp                                    ,
    output    wire                          s_axi_bvalid                                   ,
    input                                   s_axi_bready                                   ,
    input               [ 9:0]              s_axi_araddr                                   ,
    input                                   s_axi_arvalid                                  ,
    output    wire                          s_axi_arready                                  ,
    output    wire      [31:0]              s_axi_rdata                                    ,
    output    wire      [ 1:0]              s_axi_rresp                                    ,
    output    wire                          s_axi_rvalid                                   ,
    input                                   s_axi_rready
);

wire                    [31:0]              pcie_ctl                                       ;
wire                                        axi_aclk                                       ;
wire                                        axi_aresetn                                    ;
wire                                        user_lnk_up                                    ;
wire                    [255:0]             axis_c2h_tdata                                 ;
wire                    [31:0]              axis_c2h_tkeep                                 ;
wire                                        axis_c2h_tvalid                                ;
wire                                        axis_c2h_tready                                ;
wire                                        axis_c2h_tlast                                 ;
wire                                        fifo_full                                      ;
wire                                        fifo_empty                                     ;
wire                                        wr_rst_busy                                    ;
wire                                        rd_rst_busy                                    ;
wire                                        fifo_of                                        ;
wire                                        fifo_uf                                        ;
wire                                        user_lnk_up_sync                               ;
wire                                        fifo_full_sync                                 ;
wire                                        fifo_empty_sync                                ;
wire                                        fifo_busy                                      ;
wire                                        fifo_of_sync                                   ;
wire                                        fifo_uf_sync                                   ;

//////////////////////////////////////////////////
//1. Control And Status Registers
//////////////////////////////////////////////////
PCIE_REG pcie_reg(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .s_axi_awaddr                        (s_axi_awaddr                                 ),
    .s_axi_awvalid                       (s_axi_awvalid                                ),
    .s_axi_awready                       (s_axi_awready                                ),
    .s_axi_wdata                         (s_axi_wdata                                  ),
    .s_axi_wstrb                         (s_axi_wstrb                                  ),
    .s_axi_wvalid                        (s_axi_wvalid                                 ),
    .s_axi_wready                        (s_axi_wready                                 ),
    .s_axi_bresp                         (s_axi_bresp                                  ),
    .s_axi_bvalid                        (s_axi_bvalid                                 ),
    .s_axi_bready                        (s_axi_bready                                 ),
    .s_axi_araddr                        (s_axi_araddr                                 ),
    .s_axi_arvalid                       (s_axi_arvalid                                ),
    .s_axi_arready                       (s_axi_arready                                ),
    .s_axi_rdata                         (s_axi_rdata                                  ),
    .s_axi_rresp                         (s_axi_rresp                                  ),
    .s_axi_rvalid                        (s_axi_rvalid                                 ),
    .s_axi_rready                        (s_axi_rready                                 ),
    .user_lnk_up                         (user_lnk_up_sync                             ),
    .fifo_full                           (fifo_full_sync                               ),
    .fifo_empty                          (fifo_empty_sync                              ),
    .fifo_busy                           (fifo_busy                                    ),
    .fifo_of                             (fifo_of_sync                                 ),
    .fifo_uf                             (fifo_uf_sync                                 ),
    .pcie_ctl                            (pcie_ctl                                     )
);

//////////////////////////////////////////////////
//2. Receive Data Path
//////////////////////////////////////////////////
PCIE_RXD pcie_rxd(
    .data_clk                            (data_clk                                     ),
    .data_rst_n                          (data_rst_n                                   ),
    .axi_aclk                            (axi_aclk                                     ),
    .axi_aresetn                         (axi_aresetn                                  ),
    .pcie_rst_n                          (pcie_rst_n                                   ),
    .pcie_ctl                            (pcie_ctl                                     ),
    .s_axis_tdata                        (s_axis_tdata                                 ),
    .s_axis_tvalid                       (s_axis_tvalid                                ),
    .s_axis_tready                       (s_axis_tready                                ),
    .m_axis_c2h_tdata                    (axis_c2h_tdata                               ),
    .m_axis_c2h_tkeep                    (axis_c2h_tkeep                               ),
    .m_axis_c2h_tvalid                   (axis_c2h_tvalid                              ),
    .m_axis_c2h_tready                   (axis_c2h_tready                              ),
    .m_axis_c2h_tlast                    (axis_c2h_tlast                               ),
    .fifo_full                           (fifo_full                                    ),
    .fifo_empty                          (fifo_empty                                   ),
    .wr_rst_busy                         (wr_rst_busy                                  ),
    .rd_rst_busy                         (rd_rst_busy                                  ),
    .fifo_of                             (fifo_of                                      ),
    .fifo_uf                             (fifo_uf                                      )
);

//////////////////////////////////////////////////
//3. PCIe Endpoint
//////////////////////////////////////////////////
PCIE_TXD pcie_txd(
    .pcie_refclk_gt                      (pcie_refclk_gt                               ),
    .pcie_refclk_div2                    (pcie_refclk_div2                             ),
    .pcie_perst_n                        (pcie_perst_n                                 ),
    .pci_exp_rxp                         (pci_exp_rxp                                  ),
    .pci_exp_rxn                         (pci_exp_rxn                                  ),
    .pci_exp_txp                         (pci_exp_txp                                  ),
    .pci_exp_txn                         (pci_exp_txn                                  ),
    .s_axis_c2h_tdata                    (axis_c2h_tdata                               ),
    .s_axis_c2h_tkeep                    (axis_c2h_tkeep                               ),
    .s_axis_c2h_tvalid                   (axis_c2h_tvalid                              ),
    .s_axis_c2h_tready                   (axis_c2h_tready                              ),
    .s_axis_c2h_tlast                    (axis_c2h_tlast                               ),
    .axi_aclk                            (axi_aclk                                     ),
    .axi_aresetn                         (axi_aresetn                                  ),
    .user_lnk_up                         (user_lnk_up                                  )
);

//////////////////////////////////////////////////
//4. Status Synchronization
//////////////////////////////////////////////////
PCIE_SYNC pcie_sync(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .data_clk                            (data_clk                                     ),
    .data_rst_n                          (data_rst_n                                   ),
    .axi_aclk                            (axi_aclk                                     ),
    .axi_aresetn                         (axi_aresetn                                  ),
    .user_lnk_up                         (user_lnk_up                                  ),
    .user_lnk_up_sync                    (user_lnk_up_sync                             ),
    .fifo_full                           (fifo_full                                    ),
    .fifo_full_sync                      (fifo_full_sync                               ),
    .fifo_empty                          (fifo_empty                                   ),
    .fifo_empty_sync                     (fifo_empty_sync                              ),
    .wr_rst_busy                         (wr_rst_busy                                  ),
    .wr_rst_busy_sync                    (                                             ),
    .rd_rst_busy                         (rd_rst_busy                                  ),
    .rd_rst_busy_sync                    (                                             ),
    .fifo_of                             (fifo_of                                      ),
    .fifo_of_sync                        (fifo_of_sync                                 ),
    .fifo_uf                             (fifo_uf                                      ),
    .fifo_uf_sync                        (fifo_uf_sync                                 ),
    .fifo_busy                           (fifo_busy                                    )
);

endmodule
