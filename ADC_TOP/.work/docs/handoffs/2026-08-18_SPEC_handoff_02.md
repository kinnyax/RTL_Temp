<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_style_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <CONTRIBUTOR_ROSTER>Lead /root; Evidence Researcher /root/adc_decim_evidence, 2026-08-17_EVIDENCE_RESEARCH_handoff_04.md SHA256 4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c; Architecture Analyst /root/adc_phase_arch, 2026-08-18_ARCHITECTURE_handoff.md SHA256 4a8d2740e950eec6649cf65aedce290ecc2617750a99c1d9bd525a94a6be81dd, handoff_02 SHA256 3003f07e41ef9dc5007e9480c34340520b723db5a68b03a8ae2401184884aa62, handoff_03 SHA256 c7543f3518dd11be26d4ea917ed6a993a17b2965ef3f4225338a8bbac0d78051; Design Author /root/adc_style_design_author, DESIGN_AUTHOR_handoff_03 SHA256 fd0dff200bbfe17d8e7e5cc69ab6c8b954f27158f25808e0ae2acef56605a563; Final Design Reviewer /root/adc_style_design_review, FINAL_DESIGN_REVIEW_handoff_03 SHA256 31cef170b400d7fa10cbebf719dfb30ff1072ab2a27eaedafff9be7fb441dd7e; Docs Worker /root/adc_style_design_docs, this handoff. All role identities are distinct except same-role Architecture handoff reuse.</CONTRIBUTOR_ROSTER>
  <USER_DECISION_SOURCE>User-approved 2026-08-18 readability delta: preserve block_cnt/phase_cnt/block_gap/block_end and v1.11 behavior; use exact rxd_buff0/1, rxd_window0/1, and rxd_slice0/1 structure and naming; preserve lane mapping, same-edge mapping/FIFO behavior, and five-stage code organization.</USER_DECISION_SOURCE>
  <DESIGN_PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</DESIGN_PATH>
  <DESIGN_BASELINE_FINGERPRINT>3e1dea49ee3d91d7d3fe7604917b790474be75e505e5244c2877cd4a122ee23a</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_style_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_FINAL_DESIGN_REVIEW_handoff_03.md; SHA256 31cef170b400d7fa10cbebf719dfb30ff1072ab2a27eaedafff9be7fb441dd7e; ACCEPTED</DESIGN_REVIEW>
  <FINALIZATION_STATUS>DESIGN_READY / AWAITING_COMPLETION_CONFIRMATION. Lead and independent Reviewer observed DESIGN_CONTRACT_PRECHECK_PASS for this exact design fingerprint.</FINALIZATION_STATUS>
  <DECISIONS>v1.12 freezes head-coordinate block_cnt with combinational block_end, pre-edge phase_cnt scheduling, 12-bit block_gap and exact gap aliases, two registered 256-bit rxd_buff states, combinational 384-bit rxd_window and 256-bit rxd_slice signals, unchanged lane ordering and same-edge mapping/FIFO behavior, and the five-stage ADC_RXD organization. Software guarantees legal/stable static configuration.</DECISIONS>
  <SOURCES>Finalized design v1.12; Design Author handoff_03; accepted Final Design Review handoff_03; reused Evidence Researcher handoff_04; reused Architecture handoffs, handoff_02 and handoff_03, all at the hashes recorded in CONTRIBUTOR_ROSTER.</SOURCES>
  <ASSUMPTIONS>Software programs only legal static configuration and holds it stable while RXD is active. No RTL-affecting open question remains.</ASSUMPTIONS>
  <PPA_INTENT>HYPOTHESIS. Two lanes retain 512 total registered buffer bits; windows and slices remain combinational. Resource/timing equivalence and the combinational block_end path require downstream synthesis evidence.</PPA_INTENT>
  <MODEL_BOUNDARY>MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT.</MODEL_BOUNDARY>
  <LIFECYCLE_BOUNDARY>All v1.10/v1.11 and earlier RTL Review, READY_FOR_VCS, release-sidecar, lint, simulation and VMware evidence is historical and stale for v1.12. This Docs Worker did not edit RTL/TB/XDC or run VMware, VCS/Verdi, Vivado/XSIM, synthesis, implementation, bitstream, or board validation.</LIFECYCLE_BOUNDARY>
  <RESIDUAL_RISKS>Fresh rtl-vibe must implement and structurally check the exact registered/combinational boundary, NBA visibility at PREF-hit and first PAYL completion, all eight offsets, lane order, mapping/FIFO timing, head-coordinate and phase/gap behavior, then run lint and fresh VMware sanity. Registering a window, using post-shift state, reversing lanes, or changing an offset range changes behavior.</RESIDUAL_RISKS>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_SPEC_handoff_02.md</CHANGED_FILES>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE: module-local readability and state-expression refinement; no separately authorized reusable knowledge change.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT; then a fresh scoped rtl-vibe implementation task for ADC_TOP.</NEXT_OWNER>
</DOCS_HANDOFF>
