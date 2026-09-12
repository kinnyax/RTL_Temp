`timescale 1ns / 1ps

module MIG_TOP(
    input                                   mig_clk                                        ,
    input                                   mig_rst_n                                      ,
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    output    wire                          mig_ddr4_clk                                   ,
    output    wire                          mig_ddr4_rst_n                                 ,

    input               [ 7:0]              s_axi_mem_awid                                 ,
    input               [31:0]              s_axi_mem_awaddr                               ,
    input               [ 7:0]              s_axi_mem_awlen                                ,
    input               [ 2:0]              s_axi_mem_awsize                               ,
    input               [ 1:0]              s_axi_mem_awburst                              ,
    input                                   s_axi_mem_awlock                               ,
    input               [ 3:0]              s_axi_mem_awcache                              ,
    input               [ 2:0]              s_axi_mem_awprot                               ,
    input               [ 3:0]              s_axi_mem_awqos                                ,
    input                                   s_axi_mem_awvalid                              ,
    output    wire                          s_axi_mem_awready                              ,

    input               [255:0]             s_axi_mem_wdata                                ,
    input               [31:0]              s_axi_mem_wstrb                                ,
    input                                   s_axi_mem_wlast                                ,
    input                                   s_axi_mem_wvalid                               ,
    output    wire                          s_axi_mem_wready                               ,

    output    wire      [ 7:0]              s_axi_mem_bid                                  ,
    output    wire      [ 1:0]              s_axi_mem_bresp                                ,
    output    wire                          s_axi_mem_bvalid                               ,
    input                                   s_axi_mem_bready                               ,

    input               [ 7:0]              s_axi_mem_arid                                 ,
    input               [31:0]              s_axi_mem_araddr                               ,
    input               [ 7:0]              s_axi_mem_arlen                                ,
    input               [ 2:0]              s_axi_mem_arsize                               ,
    input               [ 1:0]              s_axi_mem_arburst                              ,
    input                                   s_axi_mem_arlock                               ,
    input               [ 3:0]              s_axi_mem_arcache                              ,
    input               [ 2:0]              s_axi_mem_arprot                               ,
    input               [ 3:0]              s_axi_mem_arqos                                ,
    input                                   s_axi_mem_arvalid                              ,
    output    wire                          s_axi_mem_arready                              ,

    output    wire      [ 7:0]              s_axi_mem_rid                                  ,
    output    wire      [255:0]             s_axi_mem_rdata                                ,
    output    wire      [ 1:0]              s_axi_mem_rresp                                ,
    output    wire                          s_axi_mem_rlast                                ,
    output    wire                          s_axi_mem_rvalid                               ,
    input                                   s_axi_mem_rready                               ,

    input               [31:0]              s_axi_reg_awaddr                               ,
    input               [ 2:0]              s_axi_reg_awprot                               ,
    input                                   s_axi_reg_awvalid                              ,
    output    wire                          s_axi_reg_awready                              ,

    input               [31:0]              s_axi_reg_wdata                                ,
    input               [ 3:0]              s_axi_reg_wstrb                                ,
    input                                   s_axi_reg_wvalid                               ,
    output    wire                          s_axi_reg_wready                               ,

    output    wire      [ 1:0]              s_axi_reg_bresp                                ,
    output    wire                          s_axi_reg_bvalid                               ,
    input                                   s_axi_reg_bready                               ,

    input               [31:0]              s_axi_reg_araddr                               ,
    input               [ 2:0]              s_axi_reg_arprot                               ,
    input                                   s_axi_reg_arvalid                              ,
    output    wire                          s_axi_reg_arready                              ,

    output    wire      [31:0]              s_axi_reg_rdata                                ,
    output    wire      [ 1:0]              s_axi_reg_rresp                                ,
    output    wire                          s_axi_reg_rvalid                               ,
    input                                   s_axi_reg_rready                               ,

    output    wire      [16:0]              ddr4_adr                                       ,
    output    wire      [ 1:0]              ddr4_ba                                        ,
    output    wire                          ddr4_bg                                        ,
    output    wire                          ddr4_act_n                                     ,
    output    wire                          ddr4_ck_t                                      ,
    output    wire                          ddr4_ck_c                                      ,
    output    wire                          ddr4_cke                                       ,
    output    wire                          ddr4_cs_n                                      ,
    output    wire                          ddr4_odt                                       ,
    output    wire                          ddr4_reset_n                                   ,
    inout     wire      [ 7:0]              ddr4_dm_dbi_n                                  ,
    inout     wire      [63:0]              ddr4_dq                                        ,
    inout     wire      [ 7:0]              ddr4_dqs_t                                     ,
    inout     wire      [ 7:0]              ddr4_dqs_c
);

wire                                        mig_ddr4_calib_complete                        ;
wire                                        mig_ddr4_ui_clk_sync_rst                       ;
wire                                        calib_complete_sync                            ;

//////////////////////////////////////////////////
//1. DDR4 Reset Polarity
//////////////////////////////////////////////////
assign mig_ddr4_rst_n = ~mig_ddr4_ui_clk_sync_rst;

//////////////////////////////////////////////////
//2. Hierarchy
//////////////////////////////////////////////////
MIG_DDR4 mig_ddr4(
    .mig_clk                             (mig_clk                                      ),
    .mig_rst_n                           (mig_rst_n                                    ),
    .mig_ddr4_clk                        (mig_ddr4_clk                                 ),
    .mig_ddr4_rst_n                      (mig_ddr4_rst_n                               ),
    .mig_ddr4_calib_complete             (mig_ddr4_calib_complete                      ),
    .mig_ddr4_ui_clk_sync_rst            (mig_ddr4_ui_clk_sync_rst                     ),
    .s_axi_mem_awid                      (s_axi_mem_awid                               ),
    .s_axi_mem_awaddr                    (s_axi_mem_awaddr                             ),
    .s_axi_mem_awlen                     (s_axi_mem_awlen                              ),
    .s_axi_mem_awsize                    (s_axi_mem_awsize                             ),
    .s_axi_mem_awburst                   (s_axi_mem_awburst                            ),
    .s_axi_mem_awlock                    (s_axi_mem_awlock                             ),
    .s_axi_mem_awcache                   (s_axi_mem_awcache                            ),
    .s_axi_mem_awprot                    (s_axi_mem_awprot                             ),
    .s_axi_mem_awqos                     (s_axi_mem_awqos                              ),
    .s_axi_mem_awvalid                   (s_axi_mem_awvalid                            ),
    .s_axi_mem_awready                   (s_axi_mem_awready                            ),
    .s_axi_mem_wdata                     (s_axi_mem_wdata                              ),
    .s_axi_mem_wstrb                     (s_axi_mem_wstrb                              ),
    .s_axi_mem_wlast                     (s_axi_mem_wlast                              ),
    .s_axi_mem_wvalid                    (s_axi_mem_wvalid                             ),
    .s_axi_mem_wready                    (s_axi_mem_wready                             ),
    .s_axi_mem_bid                       (s_axi_mem_bid                                ),
    .s_axi_mem_bresp                     (s_axi_mem_bresp                              ),
    .s_axi_mem_bvalid                    (s_axi_mem_bvalid                             ),
    .s_axi_mem_bready                    (s_axi_mem_bready                             ),
    .s_axi_mem_arid                      (s_axi_mem_arid                               ),
    .s_axi_mem_araddr                    (s_axi_mem_araddr                             ),
    .s_axi_mem_arlen                     (s_axi_mem_arlen                              ),
    .s_axi_mem_arsize                    (s_axi_mem_arsize                             ),
    .s_axi_mem_arburst                   (s_axi_mem_arburst                            ),
    .s_axi_mem_arlock                    (s_axi_mem_arlock                             ),
    .s_axi_mem_arcache                   (s_axi_mem_arcache                            ),
    .s_axi_mem_arprot                    (s_axi_mem_arprot                             ),
    .s_axi_mem_arqos                     (s_axi_mem_arqos                              ),
    .s_axi_mem_arvalid                   (s_axi_mem_arvalid                            ),
    .s_axi_mem_arready                   (s_axi_mem_arready                            ),
    .s_axi_mem_rid                       (s_axi_mem_rid                                ),
    .s_axi_mem_rdata                     (s_axi_mem_rdata                              ),
    .s_axi_mem_rresp                     (s_axi_mem_rresp                              ),
    .s_axi_mem_rlast                     (s_axi_mem_rlast                              ),
    .s_axi_mem_rvalid                    (s_axi_mem_rvalid                             ),
    .s_axi_mem_rready                    (s_axi_mem_rready                             ),
    .ddr4_adr                            (ddr4_adr                                     ),
    .ddr4_ba                             (ddr4_ba                                      ),
    .ddr4_bg                             (ddr4_bg                                      ),
    .ddr4_act_n                          (ddr4_act_n                                   ),
    .ddr4_ck_t                           (ddr4_ck_t                                    ),
    .ddr4_ck_c                           (ddr4_ck_c                                    ),
    .ddr4_cke                            (ddr4_cke                                     ),
    .ddr4_cs_n                           (ddr4_cs_n                                    ),
    .ddr4_odt                            (ddr4_odt                                     ),
    .ddr4_reset_n                        (ddr4_reset_n                                 ),
    .ddr4_dm_dbi_n                       (ddr4_dm_dbi_n                                ),
    .ddr4_dq                             (ddr4_dq                                      ),
    .ddr4_dqs_t                          (ddr4_dqs_t                                   ),
    .ddr4_dqs_c                          (ddr4_dqs_c                                   )
);

MIG_SYNC mig_sync(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .calib_complete                      (mig_ddr4_calib_complete                      ),
    .calib_complete_sync                 (calib_complete_sync                          )
);

MIG_REG mig_reg(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .calib_complete                      (calib_complete_sync                          ),
    .s_axi_awaddr                        (s_axi_reg_awaddr                             ),
    .s_axi_awprot                        (s_axi_reg_awprot                             ),
    .s_axi_awvalid                       (s_axi_reg_awvalid                            ),
    .s_axi_awready                       (s_axi_reg_awready                            ),
    .s_axi_wdata                         (s_axi_reg_wdata                              ),
    .s_axi_wstrb                         (s_axi_reg_wstrb                              ),
    .s_axi_wvalid                        (s_axi_reg_wvalid                             ),
    .s_axi_wready                        (s_axi_reg_wready                             ),
    .s_axi_bresp                         (s_axi_reg_bresp                              ),
    .s_axi_bvalid                        (s_axi_reg_bvalid                             ),
    .s_axi_bready                        (s_axi_reg_bready                             ),
    .s_axi_araddr                        (s_axi_reg_araddr                             ),
    .s_axi_arprot                        (s_axi_reg_arprot                             ),
    .s_axi_arvalid                       (s_axi_reg_arvalid                            ),
    .s_axi_arready                       (s_axi_reg_arready                            ),
    .s_axi_rdata                         (s_axi_reg_rdata                              ),
    .s_axi_rresp                         (s_axi_reg_rresp                              ),
    .s_axi_rvalid                        (s_axi_reg_rvalid                             ),
    .s_axi_rready                        (s_axi_reg_rready                             )
);

endmodule
