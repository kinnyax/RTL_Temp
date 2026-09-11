`timescale 1ns / 1ps

module PCIE_TXD(
    input                                   pcie_refclk_gt                                 ,
    input                                   pcie_refclk_div2                               ,
    input                                   pcie_perst_n                                   ,
    input               [ 3:0]              pci_exp_rxp                                    ,
    input               [ 3:0]              pci_exp_rxn                                    ,
    output    wire      [ 3:0]              pci_exp_txp                                    ,
    output    wire      [ 3:0]              pci_exp_txn                                    ,

    input               [255:0]             s_axis_c2h_tdata                               ,
    input               [31:0]              s_axis_c2h_tkeep                               ,
    input                                   s_axis_c2h_tvalid                              ,
    output    wire                          s_axis_c2h_tready                              ,
    input                                   s_axis_c2h_tlast                               ,

    output    wire                          axi_aclk                                       ,
    output    wire                          axi_aresetn                                    ,
    output    wire                          user_lnk_up
);

//////////////////////////////////////////////////
//1. XDMA Endpoint
//////////////////////////////////////////////////
PCIE_XDMA pcie_xdma(
    .sys_clk                             (pcie_refclk_div2                             ),
    .sys_clk_gt                          (pcie_refclk_gt                               ),
    .sys_rst_n                           (pcie_perst_n                                 ),
    .user_lnk_up                         (user_lnk_up                                  ),
    .pci_exp_txp                         (pci_exp_txp                                  ),
    .pci_exp_txn                         (pci_exp_txn                                  ),
    .pci_exp_rxp                         (pci_exp_rxp                                  ),
    .pci_exp_rxn                         (pci_exp_rxn                                  ),
    .axi_aclk                            (axi_aclk                                     ),
    .axi_aresetn                         (axi_aresetn                                  ),
    .usr_irq_req                         (1'd0                                         ),
    .usr_irq_ack                         (                                             ),
    .msi_enable                          (                                             ),
    .msi_vector_width                    (                                             ),
    .cfg_mgmt_addr                       (19'd0                                        ),
    .cfg_mgmt_write                      (1'd0                                         ),
    .cfg_mgmt_write_data                 (32'd0                                        ),
    .cfg_mgmt_byte_enable                (4'd0                                         ),
    .cfg_mgmt_read                       (1'd0                                         ),
    .cfg_mgmt_read_data                  (                                             ),
    .cfg_mgmt_read_write_done            (                                             ),
    .cfg_mgmt_type1_cfg_reg_access       (1'd0                                         ),
    .s_axis_c2h_tdata_0                  (s_axis_c2h_tdata                             ),
    .s_axis_c2h_tlast_0                  (s_axis_c2h_tlast                             ),
    .s_axis_c2h_tvalid_0                 (s_axis_c2h_tvalid                            ),
    .s_axis_c2h_tready_0                 (s_axis_c2h_tready                            ),
    .s_axis_c2h_tkeep_0                  (s_axis_c2h_tkeep                             ),
    .m_axis_h2c_tdata_0                  (                                             ),
    .m_axis_h2c_tlast_0                  (                                             ),
    .m_axis_h2c_tvalid_0                 (                                             ),
    .m_axis_h2c_tready_0                 (axi_aresetn                                  ),
    .m_axis_h2c_tkeep_0                  (                                             ),
    .int_qpll1lock_out                   (                                             ),
    .int_qpll1outrefclk_out              (                                             ),
    .int_qpll1outclk_out                 (                                             )
);

endmodule
