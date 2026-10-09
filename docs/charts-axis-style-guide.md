# 每轴独立样式、标签步长与边带布局

> 2026-10-09：下述为原生 G3 能力。通用模型 schema v4 现已接入系统字重、显式值轴刻度、类目候选间隔及序列化标签格式，见[通用模型 N2 契约](charts-neutral-model-guide.md)。这不表示所有原生轴字段或自定义字体资源都已进入 schema，也不放开 G6。

更新：2026-10-02，G3。Line/Column/Combined 支持类目、主值、次值轴；Bar 使用左侧类目与底部主值轴，仍不支持次轴。

## Swift

```swift
model.xAxis.style = .init(labelColor: .systemPurple,
                         labelFont: .boldSystemFont(ofSize: 16),
                         lineColor: .systemPurple, lineWidth: 2)
model.xAxis.categoryLabelInterval = 2
model.xAxis.tickLabelRotation = -35
model.yAxis.style = .init(labelColor: .systemBlue, showsLine: false)
model.secondaryYAxis?.style = .init(labelColor: .systemOrange,
                                    labelFont: .systemFont(ofSize: 18))
// 只关文字；网格与轴线不受影响，也不留文字占位。
model.yAxis.style.showsLabels = false
// 恢复继承（字体/颜色/线宽），显示文字和轴线。
model.yAxis.style = .init()
```

`CartesianAxisStyle` 各可选样式 nil 继承 `CartesianChartTheme`；轴线宽非有限/负数也继承，0 保留零宽语义。隐藏轴线不隐藏标签或网格；`showsLabels` 仅清除该轴文字及相应测量留白。`showsGridlines` 原规则独立，次轴默认无网格。

`categoryLabelInterval` 是类目标签的**候选步长**，不是数据抽样、网格或数值刻度间隔。nil/非正数自动；正数以原始绝对索引取模。为防止重叠，空间不足时按显式步长的整数倍抽稀（例如设 3、自动需 5，则实际 6）。平移不从窗口首项重新计数。仅类目轴消费；Bar 映射为左侧类目行。旋转仍仅垂直图底部类目标签，非有限角度按 0。

## 边界与可读性

- 各轴按自身字体/formatter 测量，不再都用同一主题字体。
- 左右总边带至多消耗可用宽度 60%，底部文字至多消耗可用高度 40%；极窄宽度保留 plot。
- 文字锚点保持在真实刻度/类目中心；在最终边带中尾部截断，旋转按包围盒限宽。
- 放不下一行或与已保留文字碰撞则省略，不缩小调用方指定字体；值轴自定义密集刻度也按此规则处理。
- 图例仍独立预留位置，文字只使用自己的布局预算，不借用图例空间。
- 标签隐藏会扩大 plot，因而数据的**屏幕位置随新布局重算**；数学域、原始索引、datum 和命中值不改变，命中矩形跟随新几何。固定柱宽模式可因可用空间变化而显示更多类目，这是既有规则。

## Objective-C

```objc
model.xAxisStyle.labelColor = UIColor.systemPurpleColor;
model.xAxisStyle.labelFont = [UIFont boldSystemFontOfSize:16];
model.xAxisStyle.lineColor = UIColor.systemPurpleColor;
model.xAxisStyle.lineWidth = @2;
model.categoryLabelInterval = @2;
model.categoryLabelRotation = -35;
model.yAxisStyle.showsLabels = NO;
model.valueGridlines = @YES;
model.secondaryYAxisStyle.labelColor = UIColor.systemOrangeColor;
```

`xAxisStyle` / `yAxisStyle` / `secondaryYAxisStyle` 为非空 `HYMCartesianAxisStyle` 值对象；configure/update 转为 Swift 快照，改 OC 对象后需再次 update。`categoryGridlines` / `valueGridlines` / `secondaryGridlines` 为可空 NSNumber，nil 沿默认。Bar 启用次轴仍按已有校验报错，不能以隐藏轴样式绕过。

## 原有 Demo

四个既有图表页搜索“独立轴”，加载不同颜色/字体/标签步长预设。在类目轴、主值轴、次值轴分组分别修改：轴标签/轴线显示、独立颜色、字体、线宽。关闭“自定义…”恢复主题继承；“恢复默认配置”清空覆盖。类目轴另有显式步长、网格与旋转配置。

`AxisStyleTests` 覆盖四种渲染器、双轴/横向映射、隐藏后留白回收、域/数据不变、绝对索引步长、长文本/大字/窄宽/旋转、对象复用 1×/2×/3×、OC 快照及 Demo 真实 Binding。实际执行结果与截图见 [G2–G5 验证记录](charts-presentation-g2-g5-2026-10-02.md)，不以源码存在代替通过。

