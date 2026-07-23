# 雷达图标签布局 + per-dim 标题点 + OC 动态主题

> 日期：2026-07-23
> 关联：[顶点点击 spec](2026-07-23-radar-vertex-tap-design.md)、[OC 使用指南](2026-07-23-charts-oc-usage.md)

本轮对雷达图的三项增强：(1) 标签布局（方向感知换行 + 四方一致间距）；(2) 标题顶点圆点 per-dimension 显隐；(3) OC 端动态修改主题触发重新渲染。

## 1. 标签布局

### 1.1 方向感知（上下单行 / 左右可换行）

`rebuildLabels` 按每个顶点角度 `a` 判定方向：

- `|sin(a)| >= |cos(a)|` → **上下**（垂直方向，顶部/底部附近）：始终单行。
- 否则 → **左右**（水平方向）：可换行。

`RadarChartTheme.labelMaxLineLength: CGFloat`（默认 `0` = 不换行，向后兼容）。`> 0` 时左右标签按此宽度 `numberOfLines = 0` + `preferredMaxLayoutWidth` 自动换行；上下标签不受影响。

```swift
var theme = RadarChartTheme()
theme.labelMaxLineLength = 60   // 左右长标签换行，上下仍单行
```
OC：`theme.labelMaxLineLength = 60;`

### 1.2 四方一致间距（近边对齐）

所有标签的**近边（靠雷达图一侧）**对齐顶点外侧点 `labelCenter = center + (radius + labelOuterPadding) * dir`：

| 位置 | 对齐 | 离顶点 |
|------|------|--------|
| 顶部 | 底边 → `labelCenter.y`，向上延展 | `labelOuterPadding` |
| 底部 | 顶边 → `labelCenter.y`，向下延展 | `labelOuterPadding` |
| 左侧 | 右边 → `labelCenter.x`，向左延展 | `labelOuterPadding` |
| 右侧 | 左边 → `labelCenter.x`，向右延展 | `labelOuterPadding` |

一个 `labelOuterPadding` 统一控制四方，表现一致。（早期上下用 `center` 对齐被标签高度吃掉一半间距，导致比左右近——已修。）

> 若要上下/左右独立微调，后续可拆 `labelOuterPaddingVertical/Horizontal`；当前统一即可。

## 2. per-dimension 标题点显隐（showsLabelDot）

`theme.showsLabelDots` 是全局开关。新增 per-dim 覆盖：

`RadarDimension.showsLabelDot: Bool?`
- `nil` → 沿用全局 `theme.showsLabelDots`
- `true` / `false` → 该维度独立显示/隐藏标题顶点圆点

`rebuildLabelDots` 与命中缓存 `hitRecords` 的 `labelVertex` 都按 `dim.showsLabelDot ?? theme.showsLabelDots` 判定——**不画的也不参与命中**（避免点空）。

```swift
RadarDimension(label: "防守", value: 60, showsLabelDot: false)   // 该维度隐藏标题点
```
OC（`NSNumber?`，`nil`=全局、`@YES`/`@NO`=覆盖）：
```objc
[[HYMRadarDimensionBridge alloc] initWithLabel:@"防守" value:60 maxValue:100
    labelColor:nil labelFont:nil dataDotColor:nil labelDotColor:nil showsLabelDot:@NO];
```

## 3. OC 动态修改主题（applyTheme）

OC 桥接 `HYMRadarChartViewBridge` / `HYMHeatmapChartViewBridge` 原本只在 `init` 时 `build()` 一次主题，之后无法换。新增：

- `theme` 改 `var`
- `configure(...)` 时缓存 `currentModel`
- `applyTheme(_ themeBuilder:)`：重新 build theme + 用 `currentModel` 调 `chart.configure(model:theme:)` → 触发 `setNeedsLayout` → `layoutSubviews` → `render` 重绘

```objc
HYMRadarThemeBuilder *t = [HYMRadarThemeBuilder new];
t.dataStrokeColor = UIColor.redColor;   // 改任意字段
[bridge applyTheme:t];                   // 触发重新渲染（数据不变，无需重传）
```

机制：数据不变只换外观时用 `applyTheme`；连数据也改仍用 `configure`。

OC demo（`OCChartDemoViewController`）含「切换雷达图主题」按钮验证：在默认主题 ↔ 红色 + 左右换行主题间切换，每次点击一次 `applyTheme` 重新渲染。

## 4. 文件改动

| 文件 | 改动 |
|------|------|
| `RadarChartTheme` | 加 `labelMaxLineLength`；`labelOuterPadding` 默认调为 15 |
| `RadarChartModel` (`RadarDimension`) | 加 `showsLabelDot: Bool?` |
| `RadarChartRenderer` | `rebuildLabels` 方向判断 + 换行 + 四方近边对齐；`rebuildLabelDots` / `hitRecords` 的 labelVertex per-dim 判定 |
| `HYMRadarThemeBuilder` | 加 `labelMaxLineLength` |
| `HYMRadarDimensionBridge` | 加 `showsLabelDot: NSNumber?` |
| `HYMRadarChartViewBridge` / `HYMHeatmapChartViewBridge` | `theme` 改 `var` + `currentModel` 缓存 + `applyTheme(_:)` |
| `OCChartDemoViewController` | applyTheme 测试按钮 + per-dim showsLabelDot 演示 |
