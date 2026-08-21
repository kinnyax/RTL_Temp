"""Public-interface cocotb sanity suite for ADC_TOP.

The Vivado JESD204 PHY remains the external model boundary. Public ADC_TOP
scoreboards are primary. A small Layer-A/B directed subset observes only the
stable semantic hierarchy signals explicitly named by the v1.32 contract.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.handle import Force, Release
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer, ValueChange, with_timeout


TEST_TIMEOUT_US = 50


def _required(dut, name):
    handle = getattr(dut, name, None)
    assert handle is not None, f"ADC_TOP is missing required port {name}"
    return handle


def _drive(dut, name, value):
    _required(dut, name).value = value


def _assert_known(dut, name):
    value = _required(dut, name).value
    assert value.is_resolvable, f"{name} contains X/Z: {value}"


def _assert_fixed_eight_channel_interface(dut):
    """Check every literal PHY/AXIS/TGC port in the non-parameterized top."""
    expected_widths = {
        "rx_data": 64,
        "rx_charisk": 8,
        "rx_disperr": 8,
        "rx_notintable": 8,
        "rx_reset_done": 1,
        "pll_lock": 1,
        "byte_aligned": 2,
        "rx_encommalign": 1,
        "sync_n": 1,
    }
    for channel in range(8):
        for suffix, width in expected_widths.items():
            assert len(_required(dut, f"afe{channel}_{suffix}")) == width, (
                f"AFE{channel} {suffix} width changed from {width}")
        for suffix, width in (("tdata", 512), ("tkeep", 64), ("tvalid", 1),
                              ("tlast", 1), ("tready", 1)):
            assert len(_required(dut, f"m_axis_afe{channel}_{suffix}")) == width, (
                f"AFE{channel} AXIS {suffix} width changed from {width}")
        for suffix in ("slope", "up_dn", "prof1", "prof2"):
            assert len(_required(dut, f"tgc{channel}_{suffix}")) == 1
    for prefix in ("afe8_rx_data", "m_axis_afe8_tdata", "tgc8_slope"):
        assert getattr(dut, prefix, None) is None, f"fixed-eight interface grew an unexpected {prefix}"


async def _jesd_clock_bus(signal, period_ns=7):
    all_high = (1 << len(signal)) - 1
    while True:
        signal.value = 0
        await Timer(period_ns / 2, unit="ns")
        signal.value = all_high
        await Timer(period_ns / 2, unit="ns")


async def _controlled_adc_clock(signal, enable, period_ns=6):
    while True:
        signal.value = 0
        await Timer(period_ns / 2, unit="ns")
        signal.value = 1 if enable[0] else 0
        await Timer(period_ns / 2, unit="ns")


def _initialize_all_inputs(dut):
    scalar_defaults = {
        "sys_clk": 0,
        "adc_clk": 0,
        "afe_clk": 0,
        "jesd_clk": 0,
        "sys_rst_n": 0,
        "adc_rst_n": 0,
        "afe_rst_n": 0,
        "jesd_rst_n": 0,
        "sysref_in": 0,
        "s_axi_awaddr": 0,
        "s_axi_awvalid": 0,
        "s_axi_wdata": 0,
        "s_axi_wstrb": 0,
        "s_axi_wvalid": 0,
        "s_axi_bready": 0,
        "s_axi_araddr": 0,
        "s_axi_arvalid": 0,
        "s_axi_rready": 0,
    }
    for name, value in scalar_defaults.items():
        _drive(dut, name, value)

    for channel in range(8):
        phy_defaults = {
            f"afe{channel}_rx_data": 0,
            f"afe{channel}_rx_charisk": 0,
            f"afe{channel}_rx_disperr": 0,
            f"afe{channel}_rx_notintable": 0,
            f"afe{channel}_rx_reset_done": 0,
            f"afe{channel}_pll_lock": 0,
            f"afe{channel}_byte_aligned": 0,
            f"m_axis_afe{channel}_tready": 1,
        }
        for name, value in phy_defaults.items():
            _drive(dut, name, value)


def _start_all_clocks(dut):
    adc_enable = [True]
    cocotb.start_soon(Clock(dut.sys_clk, 10, unit="ns").start())
    cocotb.start_soon(_controlled_adc_clock(dut.adc_clk, adc_enable))
    # ADI RX aggregates four 4-octet JESD beats into each 16-octet device
    # beat, so AFE_CLK is exactly JESD_CLK/4 (40 MHz versus 160 MHz).
    cocotb.start_soon(Clock(dut.afe_clk, 28, unit="ns").start())
    cocotb.start_soon(_jesd_clock_bus(dut.jesd_clk))
    return adc_enable


async def _release_all_resets(dut):
    for _ in range(8):
        await RisingEdge(dut.sys_clk)
    dut.sys_rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.adc_clk)
    dut.adc_rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.afe_clk)
    dut.afe_rst_n.value = 1
    for _ in range(4):
        await RisingEdge(dut.sys_clk)
    dut.jesd_rst_n.value = 0xFF
    for _ in range(12):
        await RisingEdge(dut.sys_clk)


async def _setup(dut):
    _initialize_all_inputs(dut)
    adc_enable = _start_all_clocks(dut)
    await _release_all_resets(dut)
    return adc_enable


async def _axi_write(dut, address, data, strobe=0xF, split=False,
                     split_order="aw_then_w", b_hold_cycles=0):
    """AXI4-Lite write: drive on falling edge, sample only after ReadOnly."""
    assert 0 <= strobe <= 0xF
    async def _send_aw():
        await FallingEdge(dut.sys_clk)
        ready_before_rising = int(dut.s_axi_awready.value)
        dut.s_axi_awaddr.value = address
        dut.s_axi_awvalid.value = 1
        for _ in range(12):
            await RisingEdge(dut.sys_clk)
            await ReadOnly()
            await FallingEdge(dut.sys_clk)
            if ready_before_rising:
                dut.s_axi_awvalid.value = 0
                return
            ready_before_rising = int(dut.s_axi_awready.value)
        raise AssertionError("AXI AW channel timed out")

    async def _send_w():
        await FallingEdge(dut.sys_clk)
        ready_before_rising = int(dut.s_axi_wready.value)
        dut.s_axi_wdata.value = data
        dut.s_axi_wstrb.value = strobe
        dut.s_axi_wvalid.value = 1
        for _ in range(12):
            await RisingEdge(dut.sys_clk)
            await ReadOnly()
            await FallingEdge(dut.sys_clk)
            if ready_before_rising:
                dut.s_axi_wvalid.value = 0
                return
            ready_before_rising = int(dut.s_axi_wready.value)
        raise AssertionError("AXI W channel timed out")

    # Do not use concurrent coroutines: this helper remains the single owner
    # of AW/W/B signals.  Split mode deliberately separates the channels.
    await FallingEdge(dut.sys_clk)
    dut.s_axi_bready.value = 0
    if split:
        assert split_order in ("aw_then_w", "w_then_aw")
        if split_order == "aw_then_w":
            await _send_aw()
            await _send_w()
        else:
            await _send_w()
            await _send_aw()
    else:
        await FallingEdge(dut.sys_clk)
        aw_ready_before_rising = int(dut.s_axi_awready.value)
        w_ready_before_rising = int(dut.s_axi_wready.value)
        dut.s_axi_awaddr.value = address
        dut.s_axi_wdata.value = data
        dut.s_axi_wstrb.value = strobe
        dut.s_axi_awvalid.value = 1
        dut.s_axi_wvalid.value = 1
        aw_done = False
        w_done = False
        for _ in range(12):
            await RisingEdge(dut.sys_clk)
            await ReadOnly()
            aw_done = aw_done or bool(aw_ready_before_rising)
            w_done = w_done or bool(w_ready_before_rising)
            await FallingEdge(dut.sys_clk)
            if aw_done:
                dut.s_axi_awvalid.value = 0
            if w_done:
                dut.s_axi_wvalid.value = 0
            if aw_done and w_done:
                break
            aw_ready_before_rising = int(dut.s_axi_awready.value)
            w_ready_before_rising = int(dut.s_axi_wready.value)
        assert aw_done and w_done, "AXI write address/data channels timed out"

    for _ in range(12):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        if int(dut.s_axi_bvalid.value):
            break
        await FallingEdge(dut.sys_clk)
    assert int(dut.s_axi_bvalid.value) == 1, "AXI write response timed out"
    assert int(dut.s_axi_bresp.value) == 0, "AXI write response was not OKAY"
    held_bresp = int(dut.s_axi_bresp.value)
    for _ in range(b_hold_cycles):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        assert int(dut.s_axi_bvalid.value) == 1, "BVALID dropped under backpressure"
        assert int(dut.s_axi_bresp.value) == held_bresp, "BRESP changed under backpressure"
        assert int(dut.s_axi_awready.value) == 0, "AWREADY rose while B response pending"
        assert int(dut.s_axi_wready.value) == 0, "WREADY rose while B response pending"
    await FallingEdge(dut.sys_clk)
    dut.s_axi_bready.value = 1
    await RisingEdge(dut.sys_clk)
    await Timer(2, unit="ns")
    await ReadOnly()
    assert int(dut.s_axi_bvalid.value) == 0, "BVALID did not retire after handshake"
    await FallingEdge(dut.sys_clk)
    dut.s_axi_bready.value = 0


async def _axi_read(dut, address):
    """AXI4-Lite read with deterministic drive/sample phase separation."""
    await FallingEdge(dut.sys_clk)
    arready_before_rising = int(dut.s_axi_arready.value)
    dut.s_axi_rready.value = 0
    dut.s_axi_araddr.value = address
    dut.s_axi_arvalid.value = 1
    accepted = False
    rvalid = False
    for _ in range(12):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        accepted = accepted or bool(arready_before_rising)
        rvalid = bool(int(dut.s_axi_rvalid.value))
        await FallingEdge(dut.sys_clk)
        if accepted:
            dut.s_axi_arvalid.value = 0
            break
        arready_before_rising = int(dut.s_axi_arready.value)
    assert accepted, "AXI AR channel timed out"
    while not rvalid:
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        rvalid = bool(int(dut.s_axi_rvalid.value))
        if not rvalid:
            await FallingEdge(dut.sys_clk)
    assert int(dut.s_axi_rresp.value) == 0, "AXI read response was not OKAY"
    value = int(dut.s_axi_rdata.value)
    await FallingEdge(dut.sys_clk)
    dut.s_axi_rready.value = 1
    await RisingEdge(dut.sys_clk)
    await Timer(2, unit="ns")
    await ReadOnly()
    assert int(dut.s_axi_rvalid.value) == 0, "RVALID did not retire after handshake"
    await FallingEdge(dut.sys_clk)
    dut.s_axi_rready.value = 0
    return value


async def _axi_read_response_backpressure(dut, address, hold_cycles=5):
    """Exercise one AR transaction while the manager deliberately stalls R."""
    await FallingEdge(dut.sys_clk)
    arready_before_rising = int(dut.s_axi_arready.value)
    dut.s_axi_rready.value = 0
    dut.s_axi_araddr.value = address
    dut.s_axi_arvalid.value = 1
    ar_accepted = False
    rvalid = False
    for _ in range(12):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        ar_accepted = ar_accepted or bool(arready_before_rising)
        rvalid = bool(int(dut.s_axi_rvalid.value))
        await FallingEdge(dut.sys_clk)
        if ar_accepted:
            dut.s_axi_arvalid.value = 0
            break
        arready_before_rising = int(dut.s_axi_arready.value)
    assert ar_accepted, "AR channel did not accept read"
    for _ in range(12):
        if rvalid:
            break
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        rvalid = bool(int(dut.s_axi_rvalid.value))
        if not rvalid:
            await FallingEdge(dut.sys_clk)
    assert rvalid, "R channel did not present response"
    held = (int(dut.s_axi_rdata.value), int(dut.s_axi_rresp.value))
    assert held[1] == 0, "AXI read response was not OKAY"
    for _ in range(hold_cycles):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        assert int(dut.s_axi_rvalid.value) == 1, "RVALID dropped under backpressure"
        assert int(dut.s_axi_arready.value) == 0, "ARREADY rose while R response pending"
        assert (int(dut.s_axi_rdata.value), int(dut.s_axi_rresp.value)) == held, (
            "RDATA/RRESP changed while RVALID && !RREADY"
        )
        await FallingEdge(dut.sys_clk)

    # The loop exits at a falling edge, a safe drive phase before the next
    # response handshake.
    dut.s_axi_rready.value = 1
    await RisingEdge(dut.sys_clk)
    await Timer(2, unit="ns")
    await ReadOnly()
    assert int(dut.s_axi_rvalid.value) == 0, "RVALID did not retire after handshake"
    await FallingEdge(dut.sys_clk)
    dut.s_axi_rready.value = 0
    return held[0]


def _phy_word(lane0_bytes, lane1_bytes):
    """Pack four public PHY octets per lane, lane0 in bits [31:0]."""
    return int.from_bytes(bytes(lane0_bytes + lane1_bytes), byteorder="little")


async def _jesd_bus_bit0_rising(dut):
    """Wait for bit 0 of the public packed JESD clock bus to rise."""
    previous = int(dut.jesd_clk.value) & 1
    while True:
        await ValueChange(dut.jesd_clk)
        current = int(dut.jesd_clk.value) & 1
        if not previous and current:
            return
        previous = current


async def _jesd_bus_bit0_falling(dut):
    """Wait for bit 0 of the public packed JESD clock bus to fall."""
    previous = int(dut.jesd_clk.value) & 1
    while True:
        await ValueChange(dut.jesd_clk)
        current = int(dut.jesd_clk.value) & 1
        if previous and not current:
            return
        previous = current


async def _drive_afe0_jesd_beat(dut, lane0_bytes, lane1_bytes, charisk=0,
                                disperr=0, notintable=0):
    """The sole owner of AFE0 PHY inputs in the JESD diagnostic test."""
    dut.afe0_rx_data.value = _phy_word(lane0_bytes, lane1_bytes)
    dut.afe0_rx_charisk.value = charisk
    dut.afe0_rx_disperr.value = disperr
    dut.afe0_rx_notintable.value = notintable
    await _jesd_bus_bit0_rising(dut)


async def _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=4):
    """Public 2-lane 8b/10b CGS then ILAS using ADI minus-one semantics.

    K28.5 is CGS.  Each ILAS multiframe starts K28.0 and ends K28.3;
    these encodings match the selected ADI jesd204_rx public PHY-parallel
    contract (four octets/lane/JESD_CLK).  No hierarchy below ADC_TOP is read.
    """
    cgs = [0xBC] * 4
    for _ in range(320):
        await _drive_afe0_jesd_beat(dut, cgs, cgs, charisk=0xFF)

    # ADI jesd204_rx keeps each lane's IFS/ILAS monitor in reset until the
    # first LMFC edge reaches the link clock domain.  Present SYSREF while CGS
    # is still held, then leave enough CGS beats for the device-domain LMFC and
    # its link-domain synchronization before presenting the first /R/.
    dut.sysref_in.value = 1
    for _ in range(3):
        await RisingEdge(dut.afe_clk)
    dut.sysref_in.value = 0
    for _ in range(32):
        await _drive_afe0_jesd_beat(dut, cgs, cgs, charisk=0xFF)

    octets_per_multiframe = 255 + 1
    octets_per_frame = 15 + 1
    device_beats_per_multiframe = 15 + 1
    assert octets_per_multiframe == octets_per_frame * device_beats_per_multiframe
    for multiframe in range(4):
        for beat in range(octets_per_multiframe // 4):
            lane = [((multiframe * 17 + beat * 4 + index) & 0xFF) for index in range(4)]
            charisk = 0
            if beat == 0:
                lane[0] = 0x1C       # K28.0 /R/ at the multiframe start.
                charisk |= 0x11
            if beat == 63:
                lane[3] = 0x7C       # K28.3 /A/ at the multiframe end.
                charisk |= 0x88
            await _drive_afe0_jesd_beat(dut, lane, lane, charisk=charisk)

    # The first non-K28.0 beat after /A/ releases the ADI ILAS monitor to data.
    # Start the period-16 CML pattern immediately.  Its period is exactly one
    # pure-ADC output block, so any legal LMFC elastic-buffer release phase has
    # the same public scoreboard result after position-based padding removal.
    lane0 = _ac9810_cml_words(1)
    lane1 = _ac9810_cml_words(17)
    for index in range(post_ilas_blocks * 8):
        pair = index % 8
        await _drive_afe0_jesd_beat(dut, _pack_two_words(lane0[pair * 2:pair * 2 + 2]),
                                     _pack_two_words(lane1[pair * 2:pair * 2 + 2]))


def _ac9810_cml_words(base):
    """One 16-word CML block: odd channels first, then even channels."""
    return [base + index for index in (0, 2, 4, 6, 8, 10, 12, 14,
                                       1, 3, 5, 7, 9, 11, 13, 15)]


def _pack_two_words(words):
    return [words[0] & 0xFF, (words[0] >> 8) & 0xFF,
            words[1] & 0xFF, (words[1] >> 8) & 0xFF]


async def _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=300, base=1):
    """Continue a deterministic period-16 pure-ADC stream and return its beat.

    This is the frozen pure-ADC FRAME_FMT=0 / SMP_PREC=10 case.  The source is
    always an AC9810 N'=16 container: a signed 10-bit code in bits [15:6] and
    six zero padding bits.  Its expected result is the right-aligned signed
    16-bit representation.  The repeated nonzero pattern also occupies
    positions discarded as sync and padding, proving removal is position-based.
    """
    channels, expected_beat = _normalized_sample_pattern(10, 0, phase=base)
    lane0, lane1 = _channel_cml_words(channels)
    for _ in range(block_count * 8):
        pair = _ % 8
        await _drive_afe0_jesd_beat(dut, _pack_two_words(lane0[pair * 2:pair * 2 + 2]),
                                     _pack_two_words(lane1[pair * 2:pair * 2 + 2]))
    return expected_beat


def _sign_extend(sample, width):
    """Independent ADC container-to-16-bit reference conversion."""
    mask = (1 << width) - 1
    sample &= mask
    return sample | (~mask & 0xFFFF) if sample & (1 << (width - 1)) else sample


def _channel_cml_words(channels):
    """Serialize public channels 1..32 into AC9810 odd/even CML order."""
    assert len(channels) == 32
    return ([channels[index] for index in range(0, 16, 2)] +
            [channels[index] for index in range(1, 16, 2)],
            [channels[index] for index in range(16, 32, 2)] +
            [channels[index] for index in range(17, 32, 2)])


def _normalized_sample_pattern(width, frame_fmt, phase):
    """Build documented AC9810 N'=16 containers and the FPGA-format model.

    Every physical source word is left aligned: S={C, zero-padding}.  Even
    channels carry positive C values and odd channels carry negative C values;
    each code has nonzero high and low payload bits.  This makes a low-p-bit
    extraction, dropped source MSB, nonzero-padding acceptance, or reorder
    regression observable for every supported SMP_PREC value.
    """
    assert width in (10, 12, 14)
    assert frame_fmt in (0, 1)
    magnitude_mask = (1 << (width - 1)) - 1
    samples = []
    for index in range(32):
        magnitude = ((phase * 0x25 + index * 0x55) & magnitude_mask)
        magnitude |= (1 << (width - 2)) | 1
        samples.append(magnitude if (index & 1) == 0
                       else (1 << (width - 1)) | magnitude)
    containers = [(sample << (16 - width)) & 0xFFFF for sample in samples]
    expected_words = ([_sign_extend(sample, width) for sample in samples]
                      if frame_fmt == 0 else containers)
    expected = sum(word << (16 * index)
                   for index, word in enumerate(expected_words))
    return containers, expected


async def _drive_afe0_channel_blocks(dut, channels, block_count):
    """Drive a repeated public CML block; no internal DUT state is observed."""
    lane0, lane1 = _channel_cml_words(channels)
    for _ in range(block_count * 8):
        pair = _ % 8
        await _drive_afe0_jesd_beat(
            dut, _pack_two_words(lane0[pair * 2:pair * 2 + 2]),
            _pack_two_words(lane1[pair * 2:pair * 2 + 2]))


async def _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count):
    """Drive alternating complete I and Q CML blocks through public PHY ports."""
    i_lane0, i_lane1 = _channel_cml_words(i_channels)
    q_lane0, q_lane1 = _channel_cml_words(q_channels)
    for block in range(block_count):
        lane0, lane1 = (i_lane0, i_lane1) if (block & 1) == 0 else (q_lane0, q_lane1)
        for pair in range(8):
            await _drive_afe0_jesd_beat(
                dut, _pack_two_words(lane0[pair * 2:pair * 2 + 2]),
                _pack_two_words(lane1[pair * 2:pair * 2 + 2]))


async def _drive_afe0_raw_word_stream(dut, lane0_words, lane1_words):
    """Drive an even-length, contiguous public lane-word stream."""
    assert len(lane0_words) == len(lane1_words)
    assert len(lane0_words) % 2 == 0
    for index in range(0, len(lane0_words), 2):
        await _drive_afe0_jesd_beat(
            dut, _pack_two_words(lane0_words[index:index + 2]),
            _pack_two_words(lane1_words[index:index + 2]))


def _scheduler_sample_code(lane, position):
    """Deterministic positive right-aligned 14-bit reference sample."""
    return (1 + lane * 0x0800 + position * 37 + (position >> 4) * 19) & 0x1FFF


def _scheduler_lane_word(lane, position):
    """AC9810 N'=16 source container: 14-bit code in [15:2], low zeros."""
    return _scheduler_sample_code(lane, position) << 2


def _scheduler_expected_payload(terminal):
    """Map right-aligned fmt0 samples ending at terminal into one output beat."""
    order = (0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15)
    lane0 = [_scheduler_sample_code(0, terminal - 15 + index) for index in range(16)]
    lane1 = [_scheduler_sample_code(1, terminal - 15 + index) for index in range(16)]
    mapped = [lane0[index] for index in order] + [lane1[index] for index in order]
    return sum(word << (16 * index) for index, word in enumerate(mapped))


async def _drive_afe0_scheduler_payload(dut, terminals):
    """Drive enough public lane words to complete exactly the modeled terminals."""
    word_count = terminals[-1] + 1
    if word_count & 1:
        word_count += 1
    lane0 = [_scheduler_lane_word(0, position) for position in range(word_count)]
    lane1 = [_scheduler_lane_word(1, position) for position in range(word_count)]
    await _drive_afe0_raw_word_stream(dut, lane0, lane1)


async def _wait_afe0_complete_packet(dut, expected_payloads, mode, precision, dec_m):
    """Score every public beat of one fixed packet, including framing controls."""
    assert len(expected_payloads) == 256
    for _ in range(2400):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value), "scheduler matrix packet header timed out"
    header = _header_bytes(int(dut.m_axis_afe0_tdata.value))
    assert header[8] == 0 and header[9] == mode and header[10] == precision
    assert header[16:18] == [0, 1] and header[28:30] == [0, 64]
    assert header[32] == dec_m
    assert int(dut.m_axis_afe0_tkeep.value) == (1 << 64) - 1
    assert int(dut.m_axis_afe0_tlast.value) == 0

    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 1
    await RisingEdge(dut.adc_clk)
    await Timer(2, unit="ns")
    accepted = 0
    while accepted < 256:
        await FallingEdge(dut.adc_clk)
        await ReadOnly()
        valid = int(dut.m_axis_afe0_tvalid.value)
        actual = int(dut.m_axis_afe0_tdata.value)
        keep = int(dut.m_axis_afe0_tkeep.value)
        last = int(dut.m_axis_afe0_tlast.value)
        await RisingEdge(dut.adc_clk)
        if valid:
            assert actual == expected_payloads[accepted], (
                f"scheduler payload mismatch at beat {accepted}: "
                f"actual={_axis_words_all(actual)} "
                f"expected={_axis_words_all(expected_payloads[accepted])}"
            )
            assert keep == (1 << 64) - 1
            assert last == int(accepted == 255)
            accepted += 1
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0


async def _wait_afe0_header_and_payload(dut, expected_payloads, mode, precision, dec_m,
                                        mismatch_signatures=None):
    """Scoreboard one public header followed by the requested payload prefix."""
    for _ in range(1200):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value) == 1, "packet header did not arrive"
    header = _header_bytes(int(dut.m_axis_afe0_tdata.value))
    assert header[8] == 0 and header[9] == mode and header[10] == precision
    assert header[32] == dec_m, "header DECIM_X4 mismatch"
    assert int(dut.m_axis_afe0_tlast.value) == 0

    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 1
    # This rising edge accepts the header.  ADC_PKT changes its registered
    # output after #UDLY, so score payload only from the next transaction.
    await RisingEdge(dut.adc_clk)
    await Timer(2, unit="ns")
    await ReadOnly()
    await FallingEdge(dut.adc_clk)
    for expected in expected_payloads:
        for _ in range(32):
            await RisingEdge(dut.adc_clk)
            await ReadOnly()
            if int(dut.m_axis_afe0_tvalid.value):
                break
        assert int(dut.m_axis_afe0_tvalid.value) == 1, "payload beat timed out"
        actual = int(dut.m_axis_afe0_tdata.value)
        if actual != expected:
            classification = "UNCLASSIFIED_PAYLOAD_MISMATCH"
            if mismatch_signatures is not None:
                for label, signature in mismatch_signatures.items():
                    if actual == signature:
                        classification = label
                        break
            dut._log.error(
                "PAYLOAD_CLASSIFICATION %s actual_words=%s expected_words=%s",
                classification, _axis_words_all(actual), _axis_words_all(expected))
            raise AssertionError(
                "public AC9810 mapping/sign-extension/zero-padding scoreboard mismatch: "
                f"classification={classification} "
                f"actual_words={_axis_words_all(actual)} "
                f"expected_words={_axis_words_all(expected)}"
            )
        assert int(dut.m_axis_afe0_tkeep.value) == (1 << 64) - 1
        assert int(dut.m_axis_afe0_tlast.value) == 0
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0


async def _enable_afe0_and_link(dut, adc_ctl, frame_cfg):
    """Bring up the documented public PHY sequence after static configuration."""
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 1
    _assert_software_static_config(adc_ctl, frame_cfg)
    await _axi_write(dut, 0x0008, frame_cfg, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut)


def _assert_software_static_config(adc_ctl, frame_cfg):
    """TB assumption: software enables an AFE only with a supported config."""
    smp_prec = (adc_ctl >> 30) & 0x3
    smp_mode = (adc_ctl >> 26) & 0x3
    dec_del_mode = (frame_cfg >> 8) & 0x3
    dec_m = frame_cfg & 0xFF
    assert smp_prec in (0, 1, 2), f"software contract SMP_PREC={smp_prec}"
    assert smp_mode in (0, 1, 2), f"software contract SMP_MODE={smp_mode}"
    assert dec_del_mode in (0, 1, 2), f"software contract DEC_DEL_MODE={dec_del_mode}"
    if smp_mode == 1:
        assert 1 <= (dec_m >> 2) <= 63, f"software contract single N={dec_m >> 2}"
    elif smp_mode == 2:
        assert 2 <= (dec_m >> 2) <= 63, f"software contract DDC N={dec_m >> 2}"


async def _assert_static_config_stable(dut, adc_ctl, frame_cfg):
    """Public readback check that capture did not change software static fields."""
    _assert_software_static_config(adc_ctl, frame_cfg)
    observed_ctl = await _axi_read(dut, 0x0000)
    observed_frame = await _axi_read(dut, 0x0008)
    assert observed_ctl & 0xCE000000 == adc_ctl & 0xCE000000, (
        f"static ADC_CTL changed during capture: 0x{observed_ctl:08x}")
    assert observed_frame == (frame_cfg & 0x3FF), (
        f"static FRAME_CFG changed during capture: 0x{observed_frame:08x}")


async def _inject_afe0_out_of_phase_sysref(dut):
    """Create a public ADI SYSREF alignment fault after DATA is established."""
    for _ in range(3):
        dut.sysref_in.value = 1
        await RisingEdge(dut.afe_clk)
        dut.sysref_in.value = 0
        await RisingEdge(dut.afe_clk)


def _crc16_ccitt_false(header_bytes):
    crc = 0xFFFF
    for octet in header_bytes:
        crc ^= octet << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _header_bytes(axis_word):
    return [(axis_word >> (8 * index)) & 0xFF for index in range(64)]


def _axis_words(axis_word):
    """Render a bounded public 16-bit-lane diagnostic on mismatch."""
    return [f"0x{(axis_word >> (16 * index)) & 0xFFFF:04x}" for index in range(8)]


def _axis_words_all(axis_word):
    """Render every public 16-bit sample for source-phase diagnosis."""
    return [f"0x{(axis_word >> (16 * index)) & 0xFFFF:04x}" for index in range(32)]


def _repeated_lane_sentinel_beat(lane0_word, lane1_word, width=10):
    """Reference-map one repeated per-lane sentinel through public precision rules."""
    lane0_sample = _sign_extend(lane0_word, width)
    lane1_sample = _sign_extend(lane1_word, width)
    beat = sum(lane0_sample << (16 * index) for index in range(16))
    beat |= sum(lane1_sample << (16 * index) for index in range(16, 32))
    return beat


async def _poll_register(dut, address, mask, expected, attempts=160):
    for _ in range(attempts):
        value = await _axi_read(dut, address)
        if value & mask == expected:
            return value
        await RisingEdge(dut.adc_clk)
    raise AssertionError(
        f"register 0x{address:04x} did not reach 0x{expected:08x} "
        f"under mask 0x{mask:08x}; last=0x{value:08x}"
    )


async def _assert_fifo_empty_stable(dut, channels=(0,), samples=8):
    """Observe FIFO_EMPTY through ADC_STA0 across consecutive SYS_CLK samples."""
    mask = sum(1 << (8 + channel) for channel in channels)
    for _ in range(samples):
        status = await _axi_read(dut, 0x000C)
        assert status & mask == mask, (
            f"FIFO_EMPTY did not remain stable for channels {channels}: ADC_STA0=0x{status:08x}"
        )


async def _fifo_clear_cycle_protocol(dut, selected_mask=0x01):
    """Check FIFO reset convergence while CLR is asserted, preserving AFE_EN."""
    original_ctl = await _axi_read(dut, 0x0000)
    release_ctl = original_ctl & ~0x0000ff00
    await _axi_write(dut, 0x0000,
                     release_ctl | ((selected_mask & 0xFF) << 8), 0xF)
    await _poll_register(dut, 0x000C, (selected_mask & 0xFF) << 8,
                         (selected_mask & 0xFF) << 8, attempts=160)
    # Both reset-owning clocks remain active. Hold a bounded number of cycles
    # only to exercise the selected implementation reset requirement.
    for _ in range(8):
        await RisingEdge(dut.afe_clk)
    for _ in range(8):
        await RisingEdge(dut.adc_clk)
    # A live producer may refill immediately after release.  Empty is therefore
    # a CLR-active invariant, not a post-release invariant.
    await _assert_fifo_empty_stable(dut, tuple(channel for channel in range(8)
                                                if selected_mask & (1 << channel)))
    await _axi_write(dut, 0x0000, release_ctl, 0xF)


def _chn0(dut):
    """Return the frozen AFE0 channel integration boundary."""
    channel = getattr(dut, "adc_chn0", None)
    assert channel is not None, "v1.32 acceptance: ADC_CHN0 hierarchy is absent"
    return channel


def _rxd0(dut):
    """Return the frozen AFE0 ADI/JESD wrapper boundary."""
    wrapper = getattr(_chn0(dut), "adc_rxd", None)
    assert wrapper is not None, "v1.32 acceptance: ADC_RXD hierarchy is absent"
    return wrapper


def _upk0(dut):
    """Return the frozen AFE0 unpacker boundary."""
    channel = _chn0(dut)
    unpack = getattr(channel, "adc_upk", None)
    assert unpack is not None, "v1.32 acceptance: ADC_UPK hierarchy is absent"
    return unpack


def _upk_context(upk):
    return (
        int(upk.rxd_fsm.value), int(upk.prefix_cnt.value),
        int(upk.region_cnt.value), int(upk.ddc_wr_sel.value),
    )


def _assert_upk_contract_shape(upk):
    """Check only the stable v1.32 semantic signals exposed for verification."""
    assert len(upk.rxd_buff0) == 128 and len(upk.rxd_buff1) == 128
    for name in ("rxd_buff0", "rxd_buff1", "region_cnt", "ddc_i_buff",
                  "ddc_q_buff", "ddc_wr_sel", "rxd_buff_upd", "rxd_data_upd",
                  "ddc_i_sta", "ddc_q_sta", "pref_num", "region_vld_max",
                  "region_zro_max", "region_vld_clr", "region_zro_clr",
                  "normal_wr_req", "ddc_i_upd", "ddc_q_upd", "ddc_pair_wr",
                  "data_drop_set"):
        assert getattr(upk, name).value.is_resolvable, f"{name} contains X/Z"


async def _rxd_start_epoch_source(dut):
    """Build one public link then launch the first AFE-domain DATA beat."""
    await FallingEdge(dut.afe_clk)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    for _ in range(2100):
        await _rxd_drive_afe0_jesd_beat(dut)
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _rxd_drive_afe_beat(dut)


async def _rxd_drive_afe0_jesd_beat(dut):
    """Leave ReadOnly before changing the PHY inputs for this directed test."""
    await _jesd_bus_bit0_falling(dut)
    await _drive_afe0_jesd_beat(dut, [1, 2, 3, 4], [5, 6, 7, 8])


async def _rxd_drive_afe_beat(dut):
    """Drive one held PHY value and advance exactly one AFE owner edge."""
    await _rxd_drive_afe0_jesd_beat(dut)
    await RisingEdge(dut.afe_clk)


async def _rxd_drive_afe_beats(dut, count):
    for _ in range(count):
        await _rxd_drive_afe_beat(dut)


async def _rxd_monitor(dut, label, predicate, attempts=1024):
    """Pre-armed monitor: capture the first stable AFE context that matches."""
    upk = _upk0(dut)
    for _ in range(attempts):
        await RisingEdge(dut.afe_clk)
        # ADC_UPK uses #UDLY=1ns nonblocking state updates.  This is after
        # that declared delay and still far before the 28ns AFE period ends.
        await Timer(2, unit="ns")
        await ReadOnly()
        context = _upk_context(upk)
        if predicate(context):
            return context
    raise AssertionError(f"upk_region: {label} monitor timed out: {_upk_context(upk)}")


async def _rxd_preedge_marker_monitor(dut, label, attempts=4096):
    """Pre-arm the v1.32 AFE tuple marker and its post-edge UPK consequence."""
    rxd = _rxd0(dut)
    upk = _upk0(dut)
    for cycle in range(1, attempts + 1):
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        tuple_valid = _diag_int(rxd.link_ready_afe)
        raw_somf = _diag_int(rxd.rxd_somf)
        if tuple_valid == 1 and raw_somf is not None and (raw_somf & 1):
            pre = (cycle, tuple_valid, raw_somf, _diag_hex(rxd.rxd_data),
                   _upk_context(upk))
            await RisingEdge(dut.afe_clk)
            await Timer(2, unit="ns")
            await ReadOnly()
            post = _upk_context(upk)
            dut._log.info("A9_PREEDGE_MARKER %s pre=%s post=%s", label, pre, post)
            return pre, post
    raise AssertionError(f"A9 pre-edge marker monitor timed out: {label}")


async def _rxd_observe(dut, label, predicate, source):
    """Arm before the source drive; cleanly stop the monitor on source failure."""
    monitor = cocotb.start_soon(_rxd_monitor(dut, label, predicate))
    try:
        await source
        return await with_timeout(monitor, 100, "us")
    finally:
        if not monitor.done():
            monitor.kill()


async def _monitor_ddc_pair_decisions(dut, coverage):
    """Observe atomic Q decisions and their exact FIFO-free boundaries."""
    upk = _upk0(dut)
    while True:
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        pre_drop = int(upk.data_drop_set.value)
        pre_q = int(upk.ddc_q_upd.value)
        pre_pair_wr = int(upk.ddc_pair_wr.value)
        pre_level = int(upk.fifo_wlevel.value)
        if pre_pair_wr:
            coverage["admit_levels"].add(pre_level)
        if pre_drop:
            coverage["drop_levels"].add(pre_level)
        await RisingEdge(dut.afe_clk)
        await Timer(2, unit="ns")
        await ReadOnly()
        event = int(upk.data_drop_evt.value)
        assert event == pre_drop, (
            "DATA_DROP pulse does not match the preceding Q-completion decision")
        if event:
            coverage["drop_count"] += 1
            assert pre_q == 1, (
                "DATA_DROP event occurred outside a completed Q block")
            assert pre_pair_wr == 0, (
                "a rejected DDC pair was simultaneously admitted")
            assert int(upk.fifo_wr_valid.value) == 0, (
                "a rejected DDC pair emitted a FIFO request")


async def _rxd_sample_fifo_request_once(dut):
    """Prove one accepted UPK request is stable into, then retires after, E2."""
    channel = _chn0(dut)
    upk = _upk0(dut)
    await FallingEdge(dut.afe_clk)
    await ReadOnly()
    pre_valid = int(upk.fifo_wr_valid.value)
    pre_full = int(channel.fifo_full_afe.value)
    pre_data = int(upk.fifo_wr_data.value)
    pre_level = int(channel.fifo_wr_level.value)
    assert pre_valid == 1, "FIFO request was not held through the E2 setup window"
    assert pre_full == 0, "FIFO request reached E2 while the write side was full"

    await RisingEdge(dut.afe_clk)
    await Timer(2, unit="ns")
    await ReadOnly()
    post_valid = int(upk.fifo_wr_valid.value)
    post_full_value = channel.fifo_full_afe.value
    assert post_full_value.is_resolvable, "FIFO full status contains X/Z after E2"
    post_full = int(post_full_value)
    post_data = int(upk.fifo_wr_data.value)
    post_level = int(channel.fifo_wr_level.value)
    assert post_valid == 0, "accepted FIFO request was not a single-cycle pulse"
    assert post_full == pre_full == 0, "FIFO full status changed across the E2 sample edge"
    assert post_data == pre_data, "FIFO request data changed across the E2 sample edge"
    dut._log.info(
        "A10_FIFO_REQUEST_SAMPLE valid=%d full=%d->%d level=%d->%d data_lsw=0x%08x",
        pre_valid, pre_full, post_full, pre_level, post_level, pre_data & 0xFFFFFFFF)


async def _wait_ddc_zero_terminal(dut, attempts=32):
    """Return at the read-only ZERO cnt11 boundary before the next VALID region."""
    upk = _upk0(dut)
    for cycle in range(1, attempts + 1):
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        if int(upk.rxd_fsm_zero.value) and int(upk.region_zro_clr.value):
            region = int(upk.region_cnt.value)
            assert region == 11, f"DDC ZERO terminal count changed from 11 to {region}"
            context = _upk_context(upk)
            dut._log.info(
                "DDC_CANCEL_ALIGN cycle=%d context=%s fifo_level=%d",
                cycle, context, int(_chn0(dut).fifo_wr_level.value))
            return context
    raise AssertionError(
        f"DDC ZERO terminal was not observed within {attempts} AFE beats: "
        f"{_upk_context(upk)}")


def _ddc14_payload_from_observed_tuple(first_tuple, second_tuple):
    """Independently format one DDC candidate from two observed RXD tuple beats.

    ``first_tuple`` is the cnt=0 first half and ``second_tuple`` is the cnt=1
    completing half.  This mirrors the published lane ordering and 14-bit
    right-aligned conversion, but deliberately derives every input word from
    the arriving ADC_RXD tuple rather than from a nominal PHY-drive phase.
    """
    half_mask = (1 << 128) - 1
    raw0 = ((second_tuple & half_mask) << 128) | (first_tuple & half_mask)
    raw1 = ((second_tuple >> 128) << 128) | (first_tuple >> 128)
    lane_order = (0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15)
    payload = 0
    for lane, raw in enumerate((raw0, raw1)):
        for output_word, input_word in enumerate(lane_order):
            container = (raw >> (16 * input_word)) & 0xffff
            converted = _sign_extend(container >> 2, 14)
            payload |= converted << (16 * (lane * 16 + output_word))
    return payload


async def _trace_ddc_complete_i_from_tuple(dut, attempts=4096):
    """Prove a nonzero I completion from its arriving AFE tuple through UPK.

    The PHY is a clock-crossing/aggregation boundary.  Do not infer the
    ADC_UPK input phase from when the JESD source coroutine wrote a PHY value:
    capture the actual pre-edge RXD tuple and bind it to the next post-edge
    rxd_buff_upd/rxd_data_upd/ddc_i_sta actions and ddc_i_buff verdict.
    """
    rxd = _rxd0(dut)
    upk = _upk0(dut)
    channel = _chn0(dut)
    for cycle in range(1, attempts + 1):
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        if not (int(upk.rxd_fsm_valid.value) and int(upk.region_cnt.value) == 0):
            continue
        # The first I/Q pair must already be physically committed.  This
        # excludes the pre-recovery pair while avoiding a nominal PHY latency.
        if int(channel.fifo_wr_level.value) > 510:
            continue
        first_tuple = int(rxd.rxd_data.value)
        pre_context = _upk_context(upk)
        assert int(upk.rxd_buff_upd.value) == 1, (
            f"DDC I trace cnt0 pre-edge lacks first-half capture: pre={pre_context}")
        await RisingEdge(dut.afe_clk)
        await Timer(2, unit="ns")
        await ReadOnly()
        assert int(upk.rxd_fsm_valid.value) == 1 and int(upk.region_cnt.value) == 1, (
            "DDC I trace did not advance from cnt0 to cnt1")
        assert int(upk.rxd_buff0.value) == (first_tuple & ((1 << 128) - 1)) and \
               int(upk.rxd_buff1.value) == (first_tuple >> 128), (
            "DDC I trace first-half buffer does not match the observed cnt0 tuple")

        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        assert int(upk.rxd_fsm_valid.value) == 1 and int(upk.region_cnt.value) == 1, (
            "DDC I trace did not advance from cnt0 to cnt1")
        second_tuple = int(rxd.rxd_data.value)
        observed_payload = _ddc14_payload_from_observed_tuple(first_tuple, second_tuple)
        assert int(upk.rxd_data_upd.value) == 1 and int(upk.ddc_i_sta.value) == 1, (
            "DDC I trace completion pre-edge lacks rxd_data_upd/ddc_i_sta")
        await RisingEdge(dut.afe_clk)
        await Timer(2, unit="ns")
        await ReadOnly()
        assert int(upk.ddc_i_buff.value) == observed_payload, (
            "DDC I buffer does not match the contract-derived arriving tuple payload")
        if observed_payload != 0:
            dut._log.info(
                "DDC_RECOVERY_I_TRACE cycle=%d pre=%s payload_lsw=0x%08x level=%d",
                cycle, pre_context, observed_payload & 0xffffffff,
                int(channel.fifo_wr_level.value))
            return observed_payload
    raise AssertionError("DDC recovery stream produced no nonzero tuple-derived complete I")


async def _rxd_fifo_clear_source(dut):
    """FIFO-only clear: observe reset while asserted, then allow live refill."""
    channel = _chn0(dut)
    upk = _upk0(dut)
    pre_context = _upk_context(upk)
    pre_buffers = (int(upk.rxd_buff0.value), int(upk.rxd_buff1.value),
                   int(upk.ddc_i_buff.value), int(upk.ddc_q_buff.value))
    pre_request = int(upk.fifo_wr_data.value)
    await _axi_write(dut, 0x0000, 0x00000101, 0xF)
    await _poll_register(dut, 0x000C, 0x00000100, 0x00000100, attempts=160)
    for _ in range(8):
        await RisingEdge(dut.afe_clk)
    await _assert_fifo_empty_stable(dut, (0,))
    assert _upk_context(upk) == pre_context, "FIFO_CLR modified UPK FSM/counters/commit"
    assert (int(upk.rxd_buff0.value), int(upk.rxd_buff1.value),
            int(upk.ddc_i_buff.value), int(upk.ddc_q_buff.value)) == pre_buffers, (
                "FIFO_CLR modified UPK buffers")
    assert int(channel.fifo_wr_level.value) == 512, "FIFO_CLR left a pre-clear word resident"
    assert int(dut.m_axis_afe0_tvalid.value) == 0, (
        f"pre-clear FIFO request 0x{pre_request:0128x} escaped while CLR was asserted")
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    assert (await _axi_read(dut, 0x0000)) & 0x1, "FIFO_CLR release disabled AFE_EN"
    # No persistent-empty assertion follows release: the active source may
    # resume or continue and legitimately create a new FIFO request.


async def _rxd_rx_reset_done_source(dut, value):
    await FallingEdge(dut.afe_clk)
    dut.afe0_rx_reset_done.value = value


async def _rxd_cancel_at_effective_upk_loss(dut, attempts=16):
    """Separate reset-done source drive from the first effective UPK loss edge.

    ``link_ready_afe`` is the contract-defined same-domain tuple health gate;
    its deassertion, rather than the asynchronous PHY source write, is the
    first AFE pre-edge at which ADC_UPK must clear.  A FIFO request registered
    before that edge is allowed one final FIFO sample on that edge.  No later
    request or level change is permitted.
    """
    rxd = _rxd0(dut)
    upk = _upk0(dut)
    channel = _chn0(dut)
    await _rxd_rx_reset_done_source(dut, 0)
    for cycle in range(1, attempts + 1):
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        if int(rxd.link_ready_afe.value) != 0:
            continue
        pre_context = _upk_context(upk)
        pre_level = int(channel.fifo_wr_level.value)
        pre_request = int(upk.fifo_wr_valid.value)
        assert pre_context != (0, 0, 0, 0), (
            "effective UPK-loss edge was observed only after context had already cleared")
        await RisingEdge(dut.afe_clk)
        await Timer(2, unit="ns")
        await ReadOnly()
        expected_level = pre_level - pre_request
        assert _upk_context(upk) == (0, 0, 0, 0), (
            "effective upk_vld withdrawal did not clear UPK context")
        assert int(channel.fifo_wr_level.value) == expected_level, (
            "FIFO level did not account exactly for the pre-loss registered request")
        await FallingEdge(dut.afe_clk)
        await ReadOnly()
        assert int(upk.fifo_wr_valid.value) == 0, (
            "UPK emitted a new FIFO request after effective upk_vld withdrawal")
        stable_level = int(channel.fifo_wr_level.value)
        assert stable_level == expected_level, (
            "FIFO level changed after the allowed effective-loss sample")
        await RisingEdge(dut.afe_clk)
        await Timer(2, unit="ns")
        await ReadOnly()
        assert int(channel.fifo_wr_level.value) == stable_level, (
            "FIFO accepted an extra transfer after effective upk_vld withdrawal")
        dut._log.info(
            "DDC_EFFECTIVE_CANCEL cycle=%d pre=%s level=%d request=%d final=%d",
            cycle, pre_context, pre_level, pre_request, stable_level)
        return pre_level, pre_request, stable_level
    raise AssertionError("source reset-done withdrawal never reached effective link_ready_afe=0")


async def _wait_clean_afe0_packet(dut, expected_payload, expected_sequence=None):
    """Accept a new public packet and reject stale-epoch payload data."""
    for _ in range(1200):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value), "clean relink did not expose a packet header"
    header = _header_bytes(int(dut.m_axis_afe0_tdata.value))
    if expected_sequence is not None:
        assert header[20:24] == list(expected_sequence.to_bytes(4, "little")), (
            f"unexpected packet sequence after reset/relink: {header[20:24]}"
        )
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 1
    # Accept the header on the following edge. Payload transaction 1 becomes
    # visible after the registered state update and is sampled at FallingEdge.
    await RisingEdge(dut.adc_clk)
    for beat in range(256):
        await FallingEdge(dut.adc_clk)
        await ReadOnly()
        # Sample the stable transaction before its accepting rising edge.
        assert int(dut.m_axis_afe0_tvalid.value), "packet ended before fixed payload completion"
        actual = int(dut.m_axis_afe0_tdata.value)
        assert actual == expected_payload, (
            f"stale/partial data escaped after reset at payload beat {beat + 1}: "
            f"actual={_axis_words(actual)} expected={_axis_words(expected_payload)}"
        )
        assert int(dut.m_axis_afe0_tkeep.value) == (1 << 64) - 1, (
            f"TKEEP changed in clean-restart packet at payload beat {beat + 1}"
        )
        assert int(dut.m_axis_afe0_tlast.value) == int(beat == 255), (
            f"TLAST must occur only on clean-restart payload beat 256, saw beat {beat + 1}"
        )
        await RisingEdge(dut.adc_clk)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0


class RegisterScoreboard:
    """Small independent model of the three software configuration registers."""

    def __init__(self):
        self.adc_ctl = 0
        self.adc_tgc = 0
        self.frame_cfg = 0

    def write_adc_ctl(self, data, cfg_safe):
        static = data & 0xCE000000 if cfg_safe else self.adc_ctl & 0xCE000000
        self.adc_ctl = static | (data & 0x0000FFFF)

    def write_frame_cfg(self, data, cfg_safe):
        if cfg_safe:
            self.frame_cfg = data & 0x3FF


async def _pure_adc_fixed_prefix(dut):
    """Pure ADC captures only after its fixed legal 16-AFE-beat prefix."""
    await _setup(dut)
    adc_ctl = 0x00000000
    frame_cfg = 0x000
    await _enable_afe0_and_link(dut, adc_ctl, frame_cfg)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    expected = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=320, base=1)
    await _wait_afe0_complete_packet(dut, [expected] * 256, 0, 10, frame_cfg)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, frame_cfg)
    dut._log.info("STIMULUS_MARKER pure_adc_fixed_16_beat_prefix_pass")


async def _static_cfg_non_idle_only_gate(dut):
    """AFE_EN=0 is insufficient while one public packet remains active."""
    await _setup(dut)
    await _enable_afe0_and_link(dut, 0x00000000, frame_cfg=0x155)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    expected = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=320, base=1)

    for _ in range(2400):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value), "active packet did not reach stalled header"

    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    assert await _axi_read(dut, 0x0000) & 0xFF == 0
    await _poll_register(dut, 0x000C, 1 << 24, 0, attempts=160)
    idle_status = await _axi_read(dut, 0x000C)
    assert ((idle_status >> 24) & 0xFF) == 0xFE

    pd_before_unsafe = await _axi_read(dut, 0x0010)
    await _axi_write(dut, 0x0000, 0x88000000, 0x0)
    await _axi_write(dut, 0x0008, 0x000002FF, 0x5)
    assert await _axi_read(dut, 0x0000) == 0x00000000
    assert await _axi_read(dut, 0x0008) == 0x155
    assert await _axi_read(dut, 0x0010) == pd_before_unsafe

    await _wait_afe0_complete_packet(dut, [expected] * 256, 0, 10, 0x55)
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=240)

    await _axi_write(dut, 0x0000, 0x88000000, 0x6)
    await _axi_write(dut, 0x0008, 0x000002FF, 0x2)
    assert await _axi_read(dut, 0x0000) == 0x88000000
    assert await _axi_read(dut, 0x0008) == 0x2FF
    dut._log.info("STIMULUS_MARKER static_cfg_non_idle_only_gate_pass")


async def _reset_and_top_level_defaults(dut):
    await _setup(dut)
    _assert_fixed_eight_channel_interface(dut)
    for name in (
        "s_axi_awready", "s_axi_wready", "s_axi_bresp", "s_axi_bvalid",
        "s_axi_arready", "s_axi_rdata", "s_axi_rresp", "s_axi_rvalid",
    ):
        _assert_known(dut, name)
    assert await _axi_read(dut, 0x0000) == 0
    assert await _axi_read(dut, 0x0004) == 0
    assert await _axi_read(dut, 0x0008) == 0
    assert await _axi_read(dut, 0x0030) == 0
    for channel in range(8):
        for name in (f"m_axis_afe{channel}_tvalid", f"m_axis_afe{channel}_tlast",
                     f"afe{channel}_rx_encommalign", f"afe{channel}_sync_n",
                     f"tgc{channel}_slope", f"tgc{channel}_up_dn",
                     f"tgc{channel}_prof1", f"tgc{channel}_prof2"):
            _assert_known(dut, name)
        assert int(_required(dut, f"m_axis_afe{channel}_tvalid").value) == 0
        assert int(_required(dut, f"m_axis_afe{channel}_tlast").value) == 0
    dut._log.info("STIMULUS_MARKER reset_and_defaults_pass")


async def _register_and_mode_matrix(dut):
    await _setup(dut)
    model = RegisterScoreboard()
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=160)

    # WSTRB is accepted but has no byte-enable meaning.  Every handshake
    # consumes the complete WDATA value, including WSTRB=0.
    strobe_vectors = (
        (0x0, 0x001), (0x1, 0x102), (0x5, 0x203),
        (0xA, 0x304), (0x7, 0x155), (0xF, 0xFFFFFFFF),
    )
    for index, (strobe, value) in enumerate(strobe_vectors):
        await _axi_write(
            dut, 0x0008, value, strobe,
            split=index in (0, 1),
            split_order="aw_then_w" if index == 0 else "w_then_aw",
            b_hold_cycles=5 if index == 1 else 0)
        model.write_frame_cfg(value, True)
        assert await _axi_read(dut, 0x0008) == model.frame_cfg

    # One safe ADC_CTL write updates static fields and simultaneously enables
    # AFE0.  Once active, the global static-write gate must close.
    safe_launch = 0x76000001
    await _axi_write(dut, 0x0000, safe_launch, 0x3)
    model.write_adc_ctl(safe_launch, True)
    assert await _axi_read(dut, 0x0000) == model.adc_ctl == 0x46000001
    await _poll_register(dut, 0x000C, 1 << 24, 0, attempts=160)

    held_frame_cfg = model.frame_cfg
    await _axi_write(dut, 0x0008, 0x000002FF, 0xC)
    model.write_frame_cfg(0x000002FF, False)
    assert await _axi_read(dut, 0x0008) == held_frame_cfg == model.frame_cfg

    # Unsafe ADC_CTL still replaces dynamic AFE_EN/FIFO_CLR while preserving
    # the previous static fields, irrespective of WSTRB.
    unsafe_ctl = 0x88000202
    await _axi_write(dut, 0x0000, unsafe_ctl, 0x0)
    model.write_adc_ctl(unsafe_ctl, False)
    assert await _axi_read(dut, 0x0000) == model.adc_ctl == 0x46000202
    assert await _axi_read(dut, 0x0010) == 0

    await _axi_write(dut, 0x0000, 0x00000000, 0x9)
    model.write_adc_ctl(0x00000000, False)
    assert await _axi_read(dut, 0x0000) == model.adc_ctl == 0x46000000
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=240)

    # After every AFE is disabled and idle, static writes succeed again.
    await _axi_write(dut, 0x0000, 0x88000000, 0x6)
    model.write_adc_ctl(0x88000000, True)
    await _axi_write(dut, 0x0008, 0x000002FF, 0x2)
    model.write_frame_cfg(0x000002FF, True)
    assert await _axi_read(dut, 0x0000) == model.adc_ctl == 0x88000000
    assert await _axi_read(dut, 0x0008) == model.frame_cfg == 0x2FF

    await _axi_write(dut, 0x0030, 0xDEADBEEF, 0xF)
    assert await _axi_read(dut, 0x0030) == 0


async def _fifo_clear_and_stopped_adc_access(dut):
    adc_enable = await _setup(dut)
    # FIFO_CLR is a level protocol with active AFE/ADC clocks, not a 5 ms
    # timing requirement. Assert, satisfy bounded selected-reset cycles,
    # deassert, then require observed FIFO_EMPTY convergence and stability.
    await _fifo_clear_cycle_protocol(dut, selected_mask=0xFF)
    assert await _axi_read(dut, 0x0000) & 0xFF00 == 0

    # Stop ADC_CLK after live status settles; SYS_CLK register access remains
    # responsive and synchronized live levels retain their last sampled value.
    adc_enable[0] = False
    await Timer(50, unit="ns")
    # Allow the final levels_sync pipeline update to settle.
    for _ in range(8):
        await RisingEdge(dut.sys_clk)
    await _axi_read(dut, 0x000C)
    for _ in range(8):
        await RisingEdge(dut.sys_clk)
    snapshot = await _axi_read(dut, 0x000C)
    await _axi_write(dut, 0x0008, 0x00000140, 0xF)
    assert await _axi_read(dut, 0x0008) == 0x00000140
    assert await _axi_read(dut, 0x000C) == snapshot
    dut._log.info("STIMULUS_MARKER fifo_clear_and_stopped_adc_access_pass")


async def _tgc_error_and_backpressure(dut):
    await _setup(dut)

    # Mask AFE0+AFE2, profile 2, up direction, with a one-AFE-cycle slope.
    command = (1 << 12) | (1 << 11) | (2 << 9) | (0x05 << 1) | 1
    await _axi_write(dut, 0x0004, command, 0xF)
    slope_counts = [0, 0, 0]
    for _ in range(96):
        await RisingEdge(dut.afe_clk)
        for channel in range(3):
            slope_counts[channel] += int(_required(dut, f"tgc{channel}_slope").value)
    assert slope_counts == [1, 0, 1], f"unexpected TGC slope counts {slope_counts}"
    for channel in (0, 2):
        assert int(_required(dut, f"tgc{channel}_prof1").value) == 0
        assert int(_required(dut, f"tgc{channel}_prof2").value) == 1
        assert int(_required(dut, f"tgc{channel}_up_dn").value) == 1

    # A second RUN while a new command is in flight must be rejected without
    # replacing its mask/profile/direction, and must set reentry PD.
    command2 = (1 << 9) | (0x02 << 1) | 1
    replacement = (3 << 9) | (1 << 11) | (0x02 << 1) | 1
    await _axi_write(dut, 0x0004, command2, 0xF)
    await _axi_write(dut, 0x0004, replacement, 0xF)
    await _poll_register(dut, 0x0010, 1 << 25, 1 << 25)
    no_slope_count = 0
    for _ in range(16):
        await RisingEdge(dut.afe_clk)
        no_slope_count += int(dut.tgc1_slope.value)
    assert no_slope_count == 0, "SLOPE_TRIG=0 emitted an unexpected slope pulse"
    await _poll_register(dut, 0x0004, 1, 0)
    assert int(dut.tgc1_prof1.value) == 1
    assert int(dut.tgc1_prof2.value) == 0
    assert int(dut.tgc1_up_dn.value) == 0
    assert int(dut.tgc0_prof2.value) == 1 and int(dut.tgc2_prof2.value) == 1, (
        "unselected TGC profile outputs did not retain their prior values"
    )
    await _axi_write(dut, 0x0010, 1 << 25, 0xF)
    await _poll_register(dut, 0x0010, 1 << 25, 0)

    # Exercise every fixed TGC output with one all-channel command. This also
    # catches top-level channel swaps that AFE0 datapath scoreboards cannot see.
    all_channel_command = (1 << 12) | (1 << 9) | (0xFF << 1) | 1
    await _axi_write(dut, 0x0004, all_channel_command, 0xF)
    all_slope_counts = [0] * 8
    for _ in range(320):
        await RisingEdge(dut.afe_clk)
        for channel in range(8):
            all_slope_counts[channel] += int(
                _required(dut, f"tgc{channel}_slope").value)
    assert all_slope_counts == [1] * 8, (
        f"fixed-eight TGC routing mismatch: {all_slope_counts}")
    for channel in range(8):
        assert int(_required(dut, f"tgc{channel}_prof1").value) == 1
        assert int(_required(dut, f"tgc{channel}_prof2").value) == 0
        assert int(_required(dut, f"tgc{channel}_up_dn").value) == 0

    # A run command with an empty mask sets the public sticky error; W1C clears
    # it directly in the SYS-domain sole sticky owner.
    await _axi_write(dut, 0x0004, 0x00000001, 0xF)
    await _poll_register(dut, 0x0010, 1 << 24, 1 << 24)
    await _axi_write(dut, 0x0010, 1 << 24, 0xF)
    await _poll_register(dut, 0x0010, 1 << 24, 0)

    # Inactive PHY plus downstream backpressure must never fabricate traffic.
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    for _ in range(64):
        await RisingEdge(dut.adc_clk)
        assert int(dut.m_axis_afe0_tvalid.value) == 0
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    dut._log.info("STIMULUS_MARKER tgc_error_w1c_backpressure_pass")


async def _axi_read_backpressure_and_reset_ready_low(dut):
    _initialize_all_inputs(dut)
    _start_all_clocks(dut)
    # RREADY is manager-owned and deliberately low throughout reset.  The slave
    # must not fabricate a response before an accepted AR transaction.
    dut.s_axi_rready.value = 0
    for _ in range(6):
        await RisingEdge(dut.sys_clk)
        await ReadOnly()
        assert int(dut.s_axi_rready.value) == 0, "testbench drove RREADY high in reset"
        assert int(dut.s_axi_rvalid.value) == 0, "RVALID asserted during reset"
    await _release_all_resets(dut)
    assert await _axi_read_response_backpressure(dut, 0x0000) == 0
    dut._log.info("STIMULUS_MARKER axi_r_backpressure_stability_pass")


async def _public_phy_cgs_ilas_and_packet_header(dut):
    await _setup(dut)
    # All PHY state comes in through ADC_TOP ports.  Enable only AFE0 and hold
    # its AXIS sink to expose header stability under real downstream pressure.
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    dut._log.info("STIMULUS_MARKER phy0_enable_and_reset_hold")

    # ADC_CTL's frozen PHY reset hold is 2,000 ADC_CLK cycles.  Keep the PHY
    # idle until that public timing window has elapsed; no DUT hierarchy is used.
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut)

    # Public AC9810 CML1/CML5 epoch: 16 sync + 96 zero words then repeating
    # odd-first/even-second blocks.  This drives the real ADI RX -> ADC_RXD ->
    # FWFT FIFO path and produces an unambiguous channel-order scoreboard beat.
    # Prefill below the 256-beat packet admission threshold.  FIFO_EMPTY=0 is
    # observable, but no packet has started and therefore none is expected to
    # disappear across the following software-managed reset sequence.
    await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=128)

    # Either source or destination reset clears the whole cross-domain FIFO.
    # Deliberately buffered pre-reset data must never be emitted after release.
    fifo_status_before_afe_reset = await _axi_read(dut, 0x000C)
    assert (fifo_status_before_afe_reset & (1 << 8)) == 0, (
        "AFE0 FIFO unexpectedly empty before the AFE-only reset discard test"
    )
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    dut._log.info("STIMULUS_MARKER afe_reset_whole_fifo_discard_start")
    await FallingEdge(dut.afe_clk)
    dut.afe_rst_n.value = 0
    for _ in range(4):
        await RisingEdge(dut.afe_clk)
    await FallingEdge(dut.afe_clk)
    dut.afe_rst_n.value = 1
    await _assert_fifo_empty_stable(dut, (0,))

    # Device reset and link reset are independent ADI domains.  Reset the link
    # explicitly while disabled, then re-enable and submit a new epoch.
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    # Re-establish the public link and submit a different post-reset epoch.
    # The scoreboard below proves no pre-reset or partial data survived.
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    expected_payload = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=620, base=101)
    dut._log.info("STIMULUS_MARKER afe_reset_whole_fifo_discard_pass")

    # The approved normal-mode policy submits a write attempt at full.  The
    # PUB FWFT FIFO rejects it and emits its native AFE->SYS overflow event.
    # ADC_RXD must not add a normal-mode data-drop event around that native
    # WC=0 decision.
    await _poll_register(dut, 0x0010, 1 << 0, 1 << 0, attempts=400)
    assert (await _axi_read(dut, 0x0010) & (1 << 8)) == 0, (
        "normal WC=0 FIFO full incorrectly generated DATA_DROP_PD"
    )
    status0 = await _poll_register(dut, 0x000C, 0x00000001, 0x00000001, attempts=300)
    dut._log.info("PUBLIC_PHY_DIAGNOSTIC ADC_STA0=0x%08x", status0)
    for address, name in ((0x0010, "ADC_STA1"), (0x0014, "AFE_STA"),
                          (0x0018, "SYSREF_STA"), (0x001C, "LANE_STA0"),
                          (0x0020, "LANE_STA1"), (0x0024, "LANE_STA2"),
                          (0x0028, "LANE_STA3"), (0x002C, "LANE_STA4")):
        value = await _axi_read(dut, address)
        dut._log.info("PUBLIC_PHY_DIAGNOSTIC %s=0x%08x", name, value)
    for _ in range(160):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value) == 1, (
        "PUBLIC_PHY_DIAGNOSTIC: link became ready but no packet header was exposed; "
        "inspect CGS/ILAS marker delivery and AC9810 payload epoch"
    )
    header = int(dut.m_axis_afe0_tdata.value)
    held_header = (header, int(dut.m_axis_afe0_tkeep.value),
                   int(dut.m_axis_afe0_tlast.value))
    for _ in range(4):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 1, "header VALID dropped under pressure"
        assert (int(dut.m_axis_afe0_tdata.value), int(dut.m_axis_afe0_tkeep.value),
                int(dut.m_axis_afe0_tlast.value)) == held_header, "header changed under pressure"

    header_octets = _header_bytes(header)
    assert header_octets[0:4] == [0x44, 0x54, 0x52, 0x31], "bad DTR1 header magic"
    assert header_octets[4] == 1 and header_octets[5] == 64, "bad header version/length"
    assert header_octets[8] == 0 and header_octets[9] == 0 and header_octets[10] == 10
    assert header_octets[16:18] == [0, 1], "packet frame count must be 256"
    assert header_octets[20:24] == [0, 0, 0, 0], "first packet sequence must be zero"
    assert header_octets[28:30] == [0, 64], "payload bytes must be 16384"
    assert header_octets[30:32] == [0, 0] and header_octets[33] == 0, "FLAGS must be zero"
    assert header_octets[32] == 0, "pure ADC DEC_M must be zero"
    assert _crc16_ccitt_false(header_octets[:62]) == (header_octets[62] | header_octets[63] << 8), (
        "header CRC16/CCITT-FALSE mismatch"
    )

    # Deliberately issue several out-of-phase SYSREF pulses in DATA.  This is a
    # public ADI link-error stimulus, not a PHY disparity surrogate.
    await RisingEdge(dut.adc_clk)
    await _inject_afe0_out_of_phase_sysref(dut)
    await _poll_register(dut, 0x0010, 1 << 16, 1 << 16, attempts=240)

    # Software owns link recovery. Disable before releasing backpressure; the
    # already-admitted packet must still complete, while no new packet starts.
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)

    # Release the started packet and verify all 256 public payload handshakes,
    # exact CML1/CML5 mapping, fixed TLAST, and constant TKEEP.
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 1
    payload_beats = 0
    for _ in range(400):
        await FallingEdge(dut.adc_clk)
        valid = int(dut.m_axis_afe0_tvalid.value)
        if valid:
            assert int(dut.m_axis_afe0_tkeep.value) == (1 << 64) - 1
            payload_beats += 1
            assert int(dut.m_axis_afe0_tdata.value) == expected_payload, (
                f"AC9810 CML1/CML5 channel mapping mismatch at payload beat {payload_beats}"
            )
            last = int(dut.m_axis_afe0_tlast.value)
            assert last == int(payload_beats == 256), (
                f"TLAST must occur only on payload beat 256, saw beat {payload_beats}"
            )
            if last:
                await RisingEdge(dut.adc_clk)
                await ReadOnly()
                break
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
    assert payload_beats == 256, f"expected 256 payload beats, saw {payload_beats}"
    # The disable prevents new admission after the completed packet.
    for _ in range(192):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 0, (
            "AFE_EN clear launched a packet from FIFO residual"
        )

    # Clear overflow only after software has stopped the channel and the
    # already-admitted packet has drained.  While a live source keeps writing
    # a full FIFO, a new native overflow event is required to beat W1C.
    await FallingEdge(dut.sys_clk)
    await _axi_write(dut, 0x0010, 1 << 0, 0xF)
    await _poll_register(dut, 0x0010, 1 << 0, 0, attempts=400)
    dut._log.info("STIMULUS_MARKER fifo_overflow_sys_w1c_pass")

    # W1C only clears the SYS-domain diagnostic PD. Software then performs the
    # external reset/re-enable/relink sequence; hardware has no retry FSM.
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    await RisingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0010, 1 << 16, 0xF)
    await _poll_register(dut, 0x0010, 1 << 16, 0, attempts=240)
    await Timer(4, unit="ns")
    dut.jesd_rst_n.value = 0xFE
    await Timer(56, unit="ns")
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    for _ in range(12):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut)
    for _ in range(800):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        if int(dut.m_axis_afe0_tvalid.value):
            break
    assert int(dut.m_axis_afe0_tvalid.value) == 1, "software relink did not expose second header"
    second_header = _header_bytes(int(dut.m_axis_afe0_tdata.value))
    assert second_header[20:24] == [1, 0, 0, 0], "second packet sequence must be one"
    assert second_header[16:18] == [0, 1] and second_header[28:30] == [0, 64]

    # EN clear at the second header is independent coverage: it may stop a
    # future packet but cannot terminate the packet already publicly started.
    await RisingEdge(dut.adc_clk)
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 1
    second_payload_beats = 0
    for _ in range(400):
        await FallingEdge(dut.adc_clk)
        if int(dut.m_axis_afe0_tvalid.value):
            second_payload_beats += 1
            assert int(dut.m_axis_afe0_tdata.value) == expected_payload
            assert int(dut.m_axis_afe0_tlast.value) == int(second_payload_beats == 256)
            if second_payload_beats == 256:
                await RisingEdge(dut.adc_clk)
                await ReadOnly()
                break
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
    assert second_payload_beats == 256, "AFE_EN clear truncated second fixed packet"
    for _ in range(192):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 0, "AFE_EN clear launched a residual tail"

    # In contrast with afe_rst_n above, adc_rst_n is a complete FIFO reset.
    # There is intentionally retained residual source data after both fixed
    # packets; assert the public FIFO status changes to empty after the reset.
    fifo_status_before_adc_reset = await _axi_read(dut, 0x000C)
    assert (fifo_status_before_adc_reset & (1 << 8)) == 0, (
        "AFE0 FIFO unexpectedly empty before the adc_rst_n clear test"
    )
    await FallingEdge(dut.adc_clk)
    dut.adc_rst_n.value = 0
    for _ in range(3):
        await RisingEdge(dut.adc_clk)
    await FallingEdge(dut.adc_clk)
    dut.adc_rst_n.value = 1
    for _ in range(12):
        await RisingEdge(dut.sys_clk)
    fifo_status_after_adc_reset = await _poll_register(dut, 0x000C, 1 << 8, 1 << 8)
    assert fifo_status_after_adc_reset & (1 << 8), "adc_rst_n did not clear the complete FWFT FIFO"
    dut._log.info("STIMULUS_MARKER public_cgs_ilas_header_crc_packet_pass")


async def _decimation_data_scoreboard_and_empty_guard(dut):
    """Public 12-bit decimation regression, including the empty-FIFO guard."""
    await _setup(dut)
    # SMP_PREC=12, SMP_MODE=decimation, FRAME_FMT=1 lossless left-aligned.
    # DEC_M=32 is the smallest legal decimation setting and DEC_DEL_MODE=0.
    adc_ctl = 0x46000000
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 1
    _assert_software_static_config(adc_ctl, 0x20)
    await _axi_write(dut, 0x0008, 0x20, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=240)

    channels, expected = _normalized_sample_pattern(12, 1, phase=1)

    await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)
    for _ in range(96):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 0, (
            "empty FWFT FIFO started an AXIS header/payload while TREADY was high"
        )

    await FallingEdge(dut.sys_clk)
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

    prefix_words = 39 * 8
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * (prefix_words - 32),
        [0x2468] * 32 + [0x0000] * (prefix_words - 32))
    await _drive_afe0_channel_blocks(dut, channels, block_count=4400)
    await _wait_afe0_header_and_payload(dut, (expected, expected), 1, 12, 32)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, 0x20)
    dut._log.info("STIMULUS_MARKER decimation12_empty_guard_scoreboard_pass")


async def _ddc_data_scoreboard(dut):
    """Public 14-bit DDC regression with ordered, indivisible I/Q pairs."""
    await _setup(dut)
    # SMP_PREC=14, SMP_MODE=DDC, FRAME_FMT=0 signed right-aligned, DEC_M=32.
    adc_ctl = 0x88000000
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    i_channels, expected_i = _normalized_sample_pattern(14, 0, phase=1)
    q_channels, expected_q = _normalized_sample_pattern(14, 0, phase=41)

    # _setup leaves the public FIFO empty.  Configure while disabled, then
    # enable once and keep TREADY low while the entire public PHY sequence is
    # streamed without an AXI/FIFO_CLR gap in the DATA epoch.
    _assert_software_static_config(adc_ctl, 0x20)
    await _axi_write(dut, 0x0008, 0x20, 0xF)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

    # Begin the first non-control PHY beat immediately after /A/.  The DDC
    # prefix and I/Q payload form one continuous public DATA stream.
    # DDC E=32,N=8,f=0,d=0 has pref_num=2N+23=39 AFE beats = 312 words.
    # Supply that complete physical framing prefix after the first DATA word:
    # 32 synchronizing words followed by 280 zero-padding words per lane.
    # The subsequent I/Q CML stream then begins exactly at the public epoch's
    # first payload word, rather than 24 words into a 32-word DDC period.
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    pair_coverage = {"drop_count": 0, "admit_levels": set(), "drop_levels": set()}
    drop_monitor = cocotb.start_soon(_monitor_ddc_pair_decisions(dut, pair_coverage))
    try:
        await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=2400)
        await _poll_register(dut, 0x0010, 1 << 8, 1 << 8, attempts=400)
    finally:
        if not drop_monitor.done():
            drop_monitor.kill()
    # The stalled sink exhausts the FWFT write capacity.  DDC rejects only at
    # a completed Q decision when fewer than two slots remain; DATA_DROP_PD is the
    # public indication of that whole-pair rejection.  The earliest accepted
    # packets below must remain ordered I/Q, proving no rejected I orphan was
    # inserted ahead of them.
    assert pair_coverage["drop_count"] > 0, (
        "DDC capacity stress raised no atomic Q-completion drop pulse")
    assert {2, 512}.issubset(pair_coverage["admit_levels"]), (
        f"DDC admission missed free=2/512 boundaries: {pair_coverage}")
    assert 0 in pair_coverage["drop_levels"], (
        f"DDC capacity stress missed free=0 whole-pair drop: {pair_coverage}")
    await _wait_afe0_header_and_payload(
        dut, (expected_i, expected_q, expected_i, expected_q), 2, 14, 32)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, 0x20)
    dut._log.info("STIMULUS_MARKER ddc14_iq_pair_scoreboard_pass")


async def _normalized_format_pure_scoreboard(dut, width, frame_fmt, phase):
    """Score one missing legal output-format pair through the public PHY path.

    The device-facing stimulus never changes alignment: it is always AC9810
    N'=16 S={C,zeros}.  FRAME_FMT selects only the FPGA's software-requested
    output representation, so this test catches a format path that incorrectly
    treats the physical source layout as software-dependent.
    """
    precision_code = {10: 0, 12: 1, 14: 2}[width]
    adc_ctl = (precision_code << 30) | (frame_fmt << 25)
    await _setup(dut)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    _assert_software_static_config(adc_ctl, 0x00)
    await _axi_write(dut, 0x0008, 0x00, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=240)
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    channels, expected = _normalized_sample_pattern(width, frame_fmt, phase)
    await _drive_afe0_channel_blocks(dut, channels, block_count=620)
    await _wait_afe0_header_and_payload(dut, (expected, expected), 0, width, 0)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, 0x00)
    dut._log.info(
        "STIMULUS_MARKER normalized_format_pure_scoreboard_pass width=%d frame_fmt=%d",
        width, frame_fmt)


async def _fixed_somf_alignment_and_zero_payload(dut):
    """Public fixed-SOMF epoch test: a legal all-zero ADC payload is data."""
    await _setup(dut)
    await _enable_afe0_and_link(dut, 0x00000000, frame_cfg=0x00)

    # The ADI marker is intentionally not a public ADC_TOP port.  This test
    # therefore checks its observable contract: after a documented CGS/ILAS
    # link, the fixed SOMF[0] epoch reaches the positional payload boundary
    # and a legal all-zero CML block must emerge as payload, not be discarded
    # as synchronizing/padding data.  Non-bit0 SOMF positions are not an
    # externally injectable condition in the fixed ADI instance.
    # FIFO_CLR is a recovery sequence, never an in-place DATA-epoch shortcut.
    # Stop the source, wait for AFE_IDLE, clear with clocks running, then
    # explicitly reset/relink and re-enable before supplying the zero epoch.
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    await FallingEdge(dut.adc_clk)
    dut.m_axis_afe0_tready.value = 0
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_channel_blocks(dut, [0] * 32, block_count=320)
    await _wait_afe0_header_and_payload(dut, (0, 0), 0, 10, 0)
    dut._log.info("STIMULUS_MARKER fixed_somf_bit0_zero_payload_pass")


def _diag_int(handle):
    """Return a resolved monitor value, or None for X/Z without raising."""
    if handle is None:
        return None
    value = handle.value
    if not value.is_resolvable:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _diag_scalar(handle):
    if handle is None:
        return "NA"
    value = _diag_int(handle)
    return "X" if value is None else str(value)


def _diag_hex(handle, bits=16):
    if handle is None:
        return "NA"
    value = _diag_int(handle)
    if value is None:
        return "X"
    return f"0x{value & ((1 << bits) - 1):0{(bits + 3) // 4}x}"


async def _reset_domain_whole_fifo_and_relink(dut):
    """Black-box AFE/ADC/JESD reset-domain discard and clean-restart coverage."""
    await _setup(dut)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=128, base=1)
    assert (await _axi_read(dut, 0x000C) & (1 << 8)) == 0, "pre-reset FIFO did not fill"

    # Stop before reset: sub-threshold resident data means no fixed packet has
    # been admitted, and AFE_IDLE proves the source will not refill the FIFO.
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)

    # adc_rst_n alone resets destination/read/packet state and the whole FIFO.
    dut.adc_rst_n.value = 0
    for _ in range(4):
        await RisingEdge(dut.adc_clk)
    dut.adc_rst_n.value = 1
    await _assert_fifo_empty_stable(dut, (0,))
    # Establish an explicit new link epoch before re-enabling the source.
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    expected_adc_restart = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=320, base=301)
    await _wait_clean_afe0_packet(dut, expected_adc_restart)

    # Interrupt a new source block with jesd_rst_n. A subsequent relink must
    # never splice the pre-reset half-block with post-reset words.
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)
    poison0 = _ac9810_cml_words(0x401)
    poison1 = _ac9810_cml_words(0x501)
    for pair in range(4):
        await _drive_afe0_jesd_beat(
            dut, _pack_two_words(poison0[pair * 2:pair * 2 + 2]),
            _pack_two_words(poison1[pair * 2:pair * 2 + 2]))
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    expected_jesd_restart = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=320, base=601)
    await _wait_clean_afe0_packet(dut, expected_jesd_restart)
    dut._log.info("STIMULUS_MARKER reset_domains_whole_fifo_and_relink_pass")


async def _link_drop_discards_incomplete_block(dut):
    """A public JESD reset must discard, never splice, a partial AC9810 block."""
    await _setup(dut)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    await _axi_write(dut, 0x0000, 0x00000001, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

    # Reach the first pure-ADC payload position, then present half a CML block.
    # No complete FIFO beat exists when the public link reset interrupts it.
    pre_lane0_sentinel = 0x1357
    pre_lane1_sentinel = 0x2468
    post_lane0_sentinel = 0x0155
    post_lane1_sentinel = 0x00AA
    dut._log.info(
        "STIMULUS_MARKER link_drop_sentinels pre_lane0=0x%04x pre_lane1=0x%04x "
        "post_lane0=0x%04x post_lane1=0x%04x",
        pre_lane0_sentinel, pre_lane1_sentinel,
        post_lane0_sentinel, post_lane1_sentinel)
    await _drive_afe0_raw_word_stream(
        dut, [pre_lane0_sentinel] * 32 + [0x0000] * 96,
        [pre_lane1_sentinel] * 32 + [0x0000] * 96)
    poison0 = _ac9810_cml_words(0x4001)
    poison1 = _ac9810_cml_words(0x5001)
    for pair in range(4):
        await _drive_afe0_jesd_beat(
            dut, _pack_two_words(poison0[pair * 2:pair * 2 + 2]),
            _pack_two_words(poison1[pair * 2:pair * 2 + 2]))
    assert int(dut.m_axis_afe0_tvalid.value) == 0, "partial source block fabricated AXIS data"

    # TVALID=0 does not prove the FIFO is empty because packet admission waits
    # for 256 resident beats.  Use only the public ADC_STA0 FIFO_EMPTY[0] bit.
    for _ in range(12):
        await RisingEdge(dut.sys_clk)
    pre_drop_status = await _axi_read(dut, 0x000C)
    dut._log.info(
        "STIMULUS_MARKER link_drop_pre_reset_fifo_status ADC_STA0=0x%08x",
        pre_drop_status)
    assert pre_drop_status & (1 << 8), (
        "PRE_RESET_PREFIX_COMMITTED: AFE0 FIFO_EMPTY=0 before link drop; "
        "the stimulus reached a complete FIFO beat and cannot isolate partial-block discard"
    )

    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.jesd_rst_n.value = 0xFF
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_raw_word_stream(
        dut, [post_lane0_sentinel] * 32 + [0x0000] * 96,
        [post_lane1_sentinel] * 32 + [0x0000] * 96)
    expected = await _drive_afe0_ac9810_pure_adc_epoch(dut, block_count=300)
    await _wait_afe0_header_and_payload(
        dut, (expected,), 0, 10, 0,
        mismatch_signatures={
            "PRE_RESET_STALE_SENTINEL": _repeated_lane_sentinel_beat(
                pre_lane0_sentinel, pre_lane1_sentinel),
            "POST_RESET_PREFIX_MISCLASSIFIED": _repeated_lane_sentinel_beat(
                post_lane0_sentinel, post_lane1_sentinel),
        })
    assert await _axi_read(dut, 0x0000) & 0xCE000000 == 0, (
        "static ADC configuration changed while the channel was active"
    )
    assert await _axi_read(dut, 0x0008) == 0, (
        "static FRAME_CFG changed while the channel was active"
    )
    dut._log.info("STIMULUS_MARKER link_drop_incomplete_block_discard_pass")


class RegionScoreboard:
    """Independent v1.32 beat-region model; it never models retired slices."""

    @staticmethod
    def configuration(mode, dec_m, dec_del_mode):
        assert mode in (0, 1, 2)
        assert dec_del_mode in (0, 1, 2)
        if mode == 0:
            return 16, ((16, "valid"),)
        n, frac = dec_m >> 2, dec_m & 3
        assert (mode == 1 and 1 <= n <= 63) or (mode == 2 and 2 <= n <= 63)
        prefix = (2 * n + 23, 8 * n + 25, 4 * n + 25, 8 * n + 29)[frac]
        prefix += (0, 4 * dec_m, 8 * dec_m)[dec_del_mode]
        if mode == 1:
            valid = (2, 8, 4, 8)[frac]
            zero = (2 * n - 2, 8 * n - 6, 4 * n - 2, 8 * n - 2)[frac]
        else:
            valid = (4, 16, 16, 16)[frac]
            zero = (2 * n - 4, 8 * n - 14, 4 * n - 6, 8 * n - 10)[frac]
        assert valid > 0 and valid % 2 == 0 and zero >= 0
        return prefix, ((valid, "valid"),) if zero == 0 else ((valid, "valid"), (zero, "zero"))

    @classmethod
    def candidate_terminals(cls, mode, dec_m, dec_del_mode, count):
        prefix, regions = cls.configuration(mode, dec_m, dec_del_mode)
        position, terminals = 0, []
        while len(terminals) < count:
            for beats, kind in regions:
                if kind == "valid":
                    # A complete candidate contains two adjacent 128-bit beats.
                    terminals.extend(position + 16 * item + 15 for item in range(beats // 2))
                position += 8 * beats
                if len(terminals) >= count:
                    break
        return prefix, terminals[:count], position


def _assert_region_reference_all_legal():
    """Exhaust every legal dec/ddc N,f,d formula and corrected f2 endpoints."""
    legal, max_prefix, max_zero = 0, 0, 0
    for mode, first_n in ((1, 1), (2, 2)):
        for n in range(first_n, 64):
            for frac in range(4):
                for delay in range(3):
                    dec_m = (n << 2) | frac
                    prefix, regions = RegionScoreboard.configuration(mode, dec_m, delay)
                    legal += 1
                    max_prefix = max(max_prefix, prefix)
                    valid = next(beats for beats, kind in regions if kind == "valid")
                    zero = next((beats for beats, kind in regions if kind == "zero"), 0)
                    assert valid % 2 == 0 and zero >= 0
                    terminals_prefix, terminals, _ = RegionScoreboard.candidate_terminals(
                        mode, dec_m, delay, 32)
                    assert terminals_prefix == prefix
                    assert terminals == sorted(terminals) and len(set(terminals)) == len(terminals)
                    assert all((right - left) >= 16 for left, right in zip(terminals, terminals[1:]))
                    max_zero = max(max_zero, zero)
                    if mode == 1 and frac == 2:
                        # Valid [0..31], zero [32..32N+15], then valid [32N+16..].
                        _, f2_terms, _ = RegionScoreboard.candidate_terminals(mode, dec_m, delay, 4)
                        assert f2_terms[:2] == [15, 31]
                        assert f2_terms[2:] == [32 * n + 31, 32 * n + 47]
                    if (mode, n, frac) in ((1, 1, 0), (2, 2, 0)):
                        assert zero == 0, "zero-bypass must not create a phantom ZERO region"
    assert legal == 1500 and max_prefix == 2573 and max_zero == 502


async def _drive_region_payload(dut, mode, dec_m, delay, candidates=256,
                                diagnostic_prefix_tags=False):
    """Drive monotonic nonzero source words; the model selects only valid regions."""
    prefix, terminals, total_words = RegionScoreboard.candidate_terminals(
        mode, dec_m, delay, candidates)
    if diagnostic_prefix_tags:
        # One nonzero tag per AFE beat, replicated over its eight lane words.
        # These exact prefix beats remain deliberately discarded by the DUT.
        prefix0 = [0x1000 + beat for beat in range(prefix) for _ in range(8)]
        prefix1 = [0x2000 + beat for beat in range(prefix) for _ in range(8)]
    else:
        prefix0, prefix1 = [0x3A5A] * (prefix * 8), [0x15A5] * (prefix * 8)
    await _drive_afe0_raw_word_stream(dut, prefix0, prefix1)
    lane0 = [_scheduler_lane_word(0, position) for position in range(total_words)]
    lane1 = [_scheduler_lane_word(1, position) for position in range(total_words)]
    await _drive_afe0_raw_word_stream(dut, lane0, lane1)
    return [_scheduler_expected_payload(terminal) for terminal in terminals]


async def _region_coordinate_trace(dut, label, attempts=4096):
    """Post-UDLY AFE trace around raw SOMF; no DUT signal is driven."""
    rxd = _rxd0(dut)
    upk = _upk0(dut)
    history, saw_somf, after_somf, cycle = [], False, 0, 0
    valid_cycle, write_count, first_fifo_lsw = None, 0, "none"
    reason = "timeout"
    dut._log.info("REGION_COORD %s monitor_start POST_EDGE sampling", label)
    try:
        for _ in range(attempts):
            await RisingEdge(dut.afe_clk)
            await Timer(2, unit="ns")
            await ReadOnly()
            cycle += 1
            somf = _diag_int(rxd.rxd_somf)
            fsm = _diag_int(upk.rxd_fsm)
            record = (
                f"cycle={cycle} tuple_live={_diag_scalar(rxd.link_ready_afe)} "
                f"tuple_somf={_diag_hex(rxd.rxd_somf)} "
                f"tuple_lsw={_diag_hex(rxd.rxd_data)} "
                f"fsm={_diag_scalar(upk.rxd_fsm)} prefix={_diag_scalar(upk.prefix_cnt)} "
                f"region={_diag_scalar(upk.region_cnt)} commit={_diag_scalar(upk.ddc_wr_sel)} "
                f"buffer_upd={_diag_scalar(upk.rxd_buff_upd)} "
                f"data_upd={_diag_scalar(upk.rxd_data_upd)} "
                f"fifo_valid={_diag_scalar(upk.fifo_wr_valid)} "
                f"fifo_lsw={_diag_hex(upk.fifo_wr_data)}")
            if not saw_somf:
                history.append(record)
                history = history[-4:]
            if somf is not None and (somf & 1):
                saw_somf = True
                for prior in history[:-1]:
                    dut._log.info("REGION_COORD %s POST_EDGE PRE %s", label, prior)
            if saw_somf:
                dut._log.info("REGION_COORD %s POST_EDGE %s", label, record)
                after_somf += 1
                if _diag_int(upk.fifo_wr_valid) == 1:
                    write_count += 1
                    if write_count == 1:
                        first_fifo_lsw = _diag_hex(upk.fifo_wr_data)
                    if write_count <= 2:
                        dut._log.info(
                            "REGION_COORD %s POST_EDGE fifo_write=%d pair=%s data_upd=%s fifo_lsw=%s",
                            label, write_count, _diag_scalar(upk.ddc_wr_sel),
                            _diag_scalar(upk.rxd_data_upd),
                            _diag_hex(upk.fifo_wr_data))
                if fsm == 2 and valid_cycle is None:
                    valid_cycle = cycle
                if valid_cycle is not None and cycle >= valid_cycle + 6:
                    reason = "six_edges_after_fsm_valid"
                    return
    finally:
        dut._log.info(
            "REGION_COORD %s summary reason=%s cycle=%d saw_somf=%d post_somf=%d "
            "write_count=%d first_fifo_lsw=%s",
            label, reason, cycle, saw_somf, after_somf, write_count, first_fifo_lsw)


async def _unpack_schedule_matrix(dut):
    """Public v1.32 dec/ddc packet scoreboard representatives, not a slice probe."""
    _assert_region_reference_all_legal()
    await _setup(dut)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    representatives = (
        ("dec_f0_n1_d0_bypass", 1, 1, 0, 0),
        ("dec_f1_n2_d1", 1, 2, 1, 1),
        ("dec_f2_n1_d2", 1, 1, 2, 2),
        ("dec_f2_n63_d0", 1, 63, 2, 0),
        ("dec_f3_n2_d2", 1, 2, 3, 2),
        ("ddc_f0_n2_d0_bypass", 2, 2, 0, 0),
        ("ddc_f1_n2_d1", 2, 2, 1, 1),
        ("ddc_f2_n2_d2", 2, 2, 2, 2),
        ("ddc_f3_n63_d0", 2, 63, 3, 0),
    )
    for label, mode, n, frac, delay in representatives:
        # Keep the public packet parked from reset/relink through the header
        # observation.  _wait_afe0_complete_packet alone releases it.
        dut.m_axis_afe0_tready.value = 0
        await _axi_write(dut, 0x0000, 0, 0xF)
        await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=320)
        await _fifo_clear_cycle_protocol(dut)
        dut.jesd_rst_n.value = 0xFE
        for _ in range(16):
            await _drive_afe0_jesd_beat(dut, [0] * 4, [0] * 4)
        dut.jesd_rst_n.value = 0xFF
        dec_m = (n << 2) | frac
        frame_cfg, adc_ctl = (delay << 8) | dec_m, 0x80000000 | (mode << 26)
        await _axi_write(dut, 0x0008, frame_cfg, 0xF)
        await _axi_write(dut, 0x0000, adc_ctl | 1, 0xF)
        for _ in range(2100):
            await _drive_afe0_jesd_beat(dut, [0] * 4, [0] * 4)
        await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
        _, regions = RegionScoreboard.configuration(mode, dec_m, delay)
        zero_monitor = None
        if any(kind == "zero" for _, kind in regions):
            zero_monitor = cocotb.start_soon(_rxd_monitor(
                dut, label + " RXD_ZERO", lambda c: c[0] == 3 and c[3] == 0,
                attempts=4096))
        coordinate_monitor = None
        if label == "dec_f0_n1_d0_bypass":
            coordinate_monitor = cocotb.start_soon(_region_coordinate_trace(dut, label))
        try:
            expected = await _drive_region_payload(
                dut, mode, dec_m, delay,
                diagnostic_prefix_tags=(label == "dec_f0_n1_d0_bypass"))
            if zero_monitor is not None:
                zero_context = await with_timeout(zero_monitor, 2, "ms")
                assert zero_context[2] < 503 and zero_context[3] == 0
            if coordinate_monitor is not None:
                await with_timeout(coordinate_monitor, 2, "ms")
        finally:
            if zero_monitor is not None and not zero_monitor.done():
                zero_monitor.kill()
            if coordinate_monitor is not None and not coordinate_monitor.done():
                coordinate_monitor.kill()
        await _wait_afe0_complete_packet(dut, expected, mode, 14, dec_m)
        dut._log.info("STIMULUS_MARKER region_%s_pass", label)


@cocotb.test()
async def reset_and_top_level_defaults(dut):
    await with_timeout(_reset_and_top_level_defaults(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def dec_ddc_region_v132_legal_matrix(dut):
    await with_timeout(_unpack_schedule_matrix(dut), 30, "ms")


@cocotb.test()
async def pure_adc_fixed_prefix(dut):
    await with_timeout(_pure_adc_fixed_prefix(dut), 500, "us")


@cocotb.test()
async def static_cfg_non_idle_only_gate(dut):
    await with_timeout(_static_cfg_non_idle_only_gate(dut), 500, "us")


@cocotb.test()
async def axi_register_contract_and_modes(dut):
    await with_timeout(_register_and_mode_matrix(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def fifo_clear_and_adc_clock_stop(dut):
    await with_timeout(_fifo_clear_and_stopped_adc_access(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def tgc_sticky_error_and_inactive_backpressure(dut):
    await with_timeout(_tgc_error_and_backpressure(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def axi_read_response_backpressure_and_reset_ready_low(dut):
    await with_timeout(_axi_read_backpressure_and_reset_ready_low(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def public_phy_cgs_ilas_packet_header_and_axis(dut):
    await with_timeout(_public_phy_cgs_ilas_and_packet_header(dut), 100, "us")


@cocotb.test()
async def decimation12_end_to_end_scoreboard_and_empty_fifo_guard(dut):
    await with_timeout(_decimation_data_scoreboard_and_empty_guard(dut), 500, "us")


@cocotb.test()
async def ddc14_end_to_end_scoreboard(dut):
    await with_timeout(_ddc_data_scoreboard(dut), 500, "us")


@cocotb.test()
async def normalized_format10_left_aligned_scoreboard(dut):
    await with_timeout(_normalized_format_pure_scoreboard(dut, 10, 1, 11), 500, "us")


@cocotb.test()
async def normalized_format12_right_aligned_scoreboard(dut):
    await with_timeout(_normalized_format_pure_scoreboard(dut, 12, 0, 13), 500, "us")


@cocotb.test()
async def normalized_format14_left_aligned_scoreboard(dut):
    await with_timeout(_normalized_format_pure_scoreboard(dut, 14, 1, 17), 500, "us")


@cocotb.test()
async def fixed_somf_alignment_and_legal_zero_payload(dut):
    await with_timeout(_fixed_somf_alignment_and_zero_payload(dut), 500, "us")


@cocotb.test()
async def ddc_cancellation_dirty_fifo_clear_recovery(dut):
    await with_timeout(_ddc_v132_cancel_and_recovery(dut), 600, "us")


@cocotb.test()
async def reset_domains_whole_fifo_and_relink(dut):
    await with_timeout(_reset_domain_whole_fifo_and_relink(dut), 500, "us")


@cocotb.test()
async def link_drop_incomplete_block_discard(dut):
    await with_timeout(_link_drop_discards_incomplete_block(dut), 300, "us")


@cocotb.test()
async def rxd_region_state_directed_recovery(dut):
    await with_timeout(_rxd_v132_directed_recovery(dut), 2, "ms")


async def _rxd_v132_directed_recovery(dut):
    """Contract-permitted hierarchy audit of payload-hit capture and clear separation.

    The public scoreboards remain primary. This directed check observes only
    state/actions explicitly named by the finalized contract.
    """
    await _setup(dut)
    channel = _chn0(dut)
    rxd = _rxd0(dut)
    upk = _upk0(dut)
    _assert_upk_contract_shape(upk)
    for forbidden in ("rxd_pair_phase", "ddc_iq_phase", "ddc_i_accepted_r",
                      "ddc_abort_afe", "rxd_buff_vld", "data_cnt"):
        assert getattr(upk, forbidden, None) is None, f"retired state present: {forbidden}"
    assert _upk_context(upk) == (0, 0, 0, 0)

    marker_monitor = cocotb.start_soon(_rxd_preedge_marker_monitor(dut, "IDLE->PREF"))
    try:
        await _rxd_start_epoch_source(dut)
        marker_pre, marker_post = await with_timeout(marker_monitor, 100, "us")
    finally:
        if not marker_monitor.done():
            marker_monitor.kill()
    assert marker_pre[1] == 1 and (marker_pre[2] & 1) == 1
    assert marker_pre[4][:2] == (0, 0)
    assert marker_post[:2] == (1, 0)

    await _rxd_observe(dut, "PREF->VALID", lambda c: c[0] == 2,
                       _rxd_drive_afe_beats(dut, 16))
    first_half = (int(upk.rxd_buff0.value), int(upk.rxd_buff1.value))
    assert first_half != (0, 0), "payload hit did not capture the first valid payload beat"
    await _rxd_drive_afe_beat(dut)
    await Timer(2, unit="ns")
    await ReadOnly()
    assert int(upk.fifo_wr_valid.value) == 1, "following ADC/dec payload beat did not register a request"
    request_sampler = cocotb.start_soon(_rxd_sample_fifo_request_once(dut))
    try:
        await _rxd_drive_afe_beat(dut)
        await with_timeout(request_sampler, 100, "us")
    finally:
        if not request_sampler.done():
            request_sampler.kill()

    await _rxd_fifo_clear_source(dut)
    assert int(rxd.link_ready_afe.value) == 1, "FIFO_CLR release did not preserve live RXD tuple"
    await _rxd_rx_reset_done_source(dut, 0)
    await _rxd_monitor(dut, "upk_vld cancellation", lambda c: c == (0, 0, 0, 0), attempts=64)
    assert int(upk.rxd_buff0.value) == 0 and int(upk.rxd_buff1.value) == 0
    assert int(upk.ddc_i_buff.value) == 0 and int(upk.ddc_q_buff.value) == 0


async def _ddc_v132_cancel_and_recovery(dut):
    """Cancel a completed I with dirty FIFO data, then perform software recovery."""
    await _setup(dut)
    channel = _chn0(dut)
    upk = _upk0(dut)
    for forbidden in ("ddc_abort_afe", "ddc_i_accepted_r", "ddc_iq_phase"):
        assert getattr(upk, forbidden, None) is None, f"retired DDC state present: {forbidden}"
    adc_ctl = 0x88000001
    i_channels, _ = _normalized_sample_pattern(14, 0, phase=7)
    q_channels, _ = _normalized_sample_pattern(14, 0, phase=47)
    next_i_channels, _ = _normalized_sample_pattern(14, 0, phase=23)
    await _axi_write(dut, 0x0008, 0x20, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

    # E=32,N=8,f=0,d=0 has a 39-beat prefix. Commit one complete I/Q pair,
    # then complete the following I only. This leaves two dirty FIFO entries
    # and a live incomplete source pair when link_ready_afe is withdrawn.
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)

    # Layer-A deterministic free=1 boundary. The contract explicitly exposes
    # fifo_wlevel as the Q-completion admission input; force only that input,
    # never FIFO storage or output data. Public scoreboards remain primary.
    free1_coverage = {"drop_count": 0, "admit_levels": set(), "drop_levels": set()}
    free1_monitor = cocotb.start_soon(_monitor_ddc_pair_decisions(dut, free1_coverage))
    upk.fifo_wlevel.value = Force(1)
    try:
        await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=2)
        for _ in range(64):
            await RisingEdge(dut.afe_clk)
            await ReadOnly()
            if free1_coverage["drop_count"]:
                break
        assert free1_coverage["drop_levels"] == {1}, (
            f"forced free=1 did not drop exactly at the pair boundary: {free1_coverage}")
        assert free1_coverage["drop_count"] == 1, (
            f"one rejected free=1 pair produced {free1_coverage['drop_count']} events")
    finally:
        if not free1_monitor.done():
            free1_monitor.kill()
        # The loop may exit in ReadOnly.  Release at the following falling
        # edge, before any further AFE owner edge can sample fifo_wlevel.
        await FallingEdge(dut.afe_clk)
        upk.fifo_wlevel.value = Release()
    await Timer(1, unit="ns")
    await ReadOnly()
    assert int(channel.fifo_wr_level.value) == 512, (
        "free=1 rejected pair changed physical FIFO storage")
    await _axi_write(dut, 0x0010, 1 << 8, 0xF)
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=160)

    # Re-align after the AXI W1C/poll interval, during which the AFE region
    # schedule continues.  N=8,f=0 is VALID4 + ZERO12.  From ZERO cnt11 the
    # sole source driver continuously supplies I2 + Q2 + ZERO12 + next-I2
    # AFE beats (72 JESD beats) without an extra AFE owner edge.
    # Pre-arm an edge-accurate tuple-to-UPK trace.  Its verdict is derived
    # from the RXD tuple actually arriving at cnt0/cnt1, not from an assumed
    # fixed latency between the public JESD write and ADC_UPK.
    i_buffer_monitor = cocotb.start_soon(_trace_ddc_complete_i_from_tuple(
        dut, attempts=4096))
    try:
        await with_timeout(_wait_ddc_zero_terminal(dut), 100, "us")
        # The alignment monitor returns in ReadOnly.  Enter the next JESD
        # falling-edge write phase without consuming another AFE owner edge.
        await _jesd_bus_bit0_falling(dut)
        await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=2)
        await _drive_afe0_channel_blocks(dut, [0] * 32, block_count=6)
        await _drive_afe0_channel_blocks(dut, next_i_channels, block_count=1)
        observed_recovery_i = await with_timeout(i_buffer_monitor, 500, "us")
    finally:
        if not i_buffer_monitor.done():
            i_buffer_monitor.kill()
    assert observed_recovery_i != 0 and int(upk.ddc_i_buff.value) == observed_recovery_i, (
        "DDC cancellation setup lacks the traced complete I")
    assert int(upk.ddc_wr_sel.value) == 0, "DDC cancellation setup still has Q commit pending"
    assert int(channel.fifo_wr_level.value) <= 510, "DDC dirty-FIFO setup did not commit I/Q"
    assert (await _axi_read(dut, 0x0010)) & (1 << 8) == 0, (
        "DDC cancellation setup unexpectedly reported a capacity drop")

    await _rxd_cancel_at_effective_upk_loss(dut)
    assert int(upk.ddc_i_buff.value) == 0 and int(upk.ddc_q_buff.value) == 0
    assert int(upk.ddc_wr_sel.value) == 0 and int(upk.fifo_wr_valid.value) == 0
    assert (await _axi_read(dut, 0x0010)) & (1 << 8) == 0, (
        "upk_vld cancellation incorrectly raised DATA_DROP_PD")

    # Software observes LINK_READY low, disables the channel, clears only the
    # physical FIFO, then explicitly rebuilds a fresh link epoch.
    await _poll_register(dut, 0x000C, 1 << 0, 0, attempts=240)
    await _axi_write(dut, 0x0000, 0x88000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    await _fifo_clear_cycle_protocol(dut)
    assert int(channel.fifo_wr_level.value) == 512, (
        "FIFO_CLR did not remove dirty data after cancellation")
    dut.jesd_rst_n.value = 0xFE
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.afe0_rx_reset_done.value = 1
    dut.jesd_rst_n.value = 0xFF
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    marker_monitor = cocotb.start_soon(_rxd_preedge_marker_monitor(dut, "DDC relink"))
    try:
        await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
        marker_pre, marker_post = await with_timeout(marker_monitor, 100, "us")
    finally:
        if not marker_monitor.done():
            marker_monitor.kill()
    assert marker_pre[1] == 1 and marker_post[0] == 1, (
        "disable/FIFO_CLR/relink did not establish a fresh DDC epoch")
    dut._log.info("STIMULUS_MARKER ddc_v132_cancel_dirty_fifo_clear_relink_pass")
