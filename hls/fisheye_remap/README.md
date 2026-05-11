# fisheye_remap HLS 子工程

作者：Egor Izmaylov

本目录保存真实鱼眼去畸变 BRAM 读出核。该核根据输出像素坐标和畸变表计算源像素地址，从现有视频 BRAM 读取真实图像数据，再打包为原工程使用的 65bit FIFO 数据 `{tlast, tdata[63:0]}`。

## 维护边界

- 算法源码位于 `src/fisheye_remap_reader_hls.cpp`。
- 畸变表定点 LUT 位于 `src/distortion_lut.h`，来源为 `data/distortion_table.csv`。
- `rtl/` 为 HLS 导出 RTL；需要变更时回到 `src/` 后重新综合。
- `scripts/csynth.tcl` 会自动复制 ROM `.dat`，并把 HLS 空闲周期的 `fifo_wr_en/fifo_din` 从不确定 `X` 后处理为确定 0，避免接入真实 FIFO 时污染仿真和综合。
- 本工程不修改 SRIO、MIG、BD/IP、XDC、时钟或板级接口。

## 控制位

- `algo_ctrl[0] = 0`：旁路，按原顺序读取 BRAM 输出原图。
- `algo_ctrl[0] = 1`：启用鱼眼去畸变重采样，并默认启用自适应预处理。
- `algo_ctrl[3] = 0`：使用红外畸变表，默认上板模式。
- `algo_ctrl[3] = 1`：使用激光畸变表，仅用于对比验证。
- `algo_ctrl[4] = 1`：关闭自适应预处理，仅保留去畸变。
- `algo_ctrl[5] = 1`：冻结当前自适应预处理参数。

`algo_ctrl[1]` 和 `algo_ctrl[2]` 不再产生棋盘、黑白或翻转图案。

## 运行方式

在 `hls/fisheye_remap` 目录下执行：

```powershell
$env:HLS_BUILD_ROOT=(Resolve-Path "..\..\hls_work").Path
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csim.tcl --work_dir %HLS_BUILD_ROOT%\fisheye_csim"
cmd /c "\"D:\AMD\2025.2\Vitis\settings64.bat\" && \"D:\AMD\2025.2\Vitis\bin\vitis-run.bat\" --mode hls --tcl scripts\csynth.tcl --work_dir %HLS_BUILD_ROOT%\fisheye_csynth"
..\..\80_TB\run_tb_vbram_hls_integration.bat
```

说明：Vitis HLS 2025.2 自动 `cosim` 不支持该类 `ap_ctrl_none` 多周期、非自同步 BRAM 控制端口核，会报 `COSIM 212-345`。本子工程以 `csim`、`csynth` 和 XSim RTL 集成仿真作为通过标准。

## 当前实现约束

首版采用最近邻采样，每个输出像素读取一个源像素，匹配现有单读口 BRAM 带宽。半径默认按 `1024px -> 93°` 映射，图像中心默认 `(1024,1024)`。红外表来自 `畸变表.xlsx` 的 `红外` sheet，激光表来自 `激光` sheet。自适应预处理使用上一帧 min/max 估计黑电平和 Q8 增益，第一帧保持单位增益，输出做 16-bit 饱和。如果后续提供实际主点、焦距或完整相机内参，应更新 HLS 常量并重新综合。
