# ADC VCS Environment

本目录采用与ASU相同的常驻VCS组织方式。

```bash
cd /home/zezhoux/Project/Detector/sim/adc/rtl
./gold_run
./run_deb
```

新增pattern时复制`/home/zezhoux/Project/Detector/pat/adc/P001_adc_link`，只修改
新目录中的`pattern.vh`，再把目录名加入`rtl/gold_run`的`PAT_LIST`。

通用模型位于：

```text
/home/zezhoux/Project/pub/model/AC9810_MASTER.sv
```

常用模型task：`set_i_sample`、`set_q_sample`、`configure_stream`、
`inject_disparity`、`inject_notintable`和`drop_link`。

本环境的Linux属性基准：目录`775`，普通文件`664`，运行脚本和`vcs_env.sh`
为`755`，owner/group为`zezhoux:zezhoux`。从Windows复制新目录后需要复查
目录未被创建成`707`。

详细说明见Windows工作区：

```text
D:\Codex\RTL_Temp\ADC_TOP\.work\docs\ADC_TOP_ASU_STYLE_VCS_ENV_README.md
```
