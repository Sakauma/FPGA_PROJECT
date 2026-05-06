# 预处理算法开发指南

作者：Egor Izmaylov

## 目标与边界

本指南面向算法团队。当前 FPGA 工程底层硬件链路已经由硬件部门确定，算法人员只开发视觉预处理算法，不擅自修改 SRIO、BRAM、MIG、AXI-Lite、时钟、管脚、约束、BD、IP 或板级接口。

算法接入点已经固定在 BRAM 读出到 SRIO 输出之间。后续工作应优先在 HLS 层完成，保持 RTL 顶层接线、帧格式和硬件接口稳定。

## 推荐修改位置

优先修改：

- `hls/undistort_demo/src/undistort_demo_hls.cpp`：算法主体。
- `hls/undistort_demo/tb/undistort_demo_hls_tb.cpp`：算法级测试。

谨慎修改：

- `20_HDL/22_User/SRIO_2_BRAM/undistort_demo_hls_wrap.v`：HLS RTL 到现有工程的 AXIS wrapper，仅在 HLS 接口确需适配时修改。

默认禁止修改：

- SRIO 收发、BRAM 写入/读出、MIG、BD/IP、XDC、顶层时钟复位和板级接口。
- `hls/undistort_demo/rtl/` 下的 HLS 生成 RTL。需要变更时应回到 `src/` 修改后重新综合导出。

## 数据接口契约

HLS 顶层接口必须保持：

- `s_axis`：输入 64-bit AXIS。
- `m_axis`：输出 64-bit AXIS。
- `algo_ctrl`：32-bit 组合控制字，RTL wrapper 直接接入现有控制寄存器。

payload 格式保持不变：每个 64-bit word 包含 4 个 16-bit 像素，`tlast` 沿用原始包尾语义。算法可以修改 payload 像素值，但不能改变 word 数量、包边界、握手协议或时钟域。

当前 HLS 算法内部使用 SRIO 地址头解析行号和包号，用于推导 `x/y` 像素坐标。若后续算法需要真实相机标定参数或 LUT，应在 HLS 内部新增常量表或只读表接口方案，先评审后实施。

## 控制寄存器

算法控制寄存器地址为 `0x8600_0014`，当前默认值为 `0x0000_0007`。

控制位定义：

- `bit0`：启用去畸变基础处理框架。
- `bit1`：启用黑白/棋盘可见化验收模式。
- `bit2`：按输出帧翻转演示相位，适配当前约 2Hz 板上输出。

新增控制位必须先在文档中定义位含义、默认值、软件配置方式和回退行为，再修改代码。

## HLS 开发流程

在 `hls/undistort_demo` 目录下执行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csynth"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\cosim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_cosim"
```

`HLS_BUILD_ROOT` 可选；建议多人开发时使用仓库根目录下的 `hls_work/` 隔离派生产物，避免本地旧缓存或权限问题影响验证。

## 提交流程

算法分支提交前应完成：

- `csim` 通过，覆盖关闭算法、仅去畸变、仅演示、去畸变加演示等关键模式。
- `csynth` 通过，记录资源和时序变化。
- `cosim` 通过，确认 C/RTL 行为一致。
- 如 wrapper 或 RTL 接入发生变化，运行 `80_TB/run_tb_vbram_hls_integration.bat`。

提交说明应写清算法目标、修改文件、控制位变化、验证命令和结果。所有新增说明、注释和改进点统一标记作者 `Egor Izmaylov`。
