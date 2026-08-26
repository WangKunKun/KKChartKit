# HYMCharts 折线图使用指南

> 快速上手轴系图表的首个类型：折线图（Line Chart）。
> 适用版本：2026-08-26（阶段 0 交付物：Cartesian 轴系基础层 + 折线图）。

## 概述

折线图是 HYMCharts 轴系图表的首个实现，基于 Cartesian 轴系基础层（`CartesianRendererBase`）提供：
- 等距类目 X 轴 + 数值 Y 轴（自动 nice scale）
- 单系列数据可视化（多系列配色阶段 3）
- 数据点命中 + 内置 tooltip/自定义弹窗（三层机制）
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
| `series` | `[CartesianSeriesElement]` | 必填 | 数据系列数组（阶段 0 主用单系列） |
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
| `seriesIndex` | `Int` | 系列索引（阶段 0 固定为 0） |
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

## 阶段 0 边界

**已实现**（阶段 0）：
- ✅ 类目 X 轴（自动数字标签或显式 labels）
- ✅ 数值 Y 轴（nice scale 自动刻度）
- ✅ 单系列折线渲染（strokeEnd 生长动画）
- ✅ 数据点命中 + 内置 tooltip/自定义弹窗
- ✅ 完整主题系统（26 个可调属性）

**未实现**（路线图后续阶段）：
- ❌ 多系列配色（阶段 3）
- ❌ 图例/手势/动态刷新（阶段 4）
- ❌ 数值 X 轴/散点图（阶段 5）
- ❌ CartesianViewport 缩放/平移底座（阶段 4）

> 阶段 4 起，`CartesianViewport` 将成为缩放/平移底座（`xMin/xMax/yMin/yMax` 可动态调整）。

---

## 下一步

阶段 1（柱状图/条形图）即将启动：`docs/superpowers/specs/2026-08-26-chart-parity-roadmap-design.md` §6.1。

柱状图将在不修改 Cartesian 层的前提下实现（`ColumnChartRenderer` 复用 `CartesianRendererBase`，仅重写 `drawSeries`/`seriesHitTest`），验证轴系基础层的可扩展性。

---

## 相关文档

- **设计**：`docs/superpowers/specs/2026-08-26-chart-parity-roadmap-design.md`（路线图）
- **弹窗机制**：`docs/charts-popup-guide.md`（三层命中弹窗）
- **自检**：`SwiftFunctionProject/ChartSelfTest.swift`（运行期断言验证）
- **Demo**：`SwiftFunctionProject/Charts/SwiftUI/LineChartDemo.swift`（实时属性面板）
