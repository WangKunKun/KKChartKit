# 雷达图 labelDot per-dim + 装饰 ring + 独立 Ring 绘制器

> 日期：2026-07-22
> 状态：已批准，实现中
> 前序：`specs/2026-07-22-radar-perdim-oc-design.md`

## 1. labelDot per-dim 颜色（需求 1）

`RadarDimension` 加 `labelDotColor: UIColor?`（nil → 用 Theme 统一 `labelDotColor`）。
`labelDotsLayer`（单 layer）→ 重构为 `labelDotsContainerLayer` + 每点子 layer；每点 `fillColor = dim.labelDotColor ?? theme.labelDotColor`。

## 2. 最外圈外「装饰 ring」（需求 2，默认多边形跟随维度）

`RadarChartTheme` 新增一组属性：
```swift
public var showsDecorativeRing: Bool = false       // 默认不显示
public var decorativeRingColor: UIColor = UIColor.white.withAlphaComponent(0.3)
public var decorativeRingLineWidth: CGFloat = 1
public var decorativeRingLineStyle: ChartLineStyle = .solid
public var decorativeRingInset: CGFloat = 8        // 距最外圈外的间距 pt
public var decorativeRingSides: Int = -1           // -1=跟随维度数；0=圆形；N=正N边形
```
`rebuildDecorativeRing`：用 `HYMRingRenderer.ringPath(center, radius + inset, sides, startAngle: -π/2)` 设到 `decorativeRingLayer`。`sides = (decorativeRingSides == -1) ? dimensions.count : decorativeRingSides`。

## 3. 独立 Ring 绘制器 `HYMRingRenderer`（需求 3，OC 可调）

新文件 `Charts/Core/HYMRingRenderer.swift`，`@objcMembers NSObject` 静态工具类：
- `ringLayer(center:radius:sides:strokeColor:lineWidth:fillColor:dashed:dashLength:dashGap:startAngle:) -> CAShapeLayer`
- `ringPath(center:radius:sides:startAngle:) -> CGPath`
- `sides`: `0` = 圆形 ring；`N≥3` = 正 N 边形 ring。
- OC 直接 `[HYMRingRenderer ringLayerWith...]` 拿 `CAShapeLayer`，加到自己的背景层作大背景装饰。
- 雷达图内部装饰 ring（需求②）复用 `ringPath`。

## 4. OC 开放
- `HYMRadarThemeBuilder` 加装饰 ring 6 字段；`HYMRadarDimensionBridge` 加 `labelDotColor`。
- `HYMRingRenderer` 本身即 `@objc`，外界/OC 可直接调用画背景。

## 5. 测试页
`RadarChartStyleDemo` 加：装饰 ring 显隐/颜色/线宽/线型/inset/形状 Picker；labelDot per-dim（沿用 ⑦ 的前 3 维独立色，扩展到 labelDot）。

## 6. 验收
1. 每维度最外圈顶点圆点可独立设色（labelDotColor per-dim）。
2. 最外圈外可显示装饰 ring（默认多边形跟随维度），可配色/形状/inset。
3. `HYMRingRenderer` 可独立生成圆/多边形 ring layer，OC 可调用作背景。
4. `xcodebuild` 通过；默认（showsDecorativeRing=false）视觉无变化。
