# 旧图表 Demo 与 HYMCharts 对照结果

更新：2026-10-02（G2–G5 已交付；旧 AA 运行仍引用原批次）。目标是替换老项目基于 AAChartKit 的封装，保留正确的数据和页面行为，并修正已复现的旧问题。

**当前先完善图表本体的展现形式；完整旧模块替换作为后续目标。** 按用户最新要求，统计表头、卡片、日出日落、空态装饰和全屏容器后续在图表 view 外组合，不作为本阶段前置条件。已有直线/平滑/阶梯、基础面积/堆叠和混合图继续复用，重点补绘制缺失与不完整组合。

2026-09-30 基础批次新增[独立 Swift/OC 接入与共享输入证据](#7-基础接入批次独立产物与共享输入)：Debug/Release 各 2 项宿主测试、6 项原生对照、1 项旧 Demo UI 通过；设备 arm64 Release 构建通过。以下旧轮次记录保留原执行范围。

## 1. 证据范围

| 证据 | 能说明什么 | 边界 |
| --- | --- | --- |
| [旧 Demo](../Examples/LegacyChartDemo/README.md) 全部 11 项 UI、30 张图与 15 份 JSON | 原有 7 项覆盖 11 个默认场景、图例/刷新/空态、密集/全屏及 JS 探针；仍确认为 Highcharts 11.4.3 | 主题切换未断言实际颜色；使用示例业务资源，默认场景通过不表示完整分支覆盖 |
| 其中新增 4 项旧审计 UI | 面积/混合分链、拆分边界、同模型空态、默认窗口全屏往返、功率页两版原生提示实际持触采样 | 尚未验用户缩放/显隐/选择同时恢复；原生提示采样限三组功率页；拆分异常来自直接调用原 helper |
| 历史 HYM 258 项完整单元回归 + 19 项 ChartDemo UI | 当轮核心回归；新 Demo 的属性联动、提示/显隐/滚动、OC 回调等实际操作 | 单元回归执行于扩展审计前；UI 使用新 Demo 预设，不等于完成旧模型转换或独立 OC 宿主接入 |
| 上一轮 [4 项更新后核心对照测试](../SwiftFunctionProjectTests/LegacyReferenceComparisonTests.swift)、新侧 8 张渲染图 | 4 个共享堆叠/类型 fixture 的代表点核对，加原有缺测测试；证明类型分区可对齐，并明确面积 draw 差异 | 当轮缺测仍复刻工厂公式；本批已迁至共享 v2，仍无正式适配器；使用 @testable/内部 datum 和默认主题，非外部宿主或完整页面像素验收 |
| Swift / OC 入口与旧封装源码 | 区分核心支持、OC 可配置、外层组件缺失；解释运行差异 | 静态风险不混写为已复现问题 |

上述上一轮各批全部通过，0 失败。新增共享 JSON 输入、原生提示持触采样和转换边界检查；当轮附件见[重跑证据](evidence/charts-legacy-comparison/2026-09-30-rerun/README.md)，统计边界和首轮历史见第 6 节。

运行环境为 Xcode 26.3（17C529）、iPhone 15 Pro / iOS 17.2 模拟器、Debug。新旧 App 的 Release 模拟器构建也通过；未测真机耗时、内存或功耗，不能据此宣布性能优于旧版。

运行 JSON、截图和归属见[证据索引](evidence/charts-legacy-comparison/2026-09-30/README.md)。下表“核心具备”表示有实现及相关回归；只有明确列出的样本已完成同输入断言。**没有任何一行表示真实业务页面已经替换完成。**

11 个默认场景不等于封装的全部分支或交互已验收。原有探针主要采集附件；新增 4 项 UI 用例已断言面积展开数量、混合类型独立堆叠、拆分异常/字段丢失、同模型空态状态、默认窗口全屏往返和 v1/v2 原生提示成员。JSON 比对、实际手势和完整页面视觉仍分别记录。

09-30 G1 缺测后续：新侧上层跨缺测连接已保留下层两侧的完整曲线，仅在真正缺口直连累计基准并叠加自身厚度，下层仍断开。该过渡是新侧既有正负数学下的展示规则，本批没有新增旧 AA 同输入运行或宣称像素对齐。[新侧前后图与验证](evidence/charts-legacy-comparison/2026-09-30-g1-gaps/README.md)。

09-30 G1 百分比实现：新侧同链份额共同归一化已覆盖混合线型与正负，保持原采样百分比分母和 100% 总跨度；不兼容缺测/零分母链整链回退。原百分比证据目录未保存，已按 [2026-10-02 实际补验日期](evidence/charts-legacy-comparison/2026-10-02-g1-percent/README.md)重跑 8 项专项单元与 1 项两页 UI，未改算法；只验证新侧形态，不新增旧 AA 运行或宣称像素一致。

## 当前图表展现状态（2026-10-02）

G2–G5 的新侧运行结果和独立公共 Swift/OC 产物见[连续验收记录](charts-presentation-g2-g5-2026-10-02.md)，不与下文 9 月 30 日的旧 AA 同输入批次混算。

| 内容 | 当前判定 | 后续边界 |
| --- | --- | --- |
| 复杂堆叠面积过渡 | 共享路径、薄层、跨零、描边内收、前层换链、缺测底边分段及自动百分比共同归一化已有 | G1 不兼容百分比链与冲突缺测策略仍回退；始终检查数据、填充、描边及显式 marker |
| 柱/条阈值颜色 | G2 已实现 Column/Bar/Combined 柱族的 raw/draw 阈值整段取色、X 原始索引与旧规则回退 | 与柱内按高度切多色区分；不改业务值或堆叠几何 |
| 坐标轴外观 | G3 已实现每轴颜色/字体/线宽与显隐、类目步长、有限布局预算 | Bar 无次轴；旋转仅垂直图底部类目；必要时抽稀/截断/省略 |
| 图内标注与标签 | G4 已实现线/带标签独立样式与 clamp/hide、数据背景和可选避让 | 标注先占位、总量优先，冲突省略；不是全局布局优化 |
| 点/柱/条主体选中 | G5 已实现点环、实际柱条段高亮、单点/共享及清理，默认关闭 | 不等于 R4 程序选点/生命周期或跨更新、跨页恢复已完成 |

以上为源码能力/限制核对，不是本次新增功能或已复现的所有视觉错误。验收以现有 Demo 中真实渲染和几何断言为准，不能只以旧字段是否被接受衡量。G 队列的范围、证据入口和下一编码批次见[实施计划](charts-legacy-replacement-plan.md#4-当前绘制队列与后续迁移队列)。

## 2. 按旧 Demo 的 11 个场景对照

| 场景 | 旧 Demo 实际展示/行为 | HYMCharts 当前覆盖 | 替换还差什么 / 判断 |
| --- | --- | --- | --- |
| 功率曲线与业务卡片 | 三业务组、统计表头、日出日落 footer；持触采样确认 v1 原生三组完整，v2 遗漏中间组且右组标题取错 | 曲线/渐变/分组/图标提示/图例核心具备 | **核心可复用，页面组件缺失**：补卡片和表头联动，吸收原生内容但修正漏组/错标题；当前采样不代表旧原生所有场景均验收 |
| 折线、阶梯与前值 | 直线、虚线、marker；设置阶梯与 showPrev；JS 提示及程序选点 | 直线、单调曲线、前/中/后阶梯、虚线和 marker；前值/索引偏移有回归 | **进入字段转换**：阶梯默认方向、抬手隐藏、类目刻度、程序选点 API 仍要核对；不能仅靠两边字段存在判定一致 |
| 电量柱状与分组堆叠 | 两个 stackGroup、四条系列；可切换并排/普通/百分比与显隐 | 同轴同图形族按 stackID 分组，支持三种模式、固定基准及稳定显隐 | **核心可复用**：业务组、数学堆叠组与系列身份分别映射；旧堆叠默认顺序不同，不能直接照搬数组顺序 |
| 正负堆叠与百分比 | 同组跨零；已取得普通/百分比 raw、stackY、percentage；旧百分比轴实际为 0…1 | 同输入经过顺序映射，6 个代表索引 × 2 系列 × 2 模式的 raw/draw 对照通过；百分比分母一致，新轴为 −100…100 | **数学已局部对齐**：保留正确点值，修正旧轴范围；行/图例/绘制顺序分开处理，不改变当前 SDK 默认顺序 |
| 组内分栏与长图例 | 输入 12 系列、gcname、stackGroupInterval=6，长图例已截图；左右原生提示分栏尚未持触验收 | 多组内容、图标/名称数值分栏、超高滚动；图例测量/换行/滚动与图片符号具备 | **业务分栏部分覆盖**：现有“名称/数值两栏”不等同于旧“左右各 6 个设备、各自标题”；gcname/stackGroupInterval 尚无直接映射 |
| 混合图与双 Y 轴 | column + areaspline + spline；功率/温度，次轴 0…60，2500 标线 | Combined 共用轴、命中和图例；主次轴范围/刻度/格式及基础标线具备 | **Swift 核心具备，OC 入口不足**：独立轴外观、标线/标签样式、部分刻度配置未完整透传；此场景尚未全量同输入截图验收 |
| 缺测、分区和正负颜色 | 5 与 12 个空点；最终 autoGap 用透明 zones 覆盖了手工橙/紫 zones，connectNulls=true | 同输入用 autoGap(11)，短缺测连线、长缺测分段；保留 17 个缺测索引及手工分区，原始命中不补点 | **组合语义已验证更独立**：采纳新实现；不复制旧 zones 覆盖。渐变、负值填充、分区阈值归属和复杂堆叠接缝仍按配置验收 |
| 提示分组与数值格式 | 程序选点 12 后 JS 确实显示独立日期表头、逐点组名/行名、组总值、仅名称、前值；隐藏行仍出现 | 工程单位、金额/截断/绝对值、分组/行 provider、过滤、仅名称、前值具备 | **主要语义缺口**：独立表头数据源、逐点组名、组自己的单位/格式/汇总、100 的分级精度；三条旧提示路径不统一，不能简单复制 JS 字符串 |
| 长序列与默认窗口 | 288/1440/3000 点真实渲染；另断言 288 点默认轴域 0…96 在全屏往返后仍为 0…96；未自动执行旧图捏合/拖动 | 初始类目范围、缩放/拖动/惯性、更新保留窗口；采样/图层复用/柱时间聚合具备 | **窗口核心可复用**：默认范围往返通过不代表用户缩放后的窗口、显隐和选择也恢复；仍核对半槽和更新优先级。3000 点“能绘制”不证明性能更好 |
| 无数据与恢复 | 重建模型恢复通过，全零有效；同模型 showNoData 开→关后 showLegend 仍为 NO，新增断言复现 | 空模型可清理旧窗口/图层，恢复可绘制；全零与缺测的数据语义有回归 | **缺少可复用空态组件**：禁止空态修改业务配置；分别验收空数组、全缺测、全隐藏、全零及同模型恢复 |
| 旧组件多图联动 | 三图可渲染，HMMT 内部广播同一索引；未证明原生提示/表头或窗口全部同步 | 单图内部命中/准线/共享提示具备；缺公开索引选择/清除、来源事件、联动协调组件 | **当前不能承接联动页面**：先统一选择状态，再做同采样域广播和不同采样域映射；视口联动另立契约 |

核心证据入口：[混合/堆叠回归](../SwiftFunctionProjectTests/CombinedChartTests.swift)、[数据语义与 OC 回归](../SwiftFunctionProjectTests/CartesianDataSemanticsTests.swift)、[缺测](../SwiftFunctionProjectTests/CartesianGapPolicyTests.swift)、[分区](../SwiftFunctionProjectTests/CartesianColorZoneTests.swift)、[分组](../SwiftFunctionProjectTests/GroupedPresentationTests.swift)、[富提示](../SwiftFunctionProjectTests/RichTooltipTests.swift)、[前值](../SwiftFunctionProjectTests/TooltipSelectionTests.swift)、[刷新](../SwiftFunctionProjectTests/ChartUpdateTests.swift)。

### 首轮遗漏分支的补测状态

| 遗漏/不足 | 源码依据与实际影响 | 补验要求 |
| --- | --- | --- |
| 普通堆叠面积的旧转换 | 新增运行确认单组 2 条业务系列变为 5 条引擎系列，多组变为 3 条；单组 reverse 已采集。拆分 NSNull 异常及副本字段丢失已在原函数调用中复现 | 补完面积百分比、显隐和页面缺测组合；先保留业务身份，再决定正负累计规则，不能只删除虚拟系列并反转数组 |
| 混合线类型的数学分组 | 共享 fixture 中 spline 与 area 使用相同 stackID；旧运行 stackKey 不同，各自 draw=raw。对应 [HYM stackKey](../SwiftFunctionProject/Charts/Cartesian/CartesianSeriesStyle.swift) 同属线族 | 兼容层须保留具体类型分区；本次样本不覆盖所有类型/轴组合。核心默认分链规则保持，适配器不直接照搬 stackGroup |
| 业务数据预处理 | [HMAAChartUtil](../SwiftFunctionProject/参考图表/HMAAChartUtil.m) 的 key 正负转换、按符号改名及 fixAIChatData 未被现有人工样本覆盖；fgp/consumption_power 同时出现在两个转换列表，当前先走取反分支 | 在项目适配层明确原始服务值 → 业务值 → 展示值；补重叠 key、负值、空值样本。预期方向须由调用契约确认，不能把方法名推断当成已复现错误 |
| 仅数值提示与单位类型 | 旧 hideNameInTooltip / showElementName 控制名称，与 onlyNameIntooltip 控制数值不同；旧 needCarryType 还包含金额、var/VA/Ω/bar/CARRY | HYM 可用 rowStyleProvider.title="" 表达空名称，但文本冒号/列宽/前值来源说明仍需验收；按每种单位映射缩放及货币，不仅验证 W/Wh |
| 可变输入和窗口生命周期 | 同模型 showNoData 开关后图例配置未恢复已复现；旧默认窗口全屏往返通过 | 补用户窗口、选择和隐藏系列的全屏恢复；明确输入快照，继续验收换日/换域、全隐藏恢复、旧版本异步结果丢弃 |

共享输入位于 [chart-migration-audit-v1.json](../Examples/ChartComparisonFixtures/chart-migration-audit-v1.json)，包含 column、面积单组/多组、混合类型四个样本，仅编入旧 Demo 与新单元测试资源。本批新增 [v2](../Examples/ChartComparisonFixtures/chart-migration-audit-v2.json)，缺测与提示也改为共享输入，并加入 area-missing；前四份输入与 v1 完全相同。R0a 的真实调用/默认值和剩余边界仍未全部完成。

## 3. 本次取得的具体数值与差异

### 堆叠：分母相同，默认绘制顺序不同

相同 48 点输入，第 12 点：电池 1800 W、辅助 1120 W，总量 2920 W。

| 结果 | 旧 Highcharts 普通堆叠 | HYM 默认输入顺序 | HYM 映射旧堆叠顺序后 |
| --- | --- | --- | --- |
| 电池段累计顶端 | 2920 | 1800 | 2920 |
| 辅助段累计顶端 | 1120 | 2920 | 1120 |
| 业务原值 | 1800 / 1120 | 1800 / 1120 | 1800 / 1120 |

差异来自从哪条系列开始堆叠。测试中仅对该 column 同组样本反向安排数学顺序，稳定 ID 保持，legendOrder 单独设置。当前测试未开启图例、未断言提示排序，因此这里只证明数学位置映射；OC 系列模型也尚未暴露 legendOrder。适配器仍需把提示顺序、图例顺序和绘制顺序分开，并核对业务组边界及旧 reverse 在组内的作用。

第 25 点混合正负：电池 −235、辅助 +103，分母为 `|-235| + |103| = 338`。新旧百分比分别为 **−69.526627% / +30.473373%**。第 36 点两个负数则为 −72.580645% / −27.419355%。既有数值断言容差为 `1e-8`。

旧百分比样本的运行轴范围是 **0…1**，部分百分比柱被裁在错误的值域内；HYM 的同输入轴范围为 **−100…100**，包含两条符号链。[旧点值](evidence/charts-legacy-comparison/2026-09-30-rerun/comparison-signed-percent.json)、[新点值](evidence/charts-legacy-comparison/2026-09-30-rerun/hym-signed-percent-mapped.json)、[新渲染图](evidence/charts-legacy-comparison/2026-09-30-rerun/hym-signed-percent-mapped.png)。

### 缺测：保留长缺测断线，也保留手工分区

旧输入同时指定 20 处橙/紫分界与 autoGap。实际最终配置只有 `24 → 默认色`、`37 → transparent` 两个 zones，20 与紫色消失，短缺测依靠 connectNulls 连接。源码中 autoGap 最后执行 zonesSet，与运行快照一致。

新样本把缺测分段与颜色裁剪分开：`0…7、13…24` 属于同一连接段，`37…47` 为第二段，8…12 和 25…36 的缺测索引依然没有有效 datum；20 之后保留紫色分区。**应保留新机制，并将视觉差异登记为旧问题修正。** [旧最终配置](evidence/charts-legacy-comparison/2026-09-30-rerun/comparison-gaps-options.json)、[新渲染图](evidence/charts-legacy-comparison/2026-09-30-rerun/hym-gaps-independent-zones.png)。复杂堆叠面积的跨零/无共同底边过渡仍按[已知限制](charts-stacked-area-seams-guide.md)处理。

### 提示：组总值不能换成通用小计

旧 format 场景程序选点 12 得到如下实际内容（完整字符串见 [JSON](evidence/charts-legacy-comparison/2026-09-30-rerun/comparison-format-programmatic-js.json) 与[截图](evidence/charts-legacy-comparison/2026-09-30-rerun/comparison-format-programmatic-js.png)）：

- 表头为 `2026-09-30 06:00`，轴类目为 `06:00`；组名为逐点的“发电分组 1”。
- 发电组值为 `3.1 kW`，包含“逆变器 1: 1.23 kW”和“设备正常: 1.87 kW”。后者设置了 hideInTooltip，仍出现在这条程序选点路径。
- “收益”只显示名称；电网组当前总值 `2.62 kW`，行里的前值为 `2.4 kW`。

HYM 内置提示表头由当前命中类目键构建；固定日期可用模板，任意独立表头数据还缺直接数据源。行名/过滤可以用当前 provider 处理，组名仍来自静态组模型。通用小计只计算至少两条同单位/轴/格式/源范围的展示值，不提供旧组独立格式，也不会自动复现“组当前值 + 行前值”的组合。

在旧 needCarryType 命中的单位分支中，`fractionDigits=100` 表示**低量级/k 保留最多 2 位、M/G 最多 3 位**。它不是通用的 100 位小数配置；非进位单位需另核。HYM 当前 engineering 格式使用同一个最多小数位参数，需要兼容规则，不能直接传 100（当前会钳制到 12）。旧金额也参与工程进位；当前金额、绝对值和截断已有通用实现，优先补单位政策、正负舍入、999/1000 与 M/G 临界值的映射样本。

### 补测：面积的展开、累计和轴范围是三个问题

共享样本均为 48 点、第 25 点业务原值 −235 / +103、同一 `stackGroup=battery`：

| 旧运行样本 | 实际结果 | 迁移含义 |
| --- | --- | --- |
| area-single：一个业务组、两条 areaspline | 展开为正值 2 条 + 透明辅助 1 条 + 负值 2 条。第 25 点，辅助功率的正值副本 raw=103、stackY=−132；电池负值副本 raw=−235、stackY=−235 | 引擎位置不是简单的正负独立累计；同名副本和补出的零值不能当成新的业务采样 |
| area-multi：两个业务组、同一数学堆叠组 | 2 条原系列 + 1 条辅助系列；第 25 点电池 raw=−235、stackY=−132。第 12 点累计 2920，第 36 点累计 −2480，但轴仅约 −1980…1980 | 业务分组会改变旧转换路径；该合法配置出现可见裁剪，应修正范围计算，不能当成目标视觉 |
| mixed-types：spline + area、同一数学组 | 两条独立的旧 stackKey，6 个代表索引的 stackY 均等于各自 raw | 具体类型分区必须保留；只传相同 stackID 会与当前 HYM 线族堆叠规则发生冲突 |

证据：[单组](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-area-single.json)、[单组 reverse](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-area-single-reversed.json)、[多组](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-area-multi.json)、[多组裁剪截图](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-area-multi.png)、[混合类型](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-mixed-types.json)。

新侧同 fixture 的最终核对：

| 样本 | 数值核对结果 |
| --- | --- |
| column 普通/百分比 | 各 12 个代表点原值相同；映射后 draw 最大误差 0 / 约 3.62e−13，容差 1e−8 |
| spline + area | 直接复用 stackID 的 draw 最大差异 1800；把具体类型纳入兼容栈键后，12 个代表点 raw/draw 差异均为 0 |
| 面积单组 | 归一到两个业务系列后 12 个 raw 相同；第 25/47 点辅助系列旧 draw=−132，新正链 draw=+103 |
| 面积多组 | 归一后 12 个 raw 相同；第 25/47 点电池旧 draw=−132，新负链 draw=−235；新自动范围 −3000…3000 覆盖全部已测绘制值 |

该归一化只用于本 fixture 的离线比对，不是正式适配器。[可复算数值摘要](evidence/charts-legacy-comparison/2026-09-30-rerun/numeric-audit-summary.json)、[复算脚本](evidence/charts-legacy-comparison/2026-09-30-rerun/compare_snapshots.py)、[新面积图](evidence/charts-legacy-comparison/2026-09-30-rerun/hym-area-multi-business-series.png)、[类型分区后的新图](evidence/charts-legacy-comparison/2026-09-30-rerun/hym-mixed-types-partitioned.png)。颜色、marker、轴刻度及布局仍使用 HYM 默认主题，未声称像素一致。

**面积累计差异不能全部标为旧 bug，也不能宣布已经兼容。** 目标默认继续采用 HYM 正负独立链，保留业务原值；如果真实旧页面依赖抵消/绝对值填充效果，必须单列兼容预设和验收。辅助系列身份、累计位置和轴范围分别核对。

09-30 G1 后续补测：另用共享三点 `areaspline` 样本运行旧封装与新侧。前层换链 `[20,20,20] / [30,-30,30] / [5,5,5]` 仍展开为 7 条旧引擎系列；原值 `+5` 的中间点旧正副本累计为 `−25`，新侧为 `+25`。本轮修复的是新侧采样点之间的基线衔接，不修改已选的正负独立数学，也不将旧截图视为像素目标。[本轮同输入证据](evidence/charts-legacy-comparison/2026-09-30-g1-envelope/README.md)。

原 `positiveSplitFromSeriesElement:` 与 `negativeSplitFromSeriesElement:` 接收 `[1, NSNull, -1]` 均抛 `NSInvalidArgumentException`（`NSNull doubleValue`）。审计边界捕获了原函数异常，**未通过故意崩溃整个 App 来测试**。另以有效数据调用正拆分，原本为 YES 的 `hideInTooltip/hideNameInTooltip/showPrev/markerHidden` 变为 NO，`negativeColor` 丢失。[转换证据](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-input-boundaries.json)。

### 补测：持触原生提示与同模型空态

功率三组场景使用 XCTest 实际按住横移，Demo 只读采样可见提示视图中的 UILabel：v1 的 4 个采样状态都有光伏、负载、电网；v2 的 4 个状态只有光伏、电网，中间负载缺失，右组标题还重复为“发电”。源码 `HMIconTooltip.loadTooltipDataIndex:` 的右组取 `firstObject` 与附件一致。证据：[v1](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-held-v1-原生.json)、[v2](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-held-v2-原生.json)。

这些是触摸过程的文字和 frame 快照，不是逐帧像素截图；最终 9 秒采样结束时提示已隐藏，不能由此精确量化抬手隐藏时延。12 系列分栏、format 的全部原生规则及跨图原生同步仍待补验。

同一模型执行 `showNoData=true → false` 后，`showLegend` 仍为 false，已断言复现。另对 dense 288 点场景确认默认窗口全屏前后都是 0…96；未改变过用户缩放窗口，也未同时测试显隐/选择恢复。证据：[空态](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-empty-toggle-same-model.json)、[全屏前](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-dense-before-fullscreen.json)、[全屏后](evidence/charts-legacy-comparison/2026-09-30-rerun/audit-dense-after-fullscreen.json)。

### 刷新：旧缓存行为应修正

已通过旧 UI 断言：首值 **400 → 完整刷新 525 → 仅数据入口输入 650，但运行值仍是 525**。新 update 路径接受当前模型、清除旧提示并保留/收回视口，相关回归已通过。迁移后更新 650 必须命中 650；不保留旧打包 series 缓存作为“兼容”。当前没有旧入口适配器，因此这是验收契约，不是已完成旧 API 替换。

### 差异台账

此处记录证据和目标处理；目标处理尚不等于已实现兼容。R 编号对应实施计划。

| ID | 证据状态 / 范围 | 目标处理及归属 |
| --- | --- | --- |
| D01 刷新旧值 | 旧 line 样本自动断言复现 | 修正：重新接收当前快照；R2/R4，回归 400→525→650 与视口/选择失效 |
| D02 百分比轴 | 旧 signed 样本运行 JSON 为 0…1；不能推广为所有旧百分比配置 | 修正：轴包含实际百分比正负链；R2，另验显式范围、全零、单系列 |
| D03 zones 被覆盖 | gaps 最终 JS 配置与源码一致 | 修正：缺测策略和颜色分区独立；R2，记录边界/填充的接受差异 |
| D04 提示行未隐藏 | format / v1 JS / 程序选点 12 的截图与 JSON；尚未验证手势及原生路径 | 修正：统一整行过滤；R3/R4。是否进入业务组汇总须另立规则 |
| D05 堆叠顺序 | column 同组运行数值核对；图例/提示排序未验 | 兼容正确原值与堆叠位置；R2/R3，稳定身份和三种顺序独立 |
| D06 面积辅助系列及具体类型分链 | 共享输入确认 5/3 条展开；类型分区后混合图 12 个代表点对齐，面积归一后 raw 对齐但跨零 draw 仍不同；单组 reverse 已采集 | R2 分开处理身份归一化、类型分组与累计策略；R0b 确认页面是否依赖旧面积抵消效果；不能只删辅助系列并反转数组 |
| D07 业务 key 转换优先级 | 静态确认列表重叠及 if/else 顺序；业务预期未知 | 由真实调用确认转换一次及方向；R0/R2，不在 SDK 核心复制业务 key |
| D08 初始窗口与刷新状态 | 旧默认 0…96 全屏往返已断言；新半槽语义仍与旧不同；尚未验用户窗口和选择恢复 | R2/R4：明确初始域、半槽、用户窗口、换采样域重置及全屏恢复优先级 |
| D09 面积拆分空值/复制字段 | 原函数运行确认 NSNull 异常；正拆分丢失 4 个布尔配置及 negativeColor | 修正：R2 保持位置和完整业务元数据，缺测不能转零或进入无效数值调用；不复制旧辅助拆分链 |
| D10 v2 原生漏组/错标题 | 三组功率页的持续触摸采样及源码一致；v1 三组完整，v2 少中间组且右标题错误 | 修正：R3/R5 任意已用组数逐组展示，组标题与成员按稳定身份绑定 |
| D11 强制空态修改输入 | 同一模型开/关 showNoData 后 showLegend=false，UI 断言复现 | 修正：R2/R5 用独立展示状态，不覆盖调用方图例配置；恢复时保留显隐策略 |
| D12 面积范围裁剪 | area-multi 同 stackGroup 跨业务组，累计 2920/−2480 超出约 ±1980；JSON 与截图一致 | 修正：R2 按实际绘制链和可见系列计算范围；显式业务范围另按契约验收 |

## 4. 页面交互和接入差距（后续）

以下内容保留作最终替换清单，不作为当前绘制 G 队列的前置。外层统计/卡片可通过叠加或组合 UIView 实现；图层动态色刷新仍属于图表本体。

| 项目 | 应保留/吸收的能力 | 当前需要交付 |
| --- | --- | --- |
| 两版原生提示与 JS 提示 | 业务内容、分组、图标、前值、抬手/超时策略 | 一套统一数据内容与选择生命周期；排版可不同，原值/组值/源索引必须明确；旧三路径差异逐条核对 |
| 卡片/表头/footer/空态 | 老页面能完整展示和恢复数据的能力 | 可选 UIKit 组合组件、资源/文案注入、统一测量；SDK 核心不引用能源 key 或 Language 宏 |
| 图例 | 旧业务组标题/分栏语义；新稳定 ID 与测量/滚动机制 | 先补业务字段映射；不重建另一套图例测量；显隐后仍保持正确分组和身份 |
| 程序选择/多图 | 旧 setTouchPointXIndex 与索引广播的可用入口 | Swift/OC 公开 select/clear、事件来源、通知策略；同域/异域映射与失配策略；内部手势函数不算公开接口 |
| 深浅色/外层滚动 | 旧主题切换和垂直拖动委托 | 动态颜色解析后刷新 CGColor 图层、方向仲裁；现有颜色配置不等同于已通过实时切换 |
| 全屏 | 进入/返回、横向空间 | 窗口、显隐、选择和主题恢复；旧固定白底/90° 旋转的对比不足已在截图观察到，不照搬 |
| OC / 分发 | 旧项目可低成本调用 | 独立 HYMCharts.framework 与纯 OC 宿主已通过；继续补必要轴/标线/样式/缩放透传与正式旧输入适配；LegacyChartDemo 仍仅为对照 App |

## 5. 取长补短与实施顺序

**保留 HYMCharts** 的原值/绘制值分离、稳定 ID、缺测与分区独立、单调曲线、图例统一测量、更新窗口策略和可选采样。**吸收旧模块** 的业务组元数据、卡片/统计表头/空态、完整提示内容、程序选择、联动和全屏使用方式。**修正已复现旧问题**：刷新缓存、百分比轴、zones 覆盖、JS 隐藏行，以及本次补证的拆分异常/字段丢失、原生漏组/错标题、空态修改模型和面积范围裁剪。短数组和次轴刻度等未补测项继续标为风险；面积累计策略另待真实页面确认。

下一步按[唯一实施队列](charts-legacy-replacement-plan.md)推进：

1. G1 先完善复杂面积/堆叠过渡，再补 G2 柱/条阈值颜色、G3 坐标轴、G4 图内标注与 G5 选中反馈；已有能力不重复建设。
2. 每项都在现有图表 Demo 中配置并展示，交付受影响路径测试与前后渲染证据。基础形态、缺失形态和仅桥接缺失分别记录。
3. 正式旧输入适配 R2、业务提示/卡片和完整状态/全屏在图表展现完善后推进；已完成的独立 framework 与样本工作保留使用。

当前没有老项目业务调用工程，实际页面与最低 iOS、包管理和资源仍待接入。它不妨碍上述样本与 SDK 宿主建设，但本次不能宣布真实页面已可直接替换，也不计算迁移完成百分比。

## 6. 验证记录

### 本次重跑与补测记录

| 执行 | 本次结果 | 结果包/日志 |
| --- | --- | --- |
| HYM 完整单元回归（审计扩展前） | 258 项通过，0 失败 | `/tmp/ChartsAudit-native-baseline-id-20260930.xcresult` |
| 旧 Demo 完整 UI（含新增审计） | 11 项通过，0 失败 | `/tmp/ChartsAudit-legacy-expanded-20260930.xcresult` |
| 更新后 HYM 对照 + 全部 ChartDemo UI | 4 项对照 + 19 项 UI 通过，0 失败 | `/tmp/ChartsAudit-native-expanded-20260930.xcresult` |
| 新旧 App Release 模拟器构建 | 两个 target 均通过 | `/tmp/ChartsAudit-native-release-20260930.log`、`/tmp/ChartsAudit-legacy-release-20260930.log` |

258 项含首轮 2 项对照测试；扩展后的对照测试另执行，不把重叠次数累加成独立覆盖数。该轮尚未建立独立 SDK 宿主；后续基础批次已补齐，见下一节。

本次只修改 Demo 审计入口/只读探针、共享输入与测试资源归属、测试和文档，未修改 SDK 或参考图表的运行源码。保存了工作区源码归档、逐文件 SHA-256、fixture 散列、测试摘要和附件归属，见[重跑证据目录](evidence/charts-legacy-comparison/2026-09-30-rerun/README.md)。真机性能、真实业务页和完整像素对等仍未验收。

19 项 UI 包括现有图表页、属性实时更新、密集/固定窗口、OC 四种图表回调、混合双轴、缺测/分区、面积接缝、前值置顶、富提示滚动及分组图例。它们使用原生 Demo 自己的预设，没有经过 HMAA 适配器。新侧导出 71 张 PNG（8 张对照渲染图 + 63 张 UI 图）和 8 份 JSON，旧侧导出 30 张 PNG 和 15 份 JSON；全部按结果包归属保存。

初次按设备名称启动因存在两个同名模拟器而未执行测试，随后用原设备 UUID 重跑成功；本轮没有为通过测试修改图表算法。所有截图/JSON 均来自本次运行，不复用首轮附件冒充重跑。

### 首轮对照记录

前次对照工作只增加只读探针、对照测试与证据，未修改参考源码或 SDK 运行逻辑。

- 旧探针 UI：**1 项通过**，结果 `/tmp/LegacyChartDemo-comparison-20260930.xcresult`；此前 6 项基线见旧 Demo README，两批分开执行。
- HYM 相关回归：**113 项通过**，结果 `/tmp/SwiftFunctionProject-comparison-20260930.xcresult`。
- HYM 同输入：**2 项通过**，结果 `/tmp/SwiftFunctionProject-reference-comparison-final-20260930.xcresult`。首次构建因测试误用轴构造参数失败，修正后两项通过；没有为测试改变 SDK 算法。
- 保存 8 份原始运行 JSON、5 张图及 manifest，另有由 JSON 计算的数值对照摘要；此前 23 张旧 Demo 基线图继续保留。新图为真实 UIView/CALayer 离屏渲染，不是新宿主触摸 UI 验收。

重新执行同输入测试：

```sh
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -parallel-testing-enabled NO \
  -only-testing:SwiftFunctionProjectTests/LegacyReferenceComparisonTests \
  test CODE_SIGNING_ALLOWED=NO
```

### 文档复核记录

前一次复核仅校正源码与文档，没有重新执行测试；本次应用户要求重跑并补测。113/2/1 仍属于首轮记录，本次统计单列在上方。差异台账继续区分运行确认、尚未补证和待业务确认，新增测试不代表迁移适配器已实现。

## 7. 基础接入批次：独立产物与共享输入

本批次未修改 SDK 渲染算法或参考图表实现。新增独立工程引用 75 份 Charts 源码，保留 6 种 SwiftUI 公开包装，排除 Demo、Debug 和参考资源。两个宿主只通过公开模块/生成头导入；没有 App 私有类型依赖。

| 验证 | 结果 | 限定 |
| --- | --- | --- |
| Swift + 纯 Objective-C 宿主 | Debug/Release 各 2 项 UI 通过 | 配置、更新、显隐、真实点击返回 500；各 30 次同步创建释放。OC 另验非法 ID 的 NSError 和保留有效数据 |
| 独立产物 | iPhone arm64 Release 构建通过，模拟器包含 arm64/x86_64；生成 OC 头、SwiftUI 包装、@rpath 与资源/依赖审计通过 | 尚无签名发布、真机运行或正式业务包管理验收 |
| 原生对照 | 6 项通过；包含原 4 项和 2 项新增测试 | 面积单组/多组/缺测 × normal/percent × 隐藏/恢复，全 48 类目验 raw/base/draw/范围；这是目标数学策略验证，未宣称旧面积百分比同值 |
| 旧 Demo v2 输入 | 1 项 UI 通过，导出 4 份 JSON | signed normal/percent、gaps、format 全部与上一轮 JSON 完全相同；历史 v1 不变 |
| 提示共用输入 | 名称、整行隐藏、仅名称、hidePoints、前值源索引在 0/10/11/12/47 验证 | 表头在测试内容构造处显式传入；动态组名、独立表头接入和 fractionDigits=100 尚未正式适配 |
| 字段/入口清单 | 9 个头文件 197 项通过漏项检查 | 55 能力可映射、21 需 OC 桥接、102 需新增能力、5 不承接原入口、14 需业务确认；不是进度百分比 |

初次新提示测试遗漏 `header="{key}"` 导致 5 条断言失败；补齐测试配置后 6 项全过，未改 SDK 行为。产物检查发现默认 install name 为固定路径，工程已改为 `@rpath` 并重新跑过 Debug/Release 和设备构建。现有协议 existential 写法仍有未来 Swift 语言模式警告。

完整摘要、附件归属、源码/输入散列、产物检查和复验命令见[基础批次证据](evidence/charts-legacy-comparison/2026-09-30-foundation/README.md)。该批次状态为 **R1 最小验收完成，R2 正式适配待做**。用户随后明确图表本体优先，当时下一步改为 G1、R2 后置；当前 G1 常用组合与 G2–G5 已交付，后续入口见[最新实施计划](charts-legacy-replacement-plan.md)。
