# 折线/面积颜色分区与曲线负值着色

更新：2026-09-29。适用于 `LineChartRenderer` 与 `CombinedChartRenderer` 的线族（line/spline/area/areaspline）。柱状/条形保留原有逐柱配色，不消费该配置。

## 配置与边界

`CartesianSeriesElement.colorZones` 默认 nil，可独立设置 `CartesianColorZones(axis:zones:)`。

- **X**：原始采样索引，允许小数。例如 3.5 在第 4 与第 5 个位置之间；不是日期时间戳、像素位置或降采样后的序号。
- **Y**：所属值轴上的绘制值，次轴使用次轴域；堆叠使用累计值，百分比堆叠使用百分比绘制值，而不是原始业务值。
- 区间从负无穷开始，依次为 `[前一上限, upperBound)`，等于阈值的采样点属于后一段。
- `upperBound: nil` 表示正无穷，只能是最后一段。未提供无上限末段时，剩余部分继承系列颜色/填充。
- 上限必须有限且严格递增。空数组、NaN/Infinity、重复/逆序阈值、非末段 nil 均使整份配置无效；`isValid` 可提前检查。无效配置回退旧的系列色/`negativeColor` 行为，不自动排序或部分应用。
- 有效显式分区优先于 `negativeColor`；区间内 `color: nil` 继承系列色，不重新触发负值规则。标记跟随区间线色，但主题的显式 `pointColor` 优先。图例仍表示系列，不自动扩展为分区图例。

## Swift 示例

```swift
let zones = CartesianColorZones(axis: .y, zones: [
    .init(upperBound: 0, color: .systemRed,
          areaGradientColors: [.systemRed.withAlphaComponent(0.4), .clear]),
    .init(upperBound: 50, color: .systemBlue),
    .init(color: .systemGreen,
          areaGradientColors: [.systemGreen.withAlphaComponent(0.3)])
])

var series = CartesianSeriesElement(
    name: "功率", data: [-30, 25, 60, 15, -40, -10, 45, .nan, 30],
    color: .systemBlue, colorZones: zones
)
series.style.lineConnectionStyle = .smooth
series.style.showsArea = true
series.style.fillOpacity = 0.8

var model = CartesianChartModel(series: [series])
// 已有图表通过 update(model:) 生效，默认保留视口。
// 关闭分区：model.series[0].colorZones = nil，然后再次 update(model:)。
```

每段分别配置线色和 `areaGradientColors`：

| 值 | 面积行为 |
|---|---|
| nil | 继承系列样式/主题渐变，没有指定时沿用系列色的默认渐变 |
| `[]` | 用该分区的线色生成默认渐变（alpha 0.35 → 0.04） |
| 一个颜色 | 纯色填充，保留颜色自身 alpha |
| 多个颜色 | 纵向渐变，保留颜色自身 alpha |

颜色 alpha 最后再乘系列 `fillOpacity`。所有分区的渐变都沿整个绘图区映射，不在分区边界重新从头渐变。仅指定线色，不会隐式改变面积颜色。

## 负值换色与路径保真

无有效显式分区时，`negativeColor` 等价于线条与标记的 Y=0 分区：支持直线、三种阶梯和平滑曲线。原有面积渐变不随 `negativeColor` 自动换色；负值面积需要显式分区填充。

绘制先按缺测策略构造完整路径，再用轴向矩形区间裁剪相同路径。不会为颜色交点重新估算曲线切线或插入数据。曲线、虚线相位与 strokeEnd 动画在所有区间共享相同路径；阴影只投射一次。全负值面积也正常闭合，不依赖是否存在正色线段。

## 与既有能力的关系

- autoGap 先在原始索引分段，再降采样，最后着色；颜色不会连接原本断开的缺测，也不会为阈值或缺测插入可命中点。
- 直线 Min/Max 采样按既有规则进行；X 分区始终使用原始索引。曲线/阶梯/堆叠仍不启用 Min/Max。
- 视口移动、缩放、尺寸变化、显隐切换和更新后重新计算可见裁剪区。远在视口外的阈值先求交再映射，不创建空分区层。
- 分区只改变外观：数据、聚合、值域、堆叠分母、原值/绘制值命中、图例布局不受影响。
- 启用/禁用 `reusesRenderingObjects` 结果一致；容器、线层、渐变与面积 mask 都参与池复用，未使用对象在帧末释放。
- 每个可见区间增加一份完整路径的着色层，面积覆盖时也增加渐变和 mask。分区不用于逐点万级调色；未做真机性能验收。
- 本次沿用既有堆叠面积下边界算法；**混合符号或缺测引起一段内基准链切换的复杂面积接缝仍是独立待办**，不是颜色裁剪能修复的几何问题。

## Objective-C

```objc
HYMCartesianColorZone *negative = [HYMCartesianColorZone new];
negative.upperBound = @0;
negative.color = UIColor.systemRedColor;
negative.areaGradientColors = @[[UIColor.systemRedColor colorWithAlphaComponent:0.4], UIColor.clearColor];

HYMCartesianColorZone *positive = [HYMCartesianColorZone new];
positive.color = UIColor.systemGreenColor;

HYMCartesianColorZones *zones = [HYMCartesianColorZones new];
zones.axis = HYMCartesianZoneAxisY;
zones.zones = @[negative, positive];

HYMCartesianSeries *series = [HYMCartesianSeries new];
series.data = @[@-30, @25, @60, [NSNull null], @30];
series.colorZones = zones;
series.style = [HYMCartesianSeriesStyle new];
series.style.connection = HYMCartesianLineConnectionSmooth;
series.style.showsArea = @YES;
```

`isValid` 与 Swift 使用同一校验。配置在 configure/update 时复制成 Swift 值；后续修改原 OC 对象不会隐式改变图表，需再次应用。设 `series.colorZones = nil` 可关闭；X/Y 含义与 Swift 相同。

## Demo 与验证

折线图和混合图原有调试页搜索 **zones** 可加载 X/Y 曲线面积与曲线负值三个预设；未新增图表入口。

- 搜索“颜色分区 zones”：逐系列选择关闭 / X 原始索引 / Y 绘制值。
- 搜索“分区”：调整阈值、阈值以下/以上线色，启用/关闭分区面积渐变。
- 关闭分区恢复系列色与 `negativeColor`；恢复默认配置清除本系列分区。

测试覆盖配置校验、精确阈值与继承、完整曲线路径、像素颜色、全负值面积、渐变坐标/alpha、标记优先级、缺测、采样视口、堆叠/百分比/双轴、混合柱线、复用与显隐、OC 快照、Demo 绑定和 UI 预设。最终执行结果见 [能力清单](charts-capability-status.md)。
