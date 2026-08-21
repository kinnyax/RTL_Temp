---
type: rtl_audit_handoff
module_name: ADC_TOP
date: 2026-08-18
author_agent_id: /root/adc_accum_rtl
tags: [FPGA/Handoff, RTL, Static-Audit]
---

# ADC_TOP v1.24 Layer-A RTL Truth-Table Audit

## Scope And Immutable Inputs

- This is deterministic static/source evidence only. No RTL, TB, XDC, ADI, PUB, design, or verification artifact was changed by this audit.
- Final design: `D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`, SHA256 `651b990819c3cb5d0707271014e4eb9fc7c2e716c19a14d65e441088accd6139`.
- Accepted review: `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\handoffs\2026-08-18_FINAL_DESIGN_REVIEW_handoff_15.md`, SHA256 `d61445790167c7d645a2c2f7d9091348eb00135fbeda055213182f039e3b2cda`.
- Audited RTL: `D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_RXD.v`, SHA256 `e72aafb5677a488fcdfc6f39ab81303b71dfadf4318e3ebe09e412a4ce009df6`.
- Read-only integration boundary inspected: `D:\Codex\RTL_Temp\ADC_TOP\rtl\ADC_CHN.v`; it connects `fifo_wr_valid/data` to `async_fifo.winc/wdata` and asserts FIFO reset when `fifo_clr=1`.

## Enumerated Pre-Edge Space

The audit exhaustively evaluated 144 abstract source-reachable boolean vectors over `chn_en_afe` (E), established `ddc_epoch_live` (D), `link_ready_afe` (L), `adi_rx_valid` (V), registered pending request `fifo_wr_valid` (P), pre-edge abort (A), `fifo_clr` (C), and `fifo_write_eligible` (W).

The only reachability reductions are D implies E, and P implies not-A: an existing pending request may coexist with the loss sample edge or clear edge, but cannot be produced after a prior abort because the RTL write gate already contains `!ddc_abort_afe`. Thus there are three legal E/D pairs, three legal P/A pairs, and all four L/V, two C, and two W values: `3 * 3 * 4 * 2 * 2 = 144`.

| Class | Rows | Static result |
| --- | ---: | --- |
| C=1 FIFO-clear priority | 72 | `fifo_rst_n=...&~fifo_clr` resets PUB before write sampling; RXD `rxd_clr` clears `fifo_wr_valid`; `ddc_abort_afe` clears. |
| C=1 and P=1 pending cancellation | 24 | Pending request is canceled, not deferred after clear release. |
| Enabled established DDC loss, A=0, C=0 | 12 | `ddc_abort_set_evt=1`; `data_drop_evt=1`; `rxd_clr=1`; no replacement request is registered. |
| Above loss rows with P=1 | 6 | PUB samples exactly the already-registered pre-edge request once; RXD clears its request after the edge. |
| Normal disable E=0,D=0,A=0,C=0 | 16 | `ddc_epoch_live=0`, hence no abort/drop set; `upk_vld=0` and no new request is registered. |
| Pre-existing abort A=1,C=0,W=1 | 12 | `!ddc_abort_afe` blocks all new FIFO request registration; packet admission is fail-closed through `ddc_admit_ok_afe=~ddc_abort_afe`. |

## Source Priority Proof

1. `upk_vld=chn_en_afe && link_ready_afe && adi_rx_valid`, and `rxd_clr=!upk_vld || fifo_clr`. Therefore either link/raw-valid loss or normal disable cannot create a new request on that edge.
2. `ddc_abort_set_evt=!ddc_abort_afe && ddc_epoch_live && (!link_ready_afe || !adi_rx_valid)`. Since `ddc_epoch_live` includes `chn_en_afe`, normal disable is non-abort while an enabled established DDC loss sets exactly one abort/drop event.
3. `ddc_abort_afe` clears only on asynchronous AFE reset or `fifo_clr`; W1C does not feed this owner. The FIFO request registration condition includes `!ddc_abort_afe`, so all later abort-era writes are blocked.
4. `fifo_wr_valid` has one sequential owner. Its `rxd_clr` priority clears a request after a loss edge and on FIFO clear. It only sets when the pre-edge request conditions are healthy and eligible.
5. In `ADC_CHN`, the PUB FIFO samples the pre-edge registered `winc/wdata`. Consequently a P=1 request is irrevocable on a same-edge loss, whereas `fifo_clr` forces `fifo_rst_n=0` and wins over that sample. No combinational RXD-to-FIFO write path exists.

## Result And Boundary

`LAYER_A_STATIC_TRUTH_TABLE_PASS`: 144/144 enumerated rows conform to the v1.24 fail-closed, normal-disable, loss-sample, and FIFO-clear priority contract. The RTL hash is unchanged by this audit.

This is not lint, simulation, VMware, VCS/Verdi, XSIM, synthesis, implementation, timing, or board evidence. Layer-B public end-to-end verification remains required.
