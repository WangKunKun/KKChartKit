# 雷达图 label 自适应不超出 + 装饰 ring 动态半径

> 日期：2026-07-23
> 关联：[标签布局 + 动态主题](2026-07-23-radar-labels-dynamic-theme.md)、[OC 使用指南](2026-07-23-charts-oc-usage.md)

本轮两项雷达图布局增强 + HYMRingRenderer OC 验证。

## 1. label 自适应不超出 bounds（方案 A：measure 后扣除）

**问题**：原 `maxRadius` 只扣 `labelOuterPadding`（间距）+ `dotMargin`，没算 label 文字宽/高。label 近边落在 `radius + gap ≈ bounds 边 − dotMargin`，文字再向外延展 → 超出 bounds。

**方案**（用户选定，可控性优先）：render 时先 measure 所有 label，`maxRadius` 扣除 label 尺寸，保证「图 + label」全在 bounds 内。

- `measureLabels(model, theme) -> (maxLabelW, maxLabelH)`：用 `boundingRect` 量每个 label（`labelMaxLineLength > 0` 时按换行宽度算多行高度），取全局 max。
- `maxRadius(bounds, maxLabelW, maxLabelH)`：
  ```
  radius = min( bounds.w/2 − gap − maxLabelW , bounds.h/2 − gap − maxLabelH ) − dotMargin
  ```
- `render`：先 `measureLabels` 再 `maxRadius`。

**取舍**（用户已知/接受）：label 越长 → radius 越小（图越小）。当图被压过小时，使用方设 `theme.labelMaxLineLength`（左右长 label 换行）或加大 chartView frame。`boundingRect` 是保守估算，label 远边会留极小安全余量（不会超出）。

## 2. 装饰 ring 动态半径（decorativeRingRadiusRatio）

**问题**：`rebuildDecorativeRing` 的 `bounds` 虽是整个 view，但半径算的是 `radius + gap + inset`（基于顶点圈），`viewHalf` 只作裁剪上限 → 装饰 ring 总落在「顶点外 gap+inset」，用不满 bounds。

**方案**：加 `decorativeRingRadiusRatio: CGFloat?`（相对 `viewHalf`，`0~1`；`nil` = 旧行为）。

```
decorativeRadius = ratio != nil ? viewHalf * clamp(ratio,0,1)
                                 : radius + gap + inset
然后 min(..., viewHalf − 0.5)
```

- `1.0` = 贴 view 边（用满可显示区域）
- `0.7` = 70% viewHalf
- `nil` = 旧行为（顶点圈 + gap + inset）

```swift
theme.decorativeRingRadiusRatio = 0.95   // 放大到接近 view 边
```
OC：`theme.decorativeRingRadiusRatio = @0.95;`

响应 view 大小，配合 `decorativeRingSides`（形状）+ `decorativeRingFillColor`（填充）自由组合。

## 3. HYMRingRenderer OC 验证

OC demo `OCChartDemoViewController` 加 `setupRingTest`：用 `[HYMRingRenderer ringLayerWithCenter:radius:sides:strokeColor:lineWidth:fillColor:dashed:dashLength:dashGap:startAngle:]` 生成 3 个 ring（圆 sides=0 / 六边形 sides=6 / 虚线三角形 sides=3 dashed）加到容器 layer。确认 `@objc` 独立绘制器 OC 可用。

## 4. 文件改动

| 文件 | 改动 |
|------|------|
| `RadarChartRenderer` | `measureLabels` + `maxRadius` 扣 label；`rebuildDecorativeRing` 支持 `decorativeRingRadiusRatio` |
| `RadarChartTheme` | 加 `decorativeRingRadiusRatio: CGFloat?` |
| `HYMRadarThemeBuilder` | 加 `decorativeRingRadiusRatio: NSNumber?` |
| `OCChartDemoViewController` | HYMRingRenderer 测试（3 ring）+ 主题配置调整 |
