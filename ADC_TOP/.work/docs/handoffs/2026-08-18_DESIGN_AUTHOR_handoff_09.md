<DESIGN_AUTHOR_HANDOFF>
  <AGENT_ID>/root/adc_accum_design</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_DESIGN_AUTHOR_handoff_09.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <USER_DECISION_SOURCE>Current request based on batch4 report ADC_TOP_vmware_batch_2026-08-18_291d275b.md: revoke v1.16 fixed two-beat data-only pipeline; freeze same-AFE-edge raw adi_rx_data/adi_rx_valid/adi_rx_somf consumption and marker-inclusive prefix; retain four-state region/two-beat buffers; freeze registered fifo_wr_valid request then next-edge async FIFO sampling; retain DDC recovery assertions and require per-edge abort/FIFO diagnosis.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>7a7d6ad09c9a75682190aa7a211eee5ed463149ac57d0bbc3b71ea2cea03312a</DESIGN_BASELINE_FINGERPRINT>
  <SCHEMA_SELF_CHECK>DESIGN_CONTRACT_PRECHECK_PASS: python -B C:\Users\Administrator\.codex\skills\rtl-model\scripts\validate_design_contract.py --design D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md --schema C:\Users\Administrator\.codex\skills\rtl-model\references\schemas\Module_Schema.md.</SCHEMA_SELF_CHECK>
  <CORRECTION_BATCH>Grouped batch4 correction: v1.18 removes all normative fixed data-only pipeline requirements and freezes direct same-edge raw input/marker use. It defines raw marker tag0x1000 as prefix beat0, payload P0/P1 at skip_num/skip_num+1, registered fifo_wr_data/fifo_wr_valid on P1 terminal15, and async_fifo sampling at the following AFE edge. A9/A10/A11 and assertion/coverage contract now require raw-boundary, first-terminal, request/sample, DDC abort and FIFO per-edge evidence. Manifest correction is provenance-only.</CORRECTION_BATCH>
  <OPEN_QUESTIONS>NONE. Static configuration remains software guaranteed. batch4 diagnostically disproves the prior fixed delay hypothesis; it does not change dec/ddc formulas or require ADI/TB expected changes.</OPEN_QUESTIONS>
  <CONFLICT_REPORT>Prior v1.16/v1.17 data-only two-beat pipeline interpretation conflicts with batch4 REGION_COORD, where first raw SOMF, prefix tag0x1000 and raw valid coincide while d1/d2 are unprimed. The current user instructs direct raw boundary; this supersedes that prior design hypothesis.</CONFLICT_REPORT>
  <RESIDUAL_RISKS>No RTL/TB/XDC/state/verification artifact was changed. batch4 has 13 pass/3 fail and is diagnostic input only; it is not VMWARE_SANITY_PASS, VCS, XSIM, synthesis, implementation or board evidence. PPA remains HYPOTHESIS.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT for deterministic precheck routing and independent FINAL_DESIGN review of exact v1.18 candidate fingerprint.</NEXT_OWNER>
</DESIGN_AUTHOR_HANDOFF>
