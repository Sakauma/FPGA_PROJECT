# undistort_demo

作者：Egor Izmaylov

本目录保存预处理演示用 Vitis HLS 工程。当前 HLS 核先建立“去畸变基础坐标模型 + 可见验收叠加”的接口骨架，后续真实算法应优先替换 `src/undistort_demo_hls.cpp` 内部实现，而不是改顶层 SRIO 链路。

## 控制位

- `algo_ctrl[0]`：开启去畸变基础补偿框架。
- `algo_ctrl[1]`：开启棋盘/黑白叠加演示。
- `algo_ctrl[2]`：按输出帧翻转演示相位，当前板上输出约 `2Hz`。

## 运行方式

在 `hls/undistort_demo` 目录下运行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csynth"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\cosim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_cosim"
```

`HLS_BUILD_ROOT` 可选；未设置时默认写入本目录 `build/`。若旧缓存或权限影响验证，使用 `hls_work/` 隔离派生产物。

导出的 RTL 维护边界为 `hls/undistort_demo/rtl/`。该目录属于 HLS 生成结果，人工改动必须回溯到 `src/` 后重新综合。
