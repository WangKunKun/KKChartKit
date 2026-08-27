# 轴系自定义 · 双值轴 · 折线堆叠 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 spec 实现值轴刻度自定义（数量/文本/显式位置）、双值轴（左+右，系列绑定轴）、折线/面积堆叠（分层、每系列独立颜色）。

**Architecture:** 方案 A——`CartesianAxisModel` 加 4 个 Optional 刻度字段；`CartesianChartModel` 加可选 `secondaryYAxis`；`CartesianSeriesElement` 加 `yAxisIndex` 绑定。`viewport.yDomain` 恒表示主轴域（现有路径零改动），次轴域/刻度为 renderer 新增独立状态；几何纯函数（`point`/`columnRect`/`zeroAxisPosition`）加默认为 nil 的 domain 参数保持签名兼容。折线堆叠复用柱状 `StackConfig` + 新增按轴分组的 `stackedValuesByAxis`。

**Tech Stack:** Swift / UIKit（CALayer 渲染）/ SwiftUI demo / XCTest（`ChartSelfTest` DEBUG 断言 + 模拟器运行）

**Spec:** `docs/superpowers/specs/2026-08-27-axis-customization-dual-axis-line-stacking-design.md`

## Global Constraints

- 不设 `secondaryYAxis`、不开 `stacking`、不设新刻度字段时，所有现有图表行为**逐字节不变**；现有 ChartSelfTest 断言一律不修改语义（仅 `dataBounds` 属性→函数的机械迁移）
- 每个 Task 走 TDD：先在 `ChartSelfTest` 加断言 → 跑测试看失败 → 最小实现 → 转绿 → 提交
- 测试运行命令统一：
  `xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SwiftFunctionProjectTests/SwiftFunctionProjectTests/testChartSelfTest`
  （宿主 App 启动也会跑 ChartSelfTest；断言崩溃信息会出现在输出里）
- Bar（水平图）只消费主值轴 + 刻度自定义；`secondaryYAxis` 对 Bar 忽略并 DEBUG 断言
- 提交信息格式沿用仓库惯例：`feat(charts): …` / `test(charts): …`，中文描述
- iOS 部署目标 15.0；不引入新依赖

---

### Task 1: 轴刻度自定义（模型字段 + 刻度生成器 + formatter 接线）

**Files:**
- Create: `SwiftFunctionProject/Charts/Cartesian/ValueTickGenerator.swift`
- Modify: `SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift`（`CartesianAxisModel` 加字段）
- Modify: `SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift`（`makeValueTicks` 换用生成器）
- Modify: `SwiftFunctionProject/Charts/Cartesian/AxisRenderer.swift`（刻度文本 formatter 支持）
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

**Interfaces:**
- Produces:
  - `CartesianAxisModel.tickCount: Int?` / `tickPositions: [Double]?` / `labelFormatter: ((Double) -> String)?` / `showsGridlines: Bool?`（init 带默认值参数，现有调用不变）
  - `enum ValueTickGenerator { static func ticks(axis:domain:dataBounds:generatesFromDomain:) -> [Double] }`
  - `AxisRenderer.tickText(_:formatter:) -> String`；`makeYTickLabels`/`makeBottomValueTickLabels` 加 `formatter: ((Double) -> String)? = nil` 参数

- [ ] **Step 1: 写失败测试（ChartSelfTest 末尾 `runHorizontalAxisSelfTest()` 调用之后、`print("✅…")` 之前追加调用与新方法）**

```swift
        // —— 值轴刻度自定义（tickCount / tickPositions / labelFormatter）——
        runTickCustomizationSelfTest()

        print("✅ ChartSelfTest passed")
    }

    /// 值轴刻度四档优先级：tickPositions > tickInterval > tickCount > 自动；labelFormatter 文本。
    static func runTickCustomizationSelfTest() {
        let dom = 0.0...100.0
        let bounds = (min: 0.0, max: 100.0)

        // 1) 显式位置最高优先（不规则刻度 0/25/60/100 原样返回，域内过滤）
        let posAxis = CartesianAxisModel(kind: .value, tickPositions: [0, 25, 60, 100])
        assert(ValueTickGenerator.ticks(axis: posAxis, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 25, 60, 100],
               "tickPositions 应原样生效")
        // 域外刻度被过滤
        let posOut = CartesianAxisModel(kind: .value, tickPositions: [-20, 0, 50, 120])
        assert(ValueTickGenerator.ticks(axis: posOut, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 50],
               "域外 tickPositions 应被过滤")

        // 2) tickInterval 须配显式 min/max（现状规则）：0...100 步长 25
        let intAxis = CartesianAxisModel(kind: .value, min: 0, max: 100, tickInterval: 25)
        assert(ValueTickGenerator.ticks(axis: intAxis, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 25, 50, 75, 100],
               "tickInterval 应按现状规则步进")

        // 3) tickCount 驱动 nice scale：(3,97) + count 3 → 步长 50 → [0,50,100]
        let cntAxis = CartesianAxisModel(kind: .value, tickCount: 3)
        let byCount = ValueTickGenerator.ticks(axis: cntAxis, domain: dom,
                                               dataBounds: (min: 3, max: 97),
                                               generatesFromDomain: false)
        assert(byCount == [0, 50, 100], "tickCount=3 应出 3 条刻度，got \(byCount)")

        // 4) 自动默认 6（现状）：(3,97) → 0...100 步长 20
        let autoAxis = CartesianAxisModel(kind: .value)
        let byAuto = ValueTickGenerator.ticks(axis: autoAxis, domain: dom,
                                              dataBounds: (min: 3, max: 97),
                                              generatesFromDomain: false)
        assert(byAuto == [0, 20, 40, 60, 80, 100], "自动应保持默认 6 档，got \(byAuto)")

        // 5) generatesFromDomain（水平图 X 窗口）：按窗口 50...100 生成并过滤
        let hAxis = CartesianAxisModel(kind: .value)
        let hTicks = ValueTickGenerator.ticks(axis: hAxis, domain: 50...100,
                                              dataBounds: bounds, generatesFromDomain: true)
        assert(hTicks.allSatisfy { $0 >= 50 && $0 <= 100 } && hTicks.last == 100,
               "窗口生成应落在域内且含右缘，got \(hTicks)")

        // 6) 刻度文本：formatter 优先，否则内置格式
        assert(AxisRenderer.tickText(80, formatter: nil) == "80", "默认文本应为去尾零格式")
        assert(AxisRenderer.tickText(80, formatter: { "\($0)%" }) == "80%", "formatter 应生效")

        // 7) 渲染级：labelFormatter 接入左侧刻度（80 → "80%"）
        do {
            let r = ColumnChartRenderer()
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
            r.mount(into: host)
            var y = CartesianAxisModel(kind: .value)
            y.labelFormatter = { "\($0)℃" }
            r.render(model: CartesianChartModel(
                series: [CartesianSeriesElement(name: "s", data: [20, 60])],
                yAxis: y),
                     theme: CartesianChartTheme(),
                     context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
            let texts = host.subviews.compactMap { ($0 as? UILabel)?.text }
            assert(texts.contains("60℃"),
                   "左侧刻度应使用 formatter 文本，got \(texts)")
        }
    }
```

- [ ] **Step 2: 跑测试验证失败**

Run: `xcodebuild test … -only-testing:SwiftFunctionProjectTests/SwiftFunctionProjectTests/testChartSelfTest 2>&1 | grep -E "error|Assertion"`
Expected: 编译错误 `cannot find 'ValueTickGenerator' in scope`（先建桩）或断言失败。若因新类型不存在而编译失败，先建 Task 1 Step 3 的空桩文件再跑，看到运行期断言失败为准。

- [ ] **Step 3: 实现 `ValueTickGenerator`（新文件）**

```swift
import Foundation

/// 值轴刻度生成器（纯函数，DEBUG 自检覆盖）。
///
/// 四档优先级：`tickPositions`（显式值）> `tickInterval`（须配显式 min/max）
/// > `tickCount`（nice scale 目标数量）> 自动（默认 6）。
/// 结果一律过滤到生效值域内（域外刻度不画线）。
enum ValueTickGenerator {

    /// - Parameters:
    ///   - axis: 值轴配置
    ///   - domain: 生效值域（过滤基准）
    ///   - dataBounds: 绑定系列的数据边界（自动档的生成来源；nil 走 0...1 兜底）
    ///   - generatesFromDomain: true 时自动档按 domain 本身生成
    ///     （水平图值轴在 X、随视口窗口变化，刻度跟随窗口）而非数据边界
    static func ticks(axis: CartesianAxisModel,
                      domain: ClosedRange<Double>,
                      dataBounds: (min: Double, max: Double)?,
                      generatesFromDomain: Bool) -> [Double] {
        let lo = domain.lowerBound, hi = domain.upperBound
        let inDomain: (Double) -> Bool = { $0 >= lo - 1e-9 && $0 <= hi + 1e-9 }

        if let positions = axis.tickPositions {
            return positions.filter(inDomain)
        }
        if let interval = axis.tickInterval,
           let minV = axis.min, let maxV = axis.max, interval > 0 {
            let count = Int(((maxV - minV) / interval).rounded())
            return (0...max(count, 0)).map { minV + Double($0) * interval }.filter(inDomain)
        }
        let scale: NiceScaleGenerator.Scale
        if generatesFromDomain {
            scale = NiceScaleGenerator.generate(dataMin: lo, dataMax: hi,
                                                maxTickCount: axis.tickCount ?? 6)
        } else {
            let b = dataBounds ?? (min: 0, max: 1)
            scale = NiceScaleGenerator.generate(dataMin: axis.min ?? b.min,
                                                dataMax: axis.max ?? b.max,
                                                maxTickCount: axis.tickCount ?? 6)
        }
        return scale.ticks.filter(inDomain)
    }
}
```

- [ ] **Step 4: `CartesianAxisModel` 加字段（CartesianChartModel.swift）**

在 `tickInterval` 声明后追加，并给 `init` 加同序默认参数（放在 `tickInterval: Double? = nil` 之后）：

```swift
    /// 目标刻度数量（nice scale 依据；实际 ±1~2。nil = 默认 6）。
    public var tickCount: Int?
    /// 完全显式刻度值（最高优先级；域外值被过滤）。类目轴忽略。
    public var tickPositions: [Double]?
    /// 刻度文本自定义（nil = 内置去尾零格式）。
    public var labelFormatter: ((Double) -> String)?
    /// 该轴是否画网格（nil = 主轴跟随 theme、次轴默认关）。
    public var showsGridlines: Bool?
```

init 追加：`tickCount: Int? = nil, tickPositions: [Double]? = nil, labelFormatter: ((Double) -> String)? = nil, showsGridlines: Bool? = nil` 并赋值。

- [ ] **Step 5: AxisRenderer 刻度文本接线**

`AxisRenderer` 加：

```swift
    /// 刻度文本：formatter 优先，否则内置去尾零格式。
    static func tickText(_ tick: Double, formatter: ((Double) -> String)?) -> String {
        formatter?(tick) ?? format(tick)
    }
```

`makeYTickLabels` 与 `makeBottomValueTickLabels` 签名各加 `formatter: ((Double) -> String)? = nil`，内部 `lbl.text = format(tick)` 改为 `lbl.text = tickText(tick, formatter: formatter)`。

- [ ] **Step 6: 基类 `makeValueTicks` 换用生成器（CartesianRendererBase.swift）**

私有方法 `makeValueTicks(model:)` 整体替换为：

```swift
    private func makeValueTicks(axis: CartesianAxisModel,
                                domain: ClosedRange<Double>,
                                bounds: (min: Double, max: Double)?) -> [Double] {
        ValueTickGenerator.ticks(axis: axis, domain: domain, dataBounds: bounds,
                                 generatesFromDomain: isHorizontalValueAxis)
    }
```

render() 中调用点改为：

```swift
        currentValueTicks = valueDomainDegenerate ? []
            : makeValueTicks(axis: model.yAxis, domain: currentViewport.yDomain,
                             bounds: model.dataBounds(yAxisIndex: 0))
```

（`dataBounds(yAxisIndex:)` 在 Task 2 出现前，先临时用 `model.dataBounds`——若 Task 1、2 由不同执行者完成，本 Task 写 `model.dataBounds`，Task 2 再统一替换为分组版本。）

`addTickLabels` 两处刻度调用加 `formatter: model.yAxis.labelFormatter`。

- [ ] **Step 7: 跑测试验证通过**

Run: 同 Step 2 命令
Expected: `testChartSelfTest passed`（全部旧断言不受影响）

- [ ] **Step 8: 提交**

```bash
git add -A
git commit -m "feat(charts): 值轴刻度自定义（数量/显式位置/文本 formatter）"
```

---

### Task 2: 双轴与堆叠的模型/几何纯函数层

**Files:**
- Modify: `SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift`（`yAxisIndex`、`secondaryYAxis`、`dataBounds(yAxisIndex:)`）
- Modify: `SwiftFunctionProject/Charts/Cartesian/CartesianGeometry.swift`（`stackedValuesByAxis`、`point`/`columnRect`/`zeroAxisPosition` domain 参数）
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

**Interfaces:**
- Consumes: Task 1 的 `CartesianAxisModel` 新字段
- Produces:
  - `CartesianSeriesElement.yAxisIndex: Int`（init 默认 0）与 `effectiveYAxisIndex: Int`（clamp 到 0/1）
  - `CartesianChartModel.secondaryYAxis: CartesianAxisModel?`（init 默认 nil）与 `func dataBounds(yAxisIndex: Int = 0) -> (min: Double, max: Double)?`（**替代原 `var dataBounds`**）
  - `CartesianGeometry.stackedValuesByAxis(series:) -> [[Double]]`（按轴分组链式累计，与输入同序；全 0 轴时与 `stackedValues` 结果一致）
  - `CartesianGeometry.point(x:y:viewport:plotFrame:yDomain: ClosedRange<Double>? = nil)`（nil = viewport.yDomain，现有调用不变）
  - `CartesianGeometry.columnRect(…, valueDomain: ClosedRange<Double>? = nil, …)`
  - `CartesianGeometry.zeroAxisPosition(viewport:plotArea:isHorizontal:valueDomain: ClosedRange<Double>? = nil)`

- [ ] **Step 1: 写失败测试（ChartSelfTest，接在 `runTickCustomizationSelfTest` 之后同样方式追加）**

```swift
        // —— 双轴/堆叠模型与几何纯函数 ——
        runDualAxisGeometrySelfTest()

        print("✅ ChartSelfTest passed")
    }

    /// 双轴分组边界、按轴堆叠、几何函数 domain 参数。
    static func runDualAxisGeometrySelfTest() {
        // 1) yAxisIndex clamp：越界回落 0/1
        let s0 = CartesianSeriesElement(name: "a", data: [1])
        assert(s0.effectiveYAxisIndex == 0, "默认绑主轴")
        assert(CartesianSeriesElement(name: "b", data: [1], yAxisIndex: 1).effectiveYAxisIndex == 1,
               "1 绑次轴")
        assert(CartesianSeriesElement(name: "c", data: [1], yAxisIndex: 7).effectiveYAxisIndex == 0,
               "越界回落主轴")

        // 2) dataBounds(yAxisIndex:) 分组（堆叠按轴分组累计）
        let mA = CartesianSeriesElement(name: "a", data: [10, 40])
        let mB = CartesianSeriesElement(name: "b", data: [20, 30], yAxisIndex: 1)
        let dual = CartesianChartModel(series: [mA, mB], secondaryYAxis: CartesianAxisModel(kind: .value))
        assert(dual.dataBounds(yAxisIndex: 0)!.min == 10 && dual.dataBounds(yAxisIndex: 0)!.max == 40,
               "主轴组边界只含 axis0 系列")
        assert(dual.dataBounds(yAxisIndex: 1)!.min == 20 && dual.dataBounds(yAxisIndex: 1)!.max == 30,
               "次轴组边界只含 axis1 系列")
        assert(CartesianChartModel(series: [mA]).dataBounds(yAxisIndex: 1) == nil,
               "无绑定系列且无显式域 → nil")
        // 单轴堆叠回归：dataBounds(yAxisIndex: 0) 与旧 dataBounds 语义一致
        let stacked2 = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])],
            stacking: .normal)
        let sb = stacked2.dataBounds(yAxisIndex: 0)!
        assert(sb.min == 10 && sb.max == 55, "堆叠边界应为累计值 10...55，got \(sb)")

        // 3) stackedValuesByAxis：跨轴不混叠、组内链式累计、与输入同序
        let r = CartesianGeometry.stackedValuesByAxis(series: [mA, mB, mA])
        assert(r[0] == [10, 40], "系列0（axis0 首个）= 原值")
        assert(r[1] == [20, 30], "系列1（axis1 首个）= 原值，不与 axis0 混叠")
        assert(r[2] == [20, 70], "系列2（axis0 第二个）= 10+10, 40+30")
        // 全 0 轴时与 stackedValues 一致
        let allZero = CartesianGeometry.stackedValuesByAxis(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])])
        assert(allZero == CartesianGeometry.stackedValues(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])]),
               "全主轴时应与 stackedValues 完全一致")

        // 4) point yDomain 参数：同一 y 值在不同域上映到不同高度，nil = 现状
        let vp = CartesianViewport(xMin: -0.5, xMax: 1.5, yMin: 0, yMax: 100)
        let plot = CGRect(x: 0, y: 0, width: 100, height: 100)
        let pMain = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot)
        let pNil = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot, yDomain: nil)
        assert(pMain == pNil, "yDomain nil 应等于现状")
        let pSec = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot,
                                           yDomain: 0...1000)
        assert(abs(pSec.y - 50) < 0.001, "次轴域 0...1000 时 y=50 应在半高，got \(pSec.y)")

        // 5) zeroAxisPosition valueDomain：混合域次轴零轴位置正确
        let zSec = CartesianGeometry.zeroAxisPosition(
            viewport: vp, plotArea: plot, isHorizontal: false, valueDomain: -100...100)
        assert(abs(zSec - 50) < 0.001, "次轴 -100...100 零轴应在半高，got \(zSec)")

        // 6) columnRect valueDomain：次轴系列的柱高按次轴域映射
        let secRect = CartesianGeometry.columnRect(
            dataPoint: 50, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: CartesianChartTheme(), zeroY: 100, valueDomain: 0...1000)
        assert(abs(secRect.maxY - 100) < 0.001 && abs(secRect.height - 5) < 0.001,
               "50/1000 域柱高应为 plot 高的 1/20，got \(secRect)")
    }
```

- [ ] **Step 2: 跑测试验证失败**

Run: 同 Task 1 Step 2 命令
Expected: 编译错误（`effectiveYAxisIndex`/`stackedValuesByAxis`/`yDomain:` 参数不存在）。为获得运行期 RED，可先给新 API 建空桩（返回 `[]`/`.zero`/忽略参数），确认断言失败。断言失败信息应指向第一处缺失行为。

- [ ] **Step 3: 模型层实现（CartesianChartModel.swift）**

`CartesianSeriesElement`：

```swift
    /// 绑定哪个值轴（0 = 主轴/左，1 = 次轴/右；Bar 水平图仅支持主轴）。
    public var yAxisIndex: Int
    /// clamp 后的有效轴索引（越界回落 0/1 段内）。
    public var effectiveYAxisIndex: Int { min(max(yAxisIndex, 0), 1) }
```

init 加 `yAxisIndex: Int = 0` 参数。

`CartesianChartModel`：

```swift
    /// 次值轴（右）。nil = 单轴（现状）。Bar（水平图）暂不支持，传了会被忽略（DEBUG 断言）。
    public var secondaryYAxis: CartesianAxisModel?
```

init 加 `secondaryYAxis: CartesianAxisModel? = nil`。

**删除** `public var dataBounds` 属性，替换为：

```swift
    /// 指定值轴的绑定系列全局 (min, max)；堆叠模式下按轴分组累计后取边界。
    /// 任一有效数据都没有时为 nil。轴无绑定系列时：显式 min/max 由渲染层兜底，此处返回 nil。
    public func dataBounds(yAxisIndex: Int = 0) -> (min: Double, max: Double)? {
        let group = series.filter { $0.effectiveYAxisIndex == yAxisIndex }
        guard !group.isEmpty else { return nil }
        let dataToUse: [[Double]]
        if stacking == .normal {
            dataToUse = CartesianGeometry.stackedValuesByAxis(series: group)
        } else {
            dataToUse = group.map { $0.data }
        }
        let flat = dataToUse.flatMap { $0 }
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }
```

同文件内迁移调用点：无（`categoryLabels` 不用它）。

- [ ] **Step 4: 迁移 dataBounds 调用点（基类 + 自检）**

`CartesianRendererBase.swift`：`makeViewport` 与 `makeValueTicks` 调用处（Task 1 Step 6 的临时 `model.dataBounds`）改为 `model.dataBounds(yAxisIndex: 0)`。
`ChartSelfTest.swift`：`cartModel.dataBounds!`（约 2 处）与 `CartesianChartModel(series: []).dataBounds == nil` 改为 `cartModel.dataBounds()!` / `… .dataBounds() == nil`。

- [ ] **Step 5: 几何层实现（CartesianGeometry.swift）**

`point` 加参数并使用：

```swift
    public static func point(x: Double, y: Double,
                             viewport: CartesianViewport,
                             plotFrame: CGRect,
                             yDomain: ClosedRange<Double>? = nil) -> CGPoint {
        let domain = yDomain ?? viewport.yDomain
        let tx = (x - viewport.xMin) / max(viewport.xSpan, 1e-9)
        let ty = (y - domain.lowerBound) / max(domain.upperBound - domain.lowerBound, 1e-9)
        return CGPoint(x: plotFrame.minX + tx * plotFrame.width,
                       y: plotFrame.maxY - ty * plotFrame.height)
    }
```

（注意：`value(at:)` 逆映射不加参数——命中均用缓存屏幕坐标，不需要按轴逆映射。）

`zeroAxisPosition` 垂直分支改为优先用 `valueDomain`：

```swift
    public static func zeroAxisPosition(
        viewport: CartesianViewport,
        plotArea: CGRect,
        isHorizontal: Bool = false,
        valueDomain: ClosedRange<Double>? = nil
    ) -> CGFloat {
        if isHorizontal {
            // 水平图不变（Bar 无次轴）
            …现有代码…
        } else {
            let d = valueDomain ?? viewport.yDomain
            if d.lowerBound >= 0 { return plotArea.maxY }
            if d.upperBound <= 0 { return plotArea.minY }
            let ratio = -d.lowerBound / (d.upperBound - d.lowerBound)
            return plotArea.maxY - plotArea.height * ratio
        }
    }
```

`columnRect` 加 `valueDomain: ClosedRange<Double>? = nil` 参数（放 `viewport` 之后），内部两处 `point(x:y:viewport:plotFrame:)`（valueY 与 baseline startY 计算）传 `yDomain: valueDomain`。

`stackedValuesByAxis`（新增，放在 `stackedValues` 之后）：

```swift
    /// 按值轴分组的链式累计（双轴堆叠：跨轴不混叠）；返回与输入同序。
    /// 系列 i 的累计 = 自身数据 + 同轴（effectiveYAxisIndex 相同）前一系列的累计；
    /// 短系列补 0 对齐到最长长度。全主轴时与 `stackedValues` 结果完全一致。
    public static func stackedValuesByAxis(series: [CartesianSeriesElement]) -> [[Double]] {
        guard !series.isEmpty else { return [] }
        let maxLength = series.map { $0.data.count }.max() ?? 0
        guard maxLength > 0 else { return [] }
        var running: [Int: [Double]] = [:]
        var out: [[Double]] = []
        for s in series {
            let axis = s.effectiveYAxisIndex
            var cum = running[axis] ?? [Double](repeating: 0, count: maxLength)
            let padded = s.data + [Double](repeating: 0, count: max(0, maxLength - s.data.count))
            cum = zip(cum, padded).map { $0 + $1 }
            running[axis] = cum
            out.append(cum)
        }
        return out
    }
```

- [ ] **Step 6: 跑测试验证通过**

Run: 同 Task 1 Step 2 命令
Expected: `testChartSelfTest passed`

- [ ] **Step 7: 提交**

```bash
git add -A
git commit -m "feat(charts): 双轴/堆叠模型与几何纯函数（yAxisIndex 分组、按轴累计、域参数化映射）"
```

---

### Task 3: 基类双轴渲染编排（次轴域/刻度、右侧布局、右轴标签与轴线）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift`
- Modify: `SwiftFunctionProject/Charts/Cartesian/AxisRenderer.swift`（`makeRightValueTickLabels`、轴线右缘）
- Modify: `SwiftFunctionProject/Charts/Cartesian/GridRenderer.swift`（次轴网格线）
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

**Interfaces:**
- Consumes: Task 1 `ValueTickGenerator`、Task 2 `secondaryYAxis`/`dataBounds(yAxisIndex:)`/`point(yDomain:)`
- Produces:
  - `CartesianRendererBase.currentSecondaryYDomain: ClosedRange<Double>?`、`currentSecondaryValueTicks: [Double]`
  - `CartesianRendererBase.screenPoint(x:y:yAxisIndex: Int = 0) -> CGPoint`
  - `AxisRenderer.makeRightValueTickLabels(ticks:viewport:plotFrame:theme:formatter:) -> [UILabel]`
  - `AxisRenderer.makeAxisLinesLayer(plotFrame:theme:showsRightAxis: Bool = false)`
  - `GridRenderer.makeGridLayer(…, secondaryValueTicks: [Double] = [], secondaryYDomain: ClosedRange<Double>? = nil)`
  - `CartesianGeometry.layout(…, rightAxisLabelWidth: CGFloat = 0)`

- [ ] **Step 1: 写失败测试（ChartSelfTest，同样方式追加）**

```swift
        // —— 双值轴渲染（右侧刻度、独立值域、次轴网格）——
        runDualAxisRenderSelfTest()

        print("✅ ChartSelfTest passed")
    }

    /// 双轴渲染契约：两轴值域独立、右侧让宽并画右侧刻度、次轴网格默认关。
    static func runDualAxisRenderSelfTest() {
        let r = ColumnChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        // 主轴：温度 0...30；次轴：湿度 0...100（显式域，formatter 加 %）
        var sec = CartesianAxisModel(kind: .value, min: 0, max: 100)
        sec.labelFormatter = { "\(Int($0))%" }
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "温度", data: [5, 15, 25]),
                     CartesianSeriesElement(name: "湿度", data: [40, 70, 90], yAxisIndex: 1)],
            secondaryYAxis: sec)
        r.render(model: model, theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame

        // 1) 主轴域只由 axis0 系列决定（5...25 → nice 0...30）
        assert(abs(r.currentViewport.yMin) < 0.001 && abs(r.currentViewport.yMax - 30) < 0.001,
               "主轴域应为 0...30，got \(r.currentViewport.yDomain)")
        // 2) 次轴域独立（显式 0...100）
        assert(r.currentSecondaryYDomain == 0...100,
               "次轴域应为显式 0...100，got \(String(describing: r.currentSecondaryYDomain))")
        assert(!r.currentSecondaryValueTicks.isEmpty, "次轴刻度不应为空")

        // 3) 右侧让宽：plot 右缘远离 view 右缘（右侧刻度列存在）
        assert(host.bounds.maxX - plot.maxX > 20,
               "右侧应为次轴刻度让宽，plot.maxX=\(plot.maxX)")

        // 4) 右侧刻度存在且带 formatter 文本、位于 plot 右侧
        let labels = host.subviews.compactMap { $0 as? UILabel }
        let pct = labels.first { $0.text == "100%" }
        assert(pct != nil, "右侧应有刻度文本 100%，got \(labels.map { $0.text ?? "" })")
        if let p = pct {
            assert(p.center.x > plot.maxX, "右侧刻度应在 plot 右侧，got \(p.center.x)")
        }

        // 5) 单轴回归：secondaryYAxis 为 nil 时次轴状态为空、无右侧让宽
        let single = ColumnChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        single.mount(into: host2)
        single.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "s", data: [5, 15, 25])]),
                      theme: CartesianChartTheme(),
                      context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        assert(single.currentSecondaryYDomain == nil && single.currentSecondaryValueTicks.isEmpty,
               "单轴时次轴状态应为空")
        assert(abs(host2.bounds.maxX - single.currentPlotFrame.maxX)
               - abs(host.bounds.maxX - plot.maxX) < -10,
               "单轴右侧不应为次轴让宽")
        assert(single.currentPlotFrame.maxX > plot.maxX,
               "单轴 plot 应比双轴更靠右（无右轴让宽）")
    }
```

- [ ] **Step 2: 跑测试验证失败**

Run: 同 Task 1 Step 2 命令
Expected: 编译错误（`currentSecondaryYDomain` 不存在）→ 建最小状态桩后运行期断言失败（右侧无让宽/无 100% 标签）。

- [ ] **Step 3: 基类实现（CartesianRendererBase.swift）**

3a. 渲染期状态（`currentValueTicks` 旁）：

```swift
    /// 次值轴（右）生效域；nil = 无次轴（单轴现状）。垂直图专用。
    var currentSecondaryYDomain: ClosedRange<Double>?
    /// 次值轴刻度（网格与右侧 label 同源）。
    var currentSecondaryValueTicks: [Double] = []
```

3b. 值域计算抽helper（`makeViewport` 上方）：

```swift
    /// 由轴配置 + 绑定系列边界算值域（显式 min/max 优先，否则 nice scale）。
    private func makeValueDomain(axis: CartesianAxisModel,
                                 bounds: (min: Double, max: Double)?) -> ClosedRange<Double> {
        let b = bounds ?? (min: 0, max: 1)
        let scale = NiceScaleGenerator.generate(dataMin: axis.min ?? b.min,
                                                dataMax: axis.max ?? b.max)
        let lo = axis.min ?? scale.min
        let hi = axis.max ?? scale.max
        return min(lo, hi)...max(lo, hi)
    }
```

`makeViewport` 中现有 `let scale = …; let valLo/valHi …` 段替换为：

```swift
        let fullValue = makeValueDomain(axis: model.yAxis, bounds: model.dataBounds(yAxisIndex: 0))
```

（语义与原式完全一致：显式端优先、nice 兜底。）

3c. render() 步骤 2.5（`currentViewport = makeViewport(...)` 之后、步骤 3 之前）：

```swift
        // 2.5) 次值轴（仅垂直图；Bar 水平图忽略并提示）
        if let secondary = model.secondaryYAxis {
            if isHorizontalValueAxis {
                assertionFailure("Bar（水平图）暂不支持 secondaryYAxis，将忽略")
                currentSecondaryYDomain = nil
                currentSecondaryValueTicks = []
            } else {
                let bounds = model.dataBounds(yAxisIndex: 1)
                let domain = makeValueDomain(axis: secondary, bounds: bounds)
                currentSecondaryYDomain = domain
                currentSecondaryValueTicks = domain.lowerBound == domain.upperBound
                    ? []
                    : ValueTickGenerator.ticks(axis: secondary, domain: domain,
                                               dataBounds: bounds, generatesFromDomain: false)
            }
        } else {
            currentSecondaryYDomain = nil
            currentSecondaryValueTicks = []
        }
```

3d. 步骤 3 布局：`leadingLabelWidth` 计算之后加右侧宽度，并传入 layout：

```swift
        let rightAxisLabelWidth: CGFloat = currentSecondaryYDomain == nil ? 0 :
            currentSecondaryValueTicks.map {
                textSize(AxisRenderer.tickText($0, formatter: model.yAxis.tickInterval != nil && model.secondaryYAxis?.labelFormatter == nil
                          ? nil : model.secondaryYAxis?.labelFormatter),
                         font: cartTheme.tickLabelFont).width }.max() ?? 0
```

（简化写法——直接用 `model.secondaryYAxis?.labelFormatter`：）

```swift
        let rightAxisLabelWidth: CGFloat = currentSecondaryYDomain == nil ? 0 :
            currentSecondaryValueTicks.map {
                textSize(AxisRenderer.tickText($0, formatter: model.secondaryYAxis?.labelFormatter),
                         font: cartTheme.tickLabelFont).width }.max() ?? 0
```

layout 调用加 `rightAxisLabelWidth: rightAxisLabelWidth`。

3e. 步骤 4 网格/轴/标签：

```swift
        var secondaryGridTicks: [Double] = []
        if currentSecondaryYDomain != nil,
           model.secondaryYAxis?.showsGridlines == true {
            secondaryGridTicks = currentSecondaryValueTicks
        }
        rootLayer.addSublayer(GridRenderer.makeGridLayer(
            valueTicks: currentValueTicks, categoryCount: model.maxPointCount,
            viewport: currentViewport, plotFrame: currentPlotFrame, theme: cartTheme,
            isHorizontalValueAxis: isHorizontalValueAxis,
            secondaryValueTicks: secondaryGridTicks,
            secondaryYDomain: currentSecondaryYDomain))
        rootLayer.addSublayer(AxisRenderer.makeAxisLinesLayer(
            plotFrame: currentPlotFrame, theme: cartTheme,
            showsRightAxis: currentSecondaryYDomain != nil))
```

`addTickLabels` 垂直分支末尾加：

```swift
            if let secondary = model.secondaryYAxis, !isHorizontalValueAxis {
                tickLabels.append(contentsOf: AxisRenderer.makeRightValueTickLabels(
                    ticks: currentSecondaryValueTicks, viewport: currentViewport,
                    plotFrame: currentPlotFrame, theme: theme,
                    formatter: secondary.labelFormatter))
            }
```

3f. 轴感知屏幕映射（`screenPoint` 旁）：

```swift
    /// 值 → 屏幕（按系列绑定的值轴选域；0 = 主轴 viewport.yDomain，1 = 次轴域）。
    func screenPoint(x: Double, y: Double, yAxisIndex: Int = 0) -> CGPoint {
        let domain = yAxisIndex == 1 ? currentSecondaryYDomain : nil
        return CartesianGeometry.point(x: x, y: y, viewport: currentViewport,
                                       plotFrame: currentPlotFrame, yDomain: domain)
    }
```

（既有 `screenPoint(x:y:)` 调用不删——它是 `screenPoint(x:y:yAxisIndex:0)` 的等价形式，直接改原方法签名加默认参数即可，二选一，推荐改签名。）

- [ ] **Step 4: AxisRenderer / GridRenderer / layout 实现**

`AxisRenderer`：

```swift
    /// 生成右侧数值刻度 labels（双值轴的次轴）：左对齐贴 plot 右缘外侧。
    static func makeRightValueTickLabels(ticks: [Double],
                                         viewport: CartesianViewport,
                                         plotFrame: CGRect,
                                         theme: CartesianChartTheme,
                                         formatter: ((Double) -> String)? = nil) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = tickText(tick, formatter: formatter)
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let y = CartesianGeometry.point(x: 0, y: tick,
                                            viewport: viewport, plotFrame: plotFrame).y
            lbl.center = CGPoint(x: plotFrame.maxX + theme.axisLabelGap + lbl.bounds.width / 2,
                                 y: y)
            return lbl
        }
    }
```

`makeAxisLinesLayer` 加 `showsRightAxis: Bool = false`，为 true 时 path 追加右缘竖线（`(maxX, minY) → (maxX, maxY)`）。

`GridRenderer.makeGridLayer` 加 `secondaryValueTicks: [Double] = []`、`secondaryYDomain: ClosedRange<Double>? = nil`；垂直分支在现有横线块后追加：

```swift
        // 次轴网格线（默认关；轴级 showsGridlines 开启时才传入 ticks）
        if !secondaryValueTicks.isEmpty, theme.showsHorizontalGridlines {
            for tick in secondaryValueTicks {
                let y = CartesianGeometry.point(x: 0, y: tick, viewport: viewport,
                                                plotFrame: plotFrame,
                                                yDomain: secondaryYDomain).y
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
        }
```

`CartesianGeometry.layout` 加 `rightAxisLabelWidth: CGFloat = 0`，宽度公式改为：

```swift
        let w = max(0, bounds.width - contentInset.left - contentInset.right
                        - yAxisTickLabelWidth - axisLabelGap
                        - rightAxisLabelWidth - (rightAxisLabelWidth > 0 ? axisLabelGap : 0))
```

- [ ] **Step 5: 跑测试验证通过 + 全量回归**

Run: 同 Task 1 Step 2 命令
Expected: `testChartSelfTest passed`（含 Bar 水平轴断言不回归）

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat(charts): 双值轴渲染（次轴独立域/刻度、右侧让宽、右轴标签与轴线、次轴网格开关）"
```

---

### Task 4: Column/Line 系列按轴映射 + 命中带轴索引

**Files:**
- Modify: `SwiftFunctionProject/Charts/Column/ColumnChartRenderer.swift`
- Modify: `SwiftFunctionProject/Charts/Column/ColumnHitTarget.swift`
- Modify: `SwiftFunctionProject/Charts/Line/LineChartRenderer.swift`（`LineHitTarget` 同文件）
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

**Interfaces:**
- Consumes: Task 2 `valueDomain`/`effectiveYAxisIndex`/`stackedValuesByAxis`、Task 3 `screenPoint(x:y:yAxisIndex:)`/`currentSecondaryYDomain`
- Produces: `ColumnHitTarget.yAxisIndex: Int`、`LineHitTarget.yAxisIndex: Int`（init 默认 0）；Column/Line 双轴系列正确映射

- [ ] **Step 1: 写失败测试（ChartSelfTest，同样方式追加）**

```swift
        // —— 双轴系列映射与命中 ——
        runDualAxisSeriesSelfTest()

        print("✅ ChartSelfTest passed")
    }

    /// 次轴系列按次轴域映射：同一数值、不同轴 → 不同屏幕高度；命中 target 带轴索引。
    static func runDualAxisSeriesSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        var sec = CartesianAxisModel(kind: .value, min: 0, max: 100)
        sec.tickPositions = [0, 50, 100]
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "温度", data: [15, 25]),
                     CartesianSeriesElement(name: "湿度", data: [15, 25], yAxisIndex: 1)],
            secondaryYAxis: sec)
        r.render(model: model, theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame

        // 1) 主轴系列：25 在域 0...30 → 上部 1/6 高度处
        let pMain = r.testScreenPoint(series: 0, index: 1)
        let expectedMain = plot.maxY - plot.height * (25.0 / 30.0)
        assert(abs(pMain.y - expectedMain) < 1.0,
               "主轴系列应按主轴域映射，got \(pMain.y) vs \(expectedMain)")
        // 2) 次轴系列：25 在域 0...100 → 正中
        let pSec = r.testScreenPoint(series: 1, index: 1)
        assert(abs(pSec.y - plot.midY) < 1.0,
               "次轴系列应按次轴域映射到半高，got \(pSec.y) vs \(plot.midY)")

        // 3) 命中 target 带 yAxisIndex
        if let hit = r.hitTest(pSec) as? LineHitTarget {
            assert(hit.yAxisIndex == 1, "次轴系列命中应带 yAxisIndex=1，got \(hit.yAxisIndex)")
            assert(abs(hit.value - 25) < 0.001, "命中值应为原始值 25")
        } else {
            assertionFailure("次轴数据点应可命中")
        }

        // 4) Column 双轴负值零轴：次轴域 -50...50、值 -25 → 柱在零轴（半高）下方
        let c = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        c.mount(into: hostC)
        var secNeg = CartesianAxisModel(kind: .value, min: -50, max: 50)
        secNeg.tickPositions = [-50, 0, 50]
        c.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "s", data: [-25], yAxisIndex: 1)],
            secondaryYAxis: secNeg),
                 theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        let plotC = c.currentPlotFrame
        if let hitC = c.hitTest(CGPoint(x: plotC.midX, y: plotC.midY + plotC.height * 0.2)) as? ColumnHitTarget {
            assert(hitC.yAxisIndex == 1, "次轴柱命中应带 yAxisIndex=1")
        } else {
            assertionFailure("次轴负值柱（零轴下方）应可命中")
        }
    }
```

- [ ] **Step 2: 跑测试验证失败**

Run: 同 Task 1 Step 2 命令
Expected: `testScreenPoint` 无 axis 参数编译错 → 桩化后断言失败（次轴系列仍按主轴域映射、yAxisIndex 不存在）。

- [ ] **Step 3: LineHitTarget / ColumnHitTarget 加 yAxisIndex**

`LineHitTarget`：

```swift
    public let yAxisIndex: Int
    public init(seriesIndex: Int, index: Int, value: Double, label: String?, yAxisIndex: Int = 0) {
        …现有赋值…
        self.yAxisIndex = yAxisIndex
        // tooltip 文本追加轴标记（次轴）
        if yAxisIndex == 1 { self.tooltipText = "\(name) · \(AxisRenderer.format(value)) (右轴)" }
    }
```

（注意现有 init 里 tooltipText 的构造需按上面拆开：默认路径保持原文本。）

`ColumnHitTarget` 加 `public let yAxisIndex: Int`，init 加 `yAxisIndex: Int = 0`；`identifier` 改为 `"column:\(seriesIndex):\(categoryIndex):\(yAxisIndex)"` 之外的**保持不变**（identifier 语义不动，避免影响外部判等）。

- [ ] **Step 4: LineChartRenderer 按轴映射**

- `drawSeries`：系列循环内取 `let axisIdx = element.effectiveYAxisIndex`，`screenPts` 改用 `screenPoint(x: Double(i), y: v, yAxisIndex: axisIdx)`；
  面积分支的 `zeroY` 改为按轴计算：

```swift
            let zeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)
```

（`zeroY` 移进系列循环；`hitRadius` 命中 frame 逻辑不变。）

- `seriesHitTest` 返回处带轴：

```swift
            let element = model.series[hit.series]
            return LineHitTarget(seriesIndex: hit.series, index: hit.index,
                                 value: value, label: element.name,
                                 yAxisIndex: element.effectiveYAxisIndex)
```

- `testScreenPoint`（DEBUG 辅助）加轴感知：

```swift
    func testScreenPoint(series: Int, index: Int) -> CGPoint {
        guard let model = currentModel,
              series < model.series.count, index < model.series[series].data.count else {
            return .zero
        }
        return screenPoint(x: Double(index), y: model.series[series].data[index],
                           yAxisIndex: model.series[series].effectiveYAxisIndex)
    }
```

- [ ] **Step 5: ColumnChartRenderer 按轴映射**

- `drawSeries` 系列循环内：

```swift
            let axisIdx = model.series[seriesIndex].effectiveYAxisIndex
            let zeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)
```

（原循环外 `zeroY` 移入循环；`animatedRect(from:zeroY:)` 用各系列自己的 zeroY。）

- `columnRect` 调用加 `valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil`。
- 堆叠基准/分隔线改按轴分组（见 Task 5 一起改，本 Task 先不动堆叠逻辑）。
- `seriesHitTest` 循环内 rect 计算同样加 `valueDomain:`（按 `model.series[seriesIndex].effectiveYAxisIndex`），返回 `ColumnHitTarget(seriesIndex:categoryIndex:value:yAxisIndex:)`。

- [ ] **Step 6: 跑测试验证通过**

Run: 同 Task 1 Step 2 命令
Expected: `testChartSelfTest passed`

- [ ] **Step 7: 提交**

```bash
git add -A
git commit -m "feat(charts): Column/Line 系列按绑定值轴映射，命中 target 携带 yAxisIndex"
```

---

### Task 5: 折线/面积堆叠（+ Column 堆叠按轴分组）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Line/LineChartRenderer.swift`
- Modify: `SwiftFunctionProject/Charts/Column/ColumnChartRenderer.swift`
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

**Interfaces:**
- Consumes: Task 2 `stackedValuesByAxis`、Task 4 按轴 `screenPoint`/`zeroY`
- Produces: `StackConfig.normal` 下折线画累计值、面积分层（系列 i 面积下边界 = 同轴前一累计线）、命中报累计值（与柱状一致）

- [ ] **Step 1: 写失败测试（ChartSelfTest，同样方式追加）**

```swift
        // —— 折线/面积堆叠 ——
        runLineStackingSelfTest()

        print("✅ ChartSelfTest passed")
    }

    /// 堆叠折线：累计线位置正确；面积分层（第 2 系列面积下边界 = 第 1 系列累计线）；命中报累计值。
    static func runLineStackingSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        var theme = CartesianChartTheme()
        theme.showsArea = true
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 40]),
                     CartesianSeriesElement(name: "b", data: [10, 20])],
            stacking: .normal)
        r.render(model: model, theme: theme,
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame
        // 域 = 累计边界 (10...60) → nice 0...60
        assert(abs(r.currentViewport.yMax - 60) < 0.001,
               "堆叠域应按累计值 0...60，got \(r.currentViewport.yDomain)")

        // 系列 1（上层）在 index1 的累计值 = 40+20 = 60 → 顶部
        let top = r.testScreenPoint(series: 1, index: 1)
        assert(abs(top.y - plot.minY) < 1.0, "累计 60 应在 plot 顶部，got \(top.y)")
        // 系列 0 在 index1 = 40 → 底部起 2/3 高
        let mid = r.testScreenPoint(series: 0, index: 1)
        assert(abs(mid.y - (plot.maxY - plot.height * (40.0 / 60.0))) < 1.0,
               "系列0 累计 40 应按 40/60 映射，got \(mid.y)")

        // 命中报累计值（与柱状一致）：点系列1 index1 → 60
        if let hit = r.hitTest(top) as? LineHitTarget {
            assert(abs(hit.value - 60) < 0.001, "堆叠命中应报累计值 60，got \(hit.value)")
        } else {
            assertionFailure("堆叠折线顶层点应可命中")
        }

        // 面积分层：系列 1 的面积 mask path 应包含「系列 0 累计线上的点」（下边界），
        // 且不包含零轴下方。取系列0 index1 屏幕点 mid：它应落在系列1面积 path 内部
        // （CGPath.contains 判定；seriesLayer 上的 gradient mask 数量 = 2）
        let seriesLayers = r.seriesLayerSublayersForTesting()
        assert(seriesLayers.count { $0 is CAGradientLayer } == 2, "两层面积渐变")
    }
```

> 注：`seriesLayerSublayersForTesting()` 为本 Task 在 `LineChartRenderer` 加的 DEBUG 辅助（返回 `seriesLayer.sublayers ?? []`）；`testScreenPoint` 在堆叠模式须返回**累计值**位置（实现见 Step 3），断言依赖这一点。

- [ ] **Step 2: 跑测试验证失败**

Run: 同 Task 1 Step 2 命令
Expected: 桩化编译后断言失败（当前折线不堆叠：域为 10...40 而非 0...60；顶层点位置错误）。

- [ ] **Step 3: LineChartRenderer 堆叠实现（drawSeries 重写数据源与面积下边界）**

drawSeries 开头（清空之后）：

```swift
        // 堆叠：按轴分组链式累计（跨轴不混叠）；非堆叠用原值
        let dataToDraw: [[Double]] = model.stacking == .normal
            ? CartesianGeometry.stackedValuesByAxis(series: model.series)
            : model.series.map { $0.data }
```

系列循环签名改遍历 `(s, element)`，取：

```swift
            let axisIdx = element.effectiveYAxisIndex
            let values = dataToDraw[s]
```

`screenPts` 用 `values` 与 `screenPoint(x: Double(i), y: v, yAxisIndex: axisIdx)`；命中 frame 收集同步用 `values`（数值仅作位置；命中值见下）。

面积下边界（替换现有 `if theme.showsArea` 块中从零轴闭合的部分）：

```swift
            if theme.showsArea, let first = screenPts.first, let last = screenPts.last {
                let areaPath = UIBezierPath(cgPath: path.cgPath)
                // 分层下边界：同轴前一系列的累计线（屏幕坐标倒序回走）；组内首系列为零轴
                if model.stacking == .normal {
                    let prevSameAxis = model.series[..<s].lastIndex { $0.effectiveYAxisIndex == axisIdx }
                    if let p = prevSameAxis {
                        let prevPts = dataToDraw[p].enumerated().map { (i, v) in
                            screenPoint(x: Double(i), y: v, yAxisIndex: axisIdx)
                        }
                        for pp in prevPts.reversed() { areaPath.addLine(to: pp) }
                    } else {
                        areaPath.addLine(to: CGPoint(x: last.x, y: zeroY))
                        areaPath.addLine(to: CGPoint(x: first.x, y: zeroY))
                    }
                } else {
                    areaPath.addLine(to: CGPoint(x: last.x, y: zeroY))
                    areaPath.addLine(to: CGPoint(x: first.x, y: zeroY))
                }
                areaPath.close()
                …现有 gradient/mask 构造不变…
            }
```

（`lastIndex(where:)` 若无内置，用 `model.series[..<s].indices.last { model.series[$0].effectiveYAxisIndex == axisIdx }`。）

`lastPointFrames` 存值改为累计值供命中：

```swift
            for (i, p) in screenPts.enumerated() {
                let r = max(hitRadius, theme.pointRadius)
                lastPointFrames.append((s, i,
                    CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
            }
```

`seriesHitTest` 取值改为：

```swift
            let value: Double
            if currentModel?.stacking == .normal {
                value = CartesianGeometry.stackedValuesByAxis(series: model.series)[hit.series][hit.index]
            } else {
                value = model.series[hit.series].data[hit.index]
            }
```

`testScreenPoint` 同样在堆叠模式用 `stackedValuesByAxis` 的值。

加 DEBUG 辅助：

```swift
    func seriesLayerSublayersForTesting() -> [CALayer] { seriesLayer.sublayers ?? [] }
```

- [ ] **Step 4: ColumnChartRenderer 堆叠换 stackedValuesByAxis（跨轴分组）**

`drawSeries` 与 `seriesHitTest` 中 `CartesianGeometry.stackedValues(series:)` 全部替换为 `CartesianGeometry.stackedValuesByAxis(series:)`；`baselineValue` 判断改为"同轴前一系列"：

```swift
                let baselineValue: Double?
                if model.stacking == .normal {
                    if let p = model.series[..<seriesIndex].indices
                        .last(where: { model.series[$0].effectiveYAxisIndex == axisIdx }) {
                        baselineValue = dataToDraw[p][index]
                    } else { baselineValue = nil }
                } else { baselineValue = nil }
```

分隔线条件 `seriesIndex < model.series.count - 1` 改为"不是同轴最后一个系列"（同 `lastIndex` 判定取反）。

- [ ] **Step 5: 跑测试验证通过 + 全量回归**

Run: `xcodebuild test … `（不带 -only-testing，全量）
Expected: 全部测试通过（含柱状堆叠既有断言——`stackedValuesByAxis` 全 0 轴等价已由 Task 2 断言保证）

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat(charts): 折线/面积堆叠（按轴分组累计、分层面积、每系列独立颜色渐变）"
```

---

### Task 6: demo、文档与视觉验收

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/LineChartDemo.swift`
- Modify: `SwiftFunctionProject/Charts/SwiftUI/ColumnChartDemo.swift`
- Modify: `docs/charts-line-guide.md`、`docs/charts-column-guide.md`
- Test: 模拟器截图目检（临时快照测试，验后删）

**Interfaces:**
- Consumes: 前五个 Task 的全部公开 API

- [ ] **Step 1: LineChartDemo 面板与数据**

新增 @State：

```swift
    // —— 双轴 / 堆叠 / 刻度自定义 ——
    @State private var dualAxisOn = false
    @State private var stackingMode = "不堆叠"
    @State private var tickCountOn = false
    @State private var tickCount = 6.0
    @State private var useTickPositions = false
    @State private var usePercentFormatter = false
```

`currentModel` 改造：

```swift
    private var currentModel: CartesianChartModel {
        var y = CartesianAxisModel(kind: .value)
        if tickCountOn { y.tickCount = Int(tickCount) }
        if useTickPositions { y.tickPositions = [0, 30, 60, 100] }
        if usePercentFormatter { y.labelFormatter = { "\(Int($0))%" } }

        let stacking: StackConfig? = stackingMode == "普通堆叠" ? .normal : nil
        var series: [CartesianSeriesElement]
        if dualAxisOn {
            // 温度（左轴）+ 湿度（右轴）
            series = [
                CartesianSeriesElement(name: "温度(℃)", data: data.map { ($0 / 10 + 5).rounded() },
                                       color: .systemOrange),
                CartesianSeriesElement(name: "湿度(%)", data: data, yAxisIndex: 1, color: .systemBlue)
            ]
        } else if stacking == .normal {
            series = [
                CartesianSeriesElement(name: "系列1", data: data.map { $0 * 0.6 }, color: .systemBlue),
                CartesianSeriesElement(name: "系列2", data: data.map { $0 * 0.4 }, color: .systemGreen)
            ]
        } else {
            series = [CartesianSeriesElement(name: "2026", data: data)]
        }

        var secondary: CartesianAxisModel?
        if dualAxisOn {
            var s = CartesianAxisModel(kind: .value, min: 0, max: 100)
            s.labelFormatter = { "\(Int($0))%" }
            secondary = s
        }
        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            xAxis: CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : [])),
            yAxis: y,
            secondaryYAxis: secondary,
            stacking: stacking)
    }
```

面板加 section（`panel` 中 `dataSection` 之后）：

```swift
        let axisSection = ChartDemoPanel.DemoSection(title: "轴系", items: [
            .toggle(label: "双轴（温度左轴 / 湿度右轴）", value: $dualAxisOn),
            .picker(label: "堆叠模式", selection: $stackingMode, options: ["不堆叠", "普通堆叠"]),
            .toggle(label: "自定义刻度数量", value: $tickCountOn),
            .slider(label: "刻度数量", value: $tickCount, range: 2...12, step: 1),
            .toggle(label: "显式刻度位置（0/30/60/100）", value: $useTickPositions),
            .toggle(label: "刻度文本加 %", value: $usePercentFormatter),
        ])
```

sections 数组加入 `axisSection`。堆叠开启时建议联动开 `showsArea`（在 currentTheme 中 `if stackingMode == "普通堆叠" { t.showsArea = true }`，面板仍可关）。

- [ ] **Step 2: ColumnChartDemo 双轴**

新增 `@State private var dualAxisOn = false`；`currentModel` 中当 `dualAxisOn` 时最后一系列绑次轴并设 `secondaryYAxis`：

```swift
        var series = (0..<seriesCount).map { index in
            CartesianSeriesElement(
                name: "系列\(index + 1)",
                data: index < data.count ? data[index] : Self.randomData(count: pointCount),
                color: seriesColors[index % seriesColors.count],
                yAxisIndex: (dualAxisOn && index == seriesCount - 1) ? 1 : 0)
        }
        var secondary: CartesianAxisModel?
        if dualAxisOn {
            var s = CartesianAxisModel(kind: .value)
            s.labelFormatter = { "\(Int($0))†" }
            secondary = s
        }
```

init 传 `secondaryYAxis: secondary`。堆叠 section 加 `.toggle(label: "双轴（末系列绑右轴）", value: $dualAxisOn)`。

- [ ] **Step 3: 临时快照测试 + 目检**

在 `SwiftFunctionProjectTests/SwiftFunctionProjectTests.swift` 临时加 `testRenderSnapshots()`（参照 6e8c17a 提交前同款做法：UIGraphicsImageRenderer 渲染 6 张到 /tmp：`line_dual`（双轴）、`line_stack`（堆叠+面积）、`line_ticks`（tickCount=3 + % 文本）、`col_dual`、`col_stack_dual`（双轴+堆叠混合）、`line_plain`（回归基线））。跑测试生成图片，逐张 Read 目检：双轴两套刻度各归各边、堆叠面积分层颜色独立、刻度数量/文本生效、基线图与改造前一致。
验后删除该测试方法。

- [ ] **Step 4: 文档更新**

`docs/charts-line-guide.md` 追加「双值轴」「堆叠与面积」「刻度自定义」小节（各含一段 Swift 用法示例，示例与 demo 一致）；`docs/charts-column-guide.md` 追加「双值轴」小节。

- [ ] **Step 5: 全量回归**

Run: `xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: 全部通过（单元 + UI 测试）

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat(demo): 双轴/折线堆叠/刻度自定义 demo 与文档"
```

---

## Self-Review 记录

- Spec 覆盖：§3 模型（Task 1/2）、§4 渲染（Task 3/4）、§5 堆叠（Task 5）、§7 demo/文档（Task 6）、§8 验收（各 Task 断言 + Task 6 快照/全量回归）——全覆盖
- 类型一致性：`effectiveYAxisIndex`/`stackedValuesByAxis`/`ValueTickGenerator.ticks`/`screenPoint(x:y:yAxisIndex:)`/`currentSecondaryYDomain` 各 Task 间签名一致
- 已知取舍：命中报累计值（与柱状现状对齐，spec §5）；`identifier` 不变避免外部判等破坏
