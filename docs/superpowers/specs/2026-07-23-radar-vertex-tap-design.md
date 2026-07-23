# 蛛网图顶点点击交互 Design Spec

> 日期：2026-07-23 · 范围：HYMCharts 通用层（Core）+ 雷达图（Radar）+ OC 桥接 · 状态：已批准，待写实现计划

## 1. 目标

为雷达图（蛛网图）增加顶点点击交互：

- **数据值顶点**（内圈，按 `normalized` 定位）与**标题顶点圆点**（最外圈，ratio=1）均可点击。
- 点击触发选中态高亮 + 业务回调（`onHit`）。
- 通用层为「命中目标分类」建立可复用范式，供将来其他图表（柱状/饼等）照用。

## 2. 关键决策（brainstorming 结论）

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | 命中语义 | 区分两种目标（数据顶点 / 标题顶点），各自独立命中 |
| 2 | 选中反馈 | 高亮 + 单选互斥（点新取消旧；点空白取消）；框架内 `applySelection` 管理选中态 |
| 3 | 高亮样式 | 默认组合（放大 + 描边 + 变色），样式通过 `RadarChartTheme` 可配 |
| 4 | 通用层分类范式 | 通用协议加 `kind: String` 槽位（默认空）；特有强类型 `category` 下沉 |

## 3. 架构原则（特有下沉）

遵循 `chart-protocol-no-chart-specific-hooks` 规则：Core 协议只放通用能力。

- `kind: String` 是**通用槽位**（所有图表可用，默认空），放 Core —— 合规。
- `RadarHitCategory` 枚举的**值**（`.dataVertex` / `.labelVertex`）是雷达图特有，下沉到 `RadarHitTarget`。
- 将来其他图表：定义自己的 `XXXHitTarget`，带自己的强类型 `category` + 派生 `kind`，范式统一。

> 关键区分：通用层提供「槽位」，特有层填「值」。`kind` 是槽位，`RadarHitCategory` 是值。

## 4. 设计详述

### 4.1 Core 通用层

**`HYMChartHitTarget` 加 `kind`（带默认实现，不破坏现有实现）：**

```swift
public protocol HYMChartHitTarget {
    var identifier: String { get }
    var index: Int { get }
    var kind: String { get }          // 通用类别槽位
}
public extension HYMChartHitTarget {
    var kind: String { "" }           // 默认：不分类
}
```

**`HYMChartView.onTap` 扩展（支持点空白取消选中）：**

```swift
@objc private func onTap(_ gr: UITapGestureRecognizer) {
    let p = gr.location(in: self)
    let target = renderer.hitTest(p)
    renderer.applySelection(target)        // 命中→选中，未命中→取消
    if let target { onHit?(target, .tap) }
}
```

- 命中：`applySelection(target)` + `onHit` 回调。
- 未命中：`applySelection(nil)` 取消当前选中（通用改进，对所有图表生效）。

### 4.2 Radar 特有层

**`RadarHitTarget`（雷达图特有命中目标）：**

```swift
public enum RadarHitCategory: String {
    case dataVertex      // 数据值顶点
    case labelVertex     // 标题顶点圆点
}

public struct RadarHitTarget: HYMChartHitTarget {
    public let category: RadarHitCategory
    public let dimensionIndex: Int
    public var identifier: String { "\(category.rawValue):\(dimensionIndex)" }
    public var index: Int { dimensionIndex }
    public var kind: String { category.rawValue }   // 通用槽位 ← 强类型镜像
}
```

**命中缓存与判定（`RadarChartRenderer`）：**

渲染时（`rebuildVertexDots` / `rebuildLabelDots`）缓存每个顶点的命中信息：

```swift
private struct HitRecord {
    let category: RadarHitCategory
    let dimensionIndex: Int
    let center: CGPoint
    let radius: CGFloat
}
private var hitRecords: [HitRecord] = []   // 数据顶点先入，标题顶点后入
```

> 缓存顺序：**数据顶点先入、标题顶点后入**，遍历命中时数据顶点优先。

`hitTest(_:)`：

```swift
public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
    let pad = currentTheme?.selectionHitPadding ?? 10
    for r in hitRecords {
        let d = hypot(point.x - r.center.x, point.y - r.center.y)
        if d <= r.radius + pad {
            return RadarHitTarget(category: r.category, dimensionIndex: r.dimensionIndex)
        }
    }
    return nil
}
```

- 容差 = `半径 + selectionHitPadding`（热区 ≈ `max(vertexDotRadius, labelDotRadius) + 10pt`）。
- 数据顶点优先（数组在前，先匹配先返回）。
- 无命中 → `nil`。

**选中态与重绘：**

```swift
private var currentSelection: (category: RadarHitCategory, dimensionIndex: Int)?

public func applySelection(_ target: HYMChartHitTarget?) {
    if let radar = target as? RadarHitTarget {
        currentSelection = (radar.category, radar.dimensionIndex)
    } else {
        currentSelection = nil          // 取消
    }
    rebuildVertexDots(...)              // 内部按 currentSelection 应用高亮
    rebuildLabelDots(...)
}
```

- `rebuildVertexDots` / `rebuildLabelDots` 增加选中态分支：若该顶点 == `currentSelection`，应用高亮（半径 × `selectionScale`、描边 `selectionStrokeColor`、填充 `selectionColor ?? 原色`）。
- 选中变化不依赖 bounds，直接在 `applySelection` 内重绘顶点 layer（无需 `setNeedsLayout`）。

### 4.3 Theme 高亮字段（`RadarChartTheme` 新增）

| 字段 | 类型 | 默认 | 含义 |
|------|------|------|------|
| `selectionScale` | `CGFloat` | `1.5` | 选中顶点放大倍数；`1.0` = 不放大 |
| `selectionStrokeColor` | `UIColor?` | 白色 | 选中顶点描边色；`nil` = 不描边 |
| `selectionStrokeWidth` | `CGFloat` | `2` | 描边线宽 |
| `selectionColor` | `UIColor?` | 主题强调色 | 选中顶点变色；`nil` = 用原色不变色 |
| `selectionHitPadding` | `CGFloat` | `10` | 命中容差（pt） |

默认值给出组合效果（放大 + 描边 + 变色）。只想用几项 → 把其余置 `nil` / `1.0`。

### 4.4 回调

- **SwiftUI**：`RadarChart.onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?` —— 直接拿 `category` + `dimensionIndex`，无需 cast。
- **OC**：`HYMRadarChartViewBridge.onHit: ((NSString *kind, NSInteger index) -> Void)?` —— OC 拿 kind 字符串（`"dataVertex"` / `"labelVertex"`）+ index。

### 4.5 OC 桥接顺带

- `HYMRadarThemeBuilder` 加 5 个 selection 字段。
- `HYMRadarChartViewBridge.onHit` 签名由 `(identifier, index)` 改为 `(kind, index)`。

### 4.6 ChartSelfTest

加断言（渲染已知尺寸后）：

- 点中数据顶点圆心 → 命中 `.dataVertex` + 正确 `dimensionIndex`。
- 点中标题顶点圆心 → 命中 `.labelVertex` + 正确 `dimensionIndex`。
- 点中两类重叠区 → 数据顶点优先。
- 容差边界（恰好在 `半径 + padding`）→ 命中；超出 → `nil`。
- `RadarHitTarget.kind == category.rawValue`；`HYMChartHitTarget` 默认 `kind == ""`。

## 5. 文件清单

| 文件 | 改动 |
|------|------|
| `Charts/Core/HYMChartInteraction.swift` | `HYMChartHitTarget` 加 `kind` + 默认实现 |
| `Charts/Core/HYMChartView.swift` | `onTap` 扩展（未命中 `applySelection(nil)`） |
| `Charts/Radar/RadarChartRenderer.swift` | `RadarHitCategory`、`RadarHitTarget`、命中缓存、`hitTest`、`applySelection`、rebuild 选中态分支 |
| `Charts/Radar/RadarChartTheme.swift` | 5 个 selection 字段 |
| `Charts/SwiftUI/RadarChart.swift` | `onHit` 类型改为 `RadarHitTarget` |
| `Charts/OCBridge/HYMRadarThemeBuilder.swift` | 5 个 selection 字段 |
| `Charts/OCBridge/HYMRadarChartViewBridge.swift` | `onHit` 签名 `(kind, index)` |
| `Charts/Debug/ChartSelfTest.swift` | 命中/优先级/容差断言 |

## 6. 非目标（YAGNI）

- 多选（本期单选互斥）。
- 跨图表统一处理「带分类命中」的通用逻辑层（`kind` 槽位已为将来预留，但不预先建中间协议/existential 处理层）。
- 受控选中 API（如外部 `setSelection(_:)`）—— 如需后续再加。
- 顶点 tooltip 弹层。

## 7. 兼容性

- `HYMChartHitTarget` 加 `kind` 是**新增带默认实现的协议要求**，不破坏现有实现（默认 `""`）。
- `HYMRadarChartViewBridge.onHit` 签名变更（identifier → kind）：OC 端需同步调整；属桥接层内部，影响面可控。
- 其余为新增类型 / Theme 新增字段（均有默认值），向后兼容。
