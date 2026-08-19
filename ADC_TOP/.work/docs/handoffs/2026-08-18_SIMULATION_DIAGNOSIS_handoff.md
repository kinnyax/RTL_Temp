# ADC_TOP Simulation / Source-Timing Diagnosis Handoff

- Date: 2026-08-18
- Worker: `/root/adc_accum_sim` (Simulation Worker)
- Scope: read-only diagnosis of fresh VMware run
  `ADC_TOP_66dd4e9f5c2f427d909a5c33130a107d`.
- Status: `DIAGNOSIS_COMPLETE_NOT_A_VERIFICATION_PASS`
- Run result: 16 tests executed, 14 passed, 2 failed.  This handoff does not
  claim `VMWARE_SANITY_PASS`, VCS, XSIM, synthesis, implementation, or board
  evidence.

## Inputs observed

- JUnit: `.work/verification/sim/ADC_TOP_cocotb_results.xml`
- Cocotb log: `.work/verification/sim/ADC_TOP_cocotb.log`
- Evidence: `.work/verification/sim/ADC_TOP_evidence.json`
- Failed wave: `.work/verification/waves/ADC_TOP.fst` (retained; no local FST
  decoder was available for additional signal extraction)
- Canonical RTL: `rtl/ADC_RXD.v`, `rtl/ADC_CHN.v`, and
  `rtl/ADI_JESD204/jesd204_rx.v`
- Canonical TB/manifest at run time: hashes bound in the evidence JSON.

## Finding 1: source[16] first payload is a two-AFE-beat ADI marker/data skew

The failed `dec_ddc_region_v115_legal_matrix` JUnit assertion at payload beat
0 reported lane-0 words beginning `0x0264, 0x038c, 0x0289, 0x03b1` and lane-1
words beginning `0x0a64, 0x0b8c, 0x0a89, 0x0bb1`.  The TB function
`_scheduler_lane_word()` evaluates those values as source indices 16, 24, 17,
25 (and the lane-1 counterparts), i.e. the fixed mapping of the 16-word
candidate ending at source terminal 31.  The expected beat begins with source
indices 0, 8, 1, 9 and ends at terminal 15.  Therefore the observed delta is
exactly two AFE data beats = 16 per-lane source words, not a fractional-region
formula, N.5 endpoint, channel-mapping permutation, or AXIS-consumption shift.

The source chain supporting that diagnosis is:

1. TB `_drive_afe0_jesd_beat()` drives four octets per lane on each public
   JESD clock. `ADC_RXD` instantiates `jesd204_rx` with
   `DATA_PATH_WIDTH=4` and `TPL_DATA_PATH_WIDTH=16`.
2. Each ADI lane elastic buffer uses `ad_pack` when the output width exceeds
   its input width. Thus four JESD beats are packed into one 16-octet,
   128-bit-per-lane AFE/device beat, containing eight 16-bit source words.
3. `jesd204_rx` has default `NUM_OUTPUT_PIPELINE=1`; its output pipeline
   registers `rx_data` and `rx_valid`. The elastic buffer read is also a
   device-clock registered read.
4. In contrast, `rx_somf` is created by device-clock `jesd204_frame_mark`.
   Its reset is `eof_reset_d`, which itself comes through the output pipeline.
   Around release this allows two device/AFE data beats to emerge before the
   frame marker presents the first `somf`.
5. `ADC_RXD` defines `upk_trig = upk_vld && adi_rx_somf[0]` and starts the
   RXD epoch only at that trigger. Its first valid capture is consequently the
   beat containing source[16..23], followed by source[24..31]. The reported
   packet is therefore the exact expected result of this marker/data skew.

The v1.15 region model's dec/ddc prefix, valid/zero, f2, and no-duplicate
formulas remain internally correct. Its expected terminal 15 expresses the
final-design first-valid-beat contract. Do **not** change the test expected
sequence by +16 to accept the result: that would hide the first-valid-beat
contract mismatch.

The v1.12 continuous-source/window tests are not contrary evidence. Their
256/384-bit history and sliding-window prehistory implicitly warmed up the
stream, and their periodic source patterns did not expose this fixed startup
phase. The v1.15 two-beat first-buffer architecture makes the phase observable.

## Finding 2: DDC recovery source amount is sufficient

The post-relink branch of
`ddc_abort_blocks_admission_until_fifo_clear_recovery` supplies:

- a 312-word prefix, equal to 39 AFE beats for `E=32, N=8, f=0, d=0`; and
- 1,200 alternating I/Q CML blocks. Each CML block is 16 words = two AFE
  beats, so the payload stream is 2,400 AFE beats.

For this DDC configuration the v1.15 schedule is four valid beats followed by
twelve zero beats, a 16-AFE-beat period. Each period has two completed
16-word candidates (I then Q), hence the supplied payload permits about 300
FIFO writes, above the packet admission threshold of 256. It is not a
short-stimulus failure and it does not end in the initial zero region.

The observed `ADC_STA0=0xfe00ff01` decodes under canonical `ADC_REG.v` as
`{afe_idle,fifo_full,fifo_empty,link_ready}`: AFE0 link-ready is high and its
FIFO-empty bit is high. The test's masked expectation `0x00000101 ->
0x00000001` therefore correctly requires a nonempty AFE0 FIFO after recovery;
it is not a retired register interpretation. The failure remains a real
post-recovery write/abort-clear-path issue. Normal DDC end-to-end coverage in
the same run passed, so the issue is specific to the abort -> FIFO_CLR ->
relink path.

## Recommended correction ownership

RTL owner: preserve the v1.15 scoreboard expectation and align ADI data/valid
with the first `somf` at the ADC_RXD boundary (for example, a two-AFE-beat
data/valid delay or an equivalently data-aligned SOMF path). Then audit the
DDC abort-clear/relink path against the existing nonempty-FIFO assertion.
The next frozen TB includes a read-only `REGION_STARTUP` marker that records
the first RXD pair, concat low word, and FIFO write register values to separate
RXD from FIFO/packet boundary behavior.

## Separate implementation-batch item

The run initially reported 16 JUnit tests but only 14 manifest mappings.
That Simulation-owned issue was corrected **after** this run by adding unique
case/tag bindings for `pure_adc_fixed_prefix` and
`static_cfg_non_idle_only_gate`; it belongs to the implementation correction
batch, not to this immutable run diagnosis. No verification rerun has occurred
after that correction.

## Model boundary and residual risk

The ADI JESD PHY/elastic-buffer model is `NON_VENDOR_EQUIVALENT` for later
official-IP integration. This diagnosis establishes only source-level timing
and observed Icarus/cocotb behavior for the frozen run. Integrated Vivado XSIM
must still close the official-IP behavior gap.
