<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_accum_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_DESIGN_AUTHOR_handoff_07.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current user grouped design correction: new run ADC_TOP_66dd observed that ADI wrapper rx_data/rx_valid lead first rx_somf by two AFE beats; freeze AFE-domain exact two-beat data/valid delay, explicit SOMF/link/reset behavior, RXD consumption only of aligned signals, preserve DDC recovery assertions, add clear/relink/first-pair requirements, and record manifest correction as non-behavioral.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>ab4429a1f15d69dbc44af5c67429d94e682de042874e97f88417d46f75a6028d</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>DESIGN_CONTRACT_PRECHECK_PASS: python -B C:\Users\Administrator\.codex\skills\rtl-model\scripts\validate_design_contract.py --design D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md --schema C:\Users\Administrator\.codex\skills\rtl-model\references\schemas\Module_Schema.md.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>Grouped v1.15 accepted-design correction: v1.16 adds one AFE-clocked, single-owner two-stage 256-bit data and 1-bit valid delay; raw SOMF and link-ready remain current/live; RXD only consumes d2/v2; raw invalid/link/disable/FIFO clear/reset flush the pipe; rxd_clr retains RXD/DDC clear behavior. It adds exact source0/source8/source16 timing table, A9/A10 tests, assertions/coverage for alignment, flush, relink and first pair. No selected region FSM, dec/ddc formula, mapping, FIFO, DDC I/Q/abort/recovery, interface, register or static-config architecture changed.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE. The two-beat relationship is an observed fixed boundary condition of this frozen ADI wrapper configuration; it is not a configurable RTL option. Legal static configuration remains a software guarantee.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>NONE. ADC_TOP_66dd manifest correction is documented as provenance-only and explicitly not a behavioral design change.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC, VMware, VCS/Verdi, XSIM, synthesis, implementation or board validation was performed in this design-author task. ADC_TOP_66dd is input timing observation, not v1.16 implementation verification. PPA remains HYPOTHESIS.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck routing and independent FINAL_DESIGN review of exact v1.16 candidate fingerprint.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
