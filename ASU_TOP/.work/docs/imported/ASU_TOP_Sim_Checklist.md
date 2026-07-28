---
type: simulation_checklist
module_name: ASU_TOP
date: 2026-07-27
verification_status: Verified
tags:
  - FPGA
  - RTL
  - ASU_TOP
  - Verification
---

# ASU_TOP v0.4 仿真检查清单

## 最终架构与 PPA 收敛

依据 [[ASU_TOP_Design]] v0.4（2026-07-27）冻结基线，外部 128-bit ASU 帧协议、dummy 轮询、200 ns 帧间隔、CRC-16/CCITT-FALSE、SPI 同步结构和 AXI4-Lite Master 时序保持不变。本轮完成以下最终收敛：

- 本地寄存器只对 `CHIP_ID_ADDR` 与 `CHIP_VER_ADDR` 做精确比较，内部命名为 `chip_id/chip_ver`；删除旧 ASU 地址范围和 4-byte 对齐拒绝逻辑。
- 读写请求只要未命中两个本地寄存器，就按原地址发起 AXI4-Lite 事务；因此旧窗口空洞 `0x10000008` 和非对齐地址 `0x20000002` 均进入 AXI 路径。
- `ASU_CTL` 请求缓存从 128 bit 缩为 80 bit，只保留事务控制所需字段。
- CTL 以 `CTL_REQ_ERR` 表示请求字段错误，并把原始 `AXI_RESP` 返回 FRT；FRT据 `CTL_REQ_ERR` 与原始 AXI response 生成最终 `axi_status`。
- FRT 最终响应有效标志、最终帧和 WAIT 帧分别统一为 `resp_valid`、`resp_frame`、`wait_resp_frame`。
- 代码采用紧凑声明、短实例名和 `N'd0` 清零风格，不改变接口或协议功能。
- 最终格式遵循 RTL_Schema 的统一分列规则：ANSI 端口按 direction/type/width/name/comma 分列；`parameter/localparam/wire/reg` 声明按等号和分号分列；声明顺序固定为 `localparam -> 全部 wire -> 全部 reg`；实例按点号/端口名/括号/逗号分列。内部短名规则继续保留。

## 最终内部命名规则

跨模块接口继续使用完整的 `FRT_REQ_*`、`CTL_RSP_*`、`M_AXI_*` 命名；模块内部统一为：

- pending：`*_pd`，例如 `txn_pd/req_crc_pd/wait_crc_pd/resp_crc_pd/ctl_req_pd`；
- handshake：`*_hs`，FRT/CTL 内部使用 `req_hs/resp_hs`；
- 计数和移位：`*_cnt`、`*_shift`，例如 `bit_cnt/rx_shift/tx_shift`；
- 状态机：`state/state_nxt`；
- AXI 通道握手：`aw_hs/w_hs/b_hs/ar_hs/r_hs`；
- CRC 结果事件：`*_crc_ok/*_crc_err/*_crc_done`。

最终重命名后执行完整回归，证明风格变更未改变可观察行为。

按上述 RTL_Schema 规则完成最终格式修正后再次执行同一完整回归；结果仍为 `6/6 PASS`、累计 `437475.01 ns`，独立 Review 仍为 `ACCEPTED`，证明该轮仅改变排版，没有引入功能差异。

## 覆盖矩阵

| 检查项 | 最终结果 |
| --- | --- |
| 精确 `chip_id/chip_ver` 本地读及只读写错误 | `local_registers_and_malformed_frames`：PASS |
| 旧窗口空洞 `0x10000008` 的 AXI 读写转发 | PASS |
| 非对齐地址 `0x20000002` 的 AXI 读写转发 | PASS |
| AXI AW/W 次序、WAIT 快照、raw AXI response 与 `axi_status` | `external_axi_ordering_wait_snapshot_and_response_codes`：PASS |
| 查询长度与复位取消 | `query_lengths_and_reset_cancellation`：PASS |
| `CS_N` 低电平跨复位后的重新武装 | `reset_release_while_cs_low_requires_rearm`：PASS |
| 重复 WAIT 与有界永久 AXI 停滞 | `repeated_wait_and_bounded_permanent_axi_stall`：PASS |
| `resp_valid/resp_frame` 仅在最终响应完整消费后释放 | `final_response_is_consumed_only_on_cs_release`：PASS |

## 最终执行证据

实际执行命令：

```powershell
wsl.exe -d Ubuntu-Codex -- bash -lc "cd /mnt/d/Codex/RTL_Temp/Detector && make check MODULE=ASU_TOP VERIFY_SCRIPTS_DIR=/mnt/c/Users/Administrator/.codex/skills/rtl-vibe-design/scripts/verification"
```

- Verilator lint：PASS。
- cocotb/Icarus：`TESTS=6 PASS=6 FAIL=0 SKIP=0`。
- 随机种子：`20260723`。
- 累计仿真时间：`437475.01 ns`。
- 最终独立 Review：`ACCEPTED`，无 release-blocking finding。

该结果对应的当前 RTL SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `ASU_TOP.v` | `418911E527531A5FE4773790CF7C8214FCB826F57DADE792FF2DBF5B1F478C8F` |
| `ASU_FRT.v` | `2960D19396EEB814B20F1B3F1F738484A462996C84078E2BD17A93C1822DAC77` |
| `ASU_SYN.v` | `496C9086DDB83402F6DB2F842FF1E6B84EE32FE1EC348775BA2135B2278EE0C3` |
| `ASU_CRC.v` | `043B48850A8D8A159A8573C9E24446E0E2A115368B5C4522C9E0B74DE0A77A79` |
| `ASU_CTL.v` | `0EB4AE9FD1D9B779AD693AD0C0255E40003DC29CBBBD89BED3565B1FE6D9CB9C` |
| `CRC16.v` | `B5AFC1F2AFA8755F25DB36A185765B66E6CA40959520C0A89F5E068DDD3FDA39` |
| `filelist.f` | `2F0012465F2C114AC98E6084FEAE674F1A05A5B38AF2B11E48B0EA4F580F2F85` |

证据与产物：

- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_summary.md`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_summary.md)）
- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_cocotb.log`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_cocotb.log)）
- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_verilator_lint.log`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_verilator_lint.log)）
- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_lint_flow.log`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_lint_flow.log)）
- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_cocotb_results.xml`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_cocotb_results.xml)）
- `D:\Codex\RTL_Temp\Detector\sim\ASU_TOP\ASU_TOP_cocotb_build\ASU_TOP.fst`（[local URI](file:///D:/Codex/RTL_Temp/Detector/sim/ASU_TOP/ASU_TOP_cocotb_build/ASU_TOP.fst)）

## 残余风险与验收边界

- `DECLFILENAME`（`ASU_SYN.v`/`ASU_LEVELS_SYNC`）及保留接口参数等 lint warning 经最终 Review 判定为非阻塞。
- `ASU_FRT/ASU_CTL` 内部 ready/valid 的逐周期动态波形证据仍为 `NOT_PROVEN`；黑盒协议检查、AXI 事务覆盖及最终 Review 支持当前验收。
- 删除地址范围与对齐过滤是 v0.4 明确策略：除精确 `chip_id/chip_ver` 外的地址由下游 AXI slave 决定响应，ASU 不再预先拦截。
- 本结果仅覆盖纯 RTL lint 与 cocotb/Icarus 仿真，不代表 Vivado 综合、实现、时序收敛、IO 时序或板级验证。
