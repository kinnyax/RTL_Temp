`timescale 1ns / 1ps
`default_nettype none

// SPI framing, transaction ownership, shared CRC sequencing, and response hold.
module ASU_FRT
(
    input  wire                             SYS_CLK                                     ,
    input  wire                             SYS_RST_N                                   ,
    input  wire                             ASU_SPI_CS_N                                ,
    input  wire                             ASU_SPI_SCK                                 ,
    input  wire                             ASU_SPI_MOSI                                ,
    output wire                             ASU_SPI_MISO                                ,
    output reg                              FRT_REQ_VLD                                 ,
    output reg  [127:0]                     FRT_REQ_FRAME                               ,
    input  wire                             CTL_REQ_RDY                                 ,
    input  wire                             CTL_RSP_VLD                                 ,
    input  wire                             CTL_REQ_ERR                                 ,
    input  wire [1:0]                       CTL_AXI_RESP                                ,
    input  wire [31:0]                      CTL_RDATA                                   ,
    output wire                             FRT_RSP_RDY                                 ,
    output reg                              FRT_RSP_CONSUMED                            ,
    output wire                             CRC_START                                   ,
    output wire [111:0]                     CRC_DATA                                    ,
    input  wire                             CRC_BUSY                                    ,
    input  wire                             CRC_DONE                                    ,
    input  wire [15:0]                      CRC_VALUE
);

parameter integer                           UDLY                        = 1              ;

localparam [15:0]                           RSP_MAGIC                   = 16'h5AA5                                  ;
localparam [7:0]                            STATUS_AXI_DONE             = 8'h00                                     ;
localparam [7:0]                            STATUS_AXI_WAIT             = 8'h01                                     ;
localparam [7:0]                            STATUS_REQ_ERROR            = 8'h02                                     ;
localparam [7:0]                            STATUS_AXI_ERROR            = 8'h04                                     ;
localparam [127:0]                          REQ_ERROR_FRAME             = 128'h5AA5_0000_0200_00000000_00000000_5F07;
localparam [127:0]                          CRC_ERROR_FRAME             = 128'h5AA5_0000_0300_00000000_00000000_3042;
localparam [1:0]                            CRC_REQ                     = 2'd0                                      ;
localparam [1:0]                            CRC_WAIT                    = 2'd1                                      ;
localparam [1:0]                            CRC_FINAL                   = 2'd2                                      ;

wire [2:0]                                  spi_bus                                      ;
wire [2:0]                                  spi_bus_sync                                 ;
wire                                        sck_rise                                     ;
wire                                        sck_fall                                     ;
wire                                        nss_rise                                     ;
wire                                        nss_fall                                     ;
wire                                        crc_req_launch                               ;
wire                                        crc_wait_launch                              ;
wire                                        crc_resp_launch                              ;
wire                                        frame_start                                  ;
wire                                        spi_sample                                   ;
wire                                        spi_shift_tx                                 ;
wire                                        cmd_end                                      ;
wire                                        query_end                                    ;
wire                                        resp_consumed                                ;
wire                                        req_hs                                       ;
wire                                        resp_hs                                      ;
wire                                        req_crc_ok                                   ;
wire                                        req_crc_err                                  ;
wire                                        wait_crc_done                                ;
wire                                        resp_crc_done                                ;
wire [111:0]                                wait_crc_data                                ;
wire [111:0]                                resp_crc_data                                ;
wire [7:0]                                  axi_status                                   ;

reg  [1:0]                                  spi_bus_sync_r                               ;
reg                                         cs_armed                                     ;
reg                                         frame_active                                 ;
reg                                         query_frame                                  ;
reg                                         query_final                                  ;
reg  [8:0]                                  bit_cnt                                      ;
reg  [127:0]                                rx_shift                                     ;
reg  [127:0]                                tx_shift                                     ;
reg                                         txn_pd                                       ;
reg                                         req_crc_pd                                   ;
reg                                         wait_crc_pd                                  ;
reg                                         resp_crc_pd                                  ;
reg                                         ctl_req_pd                                   ;
reg                                         req_err                                      ;
reg  [1:0]                                  axi_resp                                     ;
reg  [31:0]                                 resp_rdata                                   ;
reg  [127:0]                                wait_resp_frame                              ;
reg  [127:0]                                resp_frame                                   ;
reg                                         resp_valid                                   ;
reg  [1:0]                                  crc_sel                                      ;

// The packed bus is only a code-reuse vehicle; ASU_LEVELS_SYNC still implements
// three independent two-flop synchronizer chains.
assign spi_bus = {ASU_SPI_CS_N, ASU_SPI_SCK, ASU_SPI_MOSI};

ASU_LEVELS_SYNC spi_bus_levels_sync
(
    .clk                                  (SYS_CLK                                      ),
    .rst_n                                (SYS_RST_N                                    ),
    .in                                   (spi_bus                                      ),
    .out                                  (spi_bus_sync                                 )
);

// Only NSS and SCK need history.  Reset-low observation prevents a CS held
// low across reset from manufacturing a falling edge before a real high.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        spi_bus_sync_r <= #UDLY 2'd0;
    else
        spi_bus_sync_r <= #UDLY {spi_bus_sync[2], spi_bus_sync[1]};
end

assign nss_rise = spi_bus_sync[2] & ~spi_bus_sync_r[1];
assign nss_fall = ~spi_bus_sync[2] & spi_bus_sync_r[1];
assign sck_rise = spi_bus_sync[1] & ~spi_bus_sync_r[0];
assign sck_fall = ~spi_bus_sync[1] & spi_bus_sync_r[0];

assign frame_start          = nss_fall & cs_armed;
assign spi_sample           = frame_active & ~spi_bus_sync[2] & sck_rise;
assign spi_shift_tx         = frame_active & ~spi_bus_sync[2] & sck_fall;
assign cmd_end              = nss_rise & frame_active & ~query_frame;
assign query_end            = nss_rise & frame_active & query_frame;
assign resp_consumed        = query_end & query_final & (bit_cnt >= 9'd128);

assign ASU_SPI_MISO = (~spi_bus_sync[2] & frame_active) ?
                      tx_shift[127] : 1'b0;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        cs_armed <= #UDLY 1'b0;
    else if(spi_bus_sync[2])
        cs_armed <= #UDLY 1'b1;
    else if(nss_fall)
        cs_armed <= #UDLY 1'b0;
end

// Localized frame reset equivalent to SYS_RST_N & ~spi_bus_sync[2]: the synchronized
// NSS high level clears only current-frame metadata on the next SYS_CLK.  It
// never reaches txn_pd, request/response caches, or CRC-control registers.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        frame_active <= #UDLY 1'b0;
        query_frame <= #UDLY 1'b0;
        query_final <= #UDLY 1'b0;
    end else if(spi_bus_sync[2]) begin
        frame_active <= #UDLY 1'b0;
        query_frame <= #UDLY 1'b0;
        query_final <= #UDLY 1'b0;
    end else if(frame_start) begin
        frame_active <= #UDLY 1'b1;
        query_frame <= #UDLY txn_pd;
        query_final <= #UDLY resp_valid;
    end
end

// These two shift registers are also in the deliberately localized frame
// reset scope.  Transaction state is held in separate SYS_RST_N-only blocks.
always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        rx_shift <= #UDLY 128'd0;
        tx_shift <= #UDLY 128'd0;
    end else if(spi_bus_sync[2]) begin
        rx_shift <= #UDLY 128'd0;
        tx_shift <= #UDLY 128'd0;
    end else if(frame_start) begin
        rx_shift <= #UDLY 128'd0;
        if(txn_pd)
            tx_shift <= #UDLY resp_valid ? resp_frame : wait_resp_frame;
        else
            tx_shift <= #UDLY 128'd0;
    end else begin
        if(spi_sample)
            rx_shift <= #UDLY {rx_shift[126:0], spi_bus_sync[0]};
        if(spi_shift_tx)
            tx_shift <= #UDLY {tx_shift[126:0], 1'b0};
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        bit_cnt <= #UDLY 9'd0;
    else if(spi_bus_sync[2])
        bit_cnt <= #UDLY 9'd0;
    else if(frame_start)
        bit_cnt <= #UDLY 9'd0;
    else if(spi_sample & (bit_cnt != 9'h1FF))
        bit_cnt <= #UDLY bit_cnt + 9'd1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        txn_pd <= #UDLY 1'b0;
    else if(resp_consumed)
        txn_pd <= #UDLY 1'b0;
    else if(cmd_end)
        txn_pd <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        FRT_REQ_FRAME <= #UDLY 128'd0;
    else if(resp_consumed)
        FRT_REQ_FRAME <= #UDLY 128'd0;
    else if(cmd_end & (bit_cnt == 9'd128))
        FRT_REQ_FRAME <= #UDLY rx_shift;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        req_crc_pd <= #UDLY 1'b0;
    else if(resp_consumed)
        req_crc_pd <= #UDLY 1'b0;
    else if(CRC_START & crc_req_launch)
        req_crc_pd <= #UDLY 1'b0;
    else if(cmd_end & (bit_cnt == 9'd128))
        req_crc_pd <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        wait_crc_pd <= #UDLY 1'b0;
    else if(resp_consumed)
        wait_crc_pd <= #UDLY 1'b0;
    else if(CRC_START & crc_wait_launch)
        wait_crc_pd <= #UDLY 1'b0;
    else if(req_crc_ok)
        wait_crc_pd <= #UDLY 1'b1;
end

assign req_hs = FRT_REQ_VLD & CTL_REQ_RDY;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        FRT_REQ_VLD <= #UDLY 1'b0;
    else if(resp_consumed)
        FRT_REQ_VLD <= #UDLY 1'b0;
    else if(req_hs)
        FRT_REQ_VLD <= #UDLY 1'b0;
    else if(req_crc_ok)
        FRT_REQ_VLD <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        ctl_req_pd <= #UDLY 1'b0;
    else if(resp_consumed)
        ctl_req_pd <= #UDLY 1'b0;
    else if(req_hs)
        ctl_req_pd <= #UDLY 1'b1;
end

assign FRT_RSP_RDY = ctl_req_pd & ~resp_crc_pd & ~resp_valid;
assign resp_hs = CTL_RSP_VLD & FRT_RSP_RDY;

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N) begin
        req_err <= #UDLY 1'b0;
        axi_resp <= #UDLY 2'd0;
        resp_rdata <= #UDLY 32'd0;
    end else if(resp_consumed) begin
        req_err <= #UDLY 1'b0;
        axi_resp <= #UDLY 2'd0;
        resp_rdata <= #UDLY 32'd0;
    end else if(resp_hs) begin
        req_err <= #UDLY CTL_REQ_ERR;
        axi_resp <= #UDLY CTL_AXI_RESP;
        resp_rdata <= #UDLY CTL_RDATA;
    end
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        resp_crc_pd <= #UDLY 1'b0;
    else if(resp_consumed)
        resp_crc_pd <= #UDLY 1'b0;
    else if(CRC_START & crc_resp_launch)
        resp_crc_pd <= #UDLY 1'b0;
    else if(resp_hs)
        resp_crc_pd <= #UDLY 1'b1;
end

assign wait_crc_data = {
    RSP_MAGIC,
    FRT_REQ_FRAME[111:96],
    STATUS_AXI_WAIT,
    8'd0,
    FRT_REQ_FRAME[95:64],
    32'd0
};

assign resp_crc_data = {
    RSP_MAGIC,
    FRT_REQ_FRAME[111:96],
    axi_status,
    {6'b000000, axi_resp},
    FRT_REQ_FRAME[95:64],
    resp_rdata
};

assign axi_status = req_err ? STATUS_REQ_ERROR :
                    (|axi_resp) ? STATUS_AXI_ERROR : STATUS_AXI_DONE;

// Pending flags are the queue; crc_sel only records the purpose of the active
// mathematical calculation.  There is intentionally no CRC protocol FSM.
assign crc_req_launch = req_crc_pd;
assign crc_wait_launch = ~req_crc_pd & (wait_crc_pd | req_crc_ok);
assign crc_resp_launch = ~req_crc_pd & ~(wait_crc_pd | req_crc_ok) & resp_crc_pd;
assign CRC_START = ~CRC_BUSY &
                   (crc_req_launch | crc_wait_launch | crc_resp_launch);

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        crc_sel <= #UDLY CRC_REQ;
    else if(CRC_START) begin
        if(crc_req_launch)
            crc_sel <= #UDLY CRC_REQ;
        else if(crc_wait_launch)
            crc_sel <= #UDLY CRC_WAIT;
        else
            crc_sel <= #UDLY CRC_FINAL;
    end
end

// At launch CRC_DATA follows the pending-source priority.  While busy it uses
// the locked crc_sel, so all 112 bits remain stable for the full calculation.
assign CRC_DATA = CRC_BUSY ?
                  ((crc_sel == CRC_REQ) ? FRT_REQ_FRAME[127:16] :
                   ((crc_sel == CRC_WAIT) ? wait_crc_data : resp_crc_data)) :
                  (crc_req_launch ? FRT_REQ_FRAME[127:16] :
                   (crc_wait_launch ? wait_crc_data : resp_crc_data));

assign req_crc_ok = CRC_DONE & (crc_sel == CRC_REQ) &
                    (CRC_VALUE == FRT_REQ_FRAME[15:0]);
assign req_crc_err = CRC_DONE & (crc_sel == CRC_REQ) &
                     (CRC_VALUE != FRT_REQ_FRAME[15:0]);
assign wait_crc_done = CRC_DONE & (crc_sel == CRC_WAIT);
assign resp_crc_done = CRC_DONE & (crc_sel == CRC_FINAL);

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        wait_resp_frame <= #UDLY 128'd0;
    else if(resp_consumed)
        wait_resp_frame <= #UDLY 128'd0;
    else if(wait_crc_done)
        wait_resp_frame <= #UDLY {wait_crc_data, CRC_VALUE};
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        resp_frame <= #UDLY 128'd0;
    else if(resp_consumed)
        resp_frame <= #UDLY 128'd0;
    else if(cmd_end & (bit_cnt != 9'd128))
        resp_frame <= #UDLY REQ_ERROR_FRAME;
    else if(req_crc_err)
        resp_frame <= #UDLY CRC_ERROR_FRAME;
    else if(resp_crc_done)
        resp_frame <= #UDLY {resp_crc_data, CRC_VALUE};
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        resp_valid <= #UDLY 1'b0;
    else if(resp_consumed)
        resp_valid <= #UDLY 1'b0;
    else if(cmd_end & (bit_cnt != 9'd128))
        resp_valid <= #UDLY 1'b1;
    else if(req_crc_err)
        resp_valid <= #UDLY 1'b1;
    else if(resp_crc_done)
        resp_valid <= #UDLY 1'b1;
end

always @(posedge SYS_CLK or negedge SYS_RST_N) begin
    if(!SYS_RST_N)
        FRT_RSP_CONSUMED <= #UDLY 1'b0;
    else begin
        FRT_RSP_CONSUMED <= #UDLY 1'b0;
        if(resp_consumed & ctl_req_pd)
            FRT_RSP_CONSUMED <= #UDLY 1'b1;
    end
end

endmodule

`default_nettype wire
