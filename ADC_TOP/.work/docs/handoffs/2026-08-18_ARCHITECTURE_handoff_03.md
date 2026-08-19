<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_phase_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff_03.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <SELECTION_SOURCE>User's current approved readability refactor: reorganize ADC_UPK as position scheduling -&gt; completion -&gt; buffer/slice -&gt; channel mapping -&gt; FIFO write, and use rxd_buff-style naming. This addendum validates and recommends the cycle-equivalent form; it does not ask for another selection.</SELECTION_SOURCE>
  <REQUIREMENTS_USED>
    <REQUIREMENT>Current read-only ADC_RXD behavior: two 256-bit per-lane history registers shift one 128-bit accepted beat at a time; each 384-bit combinational window is current lane data concatenated with the corresponding two-beat history; eight explicit block-end-offset slices produce the per-lane 256-bit raw blocks.</REQUIREMENT>
    <REQUIREMENT>Preserve the exact user-selected head-coordinate architecture from addendum _02: block_cnt is the 64-bit next block start coordinate, phase_cnt is the separate 3-bit output-block index, block_gap is the selected start-to-start delta, and combinational-only block_end=block_cnt+15 drives completion and slice offset.</REQUIREMENT>
    <REQUIREMENT>Preserve asynchronous reset, rxd_clr, RXD_IDLE/default clearing, PREF/PAYL buffer enable, current-versus-NBA behavior, slice ranges, FIFO/DDC semantics, one state owner, and all legal static-configuration behavior. Do not modify RTL/TB/XDC/design or run verification.</REQUIREMENT>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c</EVIDENCE_HANDOFF_HASH>
  <CONTEXT_FINGERPRINTS>
    <FINGERPRINT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="f11d7864cb4aff39e7777ad22b4c6829c16ba891ef951f29ebd153a61705e8ff">Current v1.11 design observed read-only. It records the selected block_cnt/phase_cnt head-coordinate contract and makes prior review stale for this new readability delta.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="416855dfa9c7abfe3482e32597531e2a68a41f54572255521e3edb540502d4a8">Current pre-refactor RTL observed read-only.</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff_02.md" sha256="3003f07e41ef9dc5007e9480c34340520b723db5a68b03a8ae2401184884aa62">Accepted head-coordinate transform reused.</FINGERPRINT>
  </CONTEXT_FINGERPRINTS>
  <CURRENT_BEHAVIOR>
    <FACT>For lane 0, current state is lane0_history_r[255:0]. Before an accepted PREF/PAYL edge it contains two previous 128-bit lane-0 beats ordered {previous_beat, two_beats_old}. The same relation holds for lane1_history_r and adi_rx_data[255:128].</FACT>
    <FACT>At a PRE-edge with current lane-0 beat C, the slice logic reads lane0_window={C,lane0_history_r}; this is a 384-bit {current, previous, two_beats_old} window. At the subsequent clock edge, nonblocking assignment replaces state with {C,lane0_history_r[255:128]}. Thus the current beat is available to the slice before the sequential buffer updates.</FACT>
    <FACT>The buffer clears on !afe_rst_n, rxd_clr, and any state other than RXD_PREF/RXD_PAYL. It shifts exactly when the current state is RXD_PREF or RXD_PAYL and rxd_clr is false. Since rxd_clr=!upk_vld||fifo_clr has priority, every actual shift corresponds to an accepted AFE beat.</FACT>
    <FACT>At PREF hit, the hit beat is shifted into history on that edge. In the following PAYL beat, the window contains that first payload beat as history plus the current next beat, so the first complete 16-word block and all later slices retain their existing cycle behavior.</FACT>
  </CURRENT_BEHAVIOR>
  <OPTIONS>
    <OPTION id="A" name="Two 256-bit rxd_buff state registers plus combinational windows" selected="USER_APPROVED_SAFE_REFACTOR">
      <STATE>reg [255:0] rxd_buff0; reg [255:0] rxd_buff1. rxd_buff0 holds lane0's two preceding accepted 128-bit beats; rxd_buff1 holds lane1's. Bits [255:128] are the immediately previous beat and [127:0] are the beat before it.</STATE>
      <WINDOWS>wire [383:0] rxd_window0={adi_rx_data[127:0],rxd_buff0}; wire [383:0] rxd_window1={adi_rx_data[255:128],rxd_buff1}.</WINDOWS>
      <UPDATE>One AFE-clocked buffer-state block retains exact priority: !afe_rst_n clear; rxd_clr clear; rxd_fsm_pref||rxd_fsm_payl shift rxd_buff0&lt;={adi_rx_data[127:0],rxd_buff0[255:128]} and rxd_buff1&lt;={adi_rx_data[255:128],rxd_buff1[255:128]}; otherwise clear.</UPDATE>
      <EQUIVALENCE>Pure renaming/reorganization of the existing two 256-bit state registers and two 384-bit combinational windows. FF state, current-cycle slice input, reset/clear behavior, and all eight range selections are identical.</EQUIVALENCE>
      <PPA>HYPOTHESIS: equal registered storage (512 FF total across both lanes) and equivalent concatenation/mux logic. No timing or area improvement claim is made.</PPA>
    </OPTION>
    <OPTION id="B" name="One 384-bit registered rxd_buff per lane">
      <STATE>Store three old 128-bit beats per lane, normally requiring rxd_buff_nx={current,rxd_buff[383:128]} so current data still reaches the slice in the intended cycle.</STATE>
      <EQUIVALENCE>Feasible only when the slice reads the combinational next buffer, not the registered old buffer. Reading the register directly moves the current beat out of the window and is one beat late. The oldest registered 128-bit segment is discarded by each next-state construction and is not needed by a 16-word slice.</EQUIVALENCE>
      <COSTS>Adds 256 FF total versus A (two lanes times one unnecessary 128-bit segment), adds a wide next-state net, and makes current-versus-NBA intent less obvious.</COSTS>
      <PPA>HYPOTHESIS: worse or neutral in FF, routing, and switching; no functional/readability benefit over A for a three-beat combinational window.</PPA>
    </OPTION>
    <OPTION id="C" name="Two explicit 128-bit historical beat registers per lane">
      <STATE>Per lane, a recent and an older 128-bit register update recent&lt;=current and older&lt;=recent. The window is {current,recent,older}.</STATE>
      <EQUIVALENCE>Cycle-equivalent when both registers share the exact existing clear/enable priority and nonblocking semantics.</EQUIVALENCE>
      <COSTS>Same 512 FF total as A but doubles named state per lane and exposes beat ordering/clear ordering in four assignments. It is more verbose than the requested compact rxd_buff representation.</COSTS>
      <PPA>HYPOTHESIS: synthesis likely implements storage equivalently to A; no measured benefit.</PPA>
    </OPTION>
  </OPTIONS>
  <RECOMMENDED_SELECTED_IMPLEMENTATION>
    <STATUS>VALIDATED_FOR_DESIGN_UPDATE</STATUS>
    <NAMES>Use exactly rxd_buff0 and rxd_buff1 for the 256-bit registered histories, rxd_window0 and rxd_window1 for the 384-bit combinational views, and rxd_slice0 and rxd_slice1 for the 256-bit per-lane outputs of the explicit eight-way slice case. Keep mapped_raw and mapped_data for the following channel-mapping stage. Numbers 0/1 retain the existing lane mapping: lane0=adi_rx_data[127:0] and lane1=adi_rx_data[255:128].</NAMES>
    <NO_NEXT_BUFFER>Do not create rxd_buff0_nx/rxd_buff1_nx. In Option A the only normal next value is the directly readable shift concatenation in the single sequential owner; a 256-bit *_nx net has no consumer other than that assignment, does not represent the required 384-bit current-plus-history slice window, and invites an incorrect slice to use post-shift rather than pre-edge data. rxd_buff*_nx is required only by the rejected 384-bit-state Option B.</NO_NEXT_BUFFER>
    <PIPELINE_ORGANIZATION>
      <STAGE>1. Position scheduling: decode/prefix, block_cnt, phase_cnt, block_gap, and combinational block_end.</STAGE>
      <STAGE>2. Completion: block_complete, block_is_i, block_is_q, and block_end_offset, all derived using block_end rather than block_cnt directly.</STAGE>
      <STAGE>3. RXD buffer/slice: rxd_buff0/1 sequential owner; rxd_window0/1 combinational views; rxd_slice0/1 eight explicit end-offset selections.</STAGE>
      <STAGE>4. Channel mapping: map rxd_slice0/1 into mapped_raw, then apply the existing sample-format mapping to mapped_data.</STAGE>
      <STAGE>5. FIFO write: retain normal/DDC eligibility, DDC I/Q reservation, drop/abort, and existing write/event sequential behavior.</STAGE>
    </PIPELINE_ORGANIZATION>
    <BLOCKING_ISSUES>NONE. Option A is a safe cycle-equivalent readability refactor provided the exact buffer/window/slice relations and priority remain as specified.</BLOCKING_ISSUES>
  </RECOMMENDED_SELECTED_IMPLEMENTATION>
  <CYCLE_EQUIVALENCE_GUARDRAILS>
    <ITEM>The slice case must read rxd_window0/1, never rxd_buff0/1 directly. Its eight ranges remain exactly [271:16], [287:32], [303:48], [319:64], [335:80], [351:96], [367:112], and [383:128] for offsets 0 through 7 respectively, on each lane.</ITEM>
    <ITEM>Keep rxd_window0/1 combinational with current adi_rx_data at the most significant 128 bits. Do not register the window, and do not shift the buffer before forming the current-cycle slice.</ITEM>
    <ITEM>Keep block_complete and block_end_offset upstream of the buffer/slice section and retain block_end=block_cnt+64'd15. No slice or FIFO decision may use block_cnt directly as an end coordinate.</ITEM>
    <ITEM>Keep both buffers in one sequential owner (one always block may own both lanes) with existing asynchronous AFE reset, rxd_clr priority, RXD_PREF/RXD_PAYL enable, and IDLE/default clear. Do not add an enable, clock, reset synchronizer, CDC, FIFO, or normal-path cycle.</ITEM>
    <ITEM>Keep the mapping and FIFO writers reading the pre-edge combinational slice/mapped data on the completion edge. NBA updating rxd_buff0/1 after that edge must not alter the accepted output block.</ITEM>
  </CYCLE_EQUIVALENCE_GUARDRAILS>
  <VERIFICATION_IMPACT>
    <REQUIRED>Fresh implementation review/lint/simulation must compare rxd_window0/1 and rxd_slice0/1 against the pre-refactor reference at every legal block_end_offset 0..7, including the single-f2 cross-period offset progression.</REQUIRED>
    <REQUIRED>Directed reset/rxd_clr/IDLE/PREF/PAYL tests must show both buffers clear or shift exactly as before; specifically cover the PREF hit beat, first PAYL completion, non-terminal PAYL hold of schedule state while buffer still shifts, and DDC I/Q completion/FIFO decisions on the same edge.</REQUIRED>
    <REQUIRED>Check that rxd_buff0/1 are the only registered buffer states, rxd_window0/1 are combinational, rxd_buff*_nx is absent, and no slice/Mapped/FIFO datapath becomes one beat late.</REQUIRED>
    <BOUNDARY>No RTL, TB, XDC, verification, VMware, VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, or board validation was performed by this analysis.</BOUNDARY>
  </VERIFICATION_IMPACT>
  <ASSUMPTIONS>
    <ASSUMPTION>Accepted AFE beat width remains 128 bits per lane and extracted block width remains 256 bits per lane; these are the reasons the buffer state is two beats (256 bits) and the combinational window is three beats (384 bits).</ASSUMPTION>
    <ASSUMPTION>User's rxd_buff naming request is the specific readability exception to the normal _r suffix convention for ordinary DFF outputs; all other naming/interface rules remain unchanged.</ASSUMPTION>
    <ASSUMPTION>Software continues to supply legal, stable static configuration during active epochs; this readability refactor does not define or handle illegal configurations.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>NONE. The user already approved the safe readability refactor, and the specified Option A has no behavior-affecting unresolved choice.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <RISK>A use of registered rxd_buff in place of combinational rxd_window, or a use of a post-shift next state for current slice selection, shifts data timing and is functionally unsafe.</RISK>
    <RISK>Option B's 384-bit storage and Option C's four explicit beat registers are feasible but unnecessary alternatives; adopting either after this approval would add review/verification surface without a stated benefit.</RISK>
    <RISK>PPA remains HYPOTHESIS until fresh synthesis on the selected RTL. Existing v1.11 design/review and prior RTL/VMware evidence are stale for this additional readability delta.</RISK>
  </RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
