# fisheye_remap HLS 子工程

作者：Egor Izmaylov

本目录保存鱼眼去畸变算法的 HLS 源码、仿真入口、畸变表和导出 RTL。当前稳定上板版本使用 `fisheye_remap_addr_hls` 作为 HLS 顶层：HLS 只计算源像素地址，SRIO 发包节奏由 RTL packetizer 保证。

## 目录说明

- `src/fisheye_remap_reader_hls.h`：算法常量、控制位、HLS 顶层接口和旧 reader 声明。
- `src/fisheye_remap_reader_hls.cpp`：去畸变映射、局部圆环拉平补偿、自适应预处理函数和旧 reader 保留代码。
- `src/distortion_lut.h`：红外/激光畸变表的 Q2.16 定点 LUT。
- `tb/fisheye_remap_reader_hls_tb.cpp`：地址核和 packet 协议单元测试。
- `tb/fisheye_remap_raw16_tb.cpp`：读取 `2048x2048 raw16` 相机帧并保存逐帧仿真结果。
- `scripts/csim.tcl`：HLS C 仿真。
- `scripts/csim_raw.tcl`：真实 raw16 数据仿真。
- `scripts/csynth.tcl`：综合并同步 `rtl/` 下导出文件。
- `rtl/`：Vitis HLS 导出的 Verilog 和 ROM `.dat`，不要手工修改。

## 当前硬件假设

- 图像尺寸：`2048 x 2048`。
- 像素格式：raw16，小端输入，SRIO payload 内 4 像素打包为 64 bit。
- BRAM 行缓存：`P_LINE_DEPTH=256`，半深度 `128`。
- 垂直 remap 安全窗口：`±96` 行。
- 每行输出：16 包，每包 1 个 header + 32 个 payload。

这些假设必须与 `20_HDL/22_User/SRIO_2_BRAM/fisheye_remap_packetizer_to_axis.v` 和 `vbram_lutaxi4_to_axis.v` 保持一致。

## 常用命令

```powershell
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csim.tcl"
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csynth.tcl"
```

raw16 逐帧仿真：

```powershell
$env:FISHEYE_RAW_DIR='D:\Staff\data'
$env:FISHEYE_RAW_MAX_FRAMES='100'
$env:FISHEYE_RAW_SAVE_EACH_FRAME='1'
$env:FISHEYE_RAW_OUT_DIR='D:\Staff\data\fisheye_clean_results'
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csim_raw.tcl"
```

## 开发注意事项

- 优先修改 `src/`，再用 `csynth.tcl` 重新生成 `rtl/`。
- 不要手改 `rtl/` 下 HLS 生成文件。
- 如果 HLS 生成新 helper 模块，必须同步检查 RTL wrapper 的 include 列表。
- 如果修改 `algo_ctrl` 语义，必须同步更新 `80_TB/` 测试平台和 `docs/algorithm_development_guide.md`。
- 当前工程不使用 HLS 旧 reader 作为实时上板路径，旧代码只作为历史保留和对照。
