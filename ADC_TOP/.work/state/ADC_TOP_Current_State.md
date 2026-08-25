---
module_name: ADC_TOP
baseline_purpose: 新版 rtl-vibe 使用前基线
verification_status: DEVELOPMENT_UNVERIFIED
baseline_date: 2026-08-25
---

# ADC_TOP Current State

本目录保存下一轮按照新版 `rtl-vibe` 重新开发前的可回退基线，不是发布版本，
不得继承旧 VMware、旧 TB 或旧 Review 的 PASS 结论。

## 当前有效输入

- 设计：`D:\Codex\Vault\Archive\Modules\ADC\ADC_Design\ADC_TOP_Design.md`
- RTL：`rtl/filelist.f` 中列出的 10 个自研模块及不可修改的 PUB/ADI 黑盒依赖
- TB：`.work/verification/tb/test_ADC_TOP.py`
- 验证清单：`.work/verification/tb/verification_manifest.json`
- 验证计划：`.work/docs/ADC_TOP_Verification_Plan.md`

## 已冻结的架构方向

- `ADC_REG` 只负责寄存器配置、命令下发及收到完成/取消事件后清除 RUN，内部不实现 TGC FSM。
- 每个 `ADC_CHN` 例化一个独立 `ADC_TGC`，由通道状态机执行 TGC 状态跳转。
- `ADC_TGC` 成功或取消时只返回一个单周期事件；命令到达 AFE 时已经 disable 也必须返回取消事件。
- `ADC_RXD`、`ADC_UPK`、`CHN_SYNC` 当前代码也属于未完整验证候选，下一轮不得视为已验证基线。
- 组帧顺序、prefix、valid/zero region 及 delete 模式需继续以设计文档和原始组帧 Excel 为权威输入复核。

## 当前验证状态

- 新 TB 已替换旧的常量/空输出型检查，并完成 Python 静态与结构绑定检查。
- 当前 RTL/TB 尚未按照本次重新安装的新版 `rtl-vibe` 执行 WSL1 Icarus/cocotb RELEASE gate。
- 本轮未形成有效 release manifest，也未完成新版独立 Review。
- 历史 VMware 证据仅保留为历史记录，不绑定当前 RTL/TB。
- `VCS_VERDI=NOT_RUN`；综合、实现、时序、bitstream 和板级验证均 `NOT_RUN`。

## 下一轮入口

新对话应重新读取当时安装的 `rtl-vibe`、设计文档、最近 `AGENTS.md`、完整自研 RTL、TB 和本状态文件，
从 DEVELOPMENT 开始重新审查并验证，不复用任何旧 PASS。
