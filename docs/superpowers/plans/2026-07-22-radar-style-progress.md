# 雷达图样式扩展 · 进度记录（断点恢复用）

> 最后更新：2026-07-22
> 分支：`feature/chart-framework`
> 状态：**全部完成** ✅，编译通过、模拟器运行视觉正确

---

## 已完成（按轮次）

### 轮 1：6 项样式需求（spec: radar-style-enhancements）
1. 数据点（vertexDot）显隐 + 颜色：`showsVertexDots` + `vertexDotColor`/`vertexDotRingColor`
2. 数据连线/区域颜色：`dataStrokeColor`（连线）+ `dataFillColor`（区域）—— 已有
3. 标题顶点圆点（labelDot）显隐 + 颜色：`showsLabelDots`/`labelDotColor`/`labelDotRadius`
4. 最外圈边框独立：`outerRing`（`showsOuterRing`/`outerRingColor`/`outerRingLineWidth`/`outerRingLineStyle`，独立于 `showsGridLines`）
5. 标题字体/颜色独立：`labelColor`/`labelFont` —— 已有
6. 网格/轴虚实线：`ChartLineStyle`（`gridLineStyle`/`axisLineStyle`）

### 轮 2：per-dim + 副标题 + OC 开放（spec: radar-perdim-oc）
1. per-dim label 颜色/字体：`RadarDimension.labelColor`/`labelFont`
2. per-dim 数据点颜色：`RadarDimension.dataDotColor` + `vertexDots` 重构为**容器 + 每点子 layer**
3. **删除副标题**：移除 `scoreSubtitleText/Color/Font` + `subtitleLabel`，中心只显示分数
4. 分数样式 OC 暴露：`scoreColor`/`scoreFont`
5. OC 全面开放：`HYMRadarThemeBuilder` 全字段 + `HYMRadarDimensionBridge` per-dim

### 轮 3：labelDot per-dim + 装饰 ring + 独立绘制器（spec: radar-labeldot-decoring）
1. labelDot per-dim：`RadarDimension.labelDotColor` + `labelDots` 重构为容器 + 每点子 layer
2. 装饰 ring（最外圈外）：`showsDecorativeRing` 等 7 字段，默认多边形跟随维度
3. **`HYMRingRenderer`** 独立类（`@objc`，`ringLayer`/`ringPath`，圆/多边形，OC 可调作背景）

### 轮 4：细节调整（本轮无独立 spec）
1. 最外圈线型独立：`outerRingLineStyle`（独立于 `gridLineStyle`）
2. 装饰 ring 放大到标签圈：半径 = `radius + labelOuterPadding + inset`，上限 `viewHalf`；`decorativeRingInset` 默认 `8→0`
3. 装饰 ring 填充色：`decorativeRingFillColor`（nil=透明，修复 CAShapeLayer 默认黑 bug）

---

## 当前 API 全貌

### `RadarChartTheme` 字段（外观集中）
- **背景**：`backgroundGradientStart/End`、`showsBackground`、`cardCornerRadius`
- **网格**：`gridColor`、`gridRingCount`、`gridRingFill`(GridRingFill)、`showsGridLines`、`gridLineStyle`
- **最外圈**：`showsOuterRing`、`outerRingColor`、`outerRingLineWidth`、`outerRingLineStyle`
- **装饰 ring**：`showsDecorativeRing`、`decorativeRingColor`、`decorativeRingFillColor`、`decorativeRingLineWidth`、`decorativeRingLineStyle`、`decorativeRingInset`、`decorativeRingSides`(-1跟随维度/0圆/N多边形)
- **放射轴**：`axisColor`、`showsAxes`、`axisLineStyle`
- **数据多边形**：`dataFillColor`、`dataStrokeColor`、`dataLineWidth`、`showsData`
- **数据点**：`vertexDotColor`、`vertexDotRingColor`、`vertexDotRadius`、`showsVertexDots`
- **标题顶点圆点**：`labelDotColor`、`labelDotRadius`、`showsLabelDots`
- **标签**：`labelColor`、`labelFont`、`labelOuterPadding`
- **分数**：`scoreColor`、`scoreFont`
- **线型枚举**：`ChartLineStyle`(.solid/.dashed(dashLength:gap:))

### `RadarDimension` per-dim 字段（nil → 用 Theme 统一）
`labelColor`、`labelFont`、`dataDotColor`、`labelDotColor`

### `HYMRingRenderer`（独立，OC 可调）
`ringLayer(center:radius:sides:strokeColor:lineWidth:fillColor:dashed:dashLength:dashGap:startAngle:)`、`ringPath(center:radius:sides:startAngle:)`。`sides`: 0=圆，N≥3=正N边形。

---

## 后续可优化点（未做，按需取用）

| # | 项 | 说明 | 依赖 |
|---|---|---|---|
| 1 | **蛛网图交互命中** | 框架已预留 `HYMChartHitTarget` + `onHit`，`RadarChartRenderer.hitTest` 待 override（点击维度/顶点回调） | 需确认命中目标粒度 |
| 2 | 新图表类型 | 柱状/折线/饼 —— 框架已就绪，只需加 `XXX/` 三文件（Model+Theme+Renderer）+ `HYMChartView<XXXRenderer>()` | — |
| 3 | 选中态/长按 | `applySelection` / `HYMChartGesture` 已预留扩展位 | — |
| 4 | `HYMChartError` 接入 | 当前数据层防御式兜底，可加 throws 校验 API | — |
| 5 | `ChartSelfTest` 扩展 | 补 per-dim 默认、`HYMRingRenderer.ringPath`、`ChartLineStyle.dashPattern` 断言 | — |
| 6 | `HYMRingRenderer` 便捷 OC 入口 | 当前全参（10 参数），可加少参数便捷版 | — |
| 7 | 测试页预设主题 | 一键切换深紫/亮色/极简等预设 | — |
| 8 | 性能：per-dim 点 layer | `vertexDots`/`labelDots` 各 N 个子 layer，维度极多（>20）时 layer 数 = 2N，可按需合并 | 仅超多维度场景 |

---

## 验证手段（本项目约定）
- 编译：`xcodebuild`（`** BUILD SUCCEEDED **` 为权威，SourceKit 假阳性忽略）
- 运行：`xcrun simctl install/launch/io screenshot`（iPhone 17 Pro UDID `FB74ECC0-DDCA-4168-A93D-81B91C56432C`，iOS 26.4）
- 截图分析：`mcp__4_5v_mcp__analyze_image`（视觉确认）
- 内存：`xcrun simctl spawn <UDID> leaks <PID>`
- **不 git commit** 除非用户明确要求（本次应要求提交）

## 相关文档
- spec：`specs/2026-07-22-radar-style-enhancements-design.md`、`radar-perdim-oc-design.md`、`radar-labeldot-decoring-design.md`
- 框架总 spec：`specs/2026-07-22-chart-framework-design.md`
- 框架总 plan：`plans/2026-07-22-chart-framework.md`
