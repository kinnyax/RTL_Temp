---
type: vcs_soc_handoff
module_name: ADC_TOP
date: 2026-08-19
verification_status: READY_FOR_VCS
accepting_review_agent_id: /root/adc_fmt_review
accepting_review_handoff_sha256: 66798366b02cf89758823894e7eaa31e73f1e3c6ae810c84e566c4d641cbeee3
tags: [FPGA/VCS, Verification]
---

# ADC_TOP v1.26 VCS SoC Verification Handoff

## Source Baseline

- Design v1.26 SHA256 `95f274fa2cae62e09c6c9addc3bcfe5ac62d6490ad1d946b96bc844f5602e7ef`; accepted Design Review SHA256 `45be60c7164c465a5582afec2f876d2dc2f6c70e1d23037767353593519f38a9`.
- `ADC_RXD.v` SHA256 `045c45194e54e2ffc33099302d8e0ce6ab4e3c7b66813a8192946c7f52532f57`; TB/manifest SHA256 `3fdcb2e965c1dc9fc54f271b0ec7a2e5ad45c6b6c8ffa06d2a3efc77910ceac5` / `4989e2415682346d2eae7ff52edad6b6386516923db02a1911fcfa9c606d16f6`.
- Fresh VMware run `ADC_TOP_6981ada4757a4989b4c56db8da415309`; VIF `40df98fc4a08cabf67f7624f12946436c1c7e5d7cf6163cd45a8560b35af7fdb`; toolchain `979fe02a6ecb4126a385f07cb5ebcfff02c04524919595a7e6b330698b3f9c0c`; lint/sim `0/0`; 19/19 PASS; JUnit SHA256 `c077efbab0d38228e491205372e80cce0136ea2387b94130990b8157c8eb918c`; cleanup PASS.
- Constraint `DEFERRED_TO_TOP/EXTERNAL_ONLY`; review/manifest SHA256 `54343ce19c80cb960fae55ccac63b6f5df5972839f8d7223fcd245a361214768` / `a50414cbca11fd50d349120e9f4324fc3f991a19ed89d8a8b7c0d593d3d171f0`; `VIVADO_RESOLUTION_NOT_RUN`.

## Required SoC Focus

- Verify normalized AC9810 N'=16 word behavior: `FRAME_FMT=1` preserves raw left-aligned `S`; `FRAME_FMT=0` yields signed right-aligned code from `S[15:6]`, `S[15:4]`, or `S[15:2]` for p=10/12/14.
- Formatting registers do not configure AC9810 source width/coding, and packet headers omit FRAME_FMT/device-coding metadata.
- Retain checks for decoded FSM transitions, `prefix_cnt`, pre-edge raw marker capture, P0/P1 request timing, FIFO clear/abort recovery, dec/DDC scheduling, AXI-Lite, TGC, AXIS backpressure, packets and CRC/TLAST.

## Boundary And Status

- ADI `jesd204_rx.v` provenance remains analogdevicesinc/hdl commit `9d5de2fc21b6069675104567c9041bcdbfbe9baa`, GPLv2; official PHY/FIFO behavior is not vendor-equivalent in VMware.
- PPA remains `HYPOTHESIS`. Future integration owns CMU/RMU clocks/resets, PHY/GTH and FIFO XCI semantics, vendor XDC precedence, and timing closure.
- Stage is `REVIEW_PENDING`; independent review must accept the frozen release baseline. Thereafter mechanical finalization may advance only to `READY_FOR_VCS`.
- VCS/Verdi execution/evidence: `NOT_RUN`; passing VCS would advance to `VCS_SOC_VERIFIED`. Integrated XSIM, synthesis, implementation, bitstream, programming, and board validation are `NOT_RUN`.
