# 蛛网图 showsData 开关设计

> 日期：2026-07-22
> 状态：已批准，实现中
> 背景：需要「只显示背景、不显示蛛网数据部分」的配置（无数据 / 加载中骨架占位）

## 1. 需求

加一个开关，开启/关闭「数据多边形 + 顶点圆点」的显示。关闭时保留网格、放射轴、标签、中心分数，呈现一张**无数据的骨架雷达图**。

## 2. 决策

| 决策点 | 结论 | 理由 |
|---|---|---|
| 开关归属 | **Theme**（`showsData`） | 与 `showsGridLines`/`showsAxes` 同类（视觉显隐开关），一致性强 |
| 默认值 | `true` | 向后兼容（Task 1-9 视觉不变） |
| 隐藏手段 | `layer.isHidden = true` | 比「清 path」更利于切回 `true` 时数据立即恢复；动画无需特判 |

## 3. 实现

1. `HYMRadarChartTheme`：新增 `public var showsData: Bool = true`（init 参数 + 赋值）。
2. `HYMRadarChartView.applyThemeColors(_:)`：
   ```swift
   let dataHidden = !theme.showsData
   dataFillLayer.isHidden = dataHidden
   dataStrokeLayer.isHidden = dataHidden
   vertexDotsLayer.isHidden = dataHidden
   ```
3. 入场动画（`performEntranceAnimation`）**不改**：`isHidden` 的 layer 其 opacity/transform 动画无视觉影响；网格 / 轴 / 分数动画照常。
4. `rebuildData` / `rebuildVertexDots` 仍设 path（`isHidden` 控制显隐，切回 `true` 即恢复）。

## 4. 正交性

`showsData`（数据层）与 `showsGridLines`/`showsAxes`（网格/轴）、`showsCenterScore`（分数）互相独立，可任意组合。例如：
- `showsData=false` + `showsGridLines=false` + `showsAxes=false` = 纯背景卡片 + 标签 + 分数。

## 5. 配置方式（OC）

OC init（Swift 代码，与现有 `gridRingFill`/`showsAxes` 配置同处）：
```swift
self.theme.showsData = false
```

## 6. 验证

- `showsData=false`：截图（独立图像分析）确认骨架——无紫色数据多边形、无顶点圆点，网格/轴/标签/中心分数仍在。
- 默认 `true`：向后兼容（与 Task 1-9 现状一致）。
