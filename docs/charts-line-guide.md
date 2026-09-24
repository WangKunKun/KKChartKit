# HYMCharts 折线图使用指南

> 高密度直线/面积图已支持可选 Min/Max 降采样，保留原始命中；配置和限制见 [降采样指南](charts-line-sampling-guide.md)。

> 内置图例已接入：详见 [图例、显隐与尺寸分配](charts-legend-guide.md)。

> 快速上手轴系图表的首个类型：折线图（Line Chart）。
> 更新：2026-09-24。当前范围与限制见 [能力清单](charts-capability-status.md)。

## 概述

折线图是 HYMCharts 轴系图表的首个实现，基于 Cartesian 轴系基础层（`CartesianRendererBase`）提供：
- 等距类目 X 轴 + 数值 Y 轴（自动 nice scale）
- 多系列直线/平滑/阶梯、面积与堆叠，系列可独立设色
- 数据点/整列提示、双向准线与缩放平移；UIKit 容器支持三层弹窗，SwiftUI LineChart 暂未完整透传自定义内容入口
- 入场动画（折线 strokeEnd 生长）

---

## 30 秒上手

### SwiftUI 方式（推荐）

```swift
import SwiftUI

struct LineChartView: View {
    let model = CartesianChartModel(
        title: "月度营收（万元）",
        series: [CartesianSeriesElement(
            name: "2026",
            data: [32, 45, 38, 52, 48, 61, 55, 67]
        )]
    )

    var body: some View {
        LineChart(model: model) { target, gesture in
            print("命中点 \(target.index): \(target.value)")
        }
        .frame(height: 280)
        .padding()
    }
}
```

### UIKit 方式

```swift
import UIKit

let chart = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 320, height: 280))
let model = CartesianChartModel(
    title: "月度营收（万元）",
    series: [CartesianSeriesElement(name: "2026", data: [32, 45, 38, 52, 48, 61, 55, 67])]
)
chart.configure(model: model, theme: CartesianChartTheme())
view.addSubview(chart)
```

### 主题定制

```swift
var theme = CartesianChartTheme()
theme.seriesColor = .systemBlue
theme.lineWidth = 3
theme.showsPoints = true
theme.pointRadius = 4
theme.showsEntranceAnimation = true
chart.configure(model: model, theme: theme)
```

---

## 数据模型

### CartesianChartModel

轴系图表数据模型（折线/柱状等共用）。

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `title` | `String?` | `nil` | 图表标题（渲染于顶部居中） |
| `series` | `[CartesianSeriesElement]` | 必填 | 数据系列数组（支持多个系列） |
| `xAxis` | `CartesianAxisModel` | `.category(labels: [])` | X 轴配置（阶段 0 仅类目轴） |
| `yAxis` | `CartesianAxisModel` | `.value` | Y 轴配置（数值轴） |

### CartesianSeriesElement

单个数据系列（等距数值数组，按索引对位类目）。

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `name` | `String` | 必填 | 系列名称（用于 tooltip/图例） |
| `data` | `[Double]` | 必填 | 数值数组（空数组跳过渲染） |
| `color` | `UIColor?` | `nil` | 系列颜色（nil 用主题默认） |

### CartesianAxisModel

轴配置（x/y 通用）。

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `kind` | `CartesianAxisKind` | 必填 | 轴类型（`.category` 或 `.value`） |
| `min` | `Double?` | `nil` | 显式值域下界（nil = 自动） |
| `max` | `Double?` | `nil` | 显式值域上界（nil = 自动） |
| `tickInterval` | `Double?` | `nil` | 显式刻度步长（须与 min/max 同显式） |

#### CartesianAxisKind

```swift
public enum CartesianAxisKind {
    /// 类目轴。labels 为空时自动生成 "1"..."n"（n = 最长 series 点数）。
    case category(labels: [String])
    /// 数值轴（阶段 5 散点图实现 x 向数值映射；阶段 0 按类目处理）。
    case value
}
```

### Y 轴值域规则

1. **显式优先**：若 `yAxis.min`/`yAxis.max` 任一非 nil，则优先使用显式值。
2. **自动 nice scale**：全 nil 时调用 `NiceScaleGenerator` 自动生成美观刻度（参考 Highcharts）。
3. **全非负数据从 0 起**：数据全 ≥ 0 时，自动下界为 0（避免"悬空"折线）。
4. **显式 tickInterval 须显式 min/max**：若 `tickInterval` 非 nil，则 `min`/`max` 必须都非 nil，否则忽略。

---

## 主题全属性表

### CartesianChartTheme

轴系图表主题（纯值类型；折线/柱状等共用）。

| 分类 | 属性 | 类型 | 默认值 | 作用 |
|---|---|---|---|---|
| **整体** | `backgroundColor` | `UIColor?` | `nil` | 背景色（nil 透明） |
| | `backgroundCornerRadius` | `CGFloat` | `0` | 背景圆角半径 |
| | `contentInset` | `UIEdgeInsets` | `(12,12,12,12)` | 内容边距 |
| | `titleColor` | `UIColor` | `#3B4045` | 标题文字颜色 |
| | `titleFont` | `UIFont` | `system(14,semibold)` | 标题字体 |
| **网格** | `showsHorizontalGridlines` | `Bool` | `true` | 是否显示横向网格线 |
| | `showsVerticalGridlines` | `Bool` | `false` | 是否显示纵向网格线 |
| | `gridColor` | `UIColor` | `#E5E5E5` | 网格线颜色 |
| | `gridLineWidth` | `CGFloat` | `0.5` | 网格线宽度 |
| **轴** | `axisLineColor` | `UIColor` | `#C7C7C7` | 轴线颜色 |
| | `axisLineWidth` | `CGFloat` | `1` | 轴线宽度 |
| | `tickLabelColor` | `UIColor` | `#596169` | 刻度标签颜色 |
| | `tickLabelFont` | `UIFont` | `system(10)` | 刕度标签字体 |
| | `axisLabelGap` | `CGFloat` | `4` | 刻度标签与 plot 区间距 |
| **系列** | `seriesColor` | `UIColor` | `#216E39` | 系列默认颜色 |
| | `lineWidth` | `CGFloat` | `2` | 折线宽度 |
| | `showsPoints` | `Bool` | `true` | 是否绘制数据点圆点 |
| | `pointRadius` | `CGFloat` | `3` | 数据点半径 |
| | `pointColor` | `UIColor?` | `nil` | 数据点颜色（nil 用系列色） |
| **行为** | `showsEntranceAnimation` | `Bool` | `true` | 是否播放入场动画 |
| | `showsTooltipOnHit` | `Bool` | `true` | 是否显示内置 tooltip |

---

## 命中与弹窗

### LineHitTarget

折线图命中目标（点中数据点时产生）。

| 属性 | 类型 | 说明 |
|---|---|---|
| `identifier` | `String` | 唯一标识（格式 "系列名:索引"） |
| `index` | `Int` | 数据点索引（0-based） |
| `seriesIndex` | `Int` | 系列索引（与输入数组一致） |
| `value` | `Double` | 命中数据点的值 |
| `tooltipText` | `String?` | 内置 tooltip 文本（格式 "系列名 · 格式化值"） |

### 容器三层弹窗机制

**一次命中互斥选用**（从高到低优先级）：

1. **便利层**（`popup` / `popupContentProvider`）：SDK 接管定位/显隐，外部只提供内容 view。
2. **低层**（`onHitLocated`）：外部全权控制（拿到位置自己显示）。
3. **内置 text tooltip**（`showsTooltipOnHit=true`）：SDK 显示简单文本提示。

> 详细用法见 `docs/charts-popup-guide.md`（热力图/雷达图已实现，折线图复用同一机制）。

### hitFrame / tooltipAnchor

- **`hitFrame`**：数据点命中区域（view 坐标系，正方形 = 命中半径直径）。
- **`tooltipAnchor`**：弹窗锚点（`HYMChartTooltipAnchor(frame:preferredPlacements:)`，用于 `popupContentProvider` 智能定位）。

折线图的锚点 `preferredPlacements` 固定为 `[.top, .bottom]`（上下避让）。

---

## 双值轴

温度挂左轴、湿度挂右轴：系列用 `yAxisIndex` 声明绑定，`secondaryYAxis` 配置次轴（独立值域与刻度，右侧显示）。两轴命中弹窗自动带 `(右轴)` 标记。

```swift
let model = CartesianChartModel(
    series: [
        CartesianSeriesElement(name: "温度(℃)", data: [5, 15, 25, 20, 10], color: .systemOrange),
        CartesianSeriesElement(name: "湿度(%)", data: [40, 70, 90, 60, 30], color: .systemBlue, yAxisIndex: 1)
    ],
    secondaryYAxis: CartesianAxisModel(kind: .value, min: 0, max: 100))
```

- `yAxisIndex`：0 = 主轴（左），1 = 次轴（右）；其余值回落主轴
- 次轴网格默认关闭，`secondaryYAxis.showsGridlines = true` 可开启
- 次轴负值零轴按次轴值域独立计算

## 堆叠与面积

`stacking: .normal` 时折线画累计值（按轴分组累计，双轴不混叠）；配合 `showsArea` 得到分层面积图——系列 i 的面积从同轴前一累计线填到自己累计线，每系列独立颜色渐变。命中报累计值（与柱状图一致）。

**正负分开堆叠（上下镜像）**：正值点只与正值累计（从 0 向上），负值点只与负值累计（从 0 向下）——收入/支出、人口金字塔等上下两组形态，与 AAChartKit/Highcharts 同款语义：

```swift
let model = CartesianChartModel(
    series: [CartesianSeriesElement(name: "收入", data: [40, 60, 50], color: .systemBlue),
             CartesianSeriesElement(name: "支出", data: [-30, -50, -20], color: .systemOrange)],
    stacking: .normal)   // 收入向上叠、支出向下叠，面积在 0 线两侧分层
```

```swift
var theme = CartesianChartTheme()
theme.showsArea = true
let model = CartesianChartModel(
    series: [CartesianSeriesElement(name: "系列1", data: [20, 40, 30], color: .systemBlue),
             CartesianSeriesElement(name: "系列2", data: [10, 20, 15], color: .systemGreen)],
    stacking: .normal)
```

## 刻度自定义

值轴刻度四档优先级：`tickPositions`（显式位置）> `tickInterval`（须配显式 min/max）> `tickCount`（目标数量，nice scale）> 自动（默认 6）。`labelFormatter` 只改文本不影响位置；域外刻度自动过滤。

```swift
var y = CartesianAxisModel(kind: .value, tickCount: 3)          // 目标 3 条刻度
y.labelFormatter = { "\(Int($0))%" }                            // 刻度文本加 %
y.tickPositions = [0, 30, 60, 100]                              // 完全显式刻度（最高优先）
```

---

## 当前边界与后续

已有多系列、平滑/阶梯、面积、堆叠、双轴、标线/色带、数据标签和 x/y/xy 缩放平移。
惯性减速目前仅 X 轴；内置图例与显隐已实现（默认关闭）；混合图、真实数值/时间 X、增量与流式刷新尚未实现。
`configure` 保留重置视口的旧语义；新增 `update` 默认保留窗口，SwiftUI LineChart 也默认保留。
数据/样式更新、显式重置和回调同步见 [更新指南](charts-update-guide.md)。

后续按 [现状与路线图](2026-09-24-charts-status-and-roadmap.md) 推进；旧阶段记录保留在 specs/plans 中。
完整适配端差异与验证状态见 [能力清单](charts-capability-status.md)。

---

## 相关文档

- **设计**：`docs/superpowers/specs/2026-08-26-chart-parity-roadmap-design.md`（路线图）
- **弹窗机制**：`docs/charts-popup-guide.md`（三层命中弹窗）
- **自检**：`SwiftFunctionProject/ChartSelfTest.swift`（运行期断言验证）
- **Demo**：`SwiftFunctionProject/Charts/SwiftUI/LineChartDemo.swift`（实时属性面板）
