---
type: module_phase_handoff
module_name: ADC_TOP
phase: VCS_ENV_SETUP
date: 2026-08-05
verification_status: READY_FOR_VCS
---

# ADC_TOP VMware常驻VCS环境交接

## 结论

已按VMware现有ASU环境的工作方式建立ADC常驻仿真工程。用户可在VMware桌面
终端编辑独立`Pxxx/pattern.vh`、运行`./gold_run`，并使用`./run_deb`打开FSDB。

最终组织决定：

- 通用模型文件和module名统一为`AC9810_MASTER`；
- 模型位于`/home/zezhoux/Project/pub/model/AC9810_MASTER.sv`；
- `Detector/pat/adc/common`只保存`sim_top.sv`；
- 每个Pxxx目录只保存`pattern.vh`及真正由具体用例需要的附属输入；P001不使用hex；
- P001通过`set_i_sample/set_q_sample`直接设置32通道容器；
- `sim_top`例化完整`ADC_TOP`、8份`AC9810_MASTER`与`AXI_MASTER`。

## VMware路径

| 角色 | 路径 |
| --- | --- |
| DUT仿真镜像 | `/home/zezhoux/Project/Detector/rtl/ADC` |
| 公共模型 | `/home/zezhoux/Project/pub/model/AC9810_MASTER.sv` |
| 公共TB | `/home/zezhoux/Project/Detector/pat/adc/common/sim_top.sv` |
| Pattern | `/home/zezhoux/Project/Detector/pat/adc/P001_adc_link/pattern.vh` |
| 运行目录 | `/home/zezhoux/Project/Detector/sim/adc/rtl` |
| 环境脚本 | `/home/zezhoux/Project/Detector/sim/adc/vcs_env.sh` |

Windows中的`D:\Codex\RTL_Temp\ADC_TOP\rtl`仍是ADC业务RTL规范源；VMware
`Detector/rtl/ADC`是本次用户明确要求的常驻仿真工作副本。

## 最终验证

命令：

```bash
cd /home/zezhoux/Project/Detector/sim/adc/rtl
./gold_run
```

观察结果：

- VCS/VCS runtime：`R-2020.12-SP2_Full64`；
- top：`sim_top`；
- 编译明确包含`/home/zezhoux/Project/pub/model/AC9810_MASTER.sv`；
- KDB：`0 error(s), 0 warning(s)`；
- `P001_adc_link`：AFE0 CGS、4个ILAS multiframe、DATA和首个payload通过；
- 最终标记：`[P001][PASS]`和`PASS ^_^`；
- FSDB：191681 B；
- 唯一工具warning为`-lca` usage warning，不是RTL warning。

## Linux文件属性复核

Windows递归`scp`首次创建的ADC目录mode为`707`，与ASU的`775`不一致。现已
按ASU实测属性完成修正：

- `Detector/rtl/ADC`、`Detector/pat/adc`、`Detector/sim/adc`及其目录：`775`；
- RTL、`AC9810_MASTER.sv`、`sim_top.sv`、`pattern.vh`、README和Makefile：`664`；
- `gold_run/run_sim/run_deb/run_clr/vcs_env.sh`：`755`；
- owner/group：`zezhoux:zezhoux`；
- ADC三个范围内mode `707`计数为0；`make list`输出`rtl`，四个运行入口保持可执行。

本次只修改Linux mode，不改变文件内容，因此既有源码、日志和FSDB SHA256不变，
未重复运行VCS。

最终证据SHA256：

| 文件 | SHA256 |
| --- | --- |
| `AC9810_MASTER.sv` | `4d0856887a1aa0e7e7dba89c22bda3e13231400c02b407b623f3c5e60d3b56b0` |
| `sim.fsdb` | `45885a2d67d1e72aaa1af1a0eb9685fe325d73190c797c0361a31e0873fa63b3` |
| `log/vlogan.log` | `a8fc6d2254e09ef932af6fd840cb7d3b745d1e00cac528cf8becc81c3c771091` |
| `log/vcs.log` | `124741aeb5f707a8ed1bda4cb62d7d6110530f355f18f45c5768b1872a31994d` |
| `log/sim.log` | `22039bb3e38ed54d81330dcc04d1c8d7d2275b88196adbf2f8a51e6d6bf14527` |

## 边界

`MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT`。本次建立的是可供pattern开发的完整
ADC_TOP VCS环境，但当前P001只验证AFE0链路与首个payload，尚未完成既有VCS SoC
验证计划的全部八路、寄存器、FIFO、TGC、packet、背压、异常及随机覆盖。因此
模块生命周期仍为`READY_FOR_VCS`，不宣称`VCS_SOC_VERIFIED`。
