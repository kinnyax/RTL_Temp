---
type: verification_plan
module_name: ADC_TOP
date: 2026-07-31
verification_status: READY_FOR_VCS
tags:
  - FPGA/RTL
  - Verification
---

# ADC_TOP 验证计划与已观察结果

## DUT 与命名基线

- 合同：`RTL_MODULE_CONTRACT_V1`；配置：`VERILOG_2001_EXPLICIT_V1`；类别：`MODIFIED_THIRD_PARTY_RTL`。
- 自写 RTL：`ADC_TOP.v`、`ADC_REG.v`、`ADC_SYNC.v`、`CHN_SYNC.v`、`ADC_TGC.v`、`ADC_PKT.v`、`ADC_RXD.v`、`ADC_CHN.v`，均位于 `D:\Codex\RTL_Temp\ADC_TOP\rtl`；`rtl/filelist.f` 以相同大写文件名列出。第三方 `ADI_JESD204/jesd204_rx.v` 保持原文件名。
- 静态回归：`D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\test_rtl_filename_contract.py` 断言八个大写文件、filelist 顺序、无 `ST_` 状态、`TGC_`/`PKT_` 前缀；本轮 supplementary 结果为 1/1 PASS。
- 格式决定：仅端口/声明的逗号、分号列对齐；已确认 CDC 原语保持单行。

## 测试环境和覆盖

- TB：`D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\test_ADC_TOP.py`，SHA256 `c565146a0767992854bd238b91edb6b07092ea56f5c4aab3826c7728f1a8bd86`。
- 静态命名测试：`D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\test_rtl_filename_contract.py`，SHA256 `bd5a6abcf813ab767de94078704e804b6bbc1471ab97138bc2bc78b9da3c8068`。
- manifest：`D:\Codex\RTL_Temp\ADC_TOP\.work\verification\tb\verification_manifest.json`，SHA256 `646671be38ad6997ab93d44f774ab4dedca01fb1da336cf9596779079e447a16`；确定性 seed `20260730`，有限 timeout `600 s`。
- 三个正常配置：10-bit 右对齐固定包；12-bit 左对齐 `DEC_M=32`；14-bit 右对齐 `DEC_M=32` DDC I/Q。
- 覆盖 reset、AXI AW/W 独立到达、WSTRB 拒绝、读写 response backpressure、FIFO clear/空/满/overflow、link-drop 不完整块丢弃、256 payload 固定包、TGC、ADI CGS/ILAS/SYSREF、数据映射与 AXIS backpressure。数据路径采用 end-to-end scoreboard，控制路径采用可观察断言。

## PUB 与模型边界

- PUB manifest：`D:\Codex\RTL_Temp\ADC_TOP\rtl\pub_filelist.f`，SHA256 `c1600dc2d907258c42da830b10bfd275110a6b9f34b468a25d81fbc61bbee482`；Windows 根 `D:\Codex\RTL\PUB`，VMware 根 `/home/zezhoux/Project/pub/rtl`。
- 本轮 PUB 比较：PASS。用于 `lib.v`、`cell.v` 和 FWFT `async_fifo_fwft` 完整传递集。
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`：行为测试不证明未来 JESD204 PHY/GTH 或 FIFO Generator XCI 的 vendor 初始化、延迟、复位与 flags 等价；这些差异必须由 VCS SoC 和集成 XSIM 关闭。

## 已观察 VMware 证据

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.codex\skills\rtl-vibe-design\scripts\verification\Test-VMwareEda.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Administrator\.codex\skills\rtl-vibe-design\scripts\verification\Invoke-VMwareModuleCheck.ps1" -Module "ADC_TOP" -Root "D:\Codex\RTL_Temp\ADC_TOP" -WorkRoot "D:\Codex\RTL_Temp\ADC_TOP\.work\verification"
```

- Gate 0：`VMWARE_PREFLIGHT_PASS`，exit 0。
- 运行：`ADC_TOP_a2597c502fe844988bfcf9cf9584cfcc`；验证输入指纹 `8702b4766d3d50851fe67262e2d25b1bf75df031b4027c1ea46f14da71c78027`。
- orchestrator、Verilator lint 和 cocotb/Icarus simulation exit code 均为 0；9/9 行为测试 PASS，0 failure/error/skip；补充静态命名测试 1/1 PASS。
- 197 条 Verilator 非致命 warning 已保留，尚未由独立 Review 接受或豁免。
- 返回证据位于 `D:\Codex\RTL_Temp\ADC_TOP\.work\verification\sim`；清理状态：`PENDING`，不得因 PASS 删除。

## 约束、PPA 与下游

- Constraint：`DEFERRED_TO_TOP`；审查文件 `D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Review.md`，SHA256 `8e89a595492aceeb1272ef1ace878cf6ce1b06bb1951d71f41825a35c73f795b`；`NOT_APPLICABLE` / `VIVADO_RESOLUTION_NOT_RUN`。
- PPA：`HYPOTHESIS`；尚未运行综合或实现。
- VCS SoC 要求非 UVM SystemVerilog stimulus、SVA、scoreboard、功能覆盖、FSDB/debug 信号和官方 IP 替换差异检查；本阶段没有运行 VCS/Verdi、XSIM、综合、实现或板级验证。

## 发布状态

- 文档阶段：`READY_FOR_VCS`；发布基线侧车路径为 `D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json`。
- Review disposition: `ACCEPTED`；`/root/adc_filename_review_worker_r3`；`b1ae8e01c489e4bae69b25e4b866b3e954dfa6ba1dea18ca59b5ef41cd603f58`。

## FINALIZATION_COMMIT

```text
FINALIZATION_COMMIT_V1_BEGIN
允许的机械替换仅限以下四份待审 Markdown：
1. ADC_TOP_Current_State.md：YAML verification_status 和“阶段”从 REVIEW_PENDING 替换为 READY_FOR_VCS；“独立 Review 尚未执行”替换为“独立 Review 已接受”；写入接受 Review 的 ID 与 handoff SHA256。
2. 2026-07-31_RTL_handoff.md：YAML verification_status 和“当前阶段”从 REVIEW_PENDING 替换为 READY_FOR_VCS；“Review disposition: PENDING”替换为“ACCEPTED”；写入接受 Review 的 ID 与 handoff SHA256。
3. ADC_TOP_VCS_SOC_HANDOFF.md：YAML verification_status 从 REVIEW_PENDING 替换为 READY_FOR_VCS；“Review disposition: PENDING”替换为“ACCEPTED”；写入接受 Review 的 ID 与 handoff SHA256。
4. ADC_TOP_Verification_Plan.md：YAML verification_status 和“文档阶段”从 REVIEW_PENDING 替换为 READY_FOR_VCS；“Review disposition: PENDING”替换为“ACCEPTED”；写入接受 Review 的 ID 与 handoff SHA256。
唯一允许的占位符绑定：/root/adc_filename_review_worker_r3 -> <接受本基线的 Review Worker ID>；b1ae8e01c489e4bae69b25e4b866b3e954dfa6ba1dea18ca59b5ef41cd603f58 -> <该 Review handoff 的观察到 SHA256>。
除上述状态、处置文本和两个字面占位符外，任何字节变更均使 Review 失效；侧车 JSON 不得在机械收尾中变更。
FINALIZATION_COMMIT_V1_END
```

## 知识候选

- 候选：link-drop 后事务上下文清除、FIFO 保留与跨域 ready 失效处理；`WIKI_WRITEBACK_AUTHORIZED=FALSE`，`ARCHIVE_PUBLISH_AUTHORIZED=FALSE`。
