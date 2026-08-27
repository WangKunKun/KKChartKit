# HYMCharts 阶段 1 设计：柱状图/条形图 + 堆叠

> 日期：2026-08-27
> 状态：已审阅
> 负责人：wangkun
> 前序文档：
> - `specs/2026-08-26-chart-parity-roadmap-design.md`（对标 AAChartKit 全量路线图）
> - `specs/2026-07-22-chart-framework-design.md`（HYMCharts 框架总设计）
> - `plans/2026-08-26-cartesian-foundation-line-chart.md`（阶段 0 实施计划）

## 1. 概述与目标

在阶段 0 完成的 Cartesian 轴系基础层之上，实现**柱状图（Column）**、**条形图（Bar）**与**普通堆叠**功能，对标 AAChartKit 的核心柱系能力。

**核心目标**：
- 提供垂直/水平两种柱系图表，支持正负值混合渲染
- 实现普通堆叠（累积高度），预留百分比/分组堆叠扩展点
- 完全对齐 AAChartKit 行为（零轴自适应、柱体宽度比例、堆叠对齐）
- 保持 Renderer 薄层特性（~150 行），复杂逻辑集中到几何层

**学习价值**：
- 堆叠数学：正向/负向累积、锯齿 series 归一化
- 零轴几何：自适应零轴位置计算、柱体双向延伸
- 坐标镜像：水平图表的 X/Y 坐标互换逻辑

---

## 2. 功能范围

### 包含

| 功能 | 说明 | 对标 AAChartKit |
|---|---|---|
| **柱状图（Column）** | 垂直柱体，Y 轴数值，X 轴类目 | `column` |
| **条形图（Bar）** | 水平柱体，X 轴数值，Y 轴类目 | `bar` |
| **负值支持** | 零轴自适应位置，正负向相反延伸 | ✅ |
| **普通堆叠** | 多系列累积高度 | `stacking: .normal` |
| **锯齿 series** | 不同长度 series 归一化对位 | ✅ |
| **柱体样式** | 宽度比例、圆角、边框 | `borderRadius`, `borderWidth` |
| **堆叠样式** | 分隔线、颜色 | ✅ |
| **入场动画** | 柱体从零轴升起 | ✅ |
| **命中测试** | 点击柱体返回系列/索引 | ✅ |
| **实时属性面板** | demo 配套（规格 §8.3） | - |

### 不包含（后续阶段）

| 功能 | 计划阶段 |
|---|---|
| 百分比堆叠 | 阶段 X |
| 分组堆叠（并排柱） | 阶段 3（混合图） |
| 多系列图例 | 阶段 3 |
| 手势缩放/平移 | 阶段 4 |

---

## 3. 核心决策

### 3.1 堆叠策略

**选择**：普通堆叠 + 扩展点预留

**理由**：
- 阶段 1 重点建立柱系渲染机制和负值处理
- 普通堆叠覆盖 80% 使用场景
- StackConfig 枚举预留 `percent` / `grouped` 入口

### 3.2 数据模型

**选择**：对齐 AAChartKit（每个数据点 = 一个柱体）

**理由**：
- 与现有 `CartesianSeriesElement` 完全兼容
- 堆叠场景下每个类目位置只有一个累积柱，符合直觉
- 避免多系列并排（分组柱）增加当前阶段复杂度

### 3.3 图表组织

**选择**：ColumnChartRenderer + BarChartRenderer 独立

**理由**：
- 职责单一，各自专注
- 虽然"旋转 90 度"听起来简单，但轴标签位置、柱体排列、交互区域都需要镜像处理
- 可在 CartesianGeometry 中提供共享计算函数

### 3.4 负值处理

**选择**：完全对齐 AAChartKit 行为

**行为**：
- 零轴位置根据数据范围自适应（正值区间时在底部，负值区间时在顶部）
- 正值柱从零轴向上延伸
- 负值柱从零轴向下延伸
- 堆叠时正值向上累积、负值向下累积

**理由**：
- 用户期望行为，零轴是"基线"概念
- CartesianViewport 已支持任意值域，零轴位置计算可复用
- 负值数据的可视化价值在于"相对于零的关系"

### 3.5 架构方案

**选择**：共享几何层（方案 A）

**架构**：
```
CartesianGeometry（扩展 ~+200 行）
├── 零轴位置计算（zeroAxisPosition）
├── 堆叠累计值（stackedValues）
└── 柱体坐标计算（columnRect / barRect）

ColumnChartRenderer（薄层，~150 行）
└── drawSeries() 调用 columnRect()

BarChartRenderer（薄层，~150 行）
└── drawSeries() 调用 barRect()
```

**理由**：
- 符合现有"几何纯函数"风格
- 零轴位置、堆叠累计等复杂逻辑只写一次
- 全部可进 ChartSelfTest，易维护

---

## 4. 数据模型设计

### 4.1 StackConfig 枚举

```swift
/// 堆叠配置（阶段 1：普通堆叠 + 扩展点预留）
public enum StackConfig {
    /// 不堆叠（默认）
    case none
    /// 普通堆叠（阶段 1 实现）
    case normal
    /// 百分比堆叠（预留，阶段 X）
    case percent
    /// 分组堆叠（预留，阶段 X）
    case grouped(groupCount: Int)
}
```

### 4.2 CartesianChartModel 扩展

```swift
public struct CartesianChartModel {
    // ... 现有属性
    /// 堆叠配置（nil = 不堆叠）
    public var stacking: StackConfig?
}
```

### 4.3 CartesianSeriesElement 扩展

```swift
public struct CartesianSeriesElement {
    public var name: String
    public var data: [Double]
    public var color: UIColor?

    /// 负值数据点的覆盖颜色（nil = 使用 color）
    public var negativeColor: UIColor?
}
```

---

## 5. 几何计算层设计

### 5.1 CartesianGeometry 新增函数

#### 零轴位置计算

```swift
extension CartesianGeometry {
    /// 零轴位置（坐标轴的 0 点在 plot 区域中的位置）
    /// - Parameters:
    ///   - viewport: 值域视口
    ///   - plotArea: plot 区域
    ///   - isHorizontal: 是否水平图表（Bar 图的 Y 轴对应数值轴）
    /// - Returns: 零轴在 plotArea 中的坐标（垂直图返回 Y，水平图返回 X）
    public static func zeroAxisPosition(
        viewport: CartesianViewport,
        plotArea: CGRect,
        isHorizontal: Bool = false
    ) -> CGFloat
}
```

**实现逻辑**：
- 垂直图（Column）：返回 Y 坐标
  - 全正数据：`plotArea.maxY`（底部）
  - 全负数据：`plotArea.minY`（顶部）
  - 混合数据：按值域插值计算
- 水平图（Bar）：返回 X 坐标（逻辑相同，X/Y 互换）

#### 堆叠累计值计算

```swift
extension CartesianGeometry {
    /// 堆叠累计值（归一化为所有 series 同长度）
    /// - Parameter series: 原始 series 数组（可能长度不一）
    /// - Returns: 累计值数组，stack[i][j] = sum(series[0...i][j])
    /// - 锯齿 series：短 series 空位补 0，长度对齐到最长 series
    public static func stackedValues(
        series: [CartesianSeriesElement]
    ) -> [[Double]]
}
```

**示例**：
```swift
let s1 = CartesianSeriesElement(name: "a", data: [10, 20, 30])
let s2 = CartesianSeriesElement(name: "b", data: [5, 15, 25])
let stacked = CartesianGeometry.stackedValues(series: [s1, s2])
// stacked = [[10, 20, 30], [15, 35, 55]]
//   系列 0：[10, 20, 30]
//   系列 1：[10+5, 20+15, 30+25] = [15, 35, 55]
```

**锯齿处理**：
```swift
let s3 = CartesianSeriesElement(name: "c", data: [100])    // 长度 1
let s4 = CartesianSeriesElement(name: "d", data: [10, 20, 30, 40])  // 长度 4
let stacked2 = CartesianGeometry.stackedValues(series: [s3, s4])
// stacked2 = [[100, 0, 0, 0], [110, 20, 30, 40]]
//   系列 0：[100, 0, 0, 0]（长度补齐）
//   系列 1：[100+10, 0+20, 0+30, 0+40]
```

#### 柱体位置计算

```swift
extension CartesianGeometry {
    /// 单个柱体位置（垂直图）
    /// - Parameters:
    ///   - dataPoint: 数据点值
    ///   - categoryIndex: 类目索引（0-based，计算柱体在 plot 中的 X 位置）
    ///   - categoryCount: 类目总数（计算柱体宽度）
    ///   - viewport: 值域视口
    ///   - plotArea: plot 区域
    ///   - theme: 主题配置（间距、圆角等）
    ///   - zeroY: 零轴 Y 坐标
    /// - Returns: 柱体的 CGRect（minY/maxY 根据 zeroY 自动确定方向）
    public static func columnRect(
        dataPoint: Double,
        categoryIndex: Int,
        categoryCount: Int,
        viewport: CartesianViewport,
        plotArea: CGRect,
        theme: CartesianChartTheme,
        zeroY: CGFloat
    ) -> CGRect

    /// 单个条形位置（水平图）
    /// 参数同 columnRect，但 zeroX 是 X 轴零位置
    public static func barRect(
        dataPoint: Double,
        categoryIndex: Int,
        categoryCount: Int,
        viewport: CartesianViewport,
        plotArea: CGRect,
        theme: CartesianChartTheme,
        zeroX: CGFloat
    ) -> CGRect
}
```

**柱体宽度计算**：
```swift
// AAChartKit 标准：柱体宽度 = plotWidth / categoryCount * 柱体比例
// 柱体间距 = (plotWidth / categoryCount) * (1 - 柱体比例)
// 默认柱体比例 = 0.8（即 80% 宽度，20% 间距）

let slotWidth = plotArea.width / CGFloat(categoryCount)
let columnWidth = slotWidth * theme.columnWidthRatio
let columnX = plotArea.minX + CGFloat(categoryIndex) * slotWidth + (slotWidth - columnWidth) / 2
```

**柱体高度计算**：
```swift
// 正值：从 zeroY 向上延伸
// 负值：从 zeroY 向下延伸

if dataPoint >= 0 {
    let height = (valueToScreen(dataPoint, viewport, plotArea) - zeroY) * progress
    return CGRect(x: columnX, y: zeroY - height, width: columnWidth, height: height)
} else {
    let height = (zeroY - valueToScreen(dataPoint, viewport, plotArea)) * progress
    return CGRect(x: columnX, y: zeroY, width: columnWidth, height: height)
}
```

---

## 6. 渲染层设计

### 6.1 ColumnChartRenderer

```swift
/// 柱状图渲染器（垂直柱体）
public final class ColumnChartRenderer: CartesianRendererBase {

    /// 子类实现：绘制 series
    override func drawSeries(
        in context: CGContext,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme
    ) {
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: viewport,
            plotArea: plotArea,
            isHorizontal: false
        )

        // 2. 如果堆叠，计算累计值
        let dataToDraw: [[Double]]
        if model.stacking == .normal {
            dataToDraw = CartesianGeometry.stackedValues(series: model.series)
        } else {
            dataToDraw = model.series.map { $0.data }
        }

        // 3. 遍历每个系列
        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let baseColor = model.series[seriesIndex].color ?? theme.seriesColor

            // 4. 遍历每个数据点，计算柱体并绘制
            for (index, value) in oneSeries.enumerated() {
                let rect = CartesianGeometry.columnRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: viewport,
                    plotArea: plotArea,
                    theme: theme,
                    zeroY: zeroY
                )

                // 负值颜色覆盖
                let color = (model.series[seriesIndex].negativeColor != nil && value < 0)
                    ? model.series[seriesIndex].negativeColor!
                    : baseColor

                // 绘制柱体（考虑圆角、边框）
                drawColumn(rect: rect, color: color, in: context, theme: theme)

                // 如果堆叠且非最后系列，绘制分隔线
                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxY, in: context, plotArea: plotArea, theme: theme)
                }
            }
        }
    }

    /// 子类实现：命中测试
    override func seriesHitTest(
        point: CGPoint,
        plotArea: CGRect,
        viewport: CartesianViewport
    ) -> HYMChartHitTarget? {
        // 反向查找：point → categoryIndex → seriesIndex → value
        guard let series = model.series.first else { return nil }

        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: viewport,
            plotArea: plotArea,
            isHorizontal: false
        )

        // 1. 确定 categoryIndex（point.x 落在哪个 slot）
        let slotWidth = plotArea.width / CGFloat(model.maxPointCount)
        let categoryIndex = Int((point.x - plotArea.minX) / slotWidth)

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        // 2. 确定系列索引（堆叠时需要判断 point.y 落在哪个柱体段）
        let dataToCheck = model.stacking == .normal
            ? CartesianGeometry.stackedValues(series: model.series)
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            let value = oneSeries[categoryIndex]
            let rect = CartesianGeometry.columnRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                categoryCount: model.maxPointCount,
                viewport: viewport,
                plotArea: plotArea,
                theme: theme,
                zeroY: zeroY
            )

            if rect.contains(point) {
                return ColumnHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex, value: value)
            }
        }

        return nil
    }

    /// 绘制单个柱体
    private func drawColumn(rect: CGRect, color: UIColor, in context: CGContext, theme: CartesianChartTheme) {
        let corners: UIRectCorner = rect.minY < theme.zeroY(for: context)
            ? [.topLeft, .topRight]    // 正值：顶部圆角
            : [.bottomLeft, .bottomRight]  // 负值：底部圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: theme.columnCornerRadius)
        context.addPath(path.cgPath)
        context.setFillColor(color.cgColor)
        context.fillPath()

        // 边框
        if let borderColor = theme.columnBorderColor {
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(theme.columnBorderWidth)
            context.strokePath()
        }
    }

    /// 绘制堆叠分隔线
    private func drawStackSeparator(at y: CGFloat, in context: CGContext, plotArea: CGRect, theme: CartesianChartTheme) {
        guard let separatorColor = theme.stackSeparatorColor else { return }

        context.move(to: CGPoint(x: plotArea.minX, y: y))
        context.addLine(to: CGPoint(x: plotArea.maxX, y: y))
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(theme.stackSeparatorWidth)
        context.strokePath()
    }
}
```

### 6.2 BarChartRenderer

```swift
/// 条形图渲染器（水平柱体）
public final class BarChartRenderer: CartesianRendererBase {

    override func drawSeries(
        in context: CGContext,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme
    ) {
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置（X 轴）
        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: viewport,
            plotArea: plotArea,
            isHorizontal: true  // 关键差异
        )

        // 2. 堆叠计算（与 Column 相同）
        let dataToDraw: [[Double]]
        if model.stacking == .normal {
            dataToDraw = CartesianGeometry.stackedValues(series: model.series)
        } else {
            dataToDraw = model.series.map { $0.data }
        }

        // 3. 绘制条形（使用 barRect 而非 columnRect）
        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let baseColor = model.series[seriesIndex].color ?? theme.seriesColor

            for (index, value) in oneSeries.enumerated() {
                let rect = CartesianGeometry.barRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: viewport,
                    plotArea: plotArea,
                    theme: theme,
                    zeroX: zeroX  // 关键差异
                )

                let color = (model.series[seriesIndex].negativeColor != nil && value < 0)
                    ? model.series[seriesIndex].negativeColor!
                    : baseColor

                drawBar(rect: rect, color: color, in: context, theme: theme)

                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxX, in: context, plotArea: plotArea, theme: theme)
                }
            }
        }
    }

    override func seriesHitTest(
        point: CGPoint,
        plotArea: CGRect,
        viewport: CartesianViewport
    ) -> HYMChartHitTarget? {
        // 水平版本的命中测试（逻辑同 Column，但 X/Y 互换）
        guard let series = model.series.first else { return nil }

        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: viewport,
            plotArea: plotArea,
            isHorizontal: true
        )

        let slotHeight = plotArea.height / CGFloat(model.maxPointCount)
        let categoryIndex = Int((point.y - plotArea.minY) / slotHeight)

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        let dataToCheck = model.stacking == .normal
            ? CartesianGeometry.stackedValues(series: model.series)
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            let value = oneSeries[categoryIndex]
            let rect = CartesianGeometry.barRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                categoryCount: model.maxPointCount,
                viewport: viewport,
                plotArea: plotArea,
                theme: theme,
                zeroX: zeroX
            )

            if rect.contains(point) {
                return BarHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex, value: value)
            }
        }

        return nil
    }

    private func drawBar(rect: CGRect, color: UIColor, in context: CGContext, theme: CartesianChartTheme) {
        // 水平版本：左右圆角
        let corners: UIRectCorner = rect.minX < theme.zeroX(for: context)
            ? [.topLeft, .bottomLeft]   // 正值：左侧圆角
            : [.topRight, .bottomRight]  // 负值：右侧圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: theme.columnCornerRadius)
        context.addPath(path.cgPath)
        context.setFillColor(color.cgColor)
        context.fillPath()

        if let borderColor = theme.columnBorderColor {
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(theme.columnBorderWidth)
            context.strokePath()
        }
    }

    private func drawStackSeparator(at x: CGFloat, in context: CGContext, plotArea: CGRect, theme: CartesianChartTheme) {
        guard let separatorColor = theme.stackSeparatorColor else { return }

        context.move(to: CGPoint(x: x, y: plotArea.minY))
        context.addLine(to: CGPoint(x: x, y: plotArea.maxY))
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(theme.stackSeparatorWidth)
        context.strokePath()
    }
}
```

---

## 7. 主题扩展设计

### 7.1 CartesianChartTheme 新增属性

```swift
extension CartesianChartTheme {
    // ===== 柱体外观 =====
    /// 柱体宽度比例（0.1 ~ 1.0，默认 0.8 = 80% 宽度，20% 间距）
    public var columnWidthRatio: CGFloat = 0.8

    /// 柱体圆角半径（默认 4）
    public var columnCornerRadius: CGFloat = 4

    /// 柱体边框颜色（nil = 无边框）
    public var columnBorderColor: UIColor?

    /// 柱体边框宽度（默认 1）
    public var columnBorderWidth: CGFloat = 1

    // ===== 堆叠样式 =====
    /// 堆叠柱体间的分隔线颜色（nil = 无分隔线）
    public var stackSeparatorColor: UIColor?

    /// 堆叠柱体间的分隔线宽度（默认 1）
    public var stackSeparatorWidth: CGFloat = 1

    // ===== 动画配置 =====
    /// 柱状图入场动画：柱体从零轴升起（默认 true）
    public var showsColumnEntranceAnimation: Bool = true
}
```

### 7.2 零轴辅助方法

```swift
extension CartesianChartTheme {
    /// 获取当前渲染上下文的零轴位置（用于判断圆角方向）
    fileprivate func zeroY(for context: CGContext) -> CGFloat {
        // 从渲染状态中获取零轴位置（在 drawSeries 中设置）
        // 简化实现：在 Renderer 中作为参数传递
        return 0  // 实际实现由 Renderer 提供
    }

    fileprivate func zeroX(for context: CGContext) -> CGFloat {
        return 0  // 同上
    }
}
```

---

## 8. 动画设计

### 8.1 入场动画

**效果**：柱体从零轴升起（Column 向上，Bar 向右）

**实现**：复用 `HYMChartValueAnimator`，progress 0 → 1

```swift
override func drawSeries(
    in context: CGContext,
    plotArea: CGRect,
    viewport: CartesianViewport,
    theme: CartesianChartTheme,
    progress: CGFloat = 1.0  // 新增参数
) {
    for rect in columnRects {
        // 计算升起过程中的矩形
        let animatedRect: CGRect
        if rect.minY < zeroY {
            // 正值：从 zeroY 降到 minY
            let currentHeight = (zeroY - rect.minY) * progress
            animatedRect = CGRect(
                x: rect.minX,
                y: zeroY - currentHeight,
                width: rect.width,
                height: currentHeight
            )
        } else {
            // 负值：从 zeroY 升到 maxY
            let currentHeight = (rect.maxY - zeroY) * progress
            animatedRect = CGRect(
                x: rect.minX,
                y: zeroY,
                width: rect.width,
                height: currentHeight
            )
        }

        drawColumn(rect: animatedRect, color: color, in: context, theme: theme)
    }
}
```

**触发动画**：
```swift
// 在 makeUIView 中
if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
    DispatchQueue.main.async {
        UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseOut) {
            // 通过 animator 触发重绘，progress 0 → 1
            chart.playEntranceAnimation()
        }
    }
}
```

---

## 9. SwiftUI 封装设计

### 9.1 ColumnChart

```swift
/// 柱状图 SwiftUI 封装（demo 配套最小版）
public struct ColumnChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        ColumnChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear,
                                onHit: onHit)
    }
}

private struct ColumnChartRepresentable: UIViewRepresentable {
    let model: CartesianChartModel
    let theme: CartesianChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<ColumnChartRenderer> {
        let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? ColumnHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<ColumnChartRenderer>, context: Context) {
        uiView.configure(model: model, theme: theme)
    }
}
```

### 9.2 BarChart

```swift
/// 条形图 SwiftUI 封装（demo 配套最小版）
public struct BarChart: View {
    // 接口同 ColumnChart，但使用 BarChartRenderer
}
```

---

## 10. 测试策略

### 10.1 ChartSelfTest 扩展（~+150 行）

```swift
// ===== 零轴位置计算 =====
// 全正数据 (10, 80) → 零轴在 plot 底部
let posVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
let posPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
let zeroY = CartesianGeometry.zeroAxisPosition(viewport: posVP, plotArea: posPlot, isHorizontal: false)
assert(abs(zeroY - posPlot.maxY) < 0.001, "全正数据零轴应在底部")

// 全负数据 (-80, -10) → 零轴在 plot 顶部
let negVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -100, yMax: 0)
let zeroY2 = CartesianGeometry.zeroAxisPosition(viewport: negVP, plotArea: posPlot, isHorizontal: false)
assert(abs(zeroY2 - posPlot.minY) < 0.001, "全负数据零轴应在顶部")

// 混合数据 (-30, 70) → 零轴在 plot 内部
let mixVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -50, yMax: 100)
let zeroY3 = CartesianGeometry.zeroAxisPosition(viewport: mixVP, plotArea: posPlot, isHorizontal: false)
assert(zeroY3 > posPlot.minY && zeroY3 < posPlot.maxY, "混合数据零轴应在内部")

// ===== 堆叠累计值计算 =====
let s1 = CartesianSeriesElement(name: "a", data: [10, 20, 30])
let s2 = CartesianSeriesElement(name: "b", data: [5, 15, 25])
let stacked = CartesianGeometry.stackedValues(series: [s1, s2])
assert(stacked[0][2] == 30, "第一个系列应保持原值")
assert(stacked[1][2] == 55, "第二个系列应累计")

// 锯齿 series（长度不一）→ 归一化到最长长度
let s3 = CartesianSeriesElement(name: "c", data: [100])
let s4 = CartesianSeriesElement(name: "d", data: [10, 20, 30, 40])
let stacked2 = CartesianGeometry.stackedValues(series: [s3, s4])
assert(stacked2[0].count == 4, "应归一化到最长长度")
assert(stacked2[0][1] == 0, "短系列空位应补零")

// ===== 柱体位置计算 =====
// 正值柱：从零轴向上
let posRect = CartesianGeometry.columnRect(
    dataPoint: 80,
    categoryIndex: 1,
    categoryCount: 3,
    viewport: posVP,
    plotArea: posPlot,
    theme: CartesianChartTheme(),
    zeroY: zeroY
)
assert(posRect.minY < zeroY && posRect.maxY <= zeroY, "正值柱应在零轴上方")
assert(abs(posRect.maxY - zeroY) < 0.001, "正值柱底部应接触零轴")

// 负值柱：从零轴向下
let negRect = CartesianGeometry.columnRect(
    dataPoint: -60,
    categoryIndex: 1,
    categoryCount: 3,
    viewport: negVP,
    plotArea: posPlot,
    theme: CartesianChartTheme(),
    zeroY: zeroY2
)
assert(negRect.minY >= zeroY2 && negRect.maxY > zeroY2, "负值柱应在零轴下方")
assert(abs(negRect.minY - zeroY2) < 0.001, "负值柱顶部应接触零轴")

// 柱体宽度 = plotWidth / categoryCount * ratio
let expectedWidth = posPlot.width / 3 * 0.8
assert(abs(posRect.width - expectedWidth) < 0.001, "柱宽应按比例计算")

// ===== 条形图水平版本 =====
let hVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
let hZeroX = CartesianGeometry.zeroAxisPosition(viewport: hVP, plotArea: posPlot, isHorizontal: true)
let hRect = CartesianGeometry.barRect(
    dataPoint: 70,
    categoryIndex: 1,
    categoryCount: 3,
    viewport: hVP,
    plotArea: posPlot,
    theme: CartesianChartTheme(),
    zeroX: hZeroX
)
assert(hRect.minX >= hZeroX, "正值条应在零轴右侧")
```

### 10.2 运行期验证

**验证场景**：
1. ✅ 单系列正负值混合
2. ✅ 双系列堆叠（正+正，负+负，正+负）
3. ✅ 锯齿 series 堆叠
4. ✅ 柱体宽度比例调整（0.5, 0.8, 1.0）
5. ✅ 圆角、边框渲染
6. ✅ 入场动画（柱体升起）
7. ✅ 命中测试（点击柱体 → 识别系列和索引）

---

## 11. 交付清单

### 11.1 代码文件

**新增 6 个文件**：
```
Charts/Column/ColumnChartRenderer.swift          # ~150 行
Charts/Bar/BarChartRenderer.swift                # ~150 行
Charts/SwiftUI/ColumnChart.swift                 # ~50 行（demo 配套）
Charts/SwiftUI/ColumnChartDemo.swift             # ~150 行（实时属性面板）
Charts/SwiftUI/BarChart.swift                   # ~50 行（demo 配套）
Charts/SwiftUI/BarChartDemo.swift               # ~150 行（实时属性面板）
```

**扩展 4 个文件**：
```
Charts/Cartesian/CartesianChartModel.swift      # +8 行（StackConfig）
Charts/Cartesian/CartesianChartTheme.swift      # +20 行（柱体样式）
Charts/Cartesian/CartesianGeometry.swift        # +200 行（坐标计算）
Charts/Debug/ChartSelfTest.swift                # +150 行（测试用例）
```

**修改 1 个文件**：
```
SwiftFunctionProject/ContentView.swift          # +10 行（新增 demo 入口）
```

### 11.2 文档

```
docs/superpowers/specs/2026-08-27-column-bar-stacked-design.md    # 本设计文档
docs/charts-column-guide.md                                         # 柱状图使用指南
docs/superpowers/plans/2026-08-27-column-bar-stacked.md           # 实施计划（待生成）
```

### 11.3 Demo 页配置

**ColumnChartDemo 实时属性面板**（标配，按规格 §8.3）：

```
【数据】
- 标题文本框
- 系列数量选择（1-3）
- 数据点数滑块（2-20）
- 随机数据生成按钮

【柱体外观】
- 柱体宽度比例滑块（0.5-1.0）
- 柱体圆角滑块（0-10）
- 柱体边框开关 + 颜色选择
- 系列颜色选择

【堆叠】
- 堆叠开关（none / normal）
- 堆叠分隔线开关 + 颜色选择

【负值处理】
- 生成负值数据按钮
- 负值颜色覆盖开关

【动画与交互】
- 入场动画开关
- 点击弹窗开关
```

**BarChartDemo**：相同控件，仅水平展示

### 11.4 验收标准

**功能验收**：
- ✅ 单系列柱状/条形图正常渲染
- ✅ 负值柱体从零轴正确方向延伸
- ✅ 双系列普通堆叠正确累积
- ✅ 锯阵 series 堆叠归一化处理
- ✅ 柱体宽度、圆角、边框样式正确应用
- ✅ 入场动画柱体从零轴升起
- ✅ 命中测试返回正确的系列索引和数据点索引

**质量验收**：
- ✅ ChartSelfTest 全部断言通过
- ✅ iOS 模拟器运行无崩溃、无渲染错位
- ✅ ContentView 入口可切换到 Column/Bar demo
- ✅ 实时属性面板可调整所有配置项

---

## 12. 风险与依赖

### 12.1 技术风险

**中等风险**：
- **堆叠累计值计算的边界情况**：锯齿 series、全负值堆叠、混合正负堆叠
  - **缓解**：在 ChartSelfTest 中覆盖全部边界情况，参考 AAChartKit 行为

- **零轴位置计算精度**：浮点数比较、极值情况（yMin=0 或 yMax=0）
  - **缓解**：使用 epsilon 比较，ChartSelfTest 验证极值

**低风险**：
- 柱体圆角绘制（现有 UIBezierPath 支持良好）
- 入场动画插值（复用现有 HYMChartValueAnimator）
- 命中测试矩形检测（CGRect.contains()）

### 12.2 依赖项

**无外部依赖**（完全基于现有代码）：
- ✅ Cartesian 基础层已交付（阶段 0）
- ✅ HYMChartView、HYMChartRenderer、交互体系已就绪
- ✅ ChartSelfTest 框架已建立

**内部依赖顺序**：
1. 先扩展 CartesianChartModel（StackConfig）
2. 再扩展 CartesianGeometry（计算函数）
3. 然后扩展 CartesianChartTheme（样式）
4. 最后实现两个 Renderer
5. 扩展 ChartSelfTest 验证
6. 添加 SwiftUI demo

---

## 13. 工期估算

**开发时间**：
- 数据模型扩展：0.5 天
- CartesianGeometry 实现：1 天
- 主题扩展：0.5 天
- ColumnChartRenderer 实现：1 天
- BarChartRenderer 实现：0.8 天（复用逻辑）
- ChartSelfTest 扩展：0.7 天
- SwiftUI demo + 属性面板：1.5 天
- 使用指南文档：0.5 天
- **总计：~6.5 天**

**缓冲时间**：1 天（处理堆叠边界情况、精度问题）

**预计交付**：7-8 个工作日

---

## 14. 下一步

本设计文档已审阅通过，下一步：

1. ✅ 设计文档已写入 `docs/superpowers/specs/2026-08-27-column-bar-stacked-design.md`
2. ⏭️ 调用 `writing-plans` skill 生成详细实施计划
3. ⏭️ 按计划实施，每完成一个模块进行 ChartSelfTest 验证
4. ⏭️ 最终交付：使用指南 + demo + iOS 模拟器验证

---

**设计完成，等待实施计划生成。**
