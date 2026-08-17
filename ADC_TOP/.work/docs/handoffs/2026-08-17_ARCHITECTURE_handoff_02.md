<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_decim_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_ARCHITECTURE_handoff_02.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <REQUIREMENT>User-selected conceptual direction: compact E={N[5:0],f[1:0]} decode, explicitly named integer/fraction formulas, a small positive-counting unpack FSM, and simpler names/logic. This is explicit approval of Option A when evidence-compatible.</REQUIREMENT>
    <REQUIREMENT>Preserve fixed JESD parameters, valid-SOMF[0]-only epoch boundary, location-driven zero handling, 384-bit per-lane history/eight slices, existing DDC I/Q pair semantics, DDC abort, CDC, and recovery behavior.</REQUIREMENT>
    <REQUIREMENT>New accepted evidence handoff _04 closes single-decimation r2/r3 positional schedules. No design, RTL, TB, or XDC change is authorized in this role.</REQUIREMENT>
  </REQUIREMENTS_USED>
  <CONTEXT_FINGERPRINTS>
    <FINGERPRINT path="D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md" sha256="62bc9f85b66f7a17f7796d26986a0b2fb475747e0d1650413ae93e84990cca7c">Current v1.5 design, read-only comparison</FINGERPRINT>
    <FINGERPRINT path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" sha256="a2203f25f6ecf3c2cc568d6c912db3510543cdee08f98e71ac03dd1ef380a217">Current RTL, read-only comparison</FINGERPRINT>
  </CONTEXT_FINGERPRINTS>
  <EVIDENCE_HANDOFF_HASH>4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c</EVIDENCE_HANDOFF_HASH>
  <EVIDENCE_REUSE>
    <ITEM path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_EVIDENCE_RESEARCH_handoff_03.md" sha256="65899ac4c0f7eebbbfe1f8749dfe92390bf02e753f5808f3faaf839e0058ea6b">N/f ranges, all DDC schedules, and corrected single f1 terminal gap.</ITEM>
    <ITEM path="D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-17_EVIDENCE_RESEARCH_handoff_04.md" sha256="4898dbf867cf3b97b51c61b66b71447164dd69ffaa51c3a8cb1e618e623b162c">Full single f2/f3 terminal position, gap, period, and offset evidence.</ITEM>
  </EVIDENCE_REUSE>
  <OPTIONS>
    <OPTION id="A" selected="USER_APPROVED" name="Explicit RXD_WAIT_SOMF / RXD_SKIP_PREFIX / RXD_PAYLOAD hybrid">
      <OWNERSHIP>One 2-bit AFE-domain FSM replaces epoch_valid_r and payload_active_r. RXD_WAIT_SOMF owns absence of an epoch; RXD_SKIP_PREFIX owns marker-inclusive padding count; RXD_PAYLOAD owns payload terminal progression. term_phase_r remains a separate 3-bit output-layout phase owner and is not a second receive FSM.</OWNERSHIP>
      <FLOW>WAIT accepts only upk_vld &amp;&amp; adi_rx_somf[0] &amp;&amp; map_vld, clears local coordinates/history, records prefix_beat_r=0 for the SOMF-bearing beat, and enters SKIP. SKIP advances prefix_beat_r only on each later upk_vld. When prefix_beat_r+1 equals payload_start_beat, that accepted beat is the first payload beat: shift it into history, initialize word_pos_r=8, next_term_r=15, term_phase_r=0, and enter PAYLOAD. In PAYLOAD each upk_vld advances word_pos_r by +8; on the one terminal hit, next_term_r advances by positive term_gap and term_phase_r advances forward. !upk_vld, !map_vld, fifo_clr, or !afe_rst_n reset local context to WAIT. A SOMF during SKIP/PAYLOAD is not a substitute realignment path.</FLOW>
      <BOUNDARIES>ADI JESD link adapter, fixed ports, JESD-to-AFE private link_ready CDC, FIFO interface, CHN_SYNC, and ADC_PKT boundary are unchanged. The refactor does not create a new module, FIFO, clock, reset synchronizer, CDC, timeout, retry, or alignment search path.</BOUNDARIES>
      <BENEFITS>Meets the approved readability objective: receive state has exactly one owner and impossible two-flag combinations are eliminated. It preserves throughput of one accepted beat per upk_vld and does not add pair buffering or normal-path wait cycles.</BENEFITS>
      <PPA_INTENT>HYPOTHESIS: control FF/LUT effect is negligible beside 512-bit mapping/slice logic; the value is auditability and lower off-by-one/recovery risk, not claimed area/timing improvement.</PPA_INTENT>
    </OPTION>
    <OPTION id="B" selected="NOT_SELECTED" name="Implicit epoch/payload flags with the compact E decode">
      <COMPARISON>Feasible and potentially equivalent, with the smallest local source delta, but retains two coupled state bits and their reset/invariant burden. It does not directly meet the user-approved small-state-machine direction and has no throughput, CDC, or measured PPA advantage over A.</COMPARISON>
    </OPTION>
    <OPTION id="C" selected="REJECTED" name="Table or microcode scheduler">
      <COMPARISON>Not selected. It duplicates arithmetic/layout knowledge in a selector table, recreates the complexity intentionally removed from v1.4/v1.5 packed-gap handling, and has no demonstrated PPA or verification advantage over direct formulas. The evidence now permits formulas; it does not motivate a table.</COMPARISON>
    </OPTION>
  </OPTIONS>
  <SELECTED_HYBRID_BEHAVIOR>
    <DECODE status="FACT">Use compact factor E[7:0], derive dec_int=E[7:2] and dec_frac=E[1:0] once, and use those names in validity checks and formula branches. E=4N+f; physical values are 8'h04..8'hff. This is an internal decode contract unless the design author separately records a port/register rename.</DECODE>
    <VALIDITY status="FACT">Pure ADC (mode 0): requires valid precision; E and delete mode do not determine framing. Single decimation (mode 1): dec_int=1..63, dec_frac=0..3, delete mode d=0..2; E=4..255. DDC (mode 2): dec_int=2..63, dec_frac=0..3, d=0..2; E=8..255. mode 3, precision 3, d=3, single N=0, and DDC N=0/1 are map_vld=0 and establish no epoch/write.</VALIDITY>
    <PREFIX_FORMULAS status="FACT">Let B(0)=0, B(1)=4E, and B(2)=8E in marker-inclusive AFE beats. payload_start_beat is: pure=16; f0=2N+23+B(d); f1=8N+25+B(d); f2=4N+25+B(d); f3=8N+29+B(d). The maximum is 8*63+29+8*255=2573, so the prefix target/count are 12-bit unsigned per-epoch quantities.</PREFIX_FORMULAS>
    <TERMINAL_FORMULAS status="FACT">
      <PURE>first terminal=15; gaps {16}; period 16.</PURE>
      <SINGLE_F0>first terminal=15; gaps {16N,16N}; phase count 2; period 32N.</SINGLE_F0>
      <SINGLE_F1>first terminal=15; gaps {16,16,16,64N-32}; phase count 4; period 64N+16. The corrected 64N-32 is zero run 64N-48 plus the next 16-word group.</SINGLE_F1>
      <SINGLE_F2>first terminal=15; gaps {16,32N+1,16,32N+1}; phase count 4; period 64N+34. The +1 is source-required repeated terminal-word accounting. Coordinates begin 15,31,32N+32,32N+48,64N+49; offsets begin 7,7,0,0,1 and continue across periods.</SINGLE_F2>
      <SINGLE_F3>first terminal=15; gaps {16,16,16,64N}; phase count 4; period 64N+48. All these initial terminal offsets are 7 modulo 8.</SINGLE_F3>
      <DDC_F0>first terminal=15 (I); gaps {16,16N-16}; I,Q phase count 2; period 16N.</DDC_F0>
      <DDC_F1>first terminal=15 (I); seven gaps of 16 then 64N-96; I,Q,I,Q,I,Q,I,Q phase count 8; period 64N+16.</DDC_F1>
      <DDC_F2>first terminal=15 (I); seven gaps of 16 then 32N-32; I,Q,I,Q,I,Q,I,Q phase count 8; period 32N+80.</DDC_F2>
      <DDC_F3>first terminal=15 (I); seven gaps of 16 then 64N-64; I,Q,I,Q,I,Q,I,Q phase count 8; period 64N+48.</DDC_F3>
    </TERMINAL_FORMULAS>
    <WIDTHS status="FACT">term_gap is unsigned 12 bits: at N=63, 16N=1008, 32N=2016, 64N=4032, and no legal terminal gap exceeds 4032. Zero-extend term_gap into 64 bits for next_term_r addition. prefix_beat_r and payload_start_beat are 12 bits, term_phase_r is 3 bits, and the FSM is 2 bits. word_pos_r and next_term_r remain unsigned 64-bit monotonic lifetime coordinates to preserve the existing explicit no-rebase contract; they are not narrowed merely because individual gaps are bounded.</WIDTHS>
    <DDC_AND_RECOVERY status="FACT">Keep ddc_i_accepted_r. At an I terminal, fifo_wlevel &gt;=2 admits and immediately writes I; otherwise reject the whole pair and generate exactly one existing data-drop event. At Q, write only when the paired I was accepted. Scheduler phase/terminal progression is independent of FIFO capacity. In an active DDC epoch, a link-ready or adi_rx_valid loss sets persistent ddc_abort_afe once, emits its one event, and clears unpack context; FIFO_CLR or AFE reset clears the abort. ddc_abort_afe continues through the existing inverted level CDC and fail-closed ADC_PKT new-packet admission; an already admitted packet remains structurally complete and software discards it in its recovery context.</DDC_AND_RECOVERY>
  </SELECTED_HYBRID_BEHAVIOR>
  <ESSENTIAL_RETAINED_LOGIC>
    <ITEM>Fixed ADI JESD parameters and existing private link_ready CDC.</ITEM>
    <ITEM>Valid-SOMF[0]-only epoch entry and position-based acceptance of zero-valued payload.</ITEM>
    <ITEM>Two stored 128-bit beats plus current 128-bit beat per lane, forming each required 384-bit history window, and all eight explicit end-offset slices. Single f2 proves why offsets cannot be treated as permanently phase-static.</ITEM>
    <ITEM>64-bit word_pos_r/next_term_r positive coordinates, initial terminal 15, one terminal comparison per beat, and forward-only phase advance.</ITEM>
    <ITEM>Existing sample mapping/sign extension, normal-mode FIFO write behavior, DDC I/Q pair rule, DDC abort, data-drop event, FIFO clear, and fail-closed packet-admission semantics.</ITEM>
  </ESSENTIAL_RETAINED_LOGIC>
  <REMOVED_OR_SIMPLIFIED_LOGIC>
    <ITEM>Replace epoch_valid_r and payload_active_r with the explicit three-state FSM; remove epoch_active when history-enable is expressed from FSM state/transition.</ITEM>
    <ITEM>Replace dec_n with dec_int and eliminate duplicate factor interpretation. Do not reintroduce zero_words, marker offset/base, payload_start_word, generalized nonaligned first-payload, packed lookup, or downcount logic.</ITEM>
    <ITEM>Formula intermediate wires may be reduced only when direct mode/fraction expressions remain individually auditable, have explicit 12-bit sizing, and do not turn into a table/microcode selector.</ITEM>
  </REMOVED_OR_SIMPLIFIED_LOGIC>
  <VERIFICATION_BOUNDARY>
    <MATRIX>For modes 0/1/2, test valid SOMF[0], invalid SOMF[15:1], loss of upk_vld, map invalidation, FIFO clear, reset, zero payload, and WAIT/SKIP/PAYLOAD transition ordering.</MATRIX>
    <MATRIX>For single f=0..3, test N=1,2,63 and d=0..2. Match all exact prefix/gap/period/offset formulas, with directed f1 correction and f2 repeated-word/offets 7,7,0,0,1 progression.</MATRIX>
    <MATRIX>For DDC f=0..3, test N=2 and 63 plus rejected N=1, each d=0..2; prove terminal/IQ sequences, 0/1-space atomic pair rejection, >=2-space immediate I/Q writes, and capacity-independent terminal advancement.</MATRIX>
    <MATRIX>Assert prefix maximum 2573, N=63 4032 gap without truncation, positive legal gaps, 12-to-64-bit extension, first terminal 15, at-most-one terminal per 8-word beat, all offset slices 0..7, and no implicit coordinate rebase.</MATRIX>
    <MATRIX>For each DDC fraction, inject loss after a valid epoch before/after I acceptance; prove one abort/drop, no mode-switch bypass, fail-closed new packet admission until FIFO_CLR/AFE reset, and structural completion of an already admitted packet.</MATRIX>
    <BOUNDARY>No verification was run by this analysis. Subsequent verification must use workbook/source vectors for the corrected single f1 and retained f2/f3 schedules; it must not use old RTL as the oracle for the f1 correction. VMware, VCS/Verdi, XSIM, synthesis, implementation, timing, bitstream, and board validation remain unperformed here.</BOUNDARY>
  </VERIFICATION_BOUNDARY>
  <REJECTED_OPTIONS>Option B is feasible but not selected by the user-approved conceptual direction. Option C is rejected because it reintroduces table complexity without a proven advantage.</REJECTED_OPTIONS>
  <RECOMMENDATION>SELECTED_HYBRID_READY_FOR_DESIGN_AUTHOR: adopt Option A exactly as specified above, with direct E integer/fraction decode, 2-bit three-state receive FSM, positive bounded prefix counter, 64-bit terminal coordinates, 12-bit gap arithmetic, and retained history/DDC/recovery contracts. Evidence no longer blocks single f2/f3; no formula behavior remains open at the unpack-scheduler level.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ASSUMPTION>E replaces dec_m semantically inside ADC_RXD; a public register/port rename requires separate design-author documentation.</ASSUMPTION>
    <ASSUMPTION>DEC_DEL_MODE remains d=0..2 and alters prefix only, because no user direction authorizes removing it.</ASSUMPTION>
    <ASSUMPTION>The N bounds establish 2-CML framing-layout validity, not lane-rate/electrical feasibility for a selected ADC-clock/CML system.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>
    <QUESTION priority="NONBLOCKING_SCHEDULER">Evaluate system lane-rate feasibility for every N/f against the selected ADC clock/CML configuration and the workbook rate ceiling.</QUESTION>
    <QUESTION priority="IMPLEMENTATION_DOCUMENTATION">Record whether the physical software field remains named dec_m or is renamed to E/dec_factor; the selected internal semantics do not require an external interface change.</QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>
    <RISK>The old single f1 expression 64N-48 is unsafe; only 64N-32 matches the source terminal layout.</RISK>
    <RISK>A first-payload transition that fails to update history, an incorrectly ordered loss/abort test, or incomplete 12-bit widening can create silent source-order or high-N failures.</RISK>
    <RISK>All PPA statements remain HYPOTHESIS until downstream synthesis/implementation; this analysis performed no verification.</RISK>
  </RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
