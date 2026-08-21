<EVIDENCE_RESEARCH_HANDOFF>
  <AGENT_ID>/root/adc_decim_evidence</AGENT_ID>
  <HANDOFF_PATH>D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-19_EVIDENCE_RESEARCH_handoff.md</HANDOFF_PATH>
  <STATUS>COMPLETED</STATUS>
  <QUESTION_SCOPE>Primary-source semantics of AC9810 JESD204B normalized 16-bit sample words and comparison with FPGA-local formatting controls. No design, RTL, TB, XDC, state, or verification artifact was modified.</QUESTION_SCOPE>
  <SOURCES>
    <SOURCE kind="PRIMARY_PDF" path="D:\Codex\Vault\RAW\Datasheet\AC9810-32\01-Data Sheet\AC9810-32 用户手册.pdf" version="03, 2025-12-08">
      <ANCHOR physical_pdf_page="78" printed_page="75" section="3.4.7.2 数据输出格式与位宽">cfg_data_width selects 10/12/14/16 bit; cfg_data_type selects signed two's-complement, signed sign-magnitude, or unsigned.</ANCHOR>
      <ANCHOR physical_pdf_page="94" printed_page="91" section="3.4.9.2 输出数据映射关系, Table 3-33">The ADC output width may be 10/12/14/16, normalized JESD supports N'=12/16, and a direct normative sentence says N less than N' zero-fills ADC low bits.</ANCHOR>
      <ANCHOR physical_pdf_page="95" printed_page="92" table="Table 3-34">N=14,N'=16 maps ADC1[13:6], then ADC1[5:0],00; N=16,N'=16 maps ADC1[15:8], then ADC1[7:0].</ANCHOR>
    </SOURCE>
    <SOURCE kind="PRIMARY_PDF" path="D:\Codex\Vault\RAW\Datasheet\AC9810-32\01-Data Sheet\AC9810-32 寄存器手册.pdf" version="03, 2025-12-08">
      <ANCHOR physical_pdf_page="43" printed_page="36" register="CFG_DATA_MODE, offset 0x104">cfg_data_type[5:4]=00 two's-complement, 01 sign-magnitude, 10 unsigned, 11 undefined; cfg_data_width[1:0]=00 16, 01 14, 10 12, 11 10 bit.</ANCHOR>
    </SOURCE>
    <SOURCE kind="PRIMARY_XLSX" path="D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 芯片配置流程.xlsx">
      <ANCHOR sheet="芯片寄存器配置流程" cell="I18">Repeats CFG_DATA_MODE and says default data output is 16-bit two's-complement.</ANCHOR>
    </SOURCE>
    <SOURCE kind="PRIMARY_XLSX" path="D:\Codex\Vault\RAW\Datasheet\AC9810-32\02-User Guide\AC9810-32 JESD204B组帧场景.xlsx">
      <ANCHOR sheet="纯ADC模式" cell="C45">204B为16bit场景.</ANCHOR>
      <ANCHOR sheet="单开抽取" cell="C56">204B为16bit场景.</ANCHOR>
      <ANCHOR sheet="抽取+DDC" cell="C54">204B为16bit场景.</ANCHOR>
    </SOURCE>
    <SOURCE kind="CURRENT_COMPARISON_ONLY" path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_REG.v" anchors="59,185-210">ADC_CTL mask=32'hce00_ffff; frame_fmt=adc_ctl[25] and smp_prec=adc_ctl[31:30]. This module has no AC9810 SPI/register-programming connection.</SOURCE>
    <SOURCE kind="CURRENT_COMPARISON_ONLY" path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v" anchors="375-403 and repeated per 32 samples">mapped_raw is the lane/channel reorder; sample_fmt={frame_fmt,smp_prec}; mapped_data is six LSB/MSB slice and two's-complement-sign-extension cases.</SOURCE>
    <SOURCE kind="CURRENT_COMPARISON_ONLY" path="D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_PKT.v" anchors="157-163,176,201">smp_prec 0/1/2 creates precision byte 10/12/14; value 3 creates 0. FRAME_FMT and device cfg_data_type are absent from the packet header.</SOURCE>
    <SOURCE kind="CURRENT_COMPARISON_ONLY" path="D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\test_ADC_TOP.py" anchors="423-456,625-636,1353-1439">TB calls FRAME_FMT=0 right-aligned and FRAME_FMT=1 left-aligned, accepts only SMP_PREC=0/1/2, and models the existing truncation/sign-extension rule.</SOURCE>
    <SOURCE kind="CURRENT_COMPARISON_ONLY" path="D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\model\AC9810_MASTER.sv" anchors="40-41,104,133-162,223-224">VCS model sends arbitrary 16-bit pattern words and has no cfg_data_width, cfg_data_type, N' padding, or physical output-format model.</SOURCE>
  </SOURCES>
  <FACTS>
    <FACT id="F1" confidence="HIGH">The physical device control is CFG_DATA_MODE at 0x104, not FPGA ADC_CTL. Its width encodings are 16/14/12/10 as 00/01/10/11, while coding is two's-complement/sign-magnitude/unsigned as 00/01/10; coding 11 is undefined.</FACT>
    <FACT id="F2" confidence="HIGH">For a normalized N'=16 word S and configured width p&lt;16, payload is S[15:16-p] and S[15-p:0]=0. Therefore p=10: S[15:6]=ADC[9:0], S[5:0]=0; p=12: S[15:4]=ADC[11:0], S[3:0]=0; p=14: S[15:2]=ADC[13:0], S[1:0]=0; p=16: S[15:0]=ADC[15:0]. p=14 and p=16 are explicitly shown in Table 3-34; p=10/p=12 follow directly from the page-91 low-bit-fill rule.</FACT>
    <FACT id="F3" confidence="HIGH">cfg_data_type changes code interpretation/generation, not the documented N' placement. Hence preserving all 16 source bits is valid for every legal device coding, whereas sign extension assumes only two's-complement.</FACT>
    <FACT id="F4" confidence="HIGH">The three active framing scenarios explicitly say 204B is a 16-bit scene. They corroborate N'=16 transport containers, but do not define FPGA FRAME_FMT or SMP_PREC.</FACT>
    <FACT id="F5" confidence="HIGH">No inspected primary manual/workbook names FPGA ADC_CTL.FRAME_FMT or ADC_CTL.SMP_PREC, assigns their polarity, or links either to CFG_DATA_MODE.</FACT>
    <FACT id="F6" confidence="HIGH">Current-code polarity only: FRAME_FMT=0 selects raw low p bits then two's-complement sign-extends; FRAME_FMT=1 selects raw high p bits then two's-complement sign-extends; SMP_PREC 0/1/2 means p=10/12/14. Cocotb labels these right/left respectively. This is not a device-source definition.</FACT>
    <FACT id="F7" confidence="HIGH">ADC_PKT serializes only precision 10/12/14 for SMP_PREC 0/1/2; value 3 is zero. It does not serialize FRAME_FMT or cfg_data_type. The AC9810 supports physical 16-bit output and the workbook default is 16-bit two's-complement.</FACT>
  </FACTS>
  <REVERSIBLE_MAPPING_ANALYSIS>
    <TERM>S is the source-normalized 16-bit JESD word after existing lane-byte/channel ordering; p is CFG_DATA_MODE width; t is cfg_data_type.</TERM>
    <FACT confidence="HIGH">The only mapping that is reversible for every legal p=10/12/14/16 and t=00/01/10 without extra semantics is raw pass-through Y=S. It has no arithmetic shift, sign/zero extension, or byte rearrangement. Existing lane byte/channel ordering is a distinct JESD-unpacking issue.</FACT>
    <INFERENCE confidence="HIGH">If an external contract explicitly requires a right-aligned p-bit representation and retains p/t metadata, define C=S[15:16-p]. For t=00, R={{(16-p){C[p-1]}},C}; for t=01 or t=10, R={{(16-p){1'b0}},C}. Reconstruct S={R[p-1:0],(16-p)'b0}. This is reversible only over the normalized-source set and is algebraic inference, not a documented FRAME_FMT contract.</INFERENCE>
    <INFERENCE confidence="HIGH">For normalized p&lt;16 input, current FRAME_FMT=1 produces the t=00 right-aligned numerical representation but replaces raw S; it is reversible only if p and t=00 are known. Current FRAME_FMT=0 reads the low p bits, which include mandatory padding, and loses source payload bits. Any p=10/12/14 selection applied to an actual p=16 word discards information.</INFERENCE>
    <OPEN_QUESTION id="Q1">Primary sources do not define external software meaning/polarity of FRAME_FMT=0/1 or whether SMP_PREC reports physical CFG_DATA_MODE, requested software representation, or packet metadata.</OPEN_QUESTION>
    <OPEN_QUESTION id="Q2">Primary byte-time tables do not map to ADC_RXD internal vector indexing. This research establishes bit preservation after existing lane/channel ordering only.</OPEN_QUESTION>
  </REVERSIBLE_MAPPING_ANALYSIS>
  <CONFLICTS>
    <CONFLICT id="C1" severity="HIGH">Device fact F2 says narrow N'=16 words are high-bit payload plus low zeros. Current FRAME_FMT=0 right-aligned logic reads low p bits, so it reads padding plus only a suffix of the code for physical p=10/12/14 output.</CONFLICT>
    <CONFLICT id="C2" severity="HIGH">Current ADC_RXD always two's-complement-sign-extends, conflicting with legal cfg_data_type=01 sign-magnitude and =10 unsigned unless an external invariant fixes the device to two's-complement.</CONFLICT>
    <CONFLICT id="C3" severity="HIGH">Device CFG_DATA_MODE permits 16-bit output/default, while FPGA software/TB/header enumerate only SMP_PREC 10/12/14. Therefore SMP_PREC cannot be assumed to be a complete device-width mirror.</CONFLICT>
    <CONFLICT id="C4" severity="MEDIUM">The tests' low-bit synthetic containers are a TB convention, not primary-source proof of physical normalized N'=16 output for p&lt;16.</CONFLICT>
  </CONFLICTS>
  <TEST_COVERAGE>
    <FACT>test_ADC_TOP.py lines 423-432 drives small raw words and expects sign_extend(low10). Lines 448-456 deliberately generate synthetic left or right containers and expect the present p-bit sign extension. The 12-bit left decimation test is lines 1353-1393; 14-bit right DDC is lines 1400-1439.</FACT>
    <FACT>AC9810_MASTER default patterns are 0x0001..0x0020 I and 0x0100..0x011f Q (lines 223-224); the VCS smoke expects them as arbitrary 16-bit containers.</FACT>
    <GAP>The active tests prove current RTL agrees with its own truncation reference. They do not drive documented normalized 10/12/14 high-bit-payload/low-zero words and assert raw preservation; do not cover physical p=16 or cfg_data_type sign-magnitude/unsigned; do not program/compare CFG_DATA_MODE; and do not validate FRAME_FMT/coding metadata in packets.</GAP>
  </TEST_COVERAGE>
  <RESIDUAL_RISKS>Physical device width/coding must not be inferred from FPGA ADC_CTL absent an explicit software/device-programming contract. Raw packet consumers also need an agreed out-of-band width/coding contract because the current header does not carry coding or placement metadata. This evidence selects no RTL architecture.</RESIDUAL_RISKS>
  <NEXT_OWNER>LEAD_AGENT: reconcile the user-required raw 16-bit preservation and any desired software representation with an explicit FPGA register/packet contract, then route only authorized design work.</NEXT_OWNER>
</EVIDENCE_RESEARCH_HANDOFF>
