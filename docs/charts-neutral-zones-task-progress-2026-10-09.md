# N1 值轴阈值颜色：schema v3 任务进度

日期：**2026-10-09（Asia/Shanghai）**。执行[同日下一步计划](charts-next-task-plan-2026-10-09.md)中的 N1，不扩展 G6、不启动旧模型 R2 mapper 或第二后端。

## 1. 本批范围

- Foundation-only 的 `ChartZoneValueSource`、`ChartValueColorZone`、`ChartValueColorZones`；逐系列入口为 `appearance.valueColorZones`，显式 schema v3。
- 逻辑值轴的半开有序阈值，nil 末上界、nil 颜色与尾部继承、无效阈值/颜色的精确错误路径。水平 Bar 仍使用逻辑值轴；各系列按 valueAxisID 绑定单位。
- HYM 柱/条支持 raw/draw，线/面积只支持 draw，raw 明确报 unsupportedCapability（隐藏系列也检查）。分区仅决定颜色，不改变原始贡献、缺测、域、堆叠、样本/命中身份；不覆盖面积填充。
- v1/v2 合法文档与示例编码保持不变，构造器继续默认 v1。旧版本夹带新保留键（包括 null）、带新配置降级、未知版本均拒绝；v2/v3 均要求显式 G1 边界字段。
- 使用现有原生分区能力，未改渲染器算法。Swift/OC 通过同一 v3 JSON 及现有不可变 document/bridge；独立宿主继续验证 v1/v2。
- 既有 Line/Column/Bar/Combined 同页通用预览增加逐系列 ID、0/50 阈值颜色示例开关、柱族 raw/draw 选择及恢复默认，不新增图表入口。原生属性字段登记不重复添加中立专用字段。

## 2. 最终验收：N1 已完成

本节是 **2026-10-09 实际执行**的结果，不沿用 10 月 3 日的运行数。主工程与独立宿主均使用 iPhone 16 Pro / iOS 18.6 / arm64 模拟器。

| 检查 | 结果 |
| --- | --- |
| 主工程完整单元 + 三项相关 UI | **406 + 3 = 409/409**，0 失败、0 跳过 |
| 独立 Release Swift / 纯 OC 公开导入 | **2/2**；每个宿主都要求 v1/v2/v3 共享示例通过 |
| Foundation-only 核心 | Swift 6 完整严格并发编译通过；v1/v2/v3 示例逐字节复现，旧两版示例未变 |
| Release framework 审计 | 新类型/字段可公开导入，OC document/bridge 保留；无旧引擎、Demo 或样例资源混入 |
| Python 审计脚本回归 | **25/25**，含“不把 Y 颜色子集算作整个旧 zones 已完成”的新增约束 |
| 文档/截图证据 | 本批 **7 张原始 PNG** 已逐张目视复核；来源、哈希与本地链接检查通过 |

最终主工程结果 `/tmp/hym-neutral-zones-final-20261009.xcresult`，独立宿主结果 `/tmp/hym-neutral-zones-public-final-20261009.xcresult`。官方摘要、测试树、压缩日志、复跑命令、输入散列及范围边界见[本批证据](evidence/charts-neutral-zones-2026-10-09/README.md)。不是全量 UI 或真机验收。

测试覆盖半开阈值、继承及颜色优先级、raw/draw、隐藏/恢复、水平/垂直柱、无堆叠/普通/自动百分比/固定百分比、主次轴和混合图族、G1 模式、缺测/原始值/稳定身份、失败更新与视口保留/重置。四页 UI 检查逐系列选择不串值、开关/取值来源、恢复默认；另回归 G1 和不支持能力的错误恢复。

**视觉证据的限度**：当前保存的是 source-0 首层，其 raw/draw 在该输入下相同，不以两张相似截图证明取色差异；raw=20 / draw=70 等跨阈值差异由专项模型/渲染器测试核对。线图分区描边/点颜色生效而面积填充保持既有色。既有深色标题/部分标签对比度偏低，未在本批修复。

开发中暴露并修正（不计入最终通过数量）：
1. 新测试直接比较 UIKit 灰度黑与 sRGB 黑对象，造成假失败；改为核对适配后的预期 RGBA 色。
2. 原有“未知未来版本”测试硬编码 3；v3 已成为有效版本，改为 `latestSchemaVersion + 1`，保留 NSError/字段路径断言。
3. 离线覆盖证据锚点随版本编码注释变动失效，改为实际边界编码语句，最终全部 25 项 Python 测试通过。
4. 产物审计初次把编译器生成的 `.abi.json` 误认作样例 JSON；仅放行 `Modules/HYMCharts.swiftmodule` 内 ABI 元数据，其他 JSON 资源仍拒绝。

## 3. 覆盖矩阵的真实增量

当前为 **197 旧声明、59 能力主题、14 原生/后端复核主题**，主题有交集，不相加算迁移量。处置仍为 **40 已表达 / 46 待补通用语义 / 104 外层职责 / 7 应拒绝或不承接**。

新建独立 `value-color-zones` 能力主题记录已支持子集。旧 `HMAASeriesElement.zones` / `zoneAxisX` 仍归 schema_gap（部分映射）：X 原始索引与分区填充没有进入本批通用 schema，不能因 Y 颜色接通而把整个旧字段判定为已覆盖。未建模额外 JSON 键不是已有拒绝入口；未来 R2 必须在丢失信息前诊断。

## 4. 仍未包含

- X 类目索引分区、真实连续 X 分区、分区面积渐变；HYM 线/面积 raw 分区仍明确拒绝。
- G6 反向值轴、连续数值/时间 X；当前适配器拒绝不变。
- 全量 UI、真机性能/长时生命周期、全主题无障碍、实际业务页面及第二生产后端验收。
- 既有深色主题静态标题/部分标签对比度，以及 Swift existential/资源警告；没有在本批假称解决。
- 不提交/推送，不清理已有工作区改动，不重复执行历史关机请求。

## 5. 下一步

下一项进入计划中的 **N2：已原生支持的轴展示进入通用模型**。先分别明确显式刻度、类目间隔、字体/刻度格式的中立契约和版本策略，再接 HYM、Swift/OC、同页 Demo 与测试；不要用轴展示任务顺带解除 G6 坐标拒绝。业务单位政策、D06/D07 和第二后端选择仍需真实输入，不能猜测。

代码入口：[模型](../SwiftFunctionProject/Charts/Specification/ChartValueColorZones.swift)、[版本编码](../SwiftFunctionProject/Charts/Specification/ChartSpecificationVersionCoding.swift)、[适配器](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift)、[新测试](../SwiftFunctionProjectTests/ChartSpecificationColorZoneTests.swift)、[同页 Demo](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationDemo.swift)、[指南](charts-neutral-model-guide.md)、[覆盖矩阵](charts-neutral-model-coverage.md)。
