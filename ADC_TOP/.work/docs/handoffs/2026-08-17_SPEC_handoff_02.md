<DOCS_HANDOFF>
  <AGENT_ID>/root/adc_decim_design_docs</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_SPEC_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <WORKFLOW_STAGE>DESIGN_READY</WORKFLOW_STAGE>
  <ROLE_ROSTER_RECORDED>TRUE</ROLE_ROSTER_RECORDED>
  <USER_DECISION_SOURCE>2026-08-17 current-task decision: separate integer/fraction decode and small state/counter unpack with positive counting; selected Option A.</USER_DECISION_SOURCE>
  <DESIGN_BASELINE_FINGERPRINT>d3deee993d866e8b31b5a2621c7ccef84f15d0ad34e2a14f61481383d1bc5b16</DESIGN_BASELINE_FINGERPRINT>
  <DESIGN_REVIEW>/root/adc_decim_design_review; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_FINAL_DESIGN_REVIEW_handoff_04.md; SHA256 a6dc45e3b224fd1277a770e6ccc15cb53d6b77cdf6f65feafe8e0ed65a225642; ACCEPTED</DESIGN_REVIEW>
  <CHANGED_FILES>D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Current_State.md; D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_SPEC_handoff_02.md</CHANGED_FILES>
  <FINAL_STATUS>DESIGN_READY; WORKFLOW_STATUS=AWAITING_COMPLETION_CONFIRMATION</FINAL_STATUS>
  <DESIGN_BASELINE>path=D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md; sha256=d3deee993d866e8b31b5a2621c7ccef84f15d0ad34e2a14f61481383d1bc5b16; RTL_MODULE_CONTRACT_V1 / VERILOG_2001_EXPLICIT_V1 / MODIFIED_THIRD_PARTY_RTL / finalized v1.6</DESIGN_BASELINE>
  <CONTRIBUTOR_ROSTER>Lead /root; Evidence /root/adc_decim_evidence (_03 65899ac4c0f7eebbbfe1f8749dfe92390bf02e753f5808f3faaf839e0058ea6b, _04 4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c); Architecture /root/adc_decim_arch (_02 2883efc008f77e23759b33e4dc614743beedfb18c09664736eaa6cc880d524b4); Design Author /root/adc_decim_design_author (_02 268714c079fbe1d23b733c0a4d904da909e772658461fcacac35ef9a03f1eaa7, _03 17c97718b9d5ef80e4a23bcc98b13f240c3ca74ef4052fd02255df0fd15cf1e2, _04 bb25fa4076770345c2833a8e2d6cc22fc4746d2bc1ea670c9d97caf0ee8fe6c7); Final Review /root/adc_decim_design_review (_04 a6dc45e3b224fd1277a770e6ccc15cb53d6b77cdf6f65feafe8e0ed65a225642); Docs /root/adc_decim_design_docs (this handoff hash intentionally not embedded).</CONTRIBUTOR_ROSTER>
  <ACCEPTED_DECISIONS>Option A decodes E=DEC_M into dec_int=N and dec_frac=f while retaining the physical AC9810 FACT boundary. Only RXD_WAIT_SOMF/RXD_SKIP_PREFIX/RXD_PAYLOAD own receive stage. SOMF is marker-inclusive prefix 0; `prefix_beat_r`/`payload_start_beat` are 12-bit positive with maximum 2573 and capture at `(prefix_beat_r+1)==payload_start_beat`. Non-pure payload start is `{2N+23,8N+25,4N+25,8N+29}+B(d)`, B={0,4E,8E}. `term_gap` is 12-bit and max 4032 then zero-extends into 64-bit positive coordinates; single f1 is 64N-32, f2 is {16,32N+1,16,32N+1}, f3 is {16,16,16,64N}; DDC remains frozen by Design section 9.2 with 384-bit history/eight slices. Pre-write cfg_wr_safe=(AFE_EN==0)&amp;&amp;(AFE_IDLE==ff) permits safe same-write static config plus AFE_EN startup; unsafe ADC_CTL static fields/whole FRAME_CFG hold/read back while dynamic fields proceed with OKAY/no-Sticky/software retry.</ACCEPTED_DECISIONS>
  <SOURCES_AND_ASSUMPTIONS>Evidence _03/_04 establish factor/gap legality and endpoint sequences; Architecture _02 and the recorded user decision establish Option A. PPA is HYPOTHESIS. MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT.</SOURCES_AND_ASSUMPTIONS>
  <STALE_EVIDENCE>v1.5 RTL, 11-bit/N=8..24 scheduler, single-f1 64N-48, implicit receive flags, and VMware 13/13 PASS are stale/non-applicable to v1.6. No v1.6 verification is claimed.</STALE_EVIDENCE>
  <RESIDUAL_RISKS>Lane-rate/electrical feasibility, official PHY/FIFO behavior, FIFO clear timing, VMware sanity, VCS/Verdi, Vivado XSIM, synthesis/PPA, implementation/timing, bitstream, and board behavior require later evidence.</RESIDUAL_RISKS>
  <NEXT_TASK>Separate rtl-vibe ADC_TOP task: implement v1.6, create/update matching TB, and obtain fresh VMware sanity evidence; do not reuse v1.5 verification.</NEXT_TASK>
  <KNOWLEDGE_WRITEBACK_CANDIDATE>NONE: implementation evidence pending; no Wiki or Archive writeback authorized.</KNOWLEDGE_WRITEBACK_CANDIDATE>
  <CONFLICT_REPORT>NONE</CONFLICT_REPORT>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</DOCS_HANDOFF>
