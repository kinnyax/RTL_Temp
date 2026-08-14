---
type: conversation_handoff
module_name: ADC_TOP
date: 2026-07-31
verification_status: READY_FOR_VCS
tags:
  - FPGA/Handoff
  - RTL
---

# ADC_TOP RTL 交接

## 范围

- 模块根：`D:\Codex\RTL_Temp\ADC_TOP`；项目关联仅供信息：Detector_v1，不取得模块所有权。
- 输入设计：`D:\Codex\Chat\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`，v0.6，SHA256 `7a250ddcfb4957e473e198210f88cc354b7fc7e16fbd383dbc3b06b73022a7d5`。
- 合同/配置/类别：`RTL_MODULE_CONTRACT_V1` / `VERILOG_2001_EXPLICIT_V1` / `MODIFIED_THIRD_PARTY_RTL`。
- 角色：Lead `/root`（ORCHESTRATION_ONLY）；RTL `/root/adc_filename_rtl_designer_r3`；Simulation `/root/adc_filename_simulation_worker_r3`；Constraint `/root/adc_filename_constraint_worker_r3`；Runner `/root/adc_filename_verification_runner_r3`；Docs `/root/adc_filename_docs_worker_r3`；Review `/root/adc_filename_review_worker_r3`（READ_ONLY）。独立 Review 的角色分离审计待执行。

## 已确认决定和工件

- 八份自写 RTL 使用大写文件名 `ADC_TOP.v`、`ADC_REG.v`、`ADC_SYNC.v`、`CHN_SYNC.v`、`ADC_TGC.v`、`ADC_PKT.v`、`ADC_RXD.v`、`ADC_CHN.v`；`rtl/filelist.f` 使用相同路径顺序；ADI 文件保持 `ADI_JESD204/jesd204_rx.v`。
- `ADC_TGC` 的状态符号使用 `TGC_*`，`ADC_PKT` 使用 `PKT_*`。仅端口和声明的逗号/分号列对齐；CDC primitive 单行是用户确认例外。
- 发布基线侧车：`D:\Codex\RTL_Temp\ADC_TOP\.work\state\ADC_TOP_Release_Baseline.json`。
- 第三方来源为 ADI HDL commit `9d5de2fc21b6069675104567c9041bcdbfbe9baa`、GPLv2；当前 `jesd204_rx.v` SHA256 `3b30e702ef440d19fb04656be61f0fc088103f3823846c4f6825b8163f873fc7`，三项许可偏差和 notices 见 `rtl/ADI_JESD204/ADI_JESD204_RX_PROVENANCE.md`。
- PUB 为 `rtl/pub_filelist.f`，SHA256 `c1600dc2d907258c42da830b10bfd275110a6b9f34b468a25d81fbc61bbee482`；本轮 Windows/VMware 比较 PASS。未来八个 FIFO 要以独立命名的 Vivado FIFO Generator XCI 替换且排除同名 PUB 定义。

## 已观察证据

| 项目 | 结果 |
| --- | --- |
| Gate 0 | `VMWARE_PREFLIGHT_PASS`，`Test-VMwareEda.ps1` exit 0 |
| VMware command | `Invoke-VMwareModuleCheck.ps1 -Module "ADC_TOP" -Root "D:\Codex\RTL_Temp\ADC_TOP" -WorkRoot "D:\Codex\RTL_Temp\ADC_TOP\.work\verification"` |
| Run / fingerprint | `ADC_TOP_a2597c502fe844988bfcf9cf9584cfcc` / `8702b4766d3d50851fe67262e2d25b1bf75df031b4027c1ea46f14da71c78027` |
| Lint / simulation | exit 0 / exit 0；9/9 PASS，0 failure/error/skip |
| Supplementary static | `test_rtl_filename_contract.py` 1/1 PASS |
| Lint residual | 197 条 nonfatal warning，待独立 Review |

证据和返回日志在 `D:\Codex\RTL_Temp\ADC_TOP\.work\verification\sim`；运行使用的远端 job 为 `/home/zezhoux/rtl_agent/jobs/ADC_TOP_a2597c502fe844988bfcf9cf9584cfcc`，remote cleanup PASS。

## 约束、PPA 与模型边界

- 约束：`DEFERRED_TO_TOP`；`D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_Constraint_Review.md` SHA256 `8e89a595492aceeb1272ef1ace878cf6ce1b06bb1951d71f41825a35c73f795b`，`NOT_APPLICABLE`，`VIVADO_RESOLUTION_NOT_RUN`。Detector_v1 系统顶层负责时钟、reset、GT、I/O 与 vendor XDC。
- PPA：`HYPOTHESIS`；无综合/实现测量。
- `MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`：VMware 不证明 Vivado JESD204 PHY/GTH 或 FIFO XCI 的等价性；VCS SoC 和集成 XSIM 是后续关闭点。

## 当前状态与下一步

- 当前阶段：`READY_FOR_VCS`；Review disposition: `ACCEPTED`；`/root/adc_filename_review_worker_r3`；`b1ae8e01c489e4bae69b25e4b866b3e954dfa6ba1dea18ca59b5ef41cd603f58`。
- 下一步：Review Worker 独立复算双指纹和发布侧车，审阅命名/格式决定、测试、197 warnings、provenance/PUB、约束延后、模型边界和下游风险。
- 尚未运行：VCS/Verdi、集成 XSIM、综合、实现、时序、bitstream、下载、硬件验证。
- 清理：`PENDING`；不得删除返回的验证证据。

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

- 候选主题：link-drop 时事务上下文丢弃但 FIFO 保留，以及 ready 跨域失效所有权。`WIKI_WRITEBACK_AUTHORIZED=FALSE`，`ARCHIVE_PUBLISH_AUTHORIZED=FALSE`；未写 Wiki/Archive。
