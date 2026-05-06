# EB4110 FPGA 预处理算法工程

作者：Egor Izmaylov

## 工程定位

本仓库是 EB4110 预处理板 FPGA 工程，当前版本已经在 Vivado 2025.2 下完成完整仿真、综合、实现、bitstream 生成，并完成板级烧录运行验证。工程后续主要面向视觉预处理算法开发；SRIO、BRAM、MIG、AXI-Lite、时钟、管脚、约束、IP、板级接口和硬件链路由硬件部门预先决定，算法开发人员不直接修改这些底层内容。

当前算法链路在原有 BRAM 到 SRIO 输出路径前插入 HLS 预处理核。演示算法以去畸变框架为基础，并提供可见验收模式：在约 2Hz 输出图像上叠加黑白/棋盘变化，用于确认数据确实经过算法 IP。

## 快速开始

主要 Vivado 工程入口：

```powershell
vivado 10_PRJ\00_PRJ.xpr
```

推荐批处理/脚本入口：

```powershell
vivado -mode batch -source 10_PRJ\open_project_2025.tcl
vivado -mode batch -source 10_PRJ\build_project_2025.tcl
```

若需要重新生成 HLS 算法核，请进入：

```powershell
cd hls\undistort_demo
```

然后按 `hls/undistort_demo/README.md` 执行 `csim`、`csynth`、`cosim`。

## 算法开发边界

算法开发优先修改：

- `hls/undistort_demo/src/undistort_demo_hls.cpp`
- `hls/undistort_demo/tb/undistort_demo_hls_tb.cpp`

必要时，经评审后才修改：

- `20_HDL/22_User/SRIO_2_BRAM/undistort_demo_hls_wrap.v`

默认不要修改：

- `20_HDL/22_User/SRIO_2_BRAM/SRIO_2_Video.v`
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`
- `10_PRJ/00_PRJ.srcs/` 下 BD/IP 配置
- `50_IP/`、`60_XDC/`、`20_HDL/LU0310.V10_SRIO/` 等硬件底层内容

如果算法需求必须改变数据宽度、时钟、寄存器、帧格式或底层链路，应先提交接口变更说明，由硬件部门确认后再实施。

## 数据与控制接口

算法输入输出保持 64-bit AXIS 数据流。每个 payload word 打包 4 个 16-bit 像素，`tlast` 保持原链路包尾语义。当前控制寄存器为 `0x8600_0014`，默认控制值为 `0x0000_0007`。

控制位定义：

- `bit0`：启用去畸变基础处理框架。
- `bit1`：启用黑白/棋盘可见化验收模式。
- `bit2`：按输出帧翻转演示相位，适配当前约 2Hz 的板上输出。

## 验证要求

算法提交前至少完成：

- HLS `csim`，确认 C/C++ 行为正确。
- HLS `csynth`，确认 RTL 可生成且资源、时序可接受。
- HLS `cosim`，确认 C/RTL 一致。
- `80_TB/run_tb_vbram_hls_integration.bat`，确认 RTL 插入点基本握手和模式输出正确。

只修改文档时不需要运行 Vivado/HLS 构建，但应确认 Markdown 为 UTF-8 编码，中文在 GitHub 上正常显示。

## 协作规则

多人并行开发时，每个算法分支只改自己的 HLS 源码和 testbench。公共 wrapper、AXI-Lite 寄存器、SRIO/BRAM 链路、BD/IP、XDC 和顶层工程配置需要评审后才能修改。所有新增说明、注释和改进点统一标记作者 `Egor Izmaylov`。
