"""Public-interface cocotb sanity suite for ADC_TOP.

The Vivado JESD204 PHY remains the external model boundary.  These tests use
only ADC_TOP ports and cover the software-visible register/CDC/FIFO/TGC
contracts without reaching into private implementation signals.
"""

import cocotb
from cocotb.clock import Clock
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

    The repeated nonzero pattern also occupies positions discarded as sync and
    padding.  This proves removal is position-based and makes every complete
    accepted CML1/CML5 block independent of legal elastic-buffer phase.
    """
    lane0 = _ac9810_cml_words(base)
    lane1 = _ac9810_cml_words(base + 16)
    # This helper exercises the frozen pure-ADC default: 10-bit samples in
    # right-aligned 16-bit PHY containers. Keep the driven containers raw, but
    # model the DUT's independent signed 10-to-16-bit output conversion.
    expected_words = [_sign_extend(word, 10) for word in range(base, base + 32)]
    expected_beat = sum(word << (16 * index) for index, word in enumerate(expected_words))
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


def _packed_sample_pattern(width, left_aligned, phase):
    """Create a signed, channel-distinct public AC9810 pattern and its model."""
    limit = 1 << (width - 1)
    samples = [(-limit + phase * 97 + index * 3) & ((1 << width) - 1)
               for index in range(32)]
    containers = [sample << (16 - width) if left_aligned else sample for sample in samples]
    expected = sum(_sign_extend(sample, width) << (16 * index)
                   for index, sample in enumerate(samples))
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


def _scheduler_lane_word(lane, position):
    """Deterministic positive 14-bit container for one payload lane position."""
    return (1 + lane * 0x0800 + position * 37 + (position >> 4) * 19) & 0x1FFF


def _scheduler_expected_payload(terminal):
    """Map the 16 lane words ending at terminal into one public 512-bit beat."""
    order = (0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15)
    lane0 = [_scheduler_lane_word(0, terminal - 15 + index) for index in range(16)]
    lane1 = [_scheduler_lane_word(1, terminal - 15 + index) for index in range(16)]
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
    """Cycle/status based FIFO_CLR protocol; no wall-clock hold is assumed."""
    await _axi_write(dut, 0x0000, (selected_mask & 0xFF) << 8, 0xF)
    await _poll_register(dut, 0x000C, (selected_mask & 0xFF) << 8,
                         (selected_mask & 0xFF) << 8, attempts=160)
    # Both reset-owning clocks remain active. Hold a bounded number of cycles
    # only to exercise the selected implementation reset requirement.
    for _ in range(8):
        await RisingEdge(dut.afe_clk)
    for _ in range(8):
        await RisingEdge(dut.adc_clk)
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _assert_fifo_empty_stable(dut, tuple(channel for channel in range(8)
                                                if selected_mask & (1 << channel)))


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


class UnpackScheduleScoreboard:
    """Independent v1.9 E={N,f} positive-coordinate schedule model."""

    @staticmethod
    def configuration(mode, dec_m, dec_del_mode):
        assert mode in (0, 1, 2), f"unsupported formal sample mode {mode}"
        if mode == 0:
            return 16, 15, (16,), ("R",)

        n = dec_m >> 2
        frac = dec_m & 0x3
        assert dec_del_mode in (0, 1, 2), f"software contract delay={dec_del_mode}"
        assert ((mode == 1 and 1 <= n <= 63) or
                (mode == 2 and 2 <= n <= 63)), (
            f"software contract mode={mode} N={n}")
        prefix_extra = (0, 4 * dec_m, 8 * dec_m)[dec_del_mode]
        if frac == 0:
            start_beat = 2 * n + 23 + prefix_extra
            gaps = (16, 16 * n - 16) if mode == 2 else (16 * n, 16 * n)
            phases = ("I", "Q") if mode == 2 else ("R",)
        elif frac == 1:
            start_beat = 8 * n + 25 + prefix_extra
            gaps = ((16,) * 7 + (64 * n - 96,)) if mode == 2 else (16, 16, 16, 64 * n - 32)
            phases = ("I", "Q") * 4 if mode == 2 else ("R",)
        elif frac == 2:
            start_beat = 4 * n + 25 + prefix_extra
            gaps = ((16,) * 7 + (32 * n - 32,)) if mode == 2 else (16, 32 * n + 1, 16, 32 * n + 1)
            phases = ("I", "Q") * 4 if mode == 2 else ("R",)
        else:
            start_beat = 8 * n + 29 + prefix_extra
            gaps = ((16,) * 7 + (64 * n - 64,)) if mode == 2 else (16, 16, 16, 64 * n)
            phases = ("I", "Q") * 4 if mode == 2 else ("R",)

        assert 0 < start_beat <= 2573
        assert all(gap >= 16 for gap in gaps), f"illegal multi-block beat gap: {gaps}"
        return start_beat, 15, gaps, phases

    @staticmethod
    def terminals(first_term, gaps, count):
        term = first_term
        values = []
        for index in range(count):
            values.append(term)
            term += gaps[index % len(gaps)]
        return values


def _assert_unpack_schedule_reference_vectors():
    """Cross-check v1.9 supported branches against independent absolute vectors."""
    vectors = (
        (0,  0, 0,  16, (16,),                 ("R",),
         (15, 31, 47, 63, 79, 95, 111, 127, 143)),
        (1,  4, 0,  25, (16, 16),               ("R",),
         (15, 31, 47, 63, 79, 95, 111, 127, 143)),
        (1,  5, 0,  33, (16, 16, 16, 32),       ("R",),
         (15, 31, 47, 63, 95, 111, 127, 143, 175)),
        (1,  6, 1,  53, (16, 33, 16, 33),       ("R",),
         (15, 31, 64, 80, 113, 129, 162, 178,
          211, 227, 260, 276, 309, 325, 358, 374)),
        (1,  7, 2,  93, (16, 16, 16, 64),       ("R",),
         (15, 31, 47, 63, 127, 143, 159, 175, 239)),
        (1, 252, 0, 149, (1008, 1008),          ("R",),
         (15, 1023, 2031, 3039, 4047)),
        (2,  8, 1,  59, (16, 16),               ("I", "Q"),
         (15, 31, 47, 63, 79, 95, 111, 127, 143)),
        (2,  9, 2, 113, (16, 16, 16, 16, 16, 16, 16, 32),
         ("I", "Q", "I", "Q", "I", "Q", "I", "Q"),
         (15, 31, 47, 63, 79, 95, 111, 127, 159)),
        (2, 10, 0,  33, (16, 16, 16, 16, 16, 16, 16, 32),
         ("I", "Q", "I", "Q", "I", "Q", "I", "Q"),
         (15, 31, 47, 63, 79, 95, 111, 127, 159)),
        (2, 11, 1,  89, (16, 16, 16, 16, 16, 16, 16, 64),
         ("I", "Q", "I", "Q", "I", "Q", "I", "Q"),
         (15, 31, 47, 63, 79, 95, 111, 127, 191)),
    )
    offsets = set()
    for mode, dec_m, delay, exp_start, exp_gaps, exp_phases, exp_terms in vectors:
        start, first, gaps, phases = UnpackScheduleScoreboard.configuration(
            mode, dec_m, delay)
        assert start == exp_start
        assert first == 15
        assert gaps == exp_gaps
        assert phases == exp_phases
        actual_terms = []
        terminal = first
        for index in range(len(exp_terms)):
            actual_terms.append(terminal)
            terminal += gaps[index % len(gaps)]
        assert tuple(actual_terms) == exp_terms
        offsets.update(term & 0x7 for term in exp_terms)
    assert offsets == set(range(8))
    # Maximum-prefix and long-gap width checks remain reference-only so the
    # public DUT matrix does not spend most of its runtime transmitting gaps.
    assert UnpackScheduleScoreboard.configuration(1, 253, 2) == (
        2553, 15, (16, 16, 16, 4000), ("R",))
    assert UnpackScheduleScoreboard.configuration(1, 255, 2) == (
        2573, 15, (16, 16, 16, 4032), ("R",))

    legal_count = 0
    max_prefix = 0
    max_gap = 0
    exhaustive_offsets = set()
    for mode, first_n in ((1, 1), (2, 2)):
        for n in range(first_n, 64):
            for frac in range(4):
                dec_m = (n << 2) | frac
                for delay in range(3):
                    legal_count += 1
                    start, first, gaps, phases = UnpackScheduleScoreboard.configuration(
                        mode, dec_m, delay)
                    prefix_base = (2 * n + 23, 8 * n + 25,
                                   4 * n + 25, 8 * n + 29)[frac]
                    expected_start = prefix_base + (0, 4 * dec_m, 8 * dec_m)[delay]
                    if mode == 1:
                        expected_gaps = (
                            (16 * n, 16 * n),
                            (16, 16, 16, 64 * n - 32),
                            (16, 32 * n + 1, 16, 32 * n + 1),
                            (16, 16, 16, 64 * n),
                        )[frac]
                        expected_phases = ("R",)
                        expected_period = (32 * n, 64 * n + 16,
                                           64 * n + 34, 64 * n + 48)[frac]
                    else:
                        expected_gaps = (
                            (16, 16 * n - 16),
                            (16, 16, 16, 16, 16, 16, 16, 64 * n - 96),
                            (16, 16, 16, 16, 16, 16, 16, 32 * n - 32),
                            (16, 16, 16, 16, 16, 16, 16, 64 * n - 64),
                        )[frac]
                        expected_phases = (("I", "Q") if frac == 0 else
                                           ("I", "Q", "I", "Q",
                                            "I", "Q", "I", "Q"))
                        expected_period = (16 * n, 64 * n + 16,
                                           32 * n + 80, 64 * n + 48)[frac]

                    assert start == expected_start and first == 15
                    assert gaps == expected_gaps and phases == expected_phases
                    assert sum(gaps) == expected_period
                    assert start < (1 << 12) and max(gaps) < (1 << 12)
                    terms = UnpackScheduleScoreboard.terminals(first, gaps, 64)
                    assert all(0 <= term < (1 << 64) for term in terms)
                    exhaustive_offsets.update(term & 0x7 for term in terms)
                    max_prefix = max(max_prefix, start)
                    max_gap = max(max_gap, max(gaps))

    assert legal_count == 1500
    assert max_prefix == 2573 and max_gap == 4032
    assert exhaustive_offsets == set(range(8))
async def _unpack_schedule_matrix(dut):
    """Drive one black-box packet for every v1.9 scheduler equivalence branch."""
    _assert_unpack_schedule_reference_vectors()
    await _setup(dut)
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0

    representatives = (
        ("pure",              0,   0, 0),
        ("single_n1_f0_d0",  1,   4, 0),
        ("single_n1_f1_d0",  1,   5, 0),
        ("single_n1_f2_d1",  1,   6, 1),
        ("single_n1_f3_d2",  1,   7, 2),
        ("single_n63_f3_d2", 1, 255, 2),
        ("ddc_n2_f0_d1",     2,   8, 1),
        ("ddc_n2_f1_d2",     2,   9, 2),
        ("ddc_n2_f2_d0",     2,  10, 0),
        ("ddc_n2_f3_d1",     2,  11, 1),
    )
    end_offsets = set()

    for label, mode, dec_m, dec_del_mode in representatives:
        await _axi_write(dut, 0x0000, 0x00000000, 0xF)
        await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=320)
        await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)

        dut.jesd_rst_n.value = 0xFE
        for _ in range(16):
            await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
        dut.jesd_rst_n.value = 0xFF

        frame_cfg = (dec_del_mode << 8) | dec_m if mode else 0
        adc_ctl = 0x80000000 | (mode << 26)
        _assert_software_static_config(adc_ctl, frame_cfg)
        await _axi_write(dut, 0x0008, frame_cfg, 0xF)
        await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
        for _ in range(2100):
            await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
        await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

        start_beat, first_term, gaps, phases = UnpackScheduleScoreboard.configuration(
            mode, dec_m, dec_del_mode)
        terminals = UnpackScheduleScoreboard.terminals(first_term, gaps, 256)
        assert start_beat >= 0 and all(right > left for left, right in zip(terminals, terminals[1:]))
        if mode == 2:
            assert len(phases) == len(gaps)
            assert all(phases[index] != phases[(index + 1) % len(phases)]
                       for index in range(len(phases)))
        end_offsets.update(term & 0x7 for term in terminals)

        prefix_words = start_beat * 8
        await _drive_afe0_raw_word_stream(
            dut, [0x3A5A] * prefix_words, [0x15A5] * prefix_words)
        await _drive_afe0_scheduler_payload(dut, terminals)
        expected = [_scheduler_expected_payload(term) for term in terminals]
        await _wait_afe0_complete_packet(dut, expected, mode, 14, dec_m)
        await _assert_static_config_stable(dut, adc_ctl | 0x1, frame_cfg)
        dut._log.info(
            "STIMULUS_MARKER scheduler_%s_d%d_offsets_%s_pass",
            label, dec_del_mode, sorted({term & 0x7 for term in terminals}))

    assert end_offsets == set(range(8)), (
        f"DUT scheduler representatives did not cover every terminal offset: {end_offsets}"
    )


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
        name = f"m_axis_afe{channel}_tvalid"
        _assert_known(dut, name)
        assert int(_required(dut, name).value) == 0
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
    # SMP_PREC=12, SMP_MODE=decimation, FRAME_FMT=left aligned.  DEC_M=32 is
    # the smallest legal decimation setting and DEC_DEL_MODE=0.
    adc_ctl = 0x46000000
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 1
    _assert_software_static_config(adc_ctl, 0x20)
    await _axi_write(dut, 0x0008, 0x20, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    await _poll_register(dut, 0x000C, 0xFF000000, 0xFF000000, attempts=240)

    channels, expected = _packed_sample_pattern(12, True, phase=1)

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
    # SMP_PREC=14, SMP_MODE=DDC, FRAME_FMT=right aligned, DEC_M=32.
    adc_ctl = 0x88000000
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    i_channels, expected_i = _packed_sample_pattern(14, False, phase=1)
    q_channels, expected_q = _packed_sample_pattern(14, False, phase=41)

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
    # DDC E=32,N=8,f=0,d=0 has ddc_num=2N+23=39 AFE beats = 312 words.
    # Supply that complete physical framing prefix after the first DATA word:
    # 32 synchronizing words followed by 280 zero-padding words per lane.
    # The subsequent I/Q CML stream then begins exactly at the public epoch's
    # first payload word, rather than 24 words into a 32-word DDC period.
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=2400)
    # The stalled sink exhausts the FWFT write capacity.  DDC rejects only at
    # an I decision when fewer than two slots remain; DATA_DROP_PD is the
    # public indication of that whole-pair rejection.  The earliest accepted
    # packets below must remain ordered I/Q, proving no rejected I orphan was
    # inserted ahead of them.
    await _poll_register(dut, 0x0010, 1 << 8, 1 << 8, attempts=400)
    await _wait_afe0_header_and_payload(
        dut, (expected_i, expected_q, expected_i, expected_q), 2, 14, 32)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, 0x20)
    dut._log.info("STIMULUS_MARKER ddc14_iq_pair_scoreboard_pass")


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


async def _ddc_abort_requires_fifo_clear_recovery(dut):
    """Public valid-epoch link loss blocks admission until FIFO_CLR recovery."""
    await _setup(dut)
    adc_ctl = 0x88000000
    frame_cfg = 0x20
    dut.afe0_pll_lock.value = 1
    dut.afe0_rx_reset_done.value = 1
    dut.afe0_byte_aligned.value = 0x3
    dut.m_axis_afe0_tready.value = 0
    i_channels, expected_i = _packed_sample_pattern(14, False, phase=7)
    q_channels, expected_q = _packed_sample_pattern(14, False, phase=47)

    _assert_software_static_config(adc_ctl, frame_cfg)
    await _axi_write(dut, 0x0008, frame_cfg, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=80)
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=4)
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=80)

    # A healthy effective disable ends the epoch without an abort.
    await _axi_write(dut, 0x0000, adc_ctl, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    for _ in range(8):
        await RisingEdge(dut.adc_clk)
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=160)
    await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)

    # Establish a fresh DDC epoch, then remove public PHY reset-done.
    _assert_software_static_config(adc_ctl, frame_cfg)
    await _axi_write(dut, 0x0008, frame_cfg, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=4)
    for _ in range(16):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 0, (
            "DDC packet started before the intentional valid-epoch link loss"
        )
    await FallingEdge(dut.adc_clk)
    dut._log.info("STIMULUS_MARKER ddc_valid_epoch_rx_reset_done_loss")
    dut.afe0_rx_reset_done.value = 0
    await _poll_register(dut, 0x000C, 1 << 0, 0, attempts=240)
    await _poll_register(dut, 0x0010, 1 << 8, 1 << 8, attempts=400)
    for _ in range(16):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    dut.afe0_rx_reset_done.value = 1
    await _axi_write(dut, 0x0010, 1 << 8, 0xF)
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=400)
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)

    # W1C does not clear the abort or reopen packet admission.
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=1200)
    await _poll_register(dut, 0x000C, (1 << 0) | (1 << 8), 1 << 0, attempts=240)
    for _ in range(240):
        await RisingEdge(dut.adc_clk)
        await ReadOnly()
        assert int(dut.m_axis_afe0_tvalid.value) == 0, (
            "DDC abort allowed a new AXIS packet before FIFO_CLR recovery"
        )
    await _poll_register(dut, 0x0010, 1 << 8, 0, attempts=160)

    # Recover through disable, idle, FIFO clear, and a clean relink.
    await _axi_write(dut, 0x0000, 0x00000000, 0xF)
    await _poll_register(dut, 0x000C, 1 << 24, 1 << 24, attempts=240)
    await _fifo_clear_cycle_protocol(dut, selected_mask=0x01)

    _assert_software_static_config(adc_ctl, frame_cfg)
    await _axi_write(dut, 0x0008, frame_cfg, 0xF)
    await _axi_write(dut, 0x0000, adc_ctl | 0x1, 0xF)
    for _ in range(2100):
        await _drive_afe0_jesd_beat(dut, [0, 0, 0, 0], [0, 0, 0, 0])
    await _drive_afe0_documented_cgs_ilas(dut, post_ilas_blocks=0)
    await _drive_afe0_raw_word_stream(
        dut, [0x1357] * 32 + [0x0000] * 280,
        [0x2468] * 32 + [0x0000] * 280)
    await _drive_afe0_iq_channel_blocks(dut, i_channels, q_channels, block_count=1200)
    await _poll_register(dut, 0x000C, (1 << 0) | (1 << 8), 1 << 0, attempts=240)
    await _wait_afe0_header_and_payload(
        dut, (expected_i, expected_q, expected_i, expected_q), 2, 14, 32)
    await _assert_static_config_stable(dut, adc_ctl | 0x1, frame_cfg)
    dut._log.info("STIMULUS_MARKER ddc_abort_fifo_clear_recovery_pass")


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


@cocotb.test()
async def reset_and_top_level_defaults(dut):
    await with_timeout(_reset_and_top_level_defaults(dut), TEST_TIMEOUT_US, "us")


@cocotb.test()
async def unpack_schedule_v19_legal_matrix(dut):
    await with_timeout(_unpack_schedule_matrix(dut), 15, "ms")


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
async def fixed_somf_alignment_and_legal_zero_payload(dut):
    await with_timeout(_fixed_somf_alignment_and_zero_payload(dut), 500, "us")


@cocotb.test()
async def ddc_abort_blocks_admission_until_fifo_clear_recovery(dut):
    await with_timeout(_ddc_abort_requires_fifo_clear_recovery(dut), 600, "us")


@cocotb.test()
async def reset_domains_whole_fifo_and_relink(dut):
    await with_timeout(_reset_domain_whole_fifo_and_relink(dut), 500, "us")


@cocotb.test()
async def link_drop_incomplete_block_discard(dut):
    await with_timeout(_link_drop_discards_incomplete_block(dut), 300, "us")
