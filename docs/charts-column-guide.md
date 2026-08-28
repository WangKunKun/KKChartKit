# HYMCharts 柱状图与条形图使用指南

> 快速上手柱系图表：柱状图（Column Chart）与条形图（Bar Chart）。
> 适用版本：2026-08-27（阶段 1 交付物：柱状图/条形图 + 堆叠）。

## 概述

柱状图和条形图是 HYMCharts 轴系图表的柱系实现，基于 Cartesian 轴系基础层提供：
- 垂直/水平两种柱体方向
- 正负值混合渲染（零轴自适应）
- 普通堆叠（累积高度）
- 柱体样式定制（宽度、圆角、边框）
- 入场动画（柱体从零轴升起）

---

## 30 秒上手

### SwiftUI 方式（推荐）

```swift
import SwiftUI

struct ColumnChartView: View {
    let model = CartesianChartModel(
        title: "季度销售额",
        series: [CartesianSeriesElement(
            name: "Q1-Q4",
            data: [32, 45, 38, 52]
        )]
    )

    var body: some View {
        ColumnChart(model: model)
            .frame(height: 280)
            .padding()
    }
}
```

### UIKit 方式

```swift
import UIKit

let chart = HYMChartView<ColumnChartRenderer>(frame: CGRect(x: 0, y: 0, width: 320, height: 280))
let model = CartesianChartModel(
    title: "季度销售额",
    series: [CartesianSeriesElement(name: "Q1-Q4", data: [32, 45, 38, 52])]
)
chart.configure(model: model, theme: CartesianChartTheme())
view.addSubview(chart)
```

### 条形图（水平版本）

```swift
// 仅需将 ColumnChart 替换为 BarChart
BarChart(model: model)
    .frame(height: 280)
```

---

## 数据模型

### CartesianChartModel

轴系图表数据模型（柱/条与折线共用）。

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `title` | `String?` | `nil` | 图表标题 |
| `series` | `[CartesianSeriesElement]` | 必填 | 数据系列数组 |
| `stacking` | `StackConfig?` | `nil` | 堆叠配置（nil = 不堆叠） |
| `xAxis` | `CartesianAxisModel` | `.category(labels: [])` | X 轴配置 |
| `yAxis` | `CartesianAxisModel` | `.value` | Y 轴配置 |

### StackConfig

堆叠配置枚举。

| 选项 | 说明 |
|---|---|
| `.none` | 不堆叠（默认） |
| `.normal` | 普通堆叠（阶段 1 实现） |
| `.percent` | 百分比堆叠（预留） |
| `.grouped(groupCount:)` | 分组堆叠（预留） |

### CartesianSeriesElement

单个数据系列。

| 属性 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `name` | `String` | 必填 | 系列名称 |
| `data` | `[Double]` | 必填 | 数值数组 |
| `color` | `UIColor?` | `nil` | 系列颜色 |
| `negativeColor` | `UIColor?` | `nil` | 负值覆盖颜色 |

---

## 主题定制

### 柱体外观

```swift
var theme = CartesianChartTheme()
theme.columnWidthRatio = 0.8          // 柱体宽度比例（0.1-1.0）
theme.columnCornerRadius = 4          // 圆角半径
theme.columnBorderColor = .black       // 边框颜色
theme.columnBorderWidth = 1            // 边框宽度
```

### 堆叠样式

```swift
theme.stackSeparatorColor = .white     // 分隔线颜色
theme.stackSeparatorWidth = 1          // 分隔线宽度
```

### 动画配置

```swift
theme.showsColumnEntranceAnimation = true  // 入场动画开关
```

---

## 堆叠功能

### 普通堆叠

```swift
let model = CartesianChartModel(
    title: "季度销售对比",
    series: [
        CartesianSeriesElement(name: "2025", data: [30, 40, 35, 50]),
        CartesianSeriesElement(name: "2026", data: [45, 55, 48, 62]),
    ],
    stacking: .normal  // 启用普通堆叠
)
```

### 负值堆叠

正值向上累积，负值向下累积，零轴是分隔线。

```swift
let series = [
    CartesianSeriesElement(name: "收入", data: [100, 120, 80]),
    CartesianSeriesElement(name: "支出", data: [-30, -40, -25]),
]
// 堆叠时：收入向上，支出向下，零轴在中间
```

### 双值轴

末系列可绑定右轴（独立值域与刻度）；堆叠链按轴分组——同 `yAxisIndex` 的系列才互相累计，跨轴不混叠，可组合出「主轴堆叠 + 次轴独立柱」：

```swift
let model = CartesianChartModel(
    series: [
        CartesianSeriesElement(name: "系列1", data: [30, 50, 20], color: .systemBlue),
        CartesianSeriesElement(name: "系列2", data: [20, 30, 25], color: .systemGreen),
        CartesianSeriesElement(name: "目标", data: [60, 40, 70], color: .systemOrange, yAxisIndex: 1)
    ],
    secondaryYAxis: CartesianAxisModel(kind: .value, min: 0, max: 100),
    stacking: .normal)   // 系列1/2 主轴堆叠，目标系列按次轴独立
```

命中弹窗的 `ColumnHitTarget.yAxisIndex` 标记所属轴。

---

## 负值处理

### 负值柱体方向

柱体自动根据数据正负从零轴向相反方向延伸：

```swift
let data = [32, -15, 48, -22, 61]
// 正值：柱体从零轴向上
// 负值：柱体从零轴向下
```

### 负值颜色覆盖

```swift
let series = CartesianSeriesElement(
    name: "利润",
    data: [32, -15, 48, -22, 61],
    negativeColor: .systemRed  // 负值用红色
)
```

---

## 交互功能

### 点击命中

```swift
ColumnChart(model: model) { target, gesture in
    print("命中系列\(target.seriesIndex), 项\(target.categoryIndex): \(target.value)")
}
```

### Tooltip

柱状图默认启用内置 tooltip，点击柱体显示数据信息。

```swift
theme.showsTooltipOnHit = true  // 开启点击弹窗（默认开启）
```

---

## 完整示例

### 柱状图 + 堆叠 + 样式

```swift
struct AdvancedColumnChart: View {
    let model = CartesianChartModel(
        title: "2025 vs 2026 季度销售额",
        series: [
            CartesianSeriesElement(name: "2025", data: [30, 40, 35, 50], color: .systemBlue),
            CartesianSeriesElement(name: "2026", data: [45, 55, 48, 62], color: .systemGreen),
        ],
        stacking: .normal
    )

    var theme: CartesianChartTheme {
        var t = CartesianChartTheme()
        t.columnWidthRatio = 0.7
        t.columnCornerRadius = 6
        t.stackSeparatorColor = .white
        t.stackSeparatorWidth = 2
        t.showsColumnEntranceAnimation = true
        return t
    }

    var body: some View {
        ColumnChart(model: model, theme: theme) { target, gesture in
            print("命中: \(target.identifier)")
        }
        .frame(height: 300)
        .padding()
        .navigationTitle("堆叠柱状图")
    }
}
```

### 条形图 + 负值

```swift
struct BarChartWithNegatives: View {
    let model = CartesianChartModel(
        title: "月度收支",
        series: [
            CartesianSeriesElement(
                name: "净额",
                data: [100, -30, 120, -45, 80],
                negativeColor: .systemRed
            ),
        ]
    )

    var body: some View {
        BarChart(model: model)
            .frame(height: 280)
            .navigationTitle("条形图（含负值）")
    }
}
```

---

## 属性说明

### 柱体宽度比例（columnWidthRatio）

- 范围：0.1 - 1.0
- 默认：0.8（80% 宽度，20% 间距）
- 含义：每个柱体占据其 slot 的比例

示例：
```swift
theme.columnWidthRatio = 0.5  // 柱体占 50%，间距 50%
theme.columnWidthRatio = 1.0  // 柱体占 100%，无间距
```

### 圆角半径（columnCornerRadius）

- 范围：0 - 无上限
- 默认：4
- 含义：柱体顶部的圆角半径（正值顶部，负值底部）

---

## 常见问题

### Q: 柱状图和条形图有什么区别？

A: 方向不同。柱状图（ColumnChart）是垂直柱体，条形图（BarChart）是水平柱体。API 完全相同，仅方向不同。

### Q: 如何实现分组柱状图（并排显示）？

A: 阶段 1 暂不支持，计划在阶段 3（混合图）中实现。当前只能通过堆叠实现多系列。

### Q: 负值柱体的零轴位置如何确定？

A: 零轴位置根据数据范围自适应：
- 全正值：零轴在底部
- 全负值：零轴在顶部
- 混合值：零轴在中间（插值计算）

### Q: 堆叠时系列顺序如何影响渲染？

A: 系列按数组顺序堆叠。第一个系列在最底部，最后一个系列在最顶部。

---

**版本**：2026-08-27（阶段 1）
**后续计划**：阶段 2（样条曲线 + 面积图），阶段 3（混合图 + 图例）