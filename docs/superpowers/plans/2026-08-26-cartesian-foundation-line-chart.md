# 阶段 0：Cartesian 轴系基础层 + 折线图 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建 Cartesian 轴系基础层（模型/刻度算法/几何/主题/渲染基类/轴与网格组件），并以折线图作为首个薄 Renderer 落地，配 ChartDemoPanel 实时属性面板 demo。

**Architecture:** 延续 HYMCharts 现有模式（Protocol-First 容器、struct Model/Theme、enum Geometry 纯函数、final class Renderer）。新增 `CartesianRendererBase` 模板方法基类（编排 plot 布局→网格→轴→`drawSeries`），`LineChartRenderer` 只实现"把 series 画成折线"。映射统一经过 `CartesianViewport`（阶段 0 固定值域，阶段 4 手势接管）。

**Tech Stack:** Swift / UIKit + QuartzCore（CALayer）/ SwiftUI 仅 demo 与 Representable。无 test target——断言写入 `ChartSelfTest`（DEBUG，App 启动跑），红绿节奏 = 断言先行 → build 编译红 → 实现 → build 绿；运行时断言验证集中在 Task 10。

**规格：** `docs/superpowers/specs/2026-08-26-chart-parity-roadmap-design.md`（§6 组件设计、§8 API/数据流、§8.3 属性面板）

**工程约束（执行前必读）：**
- 工程为文件系统同步组：**新文件放入目录即自动编译**，不改 pbxproj。
- 验证构建命令（在仓库根执行，预期输出 `** BUILD SUCCEEDED **`）：
  ```bash
  xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
    -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3
  ```
- commit 风格沿用项目惯例（`feat(charts): 中文摘要`），结尾加 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`。
- 阶段 0 的 x 轴只支持 `.category`（空数组 = 自动数字标签 1...n）；`.value` 为阶段 5 散点图预留，本期按类目处理并在代码注释标明。

**目录落位（本计划全部新增文件）：**

```
SwiftFunctionProject/Charts/
├── Cartesian/
│   ├── CartesianChartModel.swift        # Task 1（含 SeriesElement / AxisModel / ChartModel）
│   ├── CartesianViewport.swift          # Task 2
│   ├── NiceScaleGenerator.swift         # Task 3
│   ├── CartesianGeometry.swift          # Task 4
│   ├── CartesianChartTheme.swift        # Task 5
│   ├── GridRenderer.swift               # Task 6
│   ├── AxisRenderer.swift               # Task 6
│   └── CartesianRendererBase.swift      # Task 7
├── Line/
│   └── LineChartRenderer.swift          # Task 8
├── SwiftUI/
│   ├── ChartDemoPanel.swift             # Task 9（demo 专用，不属 SDK API 承诺）
│   ├── LineChart.swift                  # Task 10（最小 Representable，demo 配套）
│   └── LineChartDemo.swift              # Task 10
├── Core/HYMChartError.swift             # Task 1 修改（扩展枚举）
├── Debug/ChartSelfTest.swift            # Task 1-4、8 修改（追加断言）
└── ContentView.swift                    # Task 10 修改（demo 入口）
```

---

### Task 1: Cartesian 数据模型 + HYMChartError 扩展

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift`
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartError.swift`（追加 case）
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`（追加断言）

- [ ] **Step 1: 在 ChartSelfTest.runAll() 末尾（`print("✅ ChartSelfTest passed")` 之前）追加断言**

```swift
        // —— Cartesian 数据模型 ——
        let cartModel = CartesianChartModel(
            title: "t",
            series: [CartesianSeriesElement(name: "a", data: [3.0, 97.0]),
                     CartesianSeriesElement(name: "b", data: [-5.0])])
        assert(cartModel.maxPointCount == 2, "maxPointCount should be 2, got \(cartModel.maxPointCount)")
        let db = cartModel.dataBounds!
        assert(abs(db.min - (-5.0)) < 0.001 && abs(db.max - 97.0) < 0.001,
               "dataBounds should be (-5, 97), got \(String(describing: db))")
        // 空 series → nil
        assert(CartesianChartModel(series: []).dataBounds == nil, "empty series should have nil bounds")
        // 类目标签：显式优先，空 → 自动数字 1...n
        assert(CartesianChartModel(series: []).categoryLabels == [],
               "empty categories should be []")
        assert(CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: [1, 2, 3])],
                                   xAxis: CartesianAxisModel(kind: .category(["x", "y", "z"])))
               .categoryLabels == ["x", "y", "z"],
               "explicit category labels should win")
        assert(CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: [1, 2])])
               .categoryLabels == ["1", "2"],
               "auto labels should be 1...n")
```

- [ ] **Step 2: build 验证编译红（符号未定义）**

Run: `xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: FAIL —— `cannot find 'CartesianChartModel' in scope`

- [ ] **Step 3: 创建 `CartesianChartModel.swift`（完整实现）**

```swift
import Foundation
import CoreGraphics
import UIKit

/// 轴类型。阶段 0 仅实现 `.category` 的渲染；`.value` 为阶段 5 散点图预留。
public enum CartesianAxisKind {
    /// 类目轴。`labels` 为空时自动生成数字标签 "1"..."n"（n = 最长 series 点数）。
    case category(labels: [String])
    /// 数值轴（阶段 5 实现 x 向数值映射；阶段 0 按类目处理）。
    case value
}

/// 轴配置（x/y 通用）。
public struct CartesianAxisModel {
    public var kind: CartesianAxisKind
    /// 显式值域下界；nil = 自动（y 轴自动时走 nice scale，x 轴自动按类目数）。
    public var min: Double?
    /// 显式值域上界；nil = 自动。
    public var max: Double?
    /// 显式刻度步长；nil = 自动（nice step）。显式时须与 min/max 同显式，否则忽略。
    public var tickInterval: Double?

    public init(kind: CartesianAxisKind,
                min: Double? = nil, max: Double? = nil, tickInterval: Double? = nil) {
        self.kind = kind
        self.min = min
        self.max = max
        self.tickInterval = tickInterval
    }
}

/// 单个数据系列（阶段 0：等距数值数组，按索引对位类目）。
public struct CartesianSeriesElement {
    public var name: String
    public var data: [Double]
    /// nil → 用主题默认系列色。
    public var color: UIColor?

    public init(name: String, data: [Double], color: UIColor? = nil) {
        self.name = name
        self.data = data
        self.color = color
    }
}

/// 轴系图表数据（折线/柱状等共用）。
public struct CartesianChartModel: HYMChartModel {
    public var title: String?
    public var series: [CartesianSeriesElement]
    public var xAxis: CartesianAxisModel
    public var yAxis: CartesianAxisModel

    public init(title: String? = nil,
                series: [CartesianSeriesElement],
                xAxis: CartesianAxisModel = CartesianAxisModel(kind: .category(labels: [])),
                yAxis: CartesianAxisModel = CartesianAxisModel(kind: .value)) {
        self.title = title
        self.series = series
        self.xAxis = xAxis
        self.yAxis = yAxis
    }

    /// 最长 series 的点数（类目数）。
    public var maxPointCount: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    /// 所有 series 数据的全局 (min, max)；任一有效数据都没有时为 nil。
    public var dataBounds: (min: Double, max: Double)? {
        let flat = series.flatMap { $0.data }
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }

    /// 实际生效的类目标签：显式非空优先；否则自动 "1"..."n"。
    public var categoryLabels: [String] {
        if case .category(let labels) = xAxis.kind, !labels.isEmpty {
            return Array(labels.prefix(maxPointCount))
        }
        return (1...maxPointCount).map { String($0) }
    }
}
```

注意：`CartesianSeriesElement.color` 用到 `UIColor`，文件头三个 import 缺一不可。

- [ ] **Step 4: 修改 `HYMChartError.swift`，在 `invalidTheme` case 后追加**

```swift
    /// 轴系图表：series 为空或全部无数据
    case emptySeries
    /// 轴系图表：值域非法（NaN / max ≤ min）
    case invalidDomain(String)
```

（沿用文件头注释的定位：防御式兜底为主，本枚举供未来 throws 校验 API 使用。）

- [ ] **Step 5: build 验证绿**

Run: 同 Step 2 命令。Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift \
        SwiftFunctionProject/Charts/Core/HYMChartError.swift \
        SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): Cartesian 数据模型（SeriesElement/AxisModel/ChartModel）+ 错误枚举扩展

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: CartesianViewport（阶段 0 固定值域形态）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/CartesianViewport.swift`
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 追加断言（`print("✅ ChartSelfTest passed")` 之前，下同）**

```swift
        // —— CartesianViewport ——
        let vp = CartesianViewport(xMin: -0.5, xMax: 3.5, yMin: 0, yMax: 100)
        assert(vp.xDomain == -0.5...3.5 && vp.yDomain == 0...100, "domains wrong")
        assert(abs(vp.xSpan - 4) < 0.001 && abs(vp.ySpan - 100) < 0.001, "spans wrong")
        assert(vp.clamp(x: 5) == 3.5 && vp.clamp(x: -9) == -0.5, "x clamp wrong")
        assert(vp.clamp(y: -3) == 0 && vp.clamp(y: 120) == 100, "y clamp wrong")
        // 退化域（span=0）不崩溃：clamp 直接返回界值
        let vp0 = CartesianViewport(xMin: 1, xMax: 1, yMin: 0, yMax: 0)
        assert(vp0.clamp(x: 99) == 1 && vp0.clamp(y: -5) == 0, "degenerate clamp wrong")
```

- [ ] **Step 2: build 验证编译红**

Expected: FAIL —— `cannot find 'CartesianViewport' in scope`

- [ ] **Step 3: 创建 `CartesianViewport.swift`**

```swift
import Foundation

/// 轴系图表可见窗口（值域坐标）。
///
/// 这是缩放（阶段 4）、平移（阶段 4）、流式追加（阶段 4）的共同底座：
/// 手势改 viewport，`CartesianGeometry` 读 viewport 做值↔屏幕映射。
/// 阶段 0 为固定值域形态——由 Renderer 从 model 一次算出，无手势交互。
public struct CartesianViewport: Equatable {
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double
    public var yMax: Double

    public init(xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.xMin = min(xMin, xMax)
        self.xMax = max(xMin, xMax)
        self.yMin = min(yMin, yMax)
        self.yMax = max(yMin, yMax)
    }

    public var xDomain: ClosedRange<Double> { xMin...xMax }
    public var yDomain: ClosedRange<Double> { yMin...yMax }
    public var xSpan: Double { xMax - xMin }
    public var ySpan: Double { yMax - yMin }

    /// 值裁剪到 x 域（退化域直接返回界值，避免除零路径）。
    public func clamp(x: Double) -> Double { min(max(x, xMin), xMax) }
    /// 值裁剪到 y 域。
    public func clamp(y: Double) -> Double { min(max(y, yMin), yMax) }
}
```

- [ ] **Step 4: build 验证绿** → Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/CartesianViewport.swift \
        SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): CartesianViewport 可见窗口（阶段 0 固定值域形态）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: NiceScaleGenerator（nice numbers 刻度算法）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/NiceScaleGenerator.swift`
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 追加断言**

```swift
        // —— NiceScaleGenerator（Heckbert nice numbers，maxTickCount=6）——
        // A: 全正 (3,97) → 含 0 下界 → 0...100 步长 20
        let nsA = NiceScaleGenerator.generate(dataMin: 3, dataMax: 97)
        assert(abs(nsA.min) < 0.001 && abs(nsA.max - 100) < 0.001 && abs(nsA.step - 20) < 0.001,
               "case A should be 0...100 step 20, got \(nsA)")
        assert(nsA.ticks.first! == 0 && nsA.ticks.last! == 100, "case A ticks ends wrong")
        assert(nsA.ticks.count == 6, "case A should have 6 ticks, got \(nsA.ticks.count)")
        // B: 含负 (-37,25) → -40...30 步长 10
        let nsB = NiceScaleGenerator.generate(dataMin: -37, dataMax: 25)
        assert(abs(nsB.min - (-40)) < 0.001 && abs(nsB.max - 30) < 0.001 && abs(nsB.step - 10) < 0.001,
               "case B should be -40...30 step 10, got \(nsB)")
        // C: 平线 (50,50) → 全正 → 0...50 步长 10（顶格，Highcharts 同类行为）
        let nsC = NiceScaleGenerator.generate(dataMin: 50, dataMax: 50)
        assert(abs(nsC.min) < 0.001 && abs(nsC.max - 50) < 0.001 && abs(nsC.step - 10) < 0.001,
               "case C should be 0...50 step 10, got \(nsC)")
        // D: 全零 (0,0) → 0...1 步长 0.2
        let nsD = NiceScaleGenerator.generate(dataMin: 0, dataMax: 0)
        assert(abs(nsD.min) < 0.001 && abs(nsD.max - 1) < 0.001 && abs(nsD.step - 0.2) < 0.001,
               "case D should be 0...1 step 0.2, got \(nsD)")
        // E: NaN 防御 → 0...1
        let nsE = NiceScaleGenerator.generate(dataMin: .nan, dataMax: .nan)
        assert(abs(nsE.min) < 0.001 && abs(nsE.max - 1) < 0.001, "NaN should fall back 0...1")
```

- [ ] **Step 2: build 验证编译红**

Expected: FAIL —— `cannot find 'NiceScaleGenerator' in scope`

- [ ] **Step 3: 创建 `NiceScaleGenerator.swift`**

```swift
import Foundation

/// nice numbers 刻度生成（Heckbert 算法）：从数据原始值域生成美化轴值域与刻度，
/// 避免轴上出现 3.7142 这类刻度。纯函数，DEBUG 自检覆盖。
public enum NiceScaleGenerator {

    /// 生成结果：美化后的值域 + 步长 + 刻度序列（min 起、max 止，含两端）。
    public struct Scale: Equatable {
        public var min: Double
        public var max: Double
        public var step: Double
        public var ticks: [Double]
    }

    /// 生成美化刻度。
    ///
    /// 规则：
    /// - 数据全非负（min ≥ 0）时下界从 0 起算（柱状图语义直觉）。
    /// - 平线（min == max）：值为 0 → 0...1；否则上界保持数据值（顶格）。
    /// - NaN 输入 → 0...1 兜底。
    /// - maxTickCount 为目标刻度上限（近似，实际可能 ±2）。
    public static func generate(dataMin: Double, dataMax: Double,
                                maxTickCount: Int = 6) -> Scale {
        guard dataMin.isFinite, dataMax.isFinite else {
            return Scale(min: 0, max: 1, step: 1, ticks: [0, 1])
        }
        var lo = dataMin, hi = dataMax
        if lo > hi { swap(&lo, &hi) }
        if lo >= 0 { lo = 0 }                       // 全非负：含 0 下界
        if hi <= lo { hi = lo + (lo == 0 ? 1 : 0) }  // 平线 0 → 0...1
        let range = niceNum(hi - lo)
        let step = niceNum(range / Double(max(maxTickCount, 2)))
        let niceMin = (lo / step).rounded(.down) * step
        let niceMax = (hi / step).rounded(.up) * step
        // 刻度：整数步进避免浮点累积误差
        let count = Int(((niceMax - niceMin) / step).rounded())
        let ticks = (0...max(count, 0)).map { niceMin + Double($0) * step }
        return Scale(min: niceMin, max: niceMax, step: step, ticks: ticks)
    }

    /// 把任意正数舍入到 1 / 2 / 5 × 10ⁿ 形态（Heckbert nice number）。
    static func niceNum(_ range: Double) -> Double {
        guard range.isFinite, range > 0 else { return 1 }
        let exponent = floor(log10(range))
        let fraction = range / pow(10, exponent)
        let niceFraction: Double
        switch fraction {
        case ..<1.5: niceFraction = 1
        case ..<3:   niceFraction = 2
        case ..<7:   niceFraction = 5
        default:     niceFraction = 10
        }
        return niceFraction * pow(10, exponent)
    }
}
```

- [ ] **Step 4: build 验证绿** → Expected: `** BUILD SUCCEEDED **`
  （若 `nsA.ticks` 断言在运行期失败，属刻度数值手算偏差——用断言输出修正断言值，不改算法语义。）

- [ ] **Step 5: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/NiceScaleGenerator.swift \
        SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): NiceScaleGenerator nice numbers 刻度算法

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: CartesianGeometry（plot 布局 + 值↔屏幕映射）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/CartesianGeometry.swift`
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 追加断言**

```swift
        // —— CartesianGeometry ——
        // 布局：inset(上16,左12,下24,右12) + y刻度宽34 + x刻度高14 + gap4 + 标题高20
        let plot = CartesianGeometry.layout(
            bounds: CGRect(x: 0, y: 0, width: 320, height: 200),
            contentInset: UIEdgeInsets(top: 16, left: 12, bottom: 24, right: 12),
            yAxisTickLabelWidth: 34, xAxisTickLabelHeight: 14,
            axisLabelGap: 4, titleHeight: 20)
        // plot = x: 12+34+4=50, y: 16+20+4=40, w: 320-50-12=258, h: 200-40-24-14-4=118
        assert(abs(plot.minX - 50) < 0.001 && abs(plot.minY - 40) < 0.001, "plot origin wrong: \(plot)")
        assert(abs(plot.width - 258) < 0.001 && abs(plot.height - 118) < 0.001, "plot size wrong: \(plot)")
        // 值→屏幕：类目域 -0.5...3.5、值域 0...100
        let vpG = CartesianViewport(xMin: -0.5, xMax: 3.5, yMin: 0, yMax: 100)
        let p0 = CartesianGeometry.point(x: 0, y: 50, viewport: vpG, plotFrame: plot)
        assert(abs(p0.x - 82.25) < 0.001, "point x should be 82.25, got \(p0.x)")
        assert(abs(p0.y - 99.0) < 0.001, "point y should be 99, got \(p0.y)")
        // 逆映射 roundtrip
        let back = CartesianGeometry.value(at: p0, viewport: vpG, plotFrame: plot)
        assert(abs(back.x - 0) < 0.001 && abs(back.y - 50) < 0.001, "roundtrip wrong: \(back)")
        // 类目 label 抽样
        assert(CartesianGeometry.categoryLabelStride(count: 8) == 1, "8 cats stride 1")
        assert(CartesianGeometry.categoryLabelStride(count: 30) == 3, "30 cats stride 3")
```

- [ ] **Step 2: build 验证编译红**

Expected: FAIL —— `cannot find 'CartesianGeometry' in scope`

- [ ] **Step 3: 创建 `CartesianGeometry.swift`**

```swift
import CoreGraphics
import UIKit

/// 轴系图表几何纯函数（plot 布局、值↔屏幕映射；DEBUG 自检覆盖）。
public enum CartesianGeometry {

    /// 计算 plot 区（网格 + series 绘制区）frame。
    ///
    /// 布局模型：内容 inset → 顶部让出标题 → 左侧让出 y 刻度 label → 底部让出 x 刻度 label。
    /// `yAxisTickLabelWidth` / `xAxisTickLabelHeight` 由调用方按最宽/最高刻度文本量好传入。
    public static func layout(bounds: CGRect,
                              contentInset: UIEdgeInsets,
                              yAxisTickLabelWidth: CGFloat,
                              xAxisTickLabelHeight: CGFloat,
                              axisLabelGap: CGFloat,
                              titleHeight: CGFloat) -> CGRect {
        let x = bounds.minX + contentInset.left + yAxisTickLabelWidth + axisLabelGap
        let y = bounds.minY + contentInset.top + titleHeight + axisLabelGap
        let w = max(0, bounds.width - contentInset.left - contentInset.right
                        - yAxisTickLabelWidth - axisLabelGap)
        let h = max(0, bounds.height - contentInset.top - contentInset.bottom
                        - titleHeight - axisLabelGap - xAxisTickLabelHeight - axisLabelGap)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 值 → 屏幕（view 坐标系）。x/y 均为线性映射；y 轴屏幕向下，故值越大 y 越小。
    /// 类目模式下数据点 x 取索引值（域 -0.5...n-0.5 时点落在 band 中心）。
    public static func point(x: Double, y: Double,
                             viewport: CartesianViewport,
                             plotFrame: CGRect) -> CGPoint {
        let tx = (x - viewport.xMin) / max(viewport.xSpan, 1e-9)
        let ty = (y - viewport.yMin) / max(viewport.ySpan, 1e-9)
        return CGPoint(x: plotFrame.minX + tx * plotFrame.width,
                       y: plotFrame.maxY - ty * plotFrame.height)
    }

    /// 屏幕 → 值（`point` 的逆映射）。
    public static func value(at point: CGPoint,
                             viewport: CartesianViewport,
                             plotFrame: CGRect) -> (x: Double, y: Double) {
        let tx = (point.x - plotFrame.minX) / max(plotFrame.width, 1e-9)
        let ty = (plotFrame.maxY - point.y) / max(plotFrame.height, 1e-9)
        return (viewport.xMin + tx * viewport.xSpan,
                viewport.yMin + ty * viewport.ySpan)
    }

    /// 类目 label 抽样步长：类目数超过 `maxLabels`（默认 10）时隔 N 取 1 显示。
    public static func categoryLabelStride(count: Int, maxLabels: Int = 10) -> Int {
        guard count > maxLabels, maxLabels > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(maxLabels)))
    }
}
```

- [ ] **Step 4: build 验证绿** → Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/CartesianGeometry.swift \
        SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): CartesianGeometry plot 布局与值↔屏幕映射

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: CartesianChartTheme

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/CartesianChartTheme.swift`

（纯外观 struct，无可断言逻辑，无 SelfTest 步骤——视觉验收在 Task 10 demo。）

- [ ] **Step 1: 创建 `CartesianChartTheme.swift`**

```swift
import UIKit

/// 轴系图表主题（纯值类型；所有外观集中于此）。折线/柱状等共用，
/// 各类型特有外观（如柱宽）由该类型 Theme 扩展属性补充——阶段 1 起按需拆分。
public struct CartesianChartTheme: HYMChartTheme {
    // —— 整体 ——
    /// 背景（nil 透明）。
    public var backgroundColor: UIColor?
    public var backgroundCornerRadius: CGFloat
    public var contentInset: UIEdgeInsets
    /// 标题颜色/字体（model.title 非 nil 时渲染）。
    public var titleColor: UIColor
    public var titleFont: UIFont

    // —— 网格 ——
    public var showsHorizontalGridlines: Bool
    public var showsVerticalGridlines: Bool
    public var gridColor: UIColor
    public var gridLineWidth: CGFloat

    // —— 轴 ——
    public var axisLineColor: UIColor
    public var axisLineWidth: CGFloat
    public var tickLabelColor: UIColor
    public var tickLabelFont: UIFont
    /// 刻度 label 与 plot 边缘间距。
    public var axisLabelGap: CGFloat

    // —— 系列（折线阶段 0 直接消费；多系列配色阶段 3 引入调色板）——
    /// series 未指定颜色时的默认色。
    public var seriesColor: UIColor
    public var lineWidth: CGFloat
    /// 是否绘制数据点圆点。
    public var showsPoints: Bool
    public var pointRadius: CGFloat
    public var pointColor: UIColor?

    // —— 行为 ——
    public var showsEntranceAnimation: Bool
    public var showsTooltipOnHit: Bool

    public init(
        backgroundColor: UIColor? = nil,
        backgroundCornerRadius: CGFloat = 0,
        contentInset: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        titleColor: UIColor = UIColor(red: 0.23, green: 0.25, blue: 0.28, alpha: 1),
        titleFont: UIFont = .systemFont(ofSize: 14, weight: .semibold),
        showsHorizontalGridlines: Bool = true,
        showsVerticalGridlines: Bool = false,
        gridColor: UIColor = UIColor(white: 0.9, alpha: 1),
        gridLineWidth: CGFloat = 0.5,
        axisLineColor: UIColor = UIColor(white: 0.78, alpha: 1),
        axisLineWidth: CGFloat = 1,
        tickLabelColor: UIColor = UIColor(red: 0.35, green: 0.38, blue: 0.4, alpha: 1),
        tickLabelFont: UIFont = .systemFont(ofSize: 10),
        axisLabelGap: CGFloat = 4,
        seriesColor: UIColor = UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1),
        lineWidth: CGFloat = 2,
        showsPoints: Bool = true,
        pointRadius: CGFloat = 3,
        pointColor: UIColor? = nil,
        showsEntranceAnimation: Bool = true,
        showsTooltipOnHit: Bool = true
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = backgroundCornerRadius
        self.contentInset = contentInset
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.showsHorizontalGridlines = showsHorizontalGridlines
        self.showsVerticalGridlines = showsVerticalGridlines
        self.gridColor = gridColor
        self.gridLineWidth = gridLineWidth
        self.axisLineColor = axisLineColor
        self.axisLineWidth = axisLineWidth
        self.tickLabelColor = tickLabelColor
        self.tickLabelFont = tickLabelFont
        self.axisLabelGap = axisLabelGap
        self.seriesColor = seriesColor
        self.lineWidth = lineWidth
        self.showsPoints = showsPoints
        self.pointRadius = pointRadius
        self.pointColor = pointColor
        self.showsEntranceAnimation = showsEntranceAnimation
        self.showsTooltipOnHit = showsTooltipOnHit
    }
}
```

- [ ] **Step 2: build 验证绿** → Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/CartesianChartTheme.swift
git commit -m "feat(charts): CartesianChartTheme 轴系图表主题

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: GridRenderer + AxisRenderer（CALayer 产出组件）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/GridRenderer.swift`
- Create: `SwiftFunctionProject/Charts/Cartesian/AxisRenderer.swift`

（产出函数，无状态；视觉验收在 Task 10。）

- [ ] **Step 1: 创建 `GridRenderer.swift`**

```swift
import UIKit

/// 网格线组件：按刻度生成横/竖网格 CAShapeLayer（由 CartesianRendererBase 编排挂载）。
enum GridRenderer {

    /// 生成网格层。横线 = 每个 y 刻度一条；竖线 = 每个类目中心一条。
    /// - Parameters:
    ///   - yTicks: y 轴刻度值序列
    ///   - categoryCount: 类目数（竖线位置 = 各类目中心 x 值 0...n-1）
    static func makeGridLayer(yTicks: [Double],
                              categoryCount: Int,
                              viewport: CartesianViewport,
                              plotFrame: CGRect,
                              theme: CartesianChartTheme) -> CALayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        layer.frame = plotFrame
        if theme.showsHorizontalGridlines {
            for tick in yTicks {
                let y = CartesianGeometry.point(x: 0, y: tick,
                                                viewport: viewport, plotFrame: plotFrame).y
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
        }
        if theme.showsVerticalGridlines {
            for c in 0..<max(categoryCount, 0) {
                let x = CartesianGeometry.point(x: Double(c), y: 0,
                                                viewport: viewport, plotFrame: plotFrame).x
                path.move(to: CGPoint(x: x, y: plotFrame.minY))
                path.addLine(to: CGPoint(x: x, y: plotFrame.maxY))
            }
        }
        layer.path = path.cgPath
        layer.strokeColor = theme.gridColor.cgColor
        layer.fillColor = nil
        layer.lineWidth = theme.gridLineWidth
        return layer
    }
}
```

- [ ] **Step 2: 创建 `AxisRenderer.swift`**

```swift
import UIKit

/// 轴组件：轴线 + 刻度 label（由 CartesianRendererBase 编排挂载）。
enum AxisRenderer {

    /// 生成轴线层：plot 区左边线（y 轴）+ 底边线（x 轴）。
    static func makeAxisLinesLayer(plotFrame: CGRect,
                                   theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: plotFrame.minX, y: plotFrame.minY))
        path.addLine(to: CGPoint(x: plotFrame.minX, y: plotFrame.maxY))
        path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))
        layer.path = path.cgPath
        layer.strokeColor = theme.axisLineColor.cgColor
        layer.fillColor = nil
        layer.lineWidth = theme.axisLineWidth
        return layer
    }

    /// 生成 y 轴刻度 labels（右侧对齐、贴 plot 左缘外侧）。
    /// 返回未加 superview 的 UILabel 数组，调用方负责挂载与清理。
    static func makeYTickLabels(ticks: [Double],
                                viewport: CartesianViewport,
                                plotFrame: CGRect,
                                theme: CartesianChartTheme) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = format(tick)
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let y = CartesianGeometry.point(x: 0, y: tick,
                                            viewport: viewport, plotFrame: plotFrame).y
            lbl.center = CGPoint(x: plotFrame.minX - theme.axisLabelGap - lbl.bounds.width / 2,
                                 y: y)
            return lbl
        }
    }

    /// 生成 x 轴类目 labels（居中于类目中心、贴 plot 底缘外侧；超 10 个类目隔 N 显示）。
    static func makeCategoryLabels(labels: [String],
                                   viewport: CartesianViewport,
                                   plotFrame: CGRect,
                                   theme: CartesianChartTheme) -> [UILabel] {
        let stride = CartesianGeometry.categoryLabelStride(count: labels.count)
        var out: [UILabel] = []
        for (i, text) in labels.enumerated() where i % stride == 0 {
            let lbl = UILabel()
            lbl.text = text
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let x = CartesianGeometry.point(x: Double(i), y: 0,
                                            viewport: viewport, plotFrame: plotFrame).x
            lbl.center = CGPoint(x: x,
                                 y: plotFrame.maxY + theme.axisLabelGap + lbl.bounds.height / 2)
            out.append(lbl)
        }
        return out
    }

    /// 刻度文本：去尾零（80.0 → "80"；0.2 → "0.2"；-0.0 → "0"）。
    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.2g", value)
    }
}
```

- [ ] **Step 3: build 验证绿** → Expected: `** BUILD SUCCEEDED **`
  （注意：`GridRenderer`/`AxisRenderer` 为 internal，尚未被引用，可能出现 unused 警告——可忽略，Task 7 即消费。）

- [ ] **Step 4: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/GridRenderer.swift \
        SwiftFunctionProject/Charts/Cartesian/AxisRenderer.swift
git commit -m "feat(charts): GridRenderer/AxisRenderer 网格与轴组件

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: CartesianRendererBase（模板方法渲染基类）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift`

**这是本阶段架构核心**：实现 `HYMChartRenderer` 全契约，编排统一渲染流程，子类只 override `drawSeries` / `seriesHitTest` / `updateSeriesAnimation`。

- [ ] **Step 1: 创建 `CartesianRendererBase.swift`**

```swift
import UIKit

/// 轴系图表渲染基类（模板方法）。
///
/// 统一编排：背景 → 值域(nice scale) → viewport → plot 布局 → 网格 → 轴 → 标题
/// → **子类 `drawSeries`**。轴/网格/标题/命中上下文全部由基类负责，
/// 子类（LineChartRenderer 等）只实现"把 series 画进 plot 区"与系列命中。
///
/// 泛型参数 `ChartTheme` 让阶段 1 起各类型可扩展自己的 Theme
/// （如 ColumnChartTheme 在 CartesianChartTheme 基础上加柱宽），阶段 0 直接用 CartesianChartTheme。
open class CartesianRendererBase<ChartTheme: HYMChartTheme>: HYMChartRenderer {
    public typealias Model = CartesianChartModel
    public typealias Theme = ChartTheme

    public init() {}

    // MARK: - layer 子树
    /// 根容器（网格/轴线/series 挂其下；入场动画的 opacity 单元）。
    let rootLayer = CALayer()
    private let backgroundLayer = CALayer()
    private weak var hostView: UIView?
    private var titleLabels: [UILabel] = []
    private var tickLabels: [UILabel] = []

    // MARK: - 渲染期状态（供子类命中/动画读取）
    /// 当前生效的 viewport（render 时重算；阶段 0 为固定全量值域）。
    var currentViewport = CartesianViewport(xMin: 0, xMax: 1, yMin: 0, yMax: 1)
    /// 当前 plot 区（view 坐标系）。
    var currentPlotFrame: CGRect = .zero
    var currentModel: CartesianChartModel?
    var currentTheme: ChartTheme?
    var lastContext: HYMChartRenderContext?
    /// 当前 y 刻度（网格与 y label 同源）。
    var currentYTicks: [Double] = []

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(rootLayer)
    }

    public func unmount(from view: UIView) {
        titleLabels.forEach { $0.removeFromSuperview() }
        tickLabels.forEach { $0.removeFromSuperview() }
        titleLabels.removeAll()
        tickLabels.removeAll()
        rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        [backgroundLayer, rootLayer].forEach { $0.removeFromSuperlayer() }
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] { [rootLayer] }
    /// 入场动画逐帧：转发给子类（折线 strokeEnd 生长等）。
    public func updateEntranceAnimation(progress: Double) {
        updateSeriesAnimation(progress: progress)
    }
    /// 子类逐帧动画钩子（progress 0...1，已 ease）。
    open func updateSeriesAnimation(progress: Double) {}

    // MARK: - render（模板方法；子类不得 override，扩展点在 drawSeries）
    public final func render(model: CartesianChartModel, theme: ChartTheme,
                             context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastContext = context

        // 清空旧内容
        rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        titleLabels.forEach { $0.removeFromSuperview() }; titleLabels.removeAll()
        tickLabels.forEach { $0.removeFromSuperview() }; tickLabels.removeAll()
        rootLayer.frame = context.bounds

        guard let cartTheme = theme as? CartesianChartTheme else { return }

        // 1) 背景
        if let bg = cartTheme.backgroundColor {
            backgroundLayer.isHidden = false
            backgroundLayer.frame = context.bounds
            backgroundLayer.backgroundColor = bg.cgColor
            backgroundLayer.cornerRadius = cartTheme.backgroundCornerRadius
        } else {
            backgroundLayer.isHidden = true
        }

        // 2) viewport（y：显式或 nice；x：类目 -0.5...n-0.5）
        currentViewport = makeViewport(model: model)

        // 3) 布局（需要 y 刻度最宽文本宽度）
        currentYTicks = currentViewport.yMin == currentViewport.yMax
            ? [] : makeYTicks(model: model, domain: currentViewport.yDomain)
        let yTickWidth = currentYTicks.map { textSize(AxisRenderer.format($0), font: cartTheme.tickLabelFont).width }.max() ?? 0
        let xTickHeight = textSize("0", font: cartTheme.tickLabelFont).height
        let titleHeight = model.title == nil ? 0 : textSize(model.title!, font: cartTheme.titleFont).height
        currentPlotFrame = CartesianGeometry.layout(
            bounds: context.bounds,
            contentInset: cartTheme.contentInset,
            yAxisTickLabelWidth: yTickWidth,
            xAxisTickLabelHeight: xTickHeight,
            axisLabelGap: cartTheme.axisLabelGap,
            titleHeight: titleHeight)

        guard model.maxPointCount > 0 else { return }

        // 4) 网格 + 轴 + 标题（挂在 series 之下）
        rootLayer.addSublayer(GridRenderer.makeGridLayer(
            yTicks: currentYTicks, categoryCount: model.maxPointCount,
            viewport: currentViewport, plotFrame: currentPlotFrame, theme: cartTheme))
        rootLayer.addSublayer(AxisRenderer.makeAxisLinesLayer(
            plotFrame: currentPlotFrame, theme: cartTheme))
        addTickLabels(model: model, theme: cartTheme)
        addTitleLabel(model: model, theme: cartTheme)

        // 5) 子类绘制（模板方法扩展点）
        drawSeries(model: model, theme: theme, plotFrame: currentPlotFrame)
    }

    // MARK: - 子类扩展点
    /// 把 series 画进 plot 区（挂 rootLayer 下）。子类必须在此缓存命中几何（如各数据点 frame）。
    open func drawSeries(model: CartesianChartModel, theme: ChartTheme, plotFrame: CGRect) {}

    /// 系列命中测试（view 坐标点）。默认 nil。
    open func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }

    // MARK: - 命中契约（witness 固定在基类，子类实现 seriesHitTest 即可）
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { seriesHitTest(point) }

    // MARK: - 便捷（子类用）
    /// 值 → 屏幕（用当前 viewport/plotFrame）。
    func screenPoint(x: Double, y: Double) -> CGPoint {
        CartesianGeometry.point(x: x, y: y, viewport: currentViewport, plotFrame: currentPlotFrame)
    }

    // MARK: - 私有
    private func makeViewport(model: CartesianChartModel) -> CartesianViewport {
        let count = max(model.maxPointCount, 1)
        // x：类目域 -0.5...n-0.5（点 i 落 band 中心）。显式 min/max 覆盖。
        let xMin = model.xAxis.min ?? -0.5
        let xMax = model.xAxis.max ?? Double(count - 1) + 0.5
        // y：显式 min/max 同显式时直接用；否则 nice scale（显式端单独生效时与自动端合并）
        let bounds = model.dataBounds ?? (min: 0, max: 1)
        let scale = NiceScaleGenerator.generate(
            dataMin: model.yAxis.min ?? bounds.min,
            dataMax: model.yAxis.max ?? bounds.max)
        let yMin = model.yAxis.min ?? scale.min
        let yMax = model.yAxis.max ?? scale.max
        return CartesianViewport(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax)
    }

    /// y 刻度：显式 tickInterval（须显式 min/max）从 min 步进；否则 nice scale ticks。
    /// 结果过滤到生效值域内（显式 0...95 时 nice 化出的 100 不得越界画线）。
    private func makeYTicks(model: CartesianChartModel, domain: ClosedRange<Double>) -> [Double] {
        let ticks: [Double]
        if let interval = model.yAxis.tickInterval,
           let lo = model.yAxis.min, let hi = model.yAxis.max, interval > 0 {
            let count = Int(((hi - lo) / interval).rounded())
            ticks = (0...max(count, 0)).map { lo + Double($0) * interval }
        } else {
            let bounds = model.dataBounds ?? (min: 0, max: 1)
            ticks = NiceScaleGenerator.generate(
                dataMin: model.yAxis.min ?? bounds.min,
                dataMax: model.yAxis.max ?? bounds.max).ticks
        }
        return ticks.filter { $0 >= domain.lowerBound - 1e-9 && $0 <= domain.upperBound + 1e-9 }
    }

    private func addTickLabels(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard let view = hostView else { return }
        tickLabels.append(contentsOf: AxisRenderer.makeYTickLabels(
            ticks: currentYTicks, viewport: currentViewport,
            plotFrame: currentPlotFrame, theme: theme))
        tickLabels.append(contentsOf: AxisRenderer.makeCategoryLabels(
            labels: model.categoryLabels, viewport: currentViewport,
            plotFrame: currentPlotFrame, theme: theme))
        tickLabels.forEach { view.addSubview($0) }
    }

    private func addTitleLabel(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard let view = hostView, let title = model.title else { return }
        let lbl = UILabel()
        lbl.text = title
        lbl.textColor = theme.titleColor
        lbl.font = theme.titleFont
        lbl.sizeToFit()
        lbl.center = CGPoint(x: view.bounds.midX,
                             y: theme.contentInset.top + lbl.bounds.height / 2)
        view.addSubview(lbl)
        titleLabels.append(lbl)
    }

    private func textSize(_ s: String, font: UIFont) -> CGSize {
        (s as NSString).size(withAttributes: [.font: font])
    }
}
```

**设计说明（写给执行者）：**
- `final render` 防子类破坏编排顺序；扩展点只有 `drawSeries` / `seriesHitTest` / `updateSeriesAnimation`。
- `theme as? CartesianChartTheme` 的转换：Task 8 的 `LineChartRenderer: CartesianRendererBase<CartesianChartTheme>` 恒成立；若阶段 1+ 的子类 Theme 需要不同结构，届时把通用外观提升为协议（阶段 3 多系列时统一处理，勿提前抽象）。
- 不继承 NSObject（与现有 Radar/Heatmap Renderer 一致）；协议 `init()` 要求由基类 `public init() {}` 满足，子类自动继承。

- [ ] **Step 2: build 验证绿**

Run: `xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`（基类暂无子类引用，unused 警告可忽略）

- [ ] **Step 3: Commit**

```bash
git add SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift
git commit -m "feat(charts): CartesianRendererBase 模板方法渲染基类

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: LineChartRenderer（首个薄 Renderer）

**Files:**
- Create: `SwiftFunctionProject/Charts/Line/LineChartRenderer.swift`
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 追加断言**

```swift
        // —— LineChartRenderer ——
        let lineRenderer = LineChartRenderer()
        assert(lineRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil, "no render should miss")
        let lineModel = CartesianChartModel(
            title: "折线",
            series: [CartesianSeriesElement(name: "s", data: [10, 60, 30])])
        lineRenderer.render(model: lineModel, theme: CartesianChartTheme(),
                            context: HYMChartRenderContext(
                                bounds: CGRect(x: 0, y: 0, width: 320, height: 200),
                                center: .zero))
        // 用渲染器自身的屏幕映射反推数据点位置做命中（避免手算布局）
        let p1 = lineRenderer.testScreenPoint(series: 0, index: 1)
        if let hit = lineRenderer.hitTest(CGPoint(x: p1.x, y: p1.y)) as? LineHitTarget {
            assert(hit.seriesIndex == 0 && hit.index == 1, "should hit series0 index1, got \(hit)")
            assert(abs(hit.value - 60) < 0.001, "hit value should be 60")
            assert(hit.tooltipText != nil, "tooltipText should exist")
        } else {
            assertionFailure("should hit data point (0,1)")
        }
        // 点附近 ±8pt 命中；远处不命中
        assert(lineRenderer.hitTest(CGPoint(x: p1.x + 8, y: p1.y)) != nil, "±8pt should hit")
        assert(lineRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil, "far corner should miss")
```

- [ ] **Step 2: build 验证编译红**

Expected: FAIL —— `cannot find 'LineChartRenderer' in scope`

- [ ] **Step 3: 创建 `LineChartRenderer.swift`**

```swift
import UIKit

/// 折线图命中目标（点中数据点时产生）。
public struct LineHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let seriesIndex: Int
    /// 命中数据点的值。
    public let value: Double
    public let tooltipText: String?

    public init(seriesIndex: Int, index: Int, value: Double, label: String?) {
        self.seriesIndex = seriesIndex
        self.index = index
        self.value = value
        let name = label ?? "series \(seriesIndex)"
        self.identifier = "\(name):\(index)"
        self.tooltipText = "\(name) · \(AxisRenderer.format(value))"
    }
}

/// 折线图渲染器：CartesianRendererBase 的首个薄 Renderer——
/// 只负责"把 series 画成折线 + 数据点 + 点命中 + strokeEnd 生长动画"。
public final class LineChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    /// 命中检测缓存：各数据点 frame（view 坐标系，正方形=命中半径直径）。
    private var lastPointFrames: [(series: Int, index: Int, frame: CGRect)] = []
    /// 折线层（入场动画 strokeEnd 驱动）。
    private var lineLayers: [CAShapeLayer] = []
    /// 命中半径（pt）。
    private let hitRadius: CGFloat = 10

    // MARK: - drawSeries（模板方法扩展点）
    public override func drawSeries(model: CartesianChartModel,
                                    theme: CartesianChartTheme,
                                    plotFrame: CGRect) {
        lastPointFrames.removeAll()
        lineLayers.removeAll()

        for (s, element) in model.series.enumerated() {
            guard !element.data.isEmpty else { continue }
            let color = element.color ?? theme.seriesColor

            // 折线 path
            let path = UIBezierPath()
            for (i, v) in element.data.enumerated() {
                let p = screenPoint(x: Double(i), y: v)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
                let r = max(hitRadius, theme.pointRadius)   // 命中半径 ≥ 视觉点半径
                lastPointFrames.append((s, i,
                    CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
            }
            let line = CAShapeLayer()
            line.path = path.cgPath
            line.strokeColor = color.cgColor
            line.fillColor = nil
            line.lineWidth = theme.lineWidth
            line.lineJoin = .round
            line.lineCap = .round
            rootLayer.addSublayer(line)
            lineLayers.append(line)

            // 数据点
            if theme.showsPoints {
                for (i, v) in element.data.enumerated() {
                    let p = screenPoint(x: Double(i), y: v)
                    let dot = CALayer()
                    dot.frame = CGRect(x: p.x - theme.pointRadius, y: p.y - theme.pointRadius,
                                       width: theme.pointRadius * 2, height: theme.pointRadius * 2)
                    dot.cornerRadius = theme.pointRadius
                    dot.backgroundColor = (theme.pointColor ?? color).cgColor
                    dot.borderColor = UIColor.white.cgColor
                    dot.borderWidth = 1
                    rootLayer.addSublayer(dot)
                }
            }
        }
    }

    // MARK: - 命中（近者优先；正方形 frame 含点即命中）
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        // 后面的 series 画在上层 → 倒序先查
        for hit in lastPointFrames.reversed() where hit.frame.contains(point) {
            let value = model.series[hit.series].data[hit.index]
            return LineHitTarget(seriesIndex: hit.series, index: hit.index,
                                 value: value,
                                 label: model.series[hit.series].name)
        }
        return nil
    }

    // MARK: - 弹窗锚点（数据点正方形 frame，上下避让）
    public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let t = target as? LineHitTarget,
              currentTheme?.showsTooltipOnHit == true,
              let hit = lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })
        else { return nil }
        return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
    }

    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let t = target as? LineHitTarget,
              let hit = lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })
        else { return nil }
        return hit.frame
    }

    // MARK: - 入场动画：折线 strokeEnd 0→1 生长（点/网格随 rootLayer opacity 淡入）
    public override func updateSeriesAnimation(progress: Double) {
        for line in lineLayers {
            line.strokeEnd = CGFloat(min(max(progress, 0), 1))
        }
    }

    // MARK: - 测试辅助（DEBUG 自检用屏幕映射）
    func testScreenPoint(series: Int, index: Int) -> CGPoint {
        guard let model = currentModel,
              series < model.series.count, index < model.series[series].data.count else {
            return .zero
        }
        return screenPoint(x: Double(index), y: model.series[series].data[index])
    }
}
```

注意：`strokeEnd` 动画要求入场时折线从 0 生长——但容器 `performEntranceAnimation` 只在 `playEntranceAnimation()` 后逐帧调 `updateEntranceAnimation`，首次 render 后 strokeEnd 默认 1。demo（Task 10）调 `playEntranceAnimation()` 即生效；未播动画时折线完整显示，无需额外处理。

- [ ] **Step 4: build 验证绿** → Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SwiftFunctionProject/Charts/Line/LineChartRenderer.swift \
        SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift
git commit -m "feat(charts): LineChartRenderer 折线图薄 Renderer（点命中+strokeEnd 入场动画）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: ChartDemoPanel（demo 专用实时属性面板）

**Files:**
- Create: `SwiftFunctionProject/Charts/SwiftUI/ChartDemoPanel.swift`

（demo 基础设施，**不属 SDK API 承诺**；规格 §8.3。无断言，视觉验收在 Task 10。）

- [ ] **Step 1: 创建 `ChartDemoPanel.swift`**

```swift
import SwiftUI
import UIKit

/// demo 专用实时属性面板（规格 §8.3）：声明式描述属性项，自动生成控件。
/// 变更经 Binding 直改 demo 的 @State，驱动图表 `configure` 重绘——
/// 面板即数据流的压力测试工具。不进入 SDK API 承诺面。
struct ChartDemoPanel: View {
    struct DemoSection: Identifiable {
        let title: String
        let items: [Item]
        var id: String { title }
    }

    enum Item {
        case slider(label: String, value: Binding<Double>,
                   range: ClosedRange<Double>, step: Double = 1)
        case stepper(label: String, value: Binding<Double>, step: Double)
        case toggle(label: String, value: Binding<Bool>)
        case picker(label: String, selection: Binding<String>, options: [String])
        case color(label: String, value: Binding<UIColor>)
        case textField(label: String, value: Binding<String>)
        case button(label: String, action: () -> Void)
    }

    let sections: [DemoSection]

    var body: some View {
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    row(item)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .slider(let label, let value, let range, let step):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                    Spacer()
                    Text("\(value.wrappedValue, specifier: step < 1 ? "%.1f" : "%.0f")")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: value, in: range, step: step)
            }
        case .stepper(let label, let value, let step):
            Stepper("\(label)：\(value.wrappedValue, specifier: "%.0f")",
                    value: value, step: step)
        case .toggle(let label, let value):
            Toggle(label, isOn: value)
        case .picker(let label, let selection, let options):
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0) }
            }
        case .color(let label, let value):
            HStack {
                Text(label)
                Spacer()
                ColorPicker("",
                            selection: Binding(
                                get: { Color(uiColor: value.wrappedValue) },
                                set: { value.wrappedValue = UIColor($0) }),
                            supportsOpacity: false)
            }
        case .textField(let label, let value):
            TextField(label, text: value)
        case .button(let label, let action):
            Button(label, action: action)
        }
    }
}
```

- [ ] **Step 2: build 验证绿** → Expected: `** BUILD SUCCEEDED **`（未引用警告可忽略）

- [ ] **Step 3: Commit**

```bash
git add SwiftFunctionProject/Charts/SwiftUI/ChartDemoPanel.swift
git commit -m "feat(charts): ChartDemoPanel demo 实时属性面板（声明式控件生成）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: LineChart Representable + LineChartDemo + 入口 + 运行验证

**Files:**
- Create: `SwiftFunctionProject/Charts/SwiftUI/LineChart.swift`
- Create: `SwiftFunctionProject/Charts/SwiftUI/LineChartDemo.swift`
- Modify: `SwiftFunctionProject/ContentView.swift`（追加 Section）

- [ ] **Step 1: 创建 `LineChart.swift`（最小 Representable，demo 配套；正式 SDK 封装阶段 10 统一打磨）**

```swift
import SwiftUI

/// 折线图 SwiftUI 封装（demo 配套最小版；完备参数面在路线图阶段 10 统一补齐）。
public struct LineChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((LineHitTarget, HYMChartGesture) -> Void)?

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((LineHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        LineChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit)
    }
}

private struct LineChartRepresentable: UIViewRepresentable {
    let model: CartesianChartModel
    let theme: CartesianChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((LineHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<LineChartRenderer> {
        let chart = HYMChartView<LineChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? LineHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<LineChartRenderer>, context: Context) {
        uiView.configure(model: model, theme: theme)
    }
}
```

- [ ] **Step 2: 创建 `LineChartDemo.swift`（图表 + 实时属性面板；覆盖 Model/Theme 全部可调属性）**

```swift
import SwiftUI

/// 折线图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
/// 面板属性改动即时经 LineChart → configure 重绘。
struct LineChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "月度营收（万元）"
    @State private var pointCount = 8
    @State private var data: [Double] = Self.randomData(count: 8)

    // —— Theme 可调项（覆盖全部可调属性；UIColor 项拆出 @State 便于 ColorPicker 绑定）——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColor = CartesianChartTheme().seriesColor
    @State private var pointColorOn = false
    @State private var pointColor = UIColor.systemRed

    var body: some View {
        VStack(spacing: 0) {
            LineChart(model: currentModel, theme: currentTheme)
                .frame(height: 280)
                .padding(.horizontal)
                .padding(.top, 8)
            Form {
                panel
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("折线图 demo")
        .onChange(of: pointCount) { data = Self.randomData(count: $0) }
    }

    private var currentModel: CartesianChartModel {
        CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: [CartesianSeriesElement(name: "2026", data: data)])
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.seriesColor = seriesColor
        t.pointColor = pointColorOn ? pointColor : nil
        return t
    }

    private var panel: ChartDemoPanel {
        ChartDemoPanel(sections: [
            DemoSection(title: "数据", items: [
                .textField(label: "标题", value: $title),
                .slider(label: "数据点数", value: Binding(
                    get: { Double(pointCount) },
                    set: { pointCount = Int($0) }), range: 2...30, step: 1),
                .button(label: "🎲 随机重生成数据") {
                    data = Self.randomData(count: pointCount)
                },
            ]),
            DemoSection(title: "线条", items: [
                .slider(label: "线宽", value: $theme.lineWidth, range: 0.5...8, step: 0.5),
                .color(label: "系列颜色", value: $seriesColor),
            ]),
            DemoSection(title: "数据点", items: [
                .toggle(label: "显示数据点", value: $theme.showsPoints),
                .slider(label: "点半径", value: $theme.pointRadius, range: 1...10, step: 0.5),
                .toggle(label: "自定义点颜色", value: $pointColorOn),
                .color(label: "点颜色", value: $pointColor),
            ]),
            DemoSection(title: "网格与轴", items: [
                .toggle(label: "横向网格", value: $theme.showsHorizontalGridlines),
                .toggle(label: "纵向网格", value: $theme.showsVerticalGridlines),
                .color(label: "网格颜色", value: $theme.gridColor),
                .color(label: "轴颜色", value: $theme.axisLineColor),
                .color(label: "刻度文字颜色", value: $theme.tickLabelColor),
            ]),
            DemoSection(title: "整体", items: [
                .toggle(label: "入场动画", value: $theme.showsEntranceAnimation),
                .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
            ]),
        ])
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 10...100).rounded() }
    }
}
```

- [ ] **Step 3: 修改 `ContentView.swift`，在 `Section("热力图")` 之后追加**

```swift
                Section("折线图") {
                    NavigationLink("折线图 demo（实时属性面板）") {
                        LineChartDemo()
                    }
                }
```

- [ ] **Step 4: build 验证绿**

Run: `xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 运行 App 做运行期验证（ChartSelfTest 断言 + demo 视觉验收）**

1. Xcode 打开工程，选 iPhone 模拟器，Run（⌘R）。
2. 控制台必须出现 `✅ ChartSelfTest passed`（Task 1-4、8 的全部断言运行期通过；任何 assert 停在这里即红灯——按断言消息修实现或修断言数值，**不得改算法语义**）。
3. 首页进入「折线图 demo（实时属性面板）」：
   - 图表显示：标题、y 轴 nice 刻度（如 0/20/40/…）、类目标签、折线 + 数据点；
   - 入场动画：折线从左向右生长；
   - 点击数据点：tooltip 弹窗（上下避让）；
   - 面板逐项拖动：线宽/颜色/网格开关等**即时生效**；数据点数 slider 改变后图表数据重生成；「🎲 随机重生成数据」按钮生效。
4. 若无法本地运行（纯命令行环境）：`xcrun simctl boot "iPhone 16" && xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 16' build` 后用 `xcrun simctl launch` 启动 bundle id，`xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "ChartSelfTest"'` 抓取输出确认。

- [ ] **Step 6: Commit**

```bash
git add SwiftFunctionProject/Charts/SwiftUI/LineChart.swift \
        SwiftFunctionProject/Charts/SwiftUI/LineChartDemo.swift \
        SwiftFunctionProject/ContentView.swift
git commit -m "feat(charts): 折线图 demo + LineChart Representable + 实时属性面板接入

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: 使用指南文档 + 收尾核对

**Files:**
- Create: `docs/charts-line-guide.md`

- [ ] **Step 1: 写 `docs/charts-line-guide.md`（简版，模式对齐 `docs/charts-popup-guide.md`）**

内容提纲（执行者展开成文）：
1. 折线图 30 秒上手（SwiftUI `LineChart(model:theme:)` + UIKit `HYMChartView<LineChartRenderer>` 两段示例，代码从 Task 10 的 demo 直接摘）。
2. Model 三件（title/series/xAxis/yAxis）说明；y 轴显式 min/max/tickInterval 与自动 nice scale 的优先级规则。
3. Theme 全属性表（从 `CartesianChartTheme` 逐项列出：名称/默认值/作用）。
4. 命中与弹窗：`LineHitTarget` 字段、三层弹窗机制如何套用（引用 `docs/charts-popup-guide.md`）。
5. 阶段 0 边界：x 轴仅类目、无图例/多系列/手势（对应阶段 3/4 计划）。

- [ ] **Step 2: 收尾核对清单**

- [ ] `git status` 干净，全部提交完成（约 10 个 commit）
- [ ] demo 面板覆盖 Model/Theme 全部可调属性（对照 `CartesianChartModel`/`CartesianChartTheme` 逐项打勾）
- [ ] ChartSelfTest 断言覆盖：Cartesian 模型 / Viewport / NiceScale（5 用例）/ Geometry（布局+映射 roundtrip+stride）/ LineChartRenderer（命中）
- [ ] 验收标准（规格 §5）：阶段 1 的柱状图**无需改动 Cartesian 层**即可实现——通读 `CartesianRendererBase` 确认扩展点只有 drawSeries/seriesHitTest/updateSeriesAnimation

- [ ] **Step 3: Commit**

```bash
git add docs/charts-line-guide.md
git commit -m "docs(charts): 折线图使用指南（阶段 0 交付物）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 计划自审记录

- **规格覆盖**：§6 ①模型（Task 1）/②几何含 NiceScale+Geometry（Task 3、4）/③渲染基类+轴网格组件（Task 6、7）/④交互层 viewport（Task 2，阶段 0 形态）—— ✓；§8.1 API 形态（Task 10 demo 代码即示例）—— ✓；§8.3 属性面板（Task 9、10）—— ✓；§9 错误扩展（Task 1）—— ✓；§10 测试策略（各任务断言 + Task 10 运行验证）—— ✓；§11 目录（全部落位）—— ✓。SplineGeometry/LegendRenderer/PanZoomHandler 属阶段 2/3/4，正确不在本计划。
- **占位符扫描**：Task 11 使用指南为提纲式（每点指明素材来源，代码直接摘自 Task 10）；其余任务代码完整无 TBD、无"参考 Task N"式省略。
- **类型一致性**：`CartesianChartModel.maxPointCount/dataBounds/categoryLabels`（Task 1）与 Task 7/8 消费一致；`AxisRenderer.format`（Task 6）被 Task 8 `LineHitTarget` 引用一致；`CartesianRendererBase` 的 `screenPoint/rootLayer/currentModel/currentTheme/currentViewport`（Task 7）被 Task 8 使用一致；`makeYTicks(model:domain:)` 签名与 render 调用一致；`HYMChartRenderContext/HYMChartTooltipAnchor/HYMChartHitTarget` 与现有 Core 签名一致。
- **自审修正**（已就地修入计划）：① Task 7 去掉 NSObject 继承与"执行时修正"矛盾段；② `makeYTicks` 增加值域过滤（显式 0...95 时 nice 刻度 100 不得越界）；③ `xTickHeight` 不再依赖 y 刻度非空（y 域退化时 x 类目标签仍显示）；④ Task 10 demo 合并三种 onChange 写法为唯一干净版；⑤ 删除开头打错的构建命令段。
