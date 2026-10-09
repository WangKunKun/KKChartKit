# 轴系参考线、色带与数据标签样式（G4）

更新：2026-10-02。Line / Column / Bar / Combined 共用；Swift 和 Objective-C 使用同一渲染链，不依赖 WebView。

## 参考线与色带标签

`CartesianPlotLine.labelStyle`、`CartesianPlotBand.labelStyle` 均为 `CartesianAnnotationLabelStyle`，构造参数追加在原 initializer 尾部，已有调用不需要修改。

```swift
let style = CartesianAnnotationLabelStyle(
    color: .label,
    font: .boldSystemFont(ofSize: 15),
    backgroundColor: .systemBackground,
    alignment: .trailing,
    verticalAlignment: .top,
    offset: CGSize(width: -5, height: -24),
    bounds: .clamp
)
model.plotLines = [.init(value: 26, label: "上限 26", labelStyle: style)]
model.plotBands = [.init(from: 16, to: 23, label: "推荐区间", labelStyle:
    .init(color: .systemGreen, alignment: .leading, verticalAlignment: .bottom))]
```

- `color == nil`：线标签跟随线色，带标签用带色的不透明版；不影响线/带体颜色。
- `font == nil`：继承主题刻度字号，使用系统 medium 字体；显式字体保留字体族和字重。
- `backgroundColor == nil`：透明。可配合文字颜色提高深浅色或复杂背景上的可读性；不会自动推断最佳对比色。
- 水平对齐 `automatic / leading / center / trailing`，垂直对齐 `automatic / top / center / bottom`。方向均是**屏幕方向**，不是 RTL 排版方向，也不随 Bar 翻转。
- 对齐基准是参考线路径的边界，或与绘图区相交后的色带矩形。`automatic` 保留原默认中心：垂直图参考线右端上方、Bar 参考线上端右侧、色带居中。
- 偏移是屏幕 pt，先对齐，再加偏移，最后执行边界策略。NaN/Infinity 分量忽略；有限极大偏移限制到 ±1e9 pt，避免溢出。
- `.clamp` 默认：绘图区内留 2pt；长文字限宽、尾部截断，再钳入绘图区。高度放不下时不画。
- `.hide`：完整文本只要越界就不画；不截断。空文字和不可显示尺寸不画。
- 标线超出绑定值域不画；色带部分越界裁剪、完全越界或非有限端点不画。标注**不扩展数学值域**。
- 色带体仍位于系列下方；色带文字位于系列上方，避免不透明柱/面积覆盖。未开放任意 zIndex。
- `yAxisIndex = 1` 绑定次值轴。Bar 只支持主值轴，标签排版能力不解除这一限制。

## 数据标签与堆叠总量

```swift
var theme = CartesianChartTheme()
theme.showsDataLabels = true
theme.showsStackTotalLabels = true
theme.dataLabelColor = .label
theme.dataLabelBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
theme.dataLabelAvoidsOverlap = true
```

底色由数据标签和总量标签共用，默认透明。`dataLabelAvoidsOverlap` 默认 `false`，保持已有标签数量；开启后：

1. 先避开已放置的参考线/色带文字，再总量标签优先，其余按当前系列/类别绘制顺序；Combined 在柱/线各自处理后再统一处理跨图形族冲突。
2. 省略超出绘图区的标签；与已经保留的标签之间留约 2pt 间隔。
3. 不移动柱/条/点，不修改原值、百分比、命中、tooltip、轴范围，也不会为了标签新增图例或数据。
4. 是确定性的省略策略，不是全局最优排版。标注文字之间不会自动移动或互相避让；如业务标注特别密集，应减少标注或使用偏移。
5. `dataLabelMaxMarkCount` 的原有密度上限仍优先。总量保留独立的正/负、值轴和堆叠组语义。

## Objective-C

```objc
HYMCartesianPlotLine *line = [HYMCartesianPlotLine new];
line.value = 26;
line.label = @"上限 26";
line.labelStyle.color = UIColor.labelColor;
line.labelStyle.font = [UIFont boldSystemFontOfSize:15];
line.labelStyle.backgroundColor = UIColor.systemBackgroundColor;
line.labelStyle.alignment = HYMCartesianAnnotationAlignmentTrailing;
line.labelStyle.verticalAlignment = HYMCartesianAnnotationVerticalAlignmentTop;
line.labelStyle.offset = CGSizeMake(-5, -24);
line.labelStyle.bounds = HYMCartesianAnnotationBoundsClamp;
model.plotLines = @[line];

HYMCartesianPlotBand *band = [HYMCartesianPlotBand new];
band.from = 16; band.to = 23; band.label = @"推荐区间";
model.plotBands = @[band];
bridge.showsDataLabels = YES;
bridge.showsStackTotalLabels = YES;
bridge.dataLabelBackgroundColor = UIColor.systemBackgroundColor;
bridge.dataLabelAvoidsOverlap = YES;
[bridge updateWithModel:model preserveViewport:YES error:&error];
```

OC 使用值快照：后续修改 wrapper 需要再次 configure/update。`dashStyle` 接受 `LineDashStyle` 的 rawValue（如 `solid`、`dash`、`dot`），非法字符串回退 `solid`。

## 同页 Demo 与测试入口

四个既有轴系页面搜索“参考线色带”，点击“参考线色带与标签避让场景”；参考线/色带分组可独立调整字体、颜色、对齐、偏移与边界策略，主题分组搜索 `dataLabel`。所有可选覆盖可以关闭恢复继承。

测试：`AnnotationStyleTests` 覆盖几何边界、四种 renderer、主次轴/水平图、长文本和尺寸变化、数据命中不变、总量优先/Combined 跨族避让、复用与新建 1x/2x/3x 像素一致、OC 快照和真实 Demo Binding。界面与独立宿主结果见本批验收记录。

最终结果包、成功截图、失败与修复过程见 [2026-10-02 G2–G5 验证记录](charts-presentation-g2-g5-2026-10-02.md)。
