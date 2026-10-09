# 图表迁移共享输入

`chart-migration-audit-v1.json` 是首轮固定 48 点 column、单组/多组面积和混合类型输入，保持不可变，以便复验历史证据。

`chart-migration-audit-v2.json` 保留前四份输入，新增：

- `cases/area-missing`：面积的电池索引 12、辅助索引 25 缺测。用于新侧普通/百分比及隐藏/恢复的全 48 类目数学断言；旧拆分函数的 NSNull 崩溃已单独记录，尚未宣称旧面积百分比与此样本对等。
- `detailCases/gaps`：17 个 null、跨零数据和手工 X 分区；旧 Demo 与原生对照测试共用。
- `detailCases/format`：原始数值、逐点名称/组名、仅名称、隐藏提示行、逐点过滤和前值规则。旧 Demo 消费完整配置；新测试只验证已有提示规则和源索引，特殊精度、动态组名/表头的正式接入仍待 R2/R3。
- `xSeries`：独立于类别轴的日期表头。`revisionDelta` 指旧 Demo 刷新按钮对该系列有效数值的增量，null 保位。

旧 Demo 的 gaps/format 在 48 点时读取 v2，其余点数仍采用原公式生成。Fixture 是测试数据，不加入 HYMCharts.framework 或原生 Demo App 产品。JSON null 在旧侧为 NSNull，新侧为 NaN；绝不能删项或替换为 0。

2026-09-30 v2 重跑的 4 份旧引擎 JSON（含 gaps/format）与先前保存快照完全一致，见[证据](../../docs/evidence/charts-legacy-comparison/2026-09-30-foundation/README.md)。

`chart-area-boundaries-v1.json` 是 G1 面积边界的两份独立三点样本：固定正/负基线上的自身跨零，以及固定基底 / 跨零前层 / 正值上层的前层换链。最终两侧均用 `areaspline`（旧 model 顶层类型也为 areaspline），确保旧拆分和透明辅助分支实际执行。旧 Demo 在“正负堆叠与百分比”页的配置里提供两个按钮；新侧测试直接读取同一文件的数值和线型，页面预设也核对同值。业务输入相同不代表引擎系列数量、累计规则、颜色或默认坐标轴相同；对照结果见[本轮证据](../../docs/evidence/charts-legacy-comparison/2026-09-30-g1-envelope/README.md)。
