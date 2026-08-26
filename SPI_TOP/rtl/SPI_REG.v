`timescale 1ns / 1ps
`default_nettype none

module SPI_REG #(
    parameter integer       AXI_ADDR_WIDTH              = 15            ,
    parameter integer       UDLY                        = 1
)(
    input   wire                            SYS_CLK                     ,
    input   wire                            SYS_RST_N                   ,
    input   wire                            SPI_RST_EN                  ,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR               ,
    input   wire        [2:0]               S_AXI_AWPROT                ,
    input   wire                            S_AXI_AWVALID               ,
    output  wire                            S_AXI_AWREADY               ,
    input   wire        [31:0]              S_AXI_WDATA                ,
    input   wire        [3:0]               S_AXI_WSTRB                ,
    input   wire                            S_AXI_WVALID               ,
    output  wire                            S_AXI_WREADY               ,
    output  reg         [1:0]               S_AXI_BRESP                ,
    output  reg                             S_AXI_BVALID               ,
    input   wire                            S_AXI_BREADY               ,
    input   wire        [AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR               ,
    input   wire        [2:0]               S_AXI_ARPROT                ,
    input   wire                            S_AXI_ARVALID               ,
    output  wire                            S_AXI_ARREADY               ,
    output  reg         [31:0]              S_AXI_RDATA                ,
    output  reg         [1:0]               S_AXI_RRESP                ,
    output  reg                             S_AXI_RVALID               ,
    input   wire                            S_AXI_RREADY               ,
    input   wire                            busy_sys                    ,
    input   wire                            done_pulse_sys              ,
    input   wire                            error_pulse_sys             ,
    input   wire                            tx_underflow_sys            ,
    input   wire                            rx_overflow_sys             ,
    input   wire                            tx_fifo_full                ,
    input   wire        [8:0]               tx_fifo_level               ,
    input   wire                            rx_fifo_empty               ,
    input   wire        [8:0]               rx_fifo_level               ,
    input   wire        [31:0]              rx_fifo_rdata               ,
    output  wire                            tx_fifo_wen                 ,
    output  wire        [31:0]              tx_fifo_wdata               ,
    output  wire                            rx_fifo_ren                 ,
    output  wire                            spi_enable                  ,
    output  wire                            run_request                 ,
    output  wire                            tx_fifo_clear               ,
    output  wire                            rx_fifo_clear               ,
    output  wire        [7:0]               spi_command                ,
    output  wire        [11:0]              spi_address                ,
    output  wire        [15:0]              spi_length
);

localparam  [1:0]                   AXI_OKAY                = 2'b00      ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_CTL            = 15'h0000  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_CMD            = 15'h0004  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_ADDR           = 15'h0008  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_LEN            = 15'h000C  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_TXDATA         = 15'h0010  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_RXDATA         = 15'h0014  ;
localparam  [AXI_ADDR_WIDTH-1:0]    ADDR_SPI_STA            = 15'h0018  ;

reg         [AXI_ADDR_WIDTH-1:0]    write_address                         ;
reg         [31:0]                  write_data                            ;
reg         [3:0]                   write_strobe                          ;
reg         [AXI_ADDR_WIDTH-1:0]    read_address                          ;
reg                                 write_address_pending                 ;
reg                                 write_data_pending                    ;
reg                                 read_address_pending                  ;
reg         [3:0]                   control_register                      ;
reg         [7:0]                   command_register                      ;
reg         [11:0]                  address_register                      ;
reg         [15:0]                  length_register                       ;
reg                                 done_status                           ;
reg                                 error_status                          ;
reg         [3:0]                   exception_status                      ;
reg         [3:0]                   exception_status_next                 ;
reg                                 rx_pop_pending                        ;

wire                                write_address_accept                  ;
wire                                write_data_accept                     ;
wire                                read_address_accept                   ;
wire                                write_access                          ;
wire                                read_access                           ;
wire                                full_word_write                       ;
wire                                aligned_write                         ;
wire                                aligned_read                          ;
wire                                business_write                        ;
wire                                reg_0000h_write                       ;
wire                                reg_0000h_read                        ;
wire                                reg_0004h_write                       ;
wire                                reg_0004h_read                        ;
wire                                reg_0008h_write                       ;
wire                                reg_0008h_read                        ;
wire                                reg_000ch_write                       ;
wire                                reg_000ch_read                        ;
wire                                reg_0010h_write                       ;
wire                                reg_0010h_read                        ;
wire                                reg_0014h_read                        ;
wire                                reg_0018h_write                       ;
wire                                reg_0018h_read                        ;
wire                                run_accept                            ;
wire                                tx_overflow_event                     ;
wire                                rx_underflow_event                    ;
wire                                tx_fifo_empty_status                  ;
wire                                rx_fifo_full_status                   ;
wire        [31:0]                  reg_0000h                             ;
wire        [31:0]                  reg_0004h                             ;
wire        [31:0]                  reg_0008h                             ;
wire        [31:0]                  reg_000ch                             ;
wire        [31:0]                  reg_0010h                             ;
wire        [31:0]                  reg_0014h                             ;
wire        [31:0]                  reg_0018h                             ;
wire        [31:0]                  read_data                             ;

//////////////////////////////////////////////////
//1. AXI4-Lite Protocol
//////////////////////////////////////////////////
assign S_AXI_AWREADY = SYS_RST_N &
                       ~write_address_pending &
                       ~S_AXI_BVALID;
assign S_AXI_WREADY  = SYS_RST_N &
                       ~write_data_pending &
                       ~S_AXI_BVALID;
assign S_AXI_ARREADY = SYS_RST_N &
                       ~read_address_pending &
                       ~S_AXI_RVALID;

assign write_address_accept = S_AXI_AWREADY & S_AXI_AWVALID;
assign write_data_accept    = S_AXI_WREADY  & S_AXI_WVALID;
assign read_address_accept  = S_AXI_ARREADY & S_AXI_ARVALID;
assign write_access         = write_address_pending &
                              write_data_pending &
                              ~S_AXI_BVALID;
assign read_access          = read_address_pending & ~S_AXI_RVALID;

// AWPROT and ARPROT are standard interface attributes. Access control is
// owned by the system interconnect, so the register bank intentionally does
// not consume them.

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        write_address <= #UDLY {AXI_ADDR_WIDTH{1'b0}};
    else if(write_address_accept)
        write_address <= #UDLY S_AXI_AWADDR;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        write_address_pending <= #UDLY 1'b0;
    else if(write_access)
        write_address_pending <= #UDLY 1'b0;
    else if(write_address_accept)
        write_address_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        write_data   <= #UDLY 32'h0000_0000;
        write_strobe <= #UDLY 4'h0;
    end
    else if(write_data_accept) begin
        write_data   <= #UDLY S_AXI_WDATA;
        write_strobe <= #UDLY S_AXI_WSTRB;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        write_data_pending <= #UDLY 1'b0;
    else if(write_access)
        write_data_pending <= #UDLY 1'b0;
    else if(write_data_accept)
        write_data_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(S_AXI_BVALID & S_AXI_BREADY)
        S_AXI_BVALID <= #UDLY 1'b0;
    else if(write_access)
        S_AXI_BVALID <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_BRESP <= #UDLY AXI_OKAY;
    else if(write_access)
        S_AXI_BRESP <= #UDLY AXI_OKAY;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        read_address <= #UDLY {AXI_ADDR_WIDTH{1'b0}};
    else if(read_address_accept)
        read_address <= #UDLY S_AXI_ARADDR;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        read_address_pending <= #UDLY 1'b0;
    else if(read_access)
        read_address_pending <= #UDLY 1'b0;
    else if(read_address_accept)
        read_address_pending <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        S_AXI_RVALID <= #UDLY 1'b0;
    else if(S_AXI_RVALID & S_AXI_RREADY)
        S_AXI_RVALID <= #UDLY 1'b0;
    else if(read_access)
        S_AXI_RVALID <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        S_AXI_RDATA <= #UDLY 32'h0000_0000;
        S_AXI_RRESP <= #UDLY AXI_OKAY;
    end
    else if(read_access) begin
        S_AXI_RDATA <= #UDLY read_data;
        S_AXI_RRESP <= #UDLY AXI_OKAY;
    end
end

//////////////////////////////////////////////////
//2. Address Decode
//////////////////////////////////////////////////
assign full_word_write = (write_strobe == 4'hF);
assign aligned_write   = (write_address[1:0] == 2'b00);
assign aligned_read    = (read_address[1:0] == 2'b00);
assign business_write  = write_access & SPI_RST_EN &
                         full_word_write & aligned_write;

assign reg_0000h_write = business_write &
                         (write_address == ADDR_SPI_CTL);
assign reg_0000h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_CTL);
assign reg_0004h_write = business_write &
                         (write_address == ADDR_SPI_CMD);
assign reg_0004h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_CMD);
assign reg_0008h_write = business_write &
                         (write_address == ADDR_SPI_ADDR);
assign reg_0008h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_ADDR);
assign reg_000ch_write = business_write &
                         (write_address == ADDR_SPI_LEN);
assign reg_000ch_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_LEN);
assign reg_0010h_write = business_write &
                         (write_address == ADDR_SPI_TXDATA);
assign reg_0010h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_TXDATA);
assign reg_0014h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_RXDATA);
assign reg_0018h_write = business_write &
                         (write_address == ADDR_SPI_STA);
assign reg_0018h_read  = read_access & aligned_read &
                         (read_address == ADDR_SPI_STA);

//////////////////////////////////////////////////
//3. Register Encode
//////////////////////////////////////////////////
assign run_accept = reg_0000h_write &
                    write_data[1] &
                    write_data[0] &
                    control_register[0] &
                    ~control_register[1] &
                    ~busy_sys;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        control_register <= #UDLY 4'h0;
    else if(!SPI_RST_EN)
        control_register <= #UDLY 4'h0;
    else begin
        if(reg_0000h_write) begin
            control_register[3:2] <= #UDLY write_data[3:2];
            control_register[0]   <= #UDLY write_data[0];
        end
        if(done_pulse_sys | error_pulse_sys)
            control_register[1] <= #UDLY 1'b0;
        else if(reg_0000h_write & ~write_data[0])
            control_register[1] <= #UDLY 1'b0;
        else if(run_accept)
            control_register[1] <= #UDLY 1'b1;
        else if(~control_register[0])
            control_register[1] <= #UDLY 1'b0;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        command_register <= #UDLY 8'h00;
    else if(!SPI_RST_EN)
        command_register <= #UDLY 8'h00;
    else if(reg_0004h_write)
        command_register <= #UDLY write_data[7:0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        address_register <= #UDLY 12'h000;
    else if(!SPI_RST_EN)
        address_register <= #UDLY 12'h000;
    else if(reg_0008h_write)
        address_register <= #UDLY write_data[11:0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        length_register <= #UDLY 16'h0000;
    else if(!SPI_RST_EN)
        length_register <= #UDLY 16'h0000;
    else if(reg_000ch_write)
        length_register <= #UDLY write_data[15:0];
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        done_status  <= #UDLY 1'b0;
        error_status <= #UDLY 1'b0;
    end
    else if(!SPI_RST_EN) begin
        done_status  <= #UDLY 1'b0;
        error_status <= #UDLY 1'b0;
    end
    else if(!control_register[0] |
            (reg_0000h_write & ~write_data[0]) |
            run_accept) begin
        done_status  <= #UDLY 1'b0;
        error_status <= #UDLY 1'b0;
    end
    else begin
        if(done_pulse_sys)
            done_status <= #UDLY 1'b1;
        if(error_pulse_sys | tx_underflow_sys | rx_overflow_sys)
            error_status <= #UDLY 1'b1;
    end
end

assign tx_overflow_event  = reg_0010h_write & tx_fifo_full;
assign rx_underflow_event = reg_0014h_read & rx_fifo_empty;
assign tx_fifo_empty_status = (tx_fifo_level == 9'd0);
assign rx_fifo_full_status  = (rx_fifo_level == 9'd256);

always @(*) begin
    exception_status_next = exception_status;
    if(reg_0018h_write)
        exception_status_next = exception_status &
                                ~write_data[10:7];
    exception_status_next = exception_status_next |
                            {rx_underflow_event,
                             rx_overflow_sys,
                             tx_underflow_sys,
                             tx_overflow_event};
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        exception_status <= #UDLY 4'h0;
    else if(!SPI_RST_EN)
        exception_status <= #UDLY 4'h0;
    else
        exception_status <= #UDLY exception_status_next;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        rx_pop_pending <= #UDLY 1'b0;
    else if(!SPI_RST_EN)
        rx_pop_pending <= #UDLY 1'b0;
    else if(S_AXI_RVALID & S_AXI_RREADY)
        rx_pop_pending <= #UDLY 1'b0;
    else if(read_access)
        rx_pop_pending <= #UDLY reg_0014h_read & ~rx_fifo_empty;
end

assign tx_fifo_wen   = reg_0010h_write &
                       ~tx_fifo_full &
                       ~control_register[2];
assign tx_fifo_wdata = write_data;
assign rx_fifo_ren   = S_AXI_RVALID &
                       S_AXI_RREADY &
                       rx_pop_pending &
                       ~rx_fifo_empty &
                       ~control_register[3] &
                       SPI_RST_EN;

assign spi_enable    = control_register[0];
assign run_request   = run_accept;
assign tx_fifo_clear = control_register[2];
assign rx_fifo_clear = control_register[3];
assign spi_command   = command_register;
assign spi_address   = address_register;
assign spi_length    = length_register;

assign reg_0000h = {28'h000_0000, control_register};
assign reg_0004h = {24'h00_0000, command_register};
assign reg_0008h = {20'h0_0000, address_register};
assign reg_000ch = {16'h0000, length_register};
assign reg_0010h = 32'h0000_0000;
assign reg_0014h = rx_fifo_empty ?
                   32'h0000_0000 : rx_fifo_rdata;
assign reg_0018h = {3'b000,
                    rx_fifo_level,
                    tx_fifo_level,
                    exception_status,
                    rx_fifo_full_status,
                    rx_fifo_empty,
                    tx_fifo_full,
                    tx_fifo_empty_status,
                    error_status,
                    done_status,
                    busy_sys};

assign read_data = ({32{reg_0000h_read}} & reg_0000h) |
                   ({32{reg_0004h_read}} & reg_0004h) |
                   ({32{reg_0008h_read}} & reg_0008h) |
                   ({32{reg_000ch_read}} & reg_000ch) |
                   ({32{reg_0010h_read}} & reg_0010h) |
                   ({32{reg_0014h_read}} & reg_0014h) |
                   ({32{reg_0018h_read}} & reg_0018h);

endmodule

`default_nettype wire
