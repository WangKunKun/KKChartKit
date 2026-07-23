# 热力图（Heatmap）使用指南与设计笔记

> 日期：2026-07-23 · 提交 `aa60d71`
> 关联：[实现计划](../plans/2026-07-23-heatmap-chart.md)

HYMCharts 的热力图：二维格子色块，**行数与每行格子数不固定**（支持锯齿行），按可用渲染区域 + 列数**自适应正方形格子尺寸**。点击格子选中（边框高亮）+ `onHit` 回调。不改 Core，复用 `HYMChartView` 容器。

## 1. 文件结构

| 文件 | 职责 |
|------|------|
| `Heatmap/HeatmapChartModel.swift` | 数据：`HeatmapCell` + `HeatmapChartModel`（锯齿行、`resolvedValueRange`、`maxColumns`） |
| `Heatmap/HeatmapGeometry.swift` | 布局纯函数（正方形 `cellSize`、行/列间距分开、对齐、`cellFrame`） |
| `Heatmap/HeatmapChartTheme.swift` | 外观：色阶（none/gradient/stops/alpha）+ 标签/间距/选中边框 |
| `Heatmap/HeatmapChartRenderer.swift` | 渲染：格子色块 + `hitTest` + `applySelection`（选中边框）+ opacity 入场 |
| `SwiftUI/HeatmapChart.swift` | SwiftUI 封装（`UIViewRepresentable`） |
| `OCBridge/HYMHeatmap*Bridge.swift` | OC 桥接三件套（Cell/Theme/View） |

## 2. 使用指南

### SwiftUI

```swift
let model = HeatmapChartModel(
    rows: [[HeatmapCell(value: 12), HeatmapCell(value: 34), ...]],
    rowLabels: ["W1", "W2", ...],
    columnLabels: ["一", "二", ...])
HeatmapChart(model: model) { target, _ in
    print("hit (\(target.row),\(target.column))")
}
```

> 当前 `HeatmapChart` 的 SwiftUI 封装在 init 里默认设了 GitHub 风格：`.alpha(Green)`、无标签、无间距、无圆角。传自定义 `theme` 可覆盖（但 init 内的强制项优先；如需完全自定义，调整 init）。

### Objective-C

```objc
HYMHeatmapThemeBuilder *tb = [HYMHeatmapThemeBuilder new];
tb.colorScaleType = @"alpha";
tb.colorScaleColors = @[UIColor.greenColor];
HYMHeatmapChartViewBridge *bridge = [[HYMHeatmapChartViewBridge alloc] initWithTheme:tb frame:rect];
bridge.onHit = ^(NSInteger row, NSInteger col) { /* ... */ };
[bridge configureRows:cells rowLabels:labels columnLabels:cols];
[self.view addSubview:bridge.chartView];
```

## 3. 颜色映射逻辑（核心）

每格颜色按以下顺序决定（`HeatmapChartRenderer.resolvedColor`）：

1. **per-cell 覆盖**：`cell.color` 非 nil → 直接用，跳过下面。
2. **值域** `resolvedValueRange` = 显式 `valueRange` ?? 自动（数据 `min...max`）；空/单值/`min==max` → `0...1`。
3. **归一化 t** = `(value - lo) / (hi - lo)`，裁剪 `[0,1]`；`hi==lo` 时 `t=1`。
4. **色阶** `colorScale.color(at: t)`：
   - `.gradient(low, high)`：`t=0→low`、`t=1→high`，线性插值
   - `.stops([(value, color)])`：按 value 锚点分段插值
   - `.alpha(color)`：**单色，`alpha = t`**（`t=0` 全透明、`t=1` 全实色）
   - `.none`：返回 `.clear` → 兜底 `emptyColor`

### 关于 `value = 0`

- 默认 `.gradient` 下，`value=0` = gradient 的 `low`（最浅色），**不是** `emptyColor`。
- `emptyColor` 仅 `.none` 色阶兜底用。
- `.alpha` 下，`value=0` → `alpha=0` → 全透明（透出 `backgroundColor`）。

### `.alpha`：值越大越实色

```swift
theme.colorScale = .alpha(.systemGreen)
```
透明度 = `t`。要让 `t = value/max`（最大值百分比），保证值域下界为 0：**数据含 0**（自动 `min=0`）或显式 `model.valueRange = 0...max`。

## 4. 标签：独立显隐且不占空间

`showsRowLabels` / `showsColumnLabels` 分别控制左侧行标签、顶部列标签。`false` 时**不渲染且不占渲染空间**（`resolveCellBounds` 不为其预留，格子区域扩展过去）。

```swift
theme.showsRowLabels = false      // 隐藏左侧
theme.showsColumnLabels = false   // 隐藏顶部
```

## 5. 间距：行/列分开，最小 0

```swift
theme.rowSpacing = 0       // 行紧贴
theme.columnSpacing = 8    // 列间距 8
```
Theme init 内 `max(0, …)` 兜底，保证 ≥ 0。

## 6. 选中边框（点击格子）

点击格子 → `applySelection` 单选互斥 → 选中格子按 `selectionBorderColor` / `selectionBorderWidth` / `selectionBorderCornerRadius`（圆角默认同 `cellCornerRadius`）加边框；点空白取消。选中重绘走 `render`（不依赖 layoutSubviews）。

## 7. 入场动画

`animatableLayers` 返回 `cellsContainerLayer`，容器对其 **opacity 逐帧淡入**（DisplayLink，无 scale）。`showsEntranceAnimation` 开关。详见 [入场动画设计](2026-07-23-chart-entrance-animation.md)（layoutSubviews 抑制 CATransaction 隐式动画的坑同样适用）。

## 8. 自检

`ChartSelfTest` 加热力图几何（cellSize/cellFrame、行/列间距分开）、`HeatmapChartModel`（maxColumns/resolvedValueRange）、`HeatmapColorScale`（gradient/stops/alpha）、命中/选中断言，以及 `assertTintsEqual`（UIColor 分量比较，避开 `==` 受色彩空间影响）。
