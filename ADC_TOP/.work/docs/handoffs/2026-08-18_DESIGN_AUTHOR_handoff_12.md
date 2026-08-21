<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_accum_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_DESIGN_AUTHOR_handoff_12.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current batch6 authorization supersedes the immediately preceding batch5 direction: retain current fail-closed behavior. ddc_abort_afe=1 blocks FIFO writes and new packet admission; software must disable plus FIFO_CLR to clear abort/recover; W1C does not clear abort; TB must verify empty=1. The user authorizes batch6 and forbids RTL/TB/XDC/technical-artifact changes.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>a6a89c5faace169b1a2dacad43940c361a7612c5094999ed4774159a588f70f8</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>DESIGN_CONTRACT_PRECHECK_PASS: python -B C:\Users\Administrator\.codex\skills\rtl-model\scripts\validate_design_contract.py --design D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md --schema C:\Users\Administrator\.codex\skills\rtl-model\references\schemas\Module_Schema.md.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>v1.20 is a minimal batch6 acceptance clarification over accepted v1.19 semantics. The partial batch5 “post-abort FIFO writes continue” wording was restored/removed before completion. ddc_abort_afe is now explicitly required in fifo_wr_valid gating; established DDC loss sets abort/drop once, blocks both ADC_RXD writes and new packet admission, and requires fifo_wr_valid=0/FIFO_EMPTY=1 until software disable→idle→FIFO_CLR clears both FIFO and abort before reconfigure/relink/enable. W1C clears ADC_PD Sticky only. FIFO/abort assertions, coverage, per-edge diagnostics, status, software recovery, traceability and checklist consistently require no write and empty=1. The batch5 sequential region-write/TREADY diagnostic remains evidence only and causes no scheduler design change.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>The prior batch5 request said abort-period FIFO data may continue; the newest explicit user selection rejects that direction and reselects fail-closed FIFO gating. The partial batch5 design edit was reversed. Immutable handoff _11 remains historical but is superseded by this handoff.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC/state/verification artifact was changed. Batch5 remains diagnostic input, not a v1.20 verification pass. PPA remains HYPOTHESIS; implementation must produce a v1.20 exact RTL SHA256 before independent review and VMware sanity.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for exact-fingerprint independent FINAL_DESIGN review.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
