# Repository Guidelines

> 作者：Egor Izmaylov

## 项目结构与模块组织
`20_HDL/21_TOP/EB4110_10V10_TOP.v` 是工程顶层。手写业务逻辑集中在 `20_HDL/22_User/`，重点包括 `EB4110/`、`SRIO_2_BRAM/`、`axis/`、`Common/` 和 `XADC_GET/`。公共宏定义位于 `30_DEF/define.v`，约束位于 `60_XDC/IR2520.xdc`，测试平台位于 `80_TB/`。HLS 预处理算法工程位于 `hls/undistort_demo/`，算法接入 RTL 包装位于 `20_HDL/22_User/SRIO_2_BRAM/undistort_demo_hls_wrap.v`。

## 生成物与维护边界
`10_PRJ/00_PRJ.xpr` 是 Vivado 打开入口。`50_IP/ip/*.xci` 是可维护 IP 定义；`10_PRJ/00_PRJ.runs/`、`10_PRJ/00_PRJ.cache/`、`10_PRJ/00_PRJ.ip_user_files/`、`20_HDL/ip_gen/`、`50_IP/ip_gen/` 是 Vivado 派生产物，原则上不要手工修改。若 IP 或 BD 需要更新，应在 Vivado 中重新生成，并只提交源级工程配置和必要元数据。

## 构建、测试与开发命令
打开工程：`vivado 10_PRJ\00_PRJ.xpr`。2025.2 批处理打开检查：`vivado -mode batch -source 10_PRJ/open_project_2025.tcl`。完整构建：`vivado -mode batch -source 10_PRJ/build_project_2025.tcl`，必要时追加 `-tclargs reset` 重跑综合和实现。2020.2 静态兼容检查入口为 `vivado -mode batch -source 10_PRJ/check_project_static_2020.tcl`；当前机器未实机验证 2020.2。

## 代码风格与命名约定
沿用现有 Verilog 风格：保留历史文件头，端口和参数列表按当前对齐方式维护，大接口尽量一行一个信号。顶层模块使用功能化命名，例如 `EB4110_10V10_TOP`；可复用模块常用小写下划线并带版本号，例如 `async_fifo_v1000`。参数、宏和编译开关使用大写。新增或改进注释使用中文，并标记作者 `Egor Izmaylov`；不要重排无关代码。

## 测试规范
修改 SRIO、AXIS、BRAM、时钟复位、HLS 算法或约束后，至少执行相关 RTL 仿真和一次综合。算法验证优先运行 `hls/undistort_demo/scripts/csim.tcl`、`csynth.tcl`、`cosim.tcl`，覆盖 `0x0`、`0x1`、`0x3`、`0x7` 控制模式。RTL 集成验证使用 `80_TB/run_tb_vbram_hls_integration.bat`，期望输出 `PASS: tb_vbram_hls_integration`。

## 提交与合并请求规范
仓库使用 Git 管理，提交标题建议采用简短作用域前缀，例如 `rtl: add HLS preprocessing wrapper`、`docs: update Vivado build guide`。PR 或推送说明应包含工具链版本、目标器件、修改路径、验证命令、综合/实现状态、时序摘要和板上现象。不要提交本地缓存、构建目录、备份目录或 Vivado 日志。
