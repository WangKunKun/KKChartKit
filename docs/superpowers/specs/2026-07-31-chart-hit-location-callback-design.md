# 图表命中位置回调（外部自定义弹窗）设计

- 日期：2026-07-31
- 状态：已确认，待实现
- 关联文档：`2026-07-24-heatmap-tooltip-and-nil-cells-design.md`（tooltip 首版）、`2026-07-31-heatmap-tooltip-subtitle-design.md`（副文本，方向已搁置）
- 适用范围：`HYMCharts` Core 通用层 + 热力图 / 雷达图特有层 + OCBridge

---

## 1. 背景与动机

现有点击交互（`HYMChartView.onHit`）已经把命中的**索引**回调出去，但：
- **位置信息没传**：命中单元的 frame 只在 SDK 内部用于显示内置 tooltip，外部拿不到，无法自己定位弹窗。
- **无自定义弹窗入口**：只有内置 tooltip（`showsTooltipOnHit` 开关），没有"把弹窗显示交给外部"的机制。

业务需要：点击图表单元后，由**外部完全自定义弹窗**（浮层 / 详情卡片 / 跳页等任意形态）。为此 SDK 需把"命中单元的索引 + 几何位置"打包传出，并允许外部接管弹窗显示。

## 2. 目标 / 非目标

### 目标

- Core 新增**通用**的"带位置的命中回调" `onHitLocated`，一次实现，所有图表（Swift 端）自动具备。
- 回调携带：命中目标（索引/标识）+ 命中单元 frame + 触发点 location（均在 chartView 坐标系）。
- 注册 `onHitLocated` 后 SDK **自动不显示内置 tooltip**（互斥），由外部全权接管。
- 热力图、雷达图各自的 Renderer 提供 `hitFrame` 实现。
- Objective-C 端可通过现有 bridge 接收带位置的回调。
- 纯新增，保留现有 `onHit`，零破坏。

### 非目标（YAGNI）

- **不**由 SDK 传原始业务数据（如 cell.value）：外部用索引回查自己的数据源。Core 不绑业务。
- **不**做 Provider 模式（外部给 view、SDK 定位显示）——本期采用纯回调，SDK 只传信息。
- **不**修改现有 `onHit` 签名（保留兼容）。
- **不**改 tooltip 视图本身（`HYMChartTooltip` 不动；内置 tooltip 行为不变，只是可在外部接管时被跳过）。
- SwiftUI 封装（`HeatmapChart` / `RadarChart`）本期**可选**，按需透传（见 §11）。

## 3. 现状摘要

| 关注点 | 现状 | 文件 / 行 |
|---|---|---|
| Swift 命中回调 | `onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?` 传索引，无位置 | `HYMChartView.swift:22,124` |
| 命中目标协议 | `HYMChartHitTarget`：identifier/index/kind/tooltipText（"数据，非绘图细节"） | `HYMChartInteraction.swift:10-22` |
| 渲染器交互钩子 | `hitTest`/`applySelection`/`tooltipAnchor` 均 requirement + 默认实现 | `HYMChartRenderer.swift:49-63` |
| 内置 tooltip 锚点 | `tooltipAnchor(for:)` 返回 frame，但与 `showsTooltipOnHit` 耦合（关了返回 nil） | `HeatmapChartRenderer.swift:224-230` |
| 热力图命中缓存 | `lastCellFrames: [(row, col, frame)]`（view 坐标系） | `HeatmapChartRenderer.swift:43` |
| 雷达图命中缓存 | `hitRecords: [HitRecord]`，每条含 `category/dimensionIndex/center/radius` | `RadarChartRenderer.swift:52-58,169-181` |
| OC 命中回调 | bridge `onHit` block：热力图 `(row,column)`、雷达 `(kind,index)`，无位置 | `HYMHeatmapChartViewBridge.swift:12,19-23`、`HYMRadarChartViewBridge.swift:12,19-23` |
| OC 显示路径 | 非泛型 bridge 持有 `HYMChartView<XxxRenderer>`，暴露 `chartView: UIView` | 同上 |

## 4. 关键设计决策（已与使用方确认）

1. **控制权：纯回调** —— SDK 命中后把（索引 + 位置）回调出去并跳过内置 tooltip；外部完全自己创建/显示/隐藏弹窗。SDK 最薄，外部最自由。
2. **数据范围：索引 + 位置** —— 不传原始 value；外部用 target 的 row/column（或 kind/index）回查业务数据。Core 不绑业务。
3. **内置 tooltip：注册即关** —— `onHitLocated` 被设置后，`updateTooltip` 直接跳过内置 tooltip。
4. **OC 支持** —— 通过现有 bridge 翻译成 OC block（参数全为 C 类型）。
5. **范围：热力图 + 雷达图都做** —— Core 通用能力一次到位；两图各自提供 `hitFrame` 实现与 OC bridge 翻译。

## 5. 架构分层

沿用现有「Core 通用槽位 + 各图表特有实现」哲学：

| 层 | 改动 | 性质 |
|---|---|---|
| Core 通用 | 新增 `HYMChartHitContext`（target + frame + location） | 通用类型 |
| Core 通用 | `HYMChartRenderer` 协议新增 `hitFrame(for:)` requirement（默认 nil） | 通用钩子，独立于 tooltip 开关 |
| Core 通用 | `HYMChartView` 新增 `onHitLocated` + `updateTooltip` 互斥 | 通用回调 |
| Heatmap 特有 | `HeatmapChartRenderer.hitFrame`（格子 frame）+ OC bridge 翻译 | 特有实现 |
| Radar 特有 | `RadarChartRenderer.hitFrame`（顶点 center+radius→frame）+ OC bridge 翻译 | 特有实现 |

> 类比现有 `tooltipAnchor(for:)`：Core 协议定义一次，各图表提供自己的几何。`hitFrame` 同构，但**独立于 `showsTooltipOnHit`**（内置 tooltip 关闭时仍能拿到 frame，这是本特性的关键解耦点）。

## 6. 数据流

```
用户点击
  → HYMChartView.onTap(p)                                       [HYMChartView.swift:119]
       target = renderer.hitTest(p)
       renderer.applySelection(target)
       updateTooltip(for: target)
            ├─ if onHitLocated != nil → tooltipController?.hide(); return   ← 新增互斥
            └─ 否则走原内置 tooltip 逻辑
       if let target {
           onHit?(target, .tap)                                 ← 现有，保留
           frame = renderer.hitFrame(for: target) ?? .zero      ← 新增
           context = HYMChartHitContext(target, frame, p)       ← 新增
           onHitLocated?(context, .tap)                         ← 新增
       }
  → 外部（Swift 闭包 / 经 bridge 的 OC block）拿到 context
       用 target 的索引回查数据；用 frame/location 自行弹自定义弹窗
```

## 7. 关键技术约束

### 7.1 协议 requirement 铁律（头号风险）

`hitFrame(for:)` 必须在 `HYMChartRenderer` **协议体声明 requirement**，extension 仅提供默认 nil。原因同现有交互钩子（`HYMChartRenderer.swift:49` 注释："声明为 requirement，保证 override 走 witness table 可靠动态派发"）。

`HYMChartView.onTap` 中 `renderer` 虽是具体泛型类型，但若未来以存在量调用，漏声明 requirement 会导致静态绑定到默认 nil、frame 静默为 `.zero`。必须有专项测试覆盖。

### 7.2 坐标系

`context.frame` 与 `context.location` 统一为 **chartView 坐标系**：
- 热力图：`lastCellFrames` 本就是 view 坐标系（`cellsContainerLayer.frame = bounds`）。
- 雷达：`hitRecords.center` 来自 `context.center`（view 坐标系）。
- location = `gr.location(in: self)`（self 即 chartView）。

OC 端 frame 来自 `bridge.chartView` 坐标系，外部用 `convertRect:fromView:` 转换到目标坐标系。

### 7.3 互斥实现

在 `updateTooltip(for:)` **最前面**加判断（不污染 `showsTooltipOnHit` 状态）：
```swift
if onHitLocated != nil { tooltipController?.hide(); return }
```
- 热力图 bridge 默认 `showsTooltipOnHit = true`（`HYMHeatmapChartViewBridge.swift:18`）：OC 用户设了 `onHitLocated` → bridge 注册 `chart.onHitLocated` → 此判断命中 → 内置 tooltip 被跳过。
- 雷达本就无内置 tooltip（`tooltipAnchor` 默认 nil），互斥对其无副作用。

## 8. API 变更明细（按文件）

### 8.1 `Charts/Core/HYMChartInteraction.swift` —— 新增命中上下文

```swift
/// 一次命中 + 其在 chartView 内的几何位置（供外部自定义弹窗定位）。
/// 位置不进 HYMChartHitTarget（保持"数据，非绘图细节"），单独放此处。
public struct HYMChartHitContext {
    /// 命中的语义单元（含 identifier/index 及具体图表的 row/column 等）。
    public let target: any HYMChartHitTarget
    /// 命中单元在 chartView 坐标系的 frame。
    public let frame: CGRect
    /// 触发点在 chartView 坐标系的位置。
    public let location: CGPoint
    public init(target: any HYMChartHitTarget, frame: CGRect, location: CGPoint) { ... }
}
```

### 8.2 `Charts/Core/HYMChartRenderer.swift` —— 新增 `hitFrame` requirement

协议体（`:49-55` 交互能力区块）追加：
```swift
/// 命中单元的几何 frame（view 坐标系），供外部自定义弹窗定位；独立于 tooltip 开关。默认 nil。
func hitFrame(for target: HYMChartHitTarget) -> CGRect?
```
extension 追加默认实现：
```swift
func hitFrame(for target: HYMChartHitTarget) -> CGRect? { nil }
```

### 8.3 `Charts/Core/HYMChartView.swift` —— 新增 `onHitLocated` + 互斥

```swift
/// 命中后带位置信息的回调（外部自定义弹窗用）。设置后内置 tooltip 自动不显示。
public var onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?
```

`onTap` 命中分支追加（现有 `onHit` 保留）：
```swift
if let target {
    onHit?(target, .tap)
    let frame = renderer.hitFrame(for: target) ?? .zero
    onHitLocated?(HYMChartHitContext(target: target, frame: frame, location: p), .tap)
}
```

`updateTooltip(for:)` 开头追加互斥：
```swift
private func updateTooltip(for target: HYMChartHitTarget?) {
    if onHitLocated != nil { tooltipController?.hide(); return }   // 外部接管
    guard showsTooltipOnHit else { ... }                          // 现有逻辑不变
    ...
}
```

### 8.4 `Charts/Heatmap/HeatmapChartRenderer.swift` —— 实现 `hitFrame`

```swift
public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
    guard let h = target as? HeatmapHitTarget,
          let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
    else { return nil }
    return hit.frame
}
```

### 8.5 `Charts/Radar/RadarChartRenderer.swift` —— 实现 `hitFrame`

由 `hitRecords` 的 center+radius 构造正方形 frame：
```swift
public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
    guard let r = target as? RadarHitTarget,
          let rec = hitRecords.first(where: { $0.category == r.category
                                          && $0.dimensionIndex == r.dimensionIndex })
    else { return nil }
    let rad = rec.radius
    return CGRect(x: rec.center.x - rad, y: rec.center.y - rad, width: rad * 2, height: rad * 2)
}
```

### 8.6 `Charts/OCBridge/HYMHeatmapChartViewBridge.swift` —— 新增 `onHitLocated` block

保留现有 `onHit`，新增（参数全 C 类型，OC 友好）：
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
> didSet 按需同步：OC 用户设了才注册 `chart.onHitLocated`（→ 触发 Core 关内置）；不设则保持现状（内置 tooltip 正常）。现有 `chart.onHit`（老回调翻译）在 init 中保留不动。

### 8.7 `Charts/OCBridge/HYMRadarChartViewBridge.swift` —— 新增 `onHitLocated` block

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

### 8.8 Demo

- **Swift demo**（热力图 / 雷达图示例页）：各加一个 `onHitLocated` 示例 —— 命中后弹一个简单自定义浮层（如带"行/列 + 坐标"的 label），演示拿到 frame/location 并自行定位。
- **OC demo**（`OCChartDemoViewController.m`）：`bridge.onHitLocated = ^(NSInteger row, NSInteger column, CGRect frame, CGPoint location){ ... }` —— 弹一个自定义 UIView，演示坐标转换（`convertRect:fromView:bridge.chartView`）。

## 9. OC 兼容

- `HYMChartHitContext` 是纯 Swift struct，**不**暴露 OC；OC 端通过 bridge 的 block 拿到拆解后的 C 类型参数（`NSInteger`/`CGRect`/`CGPoint`/`NSString`），完全 OC 友好。
- 现有 `onHit`（Swift 闭包 + OC block）完整保留，老调用方零影响。
- bridge 的 `didSet` 同步保证：只有 OC 用户主动设 `onHitLocated` 才会触发"关内置 tooltip"，避免"bridge 内部偷偷注册导致老用户失去内置 tooltip"的副作用。

## 10. SwiftUI 封装（本期必做）

`HeatmapChart` / `RadarChart`（`UIViewRepresentable`）**已经**通过尾随闭包暴露 `onHit`（`HeatmapChart.swift:48/61`、`RadarChart.swift:37/49`，内部 cast 到具体 HitTarget）。

`onHitLocated` 需在封装层同构加一层透传：`init` 加 `onHitLocated: ((HYMChartHitContext, HYMChartGesture) -> Void)?` 参数；Representable 的 `makeUIView`/`updateUIView` 里设 `chart.onHitLocated = onHitLocated`。

> 更正：早期版本误记"SwiftUI 封装未暴露 onHit / 本期可选"。实际封装早已暴露 `onHit`，且 Swift 端（含 SwiftUI demo）使用 `onHitLocated` 必须经此封装，故 **本期必做**。实现见计划 Task 8。

## 11. 测试计划

| 测试 | 目的 | 关键断言 |
|---|---|---|
| **`hitFrame` 协议动态派发**（头号风险） | requirement 铁律生效 | 经 `any HYMChartRenderer` 存在量调 `hitFrame(for:)`，读到具体 Renderer 的实际 frame，而非默认 nil |
| 热力图 `hitFrame` | 格子 frame 正确 | 命中 (r,c) → 返回 `lastCellFrames` 中对应 frame |
| 雷达 `hitFrame` | 顶点 frame 正确 | 命中 dataVertex/labelVertex i → 返回以 `hitRecords[i].center` 为中心、`2*radius` 边长的正方形 |
| `HYMChartView.onHitLocated` 触发 | 命中后回调携带 context | context.target/frame/location 正确；未命中不触发 |
| **互斥逻辑** | 注册即关内置 | 设 `onHitLocated` 后 `updateTooltip` 不显示内置 tooltip（即便 `showsTooltipOnHit=true`） |
| bridge `onHitLocated` 翻译（热力图/雷达） | OC block 收到正确参数 | row/column/kind/index + frame + location 一致；`didSet` 设/清同步 `chart.onHitLocated` |
| 现有 `onHit` 回归 | 未破坏 | 老 `onHit`（Swift + OC）行为不变 |

## 12. 兼容性与风险

- **Public API 兼容**：纯新增（`onHitLocated`、`HYMChartHitContext`、`hitFrame` 协议方法 + 默认实现、bridge 新 block）；现有 `onHit` 与内置 tooltip 行为不变。老调用方零改动。
- **头号风险**：`hitFrame` requirement 漏声明（§7.1）—— 表现为 frame 静默为 `.zero`。已有专项测试覆盖。
- **次要风险**：互斥逻辑误伤 —— 若 bridge 总是注册 `chart.onHitLocated` 会导致老 OC 用户失去内置 tooltip。已用 `didSet` 按需注册规避（§8.6/8.7）。
- **坐标系风险**：OC 端忘记 `convertRect:fromView:` 转换会导致弹窗错位 —— 在 demo 与文档强调。
- **性能**：仅在命中时多一次 `hitFrame` 查找（O(n) 遍历缓存）与一次闭包调用，无影响。

## 13. 未来扩展（非本期）

- **Provider 模式**：若后续希望"外部给 view、SDK 复用现有定位算法显示"，可在 `onHitLocated` 之上叠加 `tooltipViewProvider`，与纯回调并存。
- **原始数据透传**：若多图表都需要 SDK 直接给业务数据，可考虑给各特有 HitTarget 暴露 value 等字段（由特有层各自决定）。
- **SwiftUI 封装**：按需在 representable 暴露 `onHitLocated`（§10）。
- **subtitle（副文本）**：`2026-07-31-heatmap-tooltip-subtitle-design.md` 已留设计，本回调落地后，外部自定义弹窗可直接显示任意内容（含时间），subtitle 内置方案可不再做。
