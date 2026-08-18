---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-08-18
verification_status: REVIEW_PENDING
accepting_review_agent_id: ACCEPTING_REVIEW_AGENT_ID
accepting_review_handoff_sha256: ACCEPTING_REVIEW_HANDOFF_SHA256
tags: [FPGA/Handoff, RTL]
---

# ADC_TOP RTL Handoff

## Scope And Decisions

- Module root `D:\Codex\RTL_Temp\ADC_TOP`; design v1.10 SHA256 `afd18901724ba292162e6bc500b70de00ced69002e315e5ca38b4b314f1401f8`.
- Complete module implementation class is `MODIFIED_THIRD_PARTY_RTL`; changed ADC_RXD is self-written.
- v1.10 is a behavior-preserving readability/ownership delta: state names are `RXD_IDLE/RXD_PREF/RXD_PAYL`; short semantic names follow user edits; `word_pos_r` is separated from the coupled `next_term_r/term_phase_r` block. Reset, clear, PREF hit, PAYL advance and illegal-state recovery remain cycle-equivalent.

## Frozen Artifacts And Evidence

- ADC_RXD SHA256 `416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8`.
- Reused TB/manifest SHA256 `9cb39d4d605035aef500772fa8c6409c69e7e3f2bb32937fa256eb06a62f4486` / `4094d0b25d401bfe6cc1268e9e0690b94243c9bec4be6ec17f242f86abf0c5fc`; intent and bytes unchanged.
- Accepted VMware run `ADC_TOP_2b43a31908ac4c55a6f06be923c38874`; VIF `65333f09d939430e679df93eae9480f75ff54a29e038bcbc6cbeb91d0e2618bc`; lint/simulation `0/0`; 15/15 PASS.
- Constraint review reused as `DEFERRED_TO_TOP/EXTERNAL_ONLY`; `VIVADO_RESOLUTION_NOT_RUN`.

## Status And Next Task

- Intended post-acceptance stage `READY_FOR_VCS`.
- PPA `HYPOTHESIS`; `NON_VENDOR_EQUIVALENT`; VCS and downstream FPGA phases `NOT_RUN`.
- Next action is user-owned VCS/Verdi verification. Knowledge candidate `NONE`.
