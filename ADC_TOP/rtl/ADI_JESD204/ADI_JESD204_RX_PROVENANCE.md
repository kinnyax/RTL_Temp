# ADI JESD204 RX source provenance

- Upstream: `https://github.com/analogdevicesinc/hdl.git`
- User reference: `https://github.com/analogdevicesinc/hdl/tree/main/library/jesd204`
- Frozen commit: `9d5de2fc21b6069675104567c9041bcdbfbe9baa`
- Imported and consolidated: `2026-07-29`
- Delivery source: `jesd204_rx.v`
- Original consolidated baseline SHA256: `2DF6E600BFB11894A5888E00A084B721C226971B7B2594D56BD6B104BBEC6195`
- Current module-owned SHA256: `3B30E702EF440D19FB04656BE61F0FC088103F3823846C4F6825B8163F873FC7`
- License copy: `LICENSE_ADI_GPL2`

`jesd204_rx.v` consolidates the 17 Verilog modules needed by the frozen 8B/10B
receive configuration. Original file boundaries,
copyright notices, and license notices remain embedded in the single source
file. The component hashes in `ADI_JESD204_RX_COMPONENTS.sha256` identify the
unmodified upstream inputs.

The module-owned copy has three intentional, license-permitted deviations:

1. An explicit `wire eof_reset_d;` declaration replaces the upstream implicit
   one-bit net. This is compile hardening for ADC_TOP's ``default_nettype none``
   policy and does not change connectivity or latency.
2. `jesd204_frame_mark` maps `DATA_PATH_WIDTH=16` to `DPW_LOG2=4`, so the
   contract-required 16-octet-per-lane device datapath computes one device beat
   per 16-octet frame.
3. The frame marker's generic start/end-marker branch also accepts
   `DATA_PATH_WIDTH=16`. With the configured minus-one values `255/15/15`, it
   emits SOMF on octet 0 and EOMF on octet 15 of each 16-beat multiframe.

The latter two changes close an upstream limitation in the selected frozen
revision: without them, the 16-octet TPL configuration leaves `rx_somf` and
`rx_eomf` indeterminate. Public-path cocotb regression covers CGS/ILAS, buffer
release, SOMF-based ADC epoch acquisition, mapped payload, and fixed packet
output for this deviation. No equivalence to another ADI revision is claimed.

The Vivado JESD204 PHY/GTH, clock primitives, DRP logic, Tcl, block designs,
generated IP, 64B/66B-only sources, and vendor constraints are not included.

Consolidating or relocating this source does not change its ownership or
license. The ADI source remains subject to GPLv2 or a separately purchased
commercial license; product distribution requires a project-level compliance
decision.
