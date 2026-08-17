<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_config_design_author</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_DESIGN_AUTHOR_handoff_10.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>2026-08-17 current conversation: define assign rxd_clr = !upk_vld || fifo_clr; move this common highest-priority return-to-WAIT condition into the RXD FSM state-register block; use rxd_clr for all equivalent prefix/scheduler/history/DDC-IQ context clears; next-state case contains only state-local transitions.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>37c52fe90bdb2b914fafff2b883c935532f6f007ce375839488d96e7d39a3149</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: deterministic validator returned DESIGN_CONTRACT_PRECHECK_PASS for the recorded exact fingerprint; front matter and all applicable RTL_MODULE_CONTRACT_V1 sections/checklists remain present.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>User-selected v1.9 RXD structure revision applied: state-register priority is async reset, rxd_clr to WAIT, then rxd_fsm_nx; next-state always@*/case has full begin/end and explicit state-local self-holds without rxd_clr duplication; data/context block clears all shared receive context on rxd_clr at the same AFE edge. Short prefix names adc_num/dec_num/ddc_num/skip_num/payload_hit remain unchanged.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. The structure revision preserves the exact runtime behavior and does not alter any other v1.9 contract. No RTL, TB, XDC, state, project, or verification artifact was modified.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC was modified and no verification ran. The candidate requires independent final design review before DESIGN_READY; prior RTL/VMware evidence remains stale for v1.9.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck and routing</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
