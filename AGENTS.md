# Repository Guidelines

## 项目结构与模块组织
`20_HDL/21_TOP/EB4110_10V10_TOP.v` 是工程顶层。手写业务逻辑集中在 `20_HDL/22_User/`，其中包括 `Common`、`axis`、`EB4110`、`SRIO_2_BRAM`、`XADC_GET` 等子目录；公共宏定义放在 `30_DEF/define.v`，约束文件放在 `60_XDC/IR2520.xdc`，顶层测试平台位于 `80_TB/tb_top.v`。可维护的 IP 定义位于 `50_IP/ip/*.xci`。`10_PRJ/00_PRJ.*`、`50_IP/ip_gen/`、`20_HDL/ip_gen/` 为 Vivado 生成内容，原则上不要手工修改，应通过 Vivado 重新生成。`40_COE/` 存放初始化数据，`70_BIN/` 用于发布产物，`00_DOC/` 保存板级和接口说明。

## 构建、测试与开发命令
使用 `vivado 10_PRJ\00_PRJ.xpr` 打开工程。顶层综合入口为 `10_PRJ\00_PRJ.runs\synth_1\runme.bat`，实现与比特流生成入口为 `10_PRJ\00_PRJ.runs\impl_1\runme.bat`。如需重建或清理工程，可使用 `10_PRJ/` 下的辅助 `.bat` 脚本。导出的 IP 仿真脚本位于 `10_PRJ/00_PRJ.ip_user_files/sim_scripts/`，例如 `bash 10_PRJ/00_PRJ.ip_user_files/sim_scripts/srio_gen2_5g_2x_8b/xsim/srio_gen2_5g_2x_8b.sh -reset_run`。当前工程已在 `Vivado 2025.2` 上完成完整仿真、综合、生成 bitstream，并已成功烧录到 FPGA。

## 代码风格与命名约定
沿用现有 Verilog 风格：保留文件头注释，端口和参数列表按现有格式对齐，大接口尽量一行一个信号。顶层或工程主模块使用较强的功能化命名，例如 `EB4110_10V10_TOP`；可复用模块通常采用小写下划线命名并带版本尾缀，例如 `async_fifo_v1000`。参数、宏和编译开关统一使用大写；公共常量优先放入 `30_DEF/define.v`。仓库内未发现统一格式化或 lint 配置，不要做无关的大面积排版调整。

## 测试规范
当前仓库级测试平台主要是 `80_TB/tb_top.v`。修改顶层逻辑、时钟复位、SRIO/AXIS 数据通路或约束后，至少重新执行相关仿真与一次综合；若涉及 IP 行为，需同步验证 `10_PRJ/00_PRJ.ip_user_files/sim_scripts/` 下对应导出脚本。仓库中未见覆盖率统计配置，因此提交时应补充人工验证结论，包括关键波形、时序结果、资源变化和板上现象。

## 提交与合并请求规范
当前目录不包含 `.git`，无法直接从本地历史中提炼提交格式。建议使用简短、祈使句式的提交标题，并加上作用域前缀，例如 `srio: 修正 AXI-Lite 握手`、`xdc: 收紧 GT 时钟约束`。提交合并请求时应注明目标器件、所用工具链版本（当前为 `Vivado 2025.2`）、修改的源码路径，以及验证证据：仿真结果、综合/实现状态、时序摘要，以及在行为变化明显时附上波形或 ILA 截图。
