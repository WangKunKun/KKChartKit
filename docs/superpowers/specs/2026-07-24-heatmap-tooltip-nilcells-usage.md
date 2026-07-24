# 热力图：点击弹窗 + nil 占位 + 色阶值域 使用指南

> 日期：2026-07-24 · 适用：HYMCharts 热力图（`HeatmapChart` / `HYMHeatmapChartViewBridge`）· Swift + Objective-C

本指南覆盖热力图本轮新增/修正的三项能力：**色阶值域语义**、**点击弹窗（tooltip）**、**nil 占位格**。

---

## 1. 色阶值域（重要：行为已修正）

每个格子的颜色由 `value` 在「值域」内归一化后、经 `HeatmapChartTheme.colorScale` 映射得到。

### 默认值域 = `0 ... 数据最大值`

未显式指定时，值域下界恒为 **0**，上界为**所有有效格 `value` 的最大值**。即「值越大越实色」：
- `value = 0` → 归一化 `t = 0` → `.alpha` 色阶全透明（显示 `emptyColor`）
- `value = max` → `t = 1` → 满色

> ⚠️ **旧行为修正**：旧版默认值域是「数据 min … 数据 max」，导致数据最小值映射到 `t=0`，在 `.alpha` 色阶下全透明 = 无颜色（例如「全 20 看不到颜色」）。现已改为下界 0。

### 显式指定值域（值域固定、不随数据变化的场景）

```swift
// 方式 A：便捷 init（min/max）
let model = HeatmapChartModel(rows: cells, minValue: 0, maxValue: 90)
// 20/90 ≈ 0.22 浅色；90 满色

// 方式 B：任意 ClosedRange
let model = HeatmapChartModel(rows: cells, valueRange: 10...90)
```

OC 端通过 `HYMHeatmapChartViewBridge` 间接使用（值域语义相同；OC 暂未单独开放 minValue/maxValue 入参，可后续按需加）。

### `HeatmapCell.maxValue` 已移除

旧版每个 `HeatmapCell` 都要传 `maxValue`，但**它从未参与色阶计算**（死代码，误导）。现已移除。色阶值域统一由 `HeatmapChartModel` 管理。

---

## 2. 点击弹窗（tooltip）

点击有效格子，自动弹出气泡显示该格内容；位置局限在图表区域内，默认在格子上方，空间不足翻转到下方，极端情况贴边（可能与格子重叠）。带指向锚点的小箭头与淡入动画。

### 默认开启

SwiftUI `HeatmapChart` 与 OC `HYMHeatmapChartViewBridge` **默认开启** tooltip。

### 内容：默认 value，可每点覆盖

```swift
// 默认：显示格式化后的 value（80.0 → "80"，80.5 → "80.5"）
HeatmapCell(value: 80)

// 每点自定义文本（覆盖默认）
HeatmapCell(value: 90, tooltipText: "满分 90")
```

### 关闭弹窗

```swift
// SwiftUI：构造一个关闭 tooltip 的主题
var t = HeatmapChartTheme()
t.showsTooltipOnHit = false
HeatmapChart(model: model, theme: t)
```

```objc
// OC
HYMHeatmapThemeBuilder *tb = [HYMHeatmapThemeBuilder new];
tb.showsTooltipOnHit = NO;
HYMHeatmapChartViewBridge *bridge = [[HYMHeatmapChartViewBridge alloc] initWithTheme:tb frame:frame];
```

### 外观定制（Swift）

tooltip 外观归通用层 `HYMChartTooltipTheme`（不嵌入各图表 Theme），通过 `tooltipTheme` 参数覆盖：

```swift
var tt = HYMChartTooltipTheme.default
tt.backgroundColor = .darkGray
tt.font = .systemFont(ofSize: 11)
tt.showsArrow = false
HeatmapChart(model: model, tooltipTheme: tt)
```

可配项：`backgroundColor` / `textColor` / `font` / `cornerRadius` / `contentInset` / `maxWidth` / `showsArrow` / `arrowSize` / `shadowColor` / `showsAnimation` / `gap`。

### 交互行为

弹窗跟随选中态：点有效格显示、点空白或取消选中隐藏、点新格切换（单选互斥）。tooltip 视图 `isUserInteractionEnabled = false`，不拦截下方格子的点击。

---

## 3. nil 占位格（占位但不绘制、不命中）

数据中可插入「无效格」：占据布局位置，但**不绘制、不可点击、不参与色阶归一化**。

```swift
// Swift：用 placeholder() 或 isValid=false
let rows: [[HeatmapCell]] = [
    [HeatmapCell(value: 20), HeatmapCell.placeholder(), HeatmapCell(value: 60)],
    // 等价：HeatmapCell(value: 0, isValid: false)
]
```

```objc
// OC
HYMHeatmapCellBridge *cell = [[HYMHeatmapCellBridge alloc] initWithValue:0 color:nil valid:NO tooltipText:nil];
```

适用场景：数据有缺口（如某天无数据），希望保留网格对齐，但不显示色块。

---

## 4. API 速览

### Swift

```swift
// 格子
HeatmapCell(value: Double, color: UIColor? = nil,
            isValid: Bool = true, tooltipText: String? = nil)
HeatmapCell.placeholder()                      // 无效占位

// 模型（值域）
HeatmapChartModel(rows:, valueRange: ClosedRange<Double>? = nil,
                  rowLabels: [String]? = nil, columnLabels: [String]? = nil)
HeatmapChartModel(rows:, minValue: Double, maxValue: Double,
                  rowLabels: [String]? = nil, columnLabels: [String]? = nil)  // 便捷

// SwiftUI 视图
HeatmapChart(model:, theme: HeatmapChartTheme = .default,
             playsAnimationOnAppear: Bool = true,
             tooltipTheme: HYMChartTooltipTheme = .default,
             onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)? = nil)
```

### Objective-C

```objc
HYMHeatmapCellBridge *cell = [[HYMHeatmapCellBridge alloc]
    initWithValue:20 color:nil valid:YES tooltipText:nil];

HYMHeatmapThemeBuilder *tb = [HYMHeatmapThemeBuilder new];
tb.showsTooltipOnHit = YES;          // 默认 YES
// tb.colorScaleType / colorScaleColors / showsRowLabels / ...（同旧版）

HYMHeatmapChartViewBridge *bridge = [[HYMHeatmapChartViewBridge alloc]
    initWithTheme:tb frame:self.view.bounds];
[self.view addSubview:bridge.chartView];
[bridge configureRows:rowsArr rowLabels:rowArr columnLabels:colArr];
[bridge playEntranceAnimation];
bridge.onHit = ^(NSInteger row, NSInteger column) { ... };
```

---

## 5. 从旧版迁移

| 旧用法 | 新用法 |
|---|---|
| `HeatmapCell(value: 20, maxValue: 90)` | `HeatmapCell(value: 20)` + `HeatmapChartModel(rows:, minValue: 0, maxValue: 90)` |
| `[[HYMHeatmapCellBridge alloc] initWithValue:20 maxValue:90 ...]` | `initWithValue:20 color:nil valid:YES tooltipText:nil` + 模型层指定值域 |
| 依赖「数据 min…max」默认值域 | 默认改为 `0…数据max`；若需旧行为显式传 `valueRange: dataMin...dataMax` |

**移除项**（breaking）：`HeatmapCell.maxValue`、`HeatmapCell.normalized`、`HYMHeatmapCellBridge.maxValue`、对应 init 参数。雷达图（`RadarDimension.maxValue`）不受影响。

---

## 设计与实现参考

- 设计：`docs/superpowers/specs/2026-07-24-heatmap-tooltip-and-nil-cells-design.md`
- 实施计划：`docs/superpowers/plans/2026-07-24-heatmap-tooltip-and-nil-cells.md`
- 自检：`Charts/Debug/ChartSelfTest.swift`（定位算法、nil 占位、值域默认/显式、用户色阶场景）
