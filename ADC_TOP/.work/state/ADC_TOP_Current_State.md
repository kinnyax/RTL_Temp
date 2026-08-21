---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-19
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_fmt_review
accepting_review_handoff_sha256: 66798366b02cf89758823894e7eaa31e73f1e3c6ae810c84e566c4d641cbeee3
tags: [FPGA/IP, Status]
---

# ADC_TOP Current State

## Current v1.26 Baseline

- Module root: `D:\Codex\RTL_Temp\ADC_TOP`; project association: `NONE`.
- Design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`; SHA256 `95f274fa2cae62e09c6c9addc3bcfe5ac62d6490ad1d946b96bc844f5602e7ef`.
- Accepted design review: `/root/adc_fmt_design_review`, `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_FINAL_DESIGN_REVIEW_handoff_02.md`; SHA256 `45be60c7164c465a5582afec2f876d2dc2f6c70e1d23037767353593519f38a9`.
- Contract/profile/class: `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- RTL: `rtl\ADC_RXD.v`; SHA256 `045c45194e54e2ffc33099302d8e0ce6ab4e3c7b66813a8192946c7f52532f57`.

## Confirmed Format Behavior

- AC9810 source word `S` is a normalized 16-bit container. `SMP_PREC=0/1/2` selects p=10/12/14, with meaningful signed codes `S[15:6]`, `S[15:4]`, and `S[15:2]`; remaining low bits are zero padding.
- `FRAME_FMT=0` gives the software a signed, right-aligned 16-bit value. `FRAME_FMT=1` returns raw `S` unchanged as a lossless left-aligned container.
- `FRAME_FMT` and `SMP_PREC` are FPGA-side software formatting controls; they do not configure AC9810 `CFG_DATA_MODE`. Matching two's-complement p=10/12/14 source configuration is required before the epoch. p=16, sign-magnitude, and unsigned device formats are outside v1.26.

## Fresh Evidence And Release State

- First fresh v1.26 batch `ADC_TOP_76d1fbe2c28c499f81bea9868dba8672` diagnosed one scheduler-scoreboard mismatch in `dec_ddc_region_v115_legal_matrix` (18/19 pass; VIF `0aa256d554d8c56435922b3ffe6e3658c08ee0c4a6174f1b87df16324dd1f364`); retained history documents the failed actual/expected beat-zero payload.
- Final fresh run `ADC_TOP_6981ada4757a4989b4c56db8da415309`, VIF `40df98fc4a08cabf67f7624f12946436c1c7e5d7cf6163cd45a8560b35af7fdb`, toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`: lint exit 0, simulation exit 0, 19/19 PASS, seed 20260818, timeout 600 s, total 293.672429 s, cleanup PASS.
- The six normalized format/precision combinations are covered using positive and negative high-bit-sensitive containers across reordered words. Tests reject low-padding/low-slice, sign-extension, and reorder regressions.
- Constraint review: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Review.md`; SHA256 `54343ce19c80cb960fae55ccac63b6f5df5972839f8d7223fcd245a361214768`; `DEFERRED_TO_TOP/EXTERNAL_ONLY`, `VIVADO_RESOLUTION_NOT_RUN`. Dependency manifest SHA256 `a50414cbca11fd50d349120e9f4324fc3f991a19ed89d8a8b7c0d593d3d171f0`.
- Release sidecar `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json` is the sole component/fingerprint owner and remains `REVIEW_PENDING`.

## Roles, Boundary And Next Action

- Lead `/root`; RTL `/root/adc_fmt_rtl`; Simulation `/root/adc_fmt_sim`; Constraint `/root/adc_fmt_constraint`; Verification `/root/adc_fmt_verify`; Docs `/root/adc_fmt_docs`; independent RTL Review `/root/adc_fmt_review` is pending.
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; PPA status `HYPOTHESIS`. VCS/Verdi, integrated XSIM, synthesis, implementation, timing closure, bitstream, programming, and board validation are `NOT_RUN`.
- Next action: independent reviewer validates this immutable review-pending baseline. If accepted, Docs may mechanically finalize; only then may the Lead make an intentional ADC_TOP-scoped GitHub commit/push. VCS execution: `NOT_RUN`.
- `KNOWLEDGE_WRITEBACK_CANDIDATE=NONE`; no Wiki/Archive writeback authorization.
