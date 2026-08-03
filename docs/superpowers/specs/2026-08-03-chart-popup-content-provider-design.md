# 图表自定义弹窗内容 view（SDK 接管定位）设计

> **日期**: 2026-08-03
> **状态**: 设计已与用户对齐，待写实现计划
> **关联**: `2026-07-31-chart-hit-location-callback-design.md`（`onHitLocated`，本设计的低层基础）

---

## 1. 背景与动机

当前「外部自定义弹窗」机制 `onHitLocated`（2026-07-31 落地，2026-08-03 修复 optional context）是**「位置传出、外部全权控制」**：SDK 命中后把 `target/frame/location` 传给外部，外部自己造弹窗 view、转坐标系（`convertRect`）、定位、显隐、动画。

**痛点（用户反馈）**：

- 外部每次都要写坐标转换 / offset / 显隐样板 → 繁琐
- 外部手算定位，**无法复用 SDK 已有的边界避让**（`HYMChartTooltipGeometry.resolve`）→ 弹窗可能越界、不够专业
- 每个图表 demo 各写一套弹窗逻辑 → 行为不统一

**目标**：叠加一个**「便利层」**——外部只提供弹窗**内容 view**，SDK 接管**外壳（背景/圆角/箭头）+ 智能定位 + 显隐/动画**。同时**完整保留 `onHitLocated`** 给高自定义场景。

## 2. 非目标

- 不替代 `onHitLocated`（保留给「外部全权控制」）
- 不改各 renderer 的 `tooltipAnchor` / `hitFrame`（定位锚点复用现有）
- 不做 SwiftUI 原生 popup（仍走 UIKit `HYMChartView` + 封装层 hosting）

---

## 3. 总体设计：三层命中显示 fallback

一次命中，弹窗机制按优先级**互斥**选用（设了高层就用高层，低层不触发）：

```
命中 target:
  ① popupContentProvider 已设 → SDK 外壳 + 外部内容 view（本设计新增）
  ② onHitLocated 已设       → 外部全权控制（保留）
  ③ showsTooltipOnHit=true  → 内置 text tooltip（现有）
未命中 target → ① popup hide / ② onHitLocated(nil) / ③ 内置 hide
```

> **`onHit` 例外**：`onHit` 是「命中事件通知」（低层，不含弹窗控制），**始终触发**，不参与 fallback。

**互斥理由**：①②③都是「弹窗显示机制」，同时触发会导致双弹窗；故设高层则低层不触发。`onHit` 是纯事件通知（外部一般只用来打 log / 联动别的 UI），与弹窗正交，故始终触发。

---

## 4. Core 改造（UIKit 层）

### 4.1 `HYMChartView.popupContentProvider`（新增属性）

```swift
/// 命中弹窗的「内容 view」提供者。
///
/// 设了它：SDK 命中时调用获取内容 view，套上统一外壳(背景/圆角/箭头)，
/// 用 `HYMChartTooltipGeometry` 智能定位(边界避让) + 显隐动画显示；未命中自动隐藏。
/// 设了它 → 跳过 `onHitLocated` 与内置 text tooltip（三层 fallback 最高优先级）。
///
/// 内容 view 应能报告尺寸(`intrinsicContentSize` 或 `sizeThatFits(_:)`)，供 SDK 定位计算。
/// 提供者每次命中可返回新 view（推荐，状态隔离）；SDK 负责旧 view 清理。
///
/// - Parameter context: 命中上下文(target + frame + location，chartView 坐标系)
/// - Returns: 内容 view；返回 nil 则本次不显示弹窗
/// - Thread: 主线程（UI）
public var popupContentProvider: ((HYMChartHitContext) -> UIView?)?
```

### 4.2 `HYMChartTooltip` 加 contentView 模式（复用外壳，不新建视图）

现有 `HYMChartTooltip` = `backgroundLayer` + `arrowLayer` + `textLabel`（文本内容）。改造为支持两种内容模式，**外壳（`backgroundLayer`/`arrowLayer`）共享**：

- `configure(text:theme:)` —— 现有，**不变**（内置 text tooltip 继续用）
- `configure(contentView:theme:)` —— **新增**：内容区装外部 view（替代 `textLabel`）

改造点：

- 加 `private var contentView: UIView?`（可选）。`configure(contentView:)` 时移除 `textLabel`、`addSubview` 外部 view
- `sizeThatFits(_:)`：text 模式按文字算（现有）；contentView 模式按 `contentView?.sizeThatFits(限宽)` 算
- `layoutSubviews()`：text 模式布局 `textLabel`（现有）；contentView 模式按 `theme.contentInset` 布局 `contentView`
- 箭头逻辑（`applyArrow` / `rebuildArrow`）两模式共用

**不新建独立 popup 视图** → 外壳逻辑（background/arrow）零重复。一个 `HYMChartTooltip` 实例按 `configure` 切模式（text 与 contentView 不同时使用，因 fallback 互斥）。

### 4.3 `HYMChartTooltipController.show(contentView:)`（新增方法）

现有 `show(anchor:text:in:preferred:)` **不变**。新增：

```swift
public func show(anchor: CGRect, contentView: UIView,
                 in container: CGRect, preferred: [HYMChartTooltipPlacement])
```

逻辑与 text 版同构：`tooltip.configure(contentView:theme:)` → `sizeThatFits` → `HYMChartTooltipGeometry.resolve` → `frame` + `applyArrow` → 显隐动画（复用现有 `showsAnimation` 逻辑）。

`hide()` / `removeFromSuperview()` 两模式共用。**Controller 实例复用**：`HYMChartView` 现有 `tooltipController`（懒创建）同时承担 text 与 contentView 两种 show，由 `HYMChartTooltip` 内部按 configure 切模式。

### 4.4 定位锚点（复用现有）

popup 用各 renderer 已实现的 `tooltipAnchor(for:)`（热力图返回格子 frame + `[.top,.bottom]`，雷达同理）。**零新增**。锚点返回 nil（renderer 未实现）→ 不显示 popup。

### 4.5 `onTap` 三层分支（重构）

```swift
@objc private func onTap(_ gr: UITapGestureRecognizer) {
    let p = gr.location(in: self)
    let target = renderer.hitTest(p)
    renderer.applySelection(target)

    if let target {
        onHit?(target, .tap)                       // ① 始终：命中事件通知

        let ctx = HYMChartHitContext(
            target: target,
            frame: renderer.hitFrame(for: target) ?? .zero,
            location: p)

        if popupContentProvider != nil {           // ② popup 模式（最高优先）
            if let cv = popupContentProvider?(ctx),
               let anchor = renderer.tooltipAnchor(for: target) {
                ensureTooltipController().show(anchor: anchor.frame, contentView: cv,
                                              in: bounds, preferred: anchor.preferredPlacements)
            } else {
                tooltipController?.hide()
            }
        } else if onHitLocated != nil {            // ③ onHitLocated 外部全权
            onHitLocated?(ctx, .tap)
            tooltipController?.hide()
        } else {                                   // ④ 内置 text tooltip
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

> `updateTooltip(for:)` 现有的 `if onHitLocated != nil { hide; return }` 互斥保留作防御（onTap 已分支，正常不触发该路径，但 `updateTooltip` 仍可被外部/未来代码安全调用）。

---

## 5. 分层接口

### 5.1 SwiftUI 封装（`HeatmapChart` / `RadarChart`）

新增 init 参数 `popup`（返回 `AnyView`，避免泛型 `Content` 传染到 `UIViewRepresentable`）：

```swift
public init(...,
            onHit: (...) -> Void)? = nil,
            popup: ((HYMChartHitContext) -> AnyView)? = nil)
```

`Representable` 内 hosting（SwiftUI View → UIView）：

```swift
chart.popupContentProvider = popup != nil ? { context in
    guard let popup else { return nil }
    let host = UIHostingController(rootView: popup(context))
    host.view.backgroundColor = .clear
    return host.view
} : nil
```

> **待验证（实现期）**：`UIHostingController.view` 的尺寸获取——Core 的 `HYMChartTooltip.sizeThatFits(contentView 模式)` 需 hosting view 报告正确尺寸。可能用 `host.view.sizeThatFits(限宽)` 或 `host.sizeThatFits(in:)`，在实现时验证取可用方案。

### 5.2 OC bridge（热力图 / 雷达）

新增 `@objc` block 属性，OC 按命中索引造 `UIView` 返回：

```swift
// 热力图 HYMHeatmapChartViewBridge
@objc public var popupContentProvider: ((NSInteger, NSInteger) -> UIView?)? {
    didSet {
        chart.popupContentProvider = popupContentProvider != nil ? { [weak self] context in
            guard let self, let h = context.target as? HeatmapHitTarget else { return nil }
            return self.popupContentProvider?(h.row, h.column)
        } : nil
    }
}

// 雷达 HYMRadarChartViewBridge
@objc public var popupContentProvider: ((NSString, NSInteger) -> UIView?)? {
    didSet {
        chart.popupContentProvider = popupContentProvider != nil ? { [weak self] context in
            guard let self, let r = context.target as? RadarHitTarget else { return nil }
            return self.popupContentProvider?(r.kind as NSString, r.dimensionIndex)
        } : nil
    }
}
```

OC 端命中时只造内容 `UIView`（如 `UILabel`），SDK 套外壳 + 定位 + 显隐。`didSet` 用 `[weak self]` 防循环引用。

---

## 6. demo 改造

- **Swift `HeatmapChartDemo`**：现有 `onHitLocated` + `overlay` 自定义弹窗**改成 `popup:` 闭包**给内容 view（SDK 接管定位/显隐）。直观对比新模式省多少代码。可保留一段 `onHitLocated` 示例作对比（展示两种模式）。
- **OC `OCChartDemoViewController`**：加 `popupContentProvider` block，返回一个 `UILabel`（内容），SDK 外壳包裹。保留现有 `onHitLocated` demo（展示两种模式）。

---

## 7. 兼容性

- **`onHitLocated` 完全不变**（含 optional context 修复）—— 高级用户照常
- **内置 text tooltip**（`showsTooltipOnHit`）不变 —— 未设 `popup`/`onHitLocated` 时照常
- **三层 fallback 是新增优先级**，不影响现有默认行为（默认 `popup`/`onHitLocated` 都未设 → 走 ③ 内置或无弹窗）
- **`onHit` 始终触发**（不变）

---

## 8. 测试策略

- **ChartSelfTest（纯逻辑）**：
  - `HYMChartTooltip` contentView 模式：`configure(contentView:)` 后 `sizeThatFits` 返回尺寸与给定 contentView 尺寸一致
  - `HYMChartTooltipController.show(contentView:)` 可调用不崩
  - 注：三层 fallback 分发依赖 UIView 手势（`onTap` 私有），ChartSelfTest 不便覆盖，靠 demo 视觉
- **demo 视觉（用户手动，无自动点击工具）**：
  - Swift demo：`popup` 内容显示、边界避让、未命中消失
  - OC demo：`popup` UILabel 显示、log、未命中消失
- **leaks**：`[weak self]` 闭包（provider / bridge didSet）无循环引用

---

## 9. 文件清单

| 文件 | 改动 | 职责 |
|---|---|---|
| `Charts/Core/HYMChartView.swift` | + `popupContentProvider` + `onTap` 三层分支 | 通用：内容 view 提供者 + 分发 |
| `Charts/Core/HYMChartTooltip.swift` | + `configure(contentView:)` + `sizeThatFits`/`layoutSubviews` 分模式 | 通用：外壳复用 + 内容 view 模式 |
| `Charts/Core/HYMChartTooltipController.swift` | + `show(contentView:)` | 通用：内容 view 显示 |
| `Charts/SwiftUI/HeatmapChart.swift` | + `popup` 闭包 + Representable hosting | SwiftUI：popup 透传 |
| `Charts/SwiftUI/RadarChart.swift` | + `popup` 闭包 + Representable hosting | SwiftUI：popup 透传 |
| `Charts/SwiftUI/HeatmapChartDemo.swift` | 改用 `popup` 模式（保留 onHitLocated 对比） | Swift demo |
| `Charts/OCBridge/HYMHeatmapChartViewBridge.swift` | + `popupContentProvider` block | OC：翻译 |
| `Charts/OCBridge/HYMRadarChartViewBridge.swift` | + `popupContentProvider` block | OC：翻译 |
| `Charts/OCDemo/OCChartDemoViewController.m` | + `popupContentProvider` 示例 | OC demo |
| `Charts/Debug/ChartSelfTest.swift` | + contentView 模式断言 | 自测 |

---

## 10. 风险 / 待验证

- **UIHostingController 尺寸**（§5.1）：SwiftUI View → UIView 的尺寸获取方式需在实现期验证（`sizeThatFits` 行为）。若 hosting view 不报告尺寸，popup 定位会失准。Plan 阶段加一个独立探测。
- **contentView 尺寸契约**：外部 view（含 hosting view）必须能报告尺寸（`intrinsicContentSize` 或 `sizeThatFits`）。文档需明确此契约。
