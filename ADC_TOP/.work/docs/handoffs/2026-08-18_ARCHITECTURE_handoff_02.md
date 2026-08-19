<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_phase_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <SELECTION_SOURCE>User's explicit current selection: head positioning because it maps directly to the source workbook/table and is less implicit. This addendum validates that selected architecture; it does not select again.</SELECTION_SOURCE>
  <REQUIREMENTS_USED>
    <REQUIREMENT>Compare the current terminal/tail absolute coordinate with a next-block-head coordinate for fixed 16-word extracted blocks and 8-word AFE beats. Preserve legal pure/single/DDC behavior, 64-bit coordinate width, phase-counter semantics, history/slice behavior, deterministic reset/default recovery, and software-owned legal/stable static configuration.</REQUIREMENT>
    <REQUIREMENT>Do not edit RTL/TB/XDC/design or run verification. The sole output is this immutable architecture addendum.</REQUIREMENT>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c</EVIDENCE_HANDOFF_HASH>
  <CONTEXT_FINGERPRINTS>
    <FINGERPRINT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="a36a502339912c0e105421f539187f8dd674ba06b19a77ed4466ec216c8202eb">Current design observed read-only.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8">Current RTL observed read-only.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff.md" sha256="4a8d2740e950eec6649cf65aedce290ecc2617750a99c1d9bd525a94a6be81dd">This Worker's preceding counter/wrap analysis, reused as background.</FINGERPRINT>
  </CONTEXT_FINGERPRINTS>
  <COORDINATE_DEFINITIONS>
    <FACT>A decoded output block contains exactly 16 consecutive 16-bit words. Let S be its first-word (head/start) absolute coordinate and E be its last-word (tail/end) coordinate. Then E=S+15, so the first block is S=0 and E=15.</FACT>
    <FACT>word_pos_r is the base coordinate of the current 8-word AFE beat. A complete 16-word block is available only when the beat containing E is present in the current-plus-history window, not when the beat containing S first arrives.</FACT>
    <FACT>The current scheduler stores E in next_term_r. By exact user selection, the selected head architecture stores S in the 64-bit state register block_cnt, and the separate 3-bit cycle/output-block index is phase_cnt. block_cnt is an absolute head coordinate by this user-defined naming contract; phase_cnt is not a word coordinate.</FACT>
  </COORDINATE_DEFINITIONS>
  <EXACT_TRANSFORM>
    <TAIL_TO_HEAD>block_cnt = next_term_r - 64'd15. At the current first terminal E=15, the selected first start is S=0.</TAIL_TO_HEAD>
    <HEAD_TO_TAIL>block_end = block_cnt + 64'd15. block_end is the combinational-only availability coordinate used exclusively for terminal-beat detection and existing slice selection; it is not stored.</HEAD_TO_TAIL>
    <RECURRENCE>For any successive decoded blocks i and i+1, E(i+1)=E(i)+G(i) if and only if S(i+1)=S(i)+G(i), because the same constant 15 cancels. Therefore the already evidenced term gaps are exactly the selected start-to-start gaps; no gap formula gains or loses 16 words merely because the coordinate origin changes.</RECURRENCE>
    <INITIALIZATION>Use block_gap as the 12-bit selected start-to-start delta (replacing the terminal-oriented name term_gap in this selected architecture). On the existing RXD_PREF &amp;&amp; payl_hit transition, initialize block_cnt to 64'd0 instead of next_term_r to 64'd15. On !afe_rst_n, rxd_clr, RXD_IDLE, and invalid-FSM recovery, clear it to 64'd0 exactly as the current terminal coordinate is cleared. On RXD_PAYL &amp;&amp; block_complete, update block_cnt &lt;= block_cnt + block_gap. Hold on PREF misses and non-terminal PAYL beats. phase_cnt retains the same independent reset/init/terminal-only advance/wrap behavior specified for the selected output-block index.</INITIALIZATION>
  </EXACT_TRANSFORM>
  <START_GAP_SCHEDULES>
    <ROW><MODE>pure ADC</MODE><FIRST_START>0</FIRST_START><START_TO_START_GAPS>{16}</START_TO_START_GAPS><COUNTER>phase_cnt=0, held by wrap</COUNTER></ROW>
    <ROW><MODE>single f=0</MODE><FIRST_START>0</FIRST_START><START_TO_START_GAPS>{16N}</START_TO_START_GAPS><COUNTER>phase_cnt=0, held by wrap</COUNTER></ROW>
    <ROW><MODE>single f=1</MODE><FIRST_START>0</FIRST_START><START_TO_START_GAPS>{16,16,16,64N-32}</START_TO_START_GAPS><COUNTER>0,1,2,3; wrap after 3</COUNTER></ROW>
    <ROW><MODE>single f=2</MODE><FIRST_START>0</FIRST_START><START_TO_START_GAPS>{16,32N+1,16,32N+1}</START_TO_START_GAPS><COUNTER>0,1,2,3; wrap after 3</COUNTER></ROW>
    <ROW><MODE>single f=3</MODE><FIRST_START>0</FIRST_START><START_TO_START_GAPS>{16,16,16,64N}</START_TO_START_GAPS><COUNTER>0,1,2,3; wrap after 3</COUNTER></ROW>
    <ROW><MODE>DDC f=0</MODE><FIRST_START>0 (I)</FIRST_START><START_TO_START_GAPS>{16,16N-16}</START_TO_START_GAPS><COUNTER>0:I, 1:Q; wrap after 1</COUNTER></ROW>
    <ROW><MODE>DDC f=1</MODE><FIRST_START>0 (I)</FIRST_START><START_TO_START_GAPS>{16,16,16,16,16,16,16,64N-96}</START_TO_START_GAPS><COUNTER>0..7 alternating I/Q; wrap after 7</COUNTER></ROW>
    <ROW><MODE>DDC f=2</MODE><FIRST_START>0 (I)</FIRST_START><START_TO_START_GAPS>{16,16,16,16,16,16,16,32N-32}</START_TO_START_GAPS><COUNTER>0..7 alternating I/Q; wrap after 7</COUNTER></ROW>
    <ROW><MODE>DDC f=3</MODE><FIRST_START>0 (I)</FIRST_START><START_TO_START_GAPS>{16,16,16,16,16,16,16,64N-64}</START_TO_START_GAPS><COUNTER>0..7 alternating I/Q; wrap after 7</COUNTER></ROW>
    <FACT>Examples confirm the transform: single f=2 tail positions {15,31,32N+32,32N+48,64N+49} map to starts {0,16,32N+17,32N+33,64N+34}; the gaps remain {16,32N+1,16,32N+1}. DDC I/Q parity remains a property of the same pre-edge phase_cnt[0], independent of coordinate origin.</FACT>
  </START_GAP_SCHEDULES>
  <COMPLETION_AND_SLICING>
    <FACT>Head arrival is insufficient: if S lies in the current beat, the remaining words of its 16-word block may be in the current and following beats. The correct complete-block event remains the arrival of the beat containing E=S+15.</FACT>
    <REQUIRED_LOGIC>Derive wire [63:0] block_end = block_cnt + 64'd15; then preserve the current shape: block_complete = rxd_fsm_payl &amp;&amp; (word_pos_r[63:3] == block_end[63:3]); block_end_offset = block_end[2:0]. The existing eight slices select from the same 384-bit current-plus-two-history window using block_end_offset.</REQUIRED_LOGIC>
    <OFFSET_TRANSFORM>block_end_offset=(block_cnt[2:0]+3'd7) modulo 8, equivalently block_cnt[2:0]-3'd1 in 3-bit modular arithmetic. The full block_end expression is the least ambiguous implementation contract because its upper bits also determine the availability beat.</OFFSET_TRANSFORM>
    <CYCLE_EQUIVALENCE>For every legal schedule, block_complete fires on exactly the current tail-design cycle, block_end_offset is identical, lane0_block_raw/lane1_block_raw select the identical 256-bit ranges, FIFO-write eligibility is unchanged, and no normal-path latency changes.</CYCLE_EQUIVALENCE>
  </COMPLETION_AND_SLICING>
  <COUNTER_WRAP_AND_DDC>
    <FACT>phase_cnt is unchanged by head tracking. It is initialized to zero on the same paths, advances only after pre-edge block_complete, and uses the already frozen pure/single/DDC wrap truth table.</FACT>
    <FACT>block_is_i = block_complete &amp;&amp; (smp_mode==2) &amp;&amp; !phase_cnt[0] and block_is_q = block_complete &amp;&amp; (smp_mode==2) &amp;&amp; phase_cnt[0] remain exact. Do not derive I/Q from S[0], S[2:0], E, or block_end_offset: f=2 changes start/end offsets across periods while DDC component alternation belongs to phase_cnt.</FACT>
    <FACT>block_gap is the 12-bit selected start-to-start delta and is zero-extended for block_cnt + block_gap. The 64-bit coordinate, no-rebase contract, recovery behavior, DDC pair reservation, abort event, and CDC boundary remain unchanged.</FACT>
  </COUNTER_WRAP_AND_DDC>
  <ARCHITECTURE_COMPARISON>
    <OPTION id="CURRENT_TAIL" name="Store next block end">
      <DESCRIPTION>Store E directly and use it for completion/slice selection. Derived semantic head is E-15 if needed only for documentation/debug.</DESCRIPTION>
      <BENEFITS>Minimum hardware: no per-PAYL availability addition; direct end offset and beat group compare.</BENEFITS>
      <COSTS>The source workbook's naturally indexed group start is implicit, and the name term can conflate a terminal event with the block boundary concept.</COSTS>
    </OPTION>
    <OPTION id="SELECTED_HEAD" name="Store block_cnt and derive block_end">
      <DESCRIPTION>Store S=0 initially in user-selected block_cnt, preserve exact start-to-start gaps, and calculate E=S+15 combinationally for availability/slicing.</DESCRIPTION>
      <BENEFITS>Directly matches source-workbook group indexing and makes the scheduled item visibly the next 16-word block head. It is mathematically and cycle equivalent when the prescribed transform is used.</BENEFITS>
      <COSTS>Requires a constant +15 availability derivation in the PAYL control/slice cone. A naive head comparison without that transform is functionally early and invalid.</COSTS>
    </OPTION>
    <OPTION id="HYBRID_START_END" name="Store head and derive end; or store end and expose derived head">
      <DESCRIPTION>The selected head form is itself the safe hybrid: register only block_cnt and derive block_end=block_cnt+15. The inverse form stores end and exposes start=end-15 only as a semantic/debug wire.</DESCRIPTION>
      <EQUIVALENCE>Both are exact only if all completion/slice consumers use end and all schedule recurrences use the same gap G. Registering both full 64-bit coordinates is unnecessary duplicated state and creates coherence/reset risk.</EQUIVALENCE>
      <TRADEOFF>The head-stored form best satisfies the explicit user selection. The end-stored form is the likely lower-control-cost implementation; neither changes external behavior.</TRADEOFF>
    </OPTION>
  </ARCHITECTURE_COMPARISON>
  <PPA_AND_READABILITY>
    <FACT>Head positioning does not simplify the legal gap formulas: constant translation preserves every recurrence, including source-required single-f1 64N-32 and single-f2 32N+1. It can improve formula names and review language: block_gap, block_cnt, phase_cnt, and block_end express their user-selected purposes directly.</FACT>
    <HYPOTHESIS>The selected head architecture can add a constant-15 adder/carry propagation before the 64-bit beat-group compare and end-offset selection. Synthesis may simplify the constant add, but no timing/area benefit is established. Keeping both start and end as registers avoids the combinational add but adds 64 FFs and coherence logic, which is not justified.</HYPOTHESIS>
    <HYPOTHESIS>The phase-counter PPA/readability conclusion is independent: phase_cnt and its wrap decode replace phase-next machinery; coordinate-origin choice neither changes its 3-bit width nor its decode/wrap cone.</HYPOTHESIS>
  </PPA_AND_READABILITY>
  <VALIDATION_RESULT>
    <STATUS>VALIDATED_FOR_DESIGN_UPDATE</STATUS>
    <BLOCKING_ISSUES>NONE. The selected head-coordinate architecture is cycle equivalent for every legal static smp_mode/fraction configuration when and only when combinational block_end=block_cnt+15 is used for completion and slices, block_cnt starts at zero, the original gaps are retained as start-to-start deltas, and phase_cnt remains the I/Q phase owner.</BLOCKING_ISSUES>
    <REQUIRED_VERIFICATION>Fresh downstream lint/simulation must prove the direct transform at pure, all single/DDC fractions and legal N ranges, first block S=0/E=15, every wrap boundary, f2 cross-period offsets, DDC I/Q parity, rxd_clr/reset/invalid-FSM recovery, and unchanged FIFO/abort behavior. No verification was performed here.</REQUIRED_VERIFICATION>
  </VALIDATION_RESULT>
  <ASSUMPTIONS>
    <ASSUMPTION>Software continues to hold all static configuration fields legal and stable during an active epoch; this addendum defines no behavior for illegal/mid-epoch changes.</ASSUMPTION>
    <ASSUMPTION>Fixed blocks remain 16 words and every accepted AFE beat remains eight words; a future block-width or beat-width change would invalidate the constant 15 transform.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>NONE for the user-selected architecture. PPA remains an implementation measurement question, not a design blocker.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <RISK>Using start directly in block_complete or block_end_offset would issue an incomplete/wrong slice; all availability consumers must use block_end.</RISK>
    <RISK>Changing a start-gap to a zero-run-only quantity would be an off-by-16 regression. Gaps remain distances between successive starts (and identically successive ends).</RISK>
    <RISK>No RTL/TB/XDC/design modification, VMware sanity, VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, or board work was performed.</RISK>
  </RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
