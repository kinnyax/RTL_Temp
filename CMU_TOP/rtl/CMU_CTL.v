`timescale 1ns / 1ps

module CMU_CTL(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,
    input                                   sys_clk_ready                                  ,

    input               [31:0]              cmu_spi                                        ,
    input               [31:0]              cmu_adc                                        ,
    input               [31:0]              cmu_dma                                        ,

    output    wire                          spi_clk                                        ,
    output    wire                          adc_clk                                        ,
    output    wire                          dma_clk                                        ,

    input                                   afe_clk_p                                      ,
    input                                   afe_clk_n                                      ,
    output    wire                          afe_clk                                        ,

    input               [ 3:0]              jesd_refclk_p                                  ,
    input               [ 3:0]              jesd_refclk_n                                  ,
    output    wire      [ 3:0]              jesd_refclk                                    ,

    input                                   pcie_refclk_p                                  ,
    input                                   pcie_refclk_n                                  ,
    output    wire                          pcie_refclk_gt                                 ,
    output    wire                          pcie_refclk_div2
);

parameter                                   UDLY                     = 1                   ;

wire                                        clk_100m                                       ;
wire                                        clk_50m                                        ;
wire                                        clk_25m                                        ;
wire                                        spi_clk_sel                                    ;
wire                                        adc_clk_sel                                    ;
wire                    [ 1:0]              spi_div_sel                                    ;
wire                                        adc_div_sel                                    ;
wire                                        spi_enable                                     ;
wire                                        adc_enable                                     ;
wire                                        dma_enable                                     ;
wire                                        spi_en                                         ;
wire                                        adc_en                                         ;
wire                                        dma_en                                         ;
wire                                        afe_clk_src                                    ;

//////////////////////////////////////////////////
//1. Business Clock Sources
//////////////////////////////////////////////////
XIL_CLK_DIV #(.DIVIDE(2)) clk_100m_div(.clk_in(sys_clk), .clk_out(clk_100m));
XIL_CLK_DIV #(.DIVIDE(4)) clk_50m_div(.clk_in(sys_clk), .clk_out(clk_50m));
XIL_CLK_DIV #(.DIVIDE(8)) clk_25m_div(.clk_in(sys_clk), .clk_out(clk_25m));

XIL_CLK_MUX4 spi_clk_mux(.clk_in0(sys_clk), .clk_in1(clk_100m), .clk_in2(clk_50m), .clk_in3(clk_25m), .clk_sel(spi_div_sel), .clk_out(spi_clk_sel));

XIL_CLK_MUX2 adc_clk_mux(.clk_in0(clk_100m), .clk_in1(clk_50m), .clk_sel(adc_div_sel), .clk_out(adc_clk_sel));

//////////////////////////////////////////////////
//2. Business Clock Enable Synchronization
//////////////////////////////////////////////////
assign spi_div_sel = cmu_spi[2:1];
assign adc_div_sel = cmu_adc[1];
assign spi_enable  = cmu_spi[0] & sys_clk_ready;
assign adc_enable  = cmu_adc[0] & sys_clk_ready;
assign dma_enable  = cmu_dma[0] & sys_clk_ready;

level_sync spi_enable_sync(.clk(spi_clk_sel), .rst_n(sys_rst_n), .in(spi_enable), .out(spi_en));
level_sync adc_enable_sync(.clk(adc_clk_sel), .rst_n(sys_rst_n), .in(adc_enable), .out(adc_en));
level_sync dma_enable_sync(.clk(sys_clk), .rst_n(sys_rst_n), .in(dma_enable), .out(dma_en));

//////////////////////////////////////////////////
//3. Business Clock Gating
//////////////////////////////////////////////////
XIL_CLK_GATE spi_clk_gate(.clk_in(spi_clk_sel), .clk_enable(spi_en), .clk_out(spi_clk));
XIL_CLK_GATE adc_clk_gate(.clk_in(adc_clk_sel), .clk_enable(adc_en), .clk_out(adc_clk));
XIL_CLK_GATE dma_clk_gate(.clk_in(sys_clk), .clk_enable(dma_en), .clk_out(dma_clk));

//////////////////////////////////////////////////
//4. External Clock Buffers
//////////////////////////////////////////////////
IBUFDS afe_clk_ibuf(.I(afe_clk_p), .IB(afe_clk_n), .O(afe_clk_src));
XIL_CLK_BUFFER afe_clk_buf(.clk_in(afe_clk_src), .clk_out(afe_clk));
IBUFDS_GTE3 #(.REFCLK_HROW_CK_SEL(2'b00)) jesd_refclk0_ibufds(.I(jesd_refclk_p[0]), .IB(jesd_refclk_n[0]), .CEB(1'd0), .O(jesd_refclk[0]), .ODIV2());
IBUFDS_GTE3 #(.REFCLK_HROW_CK_SEL(2'b00)) jesd_refclk1_ibufds(.I(jesd_refclk_p[1]), .IB(jesd_refclk_n[1]), .CEB(1'd0), .O(jesd_refclk[1]), .ODIV2());
IBUFDS_GTE3 #(.REFCLK_HROW_CK_SEL(2'b00)) jesd_refclk2_ibufds(.I(jesd_refclk_p[2]), .IB(jesd_refclk_n[2]), .CEB(1'd0), .O(jesd_refclk[2]), .ODIV2());
IBUFDS_GTE3 #(.REFCLK_HROW_CK_SEL(2'b00)) jesd_refclk3_ibufds(.I(jesd_refclk_p[3]), .IB(jesd_refclk_n[3]), .CEB(1'd0), .O(jesd_refclk[3]), .ODIV2());
IBUFDS_GTE3 #(.REFCLK_HROW_CK_SEL(2'b00)) pcie_refclk_ibufds(.I(pcie_refclk_p), .IB(pcie_refclk_n), .CEB(1'd0), .O(pcie_refclk_gt), .ODIV2(pcie_refclk_div2));

endmodule
