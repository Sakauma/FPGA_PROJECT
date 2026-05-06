# undistort_demo HLS 子工程

作者：Egor Izmaylov

本目录保存视觉预处理算法的 Vitis HLS 工程。当前 HLS 核提供去畸变基础处理框架，并叠加黑白/棋盘可见化验收模式。算法团队应在本目录内完成算法开发和验证，不直接修改工程底层 SRIO、BRAM、时钟、约束、BD 或 IP。

## 目录说明

- `src/undistort_demo_hls.cpp`：HLS 算法主体，后续真实去畸变、增强或检测预处理优先在这里实现。
- `src/undistort_demo_hls.h`：AXIS 类型、图像尺寸和顶层函数声明。
- `tb/undistort_demo_hls_tb.cpp`：HLS C 仿真测试平台。
- `scripts/`：`csim`、`csynth`、`cosim` Tcl 脚本。
- `rtl/`：HLS 导出的 RTL，属于生成结果，不手工改。

## 接口约束

顶层函数必须保持以下接口：

```cpp
void undistort_demo_hls(hls::stream<axis64_t>& s_axis,
                        hls::stream<axis64_t>& m_axis,
                        ap_uint<32> algo_ctrl);
```

输入输出为 64-bit AXIS，每个 payload word 打包 4 个 16-bit 像素。`algo_ctrl` 对应系统控制寄存器 `0x8600_0014`。

控制位定义：

- `algo_ctrl[0]`：启用去畸变基础处理框架。
- `algo_ctrl[1]`：启用黑白/棋盘可见化验收模式。
- `algo_ctrl[2]`：按输出帧翻转演示相位，当前板上输出约 `2Hz`。

## 运行命令

在 `hls/undistort_demo` 目录下运行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_csynth"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\cosim.tcl --work_dir %HLS_BUILD_ROOT%\dispatcher_cosim"
```

`HLS_BUILD_ROOT` 可选；未设置时默认写入本目录 `build/`。推荐使用仓库根目录下的 `hls_work/` 保存派生产物，该目录已被 `.gitignore` 忽略。

## RTL 导出规则

`rtl/` 目录用于保存当前工程接入的 HLS 生成 RTL。禁止直接手改该目录下文件；如需变更 RTL，必须先修改 `src/`，再重新执行 HLS 综合并导出。导出后需要确认 `20_HDL/22_User/SRIO_2_BRAM/undistort_demo_hls_wrap.v` 的端口映射仍然匹配。

## 提交前检查

算法修改提交前至少确认：

- `csim` 通过。
- `csynth` 通过并记录资源、时序变化。
- `cosim` 通过。
- 若重新导出 RTL 或改 wrapper，运行 `80_TB/run_tb_vbram_hls_integration.bat`。
