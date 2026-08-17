<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_upk_arch</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-14_ARCHITECTURE_handoff_04.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <REQUIREMENTS_USED>
    <ITEM>Review five user concerns: encoded JESD state CDC, JESD-to-AFE CDC ownership, one semantic unpack-valid wire, payload locator simplification, and correct-case/minimum-hardware error recovery.</ITEM>
    <ITEM>Compare committed READY_FOR_VCS baseline fc86341 with current working ADC_RXD. Preserve current user-authored `prec_vld`, `dec_vld`, `map_vld` naming/format refactor as functional input; do not overwrite or redesign it.</ITEM>
    <ITEM>Preserve fixed ADI transport, all three legal runtime modes, positional zero/prefix discard, mid-beat block completion, DDC I/Q classification, conservative DDC abort, WC=0 and current FIFO payload format.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASHES>
    <HASH role="Evidence Researcher">233e6b4f6dc83cd672646280440e99e3e4d55348b434ff83d1af1ef0aee5c8bb</HASH>
    <HASH role="Prior Architecture">2053fe0e4a78c3de7ce05db1f64f91c2f4710fa3c1194abd4bda665af4dd43d2</HASH>
  </EVIDENCE_HANDOFF_HASHES>
  <FACTS>
    <FACT>`adi_status_state[1:0]` is `status_ctrl_state` from the ADI link control state register clocked by `jesd_clk`. ADC_RXD currently forwards it to CHN_SYNC, where `levels_sync` independently samples both bits into adc_clk; ADC_SYNC then independently samples the vector again into sys_clk.</FACT>
    <FACT>ADI states are a binary encoded control state, not independent flags. A transition such as 2'b01 to 2'b10 can be observed as a torn intermediate code when the two bits are synchronized independently.</FACT>
    <FACT>`link_ready` is already decoded in the JESD source domain from `adi_status_state==3`, lane-ready, PHY-lock/reset-done and enable, then crossed as a single-bit level. This is the correct low-PPA CDC pattern for functional control.</FACT>
    <FACT>Current JESD-to-AFE functional CDC is chiefly `link_ready` into the unpack/device side. ADI itself owns the wide JESD-to-device data elastic-buffer CDC. `link_ready_afe` is consumed only by ADC_RXD AFE logic.</FACT>
    <FACT>The repeated condition `!chn_en_afe || !link_ready_afe || !adi_rx_valid` means the current AFE beat cannot advance unpack state. It is distinct from configuration validity (`map_vld`) and epoch validity (`epoch_valid_r`).</FACT>
    <FACT>All legal payload starts are divisible by eight lane words, so prefix/sync/zero discard can be counted in complete AFE beats after SOMF. Padding must remain positional; zero-valued ADC samples are legal data.</FACT>
    <FACT>Legal terminal positions can end at any offset 0 through 7 of an AFE beat. Therefore the lane history/window and eight extraction slices cannot be removed while all legal decimation/DDC settings remain supported.</FACT>
    <FACT>Current payload decode expands eight modulo-period positions and compares each against up to eight terminal positions plus four Q positions. Accepted terminal spacing is at least one 16-word block, so no legal beat contains two block completions.</FACT>
  </FACTS>
  <DECISION_1_ENCODED_STATE_CDC>
    <OPTION id="1A">
      <NAME>Keep only JESD-source decoded single-bit functional flags across CDC</NAME>
      <FLOW>Keep `adi_status_state` local to jesd_clk. Cross `link_ready` and existing error/event flags only. Software uses LINK_READY plus sticky error/lane diagnostics; the 2-bit JESD_STATE field is removed, reserved, or reduced to a documented 0/not-ready and 3/ready view generated from coherent single-bit link_ready.</FLOW>
      <CDC>PUB `level_sync` for each independent level; pulse synchronizers for events. No encoded bus CDC.</CDC>
      <PPA_HYPOTHESIS>Smallest and safest: removes two-stage 2-bit state-vector CDC and downstream state bus wiring. Unmeasured until synthesis.</PPA_HYPOTHESIS>
      <LIMITATION>Software loses exact transient RESET/WAIT/CGS/DATA debug state unless the register field is redefined.</LIMITATION>
    </OPTION>
    <OPTION id="1B">
      <NAME>Coherent requested snapshot of exact 2-bit JESD state</NAME>
      <FLOW>On a software/ADC request, capture state in jesd_clk, hold the 2-bit bus stable, transfer request/acknowledge, then sample the stable bus in the destination. Snapshot age and request latency are explicit.</FLOW>
      <CDC>Bundled-data handshake; never independent bit synchronization.</CDC>
      <PPA_HYPOTHESIS>Several state bits and handshakes per channel; more area and verification than the diagnostic value normally warrants.</PPA_HYPOTHESIS>
    </OPTION>
    <RECOMMENDATION>Select 1A unless software genuinely requires all four transient link states. `levels_sync` is acceptable for independent lane flags but not for this encoded state.</RECOMMENDATION>
  </DECISION_1_ENCODED_STATE_CDC>
  <DECISION_2_CDC_OWNERSHIP>
    <OPTION id="2A">
      <NAME>Move JESD-to-AFE link_ready synchronization inside ADC_RXD</NAME>
      <FLOW>ADC_RXD derives `link_ready_jesd` in jesd_clk and immediately instantiates one `level_sync` to produce its private `link_ready_afe` under afe_clk/afe_rst_n. Organize sections as ADI/JESD, JESD-to-AFE CDC, payload decode/unpack, FIFO output.</FLOW>
      <BOUNDARY>CHN_SYNC retains ADC-facing crossings: ADC enable to JESD/AFE, independent JESD/AFE status/events to ADC, FIFO status, and data-drop/admit signals. ADI internal data CDC stays untouched.</BOUNDARY>
      <RESET_CORRECTNESS>Destination reset is `afe_rst_n`; JESD source logic remains under `jesd_rst_n`. No business reset or new synchronizer is introduced.</RESET_CORRECTNESS>
      <PPA_HYPOTHESIS>Same synchronizer hardware, fewer external ports/wires and clearer ownership.</PPA_HYPOTHESIS>
    </OPTION>
    <OPTION id="2B">
      <NAME>Retain all channel CDC in CHN_SYNC</NAME>
      <BENEFIT>Single audit location.</BENEFIT>
      <COST>Creates an output-to-wrapper-to-input loop for a signal used only inside ADC_RXD and obscures the JESD-to-AFE data-flow boundary.</COST>
    </OPTION>
    <RECOMMENDATION>2A is the clearer boundary. Move only ADC_RXD-private JESD-to-AFE CDC; do not move unrelated JESD-to-ADC or AFE-to-ADC crossings merely for locality.</RECOMMENDATION>
  </DECISION_2_CDC_OWNERSHIP>
  <DECISION_3_SEMANTIC_VALID>
    <SELECTED_NAME>`upk_vld`</SELECTED_NAME>
    <EXACT_DEFINITION>`upk_vld = chn_en_afe &amp;&amp; link_ready_afe &amp;&amp; adi_rx_valid`.</EXACT_DEFINITION>
    <USAGE>Use `!upk_vld` for epoch, payload-position, history and DDC-pair state clearing; use `upk_vld` to qualify accepted unpack/FIFO-write progress. Keep `map_vld`, `prec_vld`, `dec_vld`, `epoch_valid_r` and `marker_present` separate because they describe different contracts.</USAGE>
    <DDC_ABORT>`ddc_epoch_live &amp;&amp; !upk_vld` is equivalent to link/data loss because ddc_epoch_live already requires chn_en_afe. This keeps intentional channel disable outside the abort set condition.</DDC_ABORT>
  </DECISION_3_SEMANTIC_VALID>
  <OPTIONS>
    <OPTION id="A">
      <NAME>Minimal-safe cleanup; retain current eight-wide terminal comparator</NAME>
      <CONTENT>Apply Decisions 1A, 2A and 3. Keep word_epoch/payload_pos, pos_w0..pos_w7, terminal arrays, Q arrays, history/window and extraction cases unchanged. Preserve the current user `prec_vld/dec_vld/map_vld` refactor.</CONTENT>
      <BEHAVIOR>Lowest semantic risk and smallest verification delta. All current modes, offsets, I/Q rules and recovery remain structurally identical.</BEHAVIOR>
      <PPA_HYPOTHESIS>CDC/state-bus and wiring reduction only; the dominant comparator/mux network remains.</PPA_HYPOTHESIS>
    </OPTION>
    <OPTION id="B">
      <NAME>Beat discard countdown plus single next-terminal scheduler</NAME>
      <CONTENT>At legal SOMF[0], load a configuration-derived `discard_beats = payload_start_word/8` and discard that many complete valid beats. Then maintain `words_to_terminal` and a small `terminal_idx/phase`. Each valid beat subtracts eight. If `words_to_terminal&lt;=8`, complete one block at `block_end_offset=words_to_terminal-1`, classify I/Q from terminal_idx/phase, and reload the next legal terminal gap after accounting for unused words in the current beat. Keep the 384-bit lane window and eight extraction slices.</CONTENT>
      <BEHAVIOR>Pure ADC loads first distance 16 and repeats 16. Decimation and DDC use mode/DEC_M-derived gap sequences equivalent to the current terminal tables. Link/epoch loss clears countdown, scheduler phase and history. Invalid `map_vld` never activates payload. Zero data is never examined.</BEHAVIOR>
      <PPA_HYPOTHESIS>Removes pos_w0..7, 128-bit terminal arrays, 128-bit Q arrays, roughly eight-by-eight terminal comparisons, eight-by-four Q comparisons and the match priority tree; adds one countdown subtract/compare, a small phase counter and a mode gap mux. Expected material LUT/toggle reduction, but actual PPA is unmeasured.</PPA_HYPOTHESIS>
      <RISK>Highest risk is off-by-one/gap-table error for DEC_M low-bit cases and period wrap. Design must enumerate every gap sequence and prove minimum gap&gt;=16 before implementation. Full three-mode scoreboards and every block_end_offset remain mandatory.</RISK>
    </OPTION>
    <OPTION id="C">
      <NAME>Restrict configurations until all block ends are beat-aligned</NAME>
      <CONTENT>Hard-code pure ADC or a reduced decimation/DDC set, eliminating most offset/window logic.</CONTENT>
      <STATUS>REJECTED under current requirements.</STATUS>
      <REASON>Changes legal software configurations and AC9810 mapping. It is not merely a correct-case optimization.</REASON>
    </OPTION>
  </OPTIONS>
  <CORRECT_CASE_ERROR_POLICY>
    <ITEM>Keep only configuration validity (`prec_vld`, `dec_vld`, `map_vld`), link/epoch validity, FIFO native overflow, DDC two-slot pair protection, conservative DDC abort and public sticky errors.</ITEM>
    <ITEM>Invalid configuration or missing epoch produces no payload writes; software diagnoses configuration/status and performs disable/clear/relink. Do not add hardware timeout, retry, value-based sync search, tail packet, automatic FIFO reset or speculative resynchronization.</ITEM>
    <ITEM>Derive CDC functional controls as single bits in their source domain. Exact debug snapshots are optional diagnostics, not data-path controls.</ITEM>
  </CORRECT_CASE_ERROR_POLICY>
  <REJECTED_OPTIONS>Independent-bit synchronization of encoded adi_status_state; moving every CDC into ADC_RXD; a generic `valid` name that conflates stream/config/epoch; value-based zero filtering; deleting lane history while legal mid-beat ends remain; hardware retry/timeout recovery.</REJECTED_OPTIONS>
  <RECOMMENDATION>For minimum immediate risk choose Option A plus Decisions 1A, 2A and `upk_vld`. For a material PPA/readability improvement choose Option B, but freeze every per-mode terminal-gap sequence in the design before RTL and rerun all offset/mode scoreboards. Option B is the best architectural simplification if the user accepts a larger verification delta; Option A is the best scoped cleanup.</RECOMMENDATION>
  <USER_DECISIONS_REQUIRED>
    <DECISION>May JESD_STA expose only coherent LINK_READY/not-ready semantics, or must software retain exact four-state snapshots? Choose 1A or 1B.</DECISION>
    <DECISION>Choose payload Option A (minimal delta) or B (single scheduler, larger PPA hypothesis and verification delta).</DECISION>
    <DECISION>Confirm moving only private JESD-to-AFE `link_ready` CDC into ADC_RXD and naming the semantic beat qualifier `upk_vld`.</DECISION>
  </USER_DECISIONS_REQUIRED>
  <ASSUMPTIONS>
    <ASSUMPTION>Current user edits are naming/format only and preserve the previously accepted map-valid truth table.</ASSUMPTION>
    <ASSUMPTION>Static configuration remains stable while channel effective enable is active.</ASSUMPTION>
    <ASSUMPTION>All accepted terminal gaps are at least 16 lane words; Option B requires this to be enumerated/proved in the next design revision.</ASSUMPTION>
  </ASSUMPTIONS>
  <OPEN_QUESTIONS>The three explicit user decisions above are RTL-affecting and must be selected before design freeze.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS>ADI exact state transitions remain JESD-domain behavior. Option B PPA is a hypothesis until synthesis and its gap schedule needs independent review. First-board AC9810/ILAS/controller mapping and official FIFO/PHY equivalence remain downstream risks.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
