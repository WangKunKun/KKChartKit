# HYMCharts 阶段 1 实施：柱状图/条形图 + 堆叠

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 在 Cartesian 轴系基础层上实现柱状图、条形图和普通堆叠功能，对标 AAChartKit 核心柱系能力。

**架构：** 共享几何层 + 两个独立薄 Renderer，零轴自适应位置，堆叠数学集中计算。

**技术栈：** Swift, UIKit, CoreGraphics, SwiftUI（demo 配套）

---

## 文件结构概览

**新增 6 个文件**：
- `Charts/Column/ColumnChartRenderer.swift` (~150 行)
- `Charts/Bar/BarChartRenderer.swift` (~150 行)
- `Charts/SwiftUI/ColumnChart.swift` (~50 行)
- `Charts/SwiftUI/ColumnChartDemo.swift` (~150 行)
- `Charts/SwiftUI/BarChart.swift` (~50 行)
- `Charts/SwiftUI/BarChartDemo.swift` (~150 行)

**扩展 5 个文件**：
- `Charts/Cartesian/CartesianChartModel.swift` (+8 行)
- `Charts/Cartesian/CartesianGeometry.swift` (+200 行)
- `Charts/Cartesian/CartesianChartTheme.swift` (+20 行)
- `Charts/Debug/ChartSelfTest.swift` (+150 行)
- `SwiftFunctionProject/ContentView.swift` (+10 行)

---

## Task 1: 添加 StackConfig 枚举

**Files:**
- Modify: `Charts/Cartesian/CartesianChartModel.swift:46-60`

- [ ] **Step 1: 在 CartesianChartModel.swift 顶部添加 StackConfig 枚举**

在文件开头的 import 语句后添加：

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

- [ ] **Step 2: 在 CartesianChartModel 结构体中添加 stacking 属性**

找到 `public struct CartesianChartModel` 的属性定义部分（约第 48 行），在 `yAxis` 属性后添加：

```swift
    /// 堆叠配置（nil = 不堆叠）
    public var stacking: StackConfig?
```

- [ ] **Step 3: 更新 CartesianChartModel.init 方法添加 stacking 参数**

找到 `public init` 方法（约第 52 行），在 `yAxis` 参数后添加：

```swift
                stacking: StackConfig? = nil) {
    self.title = title
    self.series = series
    self.xAxis = xAxis
    self.yAxis = yAxis
    self.stacking = stacking
}
```

- [ ] **Step 4: 在 CartesianSeriesElement 中添加 negativeColor 属性**

找到 `public struct CartesianSeriesElement`（约第 31 行），在 `color` 属性后添加：

```swift
    /// 负值数据点的覆盖颜色（nil = 使用 color）
    public var negativeColor: UIColor?
```

- [ ] **Step 5: 更新 CartesianSeriesElement.init 方法**

找到 `public init(name:data:color:)` 方法（约第 38 行），更新为：

```swift
    public init(name: String, data: [Double], color: UIColor? = nil, negativeColor: UIColor? = nil) {
        self.name = name
        self.data = data
        self.color = color
        self.negativeColor = negativeColor
    }
```

- [ ] **Step 6: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功，无错误

- [ ] **Step 7: 提交更改**

```bash
git add Charts/Cartesian/CartesianChartModel.swift
git commit -m "feat(charts): 添加 StackConfig 枚举和 stacking 属性

- 普通/百分比/分组堆叠扩展点预留
- CartesianSeriesElement 添加负值颜色覆盖"
```

---

## Task 2: 扩展 CartesianChartTheme 添加柱体样式

**Files:**
- Modify: `Charts/Cartesian/CartesianChartTheme.swift`

- [ ] **Step 1: 在 CartesianChartTheme 中添加柱体外观属性**

找到属性定义区域（在现有属性后添加，约第 80 行后）：

```swift
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
```

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/Cartesian/CartesianChartTheme.swift
git commit -m "feat(charts): 主题添加柱体样式配置

- 柱体宽度比例、圆角、边框
- 堆叠分隔线样式
- 入场动画开关"
```

---

## Task 3: 实现 CartesianGeometry.zeroAxisPosition

**Files:**
- Modify: `Charts/Cartesian/CartesianGeometry.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 CartesianGeometry 中添加 zeroAxisPosition 函数声明**

找到 `extension CartesianGeometry`（文件末尾），在现有函数后添加：

```swift
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
    ) -> CGFloat {
        if isHorizontal {
            // 水平图（Bar）：返回 X 坐标
            if viewport.xMin >= 0 {
                // 全正值域，零轴在左侧
                return plotArea.minX
            } else if viewport.xMax <= 0 {
                // 全负值域，零轴在右侧
                return plotArea.maxX
            } else {
                // 混合值域，零轴在内部（插值计算）
                let ratio = -viewport.xMin / (viewport.xMax - viewport.xMin)
                return plotArea.minX + plotArea.width * ratio
            }
        } else {
            // 垂直图（Column）：返回 Y 坐标
            if viewport.yMin >= 0 {
                // 全正值域，零轴在底部
                return plotArea.maxY
            } else if viewport.yMax <= 0 {
                // 全负值域，零轴在顶部
                return plotArea.minY
            } else {
                // 混合值域，零轴在内部（插值计算）
                let ratio = -viewport.yMin / (viewport.yMax - viewport.yMin)
                return plotArea.maxY - plotArea.height * ratio
            }
        }
    }
```

- [ ] **Step 2: 在 ChartSelfTest 中添加 zeroAxisPosition 测试**

找到 `// —— Cartesian 数据模型 ——` 测试区域（约第 323 行），在该区域后添加：

```swift
        // —— CartesianGeometry.zeroAxisPosition ——
        let zpVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
        let zpPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let zY = CartesianGeometry.zeroAxisPosition(viewport: zpVP, plotArea: zpPlot, isHorizontal: false)
        assert(abs(zY - zpPlot.maxY) < 0.001, "全正数据零轴应在底部")

        let znVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -100, yMax: 0)
        let znY = CartesianGeometry.zeroAxisPosition(viewport: znVP, plotArea: zpPlot, isHorizontal: false)
        assert(abs(znY - zpPlot.minY) < 0.001, "全负数据零轴应在顶部")

        let zmVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -50, yMax: 100)
        let zmY = CartesianGeometry.zeroAxisPosition(viewport: zmVP, plotArea: zpPlot, isHorizontal: false)
        assert(zmY > zpPlot.minY && zmY < zpPlot.maxY, "混合数据零轴应在内部")

        // 水平版本测试
        let zhVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
        let zX = CartesianGeometry.zeroAxisPosition(viewport: zhVP, plotArea: zpPlot, isHorizontal: true)
        assert(abs(zX - zpPlot.minX) < 0.001, "水平图全正值域零轴应在左侧")
```

- [ ] **Step 3: 运行 ChartSelfTest 验证**

运行：在 Xcode 中运行项目（Cmd+R），查看控制台输出
预期：✅ ChartSelfTest passed

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Cartesian/CartesianGeometry.swift Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): 实现零轴位置计算

- 垂直/水平图表零轴位置计算
- 全正/全负/混合值域支持
- ChartSelfTest 验证全部场景"
```

---

## Task 4: 实现 CartesianGeometry.stackedValues

**Files:**
- Modify: `Charts/Cartesian/CartesianGeometry.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 CartesianGeometry 中添加 stackedValues 函数**

在 `zeroAxisPosition` 函数后添加：

```swift
    /// 堆叠累计值（归一化为所有 series 同长度）
    /// - Parameter series: 原始 series 数组（可能长度不一）
    /// - Returns: 累计值数组，stack[i][j] = sum(series[0...i][j])
    /// - 锯齿 series：短 series 空位补 0，长度对齐到最长 series
    public static func stackedValues(series: [CartesianSeriesElement]) -> [[Double]] {
        guard !series.isEmpty else { return [] }

        // 1. 找到最长 series 的长度
        let maxLength = series.map { $0.data.count }.max() ?? 0
        guard maxLength > 0 else { return [] }

        // 2. 归一化所有 series 到相同长度（短 series 补 0）
        var normalizedData: [[Double]] = []
        for oneSeries in series {
            var padded = oneSeries.data
            while padded.count < maxLength {
                padded.append(0)
            }
            normalizedData.append(padded)
        }

        // 3. 计算累计值
        var stacked: [[Double]] = []
        for (index, data) in normalizedData.enumerated() {
            if index == 0 {
                stacked.append(data)  // 第一个系列保持原值
            } else {
                let previous = stacked[index - 1]
                let accumulated = zip(previous, data).map { $0 + $1 }
                stacked.append(accumulated)
            }
        }

        return stacked
    }
```

- [ ] **Step 2: 在 ChartSelfTest 中添加 stackedValues 测试**

在刚添加的 zeroAxisPosition 测试后添加：

```swift
        // —— CartesianGeometry.stackedValues ——
        let s1 = CartesianSeriesElement(name: "a", data: [10, 20, 30])
        let s2 = CartesianSeriesElement(name: "b", data: [5, 15, 25])
        let stacked = CartesianGeometry.stackedValues(series: [s1, s2])
        assert(stacked.count == 2, "应返回 2 个系列")
        assert(stacked[0][2] == 30, "第一个系列应保持原值")
        assert(stacked[1][2] == 55, "第二个系列应累计: 30+25=55")

        // 锯阵 series 测试
        let s3 = CartesianSeriesElement(name: "c", data: [100])
        let s4 = CartesianSeriesElement(name: "d", data: [10, 20, 30, 40])
        let stacked2 = CartesianGeometry.stackedValues(series: [s3, s4])
        assert(stacked2[0].count == 4, "应归一化到最长长度 4")
        assert(stacked2[0][1] == 0, "短系列空位应补零")
        assert(stacked2[1][0] == 110, "第一个位置应累计: 100+10=110")
        assert(stacked2[1][1] == 20, "第二个位置应累计: 0+20=20")

        // 空 series 边界情况
        let emptyStacked = CartesianGeometry.stackedValues(series: [])
        assert(emptyStacked.isEmpty, "空 series 应返回空数组")
```

- [ ] **Step 3: 运行 ChartSelfTest 验证**

运行：在 Xcode 中运行项目（Cmd+R）
预期：✅ ChartSelfTest passed

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Cartesian/CartesianGeometry.swift Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): 实现堆叠累计值计算

- 归一化锯齿 series 到相同长度
- 计算堆叠累计值
- ChartSelfTest 覆盖边界情况"
```

---

## Task 5: 实现 CartesianGeometry.columnRect

**Files:**
- Modify: `Charts/Cartesian/CartesianGeometry.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 CartesianGeometry 中添加 columnRect 函数**

在 `stackedValues` 函数后添加：

```swift
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
    ) -> CGRect {
        // 1. 计算柱体宽度
        let slotWidth = plotArea.width / CGFloat(categoryCount)
        let columnWidth = slotWidth * theme.columnWidthRatio

        // 2. 计算 X 位置（居中对齐）
        let columnX = plotArea.minX + CGFloat(categoryIndex) * slotWidth + (slotWidth - columnWidth) / 2

        // 3. 计算数据点对应的 Y 坐标
        let valueY = point(x: Double(categoryIndex), y: dataPoint, viewport: viewport, plotFrame: plotArea).y

        // 4. 根据正负值确定矩形
        if dataPoint >= 0 {
            // 正值：从 zeroY 向上到 valueY
            let height = zeroY - valueY
            return CGRect(x: columnX, y: valueY, width: columnWidth, height: height)
        } else {
            // 负值：从 valueY 向下到 zeroY
            let height = valueY - zeroY
            return CGRect(x: columnX, y: zeroY, width: columnWidth, height: height)
        }
    }
```

- [ ] **Step 2: 在 ChartSelfTest 中添加 columnRect 测试**

在刚添加的 stackedValues 测试后添加：

```swift
        // —— CartesianGeometry.columnRect ——
        let colVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
        let colPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let colZeroY = CartesianGeometry.zeroAxisPosition(viewport: colVP, plotArea: colPlot, isHorizontal: false)
        let colTheme = CartesianChartTheme()

        // 正值柱测试
        let posRect = CartesianGeometry.columnRect(
            dataPoint: 80,
            categoryIndex: 1,
            categoryCount: 3,
            viewport: colVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroY: colZeroY
        )
        assert(posRect.minY < colZeroY && posRect.maxY <= colZeroY, "正值柱应在零轴上方")
        assert(abs(posRect.maxY - colZeroY) < 0.001, "正值柱底部应接触零轴")

        // 负值柱测试
        let negVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -100, yMax: 0)
        let negZeroY = CartesianGeometry.zeroAxisPosition(viewport: negVP, plotArea: colPlot, isHorizontal: false)
        let negRect = CartesianGeometry.columnRect(
            dataPoint: -60,
            categoryIndex: 1,
            categoryCount: 3,
            viewport: negVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroY: negZeroY
        )
        assert(negRect.minY >= negZeroY && negRect.maxY > negZeroY, "负值柱应在零轴下方")
        assert(abs(negRect.minY - negZeroY) < 0.001, "负值柱顶部应接触零轴")

        // 柱体宽度测试
        let expectedWidth = colPlot.width / 3 * 0.8
        assert(abs(posRect.width - expectedWidth) < 0.001, "柱宽应按比例计算")

        // 柱体 X 位置测试（第二个柱应在中间偏右）
        let secondColumnX = colPlot.minX + colPlot.width / 3 * 1 + (colPlot.width / 3 * 0.2) / 2
        assert(abs(posRect.minX - secondColumnX) < 0.001, "柱体 X 位置应正确")
```

- [ ] **Step 3: 运行 ChartSelfTest 验证**

运行：在 Xcode 中运行项目（Cmd+R）
预期：✅ ChartSelfTest passed

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Cartesian/CartesianGeometry.swift Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): 实现柱体位置计算（垂直图）

- 柱体宽度按比例计算
- 正负值柱从零轴向相反方向延伸
- ChartSelfTest 验证位置和尺寸"
```

---

## Task 6: 实现 CartesianGeometry.barRect

**Files:**
- Modify: `Charts/Cartesian/CartesianGeometry.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 CartesianGeometry 中添加 barRect 函数**

在 `columnRect` 函数后添加：

```swift
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
    ) -> CGRect {
        // 1. 计算条形高度
        let slotHeight = plotArea.height / CGFloat(categoryCount)
        let barHeight = slotHeight * theme.columnWidthRatio

        // 2. 计算 Y 位置（居中对齐）
        let barY = plotArea.minY + CGFloat(categoryIndex) * slotHeight + (slotHeight - barHeight) / 2

        // 3. 计算数据点对应的 X 坐标
        // 注意：水平图的 X 轴对应数值，Y 轴对应类目
        let valueX = point(x: dataPoint, y: Double(categoryIndex), viewport: viewport, plotFrame: plotArea).x

        // 4. 根据正负值确定矩形
        if dataPoint >= 0 {
            // 正值：从 zeroX 向右到 valueX
            let width = valueX - zeroX
            return CGRect(x: zeroX, y: barY, width: width, height: barHeight)
        } else {
            // 负值：从 valueX 向左到 zeroX
            let width = zeroX - valueX
            return CGRect(x: valueX, y: barY, width: width, height: barHeight)
        }
    }
```

- [ ] **Step 2: 在 ChartSelfTest 中添加 barRect 测试**

在刚添加的 columnRect 测试后添加：

```swift
        // —— CartesianGeometry.barRect ——
        let barVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
        let barPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let barZeroX = CartesianGeometry.zeroAxisPosition(viewport: barVP, plotArea: barPlot, isHorizontal: true)

        // 正值条测试
        let posBar = CartesianGeometry.barRect(
            dataPoint: 70,
            categoryIndex: 1,
            categoryCount: 3,
            viewport: barVP,
            plotArea: barPlot,
            theme: colTheme,
            zeroX: barZeroX
        )
        assert(posBar.minX >= barZeroX, "正值条应在零轴右侧")
        assert(abs(posBar.minX - barZeroX) < 0.001, "正值条左侧应接触零轴")

        // 负值条测试
        let negBarVP = CartesianViewport(xMin: -100, xMax: 0, yMin: -0.5, yMax: 2.5)
        let negBarZeroX = CartesianGeometry.zeroAxisPosition(viewport: negBarVP, plotArea: barPlot, isHorizontal: true)
        let negBar = CartesianGeometry.barRect(
            dataPoint: -50,
            categoryIndex: 1,
            categoryCount: 3,
            viewport: negBarVP,
            plotArea: barPlot,
            theme: colTheme,
            zeroX: negBarZeroX
        )
        assert(negBar.maxX <= negBarZeroX, "负值条应在零轴左侧")
        assert(abs(negBar.maxX - negBarZeroX) < 0.001, "负值条右侧应接触零轴")

        // 条形高度测试
        let expectedHeight = barPlot.height / 3 * 0.8
        assert(abs(posBar.height - expectedHeight) < 0.001, "条高应按比例计算")
```

- [ ] **Step 3: 运行 ChartSelfTest 验证**

运行：在 Xcode 中运行项目（Cmd+R）
预期：✅ ChartSelfTest passed

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Cartesian/CartesianGeometry.swift Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): 实现条形位置计算（水平图）

- 条形高度按比例计算
- X/Y 坐标镜像逻辑
- ChartSelfTest 验证水平版本"
```

---

## Task 7: 创建 ColumnHitTarget 和 BarHitTarget

**Files:**
- Create: `Charts/Column/ColumnHitTarget.swift`
- Create: `Charts/Bar/BarHitTarget.swift`

- [ ] **Step 1: 创建 ColumnHitTarget.swift**

创建新文件 `Charts/Column/ColumnHitTarget.swift`：

```swift
import Foundation
import UIKit

/// 柱状图命中目标
public struct ColumnHitTarget: HYMChartHitTarget {
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double

    public init(seriesIndex: Int, categoryIndex: Int, value: Double) {
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
    }

    // MARK: - HYMChartHitTarget

    public let kind = "column"

    public var identifier: String {
        return "column:\(seriesIndex):\(categoryIndex)"
    }

    public var index: Int {
        return categoryIndex
    }

    public var tooltipText: String? {
        let seriesName = "系列\(seriesIndex + 1)"
        let categoryName = "项\(categoryIndex + 1)"
        return "\(seriesName) - \(categoryName): \(value)"
    }
}
```

- [ ] **Step 2: 创建 BarHitTarget.swift**

创建新文件 `Charts/Bar/BarHitTarget.swift`：

```swift
import Foundation
import UIKit

/// 条形图命中目标
public struct BarHitTarget: HYMChartHitTarget {
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double

    public init(seriesIndex: Int, categoryIndex: Int, value: Double) {
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
    }

    // MARK: - HYMChartHitTarget

    public let kind = "bar"

    public var identifier: String {
        return "bar:\(seriesIndex):\(categoryIndex)"
    }

    public var index: Int {
        return categoryIndex
    }

    public var tooltipText: String? {
        let seriesName = "系列\(seriesIndex + 1)"
        let categoryName = "项\(categoryIndex + 1)"
        return "\(seriesName) - \(categoryName): \(value)"
    }
}
```

- [ ] **Step 3: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Column/ColumnHitTarget.swift Charts/Bar/BarHitTarget.swift
git commit -m "feat(charts): 柱状图/条形图命中目标类型

- ColumnHitTarget 和 BarHitTarget
- 实现 HYMChartHitTarget 协议
- 提供默认 tooltip 文本"
```

---

## Task 8: 实现 ColumnChartRenderer

**Files:**
- Create: `Charts/Column/ColumnChartRenderer.swift`

- [ ] **Step 1: 创建 ColumnChartRenderer.swift 文件**

创建新文件 `Charts/Column/ColumnChartRenderer.swift`：

```swift
import UIKit
import Foundation

/// 柱状图渲染器（垂直柱体）
public final class ColumnChartRenderer: CartesianRendererBase {

    // MARK: - Override

    /// 子类实现：绘制 series
    public override func drawSeries(
        in context: CGContext,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme,
        progress: CGFloat = 1.0
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
                // 计算动画后的矩形
                var rect = CartesianGeometry.columnRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: viewport,
                    plotArea: plotArea,
                    theme: theme,
                    zeroY: zeroY
                )

                // 应用入场动画
                if progress < 1.0 {
                    rect = animatedRect(from: rect, zeroY: zeroY, progress: progress)
                }

                // 负值颜色覆盖
                let color: UIColor
                if let negColor = model.series[seriesIndex].negativeColor, value < 0 {
                    color = negColor
                } else {
                    color = baseColor
                }

                // 绘制柱体
                drawColumn(rect: rect, color: color, in: context, theme: theme)

                // 如果堆叠且非最后系列，绘制分隔线
                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxY, in: context, plotArea: plotArea, theme: theme)
                }
            }
        }
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(
        point: CGPoint,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme
    ) -> HYMChartHitTarget? {
        guard !model.series.isEmpty else { return nil }

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

    // MARK: - Private

    /// 绘制单个柱体
    private func drawColumn(rect: CGRect, color: UIColor, in context: CGContext, theme: CartesianChartTheme) {
        // 确定圆角方向
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: CartesianViewport(),  // 简化，实际应从外部传入
            plotArea: rect,
            isHorizontal: false
        )

        let corners: UIRectCorner = rect.minY < zeroY
            ? [.topLeft, .topRight]    // 正值：顶部圆角
            : [.bottomLeft, .bottomRight]  // 负值：底部圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))
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

    /// 计算动画过程中的矩形
    private func animatedRect(from rect: CGRect, zeroY: CGFloat, progress: CGFloat) -> CGRect {
        if rect.minY < zeroY {
            // 正值：从 zeroY 降到 minY
            let currentHeight = (zeroY - rect.minY) * progress
            return CGRect(x: rect.minX, y: zeroY - currentHeight, width: rect.width, height: currentHeight)
        } else {
            // 负值：从 zeroY 升到 maxY
            let currentHeight = (rect.maxY - zeroY) * progress
            return CGRect(x: rect.minX, y: zeroY, width: rect.width, height: currentHeight)
        }
    }
}
```

注意：上面的 `drawColumn` 方法中 zeroY 计算需要优化，我们将在下一步修复。

- [ ] **Step 2: 修复 drawColumn 方法的 zeroY 参数**

在 `drawSeries` 方法中，将 zeroY 传递给 `drawColumn`：

```swift
                // 绘制柱体
                drawColumn(rect: rect, color: color, zeroY: zeroY, in: context, theme: theme)
```

然后更新 `drawColumn` 方法签名和实现：

```swift
    /// 绘制单个柱体
    private func drawColumn(rect: CGRect, color: UIColor, zeroY: CGFloat, in context: CGContext, theme: CartesianChartTheme) {
        // 确定圆角方向
        let corners: UIRectCorner = rect.minY < zeroY
            ? [.topLeft, .topRight]    // 正值：顶部圆角
            : [.bottomLeft, .bottomRight]  // 负值：底部圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))
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
```

- [ ] **Step 3: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 4: 提交更改**

```bash
git add Charts/Column/ColumnChartRenderer.swift
git commit -m "feat(charts): 实现柱状图渲染器

- 单系列/堆叠柱体绘制
- 正负值柱从零轴向相反方向延伸
- 入场动画（柱体升起）
- 命中测试支持"
```

---

## Task 9: 实现 BarChartRenderer

**Files:**
- Create: `Charts/Bar/BarChartRenderer.swift`

- [ ] **Step 1: 创建 BarChartRenderer.swift 文件**

创建新文件 `Charts/Bar/BarChartRenderer.swift`，内容与 ColumnChartRenderer 类似，但水平版本：

```swift
import UIKit
import Foundation

/// 条形图渲染器（水平柱体）
public final class BarChartRenderer: CartesianRendererBase {

    // MARK: - Override

    /// 子类实现：绘制 series
    public override func drawSeries(
        in context: CGContext,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme,
        progress: CGFloat = 1.0
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
                var rect = CartesianGeometry.barRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: viewport,
                    plotArea: plotArea,
                    theme: theme,
                    zeroX: zeroX
                )

                // 应用入场动画
                if progress < 1.0 {
                    rect = animatedRect(from: rect, zeroX: zeroX, progress: progress)
                }

                let color: UIColor
                if let negColor = model.series[seriesIndex].negativeColor, value < 0 {
                    color = negColor
                } else {
                    color = baseColor
                }

                drawBar(rect: rect, color: color, zeroX: zeroX, in: context, theme: theme)

                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxX, in: context, plotArea: plotArea, theme: theme)
                }
            }
        }
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(
        point: CGPoint,
        plotArea: CGRect,
        viewport: CartesianViewport,
        theme: CartesianChartTheme
    ) -> HYMChartHitTarget? {
        guard !model.series.isEmpty else { return nil }

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

    // MARK: - Private

    /// 绘制单个条形
    private func drawBar(rect: CGRect, color: UIColor, zeroX: CGFloat, in context: CGContext, theme: CartesianChartTheme) {
        // 水平版本：左右圆角
        let corners: UIRectCorner = rect.minX < zeroX
            ? [.topLeft, .bottomLeft]   // 正值：左侧圆角
            : [.topRight, .bottomRight]  // 负值：右侧圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))
        context.addPath(path.cgPath)
        context.setFillColor(color.cgColor)
        context.fillPath()

        if let borderColor = theme.columnBorderColor {
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(theme.columnBorderWidth)
            context.strokePath()
        }
    }

    /// 绘制堆叠分隔线
    private func drawStackSeparator(at x: CGFloat, in context: CGContext, plotArea: CGRect, theme: CartesianChartTheme) {
        guard let separatorColor = theme.stackSeparatorColor else { return }

        context.move(to: CGPoint(x: x, y: plotArea.minY))
        context.addLine(to: CGPoint(x: x, y: plotArea.maxY))
        context.setStrokeColor(separatorColor.cgColor)
        context.setLineWidth(theme.stackSeparatorWidth)
        context.strokePath()
    }

    /// 计算动画过程中的矩形
    private func animatedRect(from rect: CGRect, zeroX: CGFloat, progress: CGFloat) -> CGRect {
        if rect.minX >= zeroX {
            // 正值：从 zeroX 向右扩展
            let currentWidth = (rect.maxX - zeroX) * progress
            return CGRect(x: zeroX, y: rect.minY, width: currentWidth, height: rect.height)
        } else {
            // 负值：从 zeroX 向左扩展
            let currentWidth = (zeroX - rect.minX) * progress
            return CGRect(x: zeroX - currentWidth, y: rect.minY, width: currentWidth, height: rect.height)
        }
    }
}
```

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/Bar/BarChartRenderer.swift
git commit -m "feat(charts): 实现条形图渲染器

- 水平版本柱体绘制
- X/Y 坐标镜像逻辑
- 入场动画和命中测试"
```

---

## Task 10: 实现 ColumnChart SwiftUI 封装

**Files:**
- Create: `Charts/SwiftUI/ColumnChart.swift`

- [ ] **Step 1: 创建 ColumnChart.swift**

创建新文件 `Charts/SwiftUI/ColumnChart.swift`：

```swift
import SwiftUI

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

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/SwiftUI/ColumnChart.swift
git commit -m "feat(charts): 柱状图 SwiftUI 封装

- demo 配套最小版
- 支持入场动画和命中回调"
```

---

## Task 11: 实现 BarChart SwiftUI 封装

**Files:**
- Create: `Charts/SwiftUI/BarChart.swift`

- [ ] **Step 1: 创建 BarChart.swift**

创建新文件 `Charts/SwiftUI/BarChart.swift`：

```swift
import SwiftUI

/// 条形图 SwiftUI 封装（demo 配套最小版）
public struct BarChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((BarHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        BarChartRepresentable(model: model, theme: theme,
                             playsAnimationOnAppear: playsAnimationOnAppear,
                             onHit: onHit)
    }
}

private struct BarChartRepresentable: UIViewRepresentable {
    let model: CartesianChartModel
    let theme: CartesianChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<BarChartRenderer> {
        let chart = HYMChartView<BarChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? BarHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<BarChartRenderer>, context: Context) {
        uiView.configure(model: model, theme: theme)
    }
}
```

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/SwiftUI/BarChart.swift
git commit -m "feat(charts): 条形图 SwiftUI 封装

- demo 配套最小版
- 支持入场动画和命中回调"
```

---

## Task 12: 实现ColumnChartDemo 实时属性面板

**Files:**
- Create: `Charts/SwiftUI/ColumnChartDemo.swift`

- [ ] **Step 1: 创建 ColumnChartDemo.swift**

创建新文件 `Charts/SwiftUI/ColumnChartDemo.swift`：

```swift
import SwiftUI

/// 柱状图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
struct ColumnChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "季度销售额（万元）"
    @State private var seriesCount = 1
    @State private var pointCount = 4
    @State private var data: [[Double]] = (0..<1).map { _ in Self.randomData(count: 4) }

    // —— Theme 可调项 ——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange]
    @State private var columnWidthRatio = 0.8
    @State private var columnCornerRadius = 4.0
    @State private var columnBorderOn = false
    @State private var columnBorderColor = UIColor.black
    @State private var stacking: StackConfig = .none
    @State private var stackSeparatorOn = false
    @State private var stackSeparatorColor = UIColor.white

    var body: some View {
        VStack(spacing: 0) {
            ColumnChart(model: currentModel, theme: currentTheme)
                .frame(height: 280)
                .padding(.horizontal)
                .padding(.top, 8)
            Form {
                panel
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("柱状图 demo")
        .onChange(of: pointCount) { regenerateData() }
        .onChange(of: seriesCount) { regenerateData() }
    }

    private var currentModel: CartesianChartModel {
        let series = (0..<seriesCount).map { index in
            CartesianSeriesElement(
                name: "系列\(index + 1)",
                data: data[index],
                color: seriesColors[index % seriesColors.count]
            )
        }
        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            stacking: stacking == .none ? nil : stacking
        )
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.columnWidthRatio = columnWidthRatio
        t.columnCornerRadius = columnCornerRadius
        if columnBorderOn {
            t.columnBorderColor = columnBorderColor
        }
        if stackSeparatorOn {
            t.stackSeparatorColor = stackSeparatorColor
        }
        return t
    }

    private var panel: ChartDemoPanel {
        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .stepper(label: "系列数量", value: Binding(
                get: { Double(seriesCount) },
                set: { seriesCount = Int($0) }), range: 1...3, step: 1),
            .slider(label: "数据点数", value: Binding(
                get: { Double(pointCount) },
                set: { pointCount = Int($0) }), range: 2...12, step: 1),
            .button(label: "🎲 随机重生成数据") {
                regenerateData()
            },
            .button(label: "📉 生成负值数据") {
                data = (0..<seriesCount).map { _ in Self.randomNegativeData(count: pointCount) }
            },
        ])

        let columnSection = ChartDemoPanel.DemoSection(title: "柱体外观", items: [
            .slider(label: "柱体宽度比例", value: $columnWidthRatio, range: 0.3...1.0, step: 0.05),
            .slider(label: "圆角半径", value: $columnCornerRadius, range: 0...10, step: 1),
            .toggle(label: "边框", value: $columnBorderOn),
            .color(label: "边框颜色", value: $columnBorderColor),
        ])

        let stackSection = ChartDemoPanel.DemoSection(title: "堆叠", items: [
            .picker(label: "堆叠模式", value: Binding(
                get: { stacking },
                set: { stacking = $0 }
            ), options: [
                (StackConfig.none, "不堆叠"),
                (StackConfig.normal, "普通堆叠")
            ]),
            .toggle(label: "分隔线", value: $stackSeparatorOn),
            .color(label: "分隔线颜色", value: $stackSeparatorColor),
        ])

        let animationSection = ChartDemoPanel.DemoSection(title: "动画与交互", items: [
            .toggle(label: "入场动画", value: $theme.showsColumnEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
        ])

        return ChartDemoPanel(sections: [dataSection, columnSection, stackSection, animationSection])
    }

    private func regenerateData() {
        data = (0..<seriesCount).map { _ in Self.randomData(count: pointCount) }
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 20...100).rounded() }
    }

    static func randomNegativeData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: -80...80).rounded() }
    }
}
```

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/SwiftUI/ColumnChartDemo.swift
git commit -m "feat(charts): 柱状图实时属性面板 demo

- 数据/外观/堆叠/动画 全量控制
- 负值数据生成
- 系列数量 1-3 可调"
```

---

## Task 13: 实现 BarChartDemo 实时属性面板

**Files:**
- Create: `Charts/SwiftUI/BarChartDemo.swift`

- [ ] **Step 1: 创建 BarChartDemo.swift**

创建新文件 `Charts/SwiftUI/BarChartDemo.swift`，与 ColumnChartDemo 类似但水平展示：

```swift
import SwiftUI

/// 条形图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
struct BarChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "季度销售额（万元）"
    @State private var seriesCount = 1
    @State private var pointCount = 4
    @State private var data: [[Double]] = (0..<1).map { _ in Self.randomData(count: 4) }

    // —— Theme 可调项 ——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange]
    @State private var columnWidthRatio = 0.8
    @State private var columnCornerRadius = 4.0
    @State private var columnBorderOn = false
    @State private var columnBorderColor = UIColor.black
    @State private var stacking: StackConfig = .none
    @State private var stackSeparatorOn = false
    @State private var stackSeparatorColor = UIColor.white

    var body: some View {
        VStack(spacing: 0) {
            BarChart(model: currentModel, theme: currentTheme)
                .frame(height: 280)
                .padding(.horizontal)
                .padding(.top, 8)
            Form {
                panel
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("条形图 demo")
        .onChange(of: pointCount) { regenerateData() }
        .onChange(of: seriesCount) { regenerateData() }
    }

    private var currentModel: CartesianChartModel {
        let series = (0..<seriesCount).map { index in
            CartesianSeriesElement(
                name: "系列\(index + 1)",
                data: data[index],
                color: seriesColors[index % seriesColors.count]
            )
        }
        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            stacking: stacking == .none ? nil : stacking
        )
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.columnWidthRatio = columnWidthRatio
        t.columnCornerRadius = columnCornerRadius
        if columnBorderOn {
            t.columnBorderColor = columnBorderColor
        }
        if stackSeparatorOn {
            t.stackSeparatorColor = stackSeparatorColor
        }
        return t
    }

    private var panel: ChartDemoPanel {
        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .stepper(label: "系列数量", value: Binding(
                get: { Double(seriesCount) },
                set: { seriesCount = Int($0) }), range: 1...3, step: 1),
            .slider(label: "数据点数", value: Binding(
                get: { Double(pointCount) },
                set: { pointCount = Int($0) }), range: 2...12, step: 1),
            .button(label: "🎲 随机重生成数据") {
                regenerateData()
            },
            .button(label: "📉 生成负值数据") {
                data = (0..<seriesCount).map { _ in Self.randomNegativeData(count: pointCount) }
            },
        ])

        let barSection = ChartDemoPanel.DemoSection(title: "条形外观", items: [
            .slider(label: "条形高度比例", value: $columnWidthRatio, range: 0.3...1.0, step: 0.05),
            .slider(label: "圆角半径", value: $columnCornerRadius, range: 0...10, step: 1),
            .toggle(label: "边框", value: $columnBorderOn),
            .color(label: "边框颜色", value: $columnBorderColor),
        ])

        let stackSection = ChartDemoPanel.DemoSection(title: "堆叠", items: [
            .picker(label: "堆叠模式", value: Binding(
                get: { stacking },
                set: { stacking = $0 }
            ), options: [
                (StackConfig.none, "不堆叠"),
                (StackConfig.normal, "普通堆叠")
            ]),
            .toggle(label: "分隔线", value: $stackSeparatorOn),
            .color(label: "分隔线颜色", value: $stackSeparatorColor),
        ])

        let animationSection = ChartDemoPanel.DemoSection(title: "动画与交互", items: [
            .toggle(label: "入场动画", value: $theme.showsColumnEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
        ])

        return ChartDemoPanel(sections: [dataSection, barSection, stackSection, animationSection])
    }

    private func regenerateData() {
        data = (0..<seriesCount).map { _ in Self.randomData(count: pointCount) }
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 20...100).rounded() }
    }

    static func randomNegativeData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: -80...80).rounded() }
    }
}
```

- [ ] **Step 2: 运行项目验证编译通过**

运行：在 Xcode 中编译项目（Cmd+B）
预期：编译成功

- [ ] **Step 3: 提交更改**

```bash
git add Charts/SwiftUI/BarChartDemo.swift
git commit -m "feat(charts): 条形图实时属性面板 demo

- 水平版本属性面板
- 与柱状图功能对齐"
```

---

## Task 14: 在 ContentView 中添加 demo 入口

**Files:**
- Modify: `SwiftFunctionProject/ContentView.swift`

- [ ] **Step 1: 在 ContentView 中添加柱状图和条形图入口**

找到 `Section("折线图")`（约第 27 行），在其后添加新的 Section：

```swift
                Section("柱状图") {
                    NavigationLink("柱状图 demo（实时属性面板）") {
                        ColumnChartDemo()
                    }
                }
                Section("条形图") {
                    NavigationLink("条形图 demo（实时属性面板）") {
                        BarChartDemo()
                    }
                }
```

- [ ] **Step 2: 运行项目验证入口显示**

运行：在 Xcode 中运行项目（Cmd+R）
预期：ContentView 中出现"柱状图"和"条形图"入口，点击可跳转

- [ ] **Step 3: 提交更改**

```bash
git add SwiftFunctionProject/ContentView.swift
git commit -m "feat(charts): ContentView 添加柱状图/条形图入口

- 柱状图 demo 入口
- 条形图 demo 入口"
```

---

## Task 15: 运行期验证和最终测试

**Files:**
- Test: iOS 模拟器

- [ ] **Step 1: 运行项目并导航到柱状图 demo**

运行：在 Xcode 中运行项目（Cmd+R），点击"柱状图 demo"
预期：显示柱状图 + 属性面板，图表正常渲染

- [ ] **Step 2: 测试单系列正负值混合**

操作：
1. 点击"📉 生成负值数据"
2. 观察柱体方向
预期：正值柱向上，负值柱向下，零轴在中间

- [ ] **Step 3: 测试双系列堆叠**

操作：
1. 将"系列数量"调为 2
2. 选择"普通堆叠"
3. 开启"分隔线"
预期：两个系列累积显示，分隔线可见

- [ ] **Step 4: 测试柱体样式调整**

操作：
1. 调整"柱体宽度比例"滑块
2. 调整"圆角半径"滑块
3. 开启"边框"并选择颜色
预期：柱体样式实时更新

- [ ] **Step 5: 测试入场动画**

操作：
1. 切换"入场动画"开关
2. 返回 demo 页面
预期：柱体从零轴升起动画

- [ ] **Step 6: 测试命中测试**

操作：
1. 确保开启"点击弹窗"
2. 点击柱体
预期：显示 tooltip，包含正确的系列和数值信息

- [ ] **Step 7: 测试条形图 demo**

操作：
1. 返回 ContentView
2. 点击"条形图 demo"
3. 重复步骤 2-6
预期：条形图功能与柱状图一致，仅方向不同

- [ ] **Step 8: 验证 ChartSelfTest 全部通过**

操作：查看控制台输出
预期：✅ ChartSelfTest passed

- [ ] **Step 9: 提交最终验证**

```bash
git add .
git commit -m "test(charts): 阶段 1 柱状图/条形图运行期验证

- 单系列/双系列堆叠正常渲染
- 负值柱从零轴正确方向延伸
- 柱体样式、动画、命中测试全部通过
- ChartSelfTest 全部断言通过
- 条形图功能对齐"
```

---

## Task 16: 编写使用指南文档

**Files:**
- Create: `docs/charts-column-guide.md`

- [ ] **Step 1: 创建柱状图使用指南**

创建新文件 `docs/charts-column-guide.md`：

```markdown
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
```

- [ ] **Step 2: 提交文档**

```bash
git add docs/charts-column-guide.md
git commit -m "docs(charts): 柱状图/条形图使用指南

- 30 秒上手示例
- 数据模型和主题配置
- 堆叠和负值处理
- 完整示例代码"
```

---

## 验收清单

完成所有任务后，验证以下内容：

**功能验收**：
- [ ] 单系列柱状/条形图正常渲染
- [ ] 负值柱体从零轴正确方向延伸
- [ ] 双系列普通堆叠正确累积
- [ ] 锯齿 series 堆叠归一化处理
- [ ] 柱体宽度、圆角、边框样式正确应用
- [ ] 入场动画柱体从零轴升起
- [ ] 命中测试返回正确的系列索引和数据点索引

**质量验收**：
- [ ] ChartSelfTest 全部断言通过
- [ ] iOS 模拟器运行无崩溃、无渲染错位
- [ ] ContentView 入口可切换到 Column/Bar demo
- [ ] 实时属性面板可调整所有配置项
- [ ] 使用指南文档完整

**文档验收**：
- [ ] 设计文档已提交
- [ ] 实施计划已提交
- [ ] 使用指南已提交

---

**预计工期**：7-8 个工作日
**难度**：中等（堆叠数学、零轴计算）
**依赖**：阶段 0 Cartesian 基础层
**后续阶段**：阶段 2（样条曲线 + 面积图）
