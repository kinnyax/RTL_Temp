`timescale 1ns / 1ps

module DMA_CHN #(
    parameter integer                       UDLY                        = 1
)(
    input  wire                             clk                                         ,
    input  wire                             rst_n                                       ,
    input  wire                             ch_en                                       ,
    input  wire [31:0]                      cfg_addr                                    ,
    input  wire [31:0]                      cfg_num                                     ,
    input  wire                             cfg_loop                                    ,
    input  wire                             cfg_wrap                                    ,
    input  wire [1:0]                       cfg_burst_len                               ,
    input  wire [2:0]                       cfg_data_width                              ,
    input  wire [9:0]                       fifo_data_count                             ,
    input  wire [511:0]                     fifo_tdata                                  ,
    input  wire [63:0]                      fifo_tkeep                                  ,
    input  wire                             fifo_tlast                                  ,
    input  wire                             fifo_tvalid                                 ,
    output reg                              fifo_tready                                 ,
    output wire [31:0]                      M_AXI_AWADDR                               ,
    output wire [7:0]                       M_AXI_AWLEN                                ,
    output wire [2:0]                       M_AXI_AWSIZE                               ,
    output wire [1:0]                       M_AXI_AWBURST                              ,
    output wire                             M_AXI_AWLOCK                               ,
    output wire [3:0]                       M_AXI_AWCACHE                              ,
    output wire [2:0]                       M_AXI_AWPROT                               ,
    output wire [3:0]                       M_AXI_AWQOS                                ,
    output wire [3:0]                       M_AXI_AWREGION                             ,
    output reg                              M_AXI_AWVALID                              ,
    input  wire                             M_AXI_AWREADY                              ,
    output wire [511:0]                     M_AXI_WDATA                                ,
    output wire [63:0]                      M_AXI_WSTRB                                ,
    output wire                             M_AXI_WLAST                                ,
    output reg                              M_AXI_WVALID                               ,
    input  wire                             M_AXI_WREADY                               ,
    input  wire [1:0]                       M_AXI_BRESP                                ,
    input  wire                             M_AXI_BVALID                               ,
    output reg                              M_AXI_BREADY                               ,
    output reg                              half_event                                  ,
    output reg                              full_event                                  ,
    output reg                              error_event                                 ,
    output reg                              stop_event                                  ,
    output wire                             ch_busy                                     ,
    output wire                             axi_busy
);

localparam [2:0]                         CH_IDLE                     = 3'd0               ;
localparam [2:0]                         CH_WAIT_DATA                = 3'd1               ;
localparam [2:0]                         CH_AW                       = 3'd2               ;
localparam [2:0]                         CH_W                        = 3'd3               ;
localparam [2:0]                         CH_B                        = 3'd4               ;

reg  [2:0]                               ch_state                                       ;
reg  [2:0]                               ch_state_nx                                    ;
reg                                      halt_latched                                   ;
reg  [31:0]                              current_addr                                   ;
reg  [31:0]                              committed_count                                ;
reg                                      half_seen                                     ;
reg  [6:0]                               burst_beats                                    ;
reg  [6:0]                               beat_index                                     ;
reg  [6:0]                               configured_burst                               ;
reg  [6:0]                               address_step                                   ;
reg  [2:0]                               axi_size                                       ;
reg  [511:0]                             source_data                                    ;
reg  [63:0]                              source_keep                                    ;

wire [31:0]                              remaining_beats                                ;
wire [6:0]                               burst_target                                   ;
wire [31:0]                              committed_after                               ;
wire [31:0]                              half_threshold                                ;
wire                                     burst_data_ready                              ;
wire                                     aw_accept                                      ;
wire                                     w_accept                                       ;
wire                                     b_accept                                       ;
wire                                     b_error                                        ;
wire                                     round_done                                     ;
wire                                     half_reached                                   ;

assign remaining_beats = cfg_num - committed_count;
assign burst_target    = (remaining_beats < {25'd0, configured_burst})
                       ? remaining_beats[6:0]
                       : configured_burst;
assign committed_after = committed_count + {25'd0, burst_beats};
assign half_threshold  = cfg_num >> 1;
assign burst_data_ready = (burst_target != 7'd0)
                        & (fifo_data_count >= {3'd0, burst_target});

assign aw_accept       = M_AXI_AWVALID & M_AXI_AWREADY;
assign w_accept        = M_AXI_WVALID  & M_AXI_WREADY;
assign b_accept        = M_AXI_BVALID  & M_AXI_BREADY;
assign b_error         = M_AXI_BRESP[1];
assign round_done      = committed_after >= cfg_num;
assign half_reached    = ~half_seen
                       & (committed_after >= half_threshold);

assign M_AXI_AWADDR    = current_addr;
assign M_AXI_AWLEN     = {1'b0, (burst_beats - 7'd1)};
assign M_AXI_AWSIZE    = axi_size;
assign M_AXI_AWBURST   = 2'b01;
assign M_AXI_AWLOCK    = 1'b0;
assign M_AXI_AWCACHE   = 4'b0011;
assign M_AXI_AWPROT    = 3'b000;
assign M_AXI_AWQOS     = 4'b0000;
assign M_AXI_AWREGION  = 4'b0000;
assign M_AXI_WDATA     = source_data << {current_addr[5:0], 3'b000};
assign M_AXI_WSTRB     = source_keep << current_addr[5:0];
assign M_AXI_WLAST     = (ch_state == CH_W)
                       & (beat_index == (burst_beats - 7'd1));
assign ch_busy         = (ch_state != CH_IDLE)
                       | (ch_en & ~halt_latched & (cfg_num != 32'd0));
assign axi_busy        = (ch_state == CH_AW)
                       | (ch_state == CH_W)
                       | (ch_state == CH_B);

//////////////////////////////////////////////////
//1. Transaction Shape and Narrow-Write Encoding
//////////////////////////////////////////////////

always @(*) begin
    case(cfg_burst_len)
        2'b00:   configured_burst = 7'd1;
        2'b01:   configured_burst = 7'd16;
        2'b10:   configured_burst = 7'd32;
        2'b11:   configured_burst = 7'd64;
        default: configured_burst = 7'd1;
    endcase
end

always @(*) begin
    address_step = 7'd1;
    axi_size     = 3'd0;
    source_data  = 512'd0;
    source_keep  = 64'd0;
    case(cfg_data_width)
        3'b000: begin
            address_step       = 7'd1;
            axi_size           = 3'd0;
            source_data[7:0]   = fifo_tdata[7:0];
            source_keep[0]     = fifo_tkeep[0];
        end
        3'b001: begin
            address_step       = 7'd2;
            axi_size           = 3'd1;
            source_data[15:0]  = fifo_tdata[15:0];
            source_keep[1:0]   = fifo_tkeep[1:0];
        end
        3'b010: begin
            address_step       = 7'd4;
            axi_size           = 3'd2;
            source_data[23:0]  = fifo_tdata[23:0];
            source_keep[2:0]   = fifo_tkeep[2:0];
        end
        3'b011: begin
            address_step       = 7'd4;
            axi_size           = 3'd2;
            source_data[31:0]  = fifo_tdata[31:0];
            source_keep[3:0]   = fifo_tkeep[3:0];
        end
        3'b100: begin
            address_step       = 7'd8;
            axi_size           = 3'd3;
            source_data[63:0]  = fifo_tdata[63:0];
            source_keep[7:0]   = fifo_tkeep[7:0];
        end
        3'b101: begin
            address_step       = 7'd16;
            axi_size           = 3'd4;
            source_data[127:0] = fifo_tdata[127:0];
            source_keep[15:0]  = fifo_tkeep[15:0];
        end
        3'b110: begin
            address_step       = 7'd32;
            axi_size           = 3'd5;
            source_data[255:0] = fifo_tdata[255:0];
            source_keep[31:0]  = fifo_tkeep[31:0];
        end
        3'b111: begin
            address_step       = 7'd64;
            axi_size           = 3'd6;
            source_data        = fifo_tdata;
            source_keep        = fifo_tkeep;
        end
        default: begin
            address_step       = 7'd1;
            axi_size           = 3'd0;
            source_data[7:0]   = fifo_tdata[7:0];
            source_keep[0]     = fifo_tkeep[0];
        end
    endcase
end

//////////////////////////////////////////////////
//2. Three-Process Channel FSM
//////////////////////////////////////////////////

// State register.
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        ch_state <= #UDLY CH_IDLE;
    else
        ch_state <= #UDLY ch_state_nx;
end

// Next-state logic changes only the FSM state.
always @(*) begin
    ch_state_nx = ch_state;
    case(ch_state)
        CH_IDLE: begin
            if(ch_en & ~halt_latched & (cfg_num != 32'd0))
                ch_state_nx = CH_WAIT_DATA;
        end
        CH_WAIT_DATA: begin
            if(!ch_en)
                ch_state_nx = CH_IDLE;
            else if(burst_data_ready)
                ch_state_nx = CH_AW;
        end
        CH_AW: begin
            if(aw_accept)
                ch_state_nx = CH_W;
        end
        CH_W: begin
            if(w_accept & M_AXI_WLAST)
                ch_state_nx = CH_B;
        end
        CH_B: begin
            if(b_accept) begin
                if(b_error | !ch_en)
                    ch_state_nx = CH_IDLE;
                else if(round_done & ~cfg_loop)
                    ch_state_nx = CH_IDLE;
                else
                    ch_state_nx = CH_WAIT_DATA;
            end
        end
        default: begin
            ch_state_nx = CH_IDLE;
        end
    endcase
end

// State-derived protocol controls. Valid never depends on the matching Ready.
always @(*) begin
    M_AXI_AWVALID = 1'b0;
    M_AXI_WVALID  = 1'b0;
    M_AXI_BREADY  = 1'b0;
    fifo_tready   = 1'b0;
    case(ch_state)
        CH_AW: begin
            M_AXI_AWVALID = 1'b1;
        end
        CH_W: begin
            M_AXI_WVALID = fifo_tvalid;
            fifo_tready  = M_AXI_WREADY;
        end
        CH_B: begin
            M_AXI_BREADY = 1'b1;
        end
        default: begin
            M_AXI_AWVALID = 1'b0;
            M_AXI_WVALID  = 1'b0;
            M_AXI_BREADY  = 1'b0;
            fifo_tready   = 1'b0;
        end
    endcase
end

//////////////////////////////////////////////////
//3. Runtime Datapath and Events
//////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        burst_beats <= #UDLY 7'd1;
        beat_index  <= #UDLY 7'd0;
    end
    else begin
        if((ch_state == CH_WAIT_DATA) & burst_data_ready) begin
            burst_beats <= #UDLY burst_target;
            beat_index  <= #UDLY 7'd0;
        end
        else if((ch_state == CH_W) & w_accept & ~M_AXI_WLAST) begin
            beat_index <= #UDLY beat_index + 7'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_addr    <= #UDLY 32'd0;
        committed_count <= #UDLY 32'd0;
        half_seen       <= #UDLY 1'b0;
    end
    else if(ch_state == CH_IDLE) begin
        current_addr    <= #UDLY cfg_addr;
        committed_count <= #UDLY 32'd0;
        half_seen       <= #UDLY 1'b0;
    end
    else if((ch_state == CH_WAIT_DATA) & !ch_en) begin
        current_addr    <= #UDLY cfg_addr;
        committed_count <= #UDLY 32'd0;
        half_seen       <= #UDLY 1'b0;
    end
    else begin
        if((ch_state == CH_W) & w_accept)
            current_addr <= #UDLY current_addr + {25'd0, address_step};
        if((ch_state == CH_B) & b_accept) begin
            if(b_error | !ch_en) begin
                current_addr    <= #UDLY cfg_addr;
                committed_count <= #UDLY 32'd0;
                half_seen       <= #UDLY 1'b0;
            end
            else if(round_done) begin
                if(cfg_wrap)
                    current_addr <= #UDLY cfg_addr;
                committed_count <= #UDLY 32'd0;
                half_seen       <= #UDLY 1'b0;
            end
            else begin
                committed_count <= #UDLY committed_after;
                if(half_reached)
                    half_seen <= #UDLY 1'b1;
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        halt_latched <= #UDLY 1'b0;
    else if(!ch_en)
        halt_latched <= #UDLY 1'b0;
    else if((ch_state == CH_IDLE) & (cfg_num == 32'd0))
        halt_latched <= #UDLY 1'b1;
    else if((ch_state == CH_B) & b_accept
          & (b_error | (round_done & ~cfg_loop)))
        halt_latched <= #UDLY 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        half_event  <= #UDLY 1'b0;
        full_event  <= #UDLY 1'b0;
        error_event <= #UDLY 1'b0;
        stop_event  <= #UDLY 1'b0;
    end
    else begin
        half_event  <= #UDLY 1'b0;
        full_event  <= #UDLY 1'b0;
        error_event <= #UDLY 1'b0;
        stop_event  <= #UDLY 1'b0;
        if((ch_state == CH_IDLE) & ch_en & ~halt_latched
         & (cfg_num == 32'd0)) begin
            stop_event <= #UDLY 1'b1;
        end
        else if((ch_state == CH_B) & b_accept) begin
            if(b_error) begin
                error_event <= #UDLY 1'b1;
                stop_event  <= #UDLY 1'b1;
            end
            else begin
                if(half_reached)
                    half_event <= #UDLY 1'b1;
                if(round_done) begin
                    full_event <= #UDLY 1'b1;
                    if(~cfg_loop)
                        stop_event <= #UDLY 1'b1;
                end
            end
        end
    end
end

// fifo_tlast is intentionally transported through the AXIS FIFO but does not
// affect CHn_NUM-based transaction boundaries.

endmodule
