# ADC_TOP ASU风格 VMware VCS环境

## 目录

```text
/home/zezhoux/Project/
|-- pub/model/AC9810_MASTER.sv
`-- Detector/
    |-- rtl/ADC/
    |-- pat/adc/
    |   |-- common/sim_top.sv
    |   |-- file_list
    |   `-- P001_adc_link/pattern.vh
    `-- sim/adc/
        |-- vcs_env.sh
        |-- Makefile
        `-- rtl/
            |-- gold_run
            |-- run_sim
            |-- run_deb
            `-- run_clr
```

结构与 VMware 现有 ASU 环境一致：DUT源文件、pattern、常驻编译运行目录分开。
`sim_top.sv`例化完整`ADC_TOP`、8份`AC9810_MASTER`和一份`AXI_MASTER`。

Linux文件属性按ASU环境归一化：工程目录为`775`，RTL、模型、TB、pattern、
README和Makefile等普通文件为`664`，`gold_run/run_sim/run_deb/run_clr`及
`vcs_env.sh`为`755`，owner/group为`zezhoux:zezhoux`。从Windows再次递归
复制新目录后，应复查新建目录没有被`scp`设置成`707`。

## 日常运行

在 VMware 桌面终端执行：

```bash
cd /home/zezhoux/Project/Detector/sim/adc/rtl
./gold_run
./run_deb
```

`gold_run`自动加载VCS/Verdi环境、清理上一次生成物、编译当前pattern、运行VCS
并生成`sim.fsdb`。`run_deb`使用当前KDB打开该FSDB。通过SSH已验证Verdi命令
和FSDB/KDB存在；GUI应从VMware桌面终端启动。

也可绕过`gold_run`直接指定pattern：

```bash
cd /home/zezhoux/Project/Detector/sim/adc/rtl
./run_sim Detector adc P001_adc_link -fsdb -time=20
```

清理命令：

```bash
./run_clr --wave-only
./run_clr --all
```

## 新建pattern

复制现有P001：

```bash
cp -r /home/zezhoux/Project/Detector/pat/adc/P001_adc_link \
      /home/zezhoux/Project/Detector/pat/adc/P002_my_case
vi /home/zezhoux/Project/Detector/pat/adc/P002_my_case/pattern.vh
vi /home/zezhoux/Project/Detector/sim/adc/rtl/gold_run
```

每个Pxxx目录只需要`pattern.vh`。将新目录名加入`gold_run`的`PAT_LIST`即可。
常驻pattern不依赖hex文件。

## pattern常用接口

### AXI-Lite寄存器

```systemverilog
reg [31:0] rd_data;

axi_master.write_word(16'h0000, 32'h0000_0001);
axi_master.read(16'h000c, rd_data);
```

### 设置AC9810通道数据

模型实例为`afe0_model`至`afe7_model`。每颗AFE有32个I通道容器和32个Q通道
容器：

```systemverilog
integer ch;
for(ch=0; ch<32; ch=ch+1) begin
    afe0_model.set_i_sample(ch, ch + 1);
    afe0_model.set_q_sample(ch, 16'h0100 + ch);
end
```

### 选择数据模式

```systemverilog
// 0=纯ADC，1=抽取，2=DDC
afe0_model.configure_stream(stream_mode, dec_m, dec_del_mode);
```

DUT的`ADC_CTL/FRAME_CFG`必须与模型模式一致。

### 启动和SYSREF

```systemverilog
afe_model_en[0] = 1'b1;
axi_master.write_word(16'h0000, 32'h0000_0001);

wait(afe_rx_reset_done[0] && afe_pll_lock[0] &&
     (afe_byte_aligned[0] == 2'b11));
repeat(80) @(posedge jesd_clk[0]);
pulse_sysref();
```

### 错误与掉线注入

```systemverilog
afe0_model.inject_disparity(8'h01);
afe0_model.inject_notintable(8'h10);

fork
    afe0_model.drop_link(32);
join_none
```

### AXI-Stream

- `m_axis_tdata[0:7]`
- `m_axis_tkeep[0:7]`
- `m_axis_tvalid[7:0]`
- `m_axis_tlast[7:0]`
- `axis_ready[7:0]`

公共task `wait_afe0_axis_beat(data,last)`可用于AFE0示例。其他AFE可在pattern中按同样
方法等待对应握手。

## 模型边界

`AC9810_MASTER`模拟AC9810固定JESD204B格式以及GTH解码后的并行接收接口，包含
CGS、4个ILAS multiframe、DATA、lock/reset done/alignment、两拍并行延迟以及
disparity/not-in-table注入。它不模拟真实串行8b/10b比特流、模拟CDR、jitter、
均衡、DRP或Xilinx加密GTH时序。

```text
MODEL_EQUIVALENCE=NON_VENDOR_EQUIVALENT
```
