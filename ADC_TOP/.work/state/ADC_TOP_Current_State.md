---
type: module_current_state
module_name: ADC_TOP
date: 2026-08-18
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_unpack_review
accepting_review_handoff_sha256: 1cc90cb33603487bbfa3dc74c0fc85429d0a19e389867e284e065a7084a0d6e3
tags: [FPGA/IP, Status]
---

# ADC_TOP Current State

## Current Baseline

- Intended post-acceptance stage: `READY_FOR_VCS`.
- Design v1.10: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8`; Design Author handoff SHA256 `c68085c4a4356fedbfa2a030b65ec0ecf43488d76125e2fc903f347304fcb45f`; accepted Design Review SHA256 `5f8744e23c4c3615837d0aec07d6a0be5ac5d76fbd882428c9d3e4a15c2dff0c`.
- Contract/profile/class: `RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`. ADC_RXD is self-written, but the complete module includes modified license-permitted ADI source.
- ADC_RXD SHA256 `416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8`.
- v1.10 preserves behavior while freezing user-selected names `RXD_IDLE/RXD_PREF/RXD_PAYL`, `dec_fra`, `upk_trig`, `pref_fra/pref_del/pref_num`; `word_pos_r` has one timing owner and `next_term_r/term_phase_r` retain one coupled owner. User formatting and compact semantic naming remain authoritative.
- TB/manifest SHA256 `d79a3f9e814950243feb44ccdee7967effcd7fb6fddd2cfd3297c94cb7468471` / `2373439d7cb4d6d906f339e313342d0ede5beda10f99281c8286ad80f974ba0d`; the added directed test binds IDLE/PREF/PAYL ownership, common clear, gap update and illegal-state recovery.
- User-authorized seventh fresh VMware run `ADC_TOP_33bc74bdf97d4f17a739919f36ea22d7`: VIF `3fb3f3029656bddd3893d0e506b789738effa87f679402d3b61e8e37437717f1`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint/simulation `0/0`; 16/16 PASS; JUnit SHA256 `8888d486cb93e77e060f79af48c56222e7b82f2c6729467a8609e9ec8e418ced`; seed `20260818`; timeout `600`; cleanup PASS.
- Constraint: `DEFERRED_TO_TOP/EXTERNAL_ONLY`; review SHA256 `f369a63160feecf5276074762281b3dfe642f498935cb17b35c75de121f3e4d7`; dependency manifest SHA256 `895093b4dd32640aa77f4826d807068b3af7073d0d1070cf41ba20de4c8df25e`; `VIVADO_RESOLUTION_NOT_RUN`.
- Previous release baselines are stale. PPA is `HYPOTHESIS`; model boundary is `NON_VENDOR_EQUIVALENT`.
- Release sidecar: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json`; finalization patch: `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Finalization_Patch.json`.

## Next Task

- User-owned `NON_UVM_SYSTEMVERILOG_SOC` VCS/Verdi verification; VCS execution is `NOT_RUN`.
- Official IP, XSIM, synthesis/PPA, implementation, timing, bitstream and board validation remain `NOT_RUN`.

## Distillation Status

- Knowledge writeback candidate `NONE`; Wiki/Archive authorization `FALSE`.
