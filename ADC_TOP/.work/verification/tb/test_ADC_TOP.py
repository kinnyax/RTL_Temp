"""Executable ADC_TOP v0.2 verification; third-party JESD stays a black box."""

import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.handle import Force, Release
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer, with_timeout

SEED = int(os.environ.get("RTL_TEST_SEED", "20260825"))
TIMEOUT_US = 5000


async def edge(clk):
    """Sample after the RTL's #UDLY=1 update and then enter ReadOnly."""
    await RisingEdge(clk)
    await Timer(2, unit="ns")
    await ReadOnly()


async def setup(dut):
    for name in ("sys_rst_n", "adc_rst_n", "afe_rst_n", "jesd_rst_n", "sysref_in",
                 "s_axi_awaddr", "s_axi_awvalid", "s_axi_wdata", "s_axi_wstrb",
                 "s_axi_wvalid", "s_axi_bready", "s_axi_araddr", "s_axi_arvalid",
                 "s_axi_rready"):
        getattr(dut, name).value = 0
    for channel in range(8):
        for suffix in ("rx_data", "rx_charisk", "rx_disperr", "rx_notintable",
                       "rx_reset_done", "pll_lock", "byte_aligned"):
            getattr(dut, f"afe{channel}_{suffix}").value = 0
        getattr(dut, f"m_axis_afe{channel}_tready").value = 0
    cocotb.start_soon(Clock(dut.sys_clk, 10, unit="ns").start())
    cocotb.start_soon(Clock(dut.adc_clk, 8, unit="ns").start())
    cocotb.start_soon(Clock(dut.afe_clk, 12, unit="ns").start())

    async def jesd_clock_bus(dut=dut):
        while True:
            dut.jesd_clk.value = 0
            await Timer(3, unit="ns")
            dut.jesd_clk.value = 0xFF
            await Timer(3, unit="ns")
    cocotb.start_soon(jesd_clock_bus())
    for _ in range(4):
        await RisingEdge(dut.sys_clk)
    dut.sys_rst_n.value = 1
    dut.adc_rst_n.value = 1
    dut.afe_rst_n.value = 1
    dut.jesd_rst_n.value = 0xFF
    for _ in range(8):
        await edge(dut.sys_clk)


async def axi_write(dut, address, data, strobe=0xF, order="together", stall=0):
    dut.s_axi_bready.value = 0

    async def address_phase(dut=dut, address=address):
        await FallingEdge(dut.sys_clk)
        assert int(dut.s_axi_awready.value)
        dut.s_axi_awaddr.value = address
        dut.s_axi_awvalid.value = 1
        await RisingEdge(dut.sys_clk)
        await FallingEdge(dut.sys_clk)
        dut.s_axi_awvalid.value = 0

    async def data_phase(dut=dut, data=data, strobe=strobe):
        await FallingEdge(dut.sys_clk)
        assert int(dut.s_axi_wready.value)
        dut.s_axi_wdata.value = data
        dut.s_axi_wstrb.value = strobe
        dut.s_axi_wvalid.value = 1
        await RisingEdge(dut.sys_clk)
        await FallingEdge(dut.sys_clk)
        dut.s_axi_wvalid.value = 0

    if order == "aw_first":
        await address_phase(); await data_phase()
    elif order == "w_first":
        await data_phase(); await address_phase()
    else:
        await FallingEdge(dut.sys_clk)
        assert int(dut.s_axi_awready.value) and int(dut.s_axi_wready.value)
        dut.s_axi_awaddr.value = address
        dut.s_axi_wdata.value = data
        dut.s_axi_wstrb.value = strobe
        dut.s_axi_awvalid.value = 1
        dut.s_axi_wvalid.value = 1
        await RisingEdge(dut.sys_clk)
        await FallingEdge(dut.sys_clk)
        dut.s_axi_awvalid.value = 0
        dut.s_axi_wvalid.value = 0
    for _ in range(12):
        await edge(dut.sys_clk)
        if int(dut.s_axi_bvalid.value):
            break
    assert int(dut.s_axi_bvalid.value) and int(dut.s_axi_bresp.value) == 0
    for _ in range(stall):
        await edge(dut.sys_clk)
        assert int(dut.s_axi_bvalid.value) and not int(dut.s_axi_awready.value)
        assert not int(dut.s_axi_wready.value) and int(dut.s_axi_bresp.value) == 0
    await FallingEdge(dut.sys_clk)
    dut.s_axi_bready.value = 1
    await edge(dut.sys_clk)
    assert not int(dut.s_axi_bvalid.value)
    await FallingEdge(dut.sys_clk)
    dut.s_axi_bready.value = 0


async def axi_read(dut, address, stall=0):
    await FallingEdge(dut.sys_clk)
    assert int(dut.s_axi_arready.value)
    dut.s_axi_araddr.value = address
    dut.s_axi_arvalid.value = 1
    dut.s_axi_rready.value = 0
    await RisingEdge(dut.sys_clk)
    await FallingEdge(dut.sys_clk)
    dut.s_axi_arvalid.value = 0
    for _ in range(12):
        await edge(dut.sys_clk)
        if int(dut.s_axi_rvalid.value):
            break
    assert int(dut.s_axi_rvalid.value) and int(dut.s_axi_rresp.value) == 0
    held = int(dut.s_axi_rdata.value)
    for _ in range(stall):
        await edge(dut.sys_clk)
        assert int(dut.s_axi_rvalid.value) and int(dut.s_axi_rdata.value) == held
        assert not int(dut.s_axi_arready.value)
    await FallingEdge(dut.sys_clk)
    dut.s_axi_rready.value = 1
    await edge(dut.sys_clk)
    assert not int(dut.s_axi_rvalid.value)
    await FallingEdge(dut.sys_clk)
    dut.s_axi_rready.value = 0
    return held


def force(signal, value):
    signal.value = Force(value)


def release(signal):
    signal.value = Release()


def pack(words):
    return sum((word & 0xFFFF) << (16 * index) for index, word in enumerate(words))


def interleave(first, second):
    words = []
    for left, right in zip(first, second):
        words.extend((left, right))
    return pack(words)


def format_word(container, precision, left_aligned):
    if left_aligned:
        return container & 0xFFFF
    raw = (container >> (16 - precision)) & ((1 << precision) - 1)
    if raw & (1 << (precision - 1)):
        raw |= 0xFFFF ^ ((1 << precision) - 1)
    return raw


def prefix_beats(mode, dec_m, delete_mode):
    """Excel source: sync16 + zeros + sync16, 8 words/lane/AFE beat."""
    if mode == 0:
        return 16
    n, fraction = dec_m >> 2, dec_m & 3
    base = (2*n + 23, 8*n + 25, 4*n + 25, 8*n + 29)[fraction]
    return base + (0, 4*dec_m, 8*dec_m)[delete_mode]


def regions(mode, dec_m):
    n, fraction = dec_m >> 2, dec_m & 3
    if mode == 1:
        valid = (16, 64, 32, 64)[fraction]
        zero = (16*n-16, 64*n-48, 32*n-16, 64*n-16)[fraction]
    else:
        valid = (32, 128, 128, 128)[fraction]
        zero = (16*n-32, 64*n-112, 32*n-48, 64*n-80)[fraction]
    assert valid % 8 == 0 and zero >= 0 and zero % 8 == 0
    return valid // 8, zero // 8


async def reset_afe(dut):
    dut.afe_rst_n.value = 0
    for _ in range(3): await RisingEdge(dut.afe_clk)
    dut.afe_rst_n.value = 1
    for _ in range(3): await edge(dut.afe_clk)


def upk_handles(dut):
    return dut.adc_chn0, dut.adc_chn0.adc_upk


async def configure_upk(dut, mode, dec_m, delete_mode, precision=2,
                        left_aligned=1, capacity=512):
    channel, _ = upk_handles(dut)
    await reset_afe(dut)
    force(channel.chn_en_afe, 1)
    force(dut.adc_ctl, (precision << 30) | (mode << 26) | (left_aligned << 25) | 1)
    force(dut.frm_cfg, (delete_mode << 8) | dec_m)
    force(channel.rx_fifo_wlevel, capacity)
    force(channel.rxd_data_vld, 1)
    force(channel.rxd_somf, 0)
    force(channel.rxd_data, 0)


async def upk_beat(dut, data, somf=0, valid=1):
    channel, upk = upk_handles(dut)
    await FallingEdge(dut.afe_clk)
    force(channel.rxd_data, data)
    force(channel.rxd_somf, somf)
    force(channel.rxd_data_vld, valid)
    await edge(dut.afe_clk)
    return int(upk.rx_fifo_winc.value), int(upk.rx_fifo_wdat.value), int(upk.data_error_evt.value)


async def prefix(dut, count):
    for index in range(count):
        pulse, _, _ = await upk_beat(dut, pack([0xA000 + index] * 16), index == 0)
        assert not pulse, "prefix leaked into the FIFO"


def crc16(data):
    value = 0xFFFF
    for byte in data:
        value ^= byte << 8
        for _ in range(8):
            value = (((value << 1) ^ 0x1021) if value & 0x8000 else value << 1) & 0xFFFF
    return value


@cocotb.test()
async def reset_axi_backpressure_registers(dut):
    async def body(dut=dut):
        await setup(dut)
        assert await axi_read(dut, 0, 4) == 0
        assert await axi_read(dut, 4) == 0
        assert await axi_read(dut, 0x44) == 0
        await axi_write(dut, 0, 0xFFFFFFFF, 0, "w_first", 4)
        assert await axi_read(dut, 0) == 0xCE00FFFF
        await axi_write(dut, 0, 0)
        for _ in range(20): await edge(dut.sys_clk)
        await axi_write(dut, 4, 0xFFFFFFFF, 0x3, "aw_first")
        assert await axi_read(dut, 4) == 0x3FF
        await axi_write(dut, 0x30, 0xDEADBEEF)
        assert await axi_read(dut, 0x30) == 0
        dut.adc_rst_n.value = 0
        await edge(dut.adc_clk)
        assert all(not int(getattr(dut, f"m_axis_afe{i}_tvalid").value) for i in range(8))
        assert await axi_read(dut, 4) == 0x3FF
        dut.adc_rst_n.value = 1
        dut.afe_rst_n.value = 0
        await edge(dut.afe_clk)
        assert all(not int(getattr(dut, f"tgc{i}_slope").value) for i in range(8))
    await with_timeout(body(), TIMEOUT_US, "us")


@cocotb.test()
async def tgc_success_cancel_run_clear_cdc(dut):
    async def body(dut=dut):
        await setup(dut)
        await axi_write(dut, 0, 3)
        for _ in range(12): await edge(dut.afe_clk)
        await axi_write(dut, 8, 0xF)
        assert await axi_read(dut, 8) == 0xF
        slope = False; pulses = 0
        for _ in range(40):
            await edge(dut.afe_clk)
            slope |= bool(int(dut.tgc0_slope.value))
            pulses += int(dut.adc_chn0.tgc_done_evt.value)
        assert slope and pulses == 1
        for _ in range(20):
            if (await axi_read(dut, 8)) & 1 == 0: break
        assert await axi_read(dut, 8) == 0xE
        force(dut.adc_chn1.chn_en_afe, 0)
        await axi_write(dut, 0xC, 5)
        pulses = 0
        for _ in range(40):
            await edge(dut.afe_clk)
            pulses += int(dut.adc_chn1.tgc_done_evt.value)
        release(dut.adc_chn1.chn_en_afe)
        assert pulses == 1
        for _ in range(20):
            if (await axi_read(dut, 0xC)) & 1 == 0: break
        assert await axi_read(dut, 0xC) == 4
        assert await axi_read(dut, 8) == 0xE
    await with_timeout(body(), TIMEOUT_US, "us")


@cocotb.test()
async def upk_direct_mapping_precision_capacity_validity(dut):
    async def body(dut=dut):
        await setup(dut)
        for code, precision in enumerate((10, 12, 14)):
            for left_aligned in (0, 1):
                await configure_upk(dut, 0, 0, 0, code, left_aligned, 1)
                await prefix(dut, 16)
                logical = []
                for index in range(32):
                    sample = ((index * 37 + 3) & ((1 << (precision-1))-1)) | 1
                    if index & 1: sample |= 1 << (precision-1)
                    logical.append((sample << (16-precision)) & 0xFFFF)
                assert not (await upk_beat(dut, pack(logical[0::2])))[0]
                pulse, data, _ = await upk_beat(dut, pack(logical[1::2]))
                expected = pack(format_word(word, precision, left_aligned) for word in logical)
                assert pulse and data == expected
        await configure_upk(dut, 0, 0, 0, capacity=0)
        await prefix(dut, 16)
        await upk_beat(dut, pack(range(16)))
        assert not (await upk_beat(dut, pack(range(16, 32))))[0]
        await configure_upk(dut, 0, 0, 0)
        await upk_beat(dut, 0, 1)
        first = await upk_beat(dut, 0, valid=0)
        second = await upk_beat(dut, 0, valid=0)
        assert first[2] == 1 and second[2] == 0 and not first[0] and not second[0]
        await prefix(dut, 16)
        assert not (await upk_beat(dut, 0x1234))[0]
        assert (await upk_beat(dut, 0x5678))[0]

        # Valid-half loss must discard that half and require another SOMF.
        await configure_upk(dut, 0, 0, 0)
        await prefix(dut, 16)
        assert not (await upk_beat(dut, pack([0x3333]*16)))[0]
        assert (await upk_beat(dut, 0, valid=0))[2] == 1
        assert not (await upk_beat(dut, pack([0x4444]*16)))[0]
    await with_timeout(body(), TIMEOUT_US, "us")


@cocotb.test()
async def upk_dec_ddc_prefix_regions_delete_atomic_capacity(dut):
    async def body(dut=dut):
        await setup(dut)
        # Exhaustively enumerate the source formulas for all 1500 legal
        # mode/N/f/delete schedules.  The same test then drives every f/delete
        # class and both N endpoints through the RTL below.
        legal = 0
        for reference_mode, first_n in ((1, 1), (2, 2)):
            for reference_n in range(first_n, 64):
                for reference_fraction in range(4):
                    for reference_delete in range(3):
                        reference_dec_m = (reference_n << 2) | reference_fraction
                        assert prefix_beats(reference_mode, reference_dec_m,
                                            reference_delete) > 0
                        reference_valid, reference_zero = regions(reference_mode,
                                                                   reference_dec_m)
                        assert reference_valid > 0 and reference_zero >= 0
                        legal += 1
        assert legal == 1500
        for mode in (1, 2):
            minimum = 1 if mode == 1 else 2
            for fraction in range(4):
                for delete_mode in range(3):
                    n = minimum if (fraction + delete_mode) % 2 == 0 else 63
                    dec_m = (n << 2) | fraction
                    await configure_upk(dut, mode, dec_m, delete_mode)
                    await prefix(dut, prefix_beats(mode, dec_m, delete_mode))
                    valid_count, zero_count = regions(mode, dec_m)
                    writes = 0
                    for beat_index in range(valid_count):
                        pulse, _, _ = await upk_beat(dut, pack([0x1000+beat_index]*16))
                        writes += pulse
                    zero_start = 0
                    if mode == 2:
                        # Q is retained atomically and follows I on the next
                        # AFE edge.  That edge may be the first ZERO beat.
                        pulse, _, _ = await upk_beat(dut, pack([0x6000]*16))
                        writes += pulse
                        zero_start = 1 if zero_count else 0
                    assert writes == valid_count // 2
                    for beat_index in range(zero_start, zero_count):
                        assert not (await upk_beat(dut, pack([0x7000+beat_index]*16)))[0]
                    if zero_count:
                        assert not (await upk_beat(dut, pack([0x1111]*16)))[0]
                        second = await upk_beat(dut, pack([0x2222]*16))
                        assert bool(second[0]) == (mode == 1)
        for capacity in (0, 1, 2, 512):
            dec_m = 2 << 2
            await configure_upk(dut, 2, dec_m, 0, capacity=capacity)
            await prefix(dut, prefix_beats(2, dec_m, 0))
            observed = []
            for tag in (0x1000, 0x2000, 0x3000, 0x4000, 0):
                pulse, data, _ = await upk_beat(dut, pack([tag]*16))
                if pulse: observed.append(data)
            if capacity < 2:
                assert observed == []
            else:
                assert len(observed) == 2
            if capacity >= 2: assert observed[0] != observed[1]

        # Once capacity admits a complete I/Q pair, its pending Q write must
        # drain on the next edge even if disable or validity loss arrives.
        for terminate in ("disable", "invalid"):
            dec_m = 2 << 2
            await configure_upk(dut, 2, dec_m, 0, capacity=2)
            await prefix(dut, prefix_beats(2, dec_m, 0))
            for tag in (0x1000, 0x2000, 0x3000):
                assert not (await upk_beat(dut, pack([tag]*16)))[0]
            i_pulse, i_data, _ = await upk_beat(dut, pack([0x4000]*16))
            channel, upk = upk_handles(dut)
            assert i_pulse and not int(upk.upk_idle.value)
            if terminate == "disable":
                force(channel.chn_en_afe, 0)
                q_pulse, q_data, _ = await upk_beat(dut, 0, valid=0)
            else:
                q_pulse, q_data, error = await upk_beat(dut, 0, valid=0)
                assert error == 1
            assert q_pulse and q_data != i_data and not int(upk.upk_idle.value)
            await upk_beat(dut, 0, valid=0)
            assert int(upk.upk_idle.value)

        # Incomplete DDC-I and ZERO-region validity losses each create one
        # error and never admit a partial candidate.
        dec_m = 2 << 2
        await configure_upk(dut, 2, dec_m, 0)
        await prefix(dut, prefix_beats(2, dec_m, 0))
        await upk_beat(dut, pack([0x1111]*16))
        await upk_beat(dut, pack([0x2222]*16))
        assert (await upk_beat(dut, 0, valid=0))[2] == 1
        await configure_upk(dut, 1, dec_m, 0)
        await prefix(dut, prefix_beats(1, dec_m, 0))
        await upk_beat(dut, pack([0x1111]*16))
        await upk_beat(dut, pack([0x2222]*16))
        await upk_beat(dut, pack([0x7777]*16))
        assert (await upk_beat(dut, 0, valid=0))[2] == 1
    await with_timeout(body(), TIMEOUT_US, "us")


@cocotb.test()
async def fifo_status_event_w1c_clear_recovery(dut):
    async def body(dut=dut):
        await setup(dut)
        channel, upk = upk_handles(dut)
        force(channel.chn_en_afe, 1)
        force(channel.rxd_data_vld, 1); force(channel.rxd_somf, 1)
        await edge(dut.afe_clk)
        force(channel.rxd_somf, 0); force(channel.rxd_data_vld, 0)
        await edge(dut.afe_clk)
        assert int(upk.data_error_evt.value) and int(channel.fifo_sta.value)
        for _ in range(20):
            if (await axi_read(dut, 0x2C)) & 0x100: break
        assert (await axi_read(dut, 0x2C)) & 0x100
        await axi_write(dut, 0x2C, 0x100)
        assert (await axi_read(dut, 0x2C)) & 0x100 == 0
        # Keep a synchronized HW event asserted across W1C commit: HW set wins.
        force(dut.adc_sync.data_error_evt_sys, 1)
        await axi_write(dut, 0x2C, 0x100)
        assert (await axi_read(dut, 0x2C)) & 0x100
        release(dut.adc_sync.data_error_evt_sys)
        await axi_write(dut, 0x2C, 0x100)
        assert (await axi_read(dut, 0x2C)) & 0x100 == 0
        assert int(channel.fifo_sta.value)
        force(dut.adc_ctl, 0x100)
        await edge(dut.afe_clk)
        assert not int(channel.fifo_sta.value)
        release(dut.adc_ctl)
    await with_timeout(body(), TIMEOUT_US, "us")


@cocotb.test()
async def packet_crc_header_payload_backpressure_recovery(dut):
    async def body(dut=dut):
        await setup(dut)
        rng = random.Random(SEED)
        channel = dut.adc_chn0; pkt = channel.adc_pkt
        force(channel.chn_en_adc, 1); force(channel.link_ready_sync, 1)
        force(channel.fifo_sta_sync, 1); force(channel.rx_fifo_empty, 0)
        force(channel.rx_fifo_rlevel, 0); force(channel.rx_fifo_rdat, 0xABC)
        force(dut.adc_ctl, (1 << 30) | (2 << 26) | 1); force(dut.frm_cfg, 0x2A)
        dut.m_axis_afe0_tready.value = 0
        for _ in range(3): await edge(dut.adc_clk)
        await FallingEdge(dut.adc_clk)
        force(channel.rx_fifo_rlevel, 256)
        assert int(pkt.packet_admit.value), "forced FIFO level did not create admission"
        await edge(dut.adc_clk)  # admission edge N
        done = header_cycle = None
        for cycle in range(1, 20):
            await edge(dut.adc_clk)
            if done is None and int(pkt.crc_done.value): done = cycle
            if header_cycle is None and int(dut.m_axis_afe0_tvalid.value):
                header_cycle = cycle; break
        assert done == 8 and header_cycle == 8
        header = int(dut.m_axis_afe0_tdata.value).to_bytes(64, "little")
        assert header[:4] == b"DTR1" and header[4:6] == bytes((1, 64))
        assert (header[8], header[9], header[10]) == (0, 2, 12)
        assert header[20:24] == bytes(4) and header[29] == 0x40
        assert (header[32], header[33], header[34]) == (0x2A, 1, 1)
        assert int.from_bytes(header[62:64], "little") == crc16(header[:62])
        held = int(dut.m_axis_afe0_tdata.value)
        for _ in range(5):
            await edge(dut.adc_clk)
            assert int(dut.m_axis_afe0_tvalid.value) and int(dut.m_axis_afe0_tdata.value) == held
        await FallingEdge(dut.adc_clk); dut.m_axis_afe0_tready.value = 1
        await edge(dut.adc_clk)  # header handshake
        # An admitted packet is reserved and must complete after later disable
        # and link loss; those conditions only block the next admission.
        force(channel.chn_en_adc, 0)
        force(channel.link_ready_sync, 0)
        payload = 0
        prior_stalled = None
        while payload < 256:
            await FallingEdge(dut.adc_clk)
            force(channel.rx_fifo_rdat, (payload << 480) | payload)
            dut.m_axis_afe0_tready.value = rng.randrange(2)
            await edge(dut.adc_clk)
            current = (int(dut.m_axis_afe0_tdata.value), int(dut.m_axis_afe0_tlast.value))
            if prior_stalled is not None:
                assert current == prior_stalled
            valid = int(dut.m_axis_afe0_tvalid.value)
            ready = int(dut.m_axis_afe0_tready.value)
            prior_stalled = current if valid and not ready else None
            if valid and ready:
                assert current[0] == ((payload << 480) | payload)
                assert current[1] == (payload == 255)
                payload += 1
        assert payload == 256
        force(channel.chn_en_adc, 0)
        for _ in range(2): await edge(dut.adc_clk)
        assert int(pkt.chn_idle.value)
    await with_timeout(body(), TIMEOUT_US, "us")
