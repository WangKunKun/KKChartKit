# HYMCharts 当前能力清单

更新：2026-09-24。以当前工作区源码为准；历史 specs/plans 记录设计过程，不代表当前待办。

## 能力与接入范围

| 能力 | 当前状态 | 入口与限制 |
|---|---|---|
| 雷达图 | 已实现 | Radar/；SwiftUI 与 OCBridge；当前单组维度模型 |
| 热力图 | 已实现 | Heatmap/；SwiftUI 与 OCBridge；支持无效占位格 |
| 折线/平滑/阶梯/面积 | 已实现 | LineChartRenderer；支持多系列、空值、正负堆叠 |
| 折线 Min/Max 降采样 | 已实现，第 7 步 | 非堆叠直线/面积，多系列/双轴/缺测；默认关闭，原始数据命中；曲线/阶梯/堆叠保持原始绘制 |
| 柱状/条形 | 已实现 | ColumnChartRenderer / BarChartRenderer；并排、普通/百分比/固定基准堆叠 |
| 多组分别堆叠 | 未实现 | StackConfig.grouped 仍是预留，并排多系列不是分组堆叠 |
| 刻度/标线/色带 | 已实现 | Cartesian 层；标签旋转仅垂直图底部类目轴生效 |
| 双值轴 | 部分实现 | Line/Column 支持；Bar 不支持 |
| 缩放/平移/回弹/重置 | 已实现 | HYMChartView；支持屏幕 x/y/xy，惯性仅 X 轴 |
| 双向准线/弹窗文本模板 | 已实现 | isCrosshairDualDirectionEnabled / HYMChartTooltipTextOptions |
| 自定义内容弹窗 | 部分接入 | UIKit 通用容器支持；Radar/Heatmap SwiftUI/OC 支持；三个轴系 SwiftUI 包装未完整透传 |
| 堆叠总量标签 | 已实现，本次回归通过 | Column/Bar；原值正负分链，Column 双轴独立；详见下节 |
| 点/柱主体选中视觉 | 待实现 | 轴系已有命中/准线；Radar/Heatmap 已有主体选中反馈 |
| 更新时保留视口 | 已实现，第 2 步回归通过 | update 默认保留；configure / resetViewport 显式重置；轴系 SwiftUI 默认保留且同步最新回调 |
| 系列稳定 ID、图例与显隐 | 已实现，第 3 步 | 四向布局、符号/颜色覆盖、换行滚动；Line/Column/Bar，默认关闭 |
| 混合图 | 待实现 | 首个目标为柱 + 线 + 双轴 + shared tooltip |
| 数值/时间 X、流式追加 | 部分实现 | 等间隔时间标签和区间元数据已接入；X 仍为原始索引，不等间隔/真实数值 X/流式追加待实现 |
| 高密度 Column 时间聚合 | 已实现第一版 | 按宽度/可见系列数分桶；每系列 reducer、区间 tooltip、总览/明细定位 |
| SDK 独立分发 | 待实现 | 当前为 App 工程，尚未独立 SPM 库；Cartesian OCBridge 未补齐 |

## 第 1 步：总量标签收尾

状态：完成（2026-09-24）。在原有未提交的 Theme、Demo、Renderer、自检基础上继续完成。

- 新增 CartesianStackTotalLabels：按轴、类目、正负号累计原值，统一链端标签布局。
- 修复小段小于半个像素时漏计；不等长系列不再访问补齐位置对应的不存在原值。
- 系列标签使用独立 layer，每帧替换，避免入场动画累积标签。
- 链端超出视口时隐藏总量，边缘文字保持在绘图区内；过长文字放不下时跳过。
- 可见链端数量包含双轴，超过 dataLabelMaxMarkCount 时隐藏；缩放后恢复。
- 修复相关底层问题：百分比归一化遇到 NaN/Infinity 不再清掉其他有效贡献；Column 固定基准堆叠使用正确的段基线；Bar 类目位置随 Y 视口正确映射。
- 补充使用指南，并纠正旧指南对多系列、百分比堆叠和手势能力的过时描述。

限制：不做总量标签之间的碰撞排布，双轴同位置或密集类目可能重叠。标签颜色/字号复用现有数据标签配置；不新增独立样式 API。

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

边界：本版不支持自动总高度、自定义 View/任意图片图例、单点图例或 Radar/Heatmap 图例；保留旧 target.identifier 和逐点累计值语义。显隐不代表跨更新恢复选择。

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

边界：仅 Column 自动聚合；必须有合法等间隔时间轴，所有可见系列须显式选择 reducer。固定基准百分比与 grouped 堆叠回退原始数据。不等间隔、时间加权平均、累计表复位、正负拆桶、日历整点对齐仍待实现（手势缓存已在第 6 步接入；非堆叠直线降采样见第 7 步）。

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

仍待完成：真机手势与峰值内存验证、图层/标签复用、跨 update 的精细失效（非堆叠直线 Min/Max 已在第 7 步接入）。不等间隔时间、Bar 自动聚合与混合图继续按路线图推进。

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
