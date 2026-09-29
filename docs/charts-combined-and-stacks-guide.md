# 混合图、分组堆叠和系列独立样式

2026-09-24，旧模块迁移第 2 步。UIKit、SwiftUI 与最小 OC 桥接均已接入。UI 配置、更新、显隐及测量在主线程调用；Swift 值模型可独立构造，不要并发修改同一变量。

## 最小接入

```swift
var trendStyle = CartesianSeriesStyle()
trendStyle.lineWidth = 3
trendStyle.showsPoints = false

let model = CartesianChartModel(
    series: [
        .init(name: "A 光伏", data: [60, 80, 50], color: .systemBlue,
              id: "a-solar", kind: .column, stackID: "A"),
        .init(name: "A 电池", data: [20, 30, 25], color: .systemTeal,
              id: "a-battery", kind: .column, stackID: "A"),
        .init(name: "B 光伏", data: [30, 50, 20], color: .systemOrange,
              id: "b-solar", kind: .column, stackID: "B"),
        .init(name: "B 电池", data: [10, 20, 15], color: .systemYellow,
              id: "b-battery", kind: .column, stackID: "B"),
        .init(name: "目标", data: [90, 85, 95], color: .systemRed,
              yAxisIndex: 1, id: "target", kind: .spline,
              participatesInStack: false, style: trendStyle)
    ],
    secondaryYAxis: .init(kind: .value),
    stacking: .normal
)
var theme = CartesianChartTheme()
theme.legend.isEnabled = true
theme.columnSpacing = .init(columnWidth: 12, inner: 4, group: 16)

let chart = HYMChartView<CombinedChartRenderer>(frame: .zero)
chart.isSharedTooltipOnTapEnabled = true
chart.configure(model: model, theme: theme)
// 将 chart 加到父视图并设置非零布局尺寸。
// SwiftUI 同样使用：CombinedChart(model: model, theme: theme)
```

`CombinedChartRenderer` 先画柱，再画线族；同族按模型系列顺序，命中优先上层线族。只生成一套坐标轴、图例、视口和 shared tooltip。单点回调为 `ColumnHitTarget` 或 `LineHitTarget`，共享回调为 `CartesianSharedHitTarget`；可统一转换为 `CartesianHitDataSource` 读取 `chartData`。

## 三种 ID 的含义

| 字段 | 职责 |
| --- | --- |
| `id` / OC `identifier` | 唯一且稳定的系列身份；刷新、图例显隐使用 |
| `groupID` | Tooltip/图例的业务组元数据；不参与数学计算 |
| `stackID` | 数学堆叠组；在同值轴、同图形族内分别累计 |

`.normal`、`.percent`、`.percentFixed` 都支持 `stackID`。相同 ID 的柱段叠为一根，不同组并排。nil 表示默认组；空字符串是独立显式组，Demo 的空文本转 nil。没有开启堆叠时，每个可见柱系列仍独占一个槽。

- 正负链分别累计；NaN/无穷视为缺测，不当成零数据画柱或回传。
- 主次轴互不累计，也分别占据柱槽，避免两个轴的堆叠柱重叠。
- 柱族与线族永不混叠；line/spline/area/areaspline 属于同一线族。
- `participatesInStack = false` 保持原值、零基线且没有 percentage，可用于目标线或独立柱；默认 true 兼容旧行为。
- `.percent` 分母是同轴、同族、同组内可见且参与堆叠的有限值绝对值之和。正负共享此分母；`.percentFixed` 使用统一显式基准。
- 隐藏部分段重新累计；隐藏整组后释放柱槽。组顺序取当前模型中首次出现的可见系列。
- 原接口 `.grouped(groupCount:)` 已实现为普通堆叠：无显式 stackID 的系列按原始序号 `% max(1, groupCount)` 分区。隐藏不会改变序号分区；重排会改变，推荐稳定的显式 stackID。
- 命中快照保留 `stackID`、原始系列/类目索引、raw/draw/base/percentage；总量标签按组、轴、正负链分别显示原值合计。

## 每系列独立样式

`kind` 在混合图中支持 column / line / spline / area / areaspline；nil 按 column。折线渲染器也可用线族 kind 指定默认连线及面积开关；Column/Bar 固定画柱/条。

| `CartesianSeriesStyle` 字段 | 规则 |
| --- | --- |
| `lineConnectionStyle` | nil 继承类型/主题，否则直线、平滑、三种阶梯独立生效 |
| `lineWidth` | nil 继承主题；有限非负 pt |
| `showsPoints` / `pointRadius` | 标记显隐与半径，nil 继承主题 |
| `showsArea` | nil 继承类型/主题，显式值可覆盖 line/area 默认 |
| `areaGradientColors` | nil 继承主题；[] 恢复系列默认渐变；单色为纯色，多个颜色为垂直渐变 |
| `fillOpacity` | 0...1，与渐变色 alpha 相乘；nil 为 1 |

现有 `color`、`negativeColor`、`pointSymbol`、`lineDashStyle`、`connectNulls`、`shadow`、`dataLabelsEnabled` 继续逐系列生效。覆盖优先级为系列 style → kind 默认 → theme。赋值 `style = .init()` 恢复所有样式继承。连续同符号面积堆叠的下边界沿用前层连线形态；一段内因缺测或符号变化而切换基准系列时，仍按本段形态插值，复杂交替正负/缺测接缝需在下一阶段继续处理。曲线负值颜色及长短缺测策略属于下一阶段。

## 固定尺寸和密集数据边界

固定尺寸沿用 `CartesianColumnSpacing`，单位 pt：`columnWidth` 是每根堆叠柱的宽度；`inner` 是同类目下不同柱组之间的距离；`group` 是相邻类目之间的距离。线族不占柱宽槽。空间不足自动从最早区间滚动，`showCategoryRange` 定位起点；显式固定宽度时不能保证请求区间全部塞入一屏。

Column 单图的时间聚合现按实际柱组数计算宽度预算，保留各组 ID 与独立 reducer；普通/百分比分组及 `.grouped` 可用，`.percentFixed` 继续回退原始值。混合图本阶段**不启用时间聚合**，避免给柱与趋势线擅自套用同一个 reducer；固定尺寸滚动可用。折线 Min/Max 仍只针对非堆叠直线，曲线、阶梯、堆叠保持原始绘制。此阶段未做 2000/3000 点真机性能验收。

## Objective-C

```objc
HYMCartesianSeries *line = [HYMCartesianSeries new];
line.identifier = @"target";
line.kind = HYMCartesianSeriesKindSpline;
line.data = @[@90, @85, @95];
line.participatesInStack = NO;
line.marker = HYMCartesianMarkerDiamond;
line.style = [HYMCartesianSeriesStyle new];
line.style.lineWidth = @3;
line.style.showsPoints = @YES;

HYMCartesianChartViewBridge *bridge = [[HYMCartesianChartViewBridge alloc]
    initWithKind:HYMCartesianChartKindCombined frame:CGRectZero];
// model.series 传入柱及 line；柱系列使用 stackID，model.stacking = HYMCartesianStackingNormal。
```

`HYMCartesianSeriesStyle` 的 NSNumber 字段设 nil 恢复继承，connection 的 inherit 跟随默认；配置完成后调用 configure/update。新增枚举值追加，旧枚举的数值不变。OC `stackGroupCount` 与 grouped 模式对应；最小桥接尚不代表完整主题/旧 API 兼容层。

## Demo 验收入口

首页新增唯一“混合图”页。搜索“两组堆叠”应用双组柱 + 右轴目标曲线样例，点击查看原值；“当前系列”可切换图形、stackID、参与堆叠开关、线宽、标记、填充和透明度。折线/柱状/条形原有页也同步相应功能，全部可恢复继承。序号分组在“堆叠与双轴”面板。OC 轴系验证页新增“混合”切换。


## 验证记录

新增 18 项单元测试覆盖独立组/轴/图形族、正负缺测及短系列、组内百分比、显隐释放柱槽、Column/Bar/Combined 固定尺寸与命中、双轴 shared tooltip、渐变/标记覆盖及恢复、图形切换清理、组总量与动画、2000 点区间定位、分组聚合、OC 字段快照、属性面板绑定、面积/柱段接缝。

最终 150 项单元测试通过；完整 8 项 Demo UI 回归通过，最后接缝修改后重新验证混合图和 OC 两项 UI。此处是模拟器功能验证，不代表真机性能或老项目迁移验收完成。
