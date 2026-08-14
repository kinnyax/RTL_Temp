+<EVIDENCE_HANDOFF>
  <AGENT_ID>/root/adc_upk_evidence</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-13_EVIDENCE_RESEARCH_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <QUESTION_SCOPE>Fixed ADI device-side marker alignment for ADC_TOP's TPL_DATA_PATH_WIDTH=16, M=16, L=2, N'=16, S=1, F=16, K=16 (255/15/15 count-minus-one), and the safe minimization boundary for ADC_RXD unpack control.</QUESTION_SCOPE>
  <SOURCES>
    <SOURCE>
      <TITLE>ADC_TOP accepted design contract v0.7</TITLE>
      <PUBLISHER>ADC_TOP module design</PUBLISHER>
      <DATE>2026-08-12</DATE>
      <PATH>D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md</PATH>
      <ANCHORS>lines 64, 222-235, 406-417, 740, 779, 805</ANCHORS>
    </SOURCE>
    <SOURCE>
      <TITLE>ADI JESD204 RX consolidated source provenance</TITLE>
      <PUBLISHER>Analog Devices, Inc.; local frozen source derived from commit 9d5de2fc21b6069675104567c9041bcdbfbe9baa</PUBLISHER>
      <DATE>imported 2026-07-29</DATE>
      <PATH>D:\Codex\RTL_Temp\ADC_TOP\rtl\ADI_JESD204\ADI_JESD204_RX_PROVENANCE.md</PATH>
      <ANCHORS>deviation items 2-3</ANCHORS>
    </SOURCE>
    <SOURCE>
      <TITLE>jesd204_frame_mark in frozen ADI JESD204 RX source</TITLE>
      <PUBLISHER>Analog Devices, Inc.</PUBLISHER>
      <DATE>frozen local source</DATE>
      <PATH>D:\Codex\RTL_Temp\ADC_TOP\rtl\ADI_JESD204\jesd204_rx.v</PATH>
      <ANCHORS>lines 778-805, 956-983; ADC_RXD ADI instantiation lines 151-216</ANCHORS>
    </SOURCE>
    <SOURCE>
      <TITLE>AC9810-32 JESD204B grouping scenarios</TITLE>
      <PUBLISHER>AC9810 vendor material</PUBLISHER>
      <DATE>2025-03-03 visible workbook revision</DATE>
      <PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx</PATH>
      <ANCHORS>sharedStrings: 16-bit pure-ADC/decimation/DDC scenario headings; sync_word and *0 positional rows; CML ordering labels</ANCHORS>
    </SOURCE>
    <SOURCE>
      <TITLE>Current ADC_RXD and black-box cocotb scoreboard</TITLE>
      <PUBLISHER>ADC_TOP local implementation/test</PUBLISHER>
      <DATE>current workspace bytes read 2026-08-13</DATE>
      <PATH>D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v; D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\test_ADC_TOP.py</PATH>
      <ANCHORS>ADC_RXD lines 261-383, 454-578, 864-916; TB lines 401-419, 1067-1145</ANCHORS>
    </SOURCE>
  </SOURCES>
  <FACTS>
    <FACT confidence="HIGH">The accepted contract fixes the ADI parameters to DATA_PATH_WIDTH=4, TPL_DATA_PATH_WIDTH=16, M=16, L=2, N'=16, S=1, F=16 and K=16; the configured count-minus-one values are 255/15/15. The ADI instantiation contains those exact values.</FACT>
    <FACT confidence="HIGH">The local ADI provenance explicitly records the intentional DATA_PATH_WIDTH=16 marker support and states that, at 255/15/15, SOMF is emitted on octet 0 and EOMF on octet 15 of each 16-beat multiframe.</FACT>
    <FACT confidence="HIGH">In jesd204_frame_mark, DATA_PATH_WIDTH=16 selects DPW_LOG2=4. Its generic power-of-two marker branch assigns somf={{15{1'b0}},cur_somf}. The multiframe counter is reset to zero, asserts cur_somf only when beat_cnt_mf==0, and wraps after cfg_beats_per_multiframe. ADC_RXD drives device_cfg_beats_per_multiframe=15. Thus the device stream's SOMF sequence is 16'h0001 for beat 0 of each 16-beat multiframe and 16'h0000 for the other 15 beats.</FACT>
    <FACT confidence="HIGH">A device beat is 16 octets per lane. With two lanes, ADC_RXD receives 256 bits each afe_clk. The 16-bit SOMF vector identifies octet positions within each lane's 16-octet device beat; it is not a 16-bit numeric counter.</FACT>
    <FACT confidence="HIGH">The AC9810 workbook describes sync_word and zero runs as arrangement entries such as sync_word*4/8/16 and (formula)*0, and labels the subsequent values as channel samples. It therefore specifies framing by position. The accepted contract independently requires that zero-valued payload never be deleted solely by value and that zero-padding removal use epoch, position and configuration.</FACT>
    <FACT confidence="HIGH">Current TB intentionally drives nonzero words through positions discarded as sync/padding and says this proves position-based removal. Its DDC case separately drives nonzero 32-word synchronization prefix and zero 280-word padding before payload. The test only proves the current map against its stimulus, not a board capture.</FACT>
    <FACT confidence="HIGH">For every currently accepted legal runtime configuration, payload_start_word=32+zero_words is divisible by eight 16-bit words: pure ADC is 128; decimation formula terms are multiples of eight; DEC_DEL adjustments are 32*DEC_M or 64*DEC_M. Therefore payload start never lands inside an 8-word, per-lane device beat under the current accepted configuration space.</FACT>
    <FACT confidence="HIGH">The period_words formulas are not universally multiples of eight or sixteen. For example, SMP_MODE=1 and DEC_M mod 4=2 yields 64*N+34. Therefore valid 16-word CML block completion can occur at a nonzero word offset of an afe_clk beat despite the aligned initial payload start.</FACT>
  </FACTS>
  <INFERENCES>
    <INFERENCE>marker_word_offset, marker_word_base, and current_word_base's marker-dependent branch are dead generality for this fixed transport: the only legal marker position is word 0. A reduced epoch acquisition may use marker_present defined as adi_rx_valid &amp; adi_rx_somf[0], initialize the post-marker word count deterministically to 8, and reject/ignore any impossible nonzero SOMF bits as an optional diagnostic rather than supporting offset recovery.</INFERENCE>
    <INFERENCE>initial_payload_offset and payload_pos_initial can be removed without changing accepted behavior because every legal payload_start_word is beat-aligned. The first payload beat can be recognized by equality current_word_base==payload_start_word, and the state for the following beat can be initialized to 8 exactly as the present logic evaluates when offset is zero.</INFERENCE>
    <INFERENCE>The user's intended 'epoch valid plus exclusion of periodword and zeroword' is sound only when exclusion means a positional counter derived from SOMF and selected static configuration. It must not mean deleting 16-bit words whose value is zero, nor searching for a period/sync character by data value: ADC payload may legally equal zero and workbook padding is a positional arrangement.</INFERENCE>
    <INFERENCE>The minimal fixed-transport extractor is: (1) wait for valid SOMF[0] and establish epoch; (2) count eight 16-bit lane words per valid afe_clk beat; (3) skip the fixed/configured prefix by position until payload_start_word; (4) run a modulo-period positional counter; (5) emit only at the selected CML terminal positions, preserving the existing explicit CML reorder/sign-extension and DDC I/Q atomic write rules. This removes marker-offset and first-beat slicing logic while retaining runtime-mode behaviour.</INFERENCE>
    <INFERENCE>lane history, block_end_offset, and the eight slice cases cannot all be removed merely because JESD framing is fixed. They resolve CML payload blocks ending mid-device-beat for supported decimation/DDC periods. They could be simplified only after a separate user decision narrows supported SMP_MODE/DEC_M/DEC_DEL_MODE values so every emitted CML block is device-beat aligned.</INFERENCE>
  </INFERENCES>
  <CONFLICTS>NONE within the fixed transport claim. The historical generic ADI marker limitations are intentionally superseded by the documented local, license-permitted DATA_PATH_WIDTH=16 deviations; this evidence applies to the exact local source, not arbitrary upstream revisions.</CONFLICTS>
  <GAPS>
    <OPEN_QUESTION>There is no board-capture/ILAS-backed evidence in scope proving that the AC9810 controller always begins its framing prefix at this SOMF epoch after all legal elastic-buffer release conditions. The current contract explicitly retains first-board ILAS/controller/wrap mapping as a residual risk.</OPEN_QUESTION>
    <OPEN_QUESTION>The workbook is primary vendor material but spreadsheet extraction alone does not supply a stable visible sheet/cell anchor in this handoff. A future design-freeze revision should cite worksheet name/cell ranges or a rendered source excerpt if it relies on a particular formula beyond those already encoded in the accepted contract.</OPEN_QUESTION>
  </GAPS>
  <RESIDUAL_RISKS>Do not convert the positional padding rule into data-value filtering. Do not claim vendor-equivalent behaviour beyond the local ADI source. Retaining all runtime modes means nonzero terminal offsets remain a necessary implementation concern.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</EVIDENCE_HANDOFF>

