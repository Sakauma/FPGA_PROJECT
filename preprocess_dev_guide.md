# 预处理算法开发位置说明

作者：Egor Izmaylov

## 结论

当前工程如果要开发“在 BRAM 中读取像素并完成视觉预处理”的逻辑，主改位置应放在：

- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`

必要时再下探到：

- `20_HDL/22_User/SRIO_2_BRAM/readbram_to_axis64/readbram_to_fifo.v`

不建议一开始直接修改更上层的 SRIO 协议顶层或系统总装模块。

## 依据

参考仓库 `_external/Stander` 中的原始接口说明文档《预处理SRIO接口转视频处理接模块口和仿真工程简介.md》明确给出：

- `vbram_lutaxi4_to_axis.v` 是“视频处理的接口文件”
- `SRIO_2_Video.v` 是 SRIO 与视频数据转换顶层
- 视频处理工程应在 `vbram_lutaxi4_to_axis.v` 下开发

同时，原始 `tb_top.v` 也说明了：

- `SRIO_2_Video.v` 为顶层
- `vbram_lutaxi4_to_axis.v` 为视频处理模块
- 当前测试链路是“从 BRAM 中按 16bit 读取，再拼成 64bit AXIS 发往 SRIO”

## 当前工程中的对应关系

当前工程沿用了这条结构，主链如下：

`SRIO_R_axis -> srio_v_axis_to_bram_top -> u_video_ram -> u_vbram_lutaxi4_to_axis -> SRIO_T_axis`

对应文件位置：

- `20_HDL/22_User/SRIO_2_BRAM/SRIO_2_Video.v`
- `20_HDL/22_User/SRIO_2_BRAM/vbram_lutaxi4_to_axis.v`
- `20_HDL/22_User/SRIO_2_BRAM/readbram_to_axis64/readbram_to_fifo.v`

对比原始仓库后可确认，这几处核心代码结构基本保持一致，因此原始接口文档中的开发边界对当前工程仍然有效。

## 按算法类型选择改动位置

### 1. 逐像素算法

例如阈值、增益校正、坏点修复、LUT 映射、简单灰度变换。

建议位置：

- `vbram_lutaxi4_to_axis.v`

理由：

- 这里正处于“BRAM 读出到后级 AXIS 输出”的接口层
- 插入像素处理模块最直接
- 不会破坏 SRIO 接收写 BRAM 的稳定链路

### 2. 邻域算法

例如 `3x3` / `5x5` 卷积、去噪、边缘检测、插值、行窗口处理。

建议位置：

- `readbram_to_axis64/readbram_to_fifo.v`

理由：

- 这里已经掌握 BRAM 行号、读地址和逐行输出控制
- 更适合扩展行为窗口、列窗口、邻域缓存等结构

### 3. 改写 BRAM 存储格式或写入方式

例如需要在写入 BRAM 前重组像素、改地址组织方式、改写每行布局。

建议位置：

- `srio_v_axis_to_bram/srio_v_axis_to_bram_top.v`
- `srio_v_axis_to_bram/srio_v_fifo_to_bram_wb.v`

这种改动风险更高，应放在算法需求明确之后再动。

## 建议的开发原则

- 优先在 `vbram_lutaxi4_to_axis.v` 下新增独立预处理模块，再由 `SRIO_2_Video.v` 接线
- 只有在需要邻域窗口或复杂 BRAM 读控制时，才下探修改 `readbram_to_fifo.v`
- 除非必须改变 BRAM 写入组织方式，否则不要先动 `srio_v_axis_to_bram/*`

## 额外注意

当前结构本质上是 BRAM A 口写、B 口读，更适合“读出后处理并直接输出”。如果后续算法要求“处理后再写回 BRAM”，通常需要重新设计为双缓冲或新增结果 BRAM。
