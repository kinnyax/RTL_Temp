<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_config_design_author</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_DESIGN_AUTHOR_handoff_08.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>2026-08-17 current conversation, follow-up: split ADC_RXD Payload prefix calculation into auditable pure-ADC compile-time word constants and non-pure base_prefix_beat plus delay_prefix_beat; retain marker-inclusive payload_hit and do not make pure ADC 128 beats.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>44457cdd6cc1ccc9b999b21fd60d7e7f095da13d10a87bd490979ea9a33e0f87</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>PASS: front matter and all applicable RTL_MODULE_CONTRACT_V1 sections/checklists remain present; deterministic validator returned DESIGN_CONTRACT_PRECHECK_PASS for the recorded exact fingerprint.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>User-selected v1.9 prefix-expression clarification: replaced conflicting prohibition on zero_words-style audit constants/direct prefix wording. Pure ADC requires localparams SYNC_HEAD_WORDS=16, ZERO_WORDS=96, SYNC_TAIL_WORDS=16, WORDS_PER_LANE_BEAT=8, ADC_PREFIX_WORDS=128, ADC_PREFIX_BEATS=16; non-pure requires base_prefix_beat + delay_prefix_beat; no runtime divider; payload_hit remains (prefix_beat_r+1)==payload_start_beat in SKIP.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. The follow-up user decision explicitly supersedes the older conflicting wording. No RTL, TB, XDC, state, project, or verification artifact was modified.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC was modified and no verification ran. The exact candidate must receive independent final design review before DESIGN_READY; all old RTL/VMware evidence remains stale for v1.9. Runtime safety semantics and static-configuration software-contract boundary remain as v1.9.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck and routing</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
