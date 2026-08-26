`timescale 1ns / 1ps

module CRC16(
    input                                   adc_clk                                        ,
    input                                   adc_rst_n                                      ,

    input                                   start                                          ,
    input               [495:0]             header_data                                    ,

    output    reg                           busy                                           ,
    output    reg                           done                                           ,
    output    reg       [15:0]              crc
);

parameter                                   UDLY                     = 1                   ;

reg                     [15:0]              crc_work                                       ;
reg                     [15:0]              crc_step                                       ;
reg                     [ 5:0]              byte_cnt                                       ;

integer byte_index;
integer bit_index;
integer header_index;

always @(*) begin
    crc_step = crc_work;

    for(byte_index = 0; byte_index < 8; byte_index = byte_index + 1) begin
        header_index = {26'd0, byte_cnt} + byte_index;

        if(header_index < 62) begin
            crc_step = crc_step ^ {header_data[header_index*8 +: 8], 8'd0};

            for(bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if(crc_step[15])
                    crc_step = (crc_step << 1) ^ 16'h1021;
                else
                    crc_step = crc_step << 1;
            end
        end
    end
end

always @(posedge adc_clk or negedge adc_rst_n) begin
    if(!adc_rst_n) begin
        busy     <= #UDLY 1'b0;
        done     <= #UDLY 1'b0;
        crc      <= #UDLY 16'd0;
        crc_work <= #UDLY 16'hffff;
        byte_cnt <= #UDLY 6'd0;
    end
    else begin
        done <= #UDLY 1'b0;

        if(start & !busy) begin
            busy     <= #UDLY 1'b1;
            crc_work <= #UDLY 16'hffff;
            byte_cnt <= #UDLY 6'd0;
        end
        else if(busy & (byte_cnt == 6'd56)) begin
            busy     <= #UDLY 1'b0;
            done     <= #UDLY 1'b1;
            crc      <= #UDLY crc_step;
            crc_work <= #UDLY crc_step;
        end
        else if(busy) begin
            crc_work <= #UDLY crc_step;
            byte_cnt <= #UDLY byte_cnt + 6'd8;
        end
    end
end

endmodule
