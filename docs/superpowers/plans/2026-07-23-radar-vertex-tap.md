# 蛛网图顶点点击交互 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为雷达图增加数据顶点/标题顶点的点击交互：命中 → 选中高亮（单选互斥）+ `onHit` 回调；通用层为「命中分类」建立 `kind` 槽位范式。

**Architecture:** Core 加通用 `kind: String` 槽位 + `onTap` 支持取消选中；Radar 特有 `RadarHitTarget(category)` + `hitTest`（数据顶点优先 + 容差）+ `applySelection`（单选互斥，重绘顶点应用高亮）；Theme 加可配高亮字段；ChartSelfTest 验证命中/优先级/容差。

**Tech Stack:** Swift / UIKit（CAShapeLayer）/ SwiftUI（UIViewRepresentable）/ Objective-C 桥接。部署目标 iOS 26.2。

**Spec:** `docs/superpowers/specs/2026-07-23-radar-vertex-tap-design.md`

---

## 本仓库执行约定

1. **不主动 commit。** 用户已明确「暂不提交 git」，所有改动只放工作区，完成标志是 `** BUILD SUCCEEDED **` + 自检/运行验证通过。等用户指令才 commit。
2. **测试 = `ChartSelfTest` DEBUG 断言**，不是 XCTest。纯逻辑（hitTest、kind 派生）加 `assert`；视觉（高亮）用模拟器手动验证。
3. **以 `xcodebuild` 为唯一权威**，SourceKit 假阳性（`No such module 'UIKit'` / 跨文件 `Cannot find type`）忽略。
4. **整树同步编译**，新增/修改文件无需改 pbxproj；严禁与已有 `.swift` 同名。

### 验证命令

```bash
# 编译（权威）
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 运行 + 自检输出
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
```

---

## 文件结构

| 文件 | 职责 | Task |
|------|------|------|
| `Charts/Core/HYMChartInteraction.swift` | `HYMChartHitTarget` 加通用 `kind` 槽位 + 默认实现 | 1 |
| `Charts/Radar/RadarChartRenderer.swift` | `RadarHitCategory`/`RadarHitTarget`、命中缓存、`hitTest`、`applySelection`、rebuild 选中态分支 | 2,3,4 |
| `Charts/Radar/RadarChartTheme.swift` | 5 个 selection 高亮字段 | 2 |
| `Charts/Core/HYMChartView.swift` | `onTap` 扩展（未命中 `applySelection(nil)`） | 5 |
| `Charts/SwiftUI/RadarChart.swift` | `onHit` 类型改为 `RadarHitTarget` | 6 |
| `Charts/OCBridge/HYMRadarThemeBuilder.swift` | 5 个 selection 字段 + build 映射 | 6 |
| `Charts/OCBridge/HYMRadarChartViewBridge.swift` | `onHit` 签名 `(kind, index)` | 6 |
| `Charts/Debug/ChartSelfTest.swift` | 命中/优先级/容差/kind 断言 | 7 |

---

## Task 1: Core 通用层 — `HYMChartHitTarget` 加 `kind` 槽位

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartInteraction.swift`

- [ ] **Step 1: 协议加 `kind` + 默认实现**

把 `HYMChartHitTarget` 协议改为（加 `kind` 声明），并在 extension 加默认实现 `""`：

```swift
/// 图表中一个可命中的语义单元（关联数据，非绘图细节）
public protocol HYMChartHitTarget {
    /// 业务标识，如 "进攻"
    var identifier: String { get }
    /// 序号
    var index: Int { get }
    /// 通用类别槽位（如 "dataVertex"/"labelVertex"）；默认 "" 表示不分类。
    /// 具体类别值由各图表特有 HitTarget 定义，不污染本通用协议。
    var kind: String { get }
}

public extension HYMChartHitTarget {
    var kind: String { "" }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Radar 特有层 — `RadarHitCategory`/`RadarHitTarget` + Theme 高亮字段

**Files:**
- Modify: `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift`（顶部加两个类型）
- Modify: `SwiftFunctionProject/Charts/Radar/RadarChartTheme.swift`（加 5 字段）

- [ ] **Step 1: 在 `RadarChartRenderer.swift` 顶部（`import UIKit` 之后、`class RadarChartRenderer` 之前）加两个类型**

```swift
/// 雷达图命中目标类别（特有，String rawValue 用于派生通用 `kind`）。
public enum RadarHitCategory: String {
    case dataVertex      // 数据值顶点（内圈）
    case labelVertex     // 标题顶点圆点（最外圈）
}

/// 雷达图命中目标（特有）。强类型 `category` 给 Swift 用；`kind` 派生给通用层/OC。
public struct RadarHitTarget: HYMChartHitTarget {
    public let category: RadarHitCategory
    public let dimensionIndex: Int
    public init(category: RadarHitCategory, dimensionIndex: Int) {
        self.category = category
        self.dimensionIndex = dimensionIndex
    }
    public var identifier: String { "\(category.rawValue):\(dimensionIndex)" }
    public var index: Int { dimensionIndex }
    public var kind: String { category.rawValue }
}
```

- [ ] **Step 2: `RadarChartTheme.swift` 加 5 个 selection 字段**

在 `struct RadarChartTheme` 的**存储属性区**（`showsEntranceAnimation` 相关字段附近）加：

```swift
    // —— 选中态高亮（顶点点击）——
    public var selectionScale: CGFloat          // 选中放大倍数；1.0 = 不放大
    public var selectionStrokeColor: UIColor?   // 选中描边色；nil = 不描边
    public var selectionStrokeWidth: CGFloat    // 描边线宽
    public var selectionColor: UIColor?         // 选中变色；nil = 用原色不变色
    public var selectionHitPadding: CGFloat     // 命中容差（pt）
```

在 `init(...)` 的**参数列表末尾**（最后一个现有参数 `decorativeRingFillColor: UIColor? = nil` 之后）加：

```swift
        selectionScale: CGFloat = 1.5,
        selectionStrokeColor: UIColor? = .white,
        selectionStrokeWidth: CGFloat = 2,
        selectionColor: UIColor? = UIColor(red: 0xFF/255.0, green: 0xC1/255.0, blue: 0x07/255.0, alpha: 1),
        selectionHitPadding: CGFloat = 10
```

在 `init` **方法体末尾**（最后一个 `self.xxx = xxx` 之后）加：

```swift
        self.selectionScale = selectionScale
        self.selectionStrokeColor = selectionStrokeColor
        self.selectionStrokeWidth = selectionStrokeWidth
        self.selectionColor = selectionColor
        self.selectionHitPadding = selectionHitPadding
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 3: Radar 命中缓存 + `hitTest`

**Files:**
- Modify: `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift`

- [ ] **Step 1: 加命中缓存属性 + lastRadius**

在 `RadarChartRenderer` 的私有状态区（`currentModel`/`currentTheme`/`lastCenter` 附近）加：

```swift
    private var lastRadius: CGFloat = 0
    /// 命中检测缓存：数据顶点先入、标题顶点后入（保证数据优先）
    private struct HitRecord {
        let category: RadarHitCategory
        let dimensionIndex: Int
        let center: CGPoint
        let radius: CGFloat
    }
    private var hitRecords: [HitRecord] = []
    /// 当前选中（单选）
    private var currentSelection: (category: RadarHitCategory, dimensionIndex: Int)?
```

- [ ] **Step 2: `render(...)` 末尾构建 hitRecords + 存 lastRadius**

在 `render(...)` 方法体末尾（现有 `for l in animatableLayers { l.frame = context.bounds }` 之后）加。注意复用 `render` 内已有的 `center`/`radius`/`model`/`theme`：

```swift
        lastRadius = radius
        hitRecords.removeAll()
        let nDot = model.dimensions.count
        for i in 0..<nDot {
            let dim = model.dimensions[i]
            let p = RadarGeometry.point(index: i, count: nDot, center: center, radius: radius, ratio: dim.normalized)
            hitRecords.append(HitRecord(category: .dataVertex, dimensionIndex: i, center: p, radius: theme.vertexDotRadius))
        }
        for i in 0..<nDot {
            let p = RadarGeometry.point(index: i, count: nDot, center: center, radius: radius, ratio: 1)
            hitRecords.append(HitRecord(category: .labelVertex, dimensionIndex: i, center: p, radius: theme.labelDotRadius))
        }
```

> 注意：`render` 内对空 `dimensions` 的 early-return 分支（`guard !model.dimensions.isEmpty`）也要在该分支里 `hitRecords.removeAll()`，避免命中残留旧记录。

- [ ] **Step 3: 实现 `hitTest`（覆盖协议默认 nil 实现）**

在 `RadarChartRenderer` 内加：

```swift
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        let pad = currentTheme?.selectionHitPadding ?? 10
        for r in hitRecords {
            let dx = point.x - r.center.x
            let dy = point.y - r.center.y
            if (dx * dx + dy * dy) <= (r.radius + pad) * (r.radius + pad) {
                return RadarHitTarget(category: r.category, dimensionIndex: r.dimensionIndex)
            }
        }
        return nil
    }
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 4: `applySelection` + rebuild 选中态高亮

**Files:**
- Modify: `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift`

- [ ] **Step 1: `rebuildVertexDots` 加选中态高亮分支**

把现有 `rebuildVertexDots(_:center:radius:)` 替换为（在原基础上加选中判定）：

```swift
    private func rebuildVertexDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        vertexDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let n = model.dimensions.count
        let baseDotRadius = theme.vertexDotRadius
        for i in 0..<n {
            let dim = model.dimensions[i]
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: dim.normalized)
            let selected = (currentSelection?.category == .dataVertex && currentSelection?.dimensionIndex == i)
            let dotRadius = selected ? baseDotRadius * theme.selectionScale : baseDotRadius
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(arcCenter: p, radius: dotRadius,
                                    startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true).cgPath
            let baseColor = dim.dataDotColor ?? theme.vertexDotColor
            dot.fillColor = (selected ? (theme.selectionColor ?? baseColor) : baseColor).cgColor
            dot.strokeColor = (selected ? (theme.selectionStrokeColor ?? theme.vertexDotRingColor)
                                        : theme.vertexDotRingColor).cgColor
            dot.lineWidth = selected ? max(2, theme.selectionStrokeWidth) : 2
            vertexDotsContainerLayer.addSublayer(dot)
        }
    }
```

- [ ] **Step 2: `rebuildLabelDots` 加选中态高亮分支**

把现有 `rebuildLabelDots(_:center:radius:)` 替换为：

```swift
    private func rebuildLabelDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        labelDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let n = model.dimensions.count
        let baseDotRadius = theme.labelDotRadius
        for i in 0..<n {
            let dim = model.dimensions[i]
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: 1)
            let selected = (currentSelection?.category == .labelVertex && currentSelection?.dimensionIndex == i)
            let dotRadius = selected ? baseDotRadius * theme.selectionScale : baseDotRadius
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(arcCenter: p, radius: dotRadius,
                                    startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true).cgPath
            let baseColor = dim.labelDotColor ?? theme.labelDotColor
            dot.fillColor = (selected ? (theme.selectionColor ?? baseColor) : baseColor).cgColor
            dot.strokeColor = (selected ? (theme.selectionStrokeColor ?? UIColor.clear) : UIColor.clear).cgColor
            dot.lineWidth = selected ? max(2, theme.selectionStrokeWidth) : 0
            labelDotsContainerLayer.addSublayer(dot)
        }
    }
```

- [ ] **Step 3: 实现 `applySelection`（覆盖协议默认空实现）**

在 `RadarChartRenderer` 内加：

```swift
    public func applySelection(_ target: HYMChartHitTarget?) {
        if let radar = target as? RadarHitTarget {
            currentSelection = (radar.category, radar.dimensionIndex)
        } else {
            currentSelection = nil
        }
        guard let model = currentModel else { return }
        rebuildVertexDots(model, center: lastCenter, radius: lastRadius)
        rebuildLabelDots(model, center: lastCenter, radius: lastRadius)
    }
```

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 5: Core — `HYMChartView.onTap` 扩展（取消选中）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartView.swift`

- [ ] **Step 1: 改 `onTap`**

把现有 `onTap` 方法替换为（命中→选中+回调；未命中→取消选中）：

```swift
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        let target = renderer.hitTest(p)
        renderer.applySelection(target)        // 命中→选中，未命中→取消（通用）
        if let target { onHit?(target, .tap) }
    }
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 6: SwiftUI + OC 桥接

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift`
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMRadarThemeBuilder.swift`
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift`

- [ ] **Step 1: `RadarChart.swift` 的 `onHit` 类型改为 `RadarHitTarget`**

把 `RadarChart` 与 `RadarChartRepresentable` 里的 `onHit` 类型从 `((any HYMChartHitTarget, HYMChartGesture) -> Void)?` 改为：

```swift
    private let onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?
```

`makeUIView` 里 `chart.onHit` 赋值需要桥接（容器 `onHit` 是 `any HYMChartHitTarget`）：

```swift
        chart.onHit = { target, gesture in
            if let r = target as? RadarHitTarget { onHit?(r, gesture) }
        }
```

`updateUIView` 里同样更新 `chart.onHit`（同上闭包）。删除原先直接 `chart.onHit = onHit`。

- [ ] **Step 2: `HYMRadarThemeBuilder.swift` 加 5 个 selection 字段 + build 映射**

属性区加：

```swift
    @objc public var selectionScale: CGFloat = 1.5
    @objc public var selectionStrokeColor: UIColor? = .white
    @objc public var selectionStrokeWidth: CGFloat = 2
    @objc public var selectionColor: UIColor?
    @objc public var selectionHitPadding: CGFloat = 10
```

`build()` 方法体内（末尾）加：

```swift
        t.selectionScale = selectionScale
        t.selectionStrokeColor = selectionStrokeColor
        t.selectionStrokeWidth = selectionStrokeWidth
        t.selectionColor = selectionColor
        t.selectionHitPadding = selectionHitPadding
```

- [ ] **Step 3: `HYMRadarChartViewBridge.swift` 的 `onHit` 签名改为 `(kind, index)`**

把现有 `onHit: ((NSString, Int) -> Void)?` 改为：

```swift
    /// OC 端命中回调：(kind 字符串, 维度 index)。kind = "dataVertex"/"labelVertex"。
    @objc public var onHit: ((NSString, NSInteger) -> Void)?
```

`init` 里的 `chart.onHit` 接线改为：

```swift
        chart.onHit = { [weak self] target, _ in
            if let r = target as? RadarHitTarget {
                self?.onHit?(r.kind as NSString, r.dimensionIndex)
            }
        }
```

> 注意：原签名是 `(NSString, Int)`，改 `(NSString, NSInteger)` 对 OC 等价（NSInteger）；Swift 侧 `Int`→`NSInteger` 自动桥接。

- [ ] **Step 4: 编译验证**

Run: `xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 7: ChartSelfTest 自检

**Files:**
- Modify: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 在 `runAll()` 末尾（`print("✅ ChartSelfTest passed")` 之前）加断言**

```swift
        // —— RadarHitTarget / kind 槽位 ——
        let h = RadarHitTarget(category: .dataVertex, dimensionIndex: 3)
        assert(h.kind == "dataVertex", "dataVertex kind wrong: \(h.kind)")
        assert(h.index == 3, "index should be dimensionIndex")
        assert(h.identifier == "dataVertex:3", "identifier wrong: \(h.identifier)")
        let hL = RadarHitTarget(category: .labelVertex, dimensionIndex: 2)
        assert(hL.kind == "labelVertex", "labelVertex kind wrong")
        // 通用默认 kind 为空（用一个仅实现协议的 stub 验证）
        struct PlainTarget: HYMChartHitTarget { let identifier = "x"; let index = 0 }
        assert(PlainTarget().kind == "", "default kind should be empty")

        // —— hitTest：render 已知尺寸后命中/优先级/容差 ——
        let hRenderer = RadarChartRenderer()
        let hModel = RadarChartModel(dimensions: [
            RadarDimension(label: "a", value: 100),   // normalized=1 → 数据点在最外圈，与标题点重合
            RadarDimension(label: "b", value: 50),
        ])
        // center=(50,50), radius 需 > 顶点半径+padding 才不互相吃；用 bounds 100×100
        hRenderer.render(model: hModel, theme: RadarChartTheme(),
                        context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                                                       center: CGPoint(x: 50, y: 50)))
        // 维度0 数据点 normalized=1 → 与标题点同位（最外圈顶点0）。点该位置应命中 dataVertex（优先）
        // 维度0 顶点角度 -π/2 朝上：center + (0,-radius)
        // radius ≈ maxRadius(bounds 100×100)，取渲染后的 hitRecords[0].center 验证
        let data0 = hRenderer.hitRecords[0]
        let hitTop = hRenderer.hitTest(data0.center)
        if let ht = hitTop as? RadarHitTarget {
            assert(ht.category == .dataVertex, "overlap should prefer dataVertex, got \(ht.category)")
            assert(ht.dimensionIndex == 0, "dimIndex wrong")
        } else {
            assertionFailure("should hit data vertex at dim0")
        }
        // 标题点（labelVertex）命中
        let label0 = hRenderer.hitRecords.first { $0.category == .labelVertex }!
        let hitLabel = hRenderer.hitTest(label0.center)
        // label0 与 data0 若重合（dim0 normalized=1）则命中 dataVertex；改测 dim1 标题点（不重合）
        let label1 = hRenderer.hitRecords.first { $0.category == .labelVertex && $0.dimensionIndex == 1 }!
        if let hl = hRenderer.hitTest(label1.center) as? RadarHitTarget {
            assert(hl.category == .labelVertex, "dim1 label hit wrong: \(hl.category)")
        } else {
            assertionFailure("should hit label vertex dim1")
        }
        // 远离任何顶点 → nil
        assert(hRenderer.hitTest(CGPoint(x: 1, y: 1)) == nil, "far point should miss")
        // applySelection 取消
        hRenderer.applySelection(nil)
        assert(hRenderer.currentSelection == nil, "applySelection(nil) should clear")
```

> 说明：`hitRecords` 与 `currentSelection` 是 `private`，自检在 DEBUG 且同模块内访问 `internal`/`private`——本仓库 `ChartSelfTest` 与 `RadarChartRenderer` 同 target，但 `private` 跨文件不可见。**执行时需把这两个成员临时改 `internal`（或加 `#if DEBUG` internal 版本）以供自检读取**；验证通过后再决定是否保留。若不想放开可见性，则去掉直接读 `hitRecords`/`currentSelection` 的断言，只通过 `hitTest` 公开行为验证。

- [ ] **Step 2: 编译 + 运行，确认自检通过**

Run:
```bash
xcodebuild -scheme SwiftFunctionProject -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
```
Expected: `** BUILD SUCCEEDED **` + 日志含 `✅ ChartSelfTest passed`（无 assert 崩溃）。

---

## Task 8: 运行验证（模拟器手动）

**Files:** 无（验证）

- [ ] **Step 1: 运行并验证交互**

Run:
```bash
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' | head -1)"
xcrun simctl launch booted hm-test-widget.SwiftFunctionProject
```

进入「雷达图 → 默认主题 demo」，验证：
- 点数据顶点（内圈）→ 该顶点放大+描边+变色高亮，`onHit` 触发。
- 点标题顶点（最外圈圆点）→ 高亮，`onHit` 触发。
- 点另一个顶点 → 旧的取消、新的高亮（单选互斥）。
- 点空白 → 取消高亮。
- 数据顶点与标题顶点重叠处（某维 normalized=1）→ 优先命中数据顶点。

- [ ] **Step 2（可选）: 在 demo 里接 `onHit` 打日志确认回调**

`RadarChartBasicDemo` 临时接：
```swift
RadarChart(model: Self.demoModel, replayOnTap: true) { target, _ in
    print("hit: kind=\(target.kind) dim=\(target.dimensionIndex)")
}
```

---

## Self-Review

**1. Spec 覆盖：**
- 区分两种目标命中：Task 2 `RadarHitCategory` + Task 3 `hitRecords`（数据/标题分类） ✓
- 高亮+单选互斥：Task 4 `currentSelection` + `applySelection` + rebuild 选中态 ✓
- 高亮样式 Theme 可配：Task 2 五字段 + Task 4 应用 ✓
- 通用 `kind` 槽位 + 默认：Task 1 ✓
- `onTap` 未命中取消：Task 5 ✓
- SwiftUI `onHit` RadarHitTarget：Task 6 ✓
- OC `(kind, index)`：Task 6 ✓
- 自检命中/优先级/容差/kind：Task 7 ✓

**2. 占位符扫描：** 无 TBD/TODO；每步含完整代码或确切命令。

**3. 类型一致性：**
- `RadarHitCategory`/`RadarHitTarget` 定义（Task 2）→ Task 3/4/6/7 引用一致 ✓
- `HitRecord`/`hitRecords`/`currentSelection`/`lastRadius`（Task 3/4）命名一致 ✓
- `selectionScale`/`selectionStrokeColor`/`selectionStrokeWidth`/`selectionColor`/`selectionHitPadding`（Task 2 Theme）→ Task 4/6 引用一致 ✓
- `onHit` 签名：SwiftUI `(RadarHitTarget, HYMChartGesture)`（Task 6）、OC `(NSString, NSInteger)`（Task 6）—— 与 spec §4.4 一致 ✓

**4. 风险点：**
- Task 7 自检读 `private` 成员——已在 Step 1 说明处理（临时改 internal 或只验公开行为）。
- `render` 内 `guard !dimensions.isEmpty` early-return 分支需清 `hitRecords`（Task 3 Step 2 已注明）。
- 选中态重绘走 `applySelection` → `rebuildVertexDots/LabelDots`，不触发 `layoutSubviews`（不依赖 bounds），符合 spec。

---

## Execution Handoff

计划完成，存于 `docs/superpowers/plans/2026-07-23-radar-vertex-tap.md`。两种执行方式：

1. **Inline 执行（推荐，当前会话）**——我按 Task 顺序逐个改、每 Task 编译验证，不 commit。
2. **Subagent 驱动**——每个 Task 派新 subagent，任务间审查。

考虑到 8 个 Task 多为小改 + 你在快速推进，建议 inline。哪种？
