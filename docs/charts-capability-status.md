# HYMCharts 当前能力清单

更新：2026-10-03。以当前工作区源码为准；历史 specs/plans 记录设计过程，不代表当前待办。

最新任务入口：[通用模型任务进度与交接](charts-neutral-model-task-progress-2026-10-03.md)。本批最终 384 项单元 + 2 项相关 UI、独立 Release Swift/纯 OC 宿主 2 项均通过；验证范围及未完成项见该交接，不能与下方历史轮次计数混用。

2026-10-03 新增独立于绘图库的 [ChartSpecification 通用模型](charts-neutral-model-guide.md)：Foundation 值类型、明确数据/身份/样式、结构化校验、版本化 JSON、适配协议及 HYMCharts 转换、OC 文档快照和同页 Demo。其他第三方适配器及旧 HMAA 输入 mapper 尚未实现；此批不将正式旧模型迁移 R2 标为完成。

执行方向按“替换老项目 AAChartKit 封装”推进。[旧图表运行 Demo](../Examples/LegacyChartDemo/README.md) 基线与[11 场景对照结果](charts-legacy-demo-parity-results.md)已完成；同输入堆叠/缺测初验通过。[独立 framework 与 Swift/纯 OC 宿主](../Examples/ChartsIntegration/README.md)已通过 Debug/Release，197 个声明见[字段清单](charts-legacy-field-inventory.md)。按[替换实施计划](charts-legacy-replacement-plan.md)优先完善图表本体，G1 常用组合和 G2–G5（柱条阈值、独立轴、图内标注、主体选中）已落地，详见 [2026-10-02 验证记录](charts-presentation-g2-g5-2026-10-02.md)；G1 受限组合已通过[显式正负分链契约](charts-diverging-stacks-guide.md)完成实现与验收，最终 364 单元 + 33 UI 分批全通过，见[任务进度与边界](charts-g1-task-progress-2026-10-02.md)；旧模式保持兼容；正式适配和外围 UIView 继续单列。下方能力实现状态不等于老项目迁移完成。

## 能力与接入范围

| 能力 | 当前状态 | 入口与限制 |
|---|---|---|
| 引擎无关模型与适配层 | 首版轴系模型已实现，2026-10-03 | `ChartSpecification` / `ChartAdapter`；Foundation-only、版本化 JSON、结构化诊断、HYMCharts 与 OC 接入。仅 HYMCharts 后端已交付；其他后端、完整原生能力透传、旧 HMAA mapper 尚未实现，详见[模型指南](charts-neutral-model-guide.md) |
| 雷达图 | 已实现 | Radar/；SwiftUI 与 OCBridge；当前单组维度模型 |
| 热力图 | 已实现 | Heatmap/；SwiftUI 与 OCBridge；支持无效占位格 |
| 复杂堆叠面积过渡 | G1 显式正负分链及旧模式均已实现 | 新 `.diverging`：真实过零、共享正负边界、同组缺测统一断段；混合线型/非面积贡献、自动百分比零分母与整组直线降级均有明确规则。默认独立插值不变，沿基线兼容语义保留。Swift/OC、现有 Demo 与诊断见[新模式指南](charts-diverging-stacks-guide.md)，历史模式见[接缝指南](charts-stacked-area-seams-guide.md) |
| 折线/平滑/阶梯/面积 | 已实现 | LineChartRenderer；支持多系列、空值、正负堆叠 |
| 缺测 autoGap | 已实现，迁移第 3 阶段首个子项 | 按连续空点数或等间隔缺测时长；Line/Combined 线族；默认兼容 connectNulls，不补点 |
| 连续颜色分区 / 曲线负值着色 | 已实现，迁移第 3 阶段 | Line/Combined 线族；X 原始索引 / Y 所属轴绘制值；独立线色与渐变，路径裁剪不补点；复杂堆叠基准接缝另行处理 |
| 折线 Min/Max 降采样 | 已实现，第 7 步 | 非堆叠直线/面积，多系列/双轴/缺测；默认关闭，原始数据命中；曲线/阶梯/堆叠保持原始绘制 |
| 绘制图层/标签复用 | 已实现，第 8 步 | Line/Column/Bar 默认开启；支持开关对照，逐帧回收未用对象；不含图例、tooltip、Radar/Heatmap |
| 固定柱宽与固定间距 | 已实现，第 9 步 | Column/Bar，pt 配置；默认最早、自动类目滚动、区间定位；Column 时间聚合计入完整尺寸预算 |
| 柱/条阈值分区着色 | 已实现，G2 | Column/Bar/Combined；Y raw/draw 或 X 原始索引整段选色，有效 zones 优先，关闭/非法配置保持原配色 |
| 柱状/条形 | 已实现 | ColumnChartRenderer / BarChartRenderer；并排、普通/百分比/固定基准堆叠 |
| 多组分别堆叠 | 已实现，迁移第 2 步 | stackID 按轴/图形族/正负分链；normal/percent/fixed；Column/Bar/Combined 柱槽和总量按组 |
| 刻度/标线/色带 | 已实现，G3/G4 | 主次轴独立样式/显隐、类目间隔；标注文字样式/对齐/偏移/clamp 或 hide；旋转仅垂直图底部类目轴 |
| 双值轴 | 按图形支持 | Line/Column/Combined 支持；Bar 不支持 |
| 缩放/平移/回弹/重置 | 已实现 | HYMChartView；支持屏幕 x/y/xy，惯性仅 X 轴 |
| 双向准线/弹窗文本模板 | 已实现 | isCrosshairDualDirectionEnabled / HYMChartTooltipTextOptions |
| 自定义内容弹窗 | 部分接入 | UIKit 通用容器支持；Radar/Heatmap SwiftUI/OC 支持；四个轴系 SwiftUI 包装未完整透传 |
| 堆叠总量标签 | 已实现，G4 补背景与避让 | Column/Bar/Combined；原值正负分链，双轴独立；可选避开标注、总量优先省略碰撞数据标签 |
| 点/柱/条主体选中视觉 | 已实现，G5 | 四轴系点环/真实柱条覆盖层，单点/共享、重播/更新/取消清理；默认关闭，不含跨更新选点恢复 |
| 更新时保留视口 | 已实现，第 2 步回归通过 | update 默认保留；configure / resetViewport 显式重置；轴系 SwiftUI 默认保留且同步最新回调 |
| 系列稳定 ID、图例与显隐 | 已实现，第 3 步 | 四向布局、符号/颜色覆盖、换行滚动；Line/Column/Bar，默认关闭 |
| 混合图 | 已实现，迁移第 2 步 | CombinedChartRenderer / CombinedChart / OC；柱、线、曲线、面积共轴/图例/命中；不做混合时间聚合 |
| 数值/时间 X、流式追加 | 部分实现 | 等间隔时间标签和区间元数据已接入；X 仍为原始索引，不等间隔/真实数值 X/流式追加待实现 |
| 高密度 Column 时间聚合 | 已实现第一版 | 按宽度/可见系列数分桶；每系列 reducer、区间 tooltip、总览/明细定位 |
| 轴系命中数据语义 | 已实现，迁移第 1 步 | raw/aggregated/draw/base/percentage 与源范围统一；旧 value 兼容，Tooltip 显示原值/统计值 |
| 业务组与每系列格式 | 已实现基础，迁移第 1/4 步 | 稳定组 ID/名称、每系列格式、分组、小计、图标/名称数值分栏、逐点隐藏/改名/仅名称、超高滚动、逐系列前值/索引偏移与固定顶部；生命周期待后续 |
| SDK 独立分发 | 最小 framework 验收完成，正式发布待接入 | Swift/纯 OC Debug/Release 宿主与设备构建通过；尚未发布 SPM/CocoaPods/XCFramework，完整旧字段透传待补 |

## 第 1 步：总量标签收尾

状态：完成（2026-09-24）。在原有未提交的 Theme、Demo、Renderer、自检基础上继续完成。

- 新增 CartesianStackTotalLabels：按轴、类目、正负号累计原值，统一链端标签布局。
- 修复小段小于半个像素时漏计；不等长系列不再访问补齐位置对应的不存在原值。
- 系列标签使用独立 layer，每帧替换，避免入场动画累积标签。
- 链端超出视口时隐藏总量，边缘文字保持在绘图区内；过长文字放不下时跳过。
- 可见链端数量包含双轴，超过 dataLabelMaxMarkCount 时隐藏；缩放后恢复。
- 修复相关底层问题：百分比归一化遇到 NaN/Infinity 不再清掉其他有效贡献；Column 固定基准堆叠使用正确的段基线；Bar 类目位置随 Y 视口正确映射。
- 补充使用指南，并纠正旧指南对多系列、百分比堆叠和手势能力的过时描述。

当时限制：未做总量标签之间的碰撞排布。2026-10-02 的 G4 已新增可选 `dataLabelAvoidsOverlap`（默认 false）和标签背景；总量仍共用数据标签颜色/字号，采用确定性省略而非全局排版。

## 第 1 步验证记录

- Xcode 26.3，iPhone 17 / iOS 26.3 Simulator，Debug。
- 新增 `SwiftFunctionProjectTests/StackTotalLabelTests.swift`：10 个独立 XCTest 全部通过。
- 覆盖：小段合计、动画替换、裁剪链端、正负与三种堆叠、双轴限量、全零/非堆叠、不等长与非有限值、百分比分母、缩放恢复、标题/轴区域避让。
- 现有 XCTest 同时通过：ChartSelfTest、Bar 轴系、准线点击、回弹，以及两个原有模板测试；本轮共 16 个测试成功。
- 修复前新增回归中，小值、动画累积、裁剪边界三个测试失败；修复后转绿。
- 未进行手工模拟器视觉验收、真机性能测量或 Release 性能基准；模板 performance 测试不作为性能结论。

路线图见 [现状核对与后续路线图](2026-09-24-charts-status-and-roadmap.md)，API 示例见 [柱状图与条形图指南](charts-column-guide.md)。

## 第 2 步：数据/样式更新保留视口与回调同步

状态：完成（2026-09-24）。

- 新增 `update(model:theme:viewportPolicy:)`、只更新 model/theme 的重载，以及 `resetViewport()`。
- `.preserve` 保留用户的数值窗口，并按新数据域与缩放下限收回；未缩放时继续显示全量。
- `.reset` 和原有 `configure` 恢复全量；主轴、次轴在新模型 render 时一起应用策略。
- 数据缩短后不再遗留域外窗口，后续增加数据也不会恢复更早的无效窗口；清空数据、删除次轴后清理旧窗口。
- Line/Column/Bar 的 SwiftUI 包装默认保留视口，并刷新/移除 `onHit` 闭包；可显式传 `viewportUpdatePolicy: .reset`。
- 更新停止旧入场动画、惯性和回弹，清除旧选择/准线/弹窗；外部位置弹窗收到一次失效通知。更新后立即点击也使用最新模型。

边界：本步不跨更新保留选中目标，不提供自动跟随最新数据，类目窗口仍按数组索引保持；仍为整体重绘。系列/数据身份与选择恢复属于下一步。示例和完整语义见 [更新指南](charts-update-guide.md)。

### 第 2 步验证记录

- Xcode 26.3，iPhone 17 / iOS 26.3.1 Simulator，Debug。
- `ChartUpdateTests` 新增 15 项全部通过；含真实 `UIHostingController` 更新时的视图复用、窗口保持、回调替换/移除与显式重置。
- 同时运行现有测试，全量单元测试共 **31 项通过，0 失败**（其中两个为原有模板测试）。
- 首轮复现三个 SwiftUI 组件调用旧闭包的问题，修复后转绿。中间一项窗口预期调整为遵守新数据量对应的最小缩放跨度，最终回归通过。
- `git diff --check` 通过。未进行真机、手工视觉或性能基准验证。
- 最终测试结果：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_13-53-41-+0800.xcresult`（临时构建产物）。

## 第 3 步：内置图例、稳定系列 ID 与显隐

状态：完成（2026-09-24）。用法见 [图例指南](charts-legend-guide.md)。

- 系列新增稳定 `id`、`isVisible`、`showsInLegend`、`legendOrder`，命中目标提供 `seriesID`，原始系列索引不压缩。
- 主题新增 `legend`：四个位置、行对齐、字体/间距/符号尺寸、按 ID 覆盖名称/颜色/形状；默认跟随系列的颜色、折线虚线和 marker。
- 先测量再分配空间；上下换行、左右单列；限定高度内滚动，优先保留最小绘图区。外部高度包含图例。
- 点击/公开 API 切换显隐，重算值域、正负堆叠、百分比分母及总量标签，清理旧选择/准线/弹窗。隐藏项继续保留；全隐藏后可恢复。
- SwiftUI 三组件透传并同步最新显隐回调，稳定 ID 保持本地状态；显式模型状态变化优先，删除 ID 清理旧状态。
- 修复 Column/Bar 堆叠命中与弹窗锚点未采用分段基线的问题；吸附改用累计绘制位置；固定基准百分比也按堆叠处理。
- 当时新增首页“图例 → 内置图例与布局”演示；第 5 步已并入各图表统一面板。

验证：新增 16 项 XCTest，全量 **47 项通过，0 失败**；四向柱状图渲染截图已检查，标题、坐标轴和图例不重叠。未进行真机触摸、VoiceOver 人工验收或性能基准。截图为测试渲染附件，不等同于真实手势验收。

最终测试结果：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_14-23-01-+0800.xcresult`；日志 `/tmp/hymcharts-step3-final.log`。

当时边界：不支持自动总高度、自定义 View/图片图例、单点图例或 Radar/Heatmap 图例。后续已接入图片/自定义符号，以及原值与绘制值分离；显隐仍不代表跨更新恢复选择。

下一步：统一命中数据的 rawValue / 累计绘制值 / percentage 字段，并实现主体选中反馈，再进入跨更新选择恢复和混合图。


## 图例测量补充与高密度数据设计（2026-09-24）

- 新增公开静态类方法 `ChartLegendMeasurer.measure(model:theme:availableWidth:)`，与 renderer 共用排版引擎；返回完整内容尺寸、实际预留尺寸、行数、是否滚动和追加高度/宽度。
- 新增 `legend.overflow = .expand`，支持外部先测量再设总高度；默认 `.scroll` 保留旧行为。演示页增加测量和自动追加高度开关。
- 新增 6 项测量 XCTest，全量 **53 项通过，0 失败**；确认按测量值增加上下图例高度后，原绘图区高度不变，并覆盖字体/宽度/名称变化、空图例、展开模式、侧边宽度和小容器保护。
- 测试产物：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_14-34-08-+0800.xcresult`，日志 `/tmp/hymcharts-legend-measure.log`。`git diff --check` 通过。
- 用户确认高密度场景需要每系列独立聚合配置。已整理 [高密度时间序列方案](charts-density-design.md)，当时自动聚合和降采样尚未实现；Column 聚合的后续实施记录见下节。


## 第 4 步：高密度 Column 自动时间聚合与区间明细

状态：完成第一版（2026-09-24）。接入见 [时间聚合指南](charts-time-grouping-guide.md)。

- 新增等间隔 `CartesianTimeAxis`、`CartesianTimeGrouping`、每系列 `CartesianAggregation` 与单位。支持 sum/average/min/max/last/custom；共用区间边界，缺测不按 0 处理。
- 按实际绘图区宽度、柱体样式及可见系列数选择时间档位；保留原始索引坐标，桶首承载绘制数据，桶宽按实际采样数计算。放大恢复细粒度，源模型不变。
- 新增 `CartesianTimeBucket`，包含原始范围、区间时间、有效采样数、覆盖率、统计值及 min/max。逐柱/共享/吸附命中与 tooltip 接通；部分可见桶的准线不越出绘图区。
- UIKit `showCategoryRange` 和 SwiftUI Column `visibleCategoryRange` 支持初始/主动定位明细、恢复总览。修复 onHit 内更新窗口后旧弹窗/准线继续显示的问题。
- Line/Column/Bar 绘制、动画和命中复用渲染时预计算的累计值/基准值，移除逐柱的全数组归一化。时间标签在一次渲染内复用；跨天显示日期，省略容器边界外的长时间标签。
- 当时新增“高密度时间序列（288–3000 点）”演示（第 5 步已并入柱状图面板），包含 1/3/6 系列、求和/平均与双轴、图例显隐、全天/最近 24 点/所选区间。

验证：新增 `TimeGroupingTests` 19 项，连同既有 53 项，共 **72 项通过**。覆盖守恒、不同 reducer、空缺/短数组、尾桶、百分比、回退、宽度/显隐/缩放、命中、SwiftUI 命令与截图；检查了 3000 点总览和局部明细渲染。

性能记录：[24 组模拟器布局耗时](benchmarks/2026-09-24-column-layout-simulator.csv)。这是 Debug 单次 UIView 创建到 layout 的观测，测试为普通堆叠，非真机帧率/内存基准。原始/聚合两种模式都已包含本步重复计算修复，不能作为修改前后的完整速度对比。

边界：仅 Column 自动聚合；必须有合法等间隔时间轴，所有可见系列须显式选择 reducer。固定基准百分比回退原始数据；grouped 已在迁移第 2 步接入。不等间隔、时间加权平均、累计表复位、正负拆桶、日历整点对齐仍待实现（手势缓存已在第 6 步接入；非堆叠直线降采样见第 7 步）。

第 4 步结束时的计划：跨渲染缓存和粒度切换缓冲（现已在第 6 步接入）、真机手势/内存基准；随后折线 Min/Max 降采样。统一全部命中值字段、主体选中反馈和混合图仍在路线图内。

最终测试产物：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_15-05-31-+0800.xcresult`；日志 `/tmp/hymcharts-density-verified.log`。

## 第 5 步：统一 Demo 与实时属性面板

状态：已合并首页入口。雷达、热力、折线、柱状、条形各保留一个页面；Objective-C 接入示例保留。图例与高密度演示并入对应页面，原有重复 Demo 已删除。

- 面板支持分组折叠、按属性名/组名搜索、可选值恢复默认、透明度、字体、布局与数据调整。
- 轴系图按稳定 ID 保存独立系列配置：名称、数据覆盖、显隐、配色、标记、值轴、图例覆盖与统计规则。
- 雷达新增逐维度数据及样式编辑；热力新增逐格数据、缺测、色阶、锯齿行、标签和主题编辑。
- 修复 HeatmapChart SwiftUI 入口强制覆盖传入主题的问题，以及 `.none` 色阶未使用 `baseColor` 的问题。
- 数值格式化、聚合、自定义弹窗和位置回调提供命名预设。后续每个新增配置必须在同一变更中同步 Demo 面板与文档，见 [调试页面指南](charts-demo-guide.md)。

## 第 6 步：手势数据缓存与粒度切换缓冲

状态：已接入。配置见 [时间聚合指南](charts-time-grouping-guide.md)。

- 将宽度/粒度计划与实际 reducer 执行分开；renderer 按最终粒度缓存聚合模型、堆叠累计值/基准值、主次轴值域，并复用时间标签。
- 每个 renderer 最多保留三个最近使用的粒度；外部 render、数据/样式更新、图例显隐更新与容器重新布局保守失效，避免闭包捕获状态或数据变化产生旧结果。
- `CartesianTimeGrouping.isCacheEnabled` 默认 true，可关闭作对照；`granularityHysteresis` 默认 0.15，放大时预留宽度再细化，缩小时宽度不足立即合并。
- 两个新选项已同步到柱状图“高密度时间聚合”面板。缓存关闭时，数值和命中映射保持一致。
- 根据 Demo 截图优化了条形图默认数据密度和时间轴文字间距。

性能观测见 [模拟器平移缓存对照](benchmarks/2026-09-24-column-pan-cache-simulator.csv)。3000 点、6 系列、连续 30 次 renderer 平移调用；不包含初始布局，Debug、单次观测。统计 CPU 同步调用耗时，非 GPU 呈现时间/触控 FPS/真机内存基准。

仍待完成：真机手势与峰值内存验证、跨 update 的精细失效（图层/标签复用已在第 8 步接入）（非堆叠直线 Min/Max 已在第 7 步接入）。不等间隔时间、Bar 自动聚合与混合图继续按路线图推进。

最终验证（2026-09-24）：**84 项单元测试 + 2 项界面测试全部通过**。本次新增 3 项 Demo 配置/主题测试、8 项缓存/缓冲/对照测试、1 项时间标签间距回归；界面测试遍历五类页面并切换真实属性，覆盖 3000 点预设、总览/明细与恢复默认。已检查五类实时属性截图及密集柱状图总览/明细截图。

本次最终模拟器平移对照：关闭缓存约 412 ms，开启约 138 ms（30 次调用的总 CPU 时间；仅此配置的单次观测）。原始 CSV 包含缓存命中/未命中数。

最终产物：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_15-53-18-+0800.xcresult`；日志 `/tmp/hymcharts-demo-cache-complete.log`，导出截图 `/tmp/hymcharts-demo-complete-evidence/`。`git diff --check` 通过。


## 第 7 步：折线 Min/Max 绘制降采样

状态：完成首版（2026-09-24）。接入见 [折线降采样指南](charts-line-sampling-guide.md)。

- 新增可选 `CartesianChartTheme.lineSampling` / `LineChartSampling`，配置分组宽度、可见点启用门槛、密集 marker/标签策略，默认关闭。
- 每个有效连续段、每个固定索引分组保留首尾/min/max 原始索引并按原序连接；保留缺测分段、跨空值策略及视口边缘邻点。单点缺测段保留 marker，避免密集模式把孤立点全部隐藏。
- 多系列独立选择，原始模型和轴值域不变。使用原始点坐标按触点容差搜索命中，省略点仍有逐点/吸附/共享 tooltip 和命中位置。
- 放大到稀疏视口恢复原始点。仅直线和非堆叠面积图启用；平滑、阶梯、堆叠保持原始绘制，Demo 显示该状态。
- 所有新增参数与 3000 点尖峰/低谷样本、尖峰附近 24 点明细按钮已同步到折线图统一面板，无新增同类页面。

验证：新增 **15 项单元测试 + 1 项界面测试**；全量 **99 项单元测试、3 项界面测试通过**。检查总览与尖峰明细截图，验证极值/顺序/端点、缺测/孤立点、双轴/短数组/显隐、原始命中、配置绑定、回退与更新。

[布局性能对照](benchmarks/2026-09-24-line-minmax-layout-simulator.csv)：每系列 3000 点、两个系列，路径点从 6000 降到 692。保留采样 marker 时系列图层 694 个；隐藏密集 marker 时 2 个，原始模式为 6002 个。本次 Debug 模拟器单次初始布局约 23.4 / 15.8 / 14.4 ms（原始 / 采样保留 marker / 采样隐藏 marker），不代表真机 FPS 或 GPU/内存指标。

边界：仍扫描原始有效段，尚无多层采样索引缓存；大量缺测段会削弱点数压缩比例。近似路径保留组内极值，但不保证保留所有高频振荡/过零时刻。下一步优先完善可复用绘制层/标签和真机分析，再扩展曲线/阶梯/堆叠采样与命中主体高亮。

测试产物：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_16-24-55-+0800.xcresult`；日志 `/tmp/hymcharts-line-sampling-final.log`；截图 `/tmp/hymcharts-line-sampling-evidence/`。`git diff --check` 通过。


## 第 8 步：绘制图层与标签复用

前置：已将前 7 步累计成果提交为 `3e8571d`（本地提交）。

- 新增渲染器独占对象池，公共装饰与系列绘制独立；复用轴/网格、标题/刻度、标线/色带、线/柱/条形、渐变/mask、阴影与文字。
- 逐帧释放未使用对象，卸载清理；Column/Bar 入场动画复用系列标签和总量标签。
- 重置可变样式及旋转，避免关闭虚线/边框/阴影或切换形状后残留。空数据继续调用子类清理，修复旧 series 图层/命中缓存未清空的问题。
- 新增 `CartesianChartTheme.reusesRenderingObjects`，默认 true；在三个统一 Demo 的主题面板实时切换。
- 仍重建 path 并重新挂载图层；几何缓存、局部更新、真机性能分析尚未完成。接入与验证范围见 [复用指南](charts-rendering-reuse-guide.md)。


验证：新增 8 项单元测试、1 项界面测试；完整 107 项单元测试与 4 项界面测试通过。三个 Demo 的复用开关与图表截图已检查；开启/关闭复用跨样式、空数据、显隐更新的图片一致。原始 3000 点 × 2 系列、12 次布局的池内创建数 72,252 → 0；平均 CPU 布局约 26.94 → 25.28 ms。启用 Min/Max 后约 14.67 → 13.74 ms。仅 Debug 模拟器单次观测，详见 [原始 CSV](benchmarks/2026-09-24-render-object-reuse-simulator.csv)。

最终单元测试：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_16-53-11-+0800.xcresult`。界面测试：`Test-SwiftFunctionProject-2026.09.24_16-47-35-+0800.xcresult` 中 4 项 UI 测试通过；该批次曾有 1 项对象释放时机断言失败，补充事务提交/autoreleasepool 后在最终单元测试中通过。UI 截图：`/tmp/hymcharts-reuse-evidence/`。日志 `/tmp/hymcharts-reuse-optimized.log`。


## 第 9 步：固定尺寸与默认最早滚动窗口

按用户要求新增 `CartesianColumnSpacing(columnWidth:inner:group:)`，设置到 `theme.columnSpacing`，覆盖旧比例布局。固定柱宽后自动启用类目滚动，默认最早；现有 `showCategoryRange` 定位指定区间起点，可见跨度按实际空间决定。Column 横向、Bar 纵向；更新保留位置，重置返回最早。

- 间距与柱宽在拖动、视口/尺寸更新后保持 pt 值，隐藏系列和堆叠重新计算容量。
- 时间聚合按完整固定尺寸预算分桶，末尾短桶仅扩展几何占位，真实原始数据和命中区间不补点。
- Bar 按 Y 类目窗口裁剪条形、标签与网格，避免滚动后仍创建全量可视对象。
- 两个 Demo 同步固定尺寸控件、60 点 × 3 系列滚动预设、起止索引与定位按钮；不生效的比例控件隐藏。
- 详细语义和只固定间距时空间不足的处理见 [固定布局指南](charts-fixed-column-layout-guide.md)。


验证：新增 12 项单元测试、1 项界面测试；最终 119 项单元测试与 5 项 Demo 界面测试通过。截图检查发现并修复 Bar 滚动后视口外刻度/网格越界，针对性界面复测通过。固定尺寸、间距、默认最早、手动起点、重置、更新、容器尺寸变化、隐藏系列、堆叠、短末桶命中元数据及旧比例模式回退均有覆盖。

最终单元与滚动界面复测：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_17-20-46-+0800.xcresult`。完整 5 项界面测试：`Test-SwiftFunctionProject-2026.09.24_17-15-54-+0800.xcresult`。日志 `/tmp/hymcharts-fixed-layout-boundary.log`；修复后截图 `/tmp/hymcharts-fixed-layout-boundary-evidence/`。`git diff --check` 通过。


## 旧模块迁移第 1 步：数据语义、分组与格式、最小 OC 接入

- Line/Column/Bar 逐点、吸附、共享命中统一提供 CartesianDatum：原值、聚合统计、绘制终点、堆叠起点、有符号百分比、源索引范围与聚合元数据。旧 value 保持兼容；内置 Tooltip 使用 displayValue，修正堆叠值误作原值的问题。
- 新增业务组 ID/名称，不改变数学堆叠或自动跨单位求和；格式支持每系列单位、k/M/G、绝对值展示、货币、截断/舍入、精度和 Locale。
- 新增轴系最小 NSObject/UIView OC facade；包含数据转换、配置校验、更新、窗口与显隐命令、语义快照回调。混合图后续已在第 2 步接入；旧 API 适配/独立分发仍待后续。
- 同步三个轴系 Demo 属性面板与命中读数；Objective-C 接入页增加单个轴系验证入口。
- 参考目录排除 App target，避免依赖老项目宏与 vendor 代码的参考资料混入新库构建。

用法与边界见 [数据语义与 OC 接入指南](charts-data-semantics-guide.md)。

验证：新增 13 项数据语义/OC XCTest。首轮平均值精度断言调整为容差后，全量 131 项单元 + 7 项 Demo UI 通过；最终兼容性补充后 **132 项单元 + 2 项新增 UI 复查全部通过**。检查了单点 100+50 堆叠截图及三种 OC 图表截图，原值与绘制终点正确分离。`git diff --check` 通过，未做真机或老项目集成验收。

- 全量 UI 结果：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_18-05-54-+0800.xcresult`。
- 最终复查：`/tmp/hymcharts-step1-build/Logs/Test/Test-SwiftFunctionProject-2026.09.24_18-09-34-+0800.xcresult`。
- 最终截图：`/tmp/hymcharts-semantics-evidence-final/`（临时产物）。


## 旧模块迁移第 2 步：混合图与分组堆叠

- 新增 CombinedChartRenderer 与 SwiftUI/OC 入口；沿用 Column/Line 绘制 pass，共用一套轴、图例和命中上下文。
- series.kind、stackID、participatesInStack、CartesianSeriesStyle 支持独立图形/连线/标记/填充；业务 groupID 与数学 stackID 分离。
- 分组堆叠同步修正百分比分母、值域、柱槽、固定尺寸预算、组总量、圆角/分隔线和命中；隐藏整组释放槽位。
- 首页只新增一个混合图调试页；其他轴系页同步新属性，OC 页面增加混合类型。
- 使用方式、继承规则及时间聚合边界见 [混合图与分组堆叠指南](charts-combined-and-stacks-guide.md)。

验证：新增 18 项混合图/分组/样式 XCTest，最终 **150 项单元测试全部通过**。完整 **8 项 Demo UI 回归通过**；接缝修正后再次通过混合图与 OC 的 2 项 UI 测试。已检查双组柱 + 双轴曲线、柱/线/面积混合和 OC shared tooltip 截图。最终结果：`Test-SwiftFunctionProject-2026.09.24_18-41-02-+0800.xcresult`；完整 UI 结果：`Test-SwiftFunctionProject-2026.09.24_18-34-56-+0800.xcresult`。`git diff --check` 通过；未提交代码，未做老项目接入或真机性能验收。

仍有边界：混合图时间聚合未启用；缺测/换符号导致面积一段内基准切换时的复杂接缝，以及曲线负值颜色，在迁移第 3 步处理。


## 旧模块迁移第 3 阶段（部分）：缺测连接策略（2026-09-29）

- 新增 `CartesianGapPolicy`：全部断开/连接、按空点数、按等间隔缺测时长；系列可独立配置，nil 保留 `connectNulls`。
- 明确包含上限：设为 11 时，11 个空点连接，12/13 个断开；时间模式按缺失采样槽数 × 采样间隔计算。
- 原始索引先分段再降采样；路径、面积、命中及数学数据分离，不填补业务数据。
- OC 新增可选策略包装及等间隔时间轴配置；折线/混合 Demo 具备真实绑定和 11/12/13 预设。
- 本节记录缺测子项；同日后续已完成 X/Y zones 和曲线负值颜色，见下节。同日后续已修复堆叠面积共享边界的路径复用，剩余过渡区间限制见 [接缝指南](charts-stacked-area-seams-guide.md)。

使用与边界见 [autoGap 指南](charts-gap-policy-guide.md)。


验证（2026-09-29）：iPhone 15 Pro / iOS 17.2 模拟器上，新增 **15 项缺测策略单元测试**及 **1 项覆盖折线/混合两页的 UI 测试**；最终 **165 项单元测试 + 9 项 Demo UI 测试全部通过**。已检查两页截图，11 个空点跨缺测连接并闭合面积，12/13 个空点保持断开，未创建中间采样点。`git diff --check` 通过；未做真机或老项目集成验收。

- 测试结果：`/tmp/SwiftFunctionProject-autoGap-regression-20260929.xcresult`。
- 测试日志：`/tmp/SwiftFunctionProject-autoGap-regression-20260929.log`。
- UI 截图：`/tmp/SwiftFunctionProject-autoGap-evidence-20260929/`（临时产物）。


## 旧模块迁移第 3 阶段：X/Y 颜色分区与曲线负值着色（2026-09-29）

- 新增逐系列 `CartesianColorZones`：半开区间、严格阈值校验、独立线色/面积渐变，默认关闭；有效显式分区优先于 `negativeColor`。
- 完整路径按可见轴向区间裁剪，支持平滑/阶梯、缺测与原始索引采样；保持曲率、虚线相位、入场动画进度及命中数据不变。
- 负值换色覆盖平滑曲线，修正原正/负路径拆分对全负值面积的影响；未指定填充分区时继承旧渐变。
- 图层池同步支持分区容器生命周期；OC 快照、逐系列 Demo 控件与三个预设同步接入。
- 本次完成颜色子项；同日后续已修复可共享堆叠面积边界的切线/样式不一致；无共同前层路径的过渡区间仍不保证全域无缝，见 [接缝指南](charts-stacked-area-seams-guide.md)。未做真机性能或老项目集成验收。

用法、边界和性能取舍见 [颜色分区指南](charts-color-zones-guide.md)。


验证（2026-09-29，iPhone 15 Pro / iOS 17.2 模拟器）：新增 **20 项颜色分区单元测试**和 **1 项覆盖折线/混合两页的 UI 测试**。本轮全量执行的 **185 项单元测试、9 项既有 Demo UI 测试全部通过**；新增 UI 用例首次因搜索框输入定位失败，改用短关键词后单独复测通过，合计 **10 项 Demo UI 用例均已通过验证**。已逐张核查 6 张 X/Y 分区及曲线负值预设截图，颜色变化不改变曲线形状，缺测保持断开。生成的 Swift→Objective-C 头文件通过独立 Objective-C 语法编译检查。`git diff --check` 通过；未做真机或老项目集成验收。

- 单元测试及既有 UI 回归：`/tmp/SwiftFunctionProject-zones-final-20260929.xcresult`（该次总结果含上述已修正的新增 UI 输入失败）；同名 `.log` 可查 185 项单元测试结果。
- 新增 UI 修正后复测：`/tmp/SwiftFunctionProject-zones-ui-recheck-20260929.xcresult`（成功）；同名 `.log`。
- 6 张 UI 截图：`/tmp/SwiftFunctionProject-zones-evidence-20260929/`（临时产物）。


## 2026-09-29：折线目标点数采样

- `LineChartSampling.targetPointCount` 可选，默认 nil 保持原宽度模式；非 nil 时按每系列当前视口预算选点，优先于宽度与启动门槛。
- 数量为 `min(候选点数, max(必保点数, max(2, 目标)))`，候选包含边缘邻点；每段首尾/最低/最高点优先，保护点超额时明确提示，不补点、不错误连接缺测。
- Demo 增加整数输入、目标 200 的 3000 点预设和逐系列实际绘制数；两种模式的互斥在面板上直接说明。
- 不扩展平滑、阶梯、堆叠的采样范围，不改变模型、值域或命中的原始值。详情见 [降采样指南](charts-line-sampling-guide.md)。

## 2026-09-30：迁移第 4 阶段基础展示能力

- 新增内置文本 Tooltip 按业务组排列、零值/系列过滤，以及可选的同单位/值轴/格式原始值小计。默认保持平铺，小计不汇总聚合值、累计终点或百分比。
- 图例新增图片、隐藏态图片、自定义符号视图、背景/圆角和相邻业务组变化换行；复用公开测量引擎与系列显隐事件。
- SwiftUI、OC 桥接、四个轴系 Demo 和使用文档同步。原宽度降采样仍为默认可选模式。
- 此条记录基础能力交付；同日后续的富内容和前值/置顶提示见下节；生命周期、分组图例标题、整行模板仍待后续。见 [使用指南](charts-grouped-presentation-guide.md)。

验证：完整 **234 项单元测试 + 17 项 Demo UI 测试通过**，新增分组展示 10 项单元测试与 1 项跨四页面 UI 测试。绑定清单 241 项 / 2,597 次读写，场景切换 169 组，渲染矩阵 750 组。并修复超出 Int 范围的有限值显示崩溃。截图、边界和结果包见 [分组展示验证](charts-grouped-presentation-guide.md#2026-09-30-验证结果)。补齐中英文 README，Swift 示例通过类型检查。

收尾改动后复测全部 234 项单元测试及 2 项相关 UI 测试，均通过；最终结果包：`/tmp/SwiftFunctionProject-presentation-final-20260930.xcresult`。本轮代码与文档保留在工作区，未提交或推送。


## 2026-09-30：迁移第 4 阶段富内容提示

- 新增 `CartesianTooltipContent` 展示快照及 `CartesianTooltipPresentation`：复用分组/格式/过滤/小计语义；支持图标、名称/数值分栏、逐点改名/隐藏/仅名称。
- 仅名称行不参与小计；聚合保留源范围和区间信息。长名称换行、窄宽度上下排版，超高提示内部滚动，图表手势不抢占。
- UIKit、四轴系 SwiftUI、OC、单点/吸附/共享提示全部接入；新增 Demo 命名预设与 7 个面板字段。Radar/Heatmap 继续使用各自的弹窗面板。
- 默认保持文本布局。修复旧淡出完成回调误隐藏新提示的竞态。详见[富内容提示指南](charts-rich-tooltip-guide.md)。

验证：243 项单元测试与 4 项相关 UI 测试通过；新增富内容单测 9 项，四轴系滚动 UI 1 项。当前清单为 248 项控件、2,685 次绑定读写、196 组场景切换；Swift 示例类型检查及本地链接检查通过。结果包与精确范围见[富内容提示验证](charts-rich-tooltip-guide.md#2026-09-30-验证记录)。


## 2026-09-30：迁移第 4 阶段前值与固定顶部

- 新增 `CartesianTooltipSampleSelection`：全局/逐系列原始索引偏移、omit/clamp/current 首尾策略、可本地化来源标签；缺测不搜索更早有效值，实际时间聚合保留当前桶。
- 行分别提供命中 `datum` 和取值 `displayedDatum`；表头、准线与 raw/draw/base/percentage 回调仍为当前命中。过滤/小计依据展示值，不合计不同来源范围。
- 通用主题新增 automatic/fixedTop、屏幕 offset 与顶部间距；固定顶部隐藏箭头，约束宽高并在 bounds 改变时重测，columns 保持超高滚动。
- 四轴系 SwiftUI、OC 和现有 Demo 同步，新增前值与置顶预设及 9 个面板字段。生命周期/外部表头联动和图例整行模板仍未交付。

验证：最终 **256 项单元 + 1 项遍历四页面的新 UI 通过**；既有富内容/滚动和弹窗模式 2 项 UI 在前一轮通过。新增单测 13 项。当前清单 257 项 / 2,793 次读写 / 225 组场景切换 / 750 组渲染矩阵，Swift 示例、链接与空白检查通过。截图和各结果包的准确范围见[前值与置顶验证](charts-tooltip-selection-guide.md#2026-09-30-验证记录)。代码与文档保留在工作区，未提交或推送。
