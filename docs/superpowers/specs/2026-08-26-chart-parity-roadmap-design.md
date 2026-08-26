# 原生图表库对标 AAChartKit 全量路线图设计

> 日期：2026-08-26
> 状态：待审阅
> 负责人：wangkun
> 前序文档：
> - `specs/2026-07-22-chart-framework-design.md`（HYMCharts 框架总设计，本路线图的地基）
> - `specs/2026-08-03-chart-popup-content-provider-design.md`（命中弹窗两层机制）

## 1. 概述与目标

以 [AAChartKit-Swift（AAInfographics）](https://github.com/AAChartModel/AAChartKit-Swift) 的功能清单为**学习路线图**，在现有 HYMCharts 框架上分阶段实现其全部图表类型与横切能力，**全部采用原生自绘**（UIKit + QuartzCore + CoreGraphics）。

核心动机：**学习/实践原生图表渲染技术**。图表类型数量与工期不是首要约束，渲染技术的深度才是价值所在。

本设计回答三个问题：

1. 要覆盖哪些功能（范围与阶段划分）。
2. 架构如何组织约 20 种图表类型而不失控（Cartesian 轴系基础层）。
3. 横切能力（动画/手势/动态刷新/图例）落在哪里。

## 2. 背景：AAChartKit-Swift 调研结论

| 维度 | 事实 | 对本项目的含义 |
|---|---|---|
| 底层原理 | WKWebView 内嵌 **Highcharts（JS 库）**，Swift 层只做配置翻译（`AAOptions` → JSON → 网页） | 它的"功能"本质是 Highcharts 的能力面，原生复刻 = 重新实现一个渲染引擎 |
| 图表类型 | 约 20 种：column、bar、line、spline、area、areaSpline、pie、bubble、scatter、pyramid、funnel、areaRange、columnRange、waterfall、boxplot、gauge、errorbar、雷达、极坐标、混合图 | 类型清单即本路线图的分期依据 |
| 横切能力 | 多种 easing 动画、点击/滑动事件、缩放手势、仅刷新数据、流式滚动更新、排序动画、自定义 tooltip | 除自定义 tooltip（已有三层机制）外全部纳入范围 |
| 手势 | 双指平移/缩放（WebView 中单指被页面滚动占用） | **本库 deliberately 区别：单指拖动平移**（见 §7.1） |
| OC 支持 | 不支持（OC 版为另一个库 AAChartKit） | 本库 OCBridge 是超出对标范围的增值项 |
| 许可证 | 库本身 MIT，但内嵌 Highcharts JS **商业用途收费** | 若走 WebView 路线有法律风险；原生自绘无此问题 |

**被排除的路线**（决策记录见 §3）：

- WebView 内嵌 Highcharts：学不到原生渲染，且有 Highcharts 商业许可风险。
- 直接依赖/包装 AAChartKit：同上。
- 通用配置驱动单引擎（对标 AAOptions API 形态）：Highcharts 靠 JS 引擎消化所有配置分支；原生实现会退化为数千行上帝 Renderer，违背单一职责，学习价值最低。

## 3. 决策记录

| 决策点 | 结论 | 理由 |
|---|---|---|
| 核心动机 | 学习/实践原生图表渲染 | 用户澄清的第一约束，决定一切取舍 |
| 渲染路线 | **原生自绘**（UIKit + CALayer + CoreGraphics，延续现有 HYMCharts） | 学习目标决定；规避 Highcharts 许可风险 |
| 类型范围 | **分阶段全量覆盖**（约 20 种，每阶段独立 spec + plan） | 一次性规划 20 种会失控；分阶段保证每阶段有交付 |
| 横切能力 | 动画体系、缩放/平移、动态数据更新、图例与混合图，**全部纳入** | 均为高学习价值点（插值/坐标变换/增量渲染/series 抽象） |
| 手势方案 | **单指拖动平移 + 双指捏合缩放**，与 AAChartKit 的双指方案 deliberately 区别 | 原生 iOS 手感（参照股票 App）；WebView 无此自由 |
| 工程配套 | **先内核 + demo（含最小 Representable 与属性面板），OCBridge/SwiftUI 正式封装后置统一补齐**（阶段 10） | 学习期轻装；避免每类型背负四件套全量负担 |
| 架构组织 | **方案 B：轴系基础层（Cartesian）先行** | 约 2/3 类型是轴系的，四个横切能力全部寄生在轴系上；一次投入多类型受益 |
| API 风格 | 延续 struct + memberwise init + 默认参数；**不做 AAOptions 全量对标、不做链式 builder** | 强类型、可发现性好；现有代码一致性 |
| 测试基线 | 延续 ChartSelfTest（DEBUG 断言）模式，纯函数全覆盖 | 无 test target 的工程约束仍在（改 pbxproj 风险高） |

## 4. 分层架构（在现有 HYMCharts 之上增量演进）

现有 Core/Radar/Heatmap/SwiftUI/OCBridge/Debug 结构**全部保留不动**，新增 `Cartesian/` 轴系基础层与各图表类型目录：

```
SwiftFunctionProject/Charts/
├── Core/          # 现有内核：HYMChartView 容器、HYMChartRenderer 协议、
│                  # Tooltip 三层、HYMChartValueAnimator、HYMChartError、交互
├── Cartesian/     # ★ 新增：轴系基础层（本设计的核心增量，见 §6）
├── Line/ Column/ Pie/ Gauge/ Funnel/ ...
│                  # 各图表类型 = 薄 Renderer（只实现 drawSeries / seriesHitTest）
├── Radar/ Heatmap/   # 现有非轴系类型，保持不动
├── SwiftUI/       # 各类型 Representable 封装 + demo（后置统一补齐）
├── OCBridge/      # OC Wrapper（后置统一补齐）
└── Debug/         # ChartSelfTest 持续扩展
```

依赖方向不变：`Core ← Cartesian ← 各类型薄 Renderer ← SwiftUI/OCBridge`，Core 永不依赖上层。

**"薄 Renderer"机制**：`LineChartRenderer` 只负责"把 series 画成折线"（预计百行级），轴、网格、图例、手势、动画全部来自 Cartesian 层——这是约 20 种类型能批量产出而不失控的关键。

## 5. 阶段划分（每阶段独立 spec + plan）

| 阶段 | 内容 | 学习重点 |
|---|---|---|
| **0** | Cartesian 基础层 + **折线图**（首个载体） | 值域计算、nice ticks、轴渲染、坐标映射 |
| **1** | 柱状图 / 条形图（含负值、堆叠） | 第二轴系形态、堆叠数学 |
| **2** | 样条曲线 + 面积图（渐变填充） | Catmull-Rom / 贝塞尔平滑算法 |
| **3** | 多系列 + 图例 + 混合图 | series 抽象、图例布局与交互 |
| **4** | 单指拖动平移 + 捏合缩放 + crosshair + 动态数据更新（流式追加） | viewport 坐标变换、增量渲染 |
| **5** | 散点图 + 气泡图 | 点命中、气泡尺寸映射 |
| **6** | 饼图 + 仪表盘 | 弧形几何、极坐标、label 碰撞 |
| **7** | 漏斗图 + 金字塔图 | 梯形几何、占比布局 |
| **8** | 范围图 / 瀑布图 / 箱线图 / 误差线 | 统计类数据建模 |
| **9** | 动画体系完善：数据过渡动画、排序动画、更多 easing | 插值驱动帧动画深化 |
| **10** | 产品化收尾：OCBridge + SwiftUI 封装统一补齐、全量 demo、SelfTest 盘点 | 工程化 |

说明：

- 非轴系类型（饼/仪表/漏斗/金字塔）不依赖 Cartesian 层，可按需提前或穿插；上表为按学习价值的推荐顺序。
- 每阶段开工前单独写 spec + plan（沿用现有 docs/superpowers 工作流），本文档只锁定路线图与架构骨架。
- 阶段 0 的折线图是轴系基础层的"首个用户"，其验收标准 = 基础层可复用性（阶段 1 的柱状图无需改动 Cartesian 层即可实现）。
- **每个新图表类型的 demo 页标配「实时属性调整面板」**（见 §8.3），作为该阶段视觉验收的交互手段。

## 6. Cartesian 轴系基础层组件设计

四层结构，延续"模型纯 struct / 几何纯函数 / 渲染薄层"风格：

### ① 数据模型层（纯 struct）

| 类型 | 职责 | 对标 AAChartKit |
|---|---|---|
| `CartesianSeriesElement` | 系列数据：name、data、颜色、stack 分组 | `AASeriesElement` |

`data` 形态：阶段 0 起步为等距数值数组（`[Double]`，类目轴对位）；x-y 点对形态随散点/气泡图（阶段 5）扩展为关联枚举，具体在对应阶段 spec 中定。
| `CartesianAxisModel` | 轴配置：kind（`.value` / `.category`）、min/max（nil = 自动）、tickInterval、label formatter | `AAXAxisModel` / `AAYAxisModel` 的常用子集 |
| `CartesianChartModel` | title/subtitle + series 数组 + xAxis/yAxis + 图例配置 | `AAChartModel` 的常用子集 |

只映射常用配置，不全量对标 Highcharts options 面。

### ② 几何计算层（纯函数，全部进 ChartSelfTest）

| 类型 | 职责 | 学习价值 |
|---|---|---|
| `NiceScaleGenerator` | nice numbers 刻度算法：从原始值域生成美化刻度（1/2/2.5/5/10 × 10ⁿ 步长） | 经典算法，避免"轴上出现 3.7142 刻度" |
| `CartesianGeometry` | 值 ↔ 屏幕坐标映射（**所有映射经过 viewport**）、plot 区 margin 计算（轴 label 宽度自适应） | 坐标变换核心 |
| `SplineGeometry` | Catmull-Rom → 三次贝塞尔控制点换算 | 平滑曲线算法（阶段 2） |

### ③ 渲染层（模板方法模式）

- `CartesianRendererBase`：编排统一渲染流程——布局 plot 区 → 网格 → 轴 → **调子类 `drawSeries(in:plotArea:)`** → 图例；命中测试由子类实现 `seriesHitTest`。
- 各类型薄 Renderer：`LineChartRenderer`、`ColumnChartRenderer` 等只写"如何把 series 画进 plot 区"。
- `AxisRenderer` / `GridRenderer` / `LegendRenderer`：独立小组件，被基类编排。

### ④ 交互层

| 类型 | 职责 |
|---|---|
| `CartesianViewport` | 可见窗口状态（xMin/xMax/yMin/yMax，可设边界约束）。**缩放、平移、流式追加三个功能的共同底座**：手势改 viewport，坐标映射读 viewport，数据追加推动 viewport |
| `CartesianPanZoomHandler` | 单指拖动 = 平移，双指捏合 = 缩放；挂接现有 `HYMChartInteraction` 手势体系 |
| crosshair | 十字准线 + 轴 label 高亮，与现有 tooltip 三层机制并存 |

## 7. 横切能力设计

### 7.1 手势（与 AAChartKit 的 deliberate 区别）

- AAChartKit/Highcharts：双指平移缩放（WebView 中单指被页面滚动占用）。
- 本库：**单指拖动 = 平移，双指捏合 = 缩放**——原生 iOS 手感（参照股票 App），WebView 方案做不到的自由。
- 图表嵌于 UIScrollView 时的手势冲突：提供交互开关（复用现有 `HYMChartInteraction` 配置），冲突协调细节在阶段 4 的 spec 中细化。

### 7.2 动态数据更新

- `updateSeries(data:)`：仅刷新数据，不重建轴系；值域未越界则跳过刻度重算（增量渲染）。
- `appendData(_:series:)`：流式追加 + viewport 窗口滚动（滚动更新效果）。

### 7.3 动画体系

- 入场动画：复用 `HYMChartValueAnimator`（DisplayLink + progress 0→1），各类型定义 progress 绘制（折线 strokeEnd 生长、柱从零升起、扇形角度展开——雷达/热力图已有先例）。
- 数据过渡动画（阶段 9）：新旧数据集插值。
- 排序动画（阶段 9）：柱状图重排。

### 7.4 图例与混合图（阶段 3）

- `LegendRenderer`：布局（横/纵排、自动换行）、点击切换系列显隐。
- 混合图：series 协议天然支持不同类型 series 同图共轴渲染。

## 8. API 形态与数据流

### 8.1 API 形态

```swift
// 阶段 0 完成后，画一张折线图的全部代码：
let model = CartesianChartModel(
    title: "月度营收",
    series: [CartesianSeriesElement(name: "2025", data: [120, 200, 160, 240])],
    yAxis: CartesianAxisModel(kind: .value)
)
let chartView = HYMChartView<LineChartRenderer>()
chartView.configure(model: model, theme: CartesianChartTheme())

// 阶段 4 追加：
chartView.renderer.updateSeries(data: newData)   // 仅刷新数据
chartView.renderer.appendData(220, series: 0)    // 流式追加 + 窗口滚动
```

### 8.2 数据流（单向，三条路径汇入同一渲染管线）

1. **配置**：`configure(model:theme:)` → NiceScale 计算值域 → plot 区/轴/刻度布局 → CALayer 绘制。
2. **手势**：拖动/捏合 → 更新 `CartesianViewport` → 坐标映射随之变化 → 仅重绘 plot 区（刻度变化才重算轴）。
3. **数据**：`updateSeries`/`appendData` → 值域未越界则跳过重算刻度 → 增量重绘。

命中测试复用现有 `HitTarget`/`HitContext` 体系，弹窗走现有三层 tooltip 机制（内置 text tooltip → `onHitLocated` → `popupContentProvider`），不动。

### 8.3 Demo 页实时属性调整面板（每个新图表 demo 的标配）

**需求**：demo 页把该图表 Model / Theme 的**所有可调属性**暴露成一个实时调整面板，改动即时重绘，方便肉眼验收样式与参数效果。

**设计**：

- 做一个轻量通用面板组件 `ChartDemoPanel`（SwiftUI，demo 专用，**不进入 SDK API 承诺面**），声明式描述属性项——每项绑定一个 `get/set` 闭包，面板按属性类型自动选择控件：
  - 数值/范围 → `Slider`（带范围与步长）
  - 枚举/布尔 → `Picker` / `Toggle`
  - 颜色 → 颜色选择器
  - 字体/线宽等 → `Stepper` + 数值显示
- 属性变更回调统一走 `configure(model:theme:)` 或 `updateSeries(data:)` 的增量路径（顺带验证数据流 §8.2 的正确性——面板本身成为数据流的压力测试工具）。
- demo 展示图表所需的最小 `UIViewRepresentable`（仅 model/theme/onHit 基础参数）属于 **demo 配套**，随每阶段提供——这与"SwiftUI 封装后置"不矛盾：后置到阶段 10 的是**正式 SDK 级封装**（完备参数面 + 文档 + API 承诺）。
- 每个 demo 页布局：上方图表 + 下方可滚动属性面板（`Form`/分组 `Section`），与现有 `RadarChartStyleDemo` 的手动调样式做法一致，但控件由面板统一生成，不逐个手写。
- 面板随阶段演进：阶段 0 实现基础控件集，后续阶段按新属性类型按需扩展（如阶段 3 的图例配置、阶段 4 的手势开关）。

## 9. 错误处理

`HYMChartError` 扩展枚举：空 series、非法值域（NaN / max ≤ min）等。

- Release：容错降级——空数据画空坐标系不崩溃。
- DEBUG：ChartSelfTest 断言。

## 10. 测试策略

延续项目现实约束（无 test target，改 pbxproj 风险高）：

- 每阶段的**纯函数**全部进 `ChartSelfTest` 加断言：NiceScale 刻度生成、viewport 正/逆变换、Spline 控制点、堆叠累计、饼图 label 碰撞检测。
- demo 页即视觉验收：主 App `ContentView` 列表持续追加每类图表 demo。

## 11. 目录结构（阶段 0 落地形态）

```
SwiftFunctionProject/Charts/
├── Cartesian/
│   ├── CartesianChartModel.swift
│   ├── CartesianSeriesElement.swift
│   ├── CartesianAxisModel.swift
│   ├── CartesianChartTheme.swift
│   ├── NiceScaleGenerator.swift
│   ├── CartesianGeometry.swift
│   ├── CartesianViewport.swift            # 阶段 4（阶段 0 先以固定值域形态存在）
│   ├── CartesianRendererBase.swift
│   ├── AxisRenderer.swift
│   ├── GridRenderer.swift
│   ├── LegendRenderer.swift               # 阶段 3
│   └── CartesianPanZoomHandler.swift      # 阶段 4
├── Line/
│   └── LineChartRenderer.swift
├── SwiftUI/
│   ├── ChartDemoPanel.swift               # demo 专用实时属性面板（不属 SDK API）
│   ├── LineChart.swift                    # 最小 Representable（demo 配套，正式封装阶段 10）
│   └── LineChartDemo.swift                # 图表 + 属性面板布局
└── Debug/
    └── ChartSelfTest.swift                # 持续扩展
```

## 12. 风险与开放问题

| # | 风险/问题 | 应对 |
|---|---|---|
| 1 | 阶段 0 周期偏长（基础层 + 折线图一起交付） | 折线图最小可用版先行（固定值域/无图例），基础层随阶段 1-3 逐步补全 |
| 2 | Cartesian 基类可能随类型增多膨胀 | 模板方法只编排不绘制；轴/图例/手势独立组件；出现第三种重复时才上提 |
| 3 | 单指拖动与外层 UIScrollView 手势冲突 | 交互开关 + 手势协调留到阶段 4 spec 细化 |
| 4 | 后置的 OCBridge 统一补齐时 API 已定型，桥接面可能偏大 | 类型设计时保持桥接友好（避免 OC 无法表达的泛型/闭包出现在关键路径）；阶段 10 前做一次盘点 |
| 5 | 路线图跨度长，中途优先级可能变化 | 每阶段独立 spec + plan，阶段顺序可重排，非轴系类型可穿插 |
| 6 | 属性面板需随 API 演进持续维护，可能滞后 | 面板条目声明式绑定 get/set，新增属性只需补一行描述；阶段验收清单含"面板覆盖全部可调属性" |
