# EB4110 FPGA 图像预处理工程

作者：Egor Izmaylov

本仓库是 EB4110 预处理板 FPGA 工程，当前版本基于硬件部门提供的新版乒乓缓存链路，并迁入鱼眼去畸变 HLS 算法。工程主线只面向算法层开发：SRIO、BRAM 乒乓缓存、MIG、BD/IP、XDC、时钟复位和板级接口由硬件部门维护，算法开发不要直接修改这些底层链路。

## 当前功能

- SRIO 图像输入写入 BRAM 乒乓缓存。
- BRAM 读出阶段可通过 `ENABLE_FISHEYE_REMAP_READER` 启用 HLS 鱼眼去畸变地址映射。
- HLS 核 `fisheye_remap_addr_hls` 只计算源行槽和源列地址；实时发包、header、payload、tlast 节奏由 RTL packetizer 固定生成。
- 当前缓存深度为 `P_LINE_DEPTH=256`，算法常量必须保持 `256/128`，不要恢复旧工程的 `200/100` 假设。

## 工程结构

- `10_PRJ/00_PRJ.xpr`：Vivado 2025.2 工程入口。
- `20_HDL/`：硬件 RTL、SRIO 链路、BRAM 缓存和 HLS 接入 wrapper。
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`：HLS remap 编译开关所在位置。
- `20_HDL/22_User/SRIO_2_BRAM/fisheye_remap_packetizer_to_axis.v`：算法链路的稳定 SRIO packetizer。
- `hls/fisheye_remap/`：鱼眼去畸变 HLS 子工程。
- `80_TB/`：XSim 仿真平台，覆盖局部 BRAM/HLS 和 SRIO 端到端链路。
- `docs/algorithm_development_guide.md`：算法开发指南。

## 快速验证

```powershell
powershell -ExecutionPolicy Bypass -File 80_TB\check_srio_output_contract.ps1
cmd /c 80_TB\run_tb_vbram_hls_integration.bat
cmd /c 80_TB\run_tb_srio_video_e2e.bat
```

完整帧压力测试：

```powershell
$env:TB_STRESS_FULL='1'
cmd /c 80_TB\run_tb_srio_video_e2e.bat
```

raw16 相机数据验证：

```powershell
$env:FISHEYE_RAW_DIR='D:\Staff\data'
$env:FISHEYE_RAW_MAX_FRAMES='100'
$env:FISHEYE_RAW_SAVE_EACH_FRAME='1'
$env:FISHEYE_RAW_OUT_DIR='D:\Staff\data\fisheye_clean_results'
cmd /c "D:\AMD\2025.2\Vitis\settings64.bat && D:\AMD\2025.2\Vitis\bin\vitis-run.bat --mode hls --tcl hls\fisheye_remap\scripts\csim_raw.tcl"
```

## Vivado 构建

生成算法 bit 前，必须确认 `sources_1` 包含：

```tcl
ENABLE_FISHEYE_REMAP_READER
```

推荐构建前执行 JFM/IP patch hook：

```tcl
source D:/Staff/JFM_Kits/ip_patch/run.tcl
set run_tcl_path [file join $::env(JFM_PATH) "ip_patch" "run.tcl"]
source $run_tcl_path -notrace
show_ip_patch_version
add_hook_tcl_to_prj
```

上板优先使用同一轮 release 目录中的 `EB4110_10V10_TOP_incr_cfg_disable_icap.bit` 和匹配 `EB4110_10V10_TOP.ltx`。

## 提交边界

可以提交源码、HLS 脚本、TB、文档和必要 Vivado 工程元数据。不要提交 `00_PRJ.runs/`、`00_PRJ.cache/`、`00_PRJ.hw/`、`release_*/`、日志、ILA dump、bitstream 或 HLS build 输出。
