---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-14
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_unpack_review
accepting_review_handoff_sha256: 8534ebee7ea2bbe061c01a64fdc2900d8aaa4345bf3874a7f15fc2b6023b0f1c
tags:
  - FPGA/VCS
  - Verification
---

# ADC_TOP VCS SoC Verification Handoff

## Source Baseline

- Design v1.4: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `a47503e9b734c219549cb3953204a5bb89cd75f3a6a0eba96f31300d7b8d9016`; accepted design review SHA256 `c01a527a2eacf5d7d7a86420d85afe688c0421116c0773a0b75c70ead2731caa`; `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- RTL/filelist: `D:\Codex\RTL_Temp\ADC_TOP\rtl`; ADC_RXD `a4c7865126073a68ea0130e6cc4a969f8c0500b6bb6d28a1c22dd88d2111a37b`; all other RTL hashes unchanged from the accepted prior release.
- VMware sanity: run `ADC_TOP_74278b329f3e4e32a0a25fbddac56f2f`, VIF `9c175c81d9ab3b4835f1f75f8c7208fba73988aecdf0ecfa3f4aafcad01f2d71`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; 13/13 PASS, lint/simulation `0/0`, seed `20260814`, timeout `600`, orchestration `156.282472 s`, cleanup PASS.
- Reused constraint review/dependency manifest: SHA256 `c1fa25bd6a2e5e5ba19ad77976c5e11e031a7e0c0ab11f5951c655081631e145` / `1fc21f24dde9dd3f8efa455b36c891a845634115261debbe8616a0cc8ce22070`.
- Constraint applicability: `DEFERRED_TO_TOP`; review SHA256 `c1fa25bd6a2e5e5ba19ad77976c5e11e031a7e0c0ab11f5951c655081631e145`; `VIVADO_RESOLUTION_NOT_RUN`.
- Release baseline sidecar and mechanical finalization patch are under `.work\state`.

## Third-Party Provenance

- ADI JEDS204 receive source is a permitted modified third-party source, with provenance and owned-copy details in the finalized design/dependency manifest.
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; upstream/vendor-IP equivalence is `NOT_CLAIMED`.

## Environment Contract

- Methodology: `NON_UVM_SYSTEMVERILOG_SOC`.
- Simulator/debugger: VCS / Verdi.
- Official-IP availability: `UNAVAILABLE` in VMware; later Vivado IP replacement behavior is not proved by this baseline.

## Clock And Reset

| Domain | Clock | Reset | Startup expectation |
| --- | --- | --- | --- |
| JESD PHY | jesd_clk | jesd_rst_n | PHY/link bring-up |
| AFE/unpack | afe_clk | afe_rst_n | ADI receive, unpack, FIFO write |
| ADC/packet | adc_clk | adc_rst_n | FIFO read and AXIS packetization |

## Stimulus And Checking

- Self-checking VMware suite: 13 tests, three normal configurations, reset/FIFO-clear, marker-inclusive prefix beat 0 plus representative scheduler matrix, DDC abort, errors and AXI/AXIS backpressure.
- VCS task must recheck official-IP behavior, reset/link recovery and protocol behavior with scoreboards/assertions; waveform debug scope is user-owned.

## PPA Intent

- Status: `HYPOTHESIS`.
- v1.4 statically preserves scheduler results while using packed gap lookup, direct beat formula and one beat-coordinate comparison; no synthesis/PPA observation exists.

## Residual Risks And Next Status

- Risks: scheduler table fidelity, DDC I/Q/abort behavior, FWFT `WC=0` semantics, AC9810 ILAS/controller mapping, and official FIFO/PHY replacement equivalence.
- VCS pass advances status to `VCS_SOC_VERIFIED`.
- VCS execution/evidence in this handoff: `NOT_RUN`.
