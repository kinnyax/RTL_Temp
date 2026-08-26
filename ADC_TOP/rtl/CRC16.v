`timescale 1ns / 1ps

module CRC16(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input                                   start                                          ,
    input               [495:0]             header_data                                    ,

    output    wire                          busy                                           ,
    output    reg                           done                                           ,
    output    reg       [15:0]              crc
);

parameter                                   UDLY                     = 1                   ;

wire                    [15:0]              crc_step                                       ;

reg                     [495:0]             header_data_r                                  ;
reg                     [15:0]              crc_work                                       ;
reg                     [ 2:0]              crc_cnt                                        ;
reg                                         crc_busy                                       ;
reg                     [15:0]              crc_calc                                       ;
reg                     [ 7:0]              crc_byte                                       ;

integer i;
integer j;


always @(*) begin
    crc_calc = crc_work;
    crc_byte = 8'd0;
    for(i=0;i<8;i=i+1) begin
        if((crc_cnt<3'd7) || (i<6)) begin
            crc_byte = header_data_r[(crc_cnt*64)+(i*8) +: 8];
            for(j=0;j<8;j=j+1) begin
                if(crc_calc[15]^crc_byte[7-j])
                    crc_calc = {crc_calc[14:0],1'b0} ^ 16'h1021;
                else
                    crc_calc = {crc_calc[14:0],1'b0};
            end
        end
    end
end

assign crc_step = crc_calc;
assign busy     = crc_busy;

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(adc_rst_n==1'b0) begin
        header_data_r <= #UDLY 496'd0;
        crc_work      <= #UDLY 16'hffff;
        crc_cnt       <= #UDLY 3'd0;
        crc_busy      <= #UDLY 1'b0;
        done          <= #UDLY 1'b0;
        crc           <= #UDLY 16'd0;
    end
    else begin
        done <= #UDLY 1'b0;
        if(start && !crc_busy) begin
            header_data_r <= #UDLY header_data;
            crc_work      <= #UDLY 16'hffff;
            crc_cnt       <= #UDLY 3'd0;
            crc_busy      <= #UDLY 1'b1;
        end
        else if(crc_busy) begin
            crc_work <= #UDLY crc_step;
            if(crc_cnt==3'd7) begin
                crc_busy <= #UDLY 1'b0;
                done     <= #UDLY 1'b1;
                crc      <= #UDLY crc_step;
            end
            else begin
                crc_cnt <= #UDLY crc_cnt + 3'd1;
            end
        end
    end
end

endmodule
