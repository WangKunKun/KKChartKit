# 雷达图样式扩展设计

> 日期：2026-07-22
> 状态：已批准，实现中
> 前序：`specs/2026-07-22-chart-framework-design.md`（HYMCharts 框架）

## 1. 概述

在已落地的 HYMCharts 雷达图上，补齐 6 项样式配置能力。经现状梳理，**需求 2、5 现有能力已覆盖**，实际新增 **1（显隐）、3、4、6**。

| # | 需求 | 现状 | 动作 |
|---|---|---|---|
| 1 | 数据点（数据值顶点圆点）显隐 + 颜色 | `vertexDotsLayer` 已画，显隐跟随 `showsData`；颜色 `vertexDotColor`/`vertexDotRingColor` 已有 | 加独立显隐开关（颜色复用） |
| 2 | 数据点连线 + 区域颜色 | `dataStrokeColor`（连线）+ `dataFillColor`（区域）已有 | ✅ 已满足 |
| 3 | 标题顶点（标签处圆点）显隐 + 颜色 | 无 | 新增 layer + 显隐/颜色/半径 |
| 4 | 标题顶点连线（最外圈边框）独立显隐 + 颜色 | 最外圈属 `gridLayer`，被 `showsGridLines` 统控 | 分离最外圈为独立 layer + 独立开关/颜色 |
| 5 | 标题字体大小 + 颜色独立 | `labelColor` + `labelFont` 已有 | ✅ 已满足 |
| 6 | 网格线 / 轴实线或虚线 | 均实线 | 加线型枚举 + 网格/轴各一 |

## 2. 命名约定

- **vertexDot** = 数据点（数据值顶点圆点，已有）
- **labelDot** = 标题顶点圆点（最外圈顶点 = 各标签对应轴端点，新增）
- **outerRing** = 最外圈边框（连接标题顶点的线，新增）

## 3. 新增 API（`RadarChartTheme`，默认值向后兼容——不改现有视觉）

```swift
// 需求1：数据点独立显隐（与 showsData 正交；颜色复用 vertexDotColor/vertexDotRingColor）
public var showsVertexDots: Bool = true

// 需求3：标题顶点圆点
public var showsLabelDots: Bool = false        // 默认 false（现状无）
public var labelDotColor: UIColor = .white
public var labelDotRadius: CGFloat = 4

// 需求4：最外圈边框独立（显隐/颜色/线宽/线型，全部独立于内圈网格）
public var showsOuterRing: Bool = true
public var outerRingColor: UIColor = UIColor.white.withAlphaComponent(0.15)  // 默认同 gridColor
public var outerRingLineWidth: CGFloat = 1.5
public var outerRingLineStyle: ChartLineStyle = .solid   // 最外圈线型（独立于 gridLineStyle）

// 需求6：线型
public enum ChartLineStyle {
    case solid
    case dashed(dashLength: CGFloat = 4, gap: CGFloat = 3)
    var dashPattern: [NSNumber]? {  // nil=实线
        switch self {
        case .solid: return nil
        case .dashed(let d, let g): return [d as NSNumber, g as NSNumber]
        }
    }
}
public var gridLineStyle: ChartLineStyle = .solid   // 内圈网格
public var axisLineStyle: ChartLineStyle = .solid   // 放射轴
```

## 4. Renderer 改动（`RadarChartRenderer`）

- `vertexDotsLayer.isHidden = !theme.showsVertexDots`（独立于 `showsData`，正交）。
- 新增 `labelDotsLayer`（CAShapeLayer）：`rebuildLabelDots` 在每个最外圈顶点（ratio=1，`RadarGeometry.point(ratio:1)`）画圆点；`isHidden = !theme.showsLabelDots`；fill=`labelDotColor`。
- `rebuildGrid` 拆分：
  - **内圈**（`gridLayer`）：画 `ringCount-1` 圈（k=0..<ringCount-1），受 `showsGridLines` + `gridLineStyle`（lineDashPattern）。
  - **最外圈**（新增 `outerRingLayer`）：画 k=ringCount-1 那一圈，受 `showsOuterRing` + `outerRingColor` + `outerRingLineWidth`，线型跟随 `gridLineStyle`（虚线选项复用）。
- `axisLayer.lineDashPattern = theme.axisLineStyle.dashPattern`。
- z 序（底→顶）：…网格底色 → 内圈网格 → 最外圈 → 放射轴 → 数据多边形 → 数据点 → 标题顶点圆点 → 标签 → 分数。
- `labelDotsLayer`/`outerRingLayer` 加入 `mount`/`unmount` 与 `animatableLayers`（参与入场动画淡入）。

## 5. 测试页面（SwiftUI）

新增 `Charts/SwiftUI/RadarChartStyleDemo.swift`：`Form` 配置面板（所有 Toggle / ColorPicker / 线型 Picker / 半径字号 Slider，`@State` 绑定一个可变 `RadarChartTheme`）+ 实时 `RadarChart(model:theme:)` 预览。`ContentView` 增加入口（导航/Tab）跳转到该页面，便于逐项测试 6 个需求。

## 6. 向后兼容

所有新字段默认值保持现有视觉：`showsVertexDots=true`、`showsLabelDots=false`、`showsOuterRing=true` + `outerRingColor` 默认同原网格色、线型默认 `.solid`。即默认 Theme 渲染结果与扩展前一致。

## 7. 验收标准

1. 数据点可独立显隐（`showsVertexDots`），与数据多边形（`showsData`）正交。
2. 数据连线/区域颜色可配（`dataStrokeColor`/`dataFillColor`，已有）。
3. 标题顶点圆点可显隐 + 设颜色/半径（`showsLabelDots`/`labelDotColor`/`labelDotRadius`）。
4. 最外圈边框独立显隐 + 颜色 + 线宽 + 线型（`showsOuterRing`/`outerRingColor`/`outerRingLineWidth`/`outerRingLineStyle`），不受 `showsGridLines`/`gridLineStyle` 影响。
5. 标题字体/颜色可独立（`labelColor`/`labelFont`，已有）。
6. 网格线、放射轴可各自设实线/虚线（`gridLineStyle`/`axisLineStyle`）。
7. 测试页面可实时预览以上全部配置。
8. `xcodebuild` 通过；默认 Theme 视觉与扩展前一致（向后兼容）。
