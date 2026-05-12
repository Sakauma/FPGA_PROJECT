# 上板调试流程说明

作者：Egor Izmaylov

## 结论

当前工程可以直接用于上板验证。已验证的 bitstream 位于：

```text
D:\Staff\test\EB4110_FPGA_20260410_2\10_PRJ\00_PRJ.runs\impl_1\EB4110_10V10_TOP.bit
```

该 bitstream 基于算法实现基线 `ad3ff48` 生成。最后一次 Vivado 2025.2 构建已通过，时序满足：`WNS = 0.042ns`，`TNS = 0.000`。如果只是验证当前版本，可以直接烧录该 `.bit`；如果需要复现构建，再重新综合、实现并生成 bitstream。

## Vivado 重新生成流程

1. 打开 `10_PRJ\00_PRJ.xpr`。
2. 确认顶层模块为 `EB4110_10V10_TOP`。
3. 执行 `Update Compile Order`。
4. 如 IP Status 显示 stale/locked，再执行 `Report IP Status` 和必要的 `Generate Output Products`；如果状态正常，不需要重新生成 IP。
5. 依次运行 `Run Synthesis`、`Run Implementation`、`Generate Bitstream`。
6. 生成后检查 `Reports -> Timing Summary`：要求 `WNS >= 0`、`TNS = 0`。
7. 使用 `10_PRJ\00_PRJ.runs\impl_1\EB4110_10V10_TOP.bit` 上板。

也可使用批处理脚本复现完整构建：

```powershell
vivado -mode batch -source 10_PRJ\build_project_2025.tcl -tclargs reset
```

## 上板烧录流程

1. 连接板卡电源、JTAG、相机/输入链路、输出显示或采集设备。
2. 打开 Vivado `Open Hardware Manager`。
3. 点击 `Open Target -> Auto Connect`。
4. 选择 FPGA 设备，执行 `Program Device`。
5. bit 文件选择 `EB4110_10V10_TOP.bit`。
6. 烧录完成后复位或重新启动输入链路，观察输出图像。

## 默认运行模式

当前没有 PS 操作也可以运行。默认控制值为 `0x0000_0007`，实际含义如下：

- `bit0 = 1`：启用真实鱼眼去畸变和自适应预处理。
- `bit1/bit2`：已废弃，不再产生棋盘、黑白或翻转图案。
- `bit3 = 0`：默认使用红外畸变表。
- `bit4 = 0`：启用自适应预处理。
- `bit5 = 0`：自适应参数随帧更新。

因此默认烧录后应看到真实输入图像经过去畸变和预处理后的输出，不会出现棋盘格。

## 可选寄存器调试

如果后续可以通过 PS 或 JTAG-to-AXI 写寄存器，控制地址是 `0x8600_0014`：

- 写 `0x00000000`：旁路，输出原始 BRAM 图像。
- 写 `0x00000001`：红外表去畸变 + 自适应预处理。
- 写 `0x00000009`：激光表去畸变 + 自适应预处理。
- 写 `0x00000011`：只做去畸变，关闭自适应预处理。
- 写 `0x00000021`：去畸变 + 冻结当前自适应参数。

验收时建议优先对比 `0x0` 和 `0x1`，观察画面边缘、直线结构、视场边界是否有变化。

## 调试顺序

1. 先确认有输入：相机/SRIO 输入链路正常，板上能收到帧数据。
2. 再确认有输出：输出端有帧率稳定的图像，当前链路输出约 `2Hz`。
3. 如果有输入无输出，优先查复位、BRAM 写入行号、BRAM 读地址、FIFO almost-full、AXIS `tvalid/tready/tlast`。
4. 如果输出图像异常偏暗或偏亮，用 `0x11` 关闭自适应预处理对比；如果稳定后想固定效果，用 `0x21` 冻结参数。
5. 如果怀疑畸变表不合适，对比 `0x1` 红外表和 `0x9` 激光表。
6. 记录每次测试的 bit 文件时间、commit、寄存器值、输入场景、输出截图或视频。

## 验收标准

- bitstream 可正常烧录，板卡无异常复位。
- 有真实图像输入时，输出端有连续图像。
- 默认模式不出现棋盘、黑白翻转等旧演示图案。
- 旁路和去畸变模式可观察到图像几何差异。
- 时序报告满足约束，当前参考值为 `WNS = 0.042ns`。
