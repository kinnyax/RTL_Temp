---
type: module_phase_handoff
module_name: ASU_TOP
phase: VCS
date: 2026-07-28
status: VCS_SOC_VERIFIED_USER_CONFIRMED
---

# ASU_TOP VCS阶段交接

## 范围与结论

- 基线：ASU_TOP v0.4，路径`D:\Codex\RTL_Temp\ASU_TOP\rtl`。
- 用户确认：已在VCS和Verdi中完成模块验证，功能正常。
- 本次任务：归纳模块知识、记录验证边界并建立后续任务连续性。
- 本次未执行：VCS重跑、日志导入、覆盖率分析、Vivado XSIM、综合、实现和板级验证。
- 当前Jetson替代模型：`D:\Codex\RTL_Temp\Mod\ASU_MASTER.v`，仅驱动SPI，不驱动AXI；SHA-256为`06E952E5B3B17F532953E9CBFDD83E24095E3BB29A5F31E9218F09CB7BBCAC6A`。

## 已冻结设计要点

- SPI Mode 0、MSB-first、固定`128 bit`请求/响应。
- CRC-16/CCITT-FALSE覆盖帧`[127:16]`。
- FRT拥有SPI、`txn_pd`、查询帧和响应缓存；CRC只负责计算；CTL负责三阶段控制与AXI。
- 本地仅精确截获`CHIP_ID/CHIP_VER`；其他合法地址转发AXI。
- AXI写AW/W独立握手；无硬件AXI超时。

## 证据与限制

- 历史轻量证据见[[ASU_TOP_v0.4_Development_Summary]]。
- VCS/Verdi PASS来自用户于`2026-07-28`的明确确认。
- 本次没有取得VCS命令、log、seed、coverage或FSDB，因此不补写逐case证据。
- 结构具备PPA收敛意图，但没有综合数值。

## 知识写回

- [[ASU_TOP_Top]]
- [[ASU_TOP_SPI帧_CRC与查询协议]]
- [[ASU_TOP_控制译码与AXI桥接]]
- [[ASU_TOP_验证状态与集成边界]]

## 下一动作

在具体Vivado项目任务中引用当前RTL Hash和本交接，完成官方IP互连下的系统XSIM；之后再由独立综合/PPA阶段产生量化证据。
