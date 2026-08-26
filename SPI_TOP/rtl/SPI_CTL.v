`timescale 1ns / 1ps
`default_nettype none

module SPI_CTL #(
    parameter integer       UDLY                        = 1
)(
    input   wire            SPI_CLK                                     ,
    input   wire            SPI_RST_N                                   ,
    input   wire            enable_spi                                  ,
    input   wire            run_pulse                                   ,
    input   wire    [7:0]   command                                     ,
    input   wire    [11:0]  address                                     ,
    input   wire    [15:0]  length                                      ,
    input   wire            spi_miso_i                                  ,
    input   wire    [15:0]  tx_unit_data                                ,
    output  reg             tx_unit_take                                ,
    output  wire            unit_is_16bit                               ,
    output  reg             rx_unit_valid                               ,
    output  reg             rx_unit_last                                ,
    output  reg     [15:0]  rx_unit_data                                ,
    output  reg             spi_mosi_o                                  ,
    output  reg             spi_sck_o                                   ,
    output  reg     [3:0]   spi_nss_code_o                              ,
    output  wire            busy_spi                                    ,
    output  reg             done_pulse                                  ,
    output  reg             error_pulse
);

localparam  [3:0]           STATE_IDLE                  = 4'd0           ;
localparam  [3:0]           STATE_CHECK                 = 4'd1           ;
localparam  [3:0]           STATE_ASSERT_CS             = 4'd2           ;
localparam  [3:0]           STATE_SETUP                 = 4'd3           ;
localparam  [3:0]           STATE_HEADER                = 4'd4           ;
localparam  [3:0]           STATE_PAYLOAD               = 4'd5           ;
localparam  [3:0]           STATE_HOLD                  = 4'd6           ;
localparam  [3:0]           STATE_DEASSERT_CS           = 4'd7           ;
localparam  [3:0]           STATE_GAP                   = 4'd8           ;
localparam  [3:0]           STATE_DONE                  = 4'd9           ;

reg         [3:0]           state                                       ;
reg         [3:0]           state_next                                  ;
reg                         control_load_header                         ;
reg                         control_header_active                       ;
reg                         control_payload_active                      ;
reg                         control_hold_active                         ;
reg                         control_gap_active                          ;
reg         [7:0]           half_count                                  ;
reg         [7:0]           half_limit                                  ;
reg         [2:0]           gap_half_count                              ;
reg         [5:0]           bit_count                                   ;
reg         [15:0]          unit_count                                  ;
reg         [31:0]          shift_register                              ;
reg         [15:0]          receive_shift                               ;
reg                         second_phase                                ;

wire                        target_is_au                                ;
wire                        operation_is_read                           ;
wire                        operation_is_burst                          ;
wire                        command_invalid                             ;
wire                        half_tick                                   ;
wire                        header_last_bit                             ;
wire                        payload_last_bit                            ;
wire                        payload_last_unit                           ;
wire                        payload_after_header                        ;
wire                        header_falling_edge                         ;
wire                        payload_rising_edge                         ;
wire                        payload_falling_edge                        ;
wire                        normal_au_first_phase                       ;
wire        [7:0]           au_command                                  ;
wire        [31:0]          header_word                                 ;

assign target_is_au       = (command[3:0] == 4'h0);
assign operation_is_read  = command[4];
assign operation_is_burst = command[5];
assign command_invalid    = (command[3:0] > 4'h8) |
                            (length == 16'd0) |
                            (~operation_is_burst & (length != 16'd1));
assign unit_is_16bit      = ~target_is_au;
assign busy_spi           = (state != STATE_IDLE);

assign half_tick = (half_count == half_limit);
assign normal_au_first_phase = target_is_au &
                               ~operation_is_burst &
                               ~second_phase;
assign payload_after_header = ~normal_au_first_phase;

assign header_last_bit = target_is_au ?
                         (second_phase ?
                          (bit_count == 6'd7) :
                          (bit_count == 6'd15)) :
                         (bit_count == 6'd15);
assign payload_last_bit = target_is_au ?
                          (bit_count == 6'd7) :
                          (bit_count == 6'd15);
assign payload_last_unit = (unit_count == (length - 16'd1));

assign header_falling_edge  = control_header_active &
                              half_tick & spi_sck_o;
assign payload_rising_edge  = control_payload_active &
                              half_tick & ~spi_sck_o;
assign payload_falling_edge = control_payload_active &
                              half_tick & spi_sck_o;

assign au_command = second_phase ?
                    (operation_is_read ? 8'h80 : 8'h40) :
                    operation_is_burst ?
                    (operation_is_read ? 8'h20 : 8'hE0) :
                    8'h00;

assign header_word = target_is_au ?
                     (second_phase ?
                      {au_command, 24'h00_0000} :
                      {au_command, address[7:0], 16'h0000}) :
                     {command[5:4], address, 2'b00, 16'h0000};

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N)
        state <= #UDLY STATE_IDLE;
    else if(!enable_spi)
        state <= #UDLY STATE_IDLE;
    else
        state <= #UDLY state_next;
end

always @(*) begin
    state_next = state;
    case(state)
        STATE_IDLE:
            if(run_pulse)
                state_next = STATE_CHECK;
        STATE_CHECK:
            if(command_invalid)
                state_next = STATE_DONE;
            else
                state_next = STATE_ASSERT_CS;
        STATE_ASSERT_CS:
            state_next = STATE_SETUP;
        STATE_SETUP:
            if(half_tick)
                state_next = STATE_HEADER;
        STATE_HEADER:
            if(header_falling_edge & header_last_bit) begin
                if(payload_after_header)
                    state_next = STATE_PAYLOAD;
                else
                    state_next = STATE_HOLD;
            end
        STATE_PAYLOAD:
            if(payload_falling_edge & payload_last_bit &
               payload_last_unit)
                state_next = STATE_HOLD;
        STATE_HOLD:
            if(half_tick)
                state_next = STATE_DEASSERT_CS;
        STATE_DEASSERT_CS:
            if(normal_au_first_phase)
                state_next = STATE_GAP;
            else
                state_next = STATE_DONE;
        STATE_GAP:
            if(half_tick & (gap_half_count == 3'd3))
                state_next = STATE_ASSERT_CS;
        STATE_DONE:
            state_next = STATE_IDLE;
        default:
            state_next = STATE_IDLE;
    endcase
end

always @(*) begin
    control_load_header    = 1'b0;
    control_header_active  = 1'b0;
    control_payload_active = 1'b0;
    control_hold_active    = 1'b0;
    control_gap_active     = 1'b0;
    case(state)
        STATE_ASSERT_CS:
            control_load_header = 1'b1;
        STATE_HEADER:
            control_header_active = 1'b1;
        STATE_PAYLOAD:
            control_payload_active = 1'b1;
        STATE_HOLD:
            control_hold_active = 1'b1;
        STATE_GAP:
            control_gap_active = 1'b1;
        default: begin
            control_load_header    = 1'b0;
            control_header_active  = 1'b0;
            control_payload_active = 1'b0;
            control_hold_active    = 1'b0;
            control_gap_active     = 1'b0;
        end
    endcase
end

always @(*) begin
    case(command[7:6])
        2'b00:
            half_limit = 8'd99;
        2'b01:
            half_limit = 8'd19;
        2'b10:
            half_limit = 8'd9;
        default:
            half_limit = 8'd4;
    endcase
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N)
        half_count <= #UDLY 8'd0;
    else if(!enable_spi)
        half_count <= #UDLY 8'd0;
    else if((state == STATE_SETUP) |
            control_header_active |
            control_payload_active |
            control_hold_active |
            control_gap_active)
        half_count <= #UDLY
                      half_tick ? 8'd0 : (half_count + 8'd1);
    else
        half_count <= #UDLY 8'd0;
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N)
        gap_half_count <= #UDLY 3'd0;
    else if(!enable_spi)
        gap_half_count <= #UDLY 3'd0;
    else if(!control_gap_active)
        gap_half_count <= #UDLY 3'd0;
    else if(half_tick)
        gap_half_count <= #UDLY gap_half_count + 3'd1;
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        spi_sck_o      <= #UDLY 1'b0;
        spi_mosi_o     <= #UDLY 1'b0;
        shift_register <= #UDLY 32'h0000_0000;
    end
    else if(!enable_spi) begin
        spi_sck_o      <= #UDLY 1'b0;
        spi_mosi_o     <= #UDLY 1'b0;
        shift_register <= #UDLY 32'h0000_0000;
    end
    else begin
        if(control_load_header) begin
            spi_sck_o      <= #UDLY 1'b0;
            shift_register <= #UDLY header_word;
            spi_mosi_o     <= #UDLY header_word[31];
        end
        else if((state == STATE_SETUP) & half_tick)
            spi_sck_o <= #UDLY 1'b1;
        else if((control_header_active | control_payload_active) &
                half_tick)
            spi_sck_o <= #UDLY ~spi_sck_o;
        else if(!control_header_active &
                !control_payload_active &
                (state != STATE_SETUP))
            spi_sck_o <= #UDLY 1'b0;

        if(header_falling_edge) begin
            if(header_last_bit) begin
                if(payload_after_header & ~operation_is_read) begin
                    shift_register <= #UDLY
                                      unit_is_16bit ?
                                      {tx_unit_data, 16'h0000} :
                                      {tx_unit_data[7:0], 24'h00_0000};
                    spi_mosi_o <= #UDLY
                                  unit_is_16bit ?
                                  tx_unit_data[15] : tx_unit_data[7];
                end
                else begin
                    shift_register <= #UDLY 32'h0000_0000;
                    spi_mosi_o     <= #UDLY 1'b0;
                end
            end
            else begin
                shift_register <= #UDLY
                                  {shift_register[30:0], 1'b0};
                spi_mosi_o <= #UDLY shift_register[30];
            end
        end
        else if(payload_falling_edge) begin
            if(payload_last_bit) begin
                if(~payload_last_unit & ~operation_is_read) begin
                    shift_register <= #UDLY
                                      unit_is_16bit ?
                                      {tx_unit_data, 16'h0000} :
                                      {tx_unit_data[7:0], 24'h00_0000};
                    spi_mosi_o <= #UDLY
                                  unit_is_16bit ?
                                  tx_unit_data[15] : tx_unit_data[7];
                end
                else begin
                    shift_register <= #UDLY 32'h0000_0000;
                    spi_mosi_o     <= #UDLY 1'b0;
                end
            end
            else begin
                shift_register <= #UDLY
                                  {shift_register[30:0], 1'b0};
                spi_mosi_o <= #UDLY shift_register[30];
            end
        end
        else if((state == STATE_DEASSERT_CS) |
                (state == STATE_DONE))
            spi_mosi_o <= #UDLY 1'b0;
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        bit_count     <= #UDLY 6'd0;
        unit_count    <= #UDLY 16'd0;
        receive_shift <= #UDLY 16'h0000;
        second_phase  <= #UDLY 1'b0;
    end
    else if(!enable_spi) begin
        bit_count     <= #UDLY 6'd0;
        unit_count    <= #UDLY 16'd0;
        receive_shift <= #UDLY 16'h0000;
        second_phase  <= #UDLY 1'b0;
    end
    else if(state == STATE_CHECK) begin
        bit_count     <= #UDLY 6'd0;
        unit_count    <= #UDLY 16'd0;
        receive_shift <= #UDLY 16'h0000;
        second_phase  <= #UDLY 1'b0;
    end
    else begin
        if((state == STATE_DEASSERT_CS) & normal_au_first_phase)
            second_phase <= #UDLY 1'b1;
        if(payload_rising_edge & operation_is_read)
            receive_shift <= #UDLY
                             {receive_shift[14:0], spi_miso_i};
        if(header_falling_edge)
            bit_count <= #UDLY
                         header_last_bit ?
                         6'd0 : (bit_count + 6'd1);
        else if(payload_falling_edge) begin
            if(payload_last_bit) begin
                bit_count     <= #UDLY 6'd0;
                unit_count    <= #UDLY unit_count + 16'd1;
                receive_shift <= #UDLY 16'h0000;
            end
            else
                bit_count <= #UDLY bit_count + 6'd1;
        end
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N)
        spi_nss_code_o <= #UDLY 4'hF;
    else if(!enable_spi)
        spi_nss_code_o <= #UDLY 4'hF;
    else if(control_load_header)
        spi_nss_code_o <= #UDLY command[3:0];
    else if(control_hold_active & half_tick)
        spi_nss_code_o <= #UDLY 4'hF;
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        tx_unit_take <= #UDLY 1'b0;
        rx_unit_valid <= #UDLY 1'b0;
        rx_unit_last <= #UDLY 1'b0;
        rx_unit_data <= #UDLY 16'h0000;
    end
    else if(!enable_spi) begin
        tx_unit_take <= #UDLY 1'b0;
        rx_unit_valid <= #UDLY 1'b0;
        rx_unit_last <= #UDLY 1'b0;
        rx_unit_data <= #UDLY 16'h0000;
    end
    else begin
        tx_unit_take <= #UDLY 1'b0;
        rx_unit_valid <= #UDLY 1'b0;
        rx_unit_last <= #UDLY 1'b0;
        if(header_falling_edge & header_last_bit &
           payload_after_header & ~operation_is_read)
            tx_unit_take <= #UDLY 1'b1;
        if(payload_falling_edge & payload_last_bit) begin
            if(operation_is_read) begin
                rx_unit_valid <= #UDLY 1'b1;
                rx_unit_last  <= #UDLY payload_last_unit;
                rx_unit_data  <= #UDLY receive_shift;
            end
            else if(~payload_last_unit)
                tx_unit_take <= #UDLY 1'b1;
        end
    end
end

always @(posedge SPI_CLK or negedge SPI_RST_N) begin
    if(!SPI_RST_N) begin
        done_pulse  <= #UDLY 1'b0;
        error_pulse <= #UDLY 1'b0;
    end
    else if(!enable_spi) begin
        done_pulse  <= #UDLY 1'b0;
        error_pulse <= #UDLY 1'b0;
    end
    else begin
        done_pulse  <= #UDLY 1'b0;
        error_pulse <= #UDLY 1'b0;
        if(state == STATE_DONE) begin
            done_pulse  <= #UDLY ~command_invalid;
            error_pulse <= #UDLY command_invalid;
        end
    end
end

endmodule

`default_nettype wire
