`timescale 1ns / 1ps

module SPI_TXD(
    input                                   spi_clk                                        ,
    input                                   rst_n                                          ,

    input                                   spi_en                                         ,
    input               [31:0]              spi_ctl                                        ,
    input               [31:0]              sck_div                                        ,
    input                                   spi_sck_in                                     ,
    input                                   cs_sel                                         ,
    input               [31:0]              tx_fifo_rdata                                  ,
    input                                   tx_fifo_empty                                  ,
    input               [ 5:0]              tx_fifo_level                                  ,

    output    wire                          tx_fifo_rinc                                   ,
    output    wire                          spi_busy                                       ,
    output    wire                          spi_cs_n                                       ,
    output    reg                           spi_sck_out                                    ,
    output    wire                          spi_sck_oe                                     ,
    output    wire                          spi_mosi_out                                   ,
    output    wire                          spi_mosi_oe                                    ,
    output    wire                          spi_miso_out                                   ,
    output    wire                          spi_miso_oe                                    ,
    output    wire      [ 3:0]              spi_cs_oe                                      ,
    output    reg                           sample_trig                                    ,
    output    wire                          bit_end
);

parameter                                   UDLY                     = 1                   ;

localparam                                  TXD_IDLE                 = 1'd0                ;
localparam                                  TXD_BUSY                 = 1'd1                ;

wire                                        ms_mode                                        ;
wire                                        cs_mode                                        ;
wire                                        cpol                                           ;
wire                                        cpha                                           ;
wire                                        lsb                                            ;
wire                    [ 1:0]              spi_mode                                       ;
wire                    [ 1:0]              spi_size                                       ;
wire                    [15:0]              clk_div                                        ;
wire                                        manual_cs_active_sync                          ;

wire                                        master_run                                     ;
wire                                        slave_run                                      ;
wire                                        spi_run                                        ;
wire                                        master_active                                  ;
wire                                        slave_active                                   ;
wire                                        master_end                                     ;
wire                                        slave_end                                      ;
wire                                        spi_end                                        ;

wire                                        sck_tick                                       ;
wire                                        master_data_edge                               ;
wire                                        master_return_edge                             ;
wire                                        master_sck_edge                                ;

wire                                        master_sck_pos                                 ;
wire                                        master_sck_neg                                 ;
wire                                        slave_sck_pos                                  ;
wire                                        slave_sck_neg                                  ;
wire                                        sck_pos                                        ;
wire                                        sck_neg                                        ;
wire                                        pre_end                                        ;
wire                    [ 4:0]              last_index                                     ;

reg                                         txd_fsm                                        ;
reg                                         txd_fsm_nx                                     ;
reg                     [31:0]              txd_data                                       ;
reg                     [15:0]              div_cnt                                        ;
reg                     [ 4:0]              bit_cnt                                        ;
reg                                         pre_end_r                                      ;
reg                                         cs_sel_r                                       ;
reg                                         slave_sck_r                                    ;
reg                                         launch_trig                                    ;
reg                                         txd_bit                                        ;

//////////////////////////////////////////////////
//1. Configuration
//////////////////////////////////////////////////
assign ms_mode   = spi_ctl[1];
assign cs_mode   = spi_ctl[2];
assign cpol      = spi_ctl[5];
assign cpha      = spi_ctl[4];
assign lsb       = spi_ctl[6];
assign spi_mode  = spi_ctl[5:4];
assign spi_size  = spi_ctl[8:7];
assign clk_div   = sck_div[15:0];

level_sync #(.RV(1'd0)) manual_cs_level_sync(.clk(spi_clk), .rst_n(rst_n), .in(spi_ctl[3]), .out(manual_cs_active_sync));

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        cs_sel_r <= #UDLY 1'd0;
    else if(~spi_en | ms_mode)
        cs_sel_r <= #UDLY 1'd0;
    else
        cs_sel_r <= #UDLY cs_sel;
end

//////////////////////////////////////////////////
//2. IDLE/BUSY State Machine
//////////////////////////////////////////////////
assign spi_busy      = (txd_fsm == TXD_BUSY);
assign master_run    = spi_en & ms_mode & ~tx_fifo_empty & (~cs_mode | ~spi_cs_n);
assign slave_run     = spi_en & ~ms_mode & cs_sel_r;
assign spi_run       = master_run | slave_run;
assign master_active = spi_busy & ms_mode;
assign slave_active  = spi_busy & ~ms_mode;
assign master_end    = master_active & pre_end_r & sck_tick & (spi_sck_out == cpol);
assign slave_end     = slave_active & ~cs_sel_r;
assign spi_end       = master_end | slave_end;

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        txd_fsm <= #UDLY TXD_IDLE;
    else if(~spi_en)
        txd_fsm <= #UDLY TXD_IDLE;
    else
        txd_fsm <= #UDLY txd_fsm_nx;
end

always @(*) begin
    case(txd_fsm)
        TXD_IDLE : begin
            if(spi_run)
                txd_fsm_nx = TXD_BUSY;
            else
                txd_fsm_nx = TXD_IDLE;
        end
        TXD_BUSY : begin
            if(spi_end)
                txd_fsm_nx = TXD_IDLE;
            else
                txd_fsm_nx = TXD_BUSY;
        end
        default : begin
            txd_fsm_nx = TXD_IDLE;
        end
    endcase
end

//////////////////////////////////////////////////
//3. TX Data Normalize
//////////////////////////////////////////////////
always @(*) begin
    txd_data = 32'd0;
    case(spi_size)
        2'd0 : begin
            if(lsb)
                txd_data[7:0] = {tx_fifo_rdata[0], tx_fifo_rdata[1], tx_fifo_rdata[2], tx_fifo_rdata[3],
                                 tx_fifo_rdata[4], tx_fifo_rdata[5], tx_fifo_rdata[6], tx_fifo_rdata[7]};
            else
                txd_data[7:0] = tx_fifo_rdata[7:0];
        end
        2'd1 : begin
            if(lsb)
                txd_data[15:0] = {tx_fifo_rdata[0],  tx_fifo_rdata[1],  tx_fifo_rdata[2],  tx_fifo_rdata[3],
                                  tx_fifo_rdata[4],  tx_fifo_rdata[5],  tx_fifo_rdata[6],  tx_fifo_rdata[7],
                                  tx_fifo_rdata[8],  tx_fifo_rdata[9],  tx_fifo_rdata[10], tx_fifo_rdata[11],
                                  tx_fifo_rdata[12], tx_fifo_rdata[13], tx_fifo_rdata[14], tx_fifo_rdata[15]};
            else
                txd_data[15:0] = tx_fifo_rdata[15:0];
        end
        2'd2 : begin
            if(lsb)
                txd_data = {tx_fifo_rdata[0],  tx_fifo_rdata[1],  tx_fifo_rdata[2],  tx_fifo_rdata[3],
                            tx_fifo_rdata[4],  tx_fifo_rdata[5],  tx_fifo_rdata[6],  tx_fifo_rdata[7],
                            tx_fifo_rdata[8],  tx_fifo_rdata[9],  tx_fifo_rdata[10], tx_fifo_rdata[11],
                            tx_fifo_rdata[12], tx_fifo_rdata[13], tx_fifo_rdata[14], tx_fifo_rdata[15],
                            tx_fifo_rdata[16], tx_fifo_rdata[17], tx_fifo_rdata[18], tx_fifo_rdata[19],
                            tx_fifo_rdata[20], tx_fifo_rdata[21], tx_fifo_rdata[22], tx_fifo_rdata[23],
                            tx_fifo_rdata[24], tx_fifo_rdata[25], tx_fifo_rdata[26], tx_fifo_rdata[27],
                            tx_fifo_rdata[28], tx_fifo_rdata[29], tx_fifo_rdata[30], tx_fifo_rdata[31]};
            else
                txd_data = tx_fifo_rdata;
        end
        default : begin
            if(lsb)
                txd_data[7:0] = {tx_fifo_rdata[0], tx_fifo_rdata[1], tx_fifo_rdata[2], tx_fifo_rdata[3],
                                 tx_fifo_rdata[4], tx_fifo_rdata[5], tx_fifo_rdata[6], tx_fifo_rdata[7]};
            else
                txd_data[7:0] = tx_fifo_rdata[7:0];
        end
    endcase
end

//////////////////////////////////////////////////
//4. Master Clock
//////////////////////////////////////////////////
assign sck_tick           = master_active & (div_cnt == clk_div);
assign master_data_edge   = sck_tick & ~pre_end_r;
assign master_return_edge = sck_tick & pre_end_r & (spi_sck_out != cpol);
assign master_sck_edge    = master_data_edge | master_return_edge;

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        pre_end_r <= #UDLY 1'd0;
    else if(~spi_en | ~master_active)
        pre_end_r <= #UDLY 1'd0;
    else if(pre_end)
        pre_end_r <= #UDLY 1'd1;
end

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        div_cnt <= #UDLY 16'd0;
    else if(~spi_en | ~master_active)
        div_cnt <= #UDLY 16'd0;
    else if(sck_tick)
        div_cnt <= #UDLY 16'd0;
    else
        div_cnt <= #UDLY div_cnt + 16'd1;
end

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        spi_sck_out <= #UDLY 1'd0;
    else if(~spi_en)
        spi_sck_out <= #UDLY 1'd0;
    else if(~ms_mode)
        spi_sck_out <= #UDLY 1'd0;
    else if(~spi_busy)
        spi_sck_out <= #UDLY cpol;
    else if(master_sck_edge)
        spi_sck_out <= #UDLY ~spi_sck_out;
end

//////////////////////////////////////////////////
//5. SCK Edge And Mode Trigger
//////////////////////////////////////////////////
assign master_sck_pos = master_data_edge & ~spi_sck_out;
assign master_sck_neg = master_data_edge & spi_sck_out;
assign slave_sck_pos  = slave_active & ~slave_sck_r & spi_sck_in;
assign slave_sck_neg  = slave_active & slave_sck_r & ~spi_sck_in;
assign sck_pos        = ms_mode ? master_sck_pos : slave_sck_pos;
assign sck_neg        = ms_mode ? master_sck_neg : slave_sck_neg;

always @(*) begin
    sample_trig = 1'd0;
    launch_trig = 1'd0;
    case(spi_mode)
        2'd0 : begin
            sample_trig = sck_pos;
            launch_trig = sck_neg;
        end
        2'd1 : begin
            sample_trig = sck_neg;
            launch_trig = sck_pos;
        end
        2'd2 : begin
            sample_trig = sck_neg;
            launch_trig = sck_pos;
        end
        2'd3 : begin
            sample_trig = sck_pos;
            launch_trig = sck_neg;
        end
        default : begin
            sample_trig = sck_pos;
            launch_trig = sck_neg;
        end
    endcase
end

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        slave_sck_r <= #UDLY 1'd0;
    else if(~spi_en | ms_mode)
        slave_sck_r <= #UDLY 1'd0;
    else
        slave_sck_r <= #UDLY spi_sck_in;
end

//////////////////////////////////////////////////
//6. Word Counter And FIFO Read
//////////////////////////////////////////////////
assign last_index  = (spi_size == 2'd1) ? 5'd15 :
                     (spi_size == 2'd2) ? 5'd31 : 5'd7;
assign pre_end     = master_active & bit_end & (tx_fifo_level == 6'd1);
assign bit_end      = spi_en & sample_trig & (bit_cnt == 5'd0);
assign tx_fifo_rinc = spi_en & bit_end;

always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        bit_cnt <= #UDLY 5'd0;
    else if(~spi_en)
        bit_cnt <= #UDLY 5'd0;
    else if(~spi_busy) begin
        if(spi_run)
            bit_cnt <= #UDLY last_index;
        else
            bit_cnt <= #UDLY 5'd0;
    end
    else if(bit_end)
        bit_cnt <= #UDLY last_index;
    else if(sample_trig)
        bit_cnt <= #UDLY bit_cnt - 5'd1;
end

//////////////////////////////////////////////////
//7. Serial Data And Pin Control
//////////////////////////////////////////////////
always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        txd_bit <= #UDLY 1'd0;
    else if(~spi_en)
        txd_bit <= #UDLY 1'd0;
    else if(~spi_busy) begin
        txd_bit <= #UDLY 1'd0;
        if(spi_run & ~cpha)
            txd_bit <= #UDLY txd_data[last_index];
    end
    else if(launch_trig)
        txd_bit <= #UDLY txd_data[bit_cnt];
end

assign spi_cs_n    = cs_mode ? ~manual_cs_active_sync : ~(spi_en & ms_mode & spi_busy);
assign spi_mosi_out = ms_mode ? txd_bit : 1'd0;
assign spi_miso_out = ms_mode ? 1'd0 : txd_bit;
assign spi_sck_oe   = spi_en & ms_mode;
assign spi_mosi_oe  = spi_en & ms_mode;
assign spi_miso_oe  = spi_en & ~ms_mode & cs_sel_r;
assign spi_cs_oe    = {4{spi_en & ms_mode}};

endmodule
