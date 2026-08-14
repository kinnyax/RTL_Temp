initial begin : p001_adc_link
    reg [31:0]  adc_sta;
    reg [511:0] axis_header;
    reg [511:0] axis_payload;
    reg          axis_last;
    reg [511:0] expected_payload;
    integer      channel_index;
    integer      poll_count;

    expected_payload = 512'd0;
    for(channel_index=0; channel_index<32; channel_index=channel_index+1) begin
        afe0_model.set_i_sample(channel_index, channel_index + 1);
        afe0_model.set_q_sample(channel_index, 16'h0100 + channel_index);
        expected_payload[channel_index*16 +: 16] = channel_index + 1;
    end

    wait(sys_rst_n === 1'b1 && adc_rst_n === 1'b1 &&
         afe_rst_n === 1'b1 && jesd_rst_n[0] === 1'b1);
    repeat(20) @(posedge sys_clk);

    afe0_model.configure_stream(0, 0, 0);

    afe_model_en[0] = 1'b1;
    axi_master.write_word(16'h0000, 32'h0000_0001);

    wait(afe_rx_reset_done[0] && afe_pll_lock[0] &&
         (afe_byte_aligned[0] == 2'b11));
    repeat(80) @(posedge jesd_clk[0]);
    pulse_sysref();

    adc_sta = 32'd0;
    poll_count = 0;
    while(!adc_sta[0] && poll_count < 2000) begin
        axi_master.read(16'h000c, adc_sta);
        repeat(4) @(posedge sys_clk);
        poll_count = poll_count + 1;
    end
    if(!adc_sta[0]) begin
        $display("[P001][ERROR] AFE0 LINK_READY timeout ADC_STA=%08h phase=%0d",
                 adc_sta, afe_model_phase[0]);
        fail();
    end

    wait_afe0_axis_beat(axis_header, axis_last);
    if(axis_last) begin
        $display("[P001][ERROR] header unexpectedly asserted TLAST");
        fail();
    end

    wait_afe0_axis_beat(axis_payload, axis_last);
    if(axis_payload !== expected_payload) begin
        $display("[P001][ERROR] payload mismatch\nexpected=%h\nactual  =%h",
                 expected_payload, axis_payload);
        fail();
    end

    $display("[P001][PASS] ADC_TOP AFE0 CGS/ILAS/DATA and first payload passed");
    pass();
end
