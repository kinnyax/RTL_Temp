<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_rework_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_DESIGN_AUTHOR_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>User messages relayed by Lead, 2026-08-19: ADC_JESD204 owns ADI/JESD boundary; FIFO_CLR only clears FIFO; upk_vld = chn_en_afe &amp; link_ready_afe; no data_cnt/pair_pha/rxd_buff_vld; wrapper-tightened AFE readiness, link_ready_afe = link_ready_sync &amp; adi_rx_valid.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>de7833d90a5d38551ec9933373e0f3a42504a72ef70fceefeedac66f496cd788</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>Deterministic RTL_MODULE_CONTRACT_V1 precheck PASS: schema/frontmatter, sections 2–20 and all checklist items pass.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>v1.27 wrapper boundary and RXD schedule correction batch: tight AFE readiness contract, FIFO_CLR-only FIFO semantics, no persistent pair-valid state, deterministic region_cnt pairing.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC/verification work was performed. v1.26 evidence is invalid for v1.27. ADC_TGC full-register/internal-decode refactor remains a separately scoped incomplete follow-up and is not claimed implemented by this baseline.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck routing and independent Design Review.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
