# 预处理算法开发指南

作者：Egor Izmaylov

## 目标与边界

本指南面向算法团队。当前 FPGA 工程底层硬件链路已经由硬件部门确定，算法人员只开发视觉预处理算法，不擅自修改 SRIO、BRAM、MIG、AXI-Lite、时钟、管脚、约束、BD、IP 或板级接口。

算法接入点已经固定在 BRAM 读出到 SRIO 输出之间。当前真实鱼眼去畸变必须在 BRAM 读出阶段完成，因为几何重映射需要按输出坐标反查源像素地址；AXIS 后处理阶段只能看到顺序像素，不能完成真实重采样。

## 推荐修改位置

优先修改：

- `hls/fisheye_remap/src/fisheye_remap_reader_hls.cpp`：当前真实鱼眼去畸变 BRAM 读出算法主体。
- `hls/fisheye_remap/src/distortion_lut.h`：由畸变表生成的红外/激光定点 LUT。
- `hls/fisheye_remap/tb/fisheye_remap_reader_hls_tb.cpp`：算法级测试。

谨慎修改：

- `20_HDL/22_User/SRIO_2_BRAM/fisheye_remap_bram_to_axis.v`：HLS RTL 到现有 BRAM/FIFO/AXIS 链路的 wrapper。
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`：算法接入点。旧 AXIS 后处理路径已保留在宏分支中，默认启用真实 BRAM 重采样路径。

默认禁止修改：

- SRIO 收发、BRAM 写入、MIG、BD/IP、XDC、顶层时钟复位和板级接口。
- `hls/fisheye_remap/rtl/` 下的 HLS 生成 RTL。需要变更时应回到 `src/` 修改后重新综合导出；`scripts/csynth.tcl` 会自动复制 ROM `.dat` 并修正 HLS 空闲输出为确定 0。

## 数据接口契约

HLS 顶层接口必须保持：

- 输入：当前写入 BRAM 行号、行号表、BRAM 读数据、FIFO almost-full 和 `algo_ctrl`。
- 输出：BRAM 读地址、行号表地址、65-bit FIFO 数据 `{tlast,tdata[63:0]}` 和 FIFO 写使能。
- 输出 AXIS：仍为 64-bit，4 个 16-bit 像素打包，`tlast` 沿用原始包尾语义。

算法可以改变 BRAM 读地址生成方式和 payload 像素来源，但不能改变 SRIO 包头格式、word 数量、包边界、跨时钟 FIFO 接口或板级时钟域。

## 控制寄存器

算法控制寄存器地址为 `0x8600_0014`，当前默认值为 `0x0000_0007`。

控制位定义：

- `bit0 = 0`：旁路，按原顺序读取 BRAM 输出原图。
- `bit0 = 1`：启用真实鱼眼去畸变重采样，并默认启用自适应预处理。
- `bit3 = 0`：使用红外畸变表，默认上板模式。
- `bit3 = 1`：使用激光畸变表，仅用于对比测试。
- `bit4 = 1`：关闭自适应预处理，仅保留去畸变重采样。
- `bit5 = 1`：冻结当前自适应预处理参数，避免参数继续随画面变化。

`bit1/bit2` 已废弃为演示位，不再产生黑白、棋盘或翻转图案。默认值 `0x0000_0007` 只按 `bit0=1` 执行真实去畸变和自适应预处理。自适应预处理使用当前帧 min/max 统计更新下一帧黑电平和 Q8 增益；第一帧使用安全单位增益。

新增控制位必须先在文档中定义位含义、默认值、软件配置方式和回退行为，再修改代码。

## HLS 开发流程

在 `hls/fisheye_remap` 目录下执行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\fisheye_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\fisheye_csynth"
80_TB\run_tb_vbram_hls_integration.bat
```

`HLS_BUILD_ROOT` 可选；建议多人开发时使用仓库根目录下的 `hls_work/` 隔离派生产物，避免本地旧缓存或权限问题影响验证。

说明：`fisheye_remap_reader_hls` 是 `ap_ctrl_none` 多周期 BRAM 控制核，Vitis HLS 2025.2 自动 `cosim` 会报非自同步端口不支持。本工程以 `csim`、`csynth` 和 XSim RTL 集成仿真作为该核的验证闭环。

## 学习路线

阶段 1：理解本工程算法边界。先阅读 `hls/fisheye_remap/src/fisheye_remap_reader_hls.cpp`、`hls/fisheye_remap/tb/fisheye_remap_reader_hls_tb.cpp` 和 `20_HDL/22_User/SRIO_2_BRAM/fisheye_remap_bram_to_axis.v`，确认算法人员只处理 BRAM 读出重采样和 `algo_ctrl`，不修改 SRIO、MIG、BD/IP、XDC 等底层硬件内容。

阶段 2：掌握 Vitis HLS 基础。重点学习 `ap_uint`、`hls::stream`、AXIS 接口、`#pragma HLS PIPELINE`、`#pragma HLS UNROLL`、`csim`、`csynth` 和 `cosim`。本工程算法应优先保持 `II=1` 的流式处理思路，避免引入整帧缓存。

阶段 3：学习图像去畸变原理。重点掌握相机内参、畸变系数、反向映射、LUT 查表、定点化和插值。真实算法进入 HLS 前，应先用软件模型验证坐标映射和边界行为，再移植为定点/流式实现。

阶段 4：在本工程内实现和验证。先改 HLS C++ 算法和 testbench，跑通 `csim`；再执行 `csynth` 检查资源和时序；随后运行 `80_TB/run_tb_vbram_hls_integration.bat` 验证 RTL 接入；最后由硬件部门协助完成上板验证。

## 推荐开源仓库与网站

- [AMD Vitis HLS UG1399](https://docs.amd.com/r/2024.2-English/ug1399-vitis-hls/Tutorials-and-Examples?contentId=xM4ej9x5Of~UqgiDAqmoXw)：HLS 语法、接口综合、pipeline、AXIS 和 cosim 的权威资料。本工程遇到 pragma、接口协议或 C/RTL 不一致问题时，优先按该文档核对。
- [Xilinx/Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples)：包含 AXIS、数组分割、pipeline、任意精度整数等小例子。适合在修改本工程前先做独立练习，理解 HLS 如何把 C++ 变成硬件结构。
- [Xilinx/Vitis-Tutorials](https://github.com/Xilinx/Vitis-Tutorials)：覆盖较完整的 Vitis/HLS 工程流程。适合学习从 C 模型、综合、仿真到工程集成的整体节奏。
- [Xilinx/Vitis_Libraries](https://github.com/Xilinx/Vitis_Libraries)：AMD/Xilinx 官方开源加速库集合，其中 vision 部分可作为 FPGA 图像处理写法参考。本工程可借鉴其流式处理、定点类型和窗口化思路，但不要直接引入大库依赖。
- [Vitis Vision Library Docs](https://xilinx.github.io/Vitis_Libraries/vision/)：说明 `xf::cv` 图像处理模块、接口和资源权衡。适合参考 remap、resize、filter 等模块如何组织数据流和边界处理。
- [OpenCV Calibration Tutorial](https://docs.opencv.org/4.x/dc/dbb/tutorial_py_calibration.html)：介绍相机标定、畸变参数和去畸变流程。适合算法人员先在 PC 上确认标定参数和去畸变效果，再设计 HLS 版本。
- [OpenCV calib3d](https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html)：包含相机模型、`initUndistortRectifyMap`、`undistort` 等接口说明。适合作为去畸变数学模型和软件基准，不应直接照搬动态内存或浮点密集实现到 HLS。
- [opencv/opencv](https://github.com/opencv/opencv)：软件侧图像算法实现参考。可用于理解算法行为、构建 golden model 和生成测试数据，移植到本工程时必须重新做定点化、流式化和资源评估。

## 提交流程

算法分支提交前应完成：

- `csim` 通过，覆盖旁路、红外去畸变、激光表备用和默认 `0x0000_0007` 行为。
- `csynth` 通过，记录资源和时序变化。
- 如 wrapper 或 RTL 接入发生变化，运行 `80_TB/run_tb_vbram_hls_integration.bat`。

提交说明应写清算法目标、修改文件、控制位变化、验证命令和结果。所有新增说明、注释和改进点统一标记作者 `Egor Izmaylov`。
