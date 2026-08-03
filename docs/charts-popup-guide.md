# HYMCharts 自定义弹窗（Tooltip / Popup）使用指南

> 点击图表单元后显示弹窗的两种模式与配置。
> 适用版本：2026-08-03（`onHitLocated` + `popupContentProvider` 两层机制）。

## 概述

HYMCharts 提供两层「命中弹窗」机制，按控制权从「SDK 接管」到「外部全权」：

| 层 | API | 谁控制定位/显隐 | 适用 |
|---|---|---|---|
| 便利层 | `popup` / `popupContentProvider` | SDK（外壳 + 智能定位 + 显隐动画） | 标准弹窗，外部只给内容 |
| 低层 | `onHitLocated` | 外部（拿到位置自己显示） | 高度自定义弹窗 |

加上内置 text tooltip，构成**三层 fallback**（一次命中互斥选用，设了高层就用高层）：

```
命中 target:
  ① popupContentProvider 已设 → SDK 外壳 + 外部内容 view（便利层）
  ② onHitLocated 已设       → 外部全权控制（低层）
  ③ showsTooltipOnHit=true  → 内置 text tooltip
未命中 target → 三者都隐藏
```

> `onHit`（命中事件通知）始终触发，不参与 fallback。

---

## 用法 1：popup（推荐 · SDK 接管）

外部只提供「内容 view」，SDK 套统一外壳（背景/圆角/阴影/箭头）+ 智能定位（边界避让）+ 显隐动画。

### SwiftUI（HeatmapChart / RadarChart）

```swift
HeatmapChart(model: model) { target, _ in
    print("hit \(target.row),\(target.column)")
} popup: { context in
    AnyView(
        VStack(spacing: 2) {
            Text("(\(context.target.row),\(context.target.column))").font(.system(size: 13, weight: .semibold))
            if let tip = (context.target as? HeatmapHitTarget)?.tooltipText { Text(tip).font(.system(size: 11)) }
        }
        .foregroundStyle(.white)
    )
}
```

### UIKit（HYMChartView 直接）

```swift
chart.popupContentProvider = { context in
    let label = UILabel()
    label.text = "..."
    label.sizeToFit()
    return label
}
```

### Objective-C（bridge）

```objc
self.heatmapBridge.popupContentProvider = ^UIView *(NSInteger row, NSInteger column) {
    UILabel *content = [[UILabel alloc] init];
    content.text = [NSString stringWithFormat:@"(%ld,%ld)", (long)row, (long)column];
    [content sizeToFit];
    return content;
};
```

**内容 view 契约**：必须能报告尺寸（`intrinsicContentSize` 或 `sizeThatFits(_:)`），SDK 据此定位。SwiftUI View 经 `UIHostingController` 转 UIView（封装层处理）。

---

## 用法 2：onHitLocated（外部全权 · 高自定义）

SDK 把命中上下文（target + frame + location，chartView 坐标系）传出，外部自己造弹窗、定位、显隐。**命中传 context，未命中传 nil**（外部据此隐藏弹窗）。

### SwiftUI

```swift
HeatmapChart(model: model) { target, _ in } onHitLocated: { context, _ in
    if let context {
        // 用 context.frame / context.location 显示自定义弹窗
    } else {
        // 未命中：隐藏弹窗
    }
}
```

### UIKit / Objective-C

```swift
chart.onHitLocated = { context, gesture in
    guard let context else { /* 隐藏 */; return }
    let frame = chart.convert(context.frame, to: superview)  // 转坐标系
    // 自定义弹窗
}
```

```objc
// OC bridge 用 BOOL hit 前置（OC 无法直接表达 optional 多参数）
self.heatmapBridge.onHitLocated = ^(BOOL hit, NSInteger row, NSInteger column, CGRect frame, CGPoint location) {
    if (!hit) { /* 隐藏 */; return; }
    // hit=YES: row/col/frame/location 有效，自定义弹窗
};
```

---

## 配置（tooltipTheme）

弹窗外壳外观归通用 `HYMChartView.tooltipTheme`（`HYMChartTooltipTheme`）：

```swift
var theme = HYMChartTooltipTheme()
theme.backgroundColor = .black.withAlphaComponent(0.85)
theme.cornerRadius = 8
theme.showsArrow = true                    // 箭头（合成 path，从弹窗边缘伸出指向锚点）
theme.arrowSize = CGSize(width: 10, height: 6)
theme.gap = 6                              // 弹窗与锚点间距
theme.showsAnimation = true                // 淡入 + 轻缩放
theme.contentInset = .init(top: 6, left: 8, bottom: 6, right: 8)
chart.tooltipTheme = theme
```

---

## 实现要点（维护者参考）

- **三层 fallback**：`HYMChartView.onTap` 命中分支（`popupContentProvider` > `onHitLocated` > 内置 text tooltip，互斥）；未命中按激活模式镜像处理。
- **弹窗视图**：`HYMChartTooltip`（Core）= 一个 `CAShapeLayer` 合成 path（圆角矩形 + 箭头三角形）一次 fill。text 模式（`configure(text:theme:)`）/ contentView 模式（`configure(contentView:theme:)`）复用同一外壳。
- **箭头坐标系**：`HYMChartTooltipGeometry.resolve` 返回的 `arrowX` 是**容器坐标**；`HYMChartTooltip.makeBackgroundPath` 内转局部（`arrowX - frame.minX`），否则箭头会偏到弹窗一侧。
- **智能定位**：`HYMChartTooltipGeometry.resolve`（纯函数，仅 CoreGraphics）——按 preferred 顺序找完整落在容器内的方向，否则选溢出最少方向并裁进容器；水平居中、超出贴边。
- **SwiftUI hosting**：`HeatmapChartRepresentable`/`RadarChartRepresentable.makePopupProvider` 用 `UIHostingController` 转 UIView。
- **OC 兼容**：两个 bridge 的 `onHitLocated` / `popupContentProvider` 在 `didSet` 内 `[weak self]` 翻译，防循环引用。

---

## 相关文档

- 设计：`docs/superpowers/specs/2026-07-31-chart-hit-location-callback-design.md`（onHitLocated）、`docs/superpowers/specs/2026-08-03-chart-popup-content-provider-design.md`（popup）
- 计划：`docs/superpowers/plans/2026-07-31-chart-hit-location-callback.md`、`docs/superpowers/plans/2026-08-03-chart-popup-content-provider.md`
