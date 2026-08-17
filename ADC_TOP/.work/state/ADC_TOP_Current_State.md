---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-18
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_config_review
accepting_review_handoff_sha256: 00d32372a59918c9472327986313b18e61369b522dd334b2985716338a0f59bf
tags: [FPGA/IP, Status]
---

# ADC_TOP Current State

## Current Baseline

- Stage: `REVIEW_PENDING`; independent RTL Review has not yet accepted this exact release baseline.
- Design v1.9: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `010556a566a6af24fa1dae3b7ab8ba2c487582487cd0760d3ee899a8f41f7ce2`; final design review `_11`, SHA256 `c45b5d795601ec05c2ef0c1ae653a9a659be3093d03ec1c02a4f6cae8d24c4df`; `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- RTL: updated `ADC_RXD.v` SHA256 `0f465fdadb38dc16acbb5816b4d1a6c27e596e31c0328e828586e02dd0627275`; remaining filelist SHA256 `76aa2d06650dc14aae941c422ef6a2d183be3cd0076386c84d8085aa44a0f648`.
- Delta: static illegal-configuration gates are removed under the software legal/stable-config precondition. The payload scheduler now exposes `adc_num`, `dec_num`, `ddc_num`, `skip_num`, and `payload_hit`; pure ADC explicitly skips `(16+96+16)/8 = 16` AFE beats. `rxd_clr = !upk_vld || fifo_clr` is the common runtime clear, and state/event conditions separately enable prefix and payload bookkeeping.
- VMware run `ADC_TOP_a068bcae19f94e85b1f32373b9e126f9`: VIF `b3c0cd58ffeaae731102a41cfa4ecca08d220b07670394b676f5728bd8ac7b74`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint/simulation `0/0`; 15/15 PASS; seed `20260818`; timeout `600`; remote cleanup PASS. The initial failed batch caused by a TB expectation bug is retained as history, not release evidence.
- VMware startup preflight: PASS; `D:\Codex\RTL_Temp\ADC_TOP\.work\verification\state\vmware_preflight_receipt.json`, SHA256 `38d2d6fa47bae5aa11100d9675c6b2c33e6cab9f89aa89ab3f2d71d6f40ce9ca`.
- Constraint: `DEFERRED_TO_TOP` / `EXTERNAL_ONLY`; review SHA256 `55b1c8c4b3aff30bfbafb3f9dfaa38e8ac1bfbb060ca363cc205e02fd0355b25`; dependency manifest SHA256 `0a6ed286c4a575921822f65241f7c9f00c2442e8d88005a31dfcf02cbdc7c0e7`; `VIVADO_RESOLUTION_NOT_RUN`.
- PPA: `HYPOTHESIS`; model boundary: `NON_VENDOR_EQUIVALENT`. VCS/Verdi, integrated XSIM, synthesis, implementation, timing closure, bitstream and board validation are `NOT_RUN`.
- Release baseline manifest: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json` (REVIEW_PENDING). Finalization patch: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Finalization_Patch.json` (REVIEW_PENDING). Role roster: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Role_Roster.json`.

## Next Task

- Required phase: independent rtl-vibe Review of the exact review-pending sidecar.
- Next owner: `/root/adc_config_review`; upon acceptance, Docs alone applies the bound mechanical finalization patch.

## Distillation Status

- Knowledge writeback candidate: `ADC_RXD` payload-prefix naming/formula clarity and runtime clear factoring, supported by v1.9 design plus VMware run `ADC_TOP_a068bcae19f94e85b1f32373b9e126f9`.
- `WIKI_WRITEBACK_AUTHORIZED=FALSE`; `ARCHIVE_PUBLISH_AUTHORIZED=FALSE`.
