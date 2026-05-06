# 工程状态记录

作者：Egor Izmaylov

## 2026-05-06 清理与复测状态

- 仓库清洁：已补充 `.gitignore` 和 `.gitattributes`，Vivado/HLS/XSim 派生产物、备份目录、`hls_work/` 和临时目录不进入提交。
- 编码状态：手工维护 HDL/HLS/TB/Tcl/BAT/Markdown 均通过 UTF-8 解码检查；HDL/HLS 源码不添加 BOM。
- 注释状态：手工维护源码已追加中文维护说明和作者 `Egor Izmaylov`；Vivado/IP 生成物和第三方支撑代码不手工改。
- 功能验证：`80_TB/run_tb_vbram_hls_integration.bat` 通过，输出 `PASS: tb_vbram_hls_integration`，覆盖 `0x0/0x1/0x3/0x7`。
- HLS 验证：`csim` 通过；`csynth` 通过并导出 IP，II=1，Latency=4 cycles，Estimated Fmax=227.84 MHz；`cosim` 通过，C/RTL co-simulation `PASS`。
- Vivado 2025.2：`build_project_2025.tcl -tclargs reset` 完整构建通过并生成 bitstream；最终时序 `WNS=0.010 ns`、`TNS=0.000 ns`。
- Vivado 2020.2：当前机器未安装，只完成静态扫描；`.xpr/.bd` 仍含 2025.2 元数据、绝对路径和 ModelSim 遗留字段，需 2020.2 实机验证。

## 1. 当前结论

- 当前工程文件为 `10_PRJ/00_PRJ.xpr`，综合顶层为 `20_HDL/21_TOP/EB4110_10V10_TOP.v`。
- 工程已在 `Vivado 2025.2` 上完成 HLS 集成、仿真验证、综合、实现和 bitstream 生成。
- 当前可直接上板的产物位于：
  - `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.bit`
  - `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.ltx`
- 本次新增功能为“基于 HLS 的视觉预处理链路”，当前实现为：
  - 以“去畸变处理框架”为名义接入视频链路
  - 为验收提供明显可见的棋盘格叠加与按帧翻相演示效果

## 2. 工程主功能概述

- 本工程是 EB4110 预处理板 FPGA 工程，主体结构为 `Zynq PS + PL 逻辑 + SRIO/RapidIO 视频链路 + DDR3 缓存 + DMA + 6 路 RS422`。
- 视频主链路可概括为：
  - `SRIO 输入 -> BRAM/缓存组织 -> 视频处理 -> SRIO 输出`
- 当前联调结论表明，输出图像频率约为 `2Hz`。本次加入的演示逻辑会随输出帧翻转棋盘相位，因此肉眼可以看到明显变化。

## 3. 代码级改动总结

### 3.1 HLS 算法工程

- 新增 HLS 工程目录：`hls/undistort_demo/`
- HLS 顶层源码：`hls/undistort_demo/src/undistort_demo_hls.cpp`
- 关键逻辑：
  - `apply_undistort_foundation(...)`
    - 位置：`hls/undistort_demo/src/undistort_demo_hls.cpp`
    - 功能：提供基础“去畸变处理框架”，当前实现为轻量像素修正骨架，便于后续替换为真实标定映射。
  - `apply_demo_overlay(...)`
    - 位置：同文件
    - 功能：叠加大块棋盘格，用于板级验收时确认数据经过了处理 IP。
  - `undistort_demo_hls(...)`
    - 位置：同文件
    - 功能：对 AXIS 输入流做模式控制、像素处理和按帧翻相。
- 当前控制位定义：
  - `algo_ctrl[0]`：算法使能
  - `algo_ctrl[1]`：演示叠加使能
  - `algo_ctrl[2]`：按帧翻转使能

### 3.2 RTL 接入位置

- 新增 HLS RTL 包装模块：
  - `20_HDL/22_User/SRIO_2_BRAM/undistort_demo_hls_wrap.v`
  - 功能：把 HLS 生成 RTL 接成现有 64bit AXIS 流模块，避免大面积改旧逻辑。
- 主接入点：
  - `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`
  - 当前链路已改为：
    - `readbram_to_axis64_top -> undistort_demo_hls_wrap -> m_srio_axis_*`
  - 旧的直通路径已在该文件中保留为注释，未直接删除。

### 3.3 控制寄存器与信号贯通

- 新增寄存器输出：
  - 文件：`20_HDL/22_User/axil_reg_EB4110_top.v`
  - 信号：`video_algo_ctrl`
  - 偏移地址：`16'h0014`
  - 复位默认值：`32'h0000_0007`
- 基地址来源：
  - `20_HDL/21_TOP/EB4110_10V10_TOP.v` 中 `axil_reg_EB4110_top` 例化基地址为 `32'h8600_0000`
- 因此当前模式寄存器地址为：
  - `0x8600_0014`
- 信号已从顶层贯通到视频处理插入点：
  - `20_HDL/21_TOP/EB4110_10V10_TOP.v`
  - `20_HDL/22_User/EB4110/eb4110_video_prj_top.v`
  - `20_HDL/22_User/EB4110/SRIO_VIDEO/eb4110_video_srio_top.v`
  - `20_HDL/22_User/EB4110/SRIO_VIDEO/srio_video_frame_d_speed.v`
  - `20_HDL/22_User/SRIO_2_BRAM/SRIO_2_Video.v`
  - `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`

## 4. 当前默认功能行为

- 若 PS 端不写寄存器，当前 bit 下载后默认 `video_algo_ctrl = 0x0000_0007`。
- 这表示上板默认行为为：
  - 算法开
  - 棋盘叠加开
  - 按帧翻转开
- 因此默认不是纯旁路直通，而是“处理后图像 + 棋盘演示”。
- 常用模式值如下：
  - `0x0000_0000`：旁路
  - `0x0000_0001`：只开基础算法框架
  - `0x0000_0003`：固定棋盘叠加
  - `0x0000_0007`：棋盘叠加并按帧翻转

## 5. 已完成验证

### 5.1 HLS 级验证

- 测试文件：`hls/undistort_demo/tb/undistort_demo_hls_tb.cpp`
- 已完成：
  - `csim`
  - `cosim`
- 已覆盖模式：
  - `0x0`
  - `0x1`
  - `0x3`
  - `0x7`
- 验证结论：
  - 包头透传
  - payload 长度保持
  - 演示叠加有效
  - 帧翻转有效
  - 旁路模式正确

### 5.2 RTL 级验证

- 轻量集成 testbench：
  - `80_TB/tb_vbram_hls_integration.v`
- 运行脚本：
  - `80_TB/run_tb_vbram_hls_integration.bat`
- 验证范围：
  - `vbram_lutaxi4_to_axis -> undistort_demo_hls_wrap`
  - `tvalid/tready/tlast`
  - SRIO 头部透传
  - 四种控制模式切换
- 结果：
  - `xsim` 通过
  - testbench 最终输出 `PASS: tb_vbram_hls_integration`

### 5.3 全工程构建验证

- 为保证新文件纳入工程，新增 project-mode 构建脚本：
  - `10_PRJ/phase4_launch_runs.tcl`
- 已确认：
  - `synth_1` 完成
  - `impl_1` 完成
  - `write_bitstream` 成功

## 6. 最新构建状态与性能

本节以 `2026-04-15` 最新一次成功构建为准，不再沿用旧备份目录中的历史数据。

### 6.1 构建结果

- 综合完成：
  - 参考日志：`10_PRJ/phase4_launch_runs.log`
- 实现完成并生成 bitstream：
  - 参考日志：`10_PRJ/impl_phase4_console.log`
- 关键结论：
  - `write_bitstream completed successfully`

### 6.2 时序结果

- 实现后并经 post-route phys_opt 收敛结果为：
  - `WNS = 0.007 ns`
  - `TNS = 0.000 ns`
  - `WHS = 0.011 ns`
  - `THS = 0.000 ns`
- 说明：
  - 当前设计满足用户时序约束
  - 余量较小，但已闭合，可用于当前版本交付和上板验收

### 6.3 综合资源占用

来源：`10_PRJ/00_PRJ.runs/synth_1/EB4110_10V10_TOP_utilization_synth.rpt`

- Slice LUTs：`13983 / 277400`，约 `5.04%`
- Slice Registers：`16760 / 554800`，约 `3.02%`
- Block RAM Tile：`318 / 755`，约 `42.12%`
- DSP：`0 / 2020`，约 `0.00%`
- Bonded IOB：`41 / 362`，约 `11.33%`
- GTXE2_COMMON：`2 / 4`，约 `50.00%`
- IBUFDS_GTE2：`2 / 8`，约 `25.00%`

### 6.4 功耗结果

来源：`10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_power_routed.rpt`

- Total On-Chip Power：`7.110 W`
- Dynamic Power：`6.750 W`
- Static Power：`0.361 W`
- Junction Temperature：`37.5 C`
- Confidence Level：`Low`

补充说明：

- 当前功耗报告缺少足够的真实开关活动文件，因此功耗可信度仍为 `Low`。
- 如果后续需要更准确的功耗结论，应补充 SAIF/VCD 或基于板上真实业务流量的活动信息。

## 7. 当前工程风险与非阻断问题

- 约束文件 `60_XDC/IR2520.xdc` 中仍有旧约束告警，当前未阻断 bit 生成：
  - 第 `13-15` 行存在 `set_property expects at least one object`
  - 第 `162` 行存在 `set_clock_groups` 对象无效告警
- `20_HDL/22_User/EB4110/eb4110_video_prj_top.v` 中仍有 `keep` 属性格式告警。
- 当前时序虽已闭合，但 `WNS` 仅 `0.007 ns`，后续若继续增加算法复杂度，应优先关注：
  - HLS 模块流水深度
  - AXIS 包装层寄存
  - 视频路径上的关键组合逻辑

## 8. 当前可用的验收方式

- 直接使用当前 bit 文件下载到板卡：
  - `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.bit`
- 若 PS 不覆盖寄存器，默认即进入 `0x0000_0007` 演示模式。
- 上板可通过观察输出图像确认：
  - 是否存在明显棋盘格叠加
  - 棋盘格是否随输出帧翻相
- 若需切换模式，可写寄存器：
  - 地址：`0x8600_0014`
  - 例如：
    - `0x0000_0000`：旁路
    - `0x0000_0007`：演示模式

## 9. 后续建议

- 若下一阶段要接入真实去畸变标定参数，建议保留现有包装层和控制面，只替换 HLS 内部 `apply_undistort_foundation(...)` 实现。
- 若要继续扩展算法，应优先保持“新增独立模块 + 最少改旧 RTL”的策略，避免破坏现有稳定视频链路。
- 若要做正式交付，建议再补两类资料：
  - 一份寄存器说明文档
  - 一份上板验收记录，包含模式切换、图像现象和 bit 文件版本
