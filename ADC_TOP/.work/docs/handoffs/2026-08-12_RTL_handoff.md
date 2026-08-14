---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-08-12
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_reset_review
accepting_review_handoff_sha256: f2b1a760dd739558fa8b5f473fa10239c64fc60de1d2bd9e4b32d52ac0c96b47
tags:
  - FPGA/Handoff
  - RTL
---

# ADC_TOP RTL Handoff

## Scope And Baseline

- Module work root: `D:\Codex\RTL_Temp\ADC_TOP`; project-independent RTL only. Design SHA256: `bd97a436bcaada0d7a278e57a33748d7fa8cb5452c4cb0f8995b0429707bc3d9`.
- Scoped reset correction maps each JESD domain one-to-one to `jesd_rst_n[n]`, maps AFE/ADC logic to `afe_rst_n`/`adc_rst_n`, and derives FIFO reset from both domains plus software clear. Either AFE or ADC reset discards the complete FIFO.
- The former fixed 5 ms FIFO-clear behavior is removed. `FIFO_CLR` is asserted/deasserted to the selected FIFO's documented requirement while both FIFO clocks continue; access waits for convergence and stable `FIFO_EMPTY`.
- Constraint review is `DEFERRED_TO_TOP` / `EXTERNAL_ONLY`; no module XDC. Review SHA256 `8b60cb536415918276959159390b038a9334062bea376bdb605478445f898a32`; dependency manifest SHA256 `bdb1fc836d6bde3f5efd34c45dc8dbeaaed16b442949506c3fd3daf4f8bf6c24`; `VIVADO_RESOLUTION_NOT_RUN`.

## Observed Evidence

- Preflight receipt passed: `D:\Codex\RTL_Temp\ADC_TOP\.work\verification\state\vmware_preflight_receipt.json`, SHA256 `5cac0af7035b2cf9b4f0948d3e016a11c77e7a41eb776f3aa7e6dd5f751a8d21`.
- Frozen VMware run `ADC_TOP_9d9bb38c82e046e5bcc327edb89fa99e`; VIF `7ba235fbff28f57723acd5d368f4d986350f4d8b661160271a2a15cef4de2986`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint exit 0; 10/10 simulation PASS, no failures/errors/skips.
- Coverage explicitly includes whole-FIFO discard on independent AFE/ADC reset, JESD relink handling, FIFO clear status convergence without a fixed timer, three normal modes, and boundary/error/backpressure checks.
- Earlier failed diagnostic/correction batches are retained for traceability only; they are not represented as PASS evidence.

## Release Status And Continuation

- Stage: `READY_FOR_VCS`. The release sidecar and finalization patch under `.work\state` bind the exact source and evidence baseline for this RTL handoff.
- The next user-owned task is non-UVM VCS/Verdi SoC verification, with selected official FIFO/IP substitutions and their reset/latency/flag differences explicitly checked. VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, and board validation are NOT_RUN.
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; no reusable-RTL promotion, Wiki writeback, or Archive publication is authorized.
