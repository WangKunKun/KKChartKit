# Heatmap 热力图图表 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 HYMCharts 框架中新增「热力图（格子色块图）」图表类型：根据二维数据（如每日百分比）将每个格子映射为颜色，行数与每行格子数均不固定，按可用渲染区域 + 列数自适应计算正方形格子尺寸。

**Architecture:** 沿用框架既定组合——实现 `HeatmapChartRenderer: HYMChartRenderer` + 自有 `HeatmapChartModel`/`HeatmapChartTheme`，复用通用容器 `HYMChartView<Renderer>` 与 `HYMColorInterpolation`。布局抽成纯函数 `HeatmapGeometry`（便于 DEBUG 自检），外观全部集中到 `HeatmapChartTheme`（含色阶 `HeatmapColorScale`）。**不改任何 Core 文件**，纯扩展。OC 兼容走 `OCBridge/` 三件套，SwiftUI 走 `UIViewRepresentable` 包装，与雷达图完全同构。

**Tech Stack:** Swift / UIKit（CALayer 子树）/ SwiftUI（UIViewRepresentable）/ Objective-C 桥接（@objcMembers）。部署目标 iOS 26.2。

---

## 本仓库执行约定（来自 CLAUDE.md 与项目记忆，覆盖 skill 默认模板）

执行本计划时**必须**遵守以下约定（它们与 writing-plans 的标准模板有意不同）：

1. **不主动 commit。** 默认把改动堆在工作区，用编译/运行/leaks 验证。每个 Task 的完成标志是 `** BUILD SUCCEEDED **`（及相关验证通过），**不写 `git commit` 步骤**。仅当用户明确要求时才 commit。
2. **测试 = `ChartSelfTest` DEBUG 断言，不是 XCTest。** 项目图表模块用 `Charts/Debug/ChartSelfTest.swift`（`#if DEBUG` + `assert`），App 启动在 `ContentView.onAppear` 调 `ChartSelfTest.runAll()`。纯函数的「测试」就是往这里加 `assert`；运行 app 看控制台 `✅ ChartSelfTest passed` 即通过。视觉/渲染用模拟器截图验证。
3. **以 `xcodebuild` 为唯一权威。** SourceKit 持续大面积假阳性（`No such module 'UIKit'` / 跨文件 `Cannot find type`）属正常现象，**不要为假阳性改代码**。只要 `** BUILD SUCCEEDED **` 即正确。
4. **整树同步编译。** `objectVersion 77` 下 `SwiftFunctionProject/` 整树自动编译，新增文件**无需改 pbxproj**；但严禁与已有 `.swift` 同名（会触发 `Multiple commands produce ...stringsdata`）。
5. **内核纯 Swift，OC 兼容走 OCBridge。** Model/Theme/Renderer/Geometry 不带 `@objc`；OC 用 `HYMHeatmap*Bridge` 桥接。
6. **新增图表 = 新增 `Charts/Heatmap/` 目录 + `HYMChartView<HeatmapChartRenderer>()`，不改 Core。**

### 验证命令（执行时使用）

```bash
# 编译（权威）
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 运行（当前 booted 模拟器；记忆参考 UDID FB74ECC0-DDCA-4168-A93D-81B91C56432C / iPhone 17 Pro / iOS 26.4）
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Build/Products/Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject

# 看自检输出（ChartSelfTest 打印）
xcrun simctl spawn booted log stream --predicate 'process == "SwiftFunctionProject"' --level debug --timeout 5

# 截图
xcrun simctl io booted screenshot /tmp/heatmap.png
```

---

## 待确认决策（计划采用如下默认假设；用户后续通知时可调整）

| #   | 决策点         | 计划默认                                                                                                  | 备注                              |
| --- | ----------- | ----------------------------------------------------------------------------------------------------- | ------------------------------- |
| D1  | 数据 Model 结构 | `rows: [[HeatmapCell]]` 二维 + 可选 `valueRange`/`rowLabels`/`columnLabels`；`HeatmapCell` 支持 per-cell 覆盖色 | 锯齿行天然支持                         |
| D2  | 色阶档位        | `HeatmapColorScale`：`.none`/`.gradient(low,high)`/`.stops([(value,color)])`，默认绿色 `.gradient`          | 复用 `HYMColorInterpolation.lerp` |
| D3  | 入场动画        | 复用容器整体opacity；波浪式逐格动画**本期不做**（YAGNI，标注未来扩展）                                                           | `showsEntranceAnimation` 开关     |
| D4  | OC 桥接       | 提供完整三件套（Cell/Theme/View Bridge）                                                                       | 与雷达图一致                          |
| D5  | 交互 hitTest  | 实现点击命中格子（返回 `HeatmapHitTarget{row,column}`），选中时加边框（可设置颜色，宽度，圆角-默认和格子圆角相同）                             | 框架首个真实交互实现                      |
| D6  | 纵向对齐        | 顶部对齐（避免标签错位）；横向 `.leading/.center/.trailing` 可配                                                       | 默认 `.leading`                   |
| D7  | 颜色映射基准      | 全局 `resolvedValueRange`（跨格统一可比）；per-cell `color` 非空则覆盖                                                | 空/单值回退 `0...1`                  |

> 任一决策若与用户后续通知不符，**仅影响对应 Task**，不影响整体架构。

---

## File Structure

全部位于 `SwiftFunctionProject/Charts/`（整树自动编译，无需改 pbxproj）。

| 文件 | 职责 | 阶段 |
|------|------|------|
| `Heatmap/HeatmapChartModel.swift` | 数据：`HeatmapCell` + `HeatmapChartModel` + `resolvedValueRange`/`maxColumns`（纯值类型） | 1 |
| `Heatmap/HeatmapGeometry.swift` | 布局纯函数：`layout()` 算正方形 cellSize + 对齐偏移，`cellFrame()` 算格子 frame | 1 |
| `Heatmap/HeatmapChartTheme.swift` | 外观：`HeatmapColorScale` 色阶 + `HeatmapHorizontalAlignment` + `HeatmapChartTheme`（纯值类型） | 1 |
| `Heatmap/HeatmapChartRenderer.swift` | 渲染器：`HYMChartRenderer` 实现 + `HeatmapHitTarget`；layer 子树 + 标签 + 命中 | 1 |
| `SwiftUI/HeatmapChart.swift` | SwiftUI 封装（`UIViewRepresentable` 包装 `HYMChartView<HeatmapChartRenderer>`） | 1 |
| `SwiftUI/HeatmapChartDemo.swift` | Demo 页（5×7 随机百分比 + 行列标签） | 1 |
| `Charts/Debug/ChartSelfTest.swift` | **修改**：增量加热力图几何/色阶断言 | 1 |
| `ContentView.swift` | **修改**：List 加「热力图」Section + 导航 | 1 |
| `OCBridge/HYMHeatmapCellBridge.swift` | OC 单格桥接 | 2 |
| `OCBridge/HYMHeatmapThemeBuilder.swift` | OC 主题构造器（属性 → build() struct） | 2 |
| `OCBridge/HYMHeatmapChartViewBridge.swift` | OC 视图桥接（持有泛型容器） | 2 |

职责边界：Model 只管数据；Geometry 只管几何（无 UIKit 依赖，仅 CoreGraphics）；Theme 只管外观；Renderer 编排三者并绘制；OCBridge 仅做类型翻译，不含绘制逻辑。

---

## 阶段 1：核心图表（完成后即可在 SwiftUI Demo 中运行、截图验证）

### Task 1: HeatmapChartModel

**Files:**
- Create: `SwiftFunctionProject/Charts/Heatmap/HeatmapChartModel.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import Foundation
import CoreGraphics
import UIKit

/// 热力图单个格子（纯值类型）。
public struct HeatmapCell {
    /// 原始数值（如百分比 0~100，或任意量纲）。
    public var value: Double
    /// 满值，用于单格归一化；默认 100。<=0 时按 1 兜底。
    public var maxValue: Double
    /// 单格覆盖色；nil → 由 Theme 色阶按全局值域归一化计算。
    public var color: UIColor?

    public init(value: Double, maxValue: Double = 100, color: UIColor? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
    }

    /// 单格自归一化比值 [0,1]（越界裁剪；内部使用）。
    public var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }
}

/// 热力图数据（外观分离到 Theme，由 `configure(model:theme:)` 单独传入）。
///
/// `rows` 为二维数组：外层=行（自上而下），内层=该行格子（自左而右）。
/// 行数与每行格子数均不固定，支持锯齿行（每行长度不同）。
public struct HeatmapChartModel: HYMChartModel {
    public var rows: [[HeatmapCell]]
    /// 色阶归一化基准；nil → 自动按全体 value 的 min/max。用于跨格子统一可比的色阶映射。
    public var valueRange: ClosedRange<Double>?
    /// 可选行标签（左侧），长度应等于 rows.count；nil 不显示。
    public var rowLabels: [String]?
    /// 可选列标签（顶部），长度应等于 maxColumns；nil 不显示。
    public var columnLabels: [String]?

    public init(rows: [[HeatmapCell]],
                valueRange: ClosedRange<Double>? = nil,
                rowLabels: [String]? = nil,
                columnLabels: [String]? = nil) {
        self.rows = rows
        self.valueRange = valueRange
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
    }

    /// 实际生效的归一化值域；显式 nil/数据为空/极差为 0 时回退 0...1（纯函数，便于自检）。
    public var resolvedValueRange: ClosedRange<Double> {
        if let r = valueRange { return r }
        let vals = rows.flatMap { $0 }.map { $0.value }
        guard let lo = vals.min(), let hi = vals.max(), hi > lo else {
            return 0...1
        }
        return lo...hi
    }

    /// 最大列数（锯齿行取最长行）。
    public var maxColumns: Int {
        rows.map { $0.count }.max() ?? 0
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`（SourceKit 报 `Cannot find 'HYMChartModel'` 属假阳性，忽略）

---

### Task 2: HeatmapGeometry（布局纯函数 + 自检）

**Files:**
- Create: `SwiftFunctionProject/Charts/Heatmap/HeatmapGeometry.swift`
- Modify: `SwiftFunctionProject/Charts/Heatmap/HeatmapChartTheme.swift`（Task 3 才创建；本 Task 不依赖 Theme 的具体定义，但 `layout()` 签名引用 `HeatmapHorizontalAlignment`，故需先在 Theme 文件定义该 enum —— 见下方说明）

> **依赖说明：** `HeatmapHorizontalAlignment` 定义在 `HeatmapChartTheme.swift`（Task 3）。为避免 Task 2 编译失败，**先在 Task 2 创建一个仅含该 enum 的临时声明是冗余的**；实际做法：本 Task 与 Task 3 在同一工作批次创建，二者同属阶段 1。执行时可**先做 Task 3 的 Step 1（创建 Theme 文件，含 enum 与色阶）再做本 Task**，或两个文件一起创建后统一编译。下方代码按「Theme 已存在」前提给出。

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import CoreGraphics

/// 热力图布局纯函数（便于 DEBUG 自检；仅依赖 CoreGraphics）。
public enum HeatmapGeometry {
    /// 布局结果。
    public struct Layout {
        public var cellSize: CGFloat          // 正方形边长
        public var gridOrigin: CGPoint        // 第一个格子（row=0,col=0）左上角（含对齐偏移）
        public var contentWidth: CGFloat      // 格子区域实际宽度
        public var contentHeight: CGFloat     // 格子区域实际高度
    }

    /// 根据可用区域、行列数、间距、对齐，计算正方形格子尺寸与原点。
    ///
    /// 正方形约束：cellSize = min(可用宽/列数, 可用高/行数)，已扣除格子间距。
    /// 纵向恒为顶部对齐（避免行标签错位）；横向按 `alignment`。
    ///
    /// - Parameters:
    ///   - bounds: 可用绘制区域
    ///   - rows: 行数
    ///   - columns: 最大列数
    ///   - spacing: 格子间距（水平=垂直）
    ///   - alignment: 水平对齐
    /// - Returns: 布局结果；rows/columns <= 0 时 cellSize=0
    public static func layout(
        bounds: CGRect, rows: Int, columns: Int,
        spacing: CGFloat, alignment: HeatmapHorizontalAlignment
    ) -> Layout {
        guard rows > 0, columns > 0 else {
            return Layout(cellSize: 0, gridOrigin: bounds.origin,
                          contentWidth: 0, contentHeight: 0)
        }
        let usableW = max(0, bounds.width - CGFloat(columns - 1) * spacing)
        let usableH = max(0, bounds.height - CGFloat(rows - 1) * spacing)
        let byW = usableW / CGFloat(columns)
        let byH = usableH / CGFloat(rows)
        let size = floor(max(0, min(byW, byH)))
        let contentW = CGFloat(columns) * size + CGFloat(columns - 1) * spacing
        let contentH = CGFloat(rows) * size + CGFloat(rows - 1) * spacing
        let xOffset: CGFloat
        switch alignment {
        case .leading:  xOffset = bounds.minX
        case .center:   xOffset = bounds.minX + (bounds.width - contentW) / 2
        case .trailing: xOffset = bounds.maxX - contentW
        }
        let yOffset = bounds.minY
        return Layout(cellSize: size,
                      gridOrigin: CGPoint(x: xOffset, y: yOffset),
                      contentWidth: contentW,
                      contentHeight: contentH)
    }

    /// 第 (row, col) 个格子的 frame（相对 gridOrigin 同坐标系）。
    public static func cellFrame(row: Int, col: Int, layout: Layout, spacing: CGFloat) -> CGRect {
        let step = layout.cellSize + spacing
        let x = layout.gridOrigin.x + CGFloat(col) * step
        let y = layout.gridOrigin.y + CGFloat(row) * step
        return CGRect(x: x, y: y, width: layout.cellSize, height: layout.cellSize)
    }
}
```

- [ ] **Step 2: 编译验证（与 Task 3 合并编译）**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: HeatmapChartTheme（色阶 + 主题）

**Files:**
- Create: `SwiftFunctionProject/Charts/Heatmap/HeatmapChartTheme.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import UIKit

/// 热力图水平对齐方式。
public enum HeatmapHorizontalAlignment {
    case leading, center, trailing
}

/// 热力图色阶映射模式。
public enum HeatmapColorScale {
    /// 不映射（统一透明；适合每格自带 color）。
    case none
    /// 两点线性：归一化 t∈[0,1]，low → high。
    case gradient(low: UIColor, high: UIColor)
    /// 多段：按 value（原始值）升序的 (value, color) 锚点，首尾 value 作归一化基准，相邻段线性插值。
    case stops([(value: Double, color: UIColor)])

    /// 取归一化比值 t∈[0,1]（越界裁剪）对应的颜色（纯函数）。
    public func color(at normalizedT: CGFloat) -> UIColor {
        let t = max(0, min(1, normalizedT))
        switch self {
        case .none:
            return .clear
        case .gradient(let low, let high):
            return HYMColorInterpolation.lerp(low, high, t)
        case .stops(let pairs):
            return HeatmapColorScale.lerpStops(pairs, t: t)
        }
    }

    /// 多段插值（纯函数，便于自检）。stops 须按 value 升序。
    static func lerpStops(_ stops: [(value: Double, color: UIColor)], t: CGFloat) -> UIColor {
        guard let first = stops.first, let last = stops.last else { return .clear }
        guard last.value > first.value else { return last.color }
        let value = first.value + Double(t) * (last.value - first.value)
        if value <= first.value { return first.color }
        if value >= last.value { return last.color }
        for i in 1..<stops.count {
            let prev = stops[i - 1]
            let cur = stops[i]
            if value <= cur.value {
                let span = cur.value - prev.value
                let localT = span > 0 ? (value - prev.value) / span : 0
                return HYMColorInterpolation.lerp(prev.color, cur.color, CGFloat(localT))
            }
        }
        return last.color
    }
}

/// 热力图主题（纯值类型；所有外观集中于此，改色只动这里）。
public struct HeatmapChartTheme: HYMChartTheme {
    public var colorScale: HeatmapColorScale
    /// 空数据格子底色（value 落在值域下界以下时也用它）。
    public var emptyColor: UIColor
    /// `.none` 色阶时的统一填充色。
    public var baseColor: UIColor
    /// 格子圆角半径。
    public var cellCornerRadius: CGFloat
    /// 格子间距（水平=垂直）。
    public var cellSpacing: CGFloat
    /// 内容相对可用区域的外边距。
    public var contentInset: CGFloat
    /// 格子整体在可用宽度内的水平对齐。
    public var horizontalAlignment: HeatmapHorizontalAlignment
    /// 背景（nil 透明）。
    public var backgroundColor: UIColor?
    /// 背景圆角。
    public var backgroundCornerRadius: CGFloat
    /// 行/列标签颜色与字体。
    public var labelColor: UIColor
    public var labelFont: UIFont
    /// 标签与格子的间距。
    public var labelGap: CGFloat
    /// 是否显示行列标签（即便 model 提供）。
    public var showsLabels: Bool
    /// 是否参与入场动画（整体 scale+opacity）。
    public var showsEntranceAnimation: Bool

    public init(
        colorScale: HeatmapColorScale = .gradient(
            low: UIColor(red: 0x9b/255.0, green: 0xe9/255.0, blue: 0xa8/255.0, alpha: 1),
            high: UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1)),
        emptyColor: UIColor = UIColor(red: 0xeb/255.0, green: 0xed/255.0, blue: 0xf0/255.0, alpha: 1),
        baseColor: UIColor = UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1),
        cellCornerRadius: CGFloat = 2,
        cellSpacing: CGFloat = 3,
        contentInset: CGFloat = 0,
        horizontalAlignment: HeatmapHorizontalAlignment = .leading,
        backgroundColor: UIColor? = nil,
        backgroundCornerRadius: CGFloat = 0,
        labelColor: UIColor = UIColor(red: 0x58/255.0, green: 0x60/255.0, blue: 0x66/255.0, alpha: 1),
        labelFont: UIFont = .systemFont(ofSize: 10),
        labelGap: CGFloat = 6,
        showsLabels: Bool = true,
        showsEntranceAnimation: Bool = true
    ) {
        self.colorScale = colorScale
        self.emptyColor = emptyColor
        self.baseColor = baseColor
        self.cellCornerRadius = cellCornerRadius
        self.cellSpacing = cellSpacing
        self.contentInset = contentInset
        self.horizontalAlignment = horizontalAlignment
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = backgroundCornerRadius
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.labelGap = labelGap
        self.showsLabels = showsLabels
        self.showsEntranceAnimation = showsEntranceAnimation
    }
}
```

- [ ] **Step 2: 编译验证（与 Task 2 合并）**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

### Task 4: HeatmapChartRenderer（渲染器 + 命中目标）

**Files:**
- Create: `SwiftFunctionProject/Charts/Heatmap/HeatmapChartRenderer.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import UIKit

/// 热力图命中目标（点击格子时产生）。
public struct HeatmapHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let row: Int
    public let column: Int
    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
        self.identifier = "(\(row),\(column))"
        self.index = row * 1000 + column
    }
}

/// 热力图渲染器：实现 HYMChartRenderer。绘制二维格子色块 + 可选行列标签 + 点击命中。
///
/// 性能策略：每格一个 CALayer（圆角/动画天然，与雷达图「每元素一 layer」风格一致）。
/// 格子均挂在 `cellsContainerLayer` 下，入场动画整体 scale。若未来格子达数百级，
/// 可改为单 layer `draw(context:)` 批量绘制（Renderer 内部自由度，不影响协议）。
public final class HeatmapChartRenderer: HYMChartRenderer {
    public typealias Model = HeatmapChartModel
    public typealias Theme = HeatmapChartTheme

    public init() {}

    // MARK: - layer 子树
    private let backgroundLayer = CALayer()      // 背景色块（圆角，可选）
    private let cellsContainerLayer = CALayer()  // 所有格子容器（动画单元）
    private weak var hostView: UIView?
    private var rowLabels: [UILabel] = []
    private var columnLabels: [UILabel] = []

    // MARK: - 当前状态（render 时存，供动画/命中读取）
    private var currentModel: HeatmapChartModel?
    private var currentTheme: HeatmapChartTheme?
    /// 命中检测缓存：渲染后的格子 frame（view 坐标系，因容器 frame=bounds）
    private var lastCellFrames: [(row: Int, col: Int, frame: CGRect)] = []

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(cellsContainerLayer)
    }

    public func unmount(from view: UIView) {
        rowLabels.forEach { $0.removeFromSuperview() }
        columnLabels.forEach { $0.removeFromSuperview() }
        rowLabels.removeAll()
        columnLabels.removeAll()
        cellsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        [backgroundLayer, cellsContainerLayer].forEach { $0.removeFromSuperlayer() }
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] {
        guard currentTheme?.showsEntranceAnimation == true else { return [] }
        return [cellsContainerLayer]
    }
    // centerScoreTarget / updateEntranceAnimation / applySelection 用协议默认实现（热力图不需要）

    // MARK: - render
    public func render(model: HeatmapChartModel, theme: HeatmapChartTheme, context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastCellFrames.removeAll()
        cellsContainerLayer.frame = context.bounds

        // 背景
        if let bg = theme.backgroundColor {
            backgroundLayer.isHidden = false
            backgroundLayer.frame = context.bounds
            backgroundLayer.backgroundColor = bg.cgColor
            backgroundLayer.cornerRadius = theme.backgroundCornerRadius
        } else {
            backgroundLayer.isHidden = true
        }

        // 清空旧格子
        cellsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        // 清空旧标签
        rowLabels.forEach { $0.removeFromSuperview() }; rowLabels.removeAll()
        columnLabels.forEach { $0.removeFromSuperview() }; columnLabels.removeAll()

        guard !model.rows.isEmpty, model.maxColumns > 0 else { return }

        // 1) 计算标签占位 → 格子可用区域
        let (cellBounds, rowLabelWidth, columnLabelHeight) = resolveContentArea(
            bounds: context.bounds, model: model, theme: theme)

        // 2) 布局
        let layout = HeatmapGeometry.layout(
            bounds: cellBounds, rows: model.rows.count, columns: model.maxColumns,
            spacing: theme.cellSpacing, alignment: theme.horizontalAlignment)

        // 3) 色阶值域
        let range = model.resolvedValueRange
        let span = range.upperBound - range.lowerBound

        // 4) 绘制格子
        for (r, row) in model.rows.enumerated() {
            for (c, cell) in row.enumerated() {
                let f = HeatmapGeometry.cellFrame(row: r, col: c, layout: layout, spacing: theme.cellSpacing)
                lastCellFrames.append((r, c, f))
                let layer = CALayer()
                layer.frame = f
                layer.cornerRadius = theme.cellCornerRadius
                layer.backgroundColor = resolvedColor(for: cell, range: range, span: span, theme: theme).cgColor
                cellsContainerLayer.addSublayer(layer)
            }
        }

        // 5) 标签
        rebuildLabels(model: model, theme: theme, layout: layout, cellStep: layout.cellSize + theme.cellSpacing)
        _ = rowLabelWidth; _ = columnLabelHeight  // 已并入 cellBounds，此处保留命名便于阅读
    }

    // MARK: - 单格取色（per-cell 覆盖 > 色阶 > empty）
    private func resolvedColor(for cell: HeatmapCell,
                               range: ClosedRange<Double>, span: Double,
                               theme: HeatmapChartTheme) -> UIColor {
        if let override = cell.color { return override }
        let t = span > 0 ? (cell.value - range.lowerBound) / span : 1.0
        let c = theme.colorScale.color(at: CGFloat(t))
        return c == .clear ? theme.emptyColor : c
    }

    // MARK: - 内容区域（扣除标签占位与外边距）
    private func resolveContentArea(bounds: CGRect, model: HeatmapChartModel, theme: HeatmapChartTheme)
        -> (cellBounds: CGRect, rowLabelWidth: CGFloat, columnLabelHeight: CGFloat) {
        var rowLabelW: CGFloat = 0
        var colLabelH: CGFloat = 0
        if theme.showsLabels {
            if let labels = model.rowLabels, labels.count == model.rows.count {
                rowLabelW = (labels.map { textSize($0, font: theme.labelFont).width }.max() ?? 0) + theme.labelGap
            }
            if let labels = model.columnLabels, labels.count == model.maxColumns {
                colLabelH = textSize(labels.first ?? "", font: theme.labelFont).height + theme.labelGap
            }
        }
        let cellBounds = bounds
            .insetBy(dx: theme.contentInset, dy: theme.contentInset)
            .insetBy(dx: rowLabelW, dy: 0)   // 左侧让出行标签
            .insetBy(dx: 0, dy: colLabelH)   // 顶部让出列标签
        return (cellBounds, rowLabelW, colLabelH)
    }

    private func textSize(_ s: String, font: UIFont) -> CGSize {
        (s as NSString).size(withAttributes: [.font: font])
    }

    // MARK: - 标签
    private func rebuildLabels(model: HeatmapChartModel, theme: HeatmapChartTheme,
                               layout: HeatmapGeometry.Layout, cellStep: CGFloat) {
        guard let view = hostView, theme.showsLabels else { return }
        let ox = layout.gridOrigin.x
        let oy = layout.gridOrigin.y

        if let labels = model.rowLabels, labels.count == model.rows.count {
            for r in 0..<model.rows.count {
                let lbl = UILabel()
                lbl.text = labels[r]
                lbl.textColor = theme.labelColor
                lbl.font = theme.labelFont
                lbl.sizeToFit()
                let cy = oy + CGFloat(r) * cellStep + layout.cellSize / 2
                lbl.center = CGPoint(x: ox - theme.labelGap - lbl.bounds.width / 2, y: cy)
                view.addSubview(lbl)
                rowLabels.append(lbl)
            }
        }
        if let labels = model.columnLabels, labels.count == model.maxColumns {
            for c in 0..<model.maxColumns {
                let lbl = UILabel()
                lbl.text = labels[c]
                lbl.textColor = theme.labelColor
                lbl.font = theme.labelFont
                lbl.sizeToFit()
                let cx = ox + CGFloat(c) * cellStep + layout.cellSize / 2
                lbl.center = CGPoint(x: cx, y: oy - theme.labelGap - lbl.bounds.height / 2)
                view.addSubview(lbl)
                columnLabels.append(lbl)
            }
        }
    }

    // MARK: - 命中（覆盖协议默认 nil 实现）
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard currentModel != nil else { return nil }
        for hit in lastCellFrames where hit.frame.contains(point) {
            return HeatmapHitTarget(row: hit.row, column: hit.col)
        }
        return nil
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

### Task 5: ChartSelfTest 自检（几何 + 色阶 + 命中）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 `runAll()` 末尾、`print("✅ ChartSelfTest passed")` 之前，插入热力图断言**

定位标记：在现有 `// —— 交互默认空命中 ——` 区块之后、`print("✅ ChartSelfTest passed")` 之前插入。

```swift
        // —— HeatmapGeometry：3 行 4 列，bounds 30×30，spacing 0 → cellSize=10，左上对齐 ——
        let hLayout = HeatmapGeometry.layout(
            bounds: CGRect(x: 0, y: 0, width: 30, height: 30),
            rows: 3, columns: 4, spacing: 0, alignment: .leading)
        assert(abs(hLayout.cellSize - 7.0) < 0.001,
               "heatmap cellSize should be min(30/4, 30/3)=7, got \(hLayout.cellSize)")
        let hCell00 = HeatmapGeometry.cellFrame(row: 0, col: 0, layout: hLayout, spacing: 0)
        assert(abs(hCell00.minX) < 0.001 && abs(hCell00.minY) < 0.001,
               "heatmap (0,0) should be at origin, got \(hCell00)")
        let hCell12 = HeatmapGeometry.cellFrame(row: 1, col: 2, layout: hLayout, spacing: 0)
        assert(abs(hCell12.minX - 14.0) < 0.001 && abs(hCell12.minY - 7.0) < 0.001,
               "heatmap (1,2) origin wrong, got \(hCell12)")

        // center 对齐：宽度方向居中
        let hCenter = HeatmapGeometry.layout(
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            rows: 1, columns: 1, spacing: 0, alignment: .center)
        assert(abs(hCenter.cellSize - 100) < 0.001 && abs(hCenter.gridOrigin.x) < 0.001,
               "center single-cell origin wrong")

        // rows/columns<=0 → cellSize 0
        let hEmpty = HeatmapGeometry.layout(bounds: CGRect(x: 0, y: 0, width: 50, height: 50),
                                            rows: 0, columns: 4, spacing: 0, alignment: .leading)
        assert(hEmpty.cellSize == 0, "empty rows should give cellSize 0")

        // —— HeatmapChartModel.resolvedValueRange / maxColumns ——
        let hModel = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell(value: 20), HeatmapCell(value: 30)],
            [HeatmapCell(value: 40), HeatmapCell(value: 50)]   // 锯齿行
        ])
        assert(hModel.maxColumns == 3, "maxColumns should be 3, got \(hModel.maxColumns)")
        let hRange = hModel.resolvedValueRange
        assert(abs(hRange.lowerBound - 10) < 0.001 && abs(hRange.upperBound - 50) < 0.001,
               "resolved range should be 10...50, got \(hRange)")
        let hManualRange = HeatmapChartModel(rows: [[HeatmapCell(value: 5)]], valueRange: 0...100)
        assert(hManualRange.resolvedValueRange == 0...100, "manual range should win")

        // —— HeatmapColorScale：gradient 端点 ——
        let hScale = HeatmapColorScale.gradient(low: .black, high: .white)
        assertTintsEqual(hScale.color(at: 0), (0, 0, 0), eps: 0.001, msg: "scale t=0 should be black")
        assertTintsEqual(hScale.color(at: 1), (1, 1, 1), eps: 0.001, msg: "scale t=1 should be white")
        assertTintsEqual(hScale.color(at: 0.5), (0.5, 0.5, 0.5), eps: 0.01, msg: "scale t=0.5 should be mid gray")

        // —— HeatmapColorScale：stops ——
        let hStops = HeatmapColorScale.stops([(value: 0, color: .black), (value: 100, color: .white)])
        assertTintsEqual(hStops.color(at: 0.5), (0.5, 0.5, 0.5), eps: 0.01, msg: "stops t=0.5 should be mid gray")
        assertTintsEqual(hStops.color(at: 0), (0, 0, 0), eps: 0.001, msg: "stops t=0 should be black")

        // —— Heatmap 命中：默认空 model → nil；有数据 → 命中格子 ——
        let hRenderer = HeatmapChartRenderer()
        assert(hRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil,
               "renderer without render should hitTest nil")
        // 渲染后再命中（render 后 lastCellFrames 已填充）
        hRenderer.render(model: hModel, theme: HeatmapChartTheme(),
                        context: HYMChartRenderContext(
                            bounds: CGRect(x: 0, y: 0, width: 300, height: 200), center: .zero))
        if let hit = hRenderer.hitTest(CGPoint(x: 5, y: 5)) as? HeatmapHitTarget {
            assert(hit.row == 0 && hit.column == 0, "should hit (0,0), got \(hit.row),\(hit.column)")
        } else {
            assertionFailure("should hit (0,0) after render")
        }
```

> 说明：上面用到一个比较 UIColor 分量的小工具 `assertTintsEqual`，下一步加。

- [ ] **Step 2: 在 `ChartSelfTest` enum 内、`runAll()` 之前，添加颜色分量比较工具**

```swift
    /// 比较 UIColor RGB 分量（UIColor == 受色彩空间/精度影响不可靠，一律比分量）。
    static func assertTintsEqual(_ color: UIColor, _ expected: (CGFloat, CGFloat, CGFloat),
                                 eps: CGFloat, msg: String,
                                 file: StaticString = #file, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        assert(abs(r - expected.0) < eps && abs(g - expected.1) < eps && abs(b - expected.2) < eps,
               "\(msg): got r=\(r) g=\(g) b=\(b)", file: file, line: line)
    }
```

- [ ] **Step 3: 编译 + 运行，确认自检通过**

Run:
```bash
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
xcrun simctl spawn booted log stream --predicate 'process == "SwiftFunctionProject"' --level debug --timeout 5
```
Expected: 编译 `** BUILD SUCCEEDED **`；日志含 `✅ ChartSelfTest passed`（无 assert 崩溃）。

---

### Task 6: SwiftUI 封装 + Demo 页 + ContentView 入口

**Files:**
- Create: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChart.swift`
- Create: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChartDemo.swift`
- Modify: `SwiftFunctionProject/ContentView.swift`

- [ ] **Step 1: 创建 `HeatmapChart.swift`**

```swift
import SwiftUI

/// SwiftUI 热力图封装（UIViewRepresentable 包装通用容器）。
public struct HeatmapChart: View {
    private let model: HeatmapChartModel
    private let theme: HeatmapChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    public init(model: HeatmapChartModel,
                theme: HeatmapChartTheme = HeatmapChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear, onHit: onHit)
    }
}

struct HeatmapChartRepresentable: UIViewRepresentable {
    let model: HeatmapChartModel
    let theme: HeatmapChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<HeatmapChartRenderer> {
        let chart = HYMChartView<HeatmapChartRenderer>(frame: .zero)
        chart.onHit = onHit
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<HeatmapChartRenderer>, context: Context) {
        uiView.onHit = onHit
        uiView.configure(model: model, theme: theme)
    }
}
```

- [ ] **Step 2: 创建 `HeatmapChartDemo.swift`**

```swift
import SwiftUI

/// 热力图 demo：5 行 × 7 列随机百分比，含行列标签。
struct HeatmapChartDemo: View {
    private static let model: HeatmapChartModel = {
        var rows: [[HeatmapCell]] = []
        let values: [[Double]] = [
            [12, 34, 56, 78, 90, 45, 23],
            [67, 89, 12, 34, 56, 78, 90],
            [45, 23, 67, 89, 12, 34, 56],
            [78, 90, 45, 23, 67, 89, 12],
            [34, 56, 78, 90, 45, 23, 67],
        ]
        rows = values.map { row in row.map { HeatmapCell(value: $0) } }
        return HeatmapChartModel(
            rows: rows,
            rowLabels: ["W1", "W2", "W3", "W4", "W5"],
            columnLabels: ["一", "二", "三", "四", "五", "六", "日"])
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 热力图（默认绿色梯度）")
                    .font(.headline)
                HeatmapChart(model: Self.model)
                    .frame(height: 220)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("热力图 demo")
    }
}
```

- [ ] **Step 3: 修改 `ContentView.swift`，在 List 中新增「热力图」Section**

在现有 `Section("雷达图") { ... }` 之后、`.navigationTitle` 之前，插入：

```swift
                Section("热力图") {
                    NavigationLink("默认 demo") {
                        HeatmapChartDemo()
                    }
                }
```

- [ ] **Step 4: 编译 + 运行 + 截图验证**

Run:
```bash
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
xcrun simctl io booted screenshot /tmp/heatmap-home.png
```
Expected: `** BUILD SUCCEEDED **`；首页 List 出现「热力图」Section 与「默认 demo」入口。手动导航进入并截图：

```bash
xcrun simctl io booted screenshot /tmp/heatmap-grid.png
```
Expected: 截图可见 5×7 绿色梯度格子（值越大越深），左侧 W1–W5 行标签、顶部 一–日 列标签；入场时有整体缩放淡入。

- [ ] **Step 5:（可选）点击命中冒烟**

在 `HeatmapChartDemo` 临时加 `.onHit` 回调打日志，或后续 OC/交互阶段验证；本期框架层 `hitTest` 已由 Task 5 自检覆盖。

---

**阶段 1 验收标准：** BUILD SUCCEEDED + `✅ ChartSelfTest passed` + 截图可见正确热力图。到此处已是可工作的独立软件。

---

## 阶段 2：Objective-C 桥接（与雷达图 OCBridge 同构）

### Task 7: HYMHeatmapCellBridge

**Files:**
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapCellBridge.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import UIKit

/// OC 友好的热力图单格桥接：包装内部 `HeatmapCell`。
@objcMembers
public final class HYMHeatmapCellBridge: NSObject {
    @objc public var value: Double
    @objc public var maxValue: Double
    @objc public var color: UIColor?

    @objc public init(value: Double, maxValue: Double = 100, color: UIColor? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        super.init()
    }

    internal var heatCell: HeatmapCell {
        HeatmapCell(value: value, maxValue: maxValue, color: color)
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

### Task 8: HYMHeatmapThemeBuilder

**Files:**
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapThemeBuilder.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import UIKit

/// OC 友好的热力图主题构造器：属性赋值 → build() 成纯 Swift struct。
/// 覆盖 HeatmapChartTheme 全部字段。颜色/字体可选（nil → 用主题默认）。
/// `colorScaleType`：none/gradient/stops；
///   gradient 用 colorScaleColors[0..1]；stops 用 colorScaleValues + colorScaleColors（等长）。
/// `horizontalAlignment`：leading/center/trailing。
@objcMembers
public final class HYMHeatmapThemeBuilder: NSObject {
    // —— 色阶 ——
    @objc public var colorScaleType: String = "gradient"
    @objc public var colorScaleColors: [UIColor] = []
    @objc public var colorScaleValues: [NSNumber] = []
    @objc public var emptyColor: UIColor?
    @objc public var baseColor: UIColor?

    // —— 几何 ——
    @objc public var cellCornerRadius: CGFloat = 2
    @objc public var cellSpacing: CGFloat = 3
    @objc public var contentInset: CGFloat = 0
    @objc public var horizontalAlignment: String = "leading"

    // —— 背景 ——
    @objc public var backgroundColor: UIColor?
    @objc public var backgroundCornerRadius: CGFloat = 0

    // —— 标签 ——
    @objc public var labelColor: UIColor?
    @objc public var labelFont: UIFont?
    @objc public var labelGap: CGFloat = 6
    @objc public var showsLabels: Bool = true
    @objc public var showsEntranceAnimation: Bool = true

    @objc public override init() { super.init() }

    internal func build() -> HeatmapChartTheme {
        var t = HeatmapChartTheme()
        t.colorScale = buildColorScale(defaulting: t.colorScale)
        if let v = emptyColor { t.emptyColor = v }
        if let v = baseColor { t.baseColor = v }
        t.cellCornerRadius = cellCornerRadius
        t.cellSpacing = cellSpacing
        t.contentInset = contentInset
        t.horizontalAlignment = buildAlignment()
        t.backgroundColor = backgroundColor
        t.backgroundCornerRadius = backgroundCornerRadius
        if let v = labelColor { t.labelColor = v }
        if let v = labelFont { t.labelFont = v }
        t.labelGap = labelGap
        t.showsLabels = showsLabels
        t.showsEntranceAnimation = showsEntranceAnimation
        return t
    }

    private func buildColorScale(defaulting fallback: HeatmapColorScale) -> HeatmapColorScale {
        switch colorScaleType.lowercased() {
        case "none":
            return .none
        case "stops":
            guard colorScaleValues.count >= 2,
                  colorScaleColors.count == colorScaleValues.count else { return fallback }
            let pairs = zip(colorScaleValues, colorScaleColors)
                .map { (value: $0.doubleValue, color: $1) }
            return .stops(pairs)
        case "gradient", "":
            if colorScaleColors.count >= 2 {
                return .gradient(low: colorScaleColors[0], high: colorScaleColors[1])
            }
            return fallback
        default:
            return fallback
        }
    }

    private func buildAlignment() -> HeatmapHorizontalAlignment {
        switch horizontalAlignment.lowercased() {
        case "center":   return .center
        case "trailing": return .trailing
        default:         return .leading
        }
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

### Task 9: HYMHeatmapChartViewBridge

**Files:**
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapChartViewBridge.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
import UIKit

/// OC 友好的热力图视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMHeatmapChartViewBridge: NSObject {
    private let chart: HYMChartView<HeatmapChartRenderer>
    private let theme: HeatmapChartTheme

    /// OC 端命中回调：命中格子时触发 (row, column)。
    @objc public var onHit: ((NSInteger, NSInteger) -> Void)?

    @objc public init(theme: HYMHeatmapThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<HeatmapChartRenderer>(frame: frame)
        super.init()
        chart.onHit = { [weak self] target, _ in
            if let h = target as? HeatmapHitTarget {
                self?.onHit?(h.row, h.column)
            }
        }
    }

    /// OC 嵌入用（加入父 view）。
    @objc public var chartView: UIView { chart }

    /// 配置数据。rows 为嵌套数组；rowLabels/columnLabels 可传 nil。
    @objc public func configure(rows: [[HYMHeatmapCellBridge]],
                                rowLabels: [String]?,
                                columnLabels: [String]?) {
        let m = HeatmapChartModel(
            rows: rows.map { $0.map { $0.heatCell } },
            rowLabels: rowLabels,
            columnLabels: columnLabels)
        chart.configure(model: m, theme: theme)
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
```

- [ ] **Step 2: 编译验证（全量回归）**

Run:
```bash
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
xcrun simctl spawn booted log stream --predicate 'process == "SwiftFunctionProject"' --level debug --timeout 5
```
Expected: `** BUILD SUCCEEDED **` + `✅ ChartSelfTest passed`。

- [ ] **Step 3:（可选）内存泄漏检查**

Run:
```bash
PID=$(xcrun simctl spawn booted launchctl list | grep SwiftFunctionProject | awk '{print $1}')
xcrun simctl spawn booted leaks "$PID" 2>/dev/null | tail -5
```
Expected: 无 `leaks` 报告（或仅系统框架已知泄漏，非本组件）。

---

## Self-Review

**1. Spec 覆盖**（用户需求逐条）：
- 每日百分比 → 格子颜色：Task 3 `HeatmapColorScale` + Task 4 `resolvedColor`（按 `resolvedValueRange` 归一化） ✓
- 行数不固定：Task 1 `rows.count` 驱动 Task 2 `layout(rows:)` ✓
- 每行数量不固定（锯齿）：Task 1 `maxColumns` + Task 4 按每行各自 count 枚举 ✓
- 根据可用区域 + 每行数量算正方形 size：Task 2 `HeatmapGeometry.layout`（`min(可用宽/列数, 可用高/行数)`） ✓
- 默认正方形：Task 2 `cellSize = floor(min(byW, byH))` ✓
- 嵌入图表库：Task 4 `HeatmapChartRenderer: HYMChartRenderer` + `HYMChartView<HeatmapChartRenderer>`，不改 Core ✓

**2. 占位符扫描：** 无 TBD/TODO；每个代码步骤含完整可编译代码；命令含预期输出。

**3. 类型一致性：**
- `HeatmapChartModel: HYMChartModel`；`HeatmapChartTheme: HYMChartTheme`；Renderer `typealias Model/Theme` 对齐 ✓
- `HeatmapGeometry.layout/cellFrame`、`HeatmapColorScale.color(at:)`、`HeatmapHitTarget(row:column:)` 在 Renderer/Demo/Bridge 调用处签名一致 ✓
- `assertTintsEqual` 定义（Task 5 Step 2）先于使用（Task 5 Step 1）—— **执行顺序注意**：Step 2 的工具方法须在 Step 1 的断言之前编译生效；因同文件、同 `#if DEBUG` 块，Swift 不要求声明顺序，编译无碍 ✓
- `HeatmapHorizontalAlignment` 定义于 Theme（Task 3），被 Geometry（Task 2）与 ThemeBuilder（Task 8）引用；Task 2/3 须同批次创建 ✓

**4. 风险点（执行时留意）：**
- 入场动画期间 `cellsContainerLayer` 处于非 identity transform，`hitTest` 用静态 frame 命中会偏移；动画结束（identity）后正常。可接受。
- 标签用 `UILabel`（`addSubview`），不随格子 scale 动画——符合预期（标签静态）。
- 锯齿行 + `center/trailing` 对齐时，短行格子仍从同一 `gridOrigin.x` 起算（左对齐到对齐后原点），视觉上短行靠左；若需每行各自居中需扩展 Theme，本期不做（YAGNI）。

---

## 未来扩展（不在本期，避免过度设计）

- 波浪式逐格入场动画（需容器扩展逐格进度驱动，或 Renderer 内自建 DisplayLink）。
- 单格 tooltip 弹层 / 选中高亮（`applySelection` 实现）。
- 单 layer `draw(context:)` 批量绘制（格子数百级时的性能优化）。
- 时间轴语义（GitHub 周对齐）作为上层 Model 组装，不进核心组件。
