# 热力图 Tooltip 副文本（第二行）设计

- 日期：2026-07-31
- 状态：已确认，待实现
- 关联文档：`2026-07-24-heatmap-tooltip-and-nil-cells-design.md`（tooltip 首版）
- 适用范围：`HYMCharts` 通用图表层 + 热力图特有层

---

## 1. 背景与动机

热力图 tooltip 首版只显示「单个值」：内容来自 `cell.tooltipText ?? format(value)`，视图层（`HYMChartTooltip`）只支持单个 `UILabel`。

实际业务中，点击一个格子常常需要同时看到 **值 + 时间**（如「80 · 14:30」或两行「80 / 14:30」）。首版把「富文本 / 多字段 / 自定义视图」明确列为 YAGNI 非目标，因此当前没有结构化的承载方式。

本设计在不破坏首版架构、不绑定具体业务语义的前提下，为 tooltip 增加一个**通用的「副文本」第二行**能力，热力图借此显示时间。

## 2. 目标 / 非目标

### 目标

- tooltip 支持「主文本（第一行）+ 可选副文本（第二行）」的结构化双行呈现。
- 副文本是**通用能力**（Core 层），不绑定「时间」语义；热力图提供便捷入口。
- 副文本样式（字号 / 颜色 / 间距）在主题中可配置，且有合理默认值。
- 兼容 Swift 与 Objective-C。
- 纯新增字段，不破坏现有 Public API。

### 非目标（YAGNI）

- **不**引入富文本（`NSAttributedString`）。
- **不**支持任意自定义 tooltip View（仍由内置 `HYMChartTooltip` 渲染）。
- **不**让 SDK 感知「时间」概念：时间格式化由调用方完成，SDK 只接收字符串。
- **不**新增跨图表统一的「内容格式化协议」（沿用首版决策：各图表特有值类型由各自派生）。
- **不**开放 OC 端的 `HYMChartTooltipTheme` 副文本样式构建器（OC 端暂用默认样式，与现状一致）。

## 3. 现状摘要

| 关注点 | 现状 | 文件 / 行 |
|---|---|---|
| tooltip 内容决定点 | `cell.tooltipText ?? format(value)` | `HeatmapChartRenderer.swift:206` |
| tooltip 视图 | 单个 `UILabel`，`configure(text:theme:)` | `HYMChartTooltip.swift:38` |
| 通用文本槽位 | `HYMChartHitTarget.tooltipText: String?` | `HYMChartInteraction.swift:21`（协议体 requirement）+ `:28`（extension 默认 nil） |
| 显示链路 | `updateTooltip(for:)` → `controller.show(text:)` → `tooltip.configure(text:)` | `HYMChartView.swift:136-146` |
| 热力图数据入口 | `HeatmapCell`（struct，无时间字段） | `HeatmapChartModel.swift:6-28` |
| OC 桥接 | `HYMHeatmapCellBridge`（`@objcMembers`） | `HYMHeatmapCellBridge.swift:4-25` |

## 4. 关键设计决策（已与使用方确认）

1. **呈现方式：结构化多行** —— 主文本（值）+ 副文本（时间）分两行，样式可控。不采用单段拼接，也不采用完全自定义 View。
2. **时间数据粒度：每格独立** —— 业务上每个格子各自带时间。但实现上**不**为此新增专门的 `timestamp: Date?` 字段。
3. **数据入口：通用 `subtitleText: String?`** —— SDK 不感知「时间」，调用方自行把时间格式化成字符串塞入。这是最不绑业务、最符合 SDK 复用原则的边界。
4. **副文本样式：主题可配置** —— 在 `HYMChartTooltipTheme` 暴露副文本字号 / 颜色 / 间距，带默认值。

## 5. 架构分层

沿用首版「**通用层提供槽位 + 渲染机制，特有层填值 + 是否启用**」哲学：

| 层 | 改动 | 性质 |
|---|---|---|
| Core 通用 | `HYMChartHitTarget` 协议新增 `tooltipSubtitle: String?` requirement | 通用槽位，与 `tooltipText` 同级 |
| Core 通用 | `HYMChartTooltip` 视图支持主 + 副双 Label | 通用渲染 |
| Core 通用 | `HYMChartTooltipTheme` 新增副文本样式 | 通用外观 |
| Core 通用 | `HYMChartTooltipController.show` 透传 subtitle | 通用链路 |
| Core 通用 | `HYMChartView.updateTooltip` 读取并传递 subtitle | 通用链路 |
| Heatmap 特有 | `HeatmapCell` 新增 `subtitleText: String?` | 业务数据入口 |
| Heatmap 特有 | `HeatmapHitTarget` 新增 `tooltipSubtitle` 存储 + `hitTest` 填充 | 特有填值 |
| OCBridge | `HYMHeatmapCellBridge` 同步 `subtitleText` | OC 兼容 |

> 「副文本」本身是通用能力（任何图表的 tooltip 都可能想加第二行），放 Core 协议合规；`HeatmapCell.subtitleText` 是热力图的业务入口，下沉特有层。二者通过 `HeatmapChartRenderer.hitTest` 衔接。

## 6. 数据流

```
用户点击格子
  → HeatmapChartRenderer.hitTest(point)                         [HeatmapChartRenderer.swift:202]
       主文本 = cell.tooltipText ?? Self.format(cell.value)
       副文本 = cell.subtitleText                                ← 新增
       → HeatmapHitTarget(tooltipText: 主, tooltipSubtitle: 副)  ← 新增参数
  → HYMChartView.updateTooltip(for: target)                     [HYMChartView.swift:136]
       guard showsTooltipOnHit, target.tooltipText 非 nil, 有 anchor
       subtitle = target.tooltipSubtitle                         ← 新增（存在量动态派发）
       → controller.show(anchor.frame, text:, subtitle:, in:, preferred:)
  → HYMChartTooltipController.show
       → tooltip.configure(text:, subtitle:, theme:)
  → HYMChartTooltip 双行布局 + sizeThatFits + 定位 + 动画
```

## 7. 显示规则

- **主文本与副文本并存，不互斥**：`tooltipText`（或格式化 value）始终是第一行，`subtitleText` 是第二行。
- **副文本仅在主文本存在时显示**：tooltip 的显示前提本就是 `tooltipText` 非 nil（`HYMChartView.swift:138-139`），因此副文本天然不会单独出现（不会出现「只有时间、没有值」的弹窗）。
- **副文本为 nil 或空串时不渲染副行**，tooltip 退化为首版单行行为。
- **时间格式由调用方自理**：`cell.subtitleText = formatter.string(from: date)`。

## 8. 关键技术约束：协议 requirement 铁律（必须遵守）

`HYMChartView` 是泛型容器，`updateTooltip(for target: HYMChartHitTarget?)` 中 `target` 是**协议存在量**（`any HYMChartHitTarget`）。通过存在量访问属性时，Swift 的派发规则是：

- 属性在**协议体声明为 requirement** → 动态派发，走到具体类型（`HeatmapHitTarget`）的存储值。
- 属性**仅在 extension 提供默认实现**（非 requirement）→ 静态绑定到 extension 的默认值，具体类型的同名属性**无法覆盖**。

现有 `tooltipText` 之所以能正确读到 `HeatmapHitTarget` 的值，正是因为它在协议体声明了 requirement（`HYMChartInteraction.swift:21`），extension 仅提供默认 nil（`:28`）。

**因此新增 `tooltipSubtitle` 时必须：**

1. 在 `HYMChartHitTarget` **协议体**声明 `var tooltipSubtitle: String? { get }`；
2. 在 extension 提供 `var tooltipSubtitle: String? { nil }` 默认实现；
3. `HeatmapHitTarget` 用自己的存储属性 `public let tooltipSubtitle: String?` 覆盖。

> 这是本项目协议层的既定铁律。漏掉第 1 步会导致副文本永远读到 nil（编译通过、运行时静默失败），是本特性的头号风险点，实现时必须有对应测试覆盖。

## 9. API 变更明细（按文件）

### 9.1 `Charts/Core/HYMChartInteraction.swift`

协议体新增 requirement，extension 新增默认实现：

```swift
public protocol HYMChartHitTarget {
    var identifier: String { get }
    var index: Int { get }
    var kind: String { get }
    var tooltipText: String? { get }
    /// 弹窗副文本（第二行，数据驱动）；默认 nil = 不显示副行。
    /// 具体图表的 `XXXHitTarget` 按需覆盖（从自身数据派生）。
    var tooltipSubtitle: String? { get }
}

public extension HYMChartHitTarget {
    var kind: String { "" }
    var tooltipText: String? { nil }
    /// 默认不显示副行
    var tooltipSubtitle: String? { nil }
}
```

### 9.2 `Charts/Core/HYMChartTooltipTheme.swift`

新增三个字段，全部带默认值：

```swift
public struct HYMChartTooltipTheme {
    // ... 现有 12 个字段不变 ...

    /// 副文本字体；nil → 跟随主字体派生（字号 − 2pt，字重不变）。
    public var subtitleFont: UIFont?
    /// 副文本颜色；nil → 主文本色 70% 不透明（次要语义）。
    public var subtitleTextColor: UIColor?
    /// 主文本与副文本的竖向间距。
    public var subtitleSpacing: CGFloat

    public init(/* 现有参数，全部保留默认值 */
                subtitleFont: UIFont? = nil,
                subtitleTextColor: UIColor? = nil,
                subtitleSpacing: CGFloat = 2) { ... }
}
```

> 现有 `init` 的所有参数保持原默认值不变，仅在末尾追加三个新参数 —— 调用方零改动。

### 9.3 `Charts/Core/HYMChartTooltip.swift`

- 新增 `private let subtitleLabel = UILabel()`，与 `textLabel` 同样 `numberOfLines = 0`、居中。
- **新增**带副文本的重载，**保留**旧 `configure(text:theme:)` 转发到新方法（`subtitle: nil`），不破坏现有 Public API：
  ```swift
  // 新增
  public func configure(text: String, subtitle: String?, theme: HYMChartTooltipTheme)
  // 保留（兼容）—— 等价于 configure(text:, subtitle: nil, theme:)
  public func configure(text: String, theme: HYMChartTooltipTheme)
  ```
  - `subtitle` 为 nil 或空串 → 隐藏 `subtitleLabel`，与首版单行行为一致。
  - 副文本字体 / 颜色取 `theme.subtitleFont ?? 派生` / `theme.subtitleTextColor ?? 派生`。
- `layoutSubviews`：主 / 副两个 Label 在扣除 inset 与箭头后的可用区内**竖向居中排列**（主在上、副在下，中间 `theme.subtitleSpacing`）；无副时主 Label 垂直居中（保持现行为）。
- `sizeThatFits`：有副时高度 = `inset.top + 主高 + spacing + 副高 + inset.bottom + arrowH`；宽度取主 / 副文本宽度最大值 + 水平 inset。无副时维持现算式。

### 9.4 `Charts/Core/HYMChartTooltipController.swift`

**新增**带 `subtitle` 的重载，**保留**旧 `show(anchor:text:in:preferred:)` 转发（`subtitle: nil`）。新重载内部透传给 `tooltip.configure(text:subtitle:theme:)`：

```swift
// 新增
public func show(anchor: CGRect, text: String, subtitle: String?,
                 in container: CGRect, preferred: [HYMChartTooltipPlacement])
// 保留（兼容）—— 等价于 show(anchor:, text:, subtitle: nil, in:, preferred:)
public func show(anchor: CGRect, text: String,
                 in container: CGRect, preferred: [HYMChartTooltipPlacement])
```

### 9.5 `Charts/Core/HYMChartView.swift`

`updateTooltip(for:)` 读取副文本并透传（存在量动态派发，依赖第 8 节 requirement）：

```swift
private func updateTooltip(for target: HYMChartHitTarget?) {
    guard showsTooltipOnHit else { tooltipController?.hide(); return }
    guard let target,
          let text = target.tooltipText,
          let anchor = renderer.tooltipAnchor(for: target) else {
        tooltipController?.hide(); return
    }
    let subtitle = target.tooltipSubtitle          // ← 新增
    ensureTooltipController().show(anchor: anchor.frame, text: text,
                                   subtitle: subtitle,                // ← 新增
                                   in: bounds, preferred: anchor.preferredPlacements)
}
```

### 9.6 `Charts/Heatmap/HeatmapChartModel.swift`

`HeatmapCell` 新增字段与 init 参数（末尾追加，带默认值）：

```swift
public struct HeatmapCell {
    public var value: Double
    public var color: UIColor?
    public var isValid: Bool
    public var tooltipText: String?
    /// 该格子弹窗副文本（第二行，如时间字符串）；nil → 不显示副行。
    public var subtitleText: String?

    public init(value: Double, color: UIColor? = nil, isValid: Bool = true,
                tooltipText: String? = nil, subtitleText: String? = nil) { ... }
}
```

### 9.7 `Charts/Heatmap/HeatmapChartRenderer.swift`

`HeatmapHitTarget` 新增存储与 init 参数；`hitTest` 填充副文本：

```swift
public struct HeatmapHitTarget: HYMChartHitTarget {
    // ... 现有字段 ...
    public let tooltipText: String?
    public let tooltipSubtitle: String?          // ← 新增（覆盖协议默认 nil）
    public init(row: Int, column: Int,
                tooltipText: String? = nil,
                tooltipSubtitle: String? = nil) { ... }
}

public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
    guard let model = currentModel else { return nil }
    for hit in lastCellFrames where hit.frame.contains(point) {
        let cell = model.rows[hit.row][hit.col]
        let text = cell.tooltipText ?? Self.format(cell.value)
        return HeatmapHitTarget(row: hit.row, column: hit.col,
                                tooltipText: text,
                                tooltipSubtitle: cell.subtitleText)   // ← 新增
    }
    return nil
}
```

### 9.8 `Charts/OCBridge/HYMHeatmapCellBridge.swift`

同步暴露 `subtitleText`：

```swift
@objcMembers
public final class HYMHeatmapCellBridge: NSObject {
    @objc public var value: Double
    @objc public var color: UIColor?
    @objc public var valid: Bool
    @objc public var tooltipText: String?
    @objc public var subtitleText: String?          // ← 新增

    @objc public init(value: Double, color: UIColor? = nil, valid: Bool = true,
                      tooltipText: String? = nil, subtitleText: String? = nil) { ... }

    internal var heatCell: HeatmapCell {
        HeatmapCell(value: value, color: color, isValid: valid,
                    tooltipText: tooltipText, subtitleText: subtitleText)
    }
}
```

### 9.9 Demo / 使用指南

- `OCChartDemoViewController.m`：示例中给 cell 设置 `subtitleText`（格式化后的时间字符串）。
- Swift Demo / SwiftUI 封装示例同步补充。
- 更新热力图使用指南文档：说明 `subtitleText` 用法与「时间格式自理」约定。

## 10. OC 兼容

- `HYMHeatmapCellBridge` 同步新增 `subtitleText`（`@objc`），OC 端可直接使用。
- `HYMChartTooltipTheme` 为 struct，OC 端本就未开放主题构建器（首版 YAGNI）；副文本样式字段 OC 端暂用默认，**不新增** OC 构建器。若将来 OC 端需要定制样式，再单独评估（参考现有 `HYMHeatmapThemeBuilder` 模式）。
- `HeatmapHitTarget` 为 Swift struct，不暴露 OC；OC 端通过 `onHit` 回调拿到的是 `id<HYMChartHitTarget>` —— 本设计**不**改变 OC 端 `onHit` 契约（OC 端如需副文本，由 `subtitleText` 入口已能满足，无需从 HitTarget 反读）。

## 11. 测试计划

| 测试 | 目的 | 关键断言 |
|---|---|---|
| `HeatmapCell` 初始化 | 新字段默认 nil、可赋值 | `subtitleText` 默认 nil；传入后保留 |
| `HeatmapChartRenderer.hitTest` | 副文本正确进入 HitTarget | `target.tooltipSubtitle == cell.subtitleText` |
| **协议动态派发**（**头号风险**） | 第 8 节铁律生效 | 经 `any HYMChartHitTarget` 存在量访问 `.tooltipSubtitle`，读到的是 `HeatmapHitTarget` 实际值，而非协议默认 nil |
| `HYMChartTooltip.configure` + `sizeThatFits` | 双行布局 | 有副：高度 > 单行；无副：与首版一致 |
| `HYMChartTooltip` 副文本样式 | theme 派生与覆盖 | `subtitleFont`/`Color` nil 时按规则派生；非 nil 时采用传入值 |
| `HYMHeatmapCellBridge` | OC 桥接往返 | `bridge.subtitleText` → `heatCell.subtitleText` 一致 |
| `HYMChartView.updateTooltip` 集成 | 端到端 | 命中带 `subtitleText` 的格子，tooltip 显示两行 |

## 12. 兼容性与风险

- **Public API 兼容**：所有改动均为「新增字段 / 参数（带默认值）」或「新增重载（保留旧签名转发）」；`configure` 与 `show` 的旧签名完整保留，现有调用方零改动，编译与运行行为不变。
- **头号风险**：协议 requirement 漏声明（第 8 节）—— 表现为副文本静默不显示。已用专项测试覆盖。
- **次要风险**：双行 `sizeThatFits` / `layoutSubviews` 与既有定位算法（`HYMChartTooltipPlacement`）、箭头绘制的兼容 —— 定位算法是纯函数，输入仅依赖最终 `size`，双行只改变尺寸不改定位逻辑，风险可控；需回归「上方 / 下方 / 贴边翻转」几种放置。
- **性能**：副文本仅多一个 `UILabel`，单格 tooltip 生命周期内常驻一个，无影响。

## 13. 未来扩展（非本期）

- 若后续多图表都需要「值 + 单位 / 百分比 / 状态」等副内容，本设计的 Core 通用 `tooltipSubtitle` 已可直接复用，无需再改协议。
- 若需富文本或完全自定义 tooltip View，可在 `HYMChartTooltip` 之上再叠一层「自定义 View Provider」机制；本期不做。
- OC 端 `HYMChartTooltipTheme` 构建器：当 OC 端确有副文本样式定制诉求时再补，模式参考 `HYMHeatmapThemeBuilder`。
