# 蛛网图顶点点击交互 — 使用指南与实现笔记

> 日期：2026-07-23 · 提交 `90a0fd1`
> 关联：[设计 spec](2026-07-23-radar-vertex-tap-design.md) · [实现计划](../plans/2026-07-23-radar-vertex-tap.md)

雷达图（蛛网图）的**数据值顶点**（内圈，按数值定位）与**标题顶点圆点**（最外圈）支持点击：命中 → 单选高亮 + `onHit` 回调。

## 1. 使用指南

### SwiftUI

```swift
RadarChart(model: model) { target, gesture in
    switch target.category {
    case .dataVertex:  print("点了数据顶点，维度 \(target.dimensionIndex)")
    case .labelVertex: print("点了标题顶点，维度 \(target.dimensionIndex)")
    }
}
```

- `target` 是 `RadarHitTarget`，直接拿强类型 `category` + `dimensionIndex`，无需 cast。
- 关闭进场动画：`RadarChart(model: model, playsAnimationOnAppear: false) { ... }`。

### Objective-C

```objc
HYMRadarThemeBuilder *tb = [HYMRadarThemeBuilder new];
HYMRadarChartViewBridge *bridge = [[HYMRadarChartViewBridge alloc] initWithTheme:tb frame:rect];
bridge.onHit = ^(NSString *kind, NSInteger index) {
    if ([kind isEqualToString:@"dataVertex"])  { /* 数据顶点 */ }
    if ([kind isEqualToString:@"labelVertex"]) { /* 标题顶点 */ }
};
[self.view addSubview:bridge.chartView];
```

- OC 拿 `kind` 字符串（`"dataVertex"`/`"labelVertex"`）+ `index`，不涉及 Swift 强类型。

### 高亮样式（`RadarChartTheme` 5 个字段）

默认组合（放大 + 描边 + 变色）；只想用几项就把其余置 `nil` / `1.0`：

```swift
var theme = RadarChartTheme()
theme.selectionScale = 1.8          // 放大倍数；1.0 = 不放大
theme.selectionStrokeColor = .red   // 描边色；nil = 沿用原描边
theme.selectionStrokeWidth = 3      // 描边线宽
theme.selectionColor = .yellow      // 变色；nil = 用原色不变色
theme.selectionHitPadding = 14      // 命中容差 pt（越大越好点中）
```

> 注意：**标题顶点圆点默认不显示**（`showsLabelDots = false`）。`RadarChart` 的 SwiftUI 封装在 init 里强制开了 `showsLabelDots = true` 便于交互；OC 端需自行在 `HYMRadarThemeBuilder.showsLabelDots = YES` 才能点标题顶点。

## 2. 实现要点

- **命中缓存**：`RadarChartRenderer.render` 末尾构建 `hitRecords`（数据顶点先入、标题顶点后入）。`hitTest` 遍历，`距离 ≤ 半径 + selectionHitPadding` 即命中；数组顺序保证 **数据顶点优先**（重叠时）。
- **单选互斥**：`applySelection(_:)` 更新 `currentSelection`，新选中覆盖旧；`target = nil` 清除。容器 `HYMChartView.onTap` 在未命中时调 `applySelection(nil)`，实现点空白取消。
- **选中重绘不走 layoutSubviews**：`applySelection` 直接 `rebuildVertexDots/LabelDots`（不依赖 bounds，无需 `setNeedsLayout`），瞬时生效。
- **kind 范式**：通用 `HYMChartHitTarget.kind: String`（默认空）是**槽位**；雷达图特有 `RadarHitCategory` 是**值**，下沉在 `RadarHitTarget`。将来其他图表（柱状/饼）照此范式定义自己的 `XXXHitTarget`。

## 3. 踩坑记录

### replayOnTap 与命中点击冲突（已移除）

曾为排查入场动画加过 `replayOnTap`（点击重播动画）。它与命中点击共存时，点击会同时触发 `applySelection`（选中高亮）和 `playEntranceAnimation`；而入场动画把 `vertexDotsContainerLayer`（在 `animatableLayers` 里）的 opacity 重置为 0 再淡入，**把刚画好的选中高亮整个盖掉**——表现为「点了没反应」。

**教训**：进场动画驱动的 layer 集合（`animatableLayers`）与选中态重绘的 layer 集合有重叠时，动画会覆盖选中态。点击重播与点击命中不应共用同一手势。`replayOnTap` 作为临时调试工具，在动画修复、命中交互上线后已移除。

### SourceKit 假阳性

`Cannot find type 'RadarHitTarget' in scope` 等跨文件红线是本项目已知 SourceKit 假阳性（`RadarHitTarget` 定义在 `RadarChartRenderer.swift`，public）。**以 `xcodebuild ** BUILD SUCCEEDED **` 为唯一权威**，忽略编辑器红线；想消除视觉干扰可 Clean Build Folder（⌘⇧K）或重启 Xcode 让 SourceKit 重新索引。

## 4. 验证清单

- 点数据顶点（内圈紫点）→ 放大+描边+变色高亮 + `kind=dataVertex`
- 点标题顶点（最外圈圆点，`showsLabelDots=true` 时可见）→ 高亮 + `kind=labelVertex`
- 两点重合处（某维 `normalized=1` 时数据点与标题点同位）→ 优先命中 `dataVertex`
- 点另一个顶点 → 单选互斥，旧的复原
- 点空白 → 取消高亮
