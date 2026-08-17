---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-14
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_unpack_review
accepting_review_handoff_sha256: 8534ebee7ea2bbe061c01a64fdc2900d8aaa4345bf3874a7f15fc2b6023b0f1c
tags:
  - FPGA/IP
  - Status
---

# ADC_TOP Current State

## Current Baseline

- Stage after independent acceptance: `READY_FOR_VCS`.
- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, v1.4, SHA256 `a47503e9b734c219549cb3953204a5bb89cd75f3a6a0eba96f31300d7b8d9016`; accepted design review `2026-08-14_FINAL_DESIGN_REVIEW_handoff_09.md`, SHA256 `c01a527a2eacf5d7d7a86420d85afe688c0421116c0773a0b75c70ead2731caa`.
- Contract/profile/class: `RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`.
- RTL hashes: ADC_RXD `a4c7865126073a68ea0130e6cc4a969f8c0500b6bb6d28a1c22dd88d2111a37b`; ADC_CHN `16e9548c9a8af42984d22b7eebc207fc9000ea97a64f782a3193d8f01cde6fa3`; CHN_SYNC `590aad3a2df0f580249646a1ff9bddde90647e948527e1c962154fb6cbbfb842`; ADC_SYNC `0cf059b14265870a2addbd7b338fae57bc40778683f5e64af537d8718afde2af`; ADC_REG `53d16467377916772dbdd4dda4ef1db53327a0f2b4a903cc91e343eb14a051c2`; ADC_TOP `582ef4d6b813884bdec11b1b90deb202326e1461e67b13f33367258934d91bfc`.
- User-owned formatting and signal-name edits are preserved. The v1.4 compact implementation uses a 55-bit packed gap lookup, direct positive `payload_start_beat`, one beat-coordinate terminal comparison, and open unused ADI diagnostics while retaining all mappings, history slices and recovery behavior.
- Constraint: `DEFERRED_TO_TOP`; `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Review.md`, SHA256 `c1fa25bd6a2e5e5ba19ad77976c5e11e031a7e0c0ab11f5951c655081631e145`; `VIVADO_RESOLUTION_NOT_RUN`.
- VMware preflight/evidence: run `ADC_TOP_74278b329f3e4e32a0a25fbddac56f2f`, VIF `9c175c81d9ab3b4835f1f75f8c7208fba73988aecdf0ecfa3f4aafcad01f2d71`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`, 13/13 pass, lint/simulation exit `0/0`, seed `20260814`, timeout `600`, orchestration `156.282472 s`, cleanup PASS.
- Constraint review and dependency manifest were deterministically reused because interface, clocks, resets, CDC and external-only anchors are unchanged.
- PPA intent: `HYPOTHESIS`. Static equivalence and full regression support the compact RTL behavior; synthesis measurement is deferred.
- Model boundary: `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`. VCS/Verdi, integrated XSIM, synthesis, implementation, timing closure, bitstream, and board validation are `NOT_RUN`.
- Release baseline manifest: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json` (single component-table owner).
- Finalization patch: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Finalization_Patch.json`.

## Next Task

- User-owned next task: start `NON_UVM_SYSTEMVERILOG_SOC` VCS/Verdi verification from the accepted baseline.
- Required checks: official-IP boundary behavior, reset/FIFO-clear, link recovery, AXI/AXIS backpressure, and scoreboards/assertions.

## Distillation Status

- Knowledge writeback candidate: `NONE`.
- Wiki writeback authorized: `FALSE`.
- Archive publish authorized: `FALSE`.
