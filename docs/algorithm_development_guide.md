# 预处理算法并行开发说明

作者：Egor Izmaylov

## 开发边界

当前工程的视频预处理插入点固定在 `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`。SRIO 接收、BRAM 写入和后级 SRIO 发送链路已经稳定，后续算法开发应优先改 `hls/undistort_demo/src/undistort_demo_hls.cpp`，必要时只调整 `undistort_demo_hls_wrap.v` 的接口适配。

## 数据格式

BRAM 读出模块输出 64bit AXIS。payload 按 4 个 16bit 像素打包，`tlast` 保持原始包尾语义。HLS 顶层 `undistort_demo_hls` 必须维持 `s_axis`、`m_axis` 和 `algo_ctrl` 三个接口，避免多人并行时反复改顶层接线。

## 控制寄存器

算法控制寄存器为 `0x8600_0014`，复位默认 `0x0000_0007`。当前位定义：

- `bit0`：去畸变基础补偿使能。
- `bit1`：棋盘/黑白验收演示使能。
- `bit2`：按输出帧翻转演示相位，当前板上输出约 `2Hz`。

## HLS 流程

在 `hls/undistort_demo` 下运行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csynth"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\cosim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_cosim"
```

`HLS_BUILD_ROOT` 是可选项；不设置时脚本默认使用 `hls/undistort_demo/build`。多人开发或本地旧缓存有权限问题时，建议使用仓库根目录下的 `hls_work/`。

## 并行开发规则

每个算法分支只改自己的 HLS 函数和对应 testbench。公共 wrapper、AXI-Lite 寄存器和 `SRIO_2_Video.v` 需要合并评审后再改。所有新增或改进注释应标记 `Egor Izmaylov`，并在 `status.md` 记录验证结果。
