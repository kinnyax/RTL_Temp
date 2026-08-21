---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-08-19
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_v124_review7
accepting_review_handoff_sha256: 119d71d758a0f72d5f8f18153492da7b53e43591cc136b24b56bf90bc62b6c26
tags: [FPGA/Handoff, RTL]
---

# ADC_TOP RTL Handoff

## Scope And Exact Baseline

- Module root: `D:\Codex\RTL_Temp\ADC_TOP`; project association: `NONE`.
- Accepted design v1.24 SHA256 `651b990819c3cb5d0707271014e4eb9fc7c2e716c19a14d65e441088accd6139`; accepted Design Review SHA256 `d61445790167c7d645a2c2f7d9091348eb00135fbeda055213182f039e3b2cda`.
- Contract/profile/class: `RTL_MODULE_CONTRACT_V1`, `VERILOG_2001_EXPLICIT_V1`, `MODIFIED_THIRD_PARTY_RTL`.
- Changed RTL: `D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v`, SHA256 `e72aafb5677a488fcdfc6f39ab81303b71dfadf4318e3ebe09e412a4ce009df6`.
- TB/manifest SHA256 `d5c230db640c6d41054bec4fcbc18a85eec42531bff911fa3ea929bb7ec8f5ee` / `7bd740743e6685744ae351cb6557011136feed0db2770f0c3ebc05921456b28f`.

## Implemented Behavior

- ADC_RXD uses a readable beat-region FSM and positive region counters over current pre-edge raw ADI data/valid/SOMF. Dec and DDC formulas remain distinct; corrected f2/no-duplicate scheduling is part of the v1.24 baseline.
- Two 128-bit lane buffers capture P0; terminal-15 P1 forms and registers the FIFO candidate. The downstream FIFO samples the registered request once on the next AFE edge.
- Normal disable never sets abort. Enabled DDC loss is fail-closed: it preserves already-queued data, may commit at most one pre-existing registered request, creates no replacement request, and blocks later FIFO/packet admission until software performs disable plus `FIFO_CLR` and relink.
- Same-edge reset/`fifo_clr` clears the registered request with priority. W1C alone does not recover data admission.

## Layer-A And Fresh Batch-7 Evidence

- Layer-A audit SHA256 `9b2a4528f212730e3f0aeea266ad905844ca799dcb5a45bc65cee4c71948a521`; 144 deterministic source-reachable truth-table vectors PASS.
- Fresh VMware run `ADC_TOP_8698db92e112448c9e085208a7b975c3`; VIF `7c5fd2e1796010bd55e40c7171838f0f7e838f1a81a4cecf33b7441673594258`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`.
- Verilator lint/simulation exit `0/0`; 16/16 PASS; seed `20260818`; timeout `600`; JUnit SHA256 `8f8fc08da744ab5898ac54d0d72d62a39785d3478d41da3750dcb6125e550e7d`; total `280.408076 s`; remote cleanup `PASS`.
- Directed markers establish healthy disable/no-abort, retained queue, clean/no-pending loss, W1C fail-closed behavior, two FIFO clears, final recovery, pre-edge marker alignment and exactly-once next-edge FIFO sampling.
- Constraint review/manifest SHA256 `0078ae0e1d6acc747f549824a3694a7f73384a9f23126061dc0bd3267caf7835` / `9d786192b3ade1e10a007fbefa595c56d429c7ae91d8441c505cda8cc3e3b75b`; `DEFERRED_TO_TOP/EXTERNAL_ONLY`, `VIVADO_RESOLUTION_NOT_RUN`.

## Contributors, Status And Next Task

- Lead `/root`; RTL `/root/adc_accum_rtl`; Simulation `/root/adc_accum_sim`; Constraint `/root/adc_accum_constraint`; Verification `/root/adc_v124_verify7`; Docs `/root/adc_v124_docs7`.
- Upstream design contributors: Architecture `/root/adc_accum_arch2`; Evidence `/root/adc_decim_evidence`; Design `/root/adc_accum_design`; accepted Design Review `/root/adc_accum_design_review`.
- Release sidecar is `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json`; finalization patch is `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Finalization_Patch.json`. Both remain `REVIEW_PENDING` until exact independent acceptance.
- PPA is `HYPOTHESIS`; `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`; official PHY/FIFO equivalence and downstream FPGA behavior remain unproved.
- Next owner is a distinct Review Worker. VCS/Verdi, integrated XSIM, synthesis, implementation, timing closure, bitstream, programming and board validation are `NOT_RUN`. Knowledge candidate `NONE`.
