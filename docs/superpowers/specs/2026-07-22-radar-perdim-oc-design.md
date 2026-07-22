# 雷达图 per-dimension 样式 + 副标题精简 + OC 全面开放

> 日期：2026-07-22
> 状态：已批准，实现中
> 前序：`specs/2026-07-22-radar-style-enhancements-design.md`

## 1. 概述

5 项扩展：
1. 每顶点 label 颜色/字体：统一（已有）+ per-dimension 独立覆盖。
2. 每顶点（数据点）颜色：统一（已有）+ per-dimension 独立覆盖。
3. **删除副标题**（"综合评分"），中心只显示分数。
4. 分数字体/颜色：Swift 已有（`scoreColor`/`scoreFont`），OC 补暴露。
5. 所有配置对 OC 全面开放。

## 2. per-dimension 样式（需求 1/2）—— 加到 `RadarDimension`

```swift
public struct RadarDimension {
    public var label: String
    public var value: Double
    public var maxValue: Double
    /// 可选覆盖（nil → 用 Theme 统一值）
    public var labelColor: UIColor?     // 需求1：该维度标签颜色
    public var labelFont: UIFont?       // 需求1：该维度标签字体
    public var dataDotColor: UIColor?   // 需求2：该维度数据点颜色
}
```

- **label per-dim**：`UILabel` 每维度一个，`textColor = dim.labelColor ?? theme.labelColor`、`font = dim.labelFont ?? theme.labelFont`。
- **数据点 per-dim**：现 `vertexDotsLayer`（单 CAShapeLayer，一个 fillColor）无法 per-dim。重构为 **`vertexDotsContainerLayer`（CALayer 容器）+ 每点一个子 CAShapeLayer**；每点 `fillColor = dim.dataDotColor ?? theme.vertexDotColor`。`rebuildVertexDots` 每次清空容器子 layer 再按维度重建。
- 标题顶点圆点 `labelDotsLayer` 保持统一色（不在本期 per-dim 范围）。

## 3. 删除副标题（需求 3）

移除：
- `RadarChartTheme.scoreSubtitleText` / `scoreSubtitleColor` / `scoreSubtitleFont`
- `RadarChartRenderer.subtitleLabel`（含 mount/unmount/render 引用）

`rebuildScore` 只保留 `scoreLabel`（分数居中）。OC Builder 移除对应字段。

> 说明：这是按用户明确要求删除 public 字段（"只显示一个分数"），属有意破坏兼容。

## 4. 分数样式（需求 4）

`scoreColor` / `scoreFont` Swift 已有；OC Builder 补暴露。

## 5. OC 全面开放（需求 5）

- `HYMRadarThemeBuilder`：补全**所有** Theme 字段为 `@objc` 属性——颜色（`UIColor`）、字体（`UIFont`）、`CGFloat`/`Int`、布尔；`GridRingFill`（`"none"/"gradient"/"colors"` + 颜色数组）、`ChartLineStyle`（`"solid"/"dashed"` + dash/gap 参数）字符串映射。
- `HYMRadarDimensionBridge`：加 `labelColor` / `labelFont` / `dataDotColor` 可选属性（桥接内部 `RadarDimension`）。
- `HYMRadarChartViewBridge`：不变。

## 6. 测试页更新（`RadarChartStyleDemo`）

- ④ 数据点：per-dim 演示（如前 3 维数据点独立色）。
- label per-dim：前 3 维标签独立颜色演示。
- 移除副标题相关控件；分数颜色/字体可配。

## 7. 验收标准

1. 每维度 label 可独立设颜色/字体（nil 用统一）。
2. 每维度数据点可独立设颜色（nil 用统一）。
3. 中心只显示分数，无"综合评分"副标题。
4. 分数颜色/字体可配（Swift 已有 + OC 暴露）。
5. OC 端可配置 Theme 全部字段 + 每维度独立样式。
6. `xcodebuild` 通过；默认视觉除"无副标题"外与之前一致。
