<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_accum_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_DESIGN_AUTHOR_handoff_16.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current B12 correction: distinguish normal software disable chn_en_afe=0, which makes upk_vld=0 and clears RXD context but must not set abort/drop, from enabled established-DDC link_ready/raw adi_rx_valid loss, which sets abort/drop. Preserve FIFO pending/sample/clear priority and do not change behavior.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>651b990819c3cb5d0707271014e4eb9fc7c2e716c19a14d65e441088accd6139</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>DESIGN_CONTRACT_PRECHECK_PASS: python -B C:\Users\Administrator\.codex\skills\rtl-model\scripts\validate_design_contract.py --design D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md --schema C:\Users\Administrator\.codex\skills\rtl-model\references\schemas\Module_Schema.md.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>FINAL_DESIGN_REVIEW_handoff_14 SHA256 5704c075e25d411ce64f50f1cda411786dd47e036e7ceb9a9097b7ea040f045c, B12 fully addressed in v1.24. The executable guard is effective_ddc_loss_pre=ddc_epoch_live && chn_en_afe && (!link_ready_afe || !adi_rx_valid(pre-edge)). Layer A now has separate U=0,L=1 enabled-loss rows that set one abort/drop and U=0,L=0 normal-disable/inactive-epoch rows that clear RXD context with no abort/drop. Assertions, coverage, Layer B obligations, A11, pre-edge/FIFO wording and checklist consistently preserve normal shutdown non-abort. FIFO pre-edge pending request, loss-edge one-commit and same-edge FIFO_CLR priority remain unchanged.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>B12 found that the prior Layer A table treated every U=0 as loss despite the established normal-disable non-abort behavior. The L guard resolves the verification-contract contradiction without any datapath, interface or formula change.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC/state/verification artifact was changed. No test was run; this is a design acceptance-contract correction. PPA remains HYPOTHESIS; implementation must produce a v1.24 exact RTL SHA256 before independent review and VMware sanity.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for exact-fingerprint independent FINAL_DESIGN review.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
