`timescale 1ns / 1ps
`default_nettype none

// Pure fourteen-byte CRC-16/CCITT-FALSE calculator.  Protocol ownership,
// request comparison, and response construction remain in ASU_FRT.
module ASU_CRC
(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             CRC_START                                   ,
    input  wire [111:0]                     CRC_DATA                                    ,
    output reg                              CRC_BUSY                                    ,
    output reg                              CRC_DONE                                    ,
    output reg  [15:0]                      CRC_VALUE
);

parameter integer                           UDLY                        = 1              ;

reg  [15:0]                                 crc_accum                                    ;
reg  [3:0]                                  byte_index                                   ;
reg  [7:0]                                  data_byte                                    ;
wire [15:0]                                 crc_next                                     ;
wire [15:0]                                 crc_first                                    ;

always @(*) begin
    data_byte = 8'h00;
    case(byte_index)
        4'd0:    data_byte = CRC_DATA[111:104];
        4'd1:    data_byte = CRC_DATA[103:96];
        4'd2:    data_byte = CRC_DATA[95:88];
        4'd3:    data_byte = CRC_DATA[87:80];
        4'd4:    data_byte = CRC_DATA[79:72];
        4'd5:    data_byte = CRC_DATA[71:64];
        4'd6:    data_byte = CRC_DATA[63:56];
        4'd7:    data_byte = CRC_DATA[55:48];
        4'd8:    data_byte = CRC_DATA[47:40];
        4'd9:    data_byte = CRC_DATA[39:32];
        4'd10:   data_byte = CRC_DATA[31:24];
        4'd11:   data_byte = CRC_DATA[23:16];
        4'd12:   data_byte = CRC_DATA[15:8];
        4'd13:   data_byte = CRC_DATA[7:0];
        default: data_byte = 8'h00;
    endcase
end

CRC16 crc16_byte_inst
(
    .crc_in                               (crc_accum                                    ),
    .data_in                              (data_byte                                    ),
    .crc_out                              (crc_next                                     )
);

CRC16 crc16_first_byte_inst
(
    .crc_in                               (16'hFFFF                                     ),
    .data_in                              (CRC_DATA[111:104]                            ),
    .crc_out                              (crc_first                                    )
);

// Exactly five assignment targets; no enumerated state machine is required.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        crc_accum <= #UDLY 16'hFFFF;
        byte_index <= #UDLY 4'd0;
        CRC_BUSY <= #UDLY 1'b0;
        CRC_DONE <= #UDLY 1'b0;
        CRC_VALUE <= #UDLY 16'h0000;
    end else if(CRC_START & ~CRC_BUSY) begin
        // The launch edge processes Byte 0, followed by Bytes 1 through 13.
        crc_accum <= #UDLY crc_first;
        byte_index <= #UDLY 4'd1;
        CRC_BUSY <= #UDLY 1'b1;
        CRC_DONE <= #UDLY 1'b0;
    end else if(CRC_BUSY) begin
        crc_accum <= #UDLY crc_next;
        CRC_DONE <= #UDLY 1'b0;
        if(byte_index == 4'd13) begin
            CRC_BUSY <= #UDLY 1'b0;
            CRC_DONE <= #UDLY 1'b1;
            CRC_VALUE <= #UDLY crc_next;
        end else begin
            byte_index <= #UDLY byte_index + 4'd1;
        end
    end else begin
        CRC_DONE <= #UDLY 1'b0;
    end
end

endmodule

`default_nettype wire
