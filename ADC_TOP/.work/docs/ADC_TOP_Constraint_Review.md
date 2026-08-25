---
type: module_constraint_review
module_name: ADC_TOP
date: 2026-08-25
reviewer: /root/adc_v02_verification
design_sha256: 6F25849D110AC136168C9463795B1BF20786F0AC551562B3238B29D7804BB9DB
classification: DEFERRED_TO_TOP
dependency_scope: EXTERNAL_ONLY
static_review_status: NOT_APPLICABLE
vivado_resolution_status: VIVADO_RESOLUTION_NOT_RUN
---

# ADC_TOP v0.2 Constraint Review

Classification is `DEFERRED_TO_TOP`. The owning system-integration project
must constrain SYS/ADC/AFE/JESD clock sources and relationships, reset release,
PHY/GTH and board interfaces, AXI/AXIS I/O timing, external TGC setup/hold and
the selected vendor FIFO/IP implementation. No module XDC is emitted.

The v0.2 structural anchors and their exact source hashes are frozen in
`ADC_TOP_Constraint_Dependency_Manifest.tsv`. They retain external clocks and
public ports only; no module-local pin, cell, generated-clock or timing
exception endpoint is justified. `VIVADO_RESOLUTION_NOT_RUN`: object resolution,
vendor-XDC interaction, order, timing and clock-interaction evidence remain
integration-phase work.

The v0.2 VMware sanity pass does not resolve Vivado objects or alter this
classification; `VIVADO_RESOLUTION_NOT_RUN` remains binding.

The dependency manifest was refreshed for the current RTL hashes. The required
fresh VMware batch passed for fingerprint
`32f8341ca9fcbc81c6c4e97360a31ead8a41d55e9f20b48c210cc1e54381e2da`;
historical VMware evidence was not reused.
