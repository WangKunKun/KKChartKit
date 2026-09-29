# 数据语义、系列格式与最小 OC 接入

迁移第 1 步，2026-09-24。所有 UIKit 操作须在主线程；格式化值类型可在任意线程独立使用。不要并发修改 OC 配置对象。

## 命中数据

Line / Column / Bar 的逐点、吸附及共享命中均实现 `CartesianHitDataSource`。通过 `chartData` 获取 `[CartesianDatum]`，单点一项，共享命中包含该类目所有可见且有效的系列。

```swift
chart.onHit = { target, _ in
    guard let source = target as? CartesianHitDataSource else { return }
    for item in source.chartData {
        // 身份：seriesID / seriesIndex / categoryIndex
        // 业务组：groupID / groupName
        // 原始采样：rawValue；区间统计：aggregatedValue
        // 绘制终点：drawValue；堆叠起点：stackBase
        // 有符号占比：percentage；原始范围：sourceRange
        let text = item.formattedValue
        // 将 text / item.displayValue 交给业务 UI。
        _ = text
    }
}
```

| 字段 | 普通堆叠 100 + 50 的第二项 | 含义 |
|---|---|---|
| rawValue | 50 | 原始采样值；聚合项没有单个原始值，为 nil |
| aggregatedValue | nil | 聚合开启且桶含多个位置时为 reducer 统计结果 |
| displayValue | 50 | 原值或聚合值，用于 Tooltip；不取累计值 |
| drawValue | 150 | 绘制终点坐标值，不是屏幕像素 |
| stackBase | 100 | 绘制起点坐标值；非堆叠为 0 |
| percentage | nil | 只在 percent / percentFixed 下提供，单位是百分数而非 0...1 |
| sourceRange | 该点的单元素半开区间 | 聚合后变为原始采样区间，未压缩索引 |

percent 采用当前值轴下可见系列的绝对值之和为分母，保留各段正负号；例如 -100 与 -50 得到 -66.67% 与 -33.33%。percentFixed 使用固定基准，可超过 100%。零分母沿用当前渲染语义返回 0%。普通堆叠不擅自推断业务占比，percentage=nil。

例如 10 个原始采样平均成一根柱：rawValue=nil，aggregatedValue 为平均值，sourceRange 指向这 10 个位置，timeBucket 提供时间范围、有效数量、覆盖率、极值和 reducer 名称。放大恢复单点后 rawValue 重新提供单个采样值。缺测保持 NaN，不按零参与计算；缺测项不产生命中，真实 0 仍是有效数据。

兼容性：旧单点 target.value 保留历史绘制/累计值，shared entry.value 保留原值/聚合统计语义。新业务统一使用 chartData，不再依赖含义不同的旧 value。内置 Tooltip 和 tooltipRows 已改用 displayValue；自定义 View 回调也可以读取同一快照。手工创建的旧 target 未传 datum 时 rawValue/stackBase/percentage 为 nil，仍走旧文本回退，新增完整语义仅由 renderer 或显式 datum 提供。

## 业务组

```swift
let solar = CartesianSeriesElement(name: "光伏", data: [100, 200],
    id: "solar", unit: "W", groupID: "energy")
let battery = CartesianSeriesElement(name: "电池", data: [50, -50],
    id: "battery", unit: "W", groupID: "energy")
let model = CartesianChartModel(series: [solar, battery], stacking: .normal,
    groups: [.init(id: "energy", name: "能源")])
```

组元数据通过命中传给业务。组 ID 应唯一；Swift 模型重复 ID 采用首项，未找到名称则 groupName=nil。OC 入口拒绝重复/空 ID。

此处业务组不改变颜色、图例排布、绘制顺序或堆叠；不同单位可以归到同一业务组，但本步不自动求小计。组小计需明确同量纲、正负和聚合策略；结构化分组 Tooltip、图片图例、数学 stackID 在后续阶段实现。

## 每系列格式化

```swift
var format = CartesianValueFormat()
format.scale = .engineering           // none 或按原值选择 k/M/G
format.maximumFractionDigits = 2      // 实际钳制 0...12
format.rounding = .towardZero         // nearest / towardZero
format.showsAbsoluteValue = true      // 仅展示，不改变负轴绘制
format.currencySymbol = ""           // 金额可指定 ¥ / $ 等
format.localeIdentifier = "en_US"     // nil 使用当前系统地区
format.usesGroupingSeparator = true
var battery = CartesianSeriesElement(name: "电池", data: [-1250],
    id: "battery", unit: "W", valueFormat: format)
// 显示 1.25 kW，rawValue/drawValue 仍为 -1250。
```

配置独立存于每个系列，支持 W/Wh/%/温度/任意业务单位。工程进位是否启用由调用者决定，不根据单位名称猜测。货币符号属于展示前缀；金额负号位于货币符号前。小数尾零移除；nil/非有限值独立格式化返回“无数据”。

优先级：显式系列 valueFormat 优先于容器全局 valueDecimals/valueSuffix；未配置系列格式时沿用全局模板。未设置全局 suffix 时使用系列 unit。header 仍生效，聚合时间区间保留；相同区间标题不会重复输出。这一格式仅影响命中/Tooltip，不自动替代 Y 轴 formatter 或数据标签 formatter。

## 最小 OC 接入

桥接支持折线、柱状、条形，多系列、类目标签、业务组、每系列格式、主次轴范围、普通/百分比/固定基准堆叠、图例显隐、Tooltip、缩放和区间定位。Bar 暂不支持次值轴。

```objc
// 示例 App：#import "SwiftFunctionProject-Swift.h"
// bridge 要由页面强引用持有。
self.bridge = [[HYMCartesianChartViewBridge alloc]
    initWithKind:HYMCartesianChartKindColumn frame:CGRectMake(0, 0, 360, 300)];

HYMCartesianSeries *series = [HYMCartesianSeries new];
series.identifier = @"power";
series.name = @"功率";
series.unit = @"W";
series.data = @[@1250, NSNull.null, @"-500", @0];
series.valueFormat = [HYMCartesianValueFormat new];
series.valueFormat.engineeringScale = YES;

HYMCartesianModel *model = [HYMCartesianModel new];
model.categories = @[@"08:00", @"08:05", @"08:10", @"08:15"];
model.series = @[series];
self.bridge.onHit = ^(NSArray<HYMCartesianDatum *> *rows) {
    for (HYMCartesianDatum *row in rows) {
        // row.rawValue / drawValue / stackBase / percentage / formattedValue
    }
};
NSError *error = nil;
if ([self.bridge configureWithModel:model error:&error]) {
    [self.view addSubview:self.bridge.chartView];
} else {
    // 由宿主展示配置错误。
}
```

- NSNumber、严格可解析的数值字符串保留数值；NSNull、非法字符串、非有限数转为缺测并保留数组位置。
- configure 重置窗口；updateWithModel:preserveViewport:error: 可保留窗口。修改 OC 对象后需再次调用更新，renderer 使用 Swift 值模型快照。
- 显隐和回调以稳定系列 ID 为准。命中回调只在有效命中时触发，不作为取消选择事件。
- showCategoryRange: 使用 NSRange 半开区间；resetViewport 恢复总览；固定宽度情形的区间定位仍遵守现有视口语义。
- 最小桥接不是旧 HMAA 类名/方法签名的直接替代；暂未透传全部 Swift 样式、高密度、任意闭包或自定义弹窗。完整 OC facade 与独立 SDK 分发属于后续迁移步骤。

## Demo 和验证

三个现有轴系调试页均增加：单位、业务组 ID/名称、可关闭的每系列格式配置，以及“数据语义：100 + 50 堆叠”预设。原值/绘制值/起点/占比/组与索引范围显示在命中读数里。配置按稳定系列 ID 保存在同一页面，无新增同类型首页入口。

OC 真实调用入口：首页 → Objective-C 接入 → 轴系验证。一个页面切换三种图表、堆叠和格式预设；回调读数由 Objective-C 代码更新。

`CartesianDataSemanticsTests` 覆盖三图命中路径、正负/缺测/零、百分比分母与双轴、格式优先级、Locale、聚合源区间、降采样原值、OC 解析/配置校验/视口保留及生命周期。Demo UI 测试覆盖新增属性和 OC 回调；最终执行结果记录在能力清单中。

参考目录已按文件排除 App target 的编译和资源打包，仅作为迁移资料保留。新增参考文件时也应检查 target membership。
