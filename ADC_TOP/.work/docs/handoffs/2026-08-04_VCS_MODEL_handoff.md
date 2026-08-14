---
type: module_phase_handoff
module_name: ADC_TOP
phase: VCS_MODEL_SETUP
date: 2026-08-04
verification_status: READY_FOR_VCS
---

# ADC_TOP AC9810/JESD204B/GTH 模型与 VCS 环境交接

## 范围与结论

- 新增一份面向 `ADC_RXD` 的 AC9810 + JESD204B + GTH 接收并行接口行为模型。
- 新增非 UVM SystemVerilog smoke TB、I/Q 示例 pattern、VCS/Verdi 环境脚本和
  Windows 到 VMware 的自动 runner。
- 已在真实 VMware VCS `R-2020.12-SP2_Full64` 中编译、运行并生成 FSDB。
- 本次为单个 `ADC_RXD` 的模型与环境 smoke，不是完整 ADC_TOP VCS SoC
  验证；生命周期状态保持 `READY_FOR_VCS`。

## 模型边界

`MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`。GTH 部分只模拟 RTL 可见的解码后
并行接口、lock/reset done/alignment、两拍延迟和错误指示；未模拟真实串行
8b/10b、模拟 CDR、jitter、均衡、DRP、vendor 精确复位时序或加密 RTL。

## 输入与 SHA256

| 输入 | SHA256 |
| --- | --- |
| `rtl/ADC_RXD.v` | `1bd6fbf3e8a2fa15646eb5bb49a480065d06e1dd421bfdd0b115858a580c0ebc` |
| `rtl/ADI_JESD204/jesd204_rx.v` | `3b30e702ef440d19fb04656be61f0fc088103f3823846c4f6825b8163f873fc7` |
| `model/AC9810_JESD204B_GTH_MODEL.sv` | `cb5d0e58849767f920d1d1eb0d433345fe57948501eb44816a3262c97912fe8b` |
| `tb/tb_adc_rxd_vcs.sv` | `003f20d6b404dbfabb5294b0ecf41ede86c1181ca63253539c3fe1a46e7c23b2` |
| `patterns/afe0_i.hex` | `034c57fc46b2f638806250ec55bf66e6209f730cdac7dee9797af26fa0bf3e8f` |
| `patterns/afe0_q.hex` | `c1020b1a744151f65c0b5e5c7e124a1a67c7a2fb0a2b348e4b1ea409c6015afb` |
| `filelist.f` | `8b7fc1bbda0d519a8ce41b3e489a52056e185cd76818abfc9a711f508e132997` |
| `scripts/vcs_env.sh` | `52e3352e63cce92baef8d62fe680add775e0516969a580228ed870ccb8677fb5` |
| `scripts/run_vcs.sh` | `2e16789696ff8b0e151e36791563bad6db83964de1948f572e50c88e36710b73` |
| `scripts/run_vcs.ps1` | `05009987de632f25b4447487e136daba2f3714e2f4fb1efb2eec00c2067657ec` |

## 精确运行与观察结果

Windows 命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\scripts\run_vcs.ps1"
```

运行 ID：`ADC_TOP_VCS_f9051f0e38c34730b1a52252517a0d3b`。

- VCS compile/elaboration/link：exit 0；KDB `0 error(s), 0 warning(s)`；
- simulation：exit 0；仿真时间 `4,966,625 ps`，CPU `0.810 s`；
- `link_ready after 248 JESD clocks`；
- 纯 ADC pattern 正确映射到 channel 0..31；
- disparity 注入被 DUT 观察；
- `VCS_SMOKE_PASS`；
- FSDB 成功生成；
- 唯一编译 warning 为启用 `-lca` 的工具 usage warning，不是 RTL warning；
- runner 默认远端清理已确认：`REMOTE_CLEAN`。

VMware 日志显示 `Aug 3 20:29 2026`，Windows 工作区日期为 2026-08-04；这是
guest 时区/时钟显示差异，未改写为同一时间戳。

## 返回证据

目录：

```text
D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\results\ADC_TOP_VCS_f9051f0e38c34730b1a52252517a0d3b
```

| 文件 | 大小 | SHA256 |
| --- | ---: | --- |
| `compile.log` | 3458 B | `de715ff1a4772db18b8a2bc7fa9fc10907b201fe80fd846d082c5479b5dcfbe9` |
| `simulation.log` | 1910 B | `b45452c2c01b11a258e4971a14586994b3665c3d83c0a290e168b6d7770e666d` |
| `adc_rxd_vcs.fsdb` | 62162 B | `a1c8ebd04b17237940985df1606363bf14e7158ad894dfbd1f4f8e2fb698b6d4` |

## 后续动作与风险

- 使用者可先修改 `patterns/afe0_i.hex`、`afe0_q.hex` 和 TB scoreboard 编写
  新 pattern；具体 task/运行方法见 `ADC_TOP_AC9810_VCS_MODEL_README.md`。
- 若需要在 VMware Verdi 中保留编译数据库，显式使用 `-KeepRemote`；正常运行
  不保留 guest 副本。
- 完整 `VCS_SOC_VERIFIED` 仍需按既有验证计划覆盖八路 AFE、AXI-Lite、CDC、
  FIFO、TGC、packet、异常恢复与随机/边界场景，并经过对应阶段审查。
- 未运行 Vivado XSIM、综合、实现、时序、bitstream 或板级验证。

