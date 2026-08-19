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


if __name__ == "__main__":
    unittest.main()
