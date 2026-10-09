# N2：通用轴展示 schema v4 任务进度

更新：2026-10-09（Asia/Shanghai）。本轮接续 [N1 值轴颜色分区](charts-neutral-zones-task-progress-2026-10-09.md)，按[下一任务计划](charts-next-task-plan-2026-10-09.md)实施 N2；不顺带扩张 G6 或开始 R2 旧模型转换。

## 1. 已实现的切片

- Foundation-only 新增 `ChartFontWeight`（九种系统字重）和 `ChartAxisLabelFormat`（数字展示 + 显式单位后缀）。值轴增加 `tickPositions` / `labelFormat`，轴外观增加 `labelFontWeight`，类目域增加 `categoryLabelInterval`。
- **显式 schema v4** 承载新字段；默认构造仍是 v1。v1–v3 的五处新保留键即使为 null/错误类型也拒绝，编码前校验阻止静默降级；v2 及以后仍必填 G1 边界。旧三版 JSON 不变，新增第四版共享样本。
- 刻度必须有限且严格递增；nil 自动、空列表明确无刻度/同源网格。域外位置由原生有效域过滤，不改变值域。类目间隔必须是正整数，按原始绝对索引挑选候选；避让可增大步长，不抽样/重排数据。
- 轴格式只改变展示，复用已有数字格式契约。后缀前加空格、工程缩写前缀置于单位前；不自动推断单位、换算原值或套用旧业务政策。示例固定 locale，百分比显式用 `%`。
- HYM 映射到现有 G3 刻度、轴字体和 labelFormatter；未改原生绘制/坐标算法。主次值轴、域轴各自独立；Bar 正确映射逻辑值轴到屏幕 X。连续数值/时间 X、反向轴、水平次轴等拒绝边界不变。
- Swift 和纯 OC 宿主共用 `energy-axes-v4.json`；OC 沿用不可变 document + bridge。更新成功可保留/重置视口，失败保留最后有效图表。
- 现有四类页面同页增加轴选择、系统字重、刻度/单位格式预设、类目候选间隔，垂直图提供次轴示例。按稳定轴 ID 保存，关闭次轴不清除设置，恢复默认回到 v1。已核对 `DemoThemeFields` 全局字体与 `CartesianDemoSettings` 独立轴控制，未新增重复原生页面/字段登记。

完整 API、边界与代码示例见[模型指南](charts-neutral-model-guide.md)。

## 2. 验证进度

**N2 既定契约与适配范围已完成并通过验收；不是视觉无缺陷或全部旧轴配置迁移完成。**

| 验证 | 最终实际结果 |
| --- | --- |
| 主工程完整单元 | **419/419**，其中新增轴展示专项 **13/13**（包含在 419 中，不另加） |
| 受影响 UI | **4/4**：四页轴展示/独立轴/恢复默认，四页 N1 分区，G1 边界，显式不支持能力与恢复 |
| 同一主工程最终结果包 | **423/423，0 失败、0 跳过** |
| 独立 Release Swift / 纯 OC 宿主 | **2/2**，均要求四版共享 JSON 通过；framework 产物审计通过 |
| Foundation-only | Swift 6 完整严格并发独立编译通过；v1–v4 四份 JSON 逐字节复现，旧三版内容不变 |
| 离线审计 | Python 回归 **26/26**；197 条旧声明与覆盖矩阵一致性、文档/截图完整性、diff 空白检查通过 |

使用 Xcode 26.3 / iPhone 16 Pro / iOS 18.6 / arm64 模拟器；不是全量 UI 或真机验收。最终日志、官方摘要/测试树、4 张未改动原始 PNG、来源清单与散列见[本批证据](evidence/charts-neutral-axes-2026-10-09/README.md)。

**截图已逐张复核且保留限制**：Line/Column 可见主轴 W 与次轴 °C，Combined 次轴只显示有效域内的 0 °C；Bar 值轴在底部、类目在左侧。类目候选显示 8:00/10:00/12:00。主轴 bold 与次轴 light 的外观有区分，精确九种字重由专项断言覆盖。Bar 最右端 `150 W` 沿原生边带限宽策略截成 `15…`，深色标题/部分轴文字对比度仍偏低；没有删刻度、改单位或修图掩盖。原生布局策略后续单独处理，本批不宣称全主题可读性达标。

开发期问题与处理：
1. 缩放测试原窗口边界会包含原生为连续绘制保留的相邻类目，错误地预期该类目标签不存在；改用避开边界的窗口，不改变原生可见区算法。
2. 固定图表下方 Form 高度有限，UI 测试的整屏向下滑动落在固定预览上；部分开关仅露出一部分时 isHittable 仍为 true，坐标点击实际越界。改成仅在 Form 内拖动，完整露出后点击，并校验开关值实际改变；对底部恢复按钮使用安全区内可达范围。
3. 一次 XCTest runner 在连接测试之前出现 CFBundle/NSUserDefaults 启动崩溃；保留日志，未把此运行计作通过，不改生产代码绕过。
4. 首轮完整回归中旧 N1 分区 UI 仍用整屏滚动，新增轴展示区域使它无法到达分区开关；提取上述已验证的 Form 定位函数供 N1/N2 共用，不删除旧回归或放宽其断言。首轮官方摘要和日志单独保留，不混入最终通过数。
5. 覆盖报告引用指南行号，指南修改后须重新生成，不能沿用旧行号；最终重跑离线回归。

## 3. 覆盖矩阵增量

当前 **197 旧声明、59 能力主题、15 原生/后端复核主题**；处置为 **47 已表达 / 39 待补通用语义 / 104 外层职责 / 7 应拒绝或不承接**。

本批仅将 7 条旧声明的展示意图标为已表达：三条轴字重、两条主/次轴刻度、一条类目间隔、一条轴刻度单位。**不表示旧 mapper 已交付**：任意字重字符串仍需 R2 解析/诊断，旧 unit 的空白/业务换算差异仍需业务确认。旧完整 zones、连续坐标、业务单位工具等处置不变。

## 4. 明确保留的边界

- 不含值轴 tickInterval/tickCount、类目旋转、自定义字体资源、任意 JS/闭包格式或旧业务单位/金额政策。
- 不解除 G6 连续 X/反向轴、水平次轴，以及仅开次轴网格等已有后端拒绝。
- 不是全量 UI、真机、长时性能/内存、实际业务页或第二生产后端验收。
- 既有深色主题静态标题/部分标签低对比度、Bar 边缘长刻度按原生策略截断、Swift existential/资源警告未在本批修复；通过测试不等于 warning-free。
- 不提交、推送或清理既有脏工作区；不重复执行历史关机请求。

## 5. 下一入口：N3 标线/色带

N2 既定契约验收完成，下一切片为 **G4 标线/色带及必要文字样式进入通用模型**：

1. 已复核原生 `CartesianPlotLine/CartesianPlotBand`：目前仅值轴、通过 yAxisIndex 绑定；首切片应限定为稳定 valueAxisID 的值轴标线/色带。类目标注、真实 X 标注均不冒称已有支持，不借标注放开连续 X。
2. 明确有限坐标/有序范围、颜色、线型、标签、可见性；保留原生固定层次（带体在系列后、线与文字在前），不虚构可选层级。文字先复用 N2 系统字重，再核对屏幕对齐/偏移/clamp 或 hide 语义；任意 zIndex、自由画布、格式化代码不进入通用契约。
3. 先写版本与失败策略测试，再接 HYM、Swift/OC 共享例子和既有四页 Demo；不提前升级 schema，也不假定全部原生注释样式能无损表达。
4. 验证主/次轴、水平图、G1/百分比/缺测、越界裁剪、更新/重排/失败保留；最后完整单元、受影响 UI、独立 Release 和证据验收。

原生核对入口：[标线/色带结构](../SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift)、[文字布局](../SwiftFunctionProject/Charts/Cartesian/CartesianAnnotationLabel.swift)、[G4 指南](charts-annotation-style-guide.md)。这只是下一切片范围核对，本批没有新增 annotation schema 或修改 G4 绘制。

代码入口：[轴契约](../SwiftFunctionProject/Charts/Specification/ChartAxisPresentation.swift)、[版本编码](../SwiftFunctionProject/Charts/Specification/ChartSpecificationVersionCoding.swift)、[HYM 转换](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift)、[专项测试](../SwiftFunctionProjectTests/ChartSpecificationAxisPresentationTests.swift)、[共享 JSON](../Examples/ChartSpecifications/energy-axes-v4.json)、[覆盖矩阵](charts-neutral-model-coverage.md)。
