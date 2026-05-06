# 工程构建与报告汇总（2026-04-14）

作者：Egor Izmaylov

## 2026-05-06 清理后复测

本次按 `vivado -mode batch -source 10_PRJ/build_project_2025.tcl -tclargs reset` 重新执行 Vivado 2025.2 工程构建，`synth_1`、`impl_1` 和 `write_bitstream` 均完成。`impl_1/runme.log` 显示 `Bitgen Completed Successfully`，最终为 `1143 Infos / 21 Warnings / 0 Critical Warnings / 0 Errors`。

关键结果如下：

- 生成物：`10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP.bit`，大小 `17,416,474 B`，时间 `2026-05-06 17:20:17`。
- 时序：`WNS=0.010 ns`，`TNS=0.000 ns`，`WHS=0.011 ns`，`THS=0.000 ns`，报告结论为 `All user specified timing constraints are met.`。
- 资源：`Slice LUTs=56,847 (20.49%)`，`Slice Registers=74,286 (13.39%)`，`Block RAM Tile=439 (58.15%)`，`DSP=0`，`GTXE2_CHANNEL=6`。
- 功耗：`Total On-Chip Power=7.110 W`，`Dynamic=6.749 W`，`Device Static=0.361 W`，`Junction Temperature=37.5 C`，置信度 `Low`。
- 仍需关注：综合阶段保留 3 条 Critical Warning，来自 `60_XDC/IR2520.xdc:169` 的空时钟组对象和 `eb4110_video_prj_top.v:320` 的 `keep` 属性值格式；未阻塞 bitstream。

## 1. 构建结论

本次工程已完成顶层综合、实现、布线与比特流生成，目标器件为 `xc7z100ffg900-2`，顶层为 `EB4110_10V10_TOP`。最新产物位于 `10_PRJ/00_PRJ.runs/impl_1`：

| 文件 | 大小 | 时间 |
| --- | ---: | --- |
| `EB4110_10V10_TOP.bit` | 17,416,474 B | 2026-04-14 23:17:01 |
| `EB4110_10V10_TOP.ltx` | 74,203 B | 2026-04-14 23:17:02 |
| `EB4110_10V10_TOP_incr_cfg.bit` | 17,417,045 B | 2026-04-14 23:17:10 |
| `EB4110_10V10_TOP_incr_cfg_disable_icap.bit` | 17,417,202 B | 2026-04-14 23:17:16 |

`impl_1/runme.log` 显示 `Bitgen Completed Successfully`，比特流生成成功。

## 2. 综合结果

综合命令来自 `10_PRJ/00_PRJ.runs/synth_1/runme.log`：

```tcl
synth_design -top EB4110_10V10_TOP -part xc7z100ffg900-2 \
  -directive PerformanceOptimized -fsm_extraction one_hot \
  -keep_equivalent_registers -resource_sharing off -no_lc \
  -shreg_min_size 5 -incremental_mode off
```

- 综合耗时：`cpu 00:02:01`，`elapsed 00:02:06`
- 峰值内存：`2422 MB`
- 日志摘要：`0 errors / 0 critical warnings / 30 warnings`

综合后资源利用率：

| 资源 | 已用 | 可用 | 利用率 |
| --- | ---: | ---: | ---: |
| Slice LUT | 13,450 | 277,400 | 4.85% |
| Slice Register | 15,798 | 554,800 | 2.85% |
| Block RAM Tile | 318 | 755 | 42.12% |
| DSP | 0 | 2,020 | 0.00% |
| Bonded IOB | 41 | 362 | 11.33% |
| GTXE2_COMMON | 2 | 4 | 50.00% |
| IBUFDS_GTE2 | 2 | 8 | 25.00% |

综合日志中值得关注但未阻塞流程的问题：

- `60_XDC/IR2520.xdc:162` 的 `set_clock_groups` 未匹配到有效时钟对象。
- `20_HDL/22_User/EB4110/eb4110_video_prj_top.v:311` 中 `keep` 属性值 `srio_top ` 不符合 Vivado 期望格式。

## 3. 实现与时序

实现主日志 `10_PRJ/00_PRJ.runs/impl_1/runme.log` 显示：

- 放置后 WNS：`0.178 ns`
- 布线后 WNS/TNS：`0.135 ns / 0.000 ns`
- 布线后 WHS/THS：`0.033 ns / 0.000 ns`

`EB4110_10V10_TOP_timing_summary_routed.rpt` 摘要如下：

| 指标 | 数值 |
| --- | ---: |
| WNS | 0.135 ns |
| TNS | 0.000 ns |
| TNS Failing Endpoints | 0 |
| THS | 0.000 ns |
| WHS | 0.033 ns |
| THS Failing Endpoints | 0 |
| TPWS | 0.000 ns |

结论：`All user specified timing constraints are met.`

报告中可见的典型时钟包括：

- `clk_fpga_0`：`10.000 ns`，`100 MHz`
- `clk_out1_clk_dcm`：`5.000 ns`，`200 MHz`
- `clk_ref_mmcm_400`：`2.500 ns`，`400 MHz`

实现初期仍有 3 条约束对象为空的告警，均来自 `60_XDC/IR2520.xdc:13~15`，但未阻塞后续实现和写 bit 流程。

## 4. 实现后资源利用率

`EB4110_10V10_TOP_utilization_placed.rpt` 的关键结果如下：

| 资源 | 已用 | 可用 | 利用率 |
| --- | ---: | ---: | ---: |
| Slice LUT | 56,286 | 277,400 | 20.29% |
| Slice Register | 73,311 | 554,800 | 13.21% |
| Slice | 25,229 | 69,350 | 36.38% |
| Block RAM Tile | 439 | 755 | 58.15% |
| DSP | 0 | 2,020 | 0.00% |
| Bonded IOB | 132 | 362 | 36.46% |
| Bonded IOPADs | 130 | 130 | 100.00% |
| GTXE2_CHANNEL | 6 | 16 | 37.50% |
| GTXE2_COMMON | 2 | 4 | 50.00% |
| IDELAYE2 | 64 | 400 | 16.00% |
| ILOGIC | 72 | 362 | 19.89% |
| OLOGIC | 113 | 362 | 31.22% |

## 5. 功耗摘要

`EB4110_10V10_TOP_power_routed.rpt` 显示：

| 指标 | 数值 |
| --- | ---: |
| Total On-Chip Power | 7.106 W |
| Dynamic | 6.745 W |
| Device Static | 0.361 W |
| Junction Temperature | 37.5 C |
| Confidence Level | Low |

主要功耗来源：

- GTX：`1.715 W`
- PS7：`1.487 W`
- I/O：`1.126 W`
- PHASER：`0.661 W`
- MMCM：`0.537 W`
- Clocks：`0.500 W`
- Block RAM：`0.332 W`

功耗置信度为 `Low`，主要原因是 I/O activity 信息不完整；若后续需要更可信的功耗估计，应补充更完整的输入翻转率或仿真活动文件。

## 6. DRC 与方法学检查

布线后 DRC 报告 `EB4110_10V10_TOP_drc_routed.rpt`：

- 总检查项：`153`
- `CHECK-3`：2
- `PDCN-1569`：21
- `PDRC-153`：78
- `REQP-1709`：1
- `REQP-1839`：20
- `REQP-1840`：20
- `RTSTAT-10`：1
- `REQP-165` Advisory：10

方法学报告 `EB4110_10V10_TOP_methodology_drc_routed.rpt`：

- 总检查项：`593`
- `LUTAR-1`：180
- `PDRC-190`：22
- `SYNTH-6`：256
- `TIMING-9`：1
- `TIMING-10`：1
- `TIMING-18`：28
- `TIMING-24`：28
- `TIMING-47`：5
- `XDCB-5`：7
- `LATCH-1` Advisory：1
- `REQP-1959` Advisory：64

这些结果以 Warning/Advisory 为主，未阻塞 bitstream 生成。

## 7. 路由状态

`EB4110_10V10_TOP_route_status.rpt`：

- 逻辑网络数：`164,303`
- 无需布线网络：`45,191`
- 可布线网络：`119,112`
- 完全布线网络：`119,112`
- 布线错误网络：`0`

结论：当前实现结果已完成全部可布线网络，无路由错误。

## 8. 原始报告文件位置

综合阶段：

- `10_PRJ/00_PRJ.runs/synth_1/runme.log`
- `10_PRJ/00_PRJ.runs/synth_1/EB4110_10V10_TOP_utilization_synth.rpt`

实现阶段：

- `10_PRJ/00_PRJ.runs/impl_1/runme.log`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_timing_summary_routed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_timing_summary_postroute_physopted.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_utilization_placed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_power_routed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_drc_routed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_methodology_drc_routed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_route_status.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_clock_utilization_routed.rpt`
- `10_PRJ/00_PRJ.runs/impl_1/EB4110_10V10_TOP_io_placed.rpt`

## 9. 备注

- 工程元数据中顶层综合策略标签仍显示为旧版 `Flow_PerfOptimized_high (Vivado Synthesis 2020)`，但本次实际综合命令已经按 Vivado 2025.2 展开的参数执行。
- 当前结果以 `2026-04-14` 这次成功的 `synth_1` 与 `impl_1` 为准。
