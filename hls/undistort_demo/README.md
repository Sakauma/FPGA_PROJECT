# undistort_demo

这个目录保存预处理演示用的 Vitis HLS 工程。

当前 HLS 核的目标不是一次性做完高精度去畸变，而是先把下面两件事落地：

- 建立“去畸变基础坐标模型 + HLS 处理链”的接口骨架
- 提供可验收的棋盘叠加演示效果，并按输出帧翻转黑白相位

## 控制位定义

- `algo_ctrl[0]`：开启去畸变基础补偿框架
- `algo_ctrl[1]`：开启棋盘叠加演示
- `algo_ctrl[2]`：开启按帧翻转棋盘黑白相位

## 运行方式

在 `hls/undistort_demo` 目录下运行：

```powershell
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && cd /d D:\Staff\test\EB4110_FPGA_20260410_2\hls\undistort_demo && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir build\tcl_run"
```

综合完成后，导出的 RTL 会位于 `build/tcl_run/undistort_demo_hls/solution1/syn/verilog/`。
