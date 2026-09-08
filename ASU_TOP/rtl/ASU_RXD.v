`timescale 1ns / 1ps

module ASU_RXD(
    input                                   sys_clk                                        ,
    input                                   sys_rst_n                                      ,

    input                                   SPI_SCK                                        ,
    input                                   SPI_CS                                         ,
    input                                   SPI_MOSI                                       ,
    output    wire                          SPI_MISO                                       ,

    output    reg                           rxd_req                                        ,
    output    reg                           rxd_write                                      ,
    output    reg       [31:0]              rxd_addr                                       ,
    output    reg       [31:0]              rxd_wdata                                      ,
    input                                   txd_rdy                                        ,
    input                                   txd_timeout                                    ,
    input               [31:0]              txd_rdata
);

parameter                                   UDLY                     = 1                   ;

localparam              [15:0]              CMD_WRITE                = 16'hA501            ;
localparam              [15:0]              CMD_READ                 = 16'hA502            ;
localparam              [15:0]              RSP_HEADER               = 16'h5AA5            ;
localparam              [ 7:0]              STATUS_DONE              = 8'h00               ;
localparam              [ 7:0]              STATUS_WAIT              = 8'h01               ;
localparam              [ 7:0]              STATUS_REQ_ERR           = 8'h02               ;
localparam              [ 7:0]              STATUS_CRC_ERR           = 8'h03               ;
localparam              [ 7:0]              STATUS_TIMEOUT           = 8'h04               ;
localparam              [31:0]              CHIP_ID_ADDR             = 32'h1000_0000       ;
localparam              [31:0]              CHIP_VER_ADDR            = 32'h1000_0004       ;
localparam              [31:0]              ASU_PD_ADDR              = 32'h1000_0008       ;
localparam              [31:0]              CHIP_ID_VALUE            = 32'h4445_5443       ;
localparam              [31:0]              CHIP_VER_VALUE           = 32'h2026_0720       ;

wire                                        spi_sck_rise                                   ;
wire                                        spi_sck_fall                                   ;
wire                                        spi_cs_rise                                    ;
wire                                        spi_cs_fall                                    ;
wire                                        frame_start                                    ;
wire                                        spi_sample                                     ;
wire                                        spi_shift                                      ;
wire                                        cmd_end                                        ;
wire                                        query_end                                      ;
wire                                        result_consume                                 ;

wire                                        frame_exact                                    ;
wire                                        cmd_write                                      ;
wire                                        cmd_read                                       ;
wire                                        cmd_known                                      ;
wire                                        crc_match                                      ;
wire                                        addr_chip_id                                   ;
wire                                        addr_chip_ver                                  ;
wire                                        addr_asu_pd                                    ;
wire                                        addr_local                                     ;
wire                                        cmd_complete                                   ;
wire                                        cmd_length_err                                 ;
wire                                        cmd_crc_ok                                     ;
wire                                        cmd_crc_err                                    ;
wire                                        cmd_invalid                                    ;
wire                                        cmd_local_read                                 ;
wire                                        cmd_external                                   ;
wire                                        rxd_req_set                                    ;
wire                                        cmd_busy_read                                  ;
wire                                        cmd_busy_write                                 ;
wire                                        cmd_read_crc_err                               ;
wire                                        cmd_pd_w1c                                     ;
wire                                        read_context_set                               ;
wire                                        result_set                                     ;

wire                                        txd_handshake                                  ;
wire                    [15:0]              crc_value                                      ;
wire                                        pd_crc_set                                     ;
wire                                        pd_req_set                                     ;
wire                                        pd_timeout_set                                 ;
wire                                        pd_abort_set                                   ;
wire                    [31:0]              pd_value                                       ;
wire                    [31:0]              local_rdata                                    ;
wire                    [111:0]             query_wait_frame                               ;
wire                    [111:0]             result_frame                                   ;

reg                                         SPI_SCK_R                                      ;
reg                                         spi_sck                                        ;
reg                                         spi_sck_r                                      ;
reg                                         SPI_CS_R                                       ;
reg                                         spi_cs                                         ;
reg                                         spi_cs_r                                       ;
reg                                         SPI_MOSI_R                                     ;
reg                                         spi_mosi                                       ;
reg                                         cs_armed                                       ;

reg                                         frame_active                                   ;
reg                                         query_mode                                     ;
reg                     [ 8:0]              bit_cnt                                        ;
reg                     [127:0]             rx_shift                                       ;
reg                     [111:0]             query_frame                                    ;
reg                                         miso_data                                      ;

reg                                         crc_init                                       ;
reg                                         crc_valid                                      ;
reg                                         crc_data                                       ;

reg                                         read_pending                                   ;
reg                                         result_valid                                   ;
reg                     [15:0]              read_trans_id                                  ;
reg                     [31:0]              read_addr                                      ;
reg                     [ 7:0]              result_status                                  ;
reg                     [31:0]              result_rdata                                   ;

reg                     [ 4:1]              asu_pd                                         ;

//////////////////////////////////////////////////
//1. SPI Slave
//////////////////////////////////////////////////
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        SPI_SCK_R <= #UDLY 1'd0;
        spi_sck <= #UDLY 1'd0;
        spi_sck_r <= #UDLY 1'd0;
        SPI_CS_R <= #UDLY 1'd0;
        spi_cs <= #UDLY 1'd0;
        spi_cs_r <= #UDLY 1'd0;
        SPI_MOSI_R <= #UDLY 1'd0;
        spi_mosi <= #UDLY 1'd0;
    end
    else begin
        SPI_SCK_R <= #UDLY SPI_SCK;
        spi_sck <= #UDLY SPI_SCK_R;
        spi_sck_r <= #UDLY spi_sck;
        SPI_CS_R <= #UDLY SPI_CS;
        spi_cs <= #UDLY SPI_CS_R;
        spi_cs_r <= #UDLY spi_cs;
        SPI_MOSI_R <= #UDLY SPI_MOSI;
        spi_mosi <= #UDLY SPI_MOSI_R;
    end
end

assign spi_sck_rise = spi_sck & ~spi_sck_r;
assign spi_sck_fall = ~spi_sck & spi_sck_r;
assign spi_cs_rise  = spi_cs & ~spi_cs_r;
assign spi_cs_fall  = ~spi_cs & spi_cs_r;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        cs_armed <= #UDLY 1'd0;
    else if(spi_cs)
        cs_armed <= #UDLY 1'd1;
    else if(frame_start)
        cs_armed <= #UDLY 1'd0;
end

assign frame_start = spi_cs_fall & cs_armed;
assign spi_sample  = frame_active & ~spi_cs & spi_sck_rise;
assign spi_shift   = frame_active & ~spi_cs & spi_sck_fall;
assign cmd_end     = spi_cs_rise & frame_active & ~query_mode;
assign query_end   = spi_cs_rise & frame_active & query_mode;
assign SPI_MISO    = sys_rst_n & ~spi_cs & miso_data;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        frame_active <= #UDLY 1'd0;
        query_mode <= #UDLY 1'd0;
    end
    else if(frame_start) begin
        frame_active <= #UDLY 1'd1;
        query_mode <= #UDLY read_pending;
    end
    else if(spi_cs_rise) begin
        frame_active <= #UDLY 1'd0;
        query_mode <= #UDLY 1'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        bit_cnt <= #UDLY 9'd0;
    else if(frame_start)
        bit_cnt <= #UDLY 9'd0;
    else if(spi_sample & (bit_cnt < 9'd129))
        bit_cnt <= #UDLY bit_cnt + 9'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        rx_shift <= #UDLY 128'd0;
    else if(frame_start)
        rx_shift <= #UDLY 128'd0;
    else if(spi_sample & ~query_mode)
        rx_shift <= #UDLY {rx_shift[126:0], spi_mosi};
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        miso_data <= #UDLY 1'd0;
    else if(frame_start)
        miso_data <= #UDLY read_pending ? RSP_HEADER[15] : 1'd0;
    else if(spi_cs_rise)
        miso_data <= #UDLY 1'd0;
    else if(spi_shift & query_mode) begin
        if(bit_cnt < 9'd112)
            miso_data <= #UDLY query_frame[111-bit_cnt];
        else if(bit_cnt < 9'd128)
            miso_data <= #UDLY crc_value[127-bit_cnt];
        else
            miso_data <= #UDLY 1'd0;
    end
end

//////////////////////////////////////////////////
//2. Packet Decode / Encode And CRC
//////////////////////////////////////////////////
assign result_consume = query_end & (bit_cnt == 9'd128) &
                        ((query_frame[79:72] == STATUS_DONE) |
                         (query_frame[79:72] == STATUS_REQ_ERR) |
                         (query_frame[79:72] == STATUS_CRC_ERR) |
                         (query_frame[79:72] == STATUS_TIMEOUT));

assign frame_exact   = (bit_cnt == 9'd128);
assign cmd_write     = (rx_shift[127:112] == CMD_WRITE);
assign cmd_read      = (rx_shift[127:112] == CMD_READ);
assign cmd_known     = cmd_write | cmd_read;
assign crc_match     = (crc_value == rx_shift[15:0]);
assign addr_chip_id  = (rx_shift[95:64] == CHIP_ID_ADDR);
assign addr_chip_ver = (rx_shift[95:64] == CHIP_VER_ADDR);
assign addr_asu_pd   = (rx_shift[95:64] == ASU_PD_ADDR);
assign addr_local    = addr_chip_id | addr_chip_ver | addr_asu_pd;

assign cmd_complete     = cmd_end & frame_exact;
assign cmd_length_err   = cmd_end & ~frame_exact;
assign cmd_crc_ok       = cmd_complete & crc_match;
assign cmd_crc_err      = cmd_complete & ~crc_match;
assign cmd_invalid      = cmd_complete & ~cmd_known;
assign cmd_local_read   = cmd_crc_ok & cmd_read & addr_local;
assign cmd_external     = cmd_crc_ok & cmd_known & ~addr_local;
assign rxd_req_set      = cmd_external & ~rxd_req;
assign cmd_busy_read    = cmd_external & cmd_read & rxd_req;
assign cmd_busy_write   = cmd_external & cmd_write & rxd_req;
assign cmd_read_crc_err = cmd_crc_err & cmd_read;
assign cmd_pd_w1c       = cmd_crc_ok & cmd_write & addr_asu_pd;
assign read_context_set = cmd_local_read | cmd_busy_read |
                          (rxd_req_set & cmd_read);
assign result_set       = cmd_local_read | cmd_read_crc_err | cmd_busy_read;

assign local_rdata = addr_chip_id ? CHIP_ID_VALUE :
                     addr_chip_ver ? CHIP_VER_VALUE : pd_value;
assign query_wait_frame = {RSP_HEADER, read_trans_id, STATUS_WAIT, 8'd0,
                           read_addr, 32'd0};
assign result_frame = {RSP_HEADER, read_trans_id, result_status, 8'd0,
                       read_addr, result_rdata};

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        query_frame <= #UDLY 112'd0;
    else if(frame_start)
        query_frame <= #UDLY read_pending ? (result_valid ? result_frame : query_wait_frame) : 112'd0;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        crc_init <= #UDLY 1'd0;
        crc_valid <= #UDLY 1'd0;
        crc_data <= #UDLY 1'd0;
    end
    else begin
        crc_init <= #UDLY 1'd0;
        crc_valid <= #UDLY 1'd0;
        if(frame_start)
            crc_init <= #UDLY 1'd1;
        if(spi_sample & (bit_cnt < 9'd112)) begin
            crc_valid <= #UDLY 1'd1;
            crc_data <= #UDLY query_mode ? miso_data : spi_mosi;
        end
    end
end

ASU_CRC asu_crc(
    .sys_clk                             (sys_clk                                      ),
    .sys_rst_n                           (sys_rst_n                                    ),
    .crc_init                            (crc_init                                     ),
    .crc_valid                           (crc_valid                                    ),
    .crc_data                            (crc_data                                     ),
    .crc_value                           (crc_value                                    )
);

//////////////////////////////////////////////////
//3. Command Execution And TXD Handshake
//////////////////////////////////////////////////
assign txd_handshake = rxd_req & txd_rdy;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        rxd_req <= #UDLY 1'd0;
        rxd_write <= #UDLY 1'd0;
        rxd_addr <= #UDLY 32'd0;
        rxd_wdata <= #UDLY 32'd0;
    end
    else if(txd_handshake)
        rxd_req <= #UDLY 1'd0;
    else if(rxd_req_set) begin
        rxd_req <= #UDLY 1'd1;
        rxd_write <= #UDLY cmd_write;
        rxd_addr <= #UDLY rx_shift[95:64];
        rxd_wdata <= #UDLY cmd_write ? rx_shift[63:32] : 32'd0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        read_pending <= #UDLY 1'd0;
        result_valid <= #UDLY 1'd0;
    end
    else if(result_consume) begin
        read_pending <= #UDLY 1'd0;
        result_valid <= #UDLY 1'd0;
    end
    else if(result_set) begin
        read_pending <= #UDLY 1'd1;
        result_valid <= #UDLY 1'd1;
    end
    else if(rxd_req_set & cmd_read) begin
        read_pending <= #UDLY 1'd1;
        result_valid <= #UDLY 1'd0;
    end
    else if(txd_handshake & ~rxd_write)
        result_valid <= #UDLY 1'd1;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        read_trans_id <= #UDLY 16'd0;
        read_addr <= #UDLY 32'd0;
    end
    else if(result_consume) begin
        read_trans_id <= #UDLY 16'd0;
        read_addr <= #UDLY 32'd0;
    end
    else if(cmd_read_crc_err) begin
        read_trans_id <= #UDLY 16'd0;
        read_addr <= #UDLY 32'd0;
    end
    else if(read_context_set) begin
        read_trans_id <= #UDLY rx_shift[111:96];
        read_addr <= #UDLY rx_shift[95:64];
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        result_status <= #UDLY STATUS_DONE;
        result_rdata <= #UDLY 32'd0;
    end
    else if(result_consume) begin
        result_status <= #UDLY STATUS_DONE;
        result_rdata <= #UDLY 32'd0;
    end
    else if(cmd_local_read) begin
        result_status <= #UDLY STATUS_DONE;
        result_rdata <= #UDLY local_rdata;
    end
    else if(cmd_read_crc_err) begin
        result_status <= #UDLY STATUS_CRC_ERR;
        result_rdata <= #UDLY 32'd0;
    end
    else if(cmd_busy_read) begin
        result_status <= #UDLY STATUS_REQ_ERR;
        result_rdata <= #UDLY 32'd0;
    end
    else if(rxd_req_set & cmd_read) begin
        result_status <= #UDLY STATUS_DONE;
        result_rdata <= #UDLY 32'd0;
    end
    else if(txd_handshake & ~rxd_write) begin
        result_status <= #UDLY txd_timeout ? STATUS_TIMEOUT : STATUS_DONE;
        result_rdata <= #UDLY txd_timeout ? 32'd0 : txd_rdata;
    end
end

assign pd_crc_set     = cmd_crc_err;
assign pd_req_set     = cmd_length_err | cmd_invalid;
assign pd_timeout_set = txd_handshake & txd_timeout;
assign pd_abort_set   = pd_crc_set | pd_req_set | pd_timeout_set | cmd_busy_write;
assign pd_value = {27'd0, asu_pd, (rxd_req | read_pending)};

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n)
        asu_pd <= #UDLY 4'd0;
    else begin
        if(cmd_pd_w1c & rx_shift[33])
            asu_pd[1] <= #UDLY 1'd0;
        if(cmd_pd_w1c & rx_shift[34])
            asu_pd[2] <= #UDLY 1'd0;
        if(cmd_pd_w1c & rx_shift[35])
            asu_pd[3] <= #UDLY 1'd0;
        if(cmd_pd_w1c & rx_shift[36])
            asu_pd[4] <= #UDLY 1'd0;
        if(pd_crc_set)
            asu_pd[1] <= #UDLY 1'd1;
        if(pd_req_set)
            asu_pd[2] <= #UDLY 1'd1;
        if(pd_timeout_set)
            asu_pd[3] <= #UDLY 1'd1;
        if(pd_abort_set)
            asu_pd[4] <= #UDLY 1'd1;
    end
end

endmodule
