<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_upk_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-13_ARCHITECTURE_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <ITEM>Fixed local ADI transport only: DATA_PATH_WIDTH=4, TPL_DATA_PATH_WIDTH=16, M=16, L=2, N'=16, S=1, F=16, K=16; device count-minus-one configuration 255/15/15.</ITEM>
    <ITEM>Preserve all accepted pure-ADC, decimation, and DDC maps; static configuration validity; SOMF-based old/new epoch isolation; current 512-bit FIFO payload format; signed-extension and CML lane reorder.</ITEM>
    <ITEM>Keep payload/padding interpretation positional. A legitimate ADC word with value zero must never be deleted by value.</ITEM>
    <ITEM>User requests removal of dead fixed-transport generality and asks whether normal FIFO writes can be unconditional while retaining the DATA_DROP diagnostic in a simpler form.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb</EVIDENCE_HANDOFF_HASH>
  <FACTS>
    <FACT>At the fixed local ADI parameters, a valid SOMF is exactly 16'h0001 once per 16 valid device beats; nonzero SOMF[15:1] cannot occur in the supported transport.</FACT>
    <FACT>Each valid afe_clk beat carries eight 16-bit words per lane. Every accepted payload_start_word is divisible by eight, so payload never starts inside a device beat.</FACT>
    <FACT>Some accepted period_words values are not multiples of eight. A CML block can therefore end at word offset 0 through 7 of a device beat. Lane history, block_end_offset, and the eight block slices remain needed if all currently legal runtime modes are retained.</FACT>
    <FACT>The selected PUB FIFO has WC=0: it forms internal write-enable as winc &amp; ~full, and reports overflow as winc &amp; full. Thus an asserted request at full is safely rejected by the FIFO and produces its native overflow event.</FACT>
    <FACT>wlevel is writer-domain remaining capacity. In the selected FIFO, wlevel &gt;= 2 implies full=0. After a DDC I write has reserved two free slots, only this same writer can consume one of them before the matched Q write; synchronized reader progress can only increase free space.</FACT>
  </FACTS>
  <OPTIONS>
    <OPTION id="A">
      <NAME>Fixed-SOMF targeted simplification with split normal/DDC FIFO policy</NAME>
      <BOUNDARY_AND_FLOW>Wait for adi_rx_valid &amp;&amp; adi_rx_somf[0]. Set epoch_valid_r and word_epoch_r=8 for the following beat; subsequent valid beats add eight. Enter payload only when word_epoch_r equals payload_start_word. Retain positional modulo-period logic, terminal matching, block_end_offset, lane history/window, map reorder and sign extension. Normal pure-ADC/decimation block_complete always requests a FIFO write. DDC accepts I only when fifo_wlevel &gt;= 2, latches ddc_i_accepted_r, then writes Q unconditionally when that reservation is present.</BOUNDARY_AND_FLOW>
      <REMOVABLE_CLASSES>marker_word_offset register and priority encoder; marker_present as OR-reduction; marker_word_base; current_word_base marker-dependent mux; initial_payload_hit range test; initial_payload_offset; payload_pos_initial; all nonzero-SOMF recovery behavior; fifo_full input to ADC_RXD; normal FIFO-full qualification; DDC Q fifo_full qualification; normal-mode data_drop branch. If DATA_DROP is specified as deliberate whole-pair rejection only, the Q-side !ddc_i_accepted_r branch can also be removed and a single pulse occurs at rejected I.</REMOVABLE_CLASSES>
      <RETAINED_CLASSES>adi_rx_somf[0] marker qualification, adi_rx_valid/link/enable/config guards, word_epoch_r, epoch_valid_r, payload_active_r, payload_pos_r, map_config_valid, period and terminal calculations, all eight positional offsets/slices and histories, ddc_i_accepted_r, fifo_wlevel input, FIFO native overflow output/sticky path.</RETAINED_CLASSES>
      <CDC_BUFFERING>Unchanged. All new/retained state remains in afe_clk/afe_rst_n. FIFO retains its current async boundary. Removing fifo_full removes only an AFE-domain status input; it adds no CDC.</CDC_BUFFERING>
      <BEHAVIOR_AND_RECOVERY>Preserves valid-data ordering, configuration gating, link/reset discard, and the existing output format. Invalid/missing SOMF still prevents epoch acquisition. A nonzero SOMF[15:1] may be ignored as impossible or exposed as a future diagnostic, but must not be treated as an alternate alignment.</BEHAVIOR_AND_RECOVERY>
      <FIFO_DIAGNOSTICS>Normal mode deliberately attempts a write at full: native FIFO overflow reports the rejected block. DATA_DROP reports only deliberate DDC whole-pair rejection at I when fewer than two slots are available; it is not a duplicate of native overflow. DDC avoids half-pair admission because its I reservation guarantees Q capacity.</FIFO_DIAGNOSTICS>
      <PPA_HYPOTHESIS>Removes a marker priority tree, two 16-bit marker-base datapaths, range/subtract initial-offset datapath, fifo_full fanout and related event muxing. It does not remove the larger mapping/sign-extension network or mid-beat assembly mux. Net area/timing improvement is expected but unmeasured.</PPA_HYPOTHESIS>
      <STATE_LATENCY_AND_VERIFICATION>State decreases only by dead alignment state; latency and externally visible payload sequence stay unchanged. Verification must retain all three mode scoreboards and add/check SOMF[0]-only acquisition, payload beat alignment, nonzero payload in skipped prefix/padding, normal full native-overflow without DATA_DROP, and DDC one-event whole-pair discard with no partial I/Q FIFO record.</STATE_LATENCY_AND_VERIFICATION>
    </OPTION>
    <OPTION id="B">
      <NAME>More aggressive beat-index/period-counter redesign</NAME>
      <BOUNDARY_AND_FLOW>Replace word_epoch_r and payload_pos_r with a multiframe beat index plus a dedicated post-prefix modulo-period counter, derived from SOMF[0]. The counter increments by eight words per valid device beat; terminal positions generate CML assembly requests. FIFO policy can be the same as Option A.</BOUNDARY_AND_FLOW>
      <BENEFIT>It makes the fixed 16-beat multiframe and eight-word beat visually explicit, and could reduce some 16-bit comparison widths after proving maximum prefix/period ranges.</BENEFIT>
      <COST_AND_RISK>It still needs a word-granular modulo-period representation because terminal positions may fall mid-beat. It must retain the same eight end-offset cases and lane history. Converting epoch position into separate beat and word counters introduces equivalent wrap/transition state and substantially changes the proven control implementation for little functional removal.</COST_AND_RISK>
      <PPA_HYPOTHESIS>Potentially similar or slightly smaller counter arithmetic than A, but not demonstrably better after required wrap decode and comparison logic. Timing/area is unmeasured.</PPA_HYPOTHESIS>
      <VERIFICATION_IMPACT>Requires a new reference model for prefix-to-payload transition and all period wrap positions, beyond re-baselining the current scoreboard. Higher regression and maintenance risk than A.</VERIFICATION_IMPACT>
    </OPTION>
    <OPTION id="C">
      <NAME>Value-based sync/zero filter or reduced supported-mode set</NAME>
      <BOUNDARY_AND_FLOW>Either discard words whose value equals a presumed sync/zero character, or restrict allowed decimation/DDC configurations until terminal boundaries always align to a device beat.</BOUNDARY_AND_FLOW>
      <STATUS>REJECTED for the stated preservation requirement.</STATUS>
      <REASON>Value filtering destroys legal zero-valued ADC payload and does not represent the vendor workbook's positional arrangement. Restricting modes changes the public configuration contract and still needs a user decision plus revised register/verification requirements. Neither is a transparent fixed-transport cleanup.</REASON>
      <PPA_HYPOTHESIS>A reduced-mode variant could remove some offset/history logic only after formally excluding the affected runtime modes; value filtering is small but functionally incorrect.</PPA_HYPOTHESIS>
    </OPTION>
  </OPTIONS>
  <REJECTED_OPTIONS>Option C is not compatible with the accepted runtime-mode and zero-payload requirements. Option B remains feasible but has no evidence-backed PPA advantage over Option A and expands behavioral regression scope.</REJECTED_OPTIONS>
  <RECOMMENDATION>Conditional recommendation: if the user wants the smallest behavior-preserving ADC_RXD delta, select Option A. It directly implements the fixed SOMF[0]/beat-aligned-prefix facts while retaining the necessary mid-beat CML assembly. Its FIFO policy separates two meanings: normal-mode loss is the FIFO's own native overflow, whereas DATA_DROP is one intentional DDC pair rejection at I when wlevel is below two. This permits removal of ADC_RXD fifo_full but retains fifo_wlevel and ddc_i_accepted_r. Do not select an unconditional DDC write policy unless the user explicitly accepts possible lone-I/lone-Q corruption at a full FIFO.</RECOMMENDATION>
  <ASSUMPTIONS>
    <ASSUMPTION>The selected PUB async_fifo behavior remains WC=0 and its documented full/wlevel behavior is retained until later official-IP integration proves an equivalent contract.</ASSUMPTION>
    <ASSUMPTION>Static mode/configuration cannot change while the channel is active, as required by the accepted module contract.</ASSUMPTION>
    <ASSUMPTION>For a legal DDC stream, I/Q terminal events occur in the expected pairing order; link/epoch invalidation clears ddc_i_accepted_r before an old pending I can pair with a new epoch Q.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>
    <OPEN_QUESTION>If DATA_DROP is retained, should an impossible Q without a previously accepted I be a separate protocol diagnostic, or should DATA_DROP mean only the single deliberate I-side pair rejection? The recommended minimal semantics are the latter; current code pulses in both situations.</OPEN_QUESTION>
    <OPEN_QUESTION>First-board ILAS/controller capture must still confirm that the AC9810 prefix is anchored to the observed SOMF epoch; this simplification relies on that existing residual assumption.</OPEN_QUESTION>
  </OPEN_QUESTIONS>
  <RESIDUAL_RISKS>All PPA claims are hypotheses until synthesis. No architecture here validates the Vivado FIFO replacement or actual PHY/GTH behavior. Removing normal-mode DATA_DROP changes only that diagnostic's meaning/visibility; native FIFO overflow still reports every attempted normal write at full. The future testbench must not use FIFO overflow as evidence that a DDC pair was atomically discarded; it must check pair integrity directly.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
