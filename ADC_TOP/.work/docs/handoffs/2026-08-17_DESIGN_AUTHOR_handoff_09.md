<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_config_design_author</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_DESIGN_AUTHOR_handoff_09.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>2026-08-17 current conversation, final override: ADC_RXD Payload-prefix names are only adc_num, dec_num, ddc_num, skip_num and payload_hit. All *_num quantities are AFE beats; pure ADC keeps (16+96+16)/8=16; payload_hit compares (prefix_beat_r+1)==skip_num.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>af32ba63a3d7ab021c7d90ea16e2c6c172c5e268dbbd31e7305c78e841ded860</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: deterministic validator returned DESIGN_CONTRACT_PRECHECK_PASS for the recorded exact fingerprint; front matter and all applicable RTL_MODULE_CONTRACT_V1 sections/checklists remain present.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>Final user naming override applied coherently: active v1.9 RTL-facing text removes prior long prefix names; adc_num=(16+96+16)/8 is compile-time 16 AFE beats with each lane/beat explicitly eight 16-bit words; dec_num and ddc_num remain separately expressed by mode; skip_num is the SMP_MODE three-way result; payload_hit remains the marker-inclusive SKIP-stage comparison.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. The final user decision explicitly supersedes earlier v1.9 prefix naming. No RTL, TB, XDC, state, project, or verification artifact was modified.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC was modified and no verification ran. The candidate requires independent final design review before DESIGN_READY; prior RTL/VMware evidence remains stale for v1.9.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck and routing</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
