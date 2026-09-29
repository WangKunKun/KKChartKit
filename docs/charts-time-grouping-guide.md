# 高密度柱状图：时间聚合与区间明细

2026-09-24。第一版支持 **Column / ColumnChart 的等间隔时间序列**。默认关闭；原始模型不被修改。

## 接入

```swift
let model = CartesianChartModel(
    series: [
        CartesianSeriesElement(name: "电量", data: energyValues, color: .systemBlue,
                              id: "energy", aggregation: .sum, unit: "kWh"),
        CartesianSeriesElement(name: "功率", data: powerValues, color: .systemOrange,
                              yAxisIndex: 1, id: "power", aggregation: .average, unit: "kW")
    ],
    secondaryYAxis: CartesianAxisModel(kind: .value),
    timeAxis: CartesianTimeAxis(start: startDate, interval: 300),
    timeGrouping: CartesianTimeGrouping(minimumColumnWidth: 4)
)

ColumnChart(model: model, playsAnimationOnAppear: false,
            isZoomEnabled: true, minimumVisibleCategories: 2)
    .frame(height: 340)
```

`interval` 单位为秒；每 5 分钟采样一天是 288 点。3000 点不等于一天，持续时间由起始时间和间隔决定。每系列共享采样时间网格，数组中缺测位置用 `.nan` 占位，不可删除缺测位置后把后续数据往前移。短系列尾部也按缺测统计。

时间刻度默认 `HH:mm`，跨多天数据增加日期；`timeAxis.timeZone` 决定显示时区，`timeAxis.labelFormatter` 可覆盖。已有显式 `xAxis.category(labels:)` 仍优先。这里只增加等间隔时间标签与区间模型，X 轴的底层坐标仍是原始采样索引，不是任意时间戳数值轴。

## 如何决定粒度

- 根据实际绘图区宽度、可见系列数及主题的柱宽/组间距计算单组宽度预算。堆叠按一组柱宽预算，并排按可见系列数量预算。
- `minimumColumnWidth` 是目标最小柱宽（pt），默认 4；小容器或最后一个不足完整区间的桶不保证达到该宽度。
- 选择能满足预算的 `preferredIntervals` 档位，默认 1/5/15/30 分钟、1/2/4/6/12/24 小时。档位向上取到完整采样数；超出最大档位时使用所需采样数。
- 所有系列使用相同区间边界，区间锚定 `timeAxis.start`；平移不会改变同一粒度下的桶边界。第一版不按日历整点重新对齐。
- 放大后重新选择更细档位，最细恢复每个原始点。轴/图例占宽发生变化时重新计算；先估算、再用实际绘图区宽度收紧预算。

当前按完整数据生成桶，再只绘制与视口相交的柱。桶边界不会随平移切掉一部分原始数据；末桶按实际点数计宽、计时长，部分可见的桶允许裁剪显示。viewport 始终使用原始索引，因此聚合变化不会把用户窗口移到错误日期。

## 每系列聚合配置

`series.aggregation` 支持 `.sum / .average / .min / .max / .last / .custom(name:reduce:)`。

```swift
let reducer = CartesianAggregation.custom(name: "范围") { samples in
    // samples 按时间排序，只含有限值；每项有 sourceIndex、date、value。
    guard let lo = samples.map(\.value).min(),
          let hi = samples.map(\.value).max() else { return nil }
    return hi - lo
}
```

- 缺失值和 Infinity 不当成 0；全缺测桶返回缺测，不调用 custom。返回 nil 或非有限结果也按缺测处理。
- `.average` 是有效采样的算术平均；等间隔模型适用。不提供不等间隔时间加权或累计电表复位处理。
- `.sum` 对正负数求净值，可能相互抵消；需要正负分开统计时请拆系列或关闭聚合，SDK 不擅自改变业务语义。
- 所有**可见**系列必须显式设置 reducer，否则整张图回退原始展示，避免不同系列区间错位。隐藏且未配置的系列不会阻止聚合。
- 恢复原始分辨率时直接使用原值，不执行 custom。custom 必须无副作用，布局/缩放会重新计算。
- 普通堆叠与百分比堆叠：先聚合各系列原值，再计算累计值/可见系列占比。仅应堆叠单位和统计口径相容的系列。
- 固定基准百分比 `.percentFixed` 堆叠回退原始展示，避免擅自把固定目标乘以区间长度。

纯数据入口 `CartesianTimeGrouper.group(model:theme:plotWidth:visibleRange:)` 返回 `status`、`samplesPerBucket`、`buckets`，供业务验证计算结果。`visibleRange` 单位为原始索引，例如完整 288 点为 `-0.5...287.5`。`buckets` 的第一维保持原始系列索引，隐藏系列为空数组。

状态包括 `.active(samplesPerBucket:)`、`.disabled`、`.invalidTimeAxis`、`.missingAggregation`、`.unsupportedStacking`、`.noVisibleSeries`。renderer 同样公开只读 `timeGroupingStatus`；未开启聚合的 Line/Bar 保持 `.disabled`。

## 点击聚合柱与进入明细

`ColumnHitTarget.timeBucket` 和 shared entries 的 `timeBucket` 提供：

| 字段 | 含义 |
|---|---|
| `sourceRange` | 原始数组索引区间，右端不包含 |
| `interval` | 原始时间区间，按 `[start, end)` 解读 |
| `validSampleCount` / `expectedSampleCount` / `coverage` | 有效数、预期数与覆盖比例 |
| `value` | 该系列的区间统计值 |
| `minimum` / `maximum` | 桶内原始有限值的范围 |
| `aggregationName` / `unit` | 聚合方式与单位 |
| `isAggregated` | 此桶是否包含多个原始采样位置 |

`target.categoryIndex` 是桶首原始索引；`seriesIndex/seriesID` 继续指向原系列。旧 `target.value` 保留绘制值语义（堆叠时累计），聚合统计值请用 `target.aggregatedValue` 或 `timeBucket.value`。shared entry.value 为各系列统计值，不是累计值。

默认 tooltip 显示区间、聚合方式、有效采样数和单位；自定义数值模板也保留区间上下文。完全无值的桶不产生柱/命中。显式 0 值没有可见柱体，但可经 shared tooltip/吸附读取。

UIKit：

```swift
chart.onHit = { [weak chart] target, _ in
    if let bucket = (target as? ColumnHitTarget)?.timeBucket {
        // 可先在外部展示，再由“进入明细”按钮触发。
        chart?.showCategoryRange(bucket.sourceRange)
    }
}
chart.showCategoryRange(100..<124)
chart.resetViewport()
```

实际窗口仍遵守缩放下限；若每组系列很多，可调小 `minimumVisibleCategories` 以允许放大到更少点。窗口显式切换会停止旧动画/惯性并清除旧弹窗/准线。

SwiftUI：

```swift
@State var visibleRange: Range<Int>? = nil

ColumnChart(model: model, playsAnimationOnAppear: false,
    onHit: { target, _ in
        // 记录 target.timeBucket?.sourceRange，按需赋给 visibleRange。
    },
    isZoomEnabled: true, minimumVisibleCategories: 2,
    isSharedTooltipOnTapEnabled: false,
    visibleCategoryRange: visibleRange)
```

`visibleCategoryRange` 在初次创建或值变化时定位，改回 nil 恢复全量。普通更新不会反复覆盖用户后续手势窗口；显式 `.reset` 策略下会重新应用指定范围。此参数是定位命令，不是实时双向绑定。ColumnChart 的 typed onHit 处理单柱，因此示例关闭 shared tooltip；UIKit onHit 可直接接收 shared target。

## 演示、验证与边界

首页 → **柱状图**，在“数据与布局”选 288/1440/3000 点预设，在“高密度时间聚合”调节聚合策略；每个系列的 reducer、单位和主/次轴在“当前系列”中独立设置。总览/最近24点/所选区间位于预览下方。默认使用平均值，电量等累计指标请改为求和。详见 [统一调试页面](charts-demo-guide.md)。

Line/Column/Bar 的累计值、基准值、值域及时间刻度文本会在同一数据/主题版本的手势重排间复用。Column 聚合结果按粒度缓存，每个 renderer 最多保留三个最近使用的粒度；缓存与原始数据分离。

```swift
var grouping = CartesianTimeGrouping(minimumColumnWidth: 4)
grouping.isCacheEnabled = true
grouping.granularityHysteresis = 0.15  // 0 关闭，最大 0.5
model.timeGrouping = grouping
```

`isCacheEnabled = false` 可对照重算行为，统计值与命中映射不变。缓存仅在 renderer 自己的平移/缩放重排中复用；`configure` / `update`、图例显隐更新、外部 `render`（包括容器重新布局）都会失效，确保数据、reducer 捕获状态、单位、时间起点和样式变化不会沿用旧值。自定义 reducer 应保持无副作用；其捕获数据发生变化时必须调用 update。

粒度缓冲只影响有历史状态的缩放：放大时需要额外宽度才进入更细粒度，缩小时柱宽不足立即合并。大幅放大会进入有宽度余量的较细粒度，不会一直停在原来的粗粒度。纯函数 `CartesianTimeGrouper.group` 不使用历史缓冲，所以仍然是给定输入对应固定结果。

目前仍会重建轴标签和绘制图层；缓存不是帧率保证，也不是跨 update 的自动差量更新。

测试包括 reducer、缺测/短数组、总量守恒、尾桶时长、百分比、显隐、直接/共享/吸附命中、部分可见桶、进入明细/恢复总览、SwiftUI 范围命令和渲染截图。另记录 288/1440/2000/3000 点 × 1/3/6 系列 × 原始/聚合，共 24 组模拟器堆叠布局耗时。

测量明细保存于 [布局耗时 CSV](benchmarks/2026-09-24-column-layout-simulator.csv)。

耗时统计包含 UIView 创建/configure/layout，是单次 Debug 模拟器观测；不包含稳定滚动 FPS、GPU 提交时长或真机峰值内存，不作为性能承诺。

新增 [平移缓存对照记录](benchmarks/2026-09-24-column-pan-cache-simulator.csv)：3000 点、6 系列、预热后 30 次 renderer 平移，Debug 模拟器单次 CPU 计时，不含 GPU 呈现/实际触控帧率。

非堆叠直线/面积图的 [Min/Max 降采样](charts-line-sampling-guide.md) 已接入。下一步：真机手势性能测量、图层/标签复用及更丰富的采样组合。Bar 聚合、不等间隔时间戳、时间加权平均、日历对齐、正负拆桶与累计表复位暂未实现。

固定尺寸配合：`theme.columnSpacing` 生效时，容量预算包含固定组内/组间距；指定 `columnWidth` 时该宽度优先于 `minimumColumnWidth`，聚合末桶保留完整几何槽位而不补充原始数据。见 [固定布局指南](charts-fixed-column-layout-guide.md)。

迁移第 2 步：Column 的普通/百分比分组、`.grouped` 已支持按实际柱组数预算宽度。分桶保留 stackID、每系列 reducer；混合图暂不启用时间聚合。
