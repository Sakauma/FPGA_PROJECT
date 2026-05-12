# EB4110 FPGA 预处理算法工程

作者：Egor Izmaylov

## 工程定位

本仓库是 EB4110 预处理板 FPGA 工程，当前版本已经在 Vivado 2025.2 下完成完整仿真、综合、实现、bitstream 生成，并完成板级烧录运行验证。工程后续主要面向视觉预处理算法开发；SRIO、BRAM、MIG、AXI-Lite、时钟、管脚、约束、IP、板级接口和硬件链路由硬件部门预先决定，算法开发人员不直接修改这些底层内容。

当前算法链路已经前移到 BRAM 读出阶段：HLS 去畸变读出核根据输出像素坐标计算源像素地址，从真实图像 BRAM 中重采样并输出到原 SRIO AXIS 链路。本版取消棋盘、黑白、翻转等演示图案，只处理真实传入图像数据。

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

若需要重新生成当前上板算法核，请进入：

```powershell
cd hls\fisheye_remap
```

然后按 `hls/fisheye_remap/README.md` 执行 `csim`、`csynth`。`cosim` 目前受 Vitis HLS 对 `ap_ctrl_none` 多周期 BRAM 控制状态机的限制，不作为本核通过标准；RTL 集成验证使用 `80_TB/run_tb_vbram_hls_integration.bat`。

上板烧录和调试流程见 `docs/board_bringup_debug_guide.md`。

## 算法开发边界

算法开发优先修改：

- `hls/fisheye_remap/src/fisheye_remap_reader_hls.cpp`
- `hls/fisheye_remap/src/distortion_lut.h`
- `hls/fisheye_remap/tb/fisheye_remap_reader_hls_tb.cpp`

必要时，经评审后才修改：

- `20_HDL/22_User/SRIO_2_BRAM/fisheye_remap_bram_to_axis.v`
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`

默认不要修改：

- `20_HDL/22_User/SRIO_2_BRAM/SRIO_2_Video.v`
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`
- `10_PRJ/00_PRJ.srcs/` 下 BD/IP 配置
- `50_IP/`、`60_XDC/`、`20_HDL/LU0310.V10_SRIO/` 等硬件底层内容

如果算法需求必须改变数据宽度、时钟、寄存器、帧格式或底层链路，应先提交接口变更说明，由硬件部门确认后再实施。

## 数据与控制接口

算法输出保持原 64-bit AXIS 数据流。每个 payload word 打包 4 个 16-bit 像素，`tlast` 保持原链路包尾语义。当前控制寄存器为 `0x8600_0014`，默认控制值为 `0x0000_0007`。

控制位定义：

- `bit0 = 0`：旁路，按原顺序读取 BRAM 输出原图。
- `bit0 = 1`：启用真实鱼眼去畸变重采样，并默认启用自适应预处理。
- `bit3 = 0`：使用红外畸变表，默认上板模式。
- `bit3 = 1`：使用激光畸变表，仅用于后续对比测试。
- `bit4 = 1`：关闭自适应预处理，仅保留去畸变重采样，便于和原始亮度对比。
- `bit5 = 1`：冻结当前自适应参数，便于上板观察稳定画面。

`bit1/bit2` 已不再生成任何演示图案，因此默认 `0x0000_0007` 只按 `bit0=1` 执行真实去畸变和自适应预处理。自适应预处理采用上一帧 min/max 估计黑电平和 Q8 增益；第一帧使用单位增益。

## 验证要求

算法提交前至少完成：

- HLS `csim`，确认 C/C++ 行为正确。
- HLS `csynth`，确认 RTL 可生成且资源、时序可接受。
- `80_TB/run_tb_vbram_hls_integration.bat`，确认 RTL 插入点基本握手和模式输出正确。

`hls/fisheye_remap` 当前不以自动 `cosim` 作为通过条件，因为 Vitis HLS 2025.2 对该类 `ap_ctrl_none` 多周期非流式端口核会报接口不支持；以 C 仿真、综合和 XSim RTL 集成仿真作为本阶段验证闭环。

只修改文档时不需要运行 Vivado/HLS 构建，但应确认 Markdown 为 UTF-8 编码，中文在 GitHub 上正常显示。

## 协作规则

多人并行开发时，每个算法分支只改自己的 HLS 源码和 testbench。公共 wrapper、AXI-Lite 寄存器、SRIO/BRAM 链路、BD/IP、XDC 和顶层工程配置需要评审后才能修改。所有新增说明、注释和改进点统一标记作者 `Egor Izmaylov`。
