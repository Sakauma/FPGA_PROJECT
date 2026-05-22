# 算法开发指南

作者：Egor Izmaylov

本文面向后续并行开发预处理算法的同事。当前仓库的算法开发边界非常清楚：只开发 HLS 算法、对应 testbench 和必要 wrapper 适配；SRIO、BRAM 乒乓缓存、MIG、BD/IP、XDC、时钟复位和板级接口保持硬件部门版本。

## 数据流概览

图像由 SRIO 写入 BRAM 乒乓缓存，随后读出到 SRIO TX。启用 `ENABLE_FISHEYE_REMAP_READER` 后，读出链路变为：

```text
BRAM line/slot -> RTL packetizer -> HLS address core -> BRAM pixel read -> FIFO -> SRIO AXIS
```

HLS 只负责输出源行槽 `src_slot` 和源列 `src_x`。每行 16 包，每包 1 个 header 和 32 个 64-bit payload，每个 payload 打包 4 个 raw16 像素。完整 2048 行帧应输出 `32768 header / 1048576 payload / 32768 tlast`。

## 主要开发入口

- `hls/fisheye_remap/src/fisheye_remap_reader_hls.h`：图像尺寸、圆心、半径、LUT 映射、缓存深度和控制位常量。
- `hls/fisheye_remap/src/fisheye_remap_reader_hls.cpp`：去畸变地址映射、局部圆环拉平补偿、预处理函数和旧 HLS reader 保留代码。
- `hls/fisheye_remap/src/distortion_lut.h`：由畸变表转换得到的 Q2.16 红外/激光 LUT。
- `hls/fisheye_remap/tb/fisheye_remap_reader_hls_tb.cpp`：HLS 地址核和协议单元测试。
- `hls/fisheye_remap/tb/fisheye_remap_raw16_tb.cpp`：本地 raw16 图像仿真与逐帧结果保存。

## 控制位约定

- `algo_ctrl[0] = 0`：地址旁路，源坐标等于输出坐标。
- `algo_ctrl[0] = 1`：启用鱼眼去畸变源地址映射。
- `algo_ctrl[3] = 0`：使用红外畸变表。
- `algo_ctrl[3] = 1`：使用激光畸变表。
- `algo_ctrl[4] = 1`：关闭自适应预处理，仅保留几何去畸变。
- `algo_ctrl[5] = 1`：冻结当前自适应参数。

新工程当前 wrapper 默认固定 `algo_ctrl = 32'h0000_0001`。如果要恢复寄存器动态控制，需要单独评审 AXI-Lite 接线和上位机覆盖行为。

## 开发流程

1. 在 `src/` 修改算法参数或映射逻辑。
2. 运行 HLS C 仿真，确认控制位语义和 packet 统计不变。
3. 用 `D:\Staff\data` 的 raw16 帧检查图像效果，重点看 `remap_no_adaptive` 和 `remap_infrared`。
4. 运行 `csynth.tcl` 重新导出 RTL，并检查新生成 helper 是否仍被 wrapper include。
5. 跑 `tb_vbram_hls_integration` 和 `tb_srio_video_e2e`，确认无缺包、多包、tlast 错位或 13 段重复。
6. 仿真通过后再进入 Vivado 综合、实现、生成 bitstream。

常用命令：

```powershell
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csim.tcl"
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csynth.tcl"
cmd /c 80_TB\run_tb_vbram_hls_integration.bat
cmd /c 80_TB\run_tb_srio_video_e2e.bat
```

## 参数修改规则

- 修改圆心、半径、LUT 方向或局部补偿参数后，必须重新生成 raw16 对比结果。
- 垂直方向位移必须受 `kFisheyeMaxVerticalShift` 约束，当前为 `96` 行，避免超过 256 行缓存半窗。
- 不要把视觉效果问题简单处理成强度倍增；先用 raw16 软件参考判断参数是否合理。
- 不要在 HLS 中恢复实时发包状态机作为默认路径；实时 packet 节奏应由 RTL packetizer 固定生成。

## 学习路线

第一阶段先读 `fisheye_remap_reader_hls.h` 和 `fisheye_remap_reader_hls.cpp`，理解 `ap_uint`、Q 格式、行槽映射和控制位。

第二阶段跑 `csim_raw.tcl`，把本地 raw16 输入、旁路输出和 remap 输出逐帧打开对比，建立算法效果直觉。

第三阶段学习 Vitis HLS 的 `ap_ctrl_none`、`ap_none`、`PIPELINE II=1`、ROM LUT 和定点乘法，避免写出难以收敛的组合路径。

第四阶段再看 `80_TB/tb_srio_video_e2e.v`，理解算法输出为什么必须保持 SRIO 包结构稳定。

## 推荐资料

- [AMD Vitis HLS UG1399](https://docs.amd.com/r/en-US/ug1399-vitis-hls)：查接口 pragma、pipeline、定点类型和综合报告。
- [Xilinx/Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples)：学习小型 AXIS、数组、pipeline 和 arbitrary precision 类型示例。
- [Xilinx/Vitis_Libraries Vision](https://xilinx.github.io/Vitis_Libraries/vision/)：参考 FPGA 图像处理的流式设计方式。
- [OpenCV Calibration Tutorial](https://docs.opencv.org/4.x/dc/dbb/tutorial_py_calibration.html)：理解相机标定、内参、畸变系数和去畸变映射。

## 提交要求

提交前至少跑快速三项：SRIO 输出合约静态检查、`tb_vbram_hls_integration`、`tb_srio_video_e2e`。如果修改 HLS 参数，还要保存 raw16 仿真输出目录，便于评审时对比图像效果。
