# AC9810 JESD204B + GTH 行为模型与 VCS 使用说明

> 本文保留早期一次性 Windows runner 的诊断方式。日常手工编写 pattern、运行
> VCS 和打开 Verdi，请使用常驻 ASU 风格环境及
> `ADC_TOP_ASU_STYLE_VCS_ENV_README.md`。常驻环境中的模型最终命名为
> `AC9810_MASTER`，位于 VMware `Project/pub/model`；常驻 `pat/adc` 不使用
> hex pattern。

## 1. 用途与边界

本模型用于在 VMware 的 Synopsys VCS 中驱动 `ADC_RXD`，方便编写非 UVM
SystemVerilog pattern，验证 JESD204B 建链、AC9810 数据顺序、解包和异常路径。

模型固定采用当前 ADC 设计配置：

- 每颗 AFE：`M=16`、`L=2`、`N'=16`、`S=1`、`F=16`、`K=16`；
- 默认线速率 6.4 Gbps，GTH 解码后的并行时钟为 160 MHz；
- 每个 JESD 时钟每 lane 输出 4 octet；
- lane 0 位于 `rx_data[31:0]`，lane 1 位于 `rx_data[63:32]`；
- CGS 使用 K28.5，ILAS 输出 4 个 multiframe，并在首尾产生 `/R/`、`/A/`；
- DATA 按 AC9810 CML 顺序发送 32 个 16-bit 通道容器。

`AC9810_MASTER` 是 **GTH 接收并行接口行为模型**。它建模
PLL lock、RX reset done、comma/byte alignment、两拍并行延迟、解码后 octet、
K 字符标志、disparity 和 not-in-table 错误。它不建模真实串行 8b/10b code
group、模拟 CDR、jitter、均衡、DRP、Xilinx GTH 精确复位时序或加密 vendor
RTL。因此：

```text
MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT
```

## 2. 文件位置

```text
D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\
|-- filelist.f
|-- model\AC9810_MASTER.sv
|-- patterns\afe0_i.hex
|-- patterns\afe0_q.hex
|-- scripts\vcs_env.sh
|-- scripts\run_vcs.sh
|-- scripts\run_vcs.ps1
|-- tb\tb_adc_rxd_vcs.sv
`-- results\<run-id>\
```

Windows 下的上述文件是唯一规范输入。runner 每次建立独立 VMware 作业，
上传必要文件、运行 VCS、回收日志和 FSDB；正常运行结束后删除远端临时作业。

## 3. 编写数据 pattern

`afe0_i.hex` 与 `afe0_q.hex` 均为 `$readmemh` 文件，每个文件正好 32 行，
每行一个无前缀的 16-bit 十六进制数：

```text
0001  // channel 0
0002  // channel 1
...
0020  // channel 31
```

实际文件中不要写行尾注释；上例注释只用于解释。纯 ADC 和抽取模式使用 I
文件；DDC 模式在 I、Q 两个 32 通道块之间交替。文件中的数值是 JESD 传输的
16-bit 容器，`SMP_PREC` 与 `FRAME_FMT` 的最终截取/符号处理仍由 DUT 完成。

推荐先复制示例文件，再把 `run_vcs.ps1` 上传列表中的 pattern 文件名替换为
自己的用例，或直接修改 `afe0_i.hex`/`afe0_q.hex`。若预期值也改变，需要同步
修改 `tb_adc_rxd_vcs.sv` 中的 scoreboard。

## 4. 模型控制接口

TB 中的模型实例名为 `ac9810_gth_model`。可直接调用以下 task：

```systemverilog
ac9810_gth_model.load_i_pattern(pattern_i_path);
ac9810_gth_model.load_q_pattern(pattern_q_path);

// stream_mode: 0=纯 ADC，1=抽取，2=DDC
ac9810_gth_model.configure_stream(stream_mode, dec_m, dec_del_mode);

// mask 的 bit[3:0] 对应 lane0 的四个 octet，bit[7:4] 对应 lane1。
ac9810_gth_model.inject_disparity(8'h01);
ac9810_gth_model.inject_notintable(8'h10);

// 强制撤销 GTH lock/reset/alignment，保持指定 JESD 时钟周期。
fork
    ac9810_gth_model.drop_link(32);
join_none
```

`configure_stream()` 使用与当前 `ADC_RXD` 相同的纯 ADC/抽取/DDC 前缀长度
计算。改变 `SMP_MODE`、`DEC_M` 或 `DEC_DEL_MODE` 时，必须在 DUT 和模型两侧
配置一致。

主要可观测相位：`0=IDLE`、`1=CGS`、`2=ILAS`、`3=DATA`。模型通过以下
GTH 可见接口连接 `ADC_RXD`：

```text
rx_data[63:0], rx_charisk[7:0], rx_disperr[7:0],
rx_notintable[7:0], rx_reset_done, pll_lock, byte_aligned[1:0]
```

## 5. 在 Windows 启动 VMware VCS

在 PowerShell 中执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\scripts\run_vcs.ps1"
```

runner 已固定并验证以下环境：

- VCS：`R-2020.12-SP2_Full64`；
- Verdi：`R-2020.12-SP2`；
- `VCS_ARCH_OVERRIDE=linux`，VCS 使用 `-full64`；
- FSDB PLI 使用 Verdi `share/PLI/VCS/LINUX64`；
- license 路径由 `vcs_env.sh` 配置，但日志不会输出 license 内容。

每次运行的结果位于：

```text
D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\results\<run-id>\
```

其中包含 `compile.log`、`simulation.log`、`adc_rxd_vcs.fsdb`、
`SHA256SUMS` 和 `transport.log`。

需要在 VMware 中保留可供 Verdi 打开的编译数据库时，显式增加
`-KeepRemote`：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\Codex\RTL_Temp\ADC_TOP\.work\verification\vcs\scripts\run_vcs.ps1" `
  -KeepRemote
```

runner 会打印 `VCS_REMOTE_JOB`。在 VMware 桌面终端中 source 该作业下的
`vcs/scripts/vcs_env.sh`，然后用 Verdi 打开 `results/adc_rxd_vcs.fsdb` 和对应
build database。`-KeepRemote` 只用于主动调试；调试完成后由使用者删除该精确
作业目录。

## 6. 当前已观察证据

2026-08-04 的真实 VCS smoke 运行：

```text
run-id: ADC_TOP_VCS_f9051f0e38c34730b1a52252517a0d3b
VCS compiler/runtime: R-2020.12-SP2_Full64
link_ready: 248 JESD clocks
VCS_SMOKE_PASS: CGS/ILAS/DATA, AC9810 mapping and GTH error injection passed
```

该测试只实例化一份模型和一份 `ADC_RXD`，已覆盖单颗 AFE 的 CGS、ILAS、
DATA、32 通道映射以及 disparity 注入。它没有覆盖完整八通道 `ADC_TOP`、
AXI-Lite、FIFO/TGC/packet 全系统场景，因此模块生命周期仍保持
`READY_FOR_VCS`，不宣称 `VCS_SOC_VERIFIED`。
