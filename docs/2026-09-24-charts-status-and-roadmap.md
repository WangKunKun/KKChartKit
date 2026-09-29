# 图表库现状核对与后续路线图

> 最新进度（2026-09-29）：迁移第 3 阶段已接入 autoGap、X/Y 连续颜色分区与平滑曲线负值着色，含 Swift/OC 与 Demo。分区不修改原始数据；复杂堆叠面积基准切换接缝仍待后续处理。见 [缺测策略指南](charts-gap-policy-guide.md) 与 [颜色分区指南](charts-color-zones-guide.md)。

> 旧模块迁移第 2 步已接入混合图、分组堆叠、系列独立样式和 Demo/OC 调试入口，详见 [混合图指南](charts-combined-and-stacks-guide.md)。下文的缺口描述保留为当时评估基线。

> 旧模块迁移第 1 步已接入统一命中数据语义、业务组元数据、每系列格式与最小 OC 桥接；详见 [数据语义指南](charts-data-semantics-guide.md)。

> 第 9 步已接入固定 pt 柱宽/间距与默认从最早数据开始的滚动窗口，保留手动区间定位。见 [固定布局指南](charts-fixed-column-layout-guide.md)。

> 第 8 步已接入 Line / Column / Bar 图层与标签复用，并同步三个 Demo 属性开关。见 [复用指南](charts-rendering-reuse-guide.md)；真机分析、几何缓存与局部更新仍待完成。

> 第 7 步已接入非堆叠直线/面积图 Min/Max 降采样，原始命中与缩放恢复已覆盖；所有选项同步到折线 Demo，见 [使用指南](charts-line-sampling-guide.md)。

> 第 5、6 步已接入统一 Demo 属性面板、手势聚合缓存和粒度切换缓冲。见 [调试指南](charts-demo-guide.md) 与 [最新状态](charts-capability-status.md)。

> 第 4 步已完成高密度 Column 等间隔时间聚合与区间明细，参见 [接入指南](charts-time-grouping-guide.md) 和 [当前状态](charts-capability-status.md)。

> 第 3 步已完成：稳定系列 ID、内置图例与显隐。最新状态见 [能力清单](charts-capability-status.md)，接入见 [图例指南](charts-legend-guide.md)。

日期：2026-09-24。基线：当前工作区，包含已有未提交修改。

本次为文档与源码静态核对，没有重新运行构建、模拟器、测试或性能基准。下文“已有”表示存在对应实现，不代表所有组合场景已经验证。本次只新增本文，不修改实现。

> 后续执行记录：2026-09-24 第 1 步已完成，总量标签修复与 10 个新增回归测试通过，完整单元测试共 16 个通过。当前状态以 [能力清单](charts-capability-status.md) 为准；本文以下保留最初盘点基线。

> 第 2 步已完成：更新保留视口、SwiftUI 回调同步、数据域变化约束及旧动画/弹窗收尾；15 项新增测试通过，完整单元测试共 31 项通过。选择身份恢复移入下一步稳定系列 ID 工作，具体语义见 [更新指南](charts-update-guide.md)。

## 1. 建议定位

以现有 HYMCharts 为基础，形成原生 Swift 图表 SDK：吸收 AAChartKit 的配置便利性、样式与图表覆盖面，以及 ChartsOrg/Charts（DGCharts）的数据组织、交互、混合图和工程化设计。

保留 UIKit + QuartzCore/CoreGraphics、Model/Theme/Renderer、SwiftUI 适配和独立 OCBridge。无需为此更换现有引擎。近期目标是让现有图表形成稳定、完整、可独立接入的产品，再扩展图表类型。

参考：[AAChartKit-Swift 官方仓库](https://github.com/AAChartModel/AAChartKit-Swift)、[DGCharts 官方仓库](https://github.com/ChartsOrg/Charts)。前者展示丰富图表、配置、弹窗和数据刷新入口；后者列出混合图、双轴、缩放平移、图例、选中提示和图片导出等能力。

## 2. 当前实现

| 范围 | 源码确认的能力 | 边界 |
|---|---|---|
| 通用框架 | 泛型 HYMChartView、Renderer 协议、Model/Theme 分离、动画驱动、命中上下文、弹窗控制与定位 | Core 包含 UIKit，纯 Swift 不等于无 UI 依赖或跨平台 |
| 雷达图 | 维度配置、中心分数、逐维样式、网格和装饰环、数据/标题顶点命中与选中反馈 | 模型目前表达一组维度数据，未提供多系列对比模型 |
| 热力图 | 二维/不等长行、色阶、行列标签、无效占位格、命中选中、弹窗 | 独立于 Cartesian 轴系 |
| 折线家族 | 直线、单调平滑、三种阶梯、面积渐变、多系列、断线/connectNulls、点形状/空心点、虚线、阴影、数据标签 | 平滑线负值换色尚未切分；配置以全图主题为主 |
| 柱状/条形 | 正负值、并排多系列、普通/百分比/固定基准百分比堆叠、宽度间距、圆角、描边、逐柱颜色、最小长度、阴影 | 并排柱与“多组分别堆叠”不同；grouped 枚举仍是预留 |
| 轴系 | nice scale、刻度位置/间隔/数量/格式化、Line/Column 双值轴、标线、色带 | 任意数值 X/时间 X 尚未实现；Bar 不支持次值轴；标签旋转仅部分轴生效 |
| 交互 | 单点/整列命中、吸附、滑动选中、双向准线、x/y/xy 缩放、平移、回弹、双击重置 | 惯性减速仅 X 轴；Cartesian 尚无点/柱主体的 applySelection 视觉实现 |
| 弹窗 | UIKit 容器三层机制：自定义内容、位置回调、内置文本；文本模板 | Line/Column/Bar 的 SwiftUI 入口尚未完整透传 popup/onHitLocated |
| 接入 | 五类图表都有 SwiftUI 包装及 Demo；Radar/Heatmap 有 OCBridge | Cartesian 的 OCBridge 未补齐；未见独立 Package.swift/库 target |
| 验证 | ChartSelfTest 约 2500 行；已有 XCTest target，并有准线、回弹、Bar 轴系测试入口 | 大量验证仍聚合于 DEBUG assert；性能测试模板为空，未形成量化基准 |

主要代码入口：

- `SwiftFunctionProject/Charts/Core/HYMChartView.swift`
- `SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift`
- `SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift`
- `SwiftFunctionProject/Charts/Line/LineChartRenderer.swift`
- `SwiftFunctionProject/Charts/Column/ColumnChartRenderer.swift`
- `SwiftFunctionProject/Charts/Bar/BarChartRenderer.swift`
- `SwiftFunctionProjectTests/SwiftFunctionProjectTests.swift`

### 当前未提交功能

已有 6 个修改文件，涉及 Column/Bar 的堆叠总量标签、Theme、Demo 和自检。源码存在 `showsStackTotalLabels`、`stackTotalLabelFormatter` 和 `runStackTotalLabelSelfTest`。因此它应标为“已写入工作区、待验证收尾”，不能继续作为从零开始的需求，也不能视为已验证发布。

## 3. 文档与源码的差异

1. 8 月路线图的阶段 0/1 已有实现；阶段 2 的平滑/面积已有实现；阶段 3 的多系列、阶段 4 的主要手势已有实现。图例、混合图、增量/流式更新仍缺失，不能按阶段整体标完成。
2. 折线对比表仍把双向准线、弹窗模板标缺失，但源码和同文档更新日志已记录实现。
3. 折线使用指南仍描述“单系列”“无手势”；柱状指南仍把百分比堆叠、并排柱写作未实现，均已滞后。
4. 早期“无 test target”的前提已经失效。现有工程包含单元测试和 UI 测试 target。
5. `todo-bar-axis-fix.md` 是已修复的历史记录，不是当前待办清单。
6. 文档混用 HYMCharts 与 KKChartKit。建议发布前统一产品/模块名，公开类型改名需配合兼容策略。
7. “独有/领先”应改为可验证的具体行为描述；不能仅凭原生 CALayer、功能打勾或主观手感认定整体优于两库。

建议保留历史 spec/plan 作为决策记录，另维护一份当前能力矩阵，包含：状态、源码入口、适配端、限制、验证日期。对外部库的比较固定版本或提交，并附最小复现条件。

## 4. 当前最值得处理的技术问题

### 4.1 更新数据会丢失交互状态

`HYMChartView.configure` 重置 X/Y viewport；Line/Column/Bar 的 `updateUIView` 每次调用 configure。数据或 SwiftUI 状态刷新容易重置用户已经缩放的位置。

建议把数据、样式、交互状态分离。明确初始化、更新数据、更新样式、主动重置视口四种操作；提供保留窗口、适应全量、跟随最新数据等显式策略。更新数据时维护稳定系列/数据点身份，并明确删除当前选中点后的行为。

### 4.2 渲染仍有全量重建路径

`CartesianRendererBase.relayout → render` 会删除并重建轴标签和图层子树。折线会为全量有效数据计算路径/命中缓存，点标记逐点创建 layer。柱体已有按颜色合并 path 的优化，但不能据此推导整个引擎的大数据性能。

建议先量测，再引入：可见范围裁剪、几何与刻度缓存、layer/label 复用、变更类型驱动的局部更新。对于稠密折线，按数据特征评估 min/max 或 LTTB 等降采样，并保留原始数据供命中与详情读取。

### 4.3 系列模型尚不适合直接承载混合图和时序数据

目前数据为 `[Double]`，X 主要由数组索引产生，系列没有稳定 ID、可见性和 stack ID。图例若直接删除数组元素，会改变 seriesIndex，并影响选择状态、配色、堆叠及回调身份。

优先补 `SeriesID`、独立显隐状态、轴绑定/堆叠分组契约；之后增量支持明确的 XY 数据与时间轴。保留现有简洁数组入口，避免一次性改成万能字典模型。

### 4.4 公共语义需要统一

- 单点堆叠命中和 shared tooltip 的 value 语义不同；折线 `.percentFixed` 命中分支也与 `.normal/.percent` 不一致。建议显式提供 rawValue、displayValue、stackTotal、percentage，分别定义适用条件。
- “滑动选中/准线”与“数据点或柱体视觉高亮”是不同能力，应分别标记和验证。
- screen x/y 与 category/value 的含义在 Bar 中不同，后续公共 API 应避免继续传播方向歧义。
- 当前泛型 Cartesian 基类内部强转为 CartesianChartTheme，自定义 Theme 并不因泛型存在就天然可扩展。新增主题类型前需明确约束或访问协议。

## 5. 建议实施顺序

### P0：现有能力收尾与稳定基线

工作：验证当前总量标签改动；更新当前能力矩阵；把关键自检逐步拆成独立 XCTest；统一命中值语义；处理 configure/updateUIView 的视口保持和回调更新；增加空数据、无效值、全零、全负、长标签的回归场景。

验收：现有五类 Demo 可回归；缩放后更新数据/样式不会无意重置窗口；总量标签覆盖正负链、百分比、双轴和视口边界；每个关键失败能定位到独立测试。

### P1：图例 + 稳定系列身份 + 选中反馈

工作：系列 ID、显隐状态、调色板稳定映射；图例布局与点击；点/柱高亮；统一 shared tooltip 过滤与选择状态。

先确定隐藏系列是否参与值域、堆叠、百分比分母，以及全隐藏时的行为。初期建议隐藏系列退出绘制、命中和可见系列计算；后续需要保留范围时提供显式策略。

验收：Line/Column/Bar 共用图例；隐藏中间系列后颜色与回调身份稳定；双轴/堆叠/tooltip 与显隐一致；无需修改外部原始数据数组。

### P2：首个混合图闭环

工作：支持“柱 + 折线 + 面积”的系列级渲染配置、共享坐标布局、绘制顺序、双轴与统一命中。由组合渲染器复用系列绘制能力，避免往基类不断堆积图表类型分支。

验收样例：月度电量柱 + 功率/趋势线，或销售额柱 + 利润率右轴线；共用一份图例、一个 viewport、一套 shared tooltip；明确不同单位与不同系列类型的堆叠限制。

### P3：数值/时间 X、流式更新与性能

工作：引入 XY 数据、时间刻度/格式化与缺口语义；update/append 数据接口；固定窗口与跟随最新策略；有界数据缓存；局部失效与降采样。

验收：不等时间间隔按真实距离绘制；追加数据保留历史窗口或按策略跟随最新点；持续追加不会无限增长内存；报告 1k/10k/100k 点下的首绘、更新、拖动帧时间、峰值内存与 layer 数。

性能阈值应绑定设备、刷新率、系列数、点标记/标签开关和更新频率。60 Hz 可用 16.7 ms 帧预算作为目标参考，达标情况由实测决定。

### P4：SDK 分发与适配补齐

最小 SPM 拆包和独立消费工程建议 P0/P1 就开始验证，避免发布阶段才发现访问控制或资源依赖问题。

工作：分离库/Examples/Tests；明确最低 iOS 版本（当前工程配置为 iOS 15）；补齐 Cartesian OCBridge 和 SwiftUI 自定义 popup、选择/viewport 状态入口；主线程契约；API 文档、CI、版本与迁移策略；空态、可访问性与图片导出。

验收：独立 SwiftUI、UIKit、Objective-C 工程分别接入；无需复制 Demo 代码；测试自动执行；无数据和 VoiceOver 场景可用。

### P5：按共用底座扩展类型

建议顺序：饼/环 → 散点/气泡 → 范围/瀑布 → 箱线/误差线 → 仪表/漏斗/极坐标；金融场景需要时再加入蜡烛图。饼/环可在业务急需时提前；散点/气泡优先复用 P3 的 XY 数据。

雷达多系列对比、zones、轴反向、对数轴、更多 easing、数据过渡/排序动画、多图联动按实际需求插入。图例、状态保持和混合图的优先级高于装饰性细节。

每种新增图表都应同时交付数据模型、渲染、命中、标签/图例契约、Demo 和针对性验证，避免只完成静态绘制。

## 6. 下一批可执行任务

1. 验证已有堆叠总量标签修改并补齐当前能力矩阵。
2. 建立状态保持回归：缩放 → 数据更新 → 样式更新 → 选择仍有效。
3. 设计并落实 SeriesID/显隐状态和命中值语义。
4. 完成 Line/Column/Bar 通用图例与选中反馈。
5. 用“柱 + 线 + 双轴 + shared tooltip”验收首个混合图。

这批工作完成后，再以真实时序数据驱动更新性能和数据模型扩展。旧的“全部图表类型覆盖”路线图保留为长期范围，不再作为当前线性执行顺序。
