# 图表命中位置回调（外部自定义弹窗）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 HYMCharts 加一个通用的「带位置的命中回调」`onHitLocated`，让外部（Swift + OC）点击图表单元后拿到索引 + 几何位置，自行实现自定义弹窗。

**Architecture:** Core 通用层新增 `HYMChartHitContext` + `HYMChartRenderer.hitFrame(for:)` 协议方法 + `HYMChartView.onHitLocated` 回调（注册即跳过内置 tooltip）；热力图 / 雷达图各自实现 `hitFrame`；SwiftUI 封装（`HeatmapChart`/`RadarChart`）与两个 OC bridge 各加一层 `onHitLocated` 透传/翻译。

**Tech Stack:** Swift 5 / UIKit / SwiftUI / iOS 26.2 / Xcode（objectVersion 77 同步组，整树自动编译，无需改 pbxproj）。

---

## 项目约定（执行前必读）

1. **不主动 commit**：本项目约定改动堆工作区、用编译/运行验证，**用户明确要求时才 commit**。因此本计划每个 Task 末尾用「编译验证」作为检查点，**没有 git commit 步骤**；如用户中途要求提交，再单独执行。
2. **验证权威**：SourceKit 常有假阳性（`No such module 'UIKit'` / 跨文件 `Cannot find type`），**一律以 `xcodebuild` 的 `** BUILD SUCCEEDED **` 为唯一权威**，不要为假阳性改代码。
3. **测试模式**：纯逻辑用 `ChartSelfTest.runAll()`（`SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`，DEBUG 启动时跑 `assert`）。红 = 启动 app 时 assert 触发 crash；绿 = 控制台打印 `✅ ChartSelfTest passed`。运行时行为（手势/弹窗/OC block）用 demo + 模拟器验证。
4. **模拟器**：先 `xcrun simctl list devices booted` 取当前 booted 的 UDID（记 `<UDID>`），bundle id `hm-test-widget.SwiftFunctionProject`，scheme `SwiftFunctionProject`。

### 通用编译验证命令

```bash
xcodebuild -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator=name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
预期末尾：`** BUILD SUCCEEDED **`

### 通用 ChartSelfTest 运行命令（跑红/绿）

```bash
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/SwiftFunctionProject-* -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' 2>/dev/null | head -1)
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" hm-test-widget.SwiftFunctionProject
sleep 2
xcrun simctl spawn "$UDID" log show --last 5s --predicate 'eventMessage CONTAINS "ChartSelfTest"' 2>&1 | tail -5
```
- 绿预期：`✅ ChartSelfTest passed`
- 红预期：app 启动即闪退 / log 含 `assertion failed` / 缺少 `✅ ChartSelfTest passed`。

---

## File Structure

| 文件 | 改动 | 职责 |
|---|---|---|
| `SwiftFunctionProject/Charts/Core/HYMChartInteraction.swift` | 新增 `HYMChartHitContext` | 通用：命中 + 位置打包 |
| `SwiftFunctionProject/Charts/Core/HYMChartRenderer.swift` | 协议加 `hitFrame(for:)` requirement + 默认 nil | 通用：命中单元几何（独立于 tooltip 开关） |
| `SwiftFunctionProject/Charts/Core/HYMChartView.swift` | 加 `onHitLocated` + `onTap` 构造 context + `updateTooltip` 互斥 | 通用：带位置回调 + 跳过内置 tooltip |
| `SwiftFunctionProject/Charts/Heatmap/HeatmapChartRenderer.swift` | 实现 `hitFrame` | 特有：返回格子 frame |
| `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift` | 实现 `hitFrame` | 特有：顶点 center+radius → 正方形 frame |
| `SwiftFunctionProject/Charts/SwiftUI/HeatmapChart.swift` | 加 `onHitLocated` 透传 | SwiftUI 封装：暴露带位置回调 |
| `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift` | 加 `onHitLocated` 透传 | SwiftUI 封装：暴露带位置回调 |
| `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapChartViewBridge.swift` | 加 `onHitLocated` block | OC：翻译成 (row,column,frame,location) |
| `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift` | 加 `onHitLocated` block | OC：翻译成 (kind,index,frame,location) |
| `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift` | 加 hitFrame/HitContext 断言 | 自测 |
| `SwiftFunctionProject/Charts/SwiftUI/HeatmapChartDemo.swift` | 加 onHitLocated 自定义弹窗示例 | Swift demo 验证 |
| `SwiftFunctionProject/OCDemo/OCChartDemoViewController.m` | 加 bridge.onHitLocated 自定义弹窗示例 | OC demo 验证 |

---

## Task 1: Core — 新增 `HYMChartHitContext` 类型

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartInteraction.swift`（末尾追加）
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`（`runAll()` 末尾、`print("✅ ...")` 之前追加）

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾追加）

```swift
        // —— HYMChartHitContext 构造 ——
        let _ctx = HYMChartHitContext(target: _PlainTarget(), frame: CGRect(x: 1, y: 2, width: 3, height: 4),
                                      location: CGPoint(x: 5, y: 6))
        assert(abs(_ctx.frame.minX - 1) < 0.001, "HitContext.frame wrong: \(_ctx.frame)")
        assert(abs(_ctx.location.x - 5) < 0.001, "HitContext.location wrong: \(_ctx.location)")
        assert(_ctx.target.identifier == "x", "HitContext.target wrong")
```
> 注：`_PlainTarget` 已在现有 ChartSelfTest 第 56 行定义（`struct _PlainTarget: HYMChartHitTarget { let identifier = "x"; let index = 0 }`），直接复用。

- [ ] **Step 2: 跑测试确认失败**

运行「通用 ChartSelfTest 运行命令」。预期：编译失败（`cannot find 'HYMChartHitContext' in scope`）—— 红。

- [ ] **Step 3: 最小实现**（`HYMChartInteraction.swift` 文件末尾追加）

```swift

/// 一次命中 + 其在 chartView 内的几何位置（供外部自定义弹窗定位）。
///
/// 位置不进 `HYMChartHitTarget`（保持其"数据，非绘图细节"语义），单独放在此 context。
/// `frame` 与 `location` 均为 chartView 坐标系；外部按需用 `convertRect:fromView:` 等转换。
public struct HYMChartHitContext {
    /// 命中的语义单元（含 identifier/index 及具体图表的 row/column 等）。
    public let target: any HYMChartHitTarget
    /// 命中单元在 chartView 坐标系的 frame。
    public let frame: CGRect
    /// 触发点在 chartView 坐标系的位置。
    public let location: CGPoint
    public init(target: any HYMChartHitTarget, frame: CGRect, location: CGPoint) {
        self.target = target
        self.frame = frame
        self.location = location
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed` —— 绿。

- [ ] **Step 5: 编译验证**

运行「通用编译验证命令」。预期：`** BUILD SUCCEEDED **`。

---

## Task 2: Core — `HYMChartRenderer` 协议新增 `hitFrame` requirement

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartRenderer.swift:55`（协议体 `tooltipAnchor` 之后）与 `:63`（extension 默认实现区）
- Test: `ChartSelfTest.swift`（追加）

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾追加）

```swift
        // —— hitFrame 协议默认 nil ——
        // 未实现 hitFrame 的 renderer（render 前 / 默认实现）应返回 nil
        let _fr = HeatmapChartRenderer()
        assert(_fr.hitFrame(for: _PlainTarget()) == nil,
               "hitFrame default should be nil before implementation")
```

- [ ] **Step 2: 跑测试确认失败**

运行 ChartSelfTest 命令。预期：编译失败（`Value of type 'HeatmapChartRenderer' has no 'hitFrame'`）—— 红。

- [ ] **Step 3: 实现 — 协议体加 requirement**

在 `HYMChartRenderer.swift` 协议体的 `tooltipAnchor(for:)` 声明**之后**（第 55 行下方、协议右大括号之前）追加：

```swift
    /// 命中单元的几何 frame（view 坐标系），供外部自定义弹窗定位；独立于 tooltip 开关。默认 nil。
    func hitFrame(for target: HYMChartHitTarget) -> CGRect?
```

- [ ] **Step 4: 实现 — extension 加默认 nil**

在 `HYMChartRenderer.swift` 默认实现 extension（第 59-64 行）的 `tooltipAnchor` 默认实现**之后**追加：

```swift
    func hitFrame(for target: HYMChartHitTarget) -> CGRect? { nil }
```

- [ ] **Step 5: 跑测试确认通过**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed`（`HeatmapChartRenderer` 此刻用默认 nil 实现）—— 绿。

- [ ] **Step 6: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 3: Core — `HYMChartView` 新增 `onHitLocated` + 互斥逻辑

> 说明：`onHitLocated` 的触发与「互斥跳过内置 tooltip」依赖 UIView 手势 / private 方法，ChartSelfTest 不便覆盖。本 Task 验证 = 编译通过；端到端由 Task 9/10 demo 验证。

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartView.swift`（属性区 `:30` 附近、`onTap` `:124`、`updateTooltip` `:136`）

- [ ] **Step 1: 加属性**（在 `showsTooltipOnHit` 声明 `:30` **之后**追加）

```swift
    /// 命中后带位置信息的回调（外部自定义弹窗用）。
    /// 设置后内置 tooltip 自动不显示（见 `updateTooltip` 互斥）。
    public var onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?
```

- [ ] **Step 2: 改 `onTap` 命中分支**（替换 `:124` 的 `if let target { onHit?(target, .tap) }`）

```swift
        if let target {
            onHit?(target, .tap)
            let frame = renderer.hitFrame(for: target) ?? .zero
            onHitLocated?(HYMChartHitContext(target: target, frame: frame, location: p), .tap)
        }
```

- [ ] **Step 3: 加互斥**（在 `updateTooltip(for:)` `:136` 方法体最前面追加一行）

把：
```swift
    private func updateTooltip(for target: HYMChartHitTarget?) {
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
```
改为：
```swift
    private func updateTooltip(for target: HYMChartHitTarget?) {
        if onHitLocated != nil { tooltipController?.hide(); return }   // 外部接管弹窗 → 跳过内置
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
```

- [ ] **Step 4: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 5: 回归 ChartSelfTest**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed`（确保未破坏既有逻辑）。

---

## Task 4: Heatmap — 实现 `hitFrame`（格子 frame）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Heatmap/HeatmapChartRenderer.swift`（`tooltipAnchor(for:)` `:230` 之后追加）
- Test: `ChartSelfTest.swift`（追加）

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾追加）

```swift
        // —— Heatmap hitFrame：命中单元返回缓存 frame，且独立于 showsTooltipOnHit ——
        let hfModel = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell(value: 20), HeatmapCell(value: 30)]
        ])
        let hfRenderer = HeatmapChartRenderer()
        var hfTheme = HeatmapChartTheme()
        hfTheme.showsTooltipOnHit = false   // 关键：关掉内置 tooltip，hitFrame 仍必须可用
        hfRenderer.render(model: hfModel, theme: hfTheme,
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 300, height: 200),
                                                         center: .zero))
        let hfClick = CGPoint(x: 5, y: 5)
        if let hfHit = hfRenderer.hitTest(hfClick) {
            let hfFrame = hfRenderer.hitFrame(for: hfHit)
            assert(hfFrame != nil, "heatmap hitFrame should not be nil even with tooltip off")
            assert(hfFrame?.contains(hfClick) == true,
                   "heatmap hitFrame should contain the click point, got \(String(describing: hfFrame))")
        } else {
            assertionFailure("heatmap should hit (0,0)")
        }
```

- [ ] **Step 2: 跑测试确认失败**

运行 ChartSelfTest 命令。预期：assert 失败（`hitFrame` 默认 nil → `hfFrame != nil` 不成立 → crash）—— 红。

- [ ] **Step 3: 实现 `hitFrame`**（`HeatmapChartRenderer.swift` 的 `tooltipAnchor(for:)` 方法 **之后** 追加）

```swift
    // MARK: - 命中单元 frame（独立于 tooltip 开关，供外部自定义弹窗定位）
    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let h = target as? HeatmapHitTarget,
              let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
        else { return nil }
        return hit.frame
    }
```

- [ ] **Step 4: 跑测试确认通过**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed` —— 绿。

- [ ] **Step 5: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 5: Radar — 实现 `hitFrame`（顶点 center+radius → 正方形）

**Files:**
- Modify: `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift`（`applySelection(_:)` `:527` 之后追加）
- Test: `ChartSelfTest.swift`（追加）

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾追加）

```swift
        // —— Radar hitFrame：顶点 center+radius → 正方形 frame ——
        let rdModel = RadarChartModel(dimensions: [
            RadarDimension(label: "a", value: 80),
            RadarDimension(label: "b", value: 60),
        ])
        let rdRenderer = RadarChartRenderer()
        rdRenderer.render(model: rdModel, theme: RadarChartTheme(),
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
                                                         center: CGPoint(x: 100, y: 100)))
        let rdFrame = rdRenderer.hitFrame(for: RadarHitTarget(category: .dataVertex, dimensionIndex: 0))
        assert(rdFrame != nil, "radar dataVertex hitFrame should not be nil")
        if let rf = rdFrame {
            assert(rf.width > 0 && abs(rf.width - rf.height) < 0.001,
                   "radar hitFrame should be a non-zero square, got \(rf)")
        }
        // 不存在的维度 → nil
        assert(rdRenderer.hitFrame(for: RadarHitTarget(category: .dataVertex, dimensionIndex: 99)) == nil,
               "radar hitFrame for missing dimension should be nil")
```

- [ ] **Step 2: 跑测试确认失败**

运行 ChartSelfTest 命令。预期：assert 失败（`hitFrame` 默认 nil → `rdFrame != nil` 不成立）—— 红。

- [ ] **Step 3: 实现 `hitFrame`**（`RadarChartRenderer.swift` 的 `applySelection(_:)` 方法 **之后** 追加）

```swift
    // MARK: - 命中单元 frame（供外部自定义弹窗定位）
    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let r = target as? RadarHitTarget,
              let rec = hitRecords.first(where: { $0.category == r.category
                                          && $0.dimensionIndex == r.dimensionIndex })
        else { return nil }
        let rad = rec.radius
        return CGRect(x: rec.center.x - rad, y: rec.center.y - rad, width: rad * 2, height: rad * 2)
    }
```

- [ ] **Step 4: 跑测试确认通过**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed` —— 绿。

- [ ] **Step 5: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 6: OC Bridge — 热力图 `onHitLocated` block

> 说明：bridge 翻译涉及运行时闭包触发，由 Task 10 OC demo 端到端验证；本 Task 验证 = 编译通过。

**Files:**
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapChartViewBridge.swift`（现有 `onHit` `:12` 之后追加）

- [ ] **Step 1: 加 `onHitLocated` block 属性**（在 `:12` 的 `@objc public var onHit: ...` **之后**追加）

```swift
    /// OC 端带位置的命中回调：(row, column, frame, location)。设置后内置 tooltip 自动不显示。
    @objc public var onHitLocated: ((NSInteger, NSInteger, CGRect, CGPoint) -> Void)? {
        didSet {
            chart.onHitLocated = onHitLocated != nil ? { [weak self] context, _ in
                guard let self, let h = context.target as? HeatmapHitTarget else { return }
                self.onHitLocated?(h.row, h.column, context.frame, context.location)
            } : nil
        }
    }
```

> 现有 `chart.onHit`（`:19-23`，老 `(row,column)` 翻译）保持不动；`didSet` 仅同步新的 `chart.onHitLocated`，且只在 OC 用户设了 `onHitLocated` 时才注册（→ 触发 Core 关内置 tooltip）。

- [ ] **Step 2: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 7: OC Bridge — 雷达 `onHitLocated` block

**Files:**
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift`（现有 `onHit` `:12` 之后追加）

- [ ] **Step 1: 加 `onHitLocated` block 属性**（在 `:12` 的 `@objc public var onHit: ...` **之后**追加）

```swift
    /// OC 端带位置的命中回调：(kind, dimensionIndex, frame, location)。
    @objc public var onHitLocated: ((NSString, NSInteger, CGRect, CGPoint) -> Void)? {
        didSet {
            chart.onHitLocated = onHitLocated != nil ? { [weak self] context, _ in
                guard let self, let r = context.target as? RadarHitTarget else { return }
                self.onHitLocated?(r.kind as NSString, r.dimensionIndex, context.frame, context.location)
            } : nil
        }
    }
```

- [ ] **Step 2: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 8: SwiftUI 封装 — `HeatmapChart` / `RadarChart` 加 `onHitLocated` 透传

> Swift 端经 SwiftUI 封装用图表（demo 也是 SwiftUI）。Core `onHitLocated` 已就绪（Task 3），封装只做一层透传。现有封装已透传 `onHit`（`HeatmapChart.swift:48/61`、`RadarChart.swift:37/49`），本任务同构加 `onHitLocated`。

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChart.swift`
- Modify: `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift`

- [ ] **Step 1: `HeatmapChart` 加 `onHitLocated`**

(a) `HeatmapChart` 结构体属性区（`:10` `onHit` 之后）加：
```swift
    /// 命中后带位置信息的回调（自定义弹窗用）。设置后内置 tooltip 自动不显示。
    private let onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?
```
(b) `init`（`:12-28`）参数末尾（`onHit:` 之后）加，并在 init 体赋值：
```swift
                onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)? = nil) {
```
init 体（`self.onHit = onHit` 之后）加：
```swift
        self.onHitLocated = onHitLocated
```
(c) `body`（`:30-34`）透传：
```swift
    public var body: some View {
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear,
                                  tooltipTheme: tooltipTheme,
                                  onHit: onHit, onHitLocated: onHitLocated)
    }
```
(d) `HeatmapChartRepresentable`（`:37-66`）：加属性 `let onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?`；`makeUIView`（`:51` configure 前）与 `updateUIView`（`:64` configure 前）各加一行：
```swift
        chart.onHitLocated = onHitLocated
```

- [ ] **Step 2: `RadarChart` 同构加 `onHitLocated`**

对 `RadarChart.swift` 做与 Step 1 完全同构的改动：
- `RadarChart` 属性区（`:9` 之后）加 `onHitLocated` 属性；
- `init`（`:11-19`）参数末尾加 `onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)? = nil` + init 体赋值；
- `body`（`:21-25`）透传 `onHitLocated`；
- `RadarChartRepresentable`（`:28-54`）加属性；`makeUIView`（`:40` configure 前）、`updateUIView`（`:52` configure 前）各加 `chart.onHitLocated = onHitLocated`。

- [ ] **Step 3: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 9: Swift Demo — 热力图 `onHitLocated` 自定义弹窗（SwiftUI）

> `HeatmapChartDemo` 是 SwiftUI View（`HeatmapChartDemo.swift:5-47`），用 `HeatmapChart(model:) { onHit }`。自定义弹窗用 `@State` + `overlay`。`HeatmapChart` 现有两个尾随闭包（`onHit` + `onHitLocated`，Task 8 加的）。

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChartDemo.swift`

- [ ] **Step 1: demo 加 `@State` 命中信息 + `onHitLocated` + overlay 自定义弹窗**

(a) 结构体开头（`:5` `struct HeatmapChartDemo: View {` 之后）加：
```swift
    @State private var hitInfo: (row: Int, column: Int, frame: CGRect)?
```
(b) 把 `body`（`:28-46`）里的 `HeatmapChart(model:) {...}` 段替换为下面这段（含 `onHitLocated` 第二尾随闭包 + overlay）。其余 `ScrollView/VStack/Text/navigationTitle` 保持原样：

```swift
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column)) tip=\(target.tooltipText ?? "nil")")
                } onHitLocated: { context, _ in
                    if let h = context.target as? HeatmapHitTarget {
                        hitInfo = (h.row, h.column, context.frame)
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
                .overlay(alignment: .topLeading) {
                    if let info = hitInfo {
                        Text("(\(info.row),\(info.column))")
                            .font(.system(size: 12))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            // frame 在 chartView 坐标系；demo 用近似 offset 演示定位（贴格子上方）
                            .offset(x: info.frame.midX - 30,
                                    y: max(0, info.frame.minY - 28))
                            .transition(.opacity)
                    }
                }
```

- [ ] **Step 2: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 3: 模拟器手动验证**

install/launch 后进热力图 demo，点击格子：
- 预期：出现蓝色 `(<row>,<col>)` 浮层，贴在格子附近；**内置 tooltip 不再显示**（互斥生效）。
- 截图：`xcrun simctl io "$UDID" screenshot /tmp/heatmap_onHitLocated.png`

---

## Task 10: OC Demo — bridge `onHitLocated` 自定义弹窗示例

> 现状：`OCChartDemoViewController.m` 的 `setupHeatmap`（`:90-125`）创建 `self.heatmapBridge`（`:101`）、`self.heatmapBridge.onHit = ^...(row,column)`（`:112-114`）。UIKit 风格，`bridge.chartView` 是 UIView。

**Files:**
- Modify: `SwiftFunctionProject/OCDemo/OCChartDemoViewController.m`（`setupHeatmap` 内、`:114` `onHit` block 之后追加）

- [ ] **Step 1: 在 `self.heatmapBridge.onHit = ^...;` 之后追加 OC 自定义弹窗**

```objc
    __weak __typeof(self) weakSelf = self;
    self.heatmapBridge.onHitLocated = ^(NSInteger row, NSInteger column, CGRect frame, CGPoint location) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // 把 frame 从 chartView 坐标系转到 self.view 坐标系
        UIView *chartView = strongSelf.heatmapBridge.chartView;
        CGRect frameInView = [chartView convertRect:frame toView:strongSelf.view];

        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(frameInView.origin.x,
                                                                  frameInView.origin.y - 28,
                                                                  frameInView.size.width, 24)];
        tip.backgroundColor = [UIColor systemBlueColor];
        tip.textColor = [UIColor whiteColor];
        tip.font = [UIFont systemFontOfSize:12];
        tip.textAlignment = NSTextAlignmentCenter;
        tip.text = [NSString stringWithFormat:@"(%ld,%ld)", (long)row, (long)column];
        tip.layer.cornerRadius = 6;
        tip.layer.masksToBounds = YES;
        tip.tag = 9527;
        [[strongSelf.view viewWithTag:9527] removeFromSuperview];
        [strongSelf.view addSubview:tip];
        NSLog(@"[OC] onHitLocated row=%ld col=%ld frame=%@ location=%@",
              (long)row, (long)column, NSStringFromCGRect(frame), NSStringFromCGPoint(location));
    };
```

- [ ] **Step 2: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 3: 模拟器手动验证（OC demo 页）**

跑 OC demo（App 内 `OCChartDemoViewController`），点击热力图格子：
- 预期：出现蓝色 `(<row>,<col>)` 浮层（坐标已转换，位置正确）；内置 tooltip 不显示；log 打印 `[OC] onHitLocated ...`。

---

## Task 11: 最终验证（编译 + ChartSelfTest + 模拟器 + leaks）

- [ ] **Step 1: 全量编译**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 2: ChartSelfTest 全绿**

运行 ChartSelfTest 运行命令。预期：`✅ ChartSelfTest passed`（含本计划新增的 hitFrame / HitContext 断言）。

- [ ] **Step 3: 模拟器跑通两个 demo**

- Swift 热力图 demo（Task 9）：点击格子，自定义蓝色浮层出现、内置 tooltip 消失。
- OC 热力图 demo（Task 10）：点击格子，OC 浮层出现、log 打印 `[OC] onHitLocated ...`。

- [ ] **Step 4: 内存 leaks 检查**

```bash
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
PID=$(xcrun simctl spawn "$UDID" launchctl list | grep SwiftFunctionProject | awk '{print $1}')
xcrun simctl spawn "$UDID" leaks "$PID" 2>&1 | tail -15
```
预期：`leaks` 报告无新增泄漏（尤其 bridge / SwiftUI 封装的 `[weak self]` 闭包未造成循环引用）。

- [ ] **Step 5: 回归雷达图（确认未破坏）**

跑雷达图 demo，点击顶点：原有命中高亮、老 `onHit` 正常。本计划未给雷达加 Swift/OC 弹窗示例（雷达 `onHitLocated` 能力已由 Core + 封装 + bridge 提供，留给后续按需接）。

---

## Self-Review 结论

**Spec 覆盖**（对照 `2026-07-31-chart-hit-location-callback-design.md`）：
- §8.1 `HYMChartHitContext` → Task 1 ✅
- §8.2 `hitFrame` 协议 → Task 2 ✅
- §8.3 `HYMChartView.onHitLocated` + 互斥 → Task 3 ✅
- §8.4 热力图 `hitFrame` → Task 4 ✅
- §8.5 雷达 `hitFrame` → Task 5 ✅
- §8.6 热力图 OC bridge → Task 6 ✅
- §8.7 雷达 OC bridge → Task 7 ✅
- §10 SwiftUI 封装透传 → Task 8 ✅（spec §10 原写"可选"，执行时发现 Swift demo 依赖它，已转为必做）
- §8.8 Swift demo → Task 9 ✅；OC demo → Task 10 ✅
- §11 测试（hitFrame 派发 / 热力图 / 雷达 / 互斥 / bridge）→ Task 1/2/4/5（ChartSelfTest）+ Task 9/10/11（demo + leaks）✅

**类型一致性**：`hitFrame(for target: HYMChartHitTarget) -> CGRect?` 在协议（Task 2）、热力图（Task 4）、雷达（Task 5）签名一致；`HYMChartHitContext(target:frame:location:)` 在定义（Task 1）与调用（Task 3）一致；SwiftUI 封装 `onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?` 在 `HeatmapChart`/`RadarChart`（Task 8）一致；OC block `(NSInteger, NSInteger, CGRect, CGPoint)`（热力图 Task 6）与 `(NSString, NSInteger, CGRect, CGPoint)`（雷达 Task 7）各自与现有 `onHit` 签名前缀一致。

**占位符扫描**：无 TBD/TODO；每步含完整代码或确切命令；Task 8/9/10 已基于实际读过的 demo 文件结构编写（SwiftUI demo 用 `@State`+overlay，OC demo 用 UIKit `convertRect:toView:`）。
