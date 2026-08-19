<ARCHITECTURE_HANDOFF>
  <AGENT_ID>/root/adc_accum_arch2</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_ARCHITECTURE_handoff_04.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <ROLE>Architecture Analyst</ROLE>
  <MODULE_NAME>ADC_TOP</MODULE_NAME>
  <REQUIREMENTS_USED>
    <ITEM classification="FACT">The user selected a valid-region/zero-region counter and two-128-bit-beat accumulator, replacing the head/window/eight-slice scheduler. Use dec_* for single-decimation and ddc_* for decimation-plus-DDC logic.</ITEM>
    <ITEM classification="FACT">The N.5 duplicate endpoint words in the single-decimation workbook are documentation errors: hardware does not emit either duplicate. This user fact overrides those cells.</ITEM>
    <ITEM classification="FACT">Legal static configuration is software-guaranteed. Preserve all existing runtime reset/error/report/recovery behavior.</ITEM>
    <ITEM classification="FACT">Comparison baseline: ADC_TOP design v1.12 SHA256 3e1dea49ee3d91d7d3fe7604917b790474be75e505e5244c2877cd4a122ee23a; ADC_RXD.v SHA256 5094126a3e646775bf7fe4c5ec3db7454e25e0205219949ab26e477a705cfe57.</ITEM>
  </REQUIREMENTS_USED>
  <EVIDENCE_HANDOFF_HASH>2026-08-18_EVIDENCE_RESEARCH_handoff_05.md SHA256 47f70fe8389ceeb6090523fb0e2ec788208f93dc5ef8740951add48d016f3dc8; 2026-08-18_EVIDENCE_RESEARCH_handoff_06.md SHA256 c5a778d2b8617895704282b4403fb6e1602bc70428565d1be4575e678ab88837. Only their duplicate-dependent N.5 endpoint/partial-boundary conclusions are stale; all non-N.5, prefix and DDC anchors remain comparison evidence.</EVIDENCE_HANDOFF_HASH>
  <SOURCES>
    <SOURCE><TITLE>AC9810-32 JESD204B grouping scenarios</TITLE><PUBLISHER>AC9810 vendor material</PUBLISHER><PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx</PATH><ANCHORS>sheet3 单抽取 P40:T52 and rows70-71,87-90,107-108,124-127; sheet4 抽取+DDC P39:T51 and rows68-69,90-93,110-113,130-133.</ANCHORS><ACCESS_DATE>2026-08-18</ACCESS_DATE></SOURCE>
    <SOURCE><TITLE>ADC_TOP User RTL Design Preferences Draft</TITLE><PUBLISHER>User module artifact</PUBLISHER><PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_User_RTL_Design_Preferences_DRAFT.md</PATH><ANCHORS>valid/zero regions, two 128-bit beats, removal of unnecessary windows/masks.</ANCHORS><ACCESS_DATE>2026-08-18</ACCESS_DATE></SOURCE>
  </SOURCES>
  <BOUNDARY_PROOF>
    <UNITS>One lane source word is 16 bits; one accepted AFE beat has eight words per lane (128 bits per lane, 256 bits total). A 512-bit FIFO item is sixteen words per lane, therefore precisely two accepted valid AFE beats.</UNITS>
    <PREFIX_FACT>No-delete prefix beats for f=0,1,2,3 are respectively 2N+23,8N+25,4N+25,8N+29. d=0/1/2 adds B(d)=0/4E/8E, E=4N+f. Prefix deletion changes no payload-region boundary and all prefix endpoints are beat aligned.</PREFIX_FACT>
    <CORRECTED_DEC_F2 classification="FACT">After both erroneous endpoint entries are removed, a dec f=2 occurrence is valid [0..31], zero [32..32N+15], then valid [32N+16..32N+47]. Block starts are 0,16,32N+16,32N+32 and gaps are 16,32N repeating. The fundamental valid-plus-zero period is 32N+16 words; a four-block observation spans 64N+32 words.</CORRECTED_DEC_F2>
    <ALIGNMENT classification="FACT">For every legal dec case N=1..63,f=0..3,d=0..2 and ddc case N=2..63,f=0..3,d=0..2, every prefix/valid/zero boundary is divisible by eight words and every valid region has an even beat count. Thus no legal corrected configuration needs a word mask, partial append, offset slice or three-beat window.</ALIGNMENT>
  </BOUNDARY_PROOF>
  <REGION_FORMULAS unit="source_words_per_lane">
    <DEC_TABLE legal_N="1..63">
      <ROW f="0" valid_words="16" zero_words="16N-16" period_words="16N" valid_beats="2" zero_beats="2N-2" gaps_words="16N" />
      <ROW f="1" valid_words="64" zero_words="64N-48" period_words="64N+16" valid_beats="8" zero_beats="8N-6" gaps_words="16,16,16,64N-32" />
      <ROW f="2" valid_words="32" zero_words="32N-16" period_words="32N+16" valid_beats="4" zero_beats="4N-2" gaps_words="16,32N" corrected="true" />
      <ROW f="3" valid_words="64" zero_words="64N-16" period_words="64N+48" valid_beats="8" zero_beats="8N-2" gaps_words="16,16,16,64N" />
    </DEC_TABLE>
    <DDC_TABLE legal_N="2..63">
      <ROW f="0" valid_words="32" zero_words="16N-32" period_words="16N" valid_beats="4" zero_beats="2N-4" gaps_words="16,16N-16" blocks="I,Q; region begins I" />
      <ROW f="1" valid_words="128" zero_words="64N-112" period_words="64N+16" valid_beats="16" zero_beats="8N-14" gaps_words="16 x7,64N-96" blocks="I,Q,I,Q,I,Q,I,Q; region begins I" />
      <ROW f="2" valid_words="128" zero_words="32N-48" period_words="32N+80" valid_beats="16" zero_beats="4N-6" gaps_words="16 x7,32N-32" blocks="I,Q,I,Q,I,Q,I,Q; region begins I" />
      <ROW f="3" valid_words="128" zero_words="64N-80" period_words="64N+48" valid_beats="16" zero_beats="8N-10" gaps_words="16 x7,64N-64" blocks="I,Q,I,Q,I,Q,I,Q; region begins I" />
    </DDC_TABLE>
    <ZERO_LENGTH_FACT>Only dec f=0,N=1 and ddc f=0,N=2 have zero_beats=0. They must bypass RXD_ZERO without consuming a phantom beat.</ZERO_LENGTH_FACT>
  </REGION_FORMULAS>
  <OPTIONS>
    <OPTION id="A" status="SELECTED_BY_USER_AND_VALIDATED">
      <NAME>Beat-aligned region FSM and two-beat accumulator</NAME>
      <BOUNDARY>ADC_RXD stays wholly in AFE_CLK. No ADI/JESD/FIFO/AXIS/CDC/interface boundary changes.</BOUNDARY>
      <OWNERSHIP>RXD_IDLE/RXD_PREF/RXD_VALID/RXD_ZERO owns reception; prefix_beat_r owns prefix progress; region_cnt owns forward in-region beat count; rxd_pair_phase owns first/second valid beat; rxd_buff0/1 own one stored 128-bit beat per lane; ddc_iq_phase owns DDC I/Q block parity.</OWNERSHIP>
      <BUFFERING>On first valid beat capture adi_rx_data[127:0] and [255:128]. On second, create rxd_slice0={adi_rx_data[127:0],rxd_buff0} and rxd_slice1={adi_rx_data[255:128],rxd_buff1}; this is the current offset-7 lane order without a variable slice. Keep mapped_raw, mapped_data and channel/precision mapping.</BUFFERING>
      <THROUGHPUT>Accept one AFE beat per upk_vld. Candidate FIFO output occurs exactly on every second valid beat. A zero beat updates only zero-region position and cannot change accumulation buffers.</THROUGHPUT>
      <PPA_INTENT classification="HYPOTHESIS">Remove 2x256-bit histories, 2x384-bit windows, 2x8-way 256-bit slice muxes and 64-bit positional scheduler. Add 2x128-bit buffers, a 9-bit region counter and two 1-bit phases. Synthesis is required for any PPA result.</PPA_INTENT>
    </OPTION>
    <OPTION id="B" status="REJECTED_FOR_SELECTED_BASELINE"><NAME>Retain v1.12 head/window/eight-slice scheduler</NAME><REJECTION>Corrected f=2 removes the only identified offset-one boundary need. It is more general but conflicts with the selected minimal structure.</REJECTION></OPTION>
    <OPTION id="C" status="REJECTED_FOR_SELECTED_BASELINE"><NAME>Per-word mask/partial-append accumulator</NAME><REJECTION>It solves only the stale duplicate-derived partial boundary and adds unnecessary control/verification surface.</REJECTION></OPTION>
  </OPTIONS>
  <REJECTED_OPTIONS>The user selected A. Boundary proof validates every legal case, so B/C need no further user decision and no material conflict survives.</REJECTED_OPTIONS>
  <FROZEN_MINIMAL_CONTROL>
    <FSM>
      <STATE name="RXD_IDLE">Wait for upk_vld-qualified adi_rx_somf[0]; retain fixed epoch policy.</STATE>
      <STATE name="RXD_PREF">Advance the existing marker-inclusive prefix count. On payl_hit the current beat is also the first VALID beat: capture it in that edge, do not add latency or drop it.</STATE>
      <STATE name="RXD_VALID">For region_cnt=0 store first lane beats; for rxd_pair_phase=1 complete mapped output/FIFO decision. Count forwards; on final valid beat reset region_cnt and enter RXD_ZERO only if selected zero_beats is nonzero, otherwise remain VALID.</STATE>
      <STATE name="RXD_ZERO">Consume whole zero beats, forward-count them, and never update first-beat buffers or make FIFO candidates. On final zero beat reset region_cnt and enter VALID.</STATE>
    </FSM>
    <COUNTERS>
      <COUNTER name="prefix_beat_r" width="12">Unchanged existing marker-inclusive prefix counter.</COUNTER>
      <COUNTER name="region_cnt" width="9">Forward count in current region; max legal zero is dec f=3,N=63 =502 beats. Test region_cnt+1==selected_region_beats, not a downcounter.</COUNTER>
      <COUNTER name="rxd_pair_phase" width="1">0=current beat is first/store, 1=current beat is second/complete. Reset to 0; all valid regions are even and finish at 0.</COUNTER>
      <COUNTER name="ddc_iq_phase" width="1">DDC only: pre-edge 0=I, 1=Q at each completed block; toggle only per completed DDC block. Every valid region has an even block count, naturally returning to I.</COUNTER>
    </COUNTERS>
    <FORMULAS>Build dec_valid_beats/dec_zero_beats and ddc_valid_beats/ddc_zero_beats directly by dec_fra. Select dec only in SMP_MODE=1 and ddc only in SMP_MODE=2. Retain separate dec_num and ddc_num prefix expressions. Do not retain single_* names in the replacement logic.</FORMULAS>
  </FROZEN_MINIMAL_CONTROL>
  <RUNTIME_SEMANTICS_TO_PRESERVE>
    <ITEM>upk_vld remains chn_en_afe &amp;&amp; link_ready_afe &amp;&amp; adi_rx_valid and rxd_clr remains !upk_vld || fifo_clr. rxd_clr clears FSM, prefix_beat_r, region_cnt, pair/IQ phases, buffers and ddc_i_accepted_r on that AFE edge; restart requires new SOMF.</ITEM>
    <ITEM>Normal ADC/dec makes one FIFO write request per completed block and retains PUB WC=0 overflow behavior. Position, never sample value, selects valid data; valid numerical zero data is retained.</ITEM>
    <ITEM>DDC pre-edge I checks fifo_wlevel&gt;=2 and writes/sets ddc_i_accepted_r only on success. Q writes only after accepted I and clears it. Rejected I gives exactly one data_drop_evt; no Q duplicate event. Data capacity never changes region/IQ progression.</ITEM>
    <ITEM>ddc_epoch_live must include RXD_PREF, RXD_VALID and RXD_ZERO. After effective DDC epoch establishment, link_ready_afe/adi_rx_valid loss retains one-time ddc_abort_afe/data_drop_evt, fail-closed CDC packet admission, and existing fifo_clr-or-afe-reset recovery. Normal EN shutdown remains non-aborting.</ITEM>
    <ITEM>Keep the documented recovery sequence: disable, wait AFE_IDLE, FIFO_CLR while both clocks run, confirm FIFO_EMPTY/clear convergence, reconfigure/relink, enable. W1C does not clear ddc_abort_afe or reopen admission.</ITEM>
  </RUNTIME_SEMANTICS_TO_PRESERVE>
  <REMOVABLE_CURRENT_LOGIC>
    <REMOVE>word_pos_r, block_cnt, phase_cnt, block_end, block_complete, block_end_offset and all 64-bit absolute-coordinate logic.</REMOVE>
    <REMOVE>gap_16n/gap_32n/gap_64n, their subtractive aliases, single_block_gap, ddc_block_gap, block_gap and phase_cnt_clr; direct dec_*/ddc_* region lengths replace them.</REMOVE>
    <REMOVE>The 256-bit rxd_buff0/1 histories, 384-bit rxd_window0/1 and both eight-way rxd_slice muxes. Replace with two 128-bit first-beat buffers and fixed concatenation. mapped_raw/mapped_data remain required.</REMOVE>
    <REMOVE>Any f=2 duplicate-word mask/partial-append/offset exception or verification expectation derived from stale duplicate cells.</REMOVE>
  </REMOVABLE_CURRENT_LOGIC>
  <CYCLE_LEVEL_ACCEPTANCE>
    <REQUIREMENT id="A1">Exhaustively prove integer prefix endpoints for dec N=1..63 and ddc N=2..63, f=0..3,d=0..2. SOMF at accepted beat0 yields first data capture at beat skip_num.</REQUIREMENT>
    <REQUIREMENT id="A2">Exhaustively assert valid_words mod8=0, zero_words mod8=0 and valid_beats mod2=0 for every legal formula.</REQUIREMENT>
    <REQUIREMENT id="A3">With monotonically numbered lane words, a valid region starting at beat P produces FIFO candidates only P+1,P+3,... . Each must contain exactly sixteen selected words/lane in fixed existing offset-7 ordering. No zero-region word may enter; a valid word numerically equal to zero must remain.</REQUIREMENT>
    <REQUIREMENT id="A4">For corrected dec f=2 assert valid[0..31], zero[32..32N+15], next valid[32N+16..32N+47], starts 0,16,32N+16,32N+32 and gaps16,32N. Fail if either stale duplicate is consumed or any offset-one behavior exists; cover N=1,63.</REQUIREMENT>
    <REQUIREMENT id="A5">Cover direct zero bypasses dec f0,N1 and ddc f0,N2: no RXD_ZERO beat is consumed and pair phase is zero at next region start.</REQUIREMENT>
    <REQUIREMENT id="A6">For every DDC f, test minimum/maximum N, I/Q sequence, I-only two-slot admission, I-accepted-gated Q, single rejected-I drop, no Q drop, and I/Q progression through zero regions.</REQUIREMENT>
    <REQUIREMENT id="A7">Inject !upk_vld/fifo_clr on first/second VALID, ZERO and PREF beats. No half accumulation survives. In established DDC epoch inject link/valid loss and prove one abort/drop, fail-closed admission and recovery only through FIFO clear or AFE reset; normal EN shutdown must not abort.</REQUIREMENT>
    <REQUIREMENT id="A8">Regression must preserve FIFO overflow, mapping/precision expansion, AXIS packet behavior, reset and CDC contracts. This analysis ran no RTL/TB/VMware/VCS/XSIM/synthesis/implementation/board verification.</REQUIREMENT>
  </CYCLE_LEVEL_ACCEPTANCE>
  <RECOMMENDATION>Implement user-selected Option A after a Design Author freezes these corrected f=2 and region formulas into the design contract. The correction removes the prior material conflict; no alternate architecture needs selection. Follow with fresh rtl-vibe implementation and verification because the v1.12 evidence cannot validate corrected scheduling.</RECOMMENDATION>
  <ASSUMPTIONS><ITEM>Software supplies stable legal static configuration; no new static-config detector is proposed.</ITEM><ITEM>Both duplicate entries are absent while the written f=2 zero-region length remains (32N-16) words.</ITEM><ITEM>Current channel mapping and fixed offset-7 two-beat lane ordering are retained.</ITEM></ASSUMPTIONS>
  <OPEN_QUESTIONS>NONE blocking architecture selection. Board-level lane-rate feasibility is outside this positional architecture analysis.</OPEN_QUESTIONS>
  <RESIDUAL_RISKS><ITEM>No RTL/TB/XDC/design artifact was edited; no verification was run.</ITEM><ITEM>PPA is hypothesis until synthesis and complete functional evidence is fresh.</ITEM><ITEM>If future primary hardware evidence contradicts the user correction, revisit this alignment proof before implementation.</ITEM></RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</ARCHITECTURE_HANDOFF>
