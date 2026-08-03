# 图表自定义弹窗内容 view（SDK 接管定位）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 HYMCharts 加一个「便利层」弹窗机制 `popupContentProvider`——外部只提供内容 view，SDK 套统一外壳 + 智能定位 + 显隐动画；与现有 `onHitLocated`（外部全权）/ 内置 text tooltip 形成三层 fallback。

**Architecture:** Core `HYMChartTooltip` 加 contentView 模式（复用外壳）+ `HYMChartTooltipController.show(contentView:)` + `HYMChartView.popupContentProvider` + `onTap` 三层分支；SwiftUI 封装加 `popup` 闭包（`UIHostingController` 转 UIView）；两个 OC bridge 加 `popupContentProvider` block。

**Tech Stack:** Swift 5 / UIKit / SwiftUI / iOS 26.4 / Xcode26_3（objectVersion 77 同步组，整树自动编译，无需改 pbxproj）。

---

## 项目约定（执行前必读）

1. **不主动 commit**：本项目约定改动堆工作区、用编译/运行验证，**用户明确要求时才 commit**。因此本计划每个 Task 末尾用「编译验证」作为检查点，**没有 git commit 步骤**；如用户中途要求提交，再单独执行。
2. **验证权威**：SourceKit 常有假阳性（`No such module 'UIKit'` / 跨文件 `Cannot find type`），**一律以 `xcodebuild` 的 `** BUILD SUCCEEDED **` 为唯一权威**，不要为假阳性改代码。
3. **测试模式**：纯逻辑用 `ChartSelfTest.runAll()`（`SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`，DEBUG 启动时跑 `assert`）。绿 = 控制台 `✅ ChartSelfTest passed`；红 = 启动 app 时 assert 触发 crash。运行时行为（手势/弹窗/OC block）用 demo + 模拟器验证。
4. **模拟器**：iPhone 17 Pro UDID `FB74ECC0-DDCA-4168-A93D-81B91C56432C`（iOS 26.4.1，Xcode26_3 可用；**注意 Xcode26_3 无 iOS 26.0 runtime**，`simctl list` 显示的 booted 机可能是 26.0 的 `2388CCC4`，xcodebuild destination 必须用 `FB74ECC0`）。bundle id `hm-test-widget.SwiftFunctionProject`，scheme `SwiftFunctionProject`。

### 通用编译验证命令

```bash
xcodebuild -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' \
  build 2>&1 | grep -iE "BUILD (SUCCEEDED|FAILED)|error:" | head -20
```
预期末尾：`** BUILD SUCCEEDED **`

### 通用 ChartSelfTest 运行命令（跑红/绿）

```bash
UDID=FB74ECC0-DDCA-4168-A93D-81B91C56432C
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/SwiftFunctionProject-* -name 'SwiftFunctionProject.app' -path '*Debug-iphonesimulator*' 2>/dev/null | head -1)
xcodebuild -scheme SwiftFunctionProject -destination "platform=iOS Simulator,id=$UDID" build > /tmp/build.log 2>&1
grep -q "BUILD SUCCEEDED" /tmp/build.log || { echo "❌ build failed"; grep -iE "error:" /tmp/build.log | head; exit 0; }
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" hm-test-widget.SwiftFunctionProject 2>/dev/null; sleep 1
xcrun simctl launch --console-pty "$UDID" hm-test-widget.SwiftFunctionProject > /tmp/app.log 2>&1 &
BGPID=$!; sleep 4; kill $BGPID 2>/dev/null; wait $BGPID 2>/dev/null
grep -inE "ChartSelfTest passed|assertion failed|fatal" /tmp/app.log | head
```
- 绿预期：`✅ ChartSelfTest passed`
- 红预期：app 启动即闪退 / log 含 `assertion failed` / 缺少 `✅ ChartSelfTest passed`。

> 注：`print()` 不进 unified log，必须用 `--console-pty` 后台捕获 stdout；macOS zsh 无 `timeout`，用 `&` + `kill`。

---

## File Structure

| 文件 | 改动 | 职责 |
|---|---|---|
| `SwiftFunctionProject/Charts/Core/HYMChartTooltip.swift` | 加 contentView 模式（`configure(contentView:)` + `sizeThatFits`/`layoutSubviews` 分模式） | 通用：外壳复用 + 内容 view 模式 |
| `SwiftFunctionProject/Charts/Core/HYMChartTooltipController.swift` | 加 `show(anchor:contentView:in:preferred:)` | 通用：内容 view 显示 |
| `SwiftFunctionProject/Charts/Core/HYMChartView.swift` | 加 `popupContentProvider` + 重构 `onTap` 三层分支 | 通用：内容 view 提供者 + 分发 |
| `SwiftFunctionProject/Charts/SwiftUI/HeatmapChart.swift` | 加 `popup` 闭包 + Representable hosting | SwiftUI：popup 透传 |
| `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift` | 加 `popup` 闭包 + Representable hosting | SwiftUI：popup 透传 |
| `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapChartViewBridge.swift` | 加 `popupContentProvider` block | OC：翻译 |
| `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift` | 加 `popupContentProvider` block | OC：翻译 |
| `SwiftFunctionProject/Charts/SwiftUI/HeatmapChartDemo.swift` | 改用 `popup` 模式（保留 onHitLocated 对比） | Swift demo |
| `SwiftFunctionProject/OCDemo/OCChartDemoViewController.m` | 加 `popupContentProvider` 示例 | OC demo |
| `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift` | 加 contentView 模式 / show(contentView:) 断言 | 自测 |

---

## Task 1: Core — `HYMChartTooltip` 加 contentView 模式

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartTooltip.swift`
- Test: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾、`print("✅ ChartSelfTest passed")` 之前追加）

```swift
        // —— HYMChartTooltip contentView 模式（外壳复用，内容 view 尺寸驱动）——
        let tipLabel = UILabel()
        tipLabel.text = "内容"
        tipLabel.font = .systemFont(ofSize: 16)
        let expWidth = tipLabel.sizeThatFits(CGSize(width: 200, height: .greatestFiniteMagnitude))
        let tipView = HYMChartTooltip()
        var tipTheme = HYMChartTooltipTheme()
        tipTheme.contentInset = .zero
        tipTheme.showsArrow = false
        tipView.configure(contentView: tipLabel, theme: tipTheme)
        let tipSize = tipView.sizeThatFits(CGSize(width: 200, height: 200))
        assert(abs(tipSize.width - expWidth.width) < 0.001 && abs(tipSize.height - expWidth.height) < 0.001,
               "contentView mode sizeThatFits should equal contentView size (inset 0, no arrow), got \(tipSize) vs \(expWidth)")
```

- [ ] **Step 2: 跑测试确认失败**

运行「通用 ChartSelfTest 运行命令」。预期：编译失败（`cannot find 'configure(contentView:theme:)'`）—— 红。

- [ ] **Step 3: 实现 contentView 模式**

(a) 在 `HYMChartTooltip` 私有属性区（`private var lastText: String = ""` 之后）追加：

```swift
    private var contentView: UIView?
```

(b) 在现有 `configure(text:theme:)` 方法**之后**追加新方法：

```swift
    /// 设置自定义内容 view 与外观（contentView 模式）。外壳(背景/圆角/阴影/箭头)复用，
    /// 内容区装外部 view（替代 textLabel）。与 configure(text:) 互斥使用（由调用方保证不同时）。
    public func configure(contentView: UIView, theme: HYMChartTooltipTheme) {
        self.theme = theme
        textLabel.removeFromSuperview()
        self.contentView?.removeFromSuperview()
        self.contentView = contentView
        addSubview(contentView)

        backgroundLayer.backgroundColor = theme.backgroundColor.cgColor
        backgroundLayer.cornerRadius = theme.cornerRadius
        if let sc = theme.shadowColor {
            backgroundLayer.shadowColor = sc.cgColor
            backgroundLayer.shadowOpacity = 1
            backgroundLayer.shadowOffset = CGSize(width: 0, height: 1)
            backgroundLayer.shadowRadius = 3
        } else {
            backgroundLayer.shadowOpacity = 0
        }
        arrowLayer.isHidden = !theme.showsArrow
        arrowLayer.fillColor = theme.backgroundColor.cgColor
    }
```

(c) 替换 `sizeThatFits(_:)` 整个方法为分模式版本：

```swift
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inset = theme.contentInset
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        if let cv = contentView {
            let maxW = max(0, theme.maxWidth - inset.left - inset.right)
            let s = cv.sizeThatFits(CGSize(width: maxW, height: .greatestFiniteMagnitude))
            return CGSize(width: s.width + inset.left + inset.right,
                          height: s.height + inset.top + inset.bottom + arrowH)
        }
        // text 模式（原有逻辑）
        let maxTextWidth = max(0, theme.maxWidth - inset.left - inset.right)
        let textBounds = (lastText as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: theme.font],
            context: nil)
        let textH = ceil(textBounds.height)
        let w = ceil(textBounds.width + inset.left + inset.right)
        let h = textH + inset.top + inset.bottom + arrowH
        return CGSize(width: max(w, inset.left + inset.right), height: h)
    }
```

(d) 替换 `layoutSubviews()` 中布局 textLabel 的部分——把：

```swift
        var labelFrame = bounds.inset(by: inset)
        if theme.showsArrow {
            // .top（弹窗在锚点上方，箭头在底部）→ 文字区上移让出底部箭头；
            // .bottom（弹窗在锚点下方，箭头在顶部）→ 文字区下移让出顶部箭头。
            labelFrame.size.height -= arrowH
            if placement == .bottom { labelFrame.origin.y += arrowH }
        }
        textLabel.frame = labelFrame
        rebuildArrow()
```

改为分模式：

```swift
        var contentFrame = bounds.inset(by: inset)
        if theme.showsArrow {
            // .top（弹窗在锚点上方，箭头在底部）→ 内容区上移让出底部箭头；
            // .bottom（弹窗在锚点下方，箭头在顶部）→ 内容区下移让出顶部箭头。
            contentFrame.size.height -= arrowH
            if placement == .bottom { contentFrame.origin.y += arrowH }
        }
        if let cv = contentView {
            cv.frame = contentFrame
        } else {
            textLabel.frame = contentFrame
        }
        rebuildArrow()
```

- [ ] **Step 4: 跑测试确认通过**

运行「通用 ChartSelfTest 运行命令」。预期：`✅ ChartSelfTest passed` —— 绿。

- [ ] **Step 5: 编译验证**

运行「通用编译验证命令」。预期：`** BUILD SUCCEEDED **`。

---

## Task 2: Core — `HYMChartTooltipController.show(contentView:)`

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartTooltipController.swift`
- Test: `ChartSelfTest.swift`

- [ ] **Step 1: 写失败测试**（ChartSelfTest 末尾追加）

```swift
        // —— HYMChartTooltipController.show(contentView:) 不崩 ——
        let ctrlHost = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let ctrl = HYMChartTooltipController(host: ctrlHost)
        let popLabel = UILabel()
        popLabel.text = "弹窗内容"
        popLabel.font = .systemFont(ofSize: 14)
        ctrl.show(anchor: CGRect(x: 90, y: 100, width: 20, height: 20),
                  contentView: popLabel,
                  in: ctrlHost.bounds,
                  preferred: [.top, .bottom])   // 不崩即通过
```

- [ ] **Step 2: 跑测试确认失败**

运行 ChartSelfTest 命令。预期：编译失败（`cannot find 'show(anchor:contentView:in:preferred:)'`）—— 红。

- [ ] **Step 3: 实现 `show(contentView:)`**

在 `HYMChartTooltipController` 现有 `show(anchor:text:in:preferred:)` 方法**之后**追加：

```swift
    /// 显示「自定义内容 view」弹窗（contentView 模式）。
    /// 复用 HYMChartTooltipGeometry 定位与 show/hide 动画；外壳由 HYMChartTooltip 提供。
    public func show(anchor: CGRect, contentView: UIView,
                     in container: CGRect,
                     preferred: [HYMChartTooltipPlacement]) {
        guard let host = host else { return }
        tooltip.configure(contentView: contentView, theme: theme)
        let size = tooltip.sizeThatFits(CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude))
        guard let r = HYMChartTooltipGeometry.resolve(
            anchor: anchor, size: size, container: container,
            preferred: preferred, gap: theme.gap) else {
            tooltip.isHidden = true
            return
        }
        host.bringSubviewToFront(tooltip)
        tooltip.frame = r.frame
        tooltip.applyArrow(placement: r.placement, arrowX: r.arrowX)
        tooltip.layoutIfNeeded()

        if theme.showsAnimation {
            tooltip.alpha = 0
            tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            tooltip.isHidden = false
            UIView.animate(withDuration: 0.18, delay: 0, options: []) {
                self.tooltip.alpha = 1
                self.tooltip.transform = .identity
            }
        } else {
            tooltip.alpha = 1
            tooltip.transform = .identity
            tooltip.isHidden = false
        }
    }
```

- [ ] **Step 4: 跑测试确认通过**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed` —— 绿。

- [ ] **Step 5: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 3: Core — `HYMChartView.popupContentProvider` + `onTap` 三层分支

> 说明：`onTap` 三层 fallback 依赖 UIView 手势（私有），ChartSelfTest 不便覆盖。本 Task 验证 = 编译通过 + ChartSelfTest 回归；端到端由 Task 6/7 demo 验证。

**Files:**
- Modify: `SwiftFunctionProject/Charts/Core/HYMChartView.swift`

- [ ] **Step 1: 加属性**（在 `onHitLocated` 声明**之后**追加）

```swift
    /// 命中弹窗的「内容 view」提供者（外部自定义弹窗的便利模式）。
    ///
    /// 设了它：SDK 命中时调用获取内容 view，套统一外壳(背景/圆角/箭头)，
    /// 用 `HYMChartTooltipGeometry` 智能定位(边界避让) + 显隐动画显示；未命中自动隐藏。
    /// 设了它 → 跳过 `onHitLocated` 与内置 text tooltip（三层 fallback 最高优先级）。
    /// 内容 view 应能报告尺寸(`intrinsicContentSize` 或 `sizeThatFits(_:)`)。
    public var popupContentProvider: ((HYMChartHitContext) -> UIView?)?
```

- [ ] **Step 2: 重构 `onTap`** —— 把整个 `onTap(_:)` 方法替换为三层分支版：

```swift
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        let target = renderer.hitTest(p)
        renderer.applySelection(target)

        if let target {
            onHit?(target, .tap)                       // 始终：命中事件通知

            let ctx = HYMChartHitContext(
                target: target,
                frame: renderer.hitFrame(for: target) ?? .zero,
                location: p)

            if popupContentProvider != nil {           // ① popup 模式（最高优先）
                if let cv = popupContentProvider?(ctx),
                   let anchor = renderer.tooltipAnchor(for: target) {
                    ensureTooltipController().show(anchor: anchor.frame, contentView: cv,
                                                  in: bounds, preferred: anchor.preferredPlacements)
                } else {
                    tooltipController?.hide()
                }
            } else if onHitLocated != nil {            // ② onHitLocated 外部全权
                onHitLocated?(ctx, .tap)
                tooltipController?.hide()
            } else {                                   // ③ 内置 text tooltip
                updateTooltip(for: target)
            }
        } else {
            // 未命中：按激活模式镜像处理（popup 模式不触发 onHitLocated，与命中分支对称）
            tooltipController?.hide()
            if popupContentProvider == nil, onHitLocated != nil {
                onHitLocated?(nil, .tap)
            }
        }
    }
```

- [ ] **Step 3: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 4: 回归 ChartSelfTest**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed`（确保未破坏既有逻辑）。

---

## Task 4: SwiftUI 封装 — `HeatmapChart`/`RadarChart` 加 `popup` 闭包

> Swift 端经 SwiftUI 封装用图表。Core `popupContentProvider` 已就绪（Task 3），封装加一层 `popup` 闭包 + `UIHostingController` 转 UIView。

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChart.swift`
- Modify: `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift`

- [ ] **Step 1: `HeatmapChart` 加 `popup`**

(a) `HeatmapChart` 结构体属性区（`onHitLocated` 之后）加：

```swift
    /// 命中弹窗内容（SwiftUI View）。SDK 套外壳 + 智能定位 + 显隐；设了它跳过 onHitLocated 与内置 tooltip。
    private let popup: ((HYMChartHitContext) -> AnyView)?
```

(b) `init` 参数末尾（`onHitLocated:` 之后）加，并在 init 体赋值：

```swift
                popup: ((HYMChartHitContext) -> AnyView)? = nil) {
```

init 体（`self.onHitLocated = onHitLocated` 之后）加：

```swift
        self.popup = popup
```

(c) `body` 透传——把：

```swift
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear,
                                  tooltipTheme: tooltipTheme,
                                  onHit: onHit, onHitLocated: onHitLocated)
```

改为：

```swift
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear,
                                  tooltipTheme: tooltipTheme,
                                  onHit: onHit, onHitLocated: onHitLocated, popup: popup)
```

(d) `HeatmapChartRepresentable`：属性区（`onHitLocated` 之后）加：

```swift
    let popup: ((HYMChartHitContext) -> AnyView)?
```

`makeUIView`（`chart.onHitLocated = onHitLocated` 之后）与 `updateUIView`（`uiView.onHitLocated = onHitLocated` 之后）各加：

```swift
        chart.popupContentProvider = popup != nil ? { context in
            guard let popup else { return nil }
            let host = UIHostingController(rootView: popup(context))
            host.view.backgroundColor = .clear
            return host.view
        } : nil
```

- [ ] **Step 2: `RadarChart` 同构加 `popup`**

对 `RadarChart.swift` 做与 Step 1 完全同构的改动：
- `RadarChart` 属性区（`onHitLocated` 之后）加 `popup` 属性；
- `init`（参数末尾加 `popup: ((HYMChartHitContext) -> AnyView)? = nil` + init 体 `self.popup = popup`）；
- `body` 透传 `popup`（加到 `RadarChartRepresentable(...)` 调用）；
- `RadarChartRepresentable` 加 `popup` 属性；`makeUIView`（`chart.onHitLocated = onHitLocated` 之后）、`updateUIView`（`uiView.onHitLocated = onHitLocated` 之后）各加同一段 `chart.popupContentProvider = ...`（与 Step 1d 完全相同）。

- [ ] **Step 3: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

> 注：`UIHostingController` 的尺寸获取在 Task 6 demo 视觉验证。若 demo 中 popup 定位失准（尺寸为 0），改用 `host.sizeThatFits(in:)` 或显式 `host.view.invalidateIntrinsicContentSize()`；本 Task 先以 `host.view` 默认行为实现。

---

## Task 5: OC Bridge — 热力图 / 雷达 `popupContentProvider` block

> bridge 翻译涉及运行时闭包触发，由 Task 7 OC demo 端到端验证；本 Task 验证 = 编译通过。

**Files:**
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMHeatmapChartViewBridge.swift`
- Modify: `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift`

- [ ] **Step 1: 热力图 bridge 加 `popupContentProvider`**

在 `HYMHeatmapChartViewBridge` 现有 `onHitLocated` 属性**之后**追加：

```swift
    /// OC 端弹窗内容提供者：(row, column) → 内容 UIView。SDK 套外壳 + 智能定位 + 显隐。
    /// 设了它 → 跳过内置 text tooltip（与 onHitLocated 互斥，popupContentProvider 优先）。
    @objc public var popupContentProvider: ((NSInteger, NSInteger) -> UIView?)? {
        didSet {
            chart.popupContentProvider = popupContentProvider != nil ? { [weak self] context in
                guard let self, let h = context.target as? HeatmapHitTarget else { return nil }
                return self.popupContentProvider?(h.row, h.column)
            } : nil
        }
    }
```

- [ ] **Step 2: 雷达 bridge 加 `popupContentProvider`**

在 `HYMRadarChartViewBridge` 现有 `onHitLocated` 属性**之后**追加：

```swift
    /// OC 端弹窗内容提供者：(kind, dimensionIndex) → 内容 UIView。SDK 套外壳 + 智能定位 + 显隐。
    @objc public var popupContentProvider: ((NSString, NSInteger) -> UIView?)? {
        didSet {
            chart.popupContentProvider = popupContentProvider != nil ? { [weak self] context in
                guard let self, let r = context.target as? RadarHitTarget else { return nil }
                return self.popupContentProvider?(r.kind as NSString, r.dimensionIndex)
            } : nil
        }
    }
```

- [ ] **Step 3: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

---

## Task 6: Swift Demo — `HeatmapChartDemo` 改 `popup` 模式

> `HeatmapChartDemo` 是 SwiftUI View。改用 `popup:` 闭包给内容 view（SDK 接管定位/显隐），保留一段 `onHit` 日志，直观对比新模式比手写 overlay 省多少代码。

**Files:**
- Modify: `SwiftFunctionProject/Charts/SwiftUI/HeatmapChartDemo.swift`

- [ ] **Step 1: 替换 demo 的弹窗实现**

把现有 `body` 里这段（含 `onHitLocated` + overlay）：

```swift
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column)) tip=\(target.tooltipText ?? "nil")")
                } onHitLocated: { context, _ in
                    if let context, let h = context.target as? HeatmapHitTarget {
                        hitInfo = (h.row, h.column, context.frame)
                    } else {
                        hitInfo = nil   // 未命中 → 隐藏自定义弹窗
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

替换为（用 `popup:` 闭包，SDK 接管）：

```swift
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column)) tip=\(target.tooltipText ?? "nil")")
                } popup: { context in
                    if let h = context.target as? HeatmapHitTarget {
                        AnyView(
                            VStack(spacing: 2) {
                                Text("(\(h.row),\(h.column))")
                                    .font(.system(size: 13, weight: .semibold))
                                if let tip = h.tooltipText { Text(tip).font(.system(size: 11)) }
                            }
                            .foregroundStyle(.white)
                        )
                    } else {
                        AnyView(EmptyView())
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
```

- [ ] **Step 2: 移除不再使用的 `@State hitInfo`**

把结构体开头的：

```swift
    @State private var hitInfo: (row: Int, column: Int, frame: CGRect)?
```

整行删除（popup 模式不再需要手动状态）。

- [ ] **Step 3: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 4: 模拟器手动验证**

install/launch 后进热力图 demo，点击格子：
- 预期：出现 SDK 外壳包裹的内容弹窗（`(<row>,<col>)` + tooltip 文本），位置自动避让；**内置 tooltip 不显示**。
- 点空白：弹窗消失。
- 截图：`xcrun simctl io FB74ECC0-DDCA-4168-A93D-81B91C56432C screenshot /tmp/heatmap_popup.png`

> 若 popup 不显示或尺寸异常（UIHostingController 尺寸问题）：在 `HeatmapChartRepresentable` 的 hosting 闭包里，把 `return host.view` 前加 `host.view.invalidateIntrinsicContentSize()`，或改用 `host.sizeThatFits(in: CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude))` 预先 sizing。验证后回填 Task 4 的 hosting 实现。

---

## Task 7: OC Demo — bridge `popupContentProvider` 自定义弹窗示例

> 现状：`OCChartDemoViewController.m` 的 `setupHeatmap` 已有 `onHit` + `onHitLocated`。本 Task 在其后加一段 `popupContentProvider` 示例。但 `popupContentProvider` 与 `onHitLocated` 互斥（popup 优先）——为同时展示两种模式，OC demo 用 popupContentProvider（新模式），onHitLocated 保留作对比（被 popup 覆盖，实际不显示其浮层，但 log 仍可加）。

**Files:**
- Modify: `SwiftFunctionProject/OCDemo/OCChartDemoViewController.m`

- [ ] **Step 1: 在 `self.heatmapBridge.onHitLocated = ...;` 之后追加 popup 示例**

在现有 `onHitLocated` block **之后**追加（popup 优先，接管显示）：

```objc
    // popupContentProvider：新模式——OC 只返回内容 view（UILabel），SDK 套外壳 + 定位 + 显隐。
    // 设了它 → onHitLocated 的自定义浮层不再显示（popup 优先），onHit 仍触发。
    self.heatmapBridge.popupContentProvider = ^UIView *(NSInteger row, NSInteger column) {
        UILabel *content = [[UILabel alloc] init];
        content.text = [NSString stringWithFormat:@"(%ld,%ld)", (long)row, (long)column];
        content.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        content.textColor = [UIColor whiteColor];
        content.numberOfLines = 0;
        [content sizeToFit];
        return content;
    };
```

- [ ] **Step 2: 编译验证**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 3: 模拟器手动验证（OC demo 页）**

跑 OC demo（App 内 `OCChartDemoViewController`），点击热力图格子：
- 预期：出现 SDK 外壳包裹的 `(<row>,<col>)` 内容弹窗（蓝色外壳 + 白字），位置自动避让；点空白消失。
- 注：因 popupContentProvider 优先，旧 onHitLocated 的浮层不再出现（对比效果）。

---

## Task 8: 最终验证（编译 + ChartSelfTest + 模拟器 + leaks）

- [ ] **Step 1: 全量编译**

运行通用编译验证命令。预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 2: ChartSelfTest 全绿**

运行 ChartSelfTest 命令。预期：`✅ ChartSelfTest passed`（含本计划新增 contentView / show(contentView:) 断言）。

- [ ] **Step 3: 模拟器跑通两个 demo**

- Swift 热力图 demo（Task 6）：点击格子，SDK 外壳弹窗出现、位置避让；点空白消失。
- OC 热力图 demo（Task 7）：点击格子，OC 内容弹窗（外壳包裹）出现；点空白消失。

- [ ] **Step 4: 内存 leaks 检查**

```bash
UDID=FB74ECC0-DDCA-4168-A93D-81B91C56432C
xcrun simctl launch "$UDID" hm-test-widget.SwiftFunctionProject >/dev/null 2>&1
sleep 2
PID=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep SwiftFunctionProject | awk '{print $1}')
xcrun simctl spawn "$UDID" leaks "$PID" 2>&1 | tail -5
```
预期：`0 leaks for 0 total leaked bytes`（bridge/SwiftUI 封装的 `[weak self]` 闭包未造成循环引用）。

- [ ] **Step 5: 回归 onHitLocated / 内置 tooltip（确认未破坏）**

- 跑雷达图 demo（未设 popupContentProvider）→ 点击顶点 → 原有命中高亮 + 老 `onHit` 正常（走 ② onHitLocated 或 ③ 内置，未受影响）。
- 确认三层 fallback：未设 popup 的图表行为不变。

---

## Self-Review 结论

**Spec 覆盖**（对照 `2026-08-03-chart-popup-content-provider-design.md`）：
- §4.2 `HYMChartTooltip` contentView 模式 → Task 1 ✅
- §4.3 `HYMChartTooltipController.show(contentView:)` → Task 2 ✅
- §4.1 `HYMChartView.popupContentProvider` + §4.5 `onTap` 三层分支 → Task 3 ✅
- §5.1 SwiftUI `popup` 闭包 + hosting → Task 4 ✅（hosting 尺寸风险在 Task 6 验证 + 回填）
- §5.2 OC bridge `popupContentProvider` block（热力图/雷达）→ Task 5 ✅
- §6 demo（Swift/OC）→ Task 6/7 ✅
- §7 兼容性（onHitLocated 保留、三层 fallback）→ Task 8 Step 5 回归 ✅
- §8 测试（contentView / show(contentView:) / demo / leaks）→ Task 1/2（ChartSelfTest）+ Task 6/7/8（demo + leaks）✅

**类型一致性**：`popupContentProvider: ((HYMChartHitContext) -> UIView?)?` 在 `HYMChartView`（Task 3）、两个 SwiftUI 封装（Task 4，经 hosting）、两个 OC bridge（Task 5，经 didSet 翻译）签名一致；`show(anchor:contentView:in:preferred:)`（Task 2）与 `onTap` 调用（Task 3）一致；`configure(contentView:theme:)`（Task 1）与 Controller 调用（Task 2）一致；`popup: ((HYMChartHitContext) -> AnyView)?` 在 `HeatmapChart`/`RadarChart`（Task 4）一致。

**占位符扫描**：无 TBD/TODO；每步含完整代码或确切命令；Task 4/6 的 UIHostingController 尺寸风险已给出具体回填方案（`invalidateIntrinsicContentSize` / `host.sizeThatFits(in:)`），非占位符。

**风险标注**：§10 UIHostingController 尺寸——Task 4 先用默认 `host.view` 实现，Task 6 demo 视觉验证，失准则按回填方案调整。这是唯一实现期需观察点，已明确处理路径。
