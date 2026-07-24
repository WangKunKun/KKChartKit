# 热力图点击弹窗 + nil 占位格 Design Spec

> 日期：2026-07-24 · 范围：HYMCharts 通用层（Core）+ 热力图（Heatmap）+ OC 桥接 + SwiftUI · 状态：已批准，待写实现计划

## 1. 目标

为热力图增加两项能力，并为「点击弹窗」建立**所有图表可复用**的通用层范式：

1. **点击弹窗（tooltip）**：点击有效格子弹出气泡，显示该格内容。
   - 位置局限在图表可显示区域内（`HYMChartView.bounds`）。
   - 默认位于格子**上方**；上方不够则翻转到**下方**；都不够则贴边裁进区域（极端情况允许与格子重叠）。
   - 内容默认为格子数值（`value`），也可为每个格子单独指定文本（`tooltipText`）。
2. **nil 占位格**：单个格子可标记为无效（`isValid == false`），占位但不绘制、不可点击、不参与色阶归一化。

> 弹窗定位为 **Core 通用能力**；nil 占位为 **热力图特有数据语义**。

## 2. 关键决策（brainstorming 结论）

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | nil 占位表达 | `HeatmapCell.isValid: Bool`（默认 true）+ `placeholder()` 便捷构造；`rows` 类型不变，OC 友好 |
| 2 | 弹窗归属层 | Core 通用层（视图 + 定位算法 + 协议钩子 + 容器集成）；热力图率先接入，未来各图表复用 |
| 3 | 内容来源 | 默认 `value`（去尾零格式化）；`HeatmapCell.tooltipText` 非 nil 时覆盖 |
| 4 | 外观定制 | 通用 `HYMChartTooltipTheme`（默认一套样式 + 关键项可改）；不嵌入各图表 Theme |
| 5 | 弹窗开关 | 通用容器 `showsTooltipOnHit` 默认 false（不影响现有图表）；热力图 Theme `showsTooltipOnHit` 默认 true，封装层开启 |
| 6 | 弹窗生命周期 | 跟随选中态：选中显示、取消/点空白隐藏、点新格切换（不 toggle） |

## 3. 架构原则（通用 vs 特有下沉）

遵循 `chart-protocol-no-chart-specific-hooks` 规则：Core 协议只承载**所有图表通用**的能力。

- **通用**（入 Core，与 `hitTest`/`applySelection` 同级，均带默认空实现，不强迫无关图表实现）：
  - `HYMChartHitTarget.tooltipText` —— 通用文本槽位（数据驱动）。
  - `HYMChartRenderer.tooltipAnchor(for:)` —— 通用锚点槽位（绘图驱动）。
  - tooltip 视图、定位纯函数、显示控制器、外观主题。
- **特有**（下沉 Heatmap）：
  - `isValid` 占位语义、`tooltipText` 取值、`value` 格式化、`showsTooltipOnHit` 开关、格子 frame 计算。
- **关键区分**：通用层提供「槽位 + 渲染/定位机制」，特有层填「值 + 是否启用」。通用容器只通过通用接口拿锚点与文本，不感知任何热力图字段。

## 4. 设计详述

### 4.1 Core 通用层（新增）

**`HYMChartTooltipPlacement.swift` —— 定位纯函数（仅依赖 CoreGraphics，便于自检）：**

```swift
public enum HYMChartTooltipPlacement {
    case top    // 弹窗在锚点上方（箭头朝下）
    case bottom // 弹窗在锚点下方（箭头朝上）
}

public enum HYMChartTooltipGeometry {
    public struct Result {
        public var frame: CGRect       // 弹窗最终 frame（view 坐标，已裁进 container）
        public var placement: HYMChartTooltipPlacement
        public var arrowX: CGFloat     // 箭头根部 x（相对 view 坐标，已 clamp 到弹窗内）
    }

    /// 定位算法（纯函数）。
    /// - Parameters:
    ///   - anchor: 锚点 frame（view 坐标）
    ///   - size: 弹窗自适应尺寸（由 tooltip sizeThatFits 给出）
    ///   - container: 可显示区域（HYMChartView.bounds）
    ///   - preferred: 偏好方向序列（热力图传 [.top, .bottom]）
    ///   - gap: 弹窗与锚点的间距
    /// - Returns: 定位结果；size 为 0 时返回 nil
    public static func resolve(
        anchor: CGRect, size: CGSize, container: CGRect,
        preferred: [HYMChartTooltipPlacement], gap: CGFloat
    ) -> Result?
}
```

定位规则：
1. **垂直**：按 `preferred` 顺序找第一个「弹窗完整落在 container 内」的方向。`preferred` 为空时按 `[.top, .bottom]` 兜底。
   - `.top`：弹窗底部 = `anchor.minY - gap`（弹窗在锚点上方）。若 `frame.minY < container.minY`（超出顶部）→ 不可用。
   - `.bottom`：弹窗顶部 = `anchor.maxY + gap`。若 `frame.maxY > container.maxY`（超出底部）→ 不可用。
2. **都放不下**：选「超出量更小」的方向，并把 frame 平移裁进 container（此时可能与 anchor 重叠 —— 即「极端情况与格子重叠」）。
3. **水平**：弹窗水平居中于 `anchor.midX`；左/右超出 container → 平移贴边。
4. **箭头 x**：默认指向 `anchor.midX`，再 clamp 到弹窗内（留出 `arrowSize.width/2` 余量），避免箭头画出弹窗外。

**`HYMChartTooltipTheme.swift` —— 外观主题（纯值类型，通用）：**

```swift
public struct HYMChartTooltipTheme {
    public var backgroundColor: UIColor
    public var textColor: UIColor
    public var font: UIFont
    public var cornerRadius: CGFloat
    public var contentInset: UIEdgeInsets   // 文字内边距
    public var maxWidth: CGFloat            // 长文本换行上限
    public var showsArrow: Bool             // 是否绘制指向锚点的小箭头
    public var arrowSize: CGSize
    public var shadowColor: UIColor?        // nil = 无阴影
    public var showsAnimation: Bool         // 显示/隐藏淡入 + 轻缩放
    public var gap: CGFloat                 // 弹窗与锚点间距
    public static let `default`: HYMChartTooltipTheme
}
```

`default` 关键取值（落地的"一套合理默认样式"）：深色半透明背景（如 `black, alpha 0.8`）/ 白字 / `.systemFont(ofSize: 12)` / `cornerRadius 6` / `contentInset (6,8,6,8)` / `maxWidth 180`（保证弹窗窄于典型图表宽度，配合贴边规则不溢出 container）/ `showsArrow true` / `arrowSize (10,6)` / `shadowColor black·0.15` / `showsAnimation true` / `gap 6`。

**`HYMChartTooltip.swift` —— 弹窗视图（UIView）：**

- 背景圆角 layer + 可选阴影 + 文字 `UILabel`（`numberOfLines = 0`，支持多行）+ 可选箭头（`CAShapeLayer`，按 `placement`/`arrowX` 绘制）。
- `configure(text:theme:)` 设置内容；`override func sizeThatFits(_:)` 按 `maxWidth`、`contentInset`、箭头尺寸自适应。
- 箭头方向由 controller 在定位后通过 `applyArrow(placement:arrowX:)` 注入。

**`HYMChartTooltipController.swift` —— 显示管理（持有 tooltip 视图，挂在 HYMChartView 上）：**

```swift
public final class HYMChartTooltipController {
    public init(host: UIView)
    public var theme: HYMChartTooltipTheme
    public func show(anchor: CGRect, text: String,
                     in container: CGRect,
                     preferred: [HYMChartTooltipPlacement])
    public func hide()
    public func removeFromSuperview()   // unmount/deinit 清理
}
```

`show` 流程：`tooltip.configure(text:)` → `sizeThatFits` → `HYMChartTooltipGeometry.resolve(...)` → 设 frame + 注入箭头 → 淡入（`showsAnimation` 关时直接显示）。`hide` 淡出后隐藏。

### 4.2 Core 协议扩展（带默认实现，不破坏现有图表）

**`HYMChartInteraction.swift` —— `HYMChartHitTarget` 加文本槽位：**

```swift
public extension HYMChartHitTarget {
    var tooltipText: String? { nil }   // 默认无文本
}
```

**`HYMChartRenderer.swift` —— 加锚点槽位：**

```swift
public struct HYMChartTooltipAnchor {
    public var frame: CGRect                                  // 锚点（view 坐标）
    public var preferredPlacements: [HYMChartTooltipPlacement]
    public init(frame: CGRect, preferredPlacements: [HYMChartTooltipPlacement])
}

public extension HYMChartRenderer {
    func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? { nil }
}
```

> 两个钩子均为「所有图表通用」的交互能力，带默认空实现；雷达图等现有图表零改动。

### 4.3 `HYMChartView` 集成

```swift
public final class HYMChartView<Renderer: HYMChartRenderer>: UIView {
    public var tooltipTheme: HYMChartTooltipTheme = .default       // 通用外观，可覆盖
    public var showsTooltipOnHit: Bool = false                     // 通用默认关
    private var tooltipController: HYMChartTooltipController?      // 懒加载/按需创建

    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        let target = renderer.hitTest(p)
        renderer.applySelection(target)
        updateTooltip(for: target)        // 新增
        if let target { onHit?(target, .tap) }
    }

    private func updateTooltip(for target: HYMChartHitTarget?) {
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
        guard let target,
              let text = target.tooltipText,
              let anchor = renderer.tooltipAnchor(for: target) else {
            tooltipController?.hide(); return
        }
        ensureTooltipController().show(anchor: anchor.frame, text: text,
                                       in: bounds, preferred: anchor.preferredPlacements)
    }
}
```

- `ensureTooltipController()` 首次显示时创建并挂载（避免无弹窗图表白白创建视图）。
- `tooltipTheme` 变更后同步给 controller。
- `unmount`/`deinit` 调 `tooltipController?.removeFromSuperview()` 清理（防泄漏，遵循现有 animator.stop/unmount 模式）。

### 4.4 热力图 nil 占位（特有）

**`HeatmapCell` 新增字段：**

```swift
public struct HeatmapCell {
    public var value: Double
    public var maxValue: Double
    public var color: UIColor?
    public var isValid: Bool          // 新增，默认 true；false = 占位不绘制不命中
    public var tooltipText: String?   // 新增，覆盖默认弹窗内容

    public init(value: Double, maxValue: Double = 100,
                color: UIColor? = nil,
                isValid: Bool = true,
                tooltipText: String? = nil)

    /// 无效占位格（占位但不绘制、不命中、不参与色阶）。
    public static func placeholder() -> HeatmapCell
}
```

**`HeatmapChartModel.resolvedValueRange`** 改为排除无效格：

```swift
let vals = rows.flatMap { $0 }.compactMap { $0.isValid ? $0.value : nil }
```

**`HeatmapChartRenderer.render`**：遍历格子时 `guard cell.isValid else { continue }` —— 不创建 layer、不写入 `lastCellFrames`；但无效格仍占据布局位置（`cellFrame` 照算），满足「占位」语义。

**`hitTest`**：无效格未进 `lastCellFrames`，天然不命中。

### 4.5 热力图 Tooltip 接入（特有）

**`HeatmapHitTarget` 加文本：**

```swift
public struct HeatmapHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let row: Int
    public let column: Int
    public let tooltipText: String?    // 新增
    public init(row: Int, column: Int, tooltipText: String? = nil) { ... }
}
```

`hitTest` 命中时填充文本（自定义优先，否则格式化 value）：

```swift
let text = cell.tooltipText ?? HeatmapChartRenderer.format(cell.value)
return HeatmapHitTarget(row: r, column: c, tooltipText: text)
```

`format(_:)` 默认去尾零：`80.0 → "80"`、`80.5 → "80.5"`（内部 static 纯函数，便于自检）。

**`HeatmapChartRenderer.tooltipAnchor(for:)`：**

```swift
public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
    guard let theme = currentTheme, theme.showsTooltipOnHit,
          let h = target as? HeatmapHitTarget,
          let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
    else { return nil }
    return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
}
```

**`HeatmapChartTheme` 新增：**

| 字段 | 类型 | 默认 | 含义 |
|------|------|------|------|
| `showsTooltipOnHit` | `Bool` | `true` | 点击格子是否弹默认 tooltip；false 时 Renderer 不提供锚点 |

### 4.6 SwiftUI 封装

`HeatmapChart`：
- `init` 默认开启：`chart.showsTooltipOnHit = true`（透传 theme 的 `showsTooltipOnHit`，默认开）。
- 新增可选参数 `tooltipTheme: HYMChartTooltipTheme = .default`，在 `makeUIView`/`updateUIView` 透传给容器。
- Demo 增加样例：含 `placeholder()` 格子 + 部分格子自定义 `tooltipText`，点击观察上/下翻转与贴边。

### 4.7 OC 桥接

- `HYMHeatmapCellBridge`：加 `@objc var valid: Bool`（默认 YES）、`@objc var tooltipText: String?`；`heatCell` 转换带上。
- `HYMHeatmapThemeBuilder`：加 `@objc var showsTooltipOnHit: Bool = true`。
- `HYMHeatmapChartViewBridge`：`init` 后按 theme 设 `chart.showsTooltipOnHit`；OC 端通过 ThemeBuilder 控制开关与内容（cell.tooltipText）。tooltip 外观先用通用默认（YAGNI，暂不开放 OC 端 tooltip 主题构建器）。

### 4.8 ChartSelfTest 扩展

新增断言（纯函数 + 渲染已知尺寸后的行为）：

**`HYMChartTooltipGeometry.resolve`：**
- 锚点居中、上方足够 → `.top`、frame 不越界。
- 锚点贴顶（上方不够）→ 翻转 `.bottom`。
- 上下都不够 → 选超出更小方向，frame 裁进 container 不越界。
- 水平超出 → 贴边（`minX == container.minX` 或 `maxX == container.maxX`）。
- `arrowX` 被 clamp 在弹窗内。

**nil 占位：**
- `HeatmapCell.placeholder().isValid == false`。
- 含 placeholder 的 model：`resolvedValueRange` 排除无效格；render 后 `hitTest` 落在无效格位置 → `nil`。

**tooltip 文本：**
- `HeatmapHitTarget.tooltipText`：cell 带自定义 → 用自定义；否则 `format(80.0) == "80"`、`format(80.5) == "80.5"`。

构建验证以 `xcodebuild ** BUILD SUCCEEDED **` 为唯一权威（忽略 SourceKit 假阳性）；按需在模拟器（UDID `FB74ECC0-DDCA-4168-A93D-81B91C56432C`）截图 + `leaks` 验证无泄漏。

## 5. 文件清单

| 文件 | 改动 |
|------|------|
| `Charts/Core/HYMChartTooltipTheme.swift` | 新增 |
| `Charts/Core/HYMChartTooltipPlacement.swift` | 新增（`HYMChartTooltipPlacement` + `HYMChartTooltipGeometry`） |
| `Charts/Core/HYMChartTooltip.swift` | 新增（tooltip 视图） |
| `Charts/Core/HYMChartTooltipController.swift` | 新增 |
| `Charts/Core/HYMChartInteraction.swift` | `HYMChartHitTarget.tooltipText` 默认实现 |
| `Charts/Core/HYMChartRenderer.swift` | `HYMChartTooltipAnchor` + `tooltipAnchor(for:)` 默认实现 |
| `Charts/Core/HYMChartView.swift` | `tooltipTheme`/`showsTooltipOnHit`/`tooltipController` + `updateTooltip` |
| `Charts/Heatmap/HeatmapChartModel.swift` | `HeatmapCell.isValid`/`tooltipText`/`placeholder()`；`resolvedValueRange` 排除无效格 |
| `Charts/Heatmap/HeatmapChartRenderer.swift` | 跳过无效格；`HeatmapHitTarget.tooltipText`；`tooltipAnchor(for:)`；`format(_:)` |
| `Charts/Heatmap/HeatmapChartTheme.swift` | `showsTooltipOnHit` |
| `Charts/SwiftUI/HeatmapChart.swift` | 默认开 tooltip + `tooltipTheme` 参数 |
| `Charts/SwiftUI/HeatmapChartDemo.swift` | placeholder + 自定义 tooltipText 样例 |
| `Charts/OCBridge/HYMHeatmapCellBridge.swift` | `valid`/`tooltipText` |
| `Charts/OCBridge/HYMHeatmapThemeBuilder.swift` | `showsTooltipOnHit` |
| `Charts/OCBridge/HYMHeatmapChartViewBridge.swift` | 透传 `showsTooltipOnHit` |
| `Charts/Debug/ChartSelfTest.swift` | 定位/占位/文本断言 |

> objectVersion 77 同步组：新增文件自动编译，无需改 pbxproj；注意避免与旧目录同名 `.swift` 冲突。

## 6. 非目标（YAGNI）

- 多选弹窗（本期单选跟随选中态）。
- OC 端 tooltip 外观主题构建器（先用通用默认；需要时再加）。
- 跨图表统一的「tooltip 内容格式化」协议（各图表特有值类型不同，由各自 Renderer/HitTarget 派生文本）。
- tooltip 内容为富文本/自定义视图（本期纯文本）。
- 弹窗的显示时长/自动隐藏（手动跟随选中态）。

## 7. 兼容性 & 风险

- 协议新增方法（`tooltipText`/`tooltipAnchor`）均带默认实现 → 雷达图等现有图表**零改动**。
- `HeatmapCell` 新增字段带默认值 → 现有 `HeatmapCell(value:)` 调用**不破坏**。
- `showsTooltipOnHit` 通用默认 false → 现有图表行为不变；仅热力图封装默认开启（符合「添加默认弹窗」需求）。
- `resolvedValueRange` 排除无效格：对全有效数据等价，无行为变化。
- 风险点：tooltip 视图挂载生命周期 —— 在 `unmount`/`deinit` 清理，遵循现有 animator.stop/unmount 防泄漏模式。
