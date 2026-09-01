`timescale 1ns / 1ps

module SPI_RXD(
    input                                   spi_clk                                        ,
    input                                   rst_n                                          ,

    input                                   spi_en                                         ,
    input               [31:0]              spi_ctl                                        ,
    input                                   sample_trig                                    ,
    input                                   bit_end                                        ,
    input                                   spi_busy                                       ,
    input                                   spi_miso_in                                    ,
    input                                   spi_mosi_in                                    ,

    output    wire      [31:0]              rx_fifo_wdata                                  ,
    output    wire                          rx_fifo_winc
);

parameter                                   UDLY                     = 1                   ;

wire                                        ms_mode                                        ;
wire                                        lsb                                            ;
wire                    [ 1:0]              spi_size                                       ;
wire                                        serial_data                                    ;
wire                    [31:0]              rxd_buff_nx                                    ;

reg                     [31:0]              rxd_data                                       ;
reg                     [31:0]              rxd_buff                                       ;

//////////////////////////////////////////////////
//1. Configuration And Serial Select
//////////////////////////////////////////////////
assign ms_mode     = spi_ctl[1];
assign lsb         = spi_ctl[6];
assign spi_size    = spi_ctl[8:7];
assign serial_data = ms_mode ? spi_miso_in : spi_mosi_in;
assign rxd_buff_nx = lsb ? {serial_data, rxd_buff[31:1]} :
                           {rxd_buff[30:0], serial_data};

//////////////////////////////////////////////////
//2. RX Data Normalize And FIFO Write
//////////////////////////////////////////////////
always @(*) begin
    rxd_data = 32'd0;
    case(spi_size)
        2'd0 : begin
            if(lsb)
                rxd_data[7:0] = rxd_buff_nx[31:24];
            else
                rxd_data[7:0] = rxd_buff_nx[7:0];
        end
        2'd1 : begin
            if(lsb)
                rxd_data[15:0] = rxd_buff_nx[31:16];
            else
                rxd_data[15:0] = rxd_buff_nx[15:0];
        end
        2'd2 : begin
            rxd_data = rxd_buff_nx;
        end
        default : begin
            if(lsb)
                rxd_data[7:0] = rxd_buff_nx[31:24];
            else
                rxd_data[7:0] = rxd_buff_nx[7:0];
        end
    endcase
end

assign rx_fifo_wdata = rxd_data;
assign rx_fifo_winc  = bit_end;

//////////////////////////////////////////////////
//3. Receive Buffer
//////////////////////////////////////////////////
always @(posedge spi_clk or negedge rst_n) begin
    if(~rst_n)
        rxd_buff <= #UDLY 32'd0;
    else if(~spi_en | ~spi_busy)
        rxd_buff <= #UDLY 32'd0;
    else if(bit_end)
        rxd_buff <= #UDLY 32'd0;
    else if(sample_trig)
        rxd_buff <= #UDLY rxd_buff_nx;
end

endmodule
