<EVIDENCE_HANDOFF>
  <AGENT_ID>/root/adc_decim_evidence</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_EVIDENCE_RESEARCH_handoff_06.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <QUESTION_SCOPE>Exact 2-CML DDC f0..f3 positional layouts for N=2..63, I/Q block phase, beat masks and common selected-word-accumulator evidence. No architecture is proposed or selected.</QUESTION_SCOPE>
  <SOURCES>
    <SOURCE><TITLE>AC9810-32 JESD204B grouping scenarios</TITLE><PUBLISHER>AC9810 vendor material</PUBLISHER><PATH>D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx</PATH><ANCHORS>sheet4 “抽取+DDC”, 2-CML: f0 rows68-69; f1 rows90-93; f2 rows110-113; f3 rows130-133. Table P39:T51 provides matching 2-CML prefix/deletion quantities. Sheet3 rows107-108 is cited only for the single f2 repeated-word compatibility boundary.</ANCHORS></SOURCE>
  </SOURCES>
  <FACTS>
    <FACT confidence="HIGH">All DDC blocks in the cited 2-CML layouts are 16 consecutive lane words. I/Q order alternates by block, starting I: I0,Q0,I1,Q1,... . No DDC row contains the isolated duplicated terminal word seen in single-dec f2; the DDC data runs contain contiguous I/Q blocks only.</FACT>
    <FACT confidence="HIGH">DDC f0 rows68-69: I0=[0..15], Q0=[16..31], zero=[32..16N-1] of written length16N-32, I1 begins16N. Block starts are0,16,16N,16N+16,...; ends15,31,16N+15,16N+31; gaps `{16,16N-16}`; period16N. N>=2 makes the zero length nonnegative. Every start is offset0 and every end offset7 modulo8.</FACT>
    <FACT confidence="HIGH">DDC f1 rows90-93: eight contiguous blocks I0,Q0,I1,Q1,I2,Q2,I3,Q3 span [0..127]; zero=[128..64N+15] of written length64N-112; I4 begins64N+16. Starts are0,16,32,48,64,80,96,112,64N+16,...; gaps are seven16 values then64N-96; period64N+16. All starts/zero boundaries are offset0 modulo8 and all ends offset7.</FACT>
    <FACT confidence="HIGH">DDC f2 rows110-113: eight contiguous blocks I0 throughQ3 span[0..127]; zero=[128..32N+79] of written length32N-48; I4 begins32N+80. Starts0,16,32,48,64,80,96,112,32N+80,...; gaps seven16 values then32N-32; period32N+80. All starts/zero boundaries are offset0 modulo8 and all ends offset7.</FACT>
    <FACT confidence="HIGH">DDC f3 rows130-133: eight contiguous blocks I0 throughQ3 span[0..127]; zero=[128..64N+47] of written length64N-80; I4 begins64N+48. Starts0,16,32,48,64,80,96,112,64N+48,...; gaps seven16 values then64N-64; period64N+48. All starts/zero boundaries are offset0 modulo8 and all ends offset7.</FACT>
    <FACT confidence="HIGH">For every DDC f0..f3 and N=2..63, an AFE beat is either eight selected DDC words or eight zero-run words: the only source-valid mask forms are 8'b11111111 and 8'b00000000. Maximum selected words per DDC AFE beat is eight; no DDC valid/zero boundary lies inside a beat.</FACT>
    <FACT confidence="HIGH">The source’s I/Q mapping is block-granular rather than beat-granular: every 16-word block is I or Q, so each I/Q block spans exactly two all-selected AFE beats. The eight-block f1/f2/f3 sequences give I,Q,I,Q,I,Q,I,Q before the long zero run; f0 repeats I,Q.</FACT>
    <FACT confidence="HIGH">The single-dec f2 source layout is the cross-mode exceptional case: its repeated terminal source word at coordinate32 (and again at32N+49) is not part of either adjacent 16-word output block. A selected-word accumulator must not admit that duplicate into a block; it is not an additional sample word. After the duplicate, zero starts at33; selected data resumes at32N+17, offset1.</FACT>
  </FACTS>
  <INFERENCES>
    <INFERENCE>A common per-word mask/partial-append engine has sufficient source coverage for both modes: DDC needs only all-one/all-zero masks and block-aligned I/Q tagging, while single f2 needs a re-entry mask selecting lane-word offsets1..7 (binary 11111110 when bit0 denotes first word), plus correct handling of the following full beat and first word of the next beat to complete its 16-word block.</INFERENCE>
    <INFERENCE>The single f2 partial sequence demonstrates why an accumulator needs partial append/retention, not merely a mask: starting at32N+17 it receives7 selected words at offsets1..7, then8 from the following beat, then one at the next beat’s offset0 to complete the first block; offsets1..7 of that same beat begin the next block. The isolated duplicate at32 must be masked out completely, as must subsequent zero-run words.</INFERENCE>
    <INFERENCE>DDC alone could be represented by whole-beat enables, but that is not a common all-mode proof. A common engine that supports the single f2 masks can represent DDC with the all-one/all-zero subset, provided it retains the independent DDC I/Q block-phase behavior and does not infer I/Q from beat parity.</INFERENCE>
  </INFERENCES>
  <CONFLICTS>
    <CONFLICT><TARGET>Any common whole-beat-only selected-word accumulator</TARGET><DETAIL>Not sufficient for all modes because single f2 has offset1 re-entry and a duplicated source word that must not enter the next 16-word block. DDC has no such partial boundary, but cannot erase the single-mode requirement.</DETAIL></CONFLICT>
    <CONFLICT><TARGET>Current v1.12 DDC schedule</TARGET><DETAIL>NONE in quantities: its f0/f1/f2/f3 gaps and I/Q phase cycles correspond to the listed DDC source layouts. This handoff does not authorize changing its all-beat history/slice implementation.</DETAIL></CONFLICT>
  </CONFLICTS>
  <GAPS>
    <OPEN_QUESTION>Source framing establishes word position but not board-level lane-rate feasibility for every N/F; selected ADC clock/CML conditions remain required for that conclusion.</OPEN_QUESTION>
  </GAPS>
  <RESIDUAL_RISKS>No RTL/TB/XDC changed and no verification ran. This is positional source evidence only and does not prove a prospective accumulator’s RTL, buffering, backpressure, FIFO or reset behavior.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT</NEXT_OWNER>
</EVIDENCE_HANDOFF>
