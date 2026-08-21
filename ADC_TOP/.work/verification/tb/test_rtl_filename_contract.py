"""Static regression for the ADC_TOP self-written RTL naming contract.

This test is deliberately independent of cocotb and VMware: it prevents the
filelist and FSM-prefix refactor from regressing before simulator execution.
ADI_JESD204/jesd204_rx.v is third-party material and is intentionally outside
the self-written RTL checks.
"""

from pathlib import Path
import unittest


MODULE_ROOT = Path(__file__).resolve().parents[3]
RTL_ROOT = MODULE_ROOT / "rtl"

SELF_WRITTEN_FILES = (
    "ADC_TOP.v",
    "ADC_REG.v",
    "ADC_SYNC.v",
    "CHN_SYNC.v",
    "ADC_TGC.v",
    "ADC_PKT.v",
    "ADC_RXD.v",
    "ADC_UPK.v",
    "ADC_CHN.v",
)

EXPECTED_FILELIST_FILES = (
    "ADC_REG.v",
    "ADC_SYNC.v",
    "CHN_SYNC.v",
    "ADC_TGC.v",
    "ADC_PKT.v",
    "ADC_RXD.v",
    "ADC_UPK.v",
    "ADC_CHN.v",
    "ADC_TOP.v",
)

UPK_STABLE_ANCHORS = (
    "payl_hit",
    "pref_num",
    "region_vld_max",
    "region_zro_max",
    "region_vld_clr",
    "region_zro_clr",
    "rxd_buff_upd",
    "rxd_data_upd",
    "ddc_i_sta",
    "ddc_q_sta",
    "normal_wr_req",
    "ddc_i_upd",
    "ddc_q_upd",
    "ddc_pair_wr",
    "data_drop_set",
)

STALE_UPK_ALIASES = (
    "dec_num",
    "ddc_num",
    "valid_beats",
    "zero_beats",
    "valid_region_final",
    "zero_region_final",
    "ddc_abort_afe",
    "ddc_i_accepted_r",
    "ddc_iq_phase",
    "rxd_second_half",
    "rxd_buff_vld",
    "data_cnt",
)


class TestAdcTopRtlNamingContract(unittest.TestCase):
    def test_self_written_rtl_uses_uppercase_filenames_and_prefixed_fsm_states(self):
        actual_rtl_filenames = {path.name for path in RTL_ROOT.iterdir() if path.is_file()}
        missing_files = [name for name in SELF_WRITTEN_FILES if name not in actual_rtl_filenames]
        lowercase_predecessors = [
            name for name in SELF_WRITTEN_FILES if name.lower() in actual_rtl_filenames
        ]
        filelist_lines = (RTL_ROOT / "filelist.f").read_text(encoding="utf-8").splitlines()
        self_written_filelist_lines = [
            line for line in filelist_lines if line.startswith("rtl/") and "ADI_JESD204/" not in line
        ]
        expected_filelist_lines = [f"rtl/{name}" for name in EXPECTED_FILELIST_FILES]

        self.assertEqual([], missing_files, f"missing uppercase RTL files: {missing_files}")
        self.assertEqual([], lowercase_predecessors, f"lowercase predecessor files remain: {lowercase_predecessors}")
        self.assertEqual(expected_filelist_lines, self_written_filelist_lines)
        self.assertFalse(
            any(line == f"rtl/{name.lower()}" for name in SELF_WRITTEN_FILES for line in filelist_lines),
            "filelist.f retains a lowercase self-written RTL path",
        )

        self_written_text = "\n".join((RTL_ROOT / name).read_text(encoding="utf-8") for name in SELF_WRITTEN_FILES)
        self.assertNotRegex(self_written_text, r"\bST_[A-Za-z0-9_]*\b")
        self.assertRegex((RTL_ROOT / "ADC_TGC.v").read_text(encoding="utf-8"), r"\bTGC_[A-Za-z0-9_]*\b")
        self.assertRegex((RTL_ROOT / "ADC_PKT.v").read_text(encoding="utf-8"), r"\bPKT_[A-Za-z0-9_]*\b")

        upk_text = (RTL_ROOT / "ADC_UPK.v").read_text(encoding="utf-8")
        for anchor in UPK_STABLE_ANCHORS:
            self.assertRegex(upk_text, rf"\b{anchor}\b", f"missing stable UPK anchor {anchor}")
        for stale in STALE_UPK_ALIASES:
            self.assertNotRegex(
                self_written_text, rf"\b{stale}\b",
                f"stale pre-resolution UPK name remains: {stale}",
            )
        self.assertNotRegex(upk_text, r"\bfifo_clr\b")
        self.assertEqual(
            6, upk_text.count("else if (!upk_vld)"),
            "every UPK sequential context owner must give upk_vld clear priority",
        )
        self.assertRegex(
            upk_text,
            r"assign\s+ddc_pair_wr\s*=\s*ddc_q_upd\s*&&\s*fifo_has_two_space\s*;",
        )
        self.assertRegex(
            upk_text,
            r"assign\s+data_drop_set\s*=\s*ddc_q_upd\s*&&\s*!fifo_has_two_space\s*;",
        )

        channel_text = (RTL_ROOT / "ADC_CHN.v").read_text(encoding="utf-8")
        self.assertRegex(
            channel_text,
            r"assign\s+fifo_rst_n\s*=\s*afe_rst_n\s*&\s*adc_rst_n\s*&\s*~fifo_clr\s*;",
        )
        self.assertRegex(channel_text, r"\.winc\s*\(fifo_wr_valid\s*\)")

        top_text = (RTL_ROOT / "ADC_TOP.v").read_text(encoding="utf-8")
        for channel in range(8):
            self.assertRegex(top_text, rf"\bADC_CHN\s+adc_chn{channel}\s*\(")
            self.assertRegex(top_text, rf"\bafe{channel}_rx_data\b")
            self.assertRegex(top_text, rf"\bm_axis_afe{channel}_tdata\b")
            self.assertRegex(top_text, rf"\btgc{channel}_slope\b")
            instance = top_text.split(f"ADC_CHN adc_chn{channel}(", 1)[1].split(");", 1)[0]
            self.assertRegex(instance, rf"\.afe_id\s*\(3'd{channel}\s*\)")
            self.assertRegex(instance, rf"\.phy_rx_data\s*\(afe{channel}_rx_data\s*\)")
            self.assertRegex(
                instance,
                rf"\.m_axis_tdata\s*\(m_axis_afe{channel}_tdata\s*\)",
            )
            self.assertRegex(
                top_text,
                rf"assign\s+tgc{channel}_slope\s*=\s*tgc_slope_vec\[{channel}\]\s*;",
            )
        self.assertNotRegex(top_text, r"\bAFE_NUM\b")
        self.assertNotRegex(top_text, r"\b(generate|genvar)\b")


if __name__ == "__main__":
    unittest.main()
