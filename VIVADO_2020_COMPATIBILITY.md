# Vivado 2020.2 静态兼容记录

作者：Egor Izmaylov

当前机器只安装并实测了 `Vivado 2025.2`，未安装 `Vivado 2020.2`。因此本仓库对 2020.2 的结论仅为静态兼容目标，不声明已经完成 2020.2 实机打开、综合或 bitstream 验证。

## 已做处理

- 保留 `10_PRJ/00_PRJ.xpr`、`00_PRJ.srcs/**/*.bd`、`*.xci` 作为工程输入。
- 忽略 `00_PRJ.runs/`、`00_PRJ.cache/`、`00_PRJ.ip_user_files/`、`.Xil/` 等 Vivado 派生产物。
- 新增 `10_PRJ/check_project_static_2020.tcl`，用于扫描明显的 2025.2 字段、绝对路径和 ModelSim 遗留配置。

## 2026-05-06 静态扫描结果

`vivado -mode batch -source 10_PRJ/check_project_static_2020.tcl` 已在 Vivado 2025.2 环境下执行完成。扫描结果提示：

- `10_PRJ/00_PRJ.xpr` 仍包含 `Product Version: Vivado v2025.2` 和 `SimulatorVersionXsim=2025.2`。
- `10_PRJ/00_PRJ.xpr` 中仍保留当前工作区绝对路径 `D:/Staff/test/...`，克隆后应由 Vivado 重新保存或用 Tcl 入口打开校正。
- `10_PRJ/00_PRJ.xpr` 仍有 ModelSim 相关历史字段，但当前工程目标仿真器已设置为 XSim。
- `MY_MEM.bd` 和 `zynq.bd` 的 `tool_version` 为 `2025.2`，2020.2 打开时可能提示升级/降级或需要重新生成输出产物。

## 待实机验证

在安装 Vivado 2020.2 的机器上执行：

```powershell
vivado -mode batch -source 10_PRJ/check_project_static_2020.tcl
vivado 10_PRJ\00_PRJ.xpr
```

打开后应执行 `Report IP Status`、`Generate Output Products`、综合、实现和 bitstream。若 Vivado 提示升级 IP，应先在单独分支验证，避免直接覆盖当前 2025.2 已验证工程。
