# KKChartKit / HYMCharts

[English](README.en.md)

面向 iOS 的原生 Swift 图表模块。仓库中的公开类型目前使用 `HYM` / `Cartesian` 前缀，核心绘制采用 UIKit / Core Animation，提供 SwiftUI 封装和 Objective-C 桥接。

当前仓库是源码与可运行 Demo 工程，尚未发布独立 Swift Package、CocoaPod 或 XCFramework。 已提供 [HYMCharts.framework 独立接入验证工程](Examples/ChartsIntegration/README.md)，Swift/纯 Objective-C 宿主通过 Debug/Release，正式旧输入适配仍待实现。项目最低部署版本为 iOS 15；历史验证包括 Xcode 26.3／iOS 17.2 模拟器，2026-10-09 的布局补充使用 iOS 18.6（详见下方进度）。不要将验证环境理解为所有系统版本均已验收。


2026-10-09 补充 [N4 固定顶部提示布局质量](docs/charts-neutral-tooltip-layout-task-progress-2026-10-09.md)：原生新增默认关闭的 `fixedTopUsesPlotArea`，N4 fixedTop 自动启用，避开标题／图例／轴标签区；仍覆盖绘图区数据，不增加 JSON 字段或预留区域。

2026-10-09 新增 [N4 Tooltip／图例（schema v6）](docs/charts-neutral-interaction-task-progress-2026-10-09.md)：提示内容、逐系列规则、类目槽位前值与边界政策、图例布局／标题；默认 v1 与 v1–v5 样例保持不变。图片／回调留宿主，不含动态组名、业务小计或 G6。

2026-10-09 新增 [N3 值轴标线/色带（schema v5）](docs/charts-neutral-annotations-task-progress-2026-10-09.md)：稳定值轴 ID、显隐、线型及标签样式，复用原生固定层次；默认 v1 与 v1–v4 JSON 保持兼容。版本规则与边界见 [模型指南](docs/charts-neutral-model-guide.md)，不包含 G6 坐标扩展或旧输入 mapper。

## 已有功能

| 图表/能力 | 当前范围 |
| --- | --- |
| 折线与面积 | 直线、平滑曲线、三种阶梯、正负值、缺测策略、连续颜色分区 |
| 柱状与条形 | 并排、分组堆叠、百分比/固定基准堆叠、固定柱宽和间距、溢出滚动 |
| 混合图 | 柱、线、曲线、面积共用坐标轴、图例与命中 |
| 雷达与热力图 | 独立模型、主题、命中、弹窗与 SwiftUI/OC 接口 |
| 轴系数据 | 稳定系列 ID、双轴（Bar 除外）、原值/累计值分离、业务组、每系列格式 |
| 高密度 | 非堆叠直线 Min/Max 降采样；Column 等间隔时间聚合；图层/标签复用 |
| 提示与图例 | 共享提示、分组小计、图标/分栏、逐点展示规则、前值/偏移/置顶、超高滚动、图片/自定义图例、布局测量 |
| 交互 | 缩放、平移、准线、显隐、区间定位、更新保留视口、自定义弹窗 |

详细进度以 [能力清单](docs/charts-capability-status.md) 为准。

2026-10-03 新增 [通用模型与适配层](docs/charts-neutral-model-guide.md)：业务使用仅依赖 Foundation 的 `ChartSpecification`，通过 `HYMChartsSpecificationAdapter` 转换到原生图表。支持 Swift 与 OC JSON 快照，其他图库按同一协议接适配器；当前不宣称已完成第三方库适配或旧模型自动迁移。

## 运行和源码接入

1. 用 Xcode 打开 `SwiftFunctionProject.xcodeproj`。
2. 选择 `SwiftFunctionProject` scheme 和 iOS 模拟器运行。
3. 首页每种图表对应一个属性调试页，可搜索配置、切换预设、查看命中数据。

接入已有项目时，将 `SwiftFunctionProject/Charts` 的所需源码加入 App 或自行维护的 framework target，并保持目录依赖。`Charts/SwiftUI` 包含封装与 Demo，按需选择；不需要 SwiftUI 时可仅采用其余 UIKit 图表代码。不要把 `SwiftFunctionProject/参考图表` 加入构建，它是旧模块参考源码，已从当前 App target 排除。当前没有 `import KKChartKit` 对应的已发布模块。

所有图表 UIView、主题更新、测量和交互操作均在主线程执行。系列 ID 应非空、唯一且跨更新稳定。

## SwiftUI：一张折线图

```swift
import SwiftUI

struct EnergyChart: View {
    private let model = CartesianChartModel(
        title: "功率",
        series: [
            .init(name: "光伏", data: [100, 150, .nan, 180],
                  color: .systemOrange, id: "solar", unit: "W"),
            .init(name: "电池", data: [-40, 20, 35, 50],
                  color: .systemBlue, id: "battery", unit: "W")
        ],
        xAxis: .init(kind: .category(labels: ["08:00", "08:05", "08:10", "08:15"]))
    )

    var body: some View {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.showsTooltipOnHit = true
        return LineChart(model: model, theme: theme,
                         isZoomEnabled: true,
                         isSharedTooltipOnTapEnabled: true)
            .frame(height: 320)
    }
}
```

使用同一轴系模型可以切换 `ColumnChart` 或 `BarChart`。混合图使用 `CombinedChart` 并指定每条系列的 `kind`。缺测必须保留 `.nan` 占位，不要删除数组位置。

## UIKit：配置、更新和命中

```swift
let chart = HYMChartView<LineChartRenderer>(frame: .zero)
// 用 Auto Layout 或 frame 为 chart 分配非零尺寸，再加入父视图。
var model = CartesianChartModel(series: [
    .init(name: "功率", data: [100, 120, 90], id: "power", unit: "W")
])
var theme = CartesianChartTheme()
theme.legend.isEnabled = true
theme.showsTooltipOnHit = true
chart.showsTooltipOnHit = true
chart.configure(model: model, theme: theme)
chart.isZoomEnabled = true
chart.isSharedTooltipOnTapEnabled = true
chart.onHit = { target, _ in
    let rows = (target as? CartesianHitDataSource)?.chartData ?? []
    for row in rows {
        // row.rawValue: 原始采样；聚合时为 nil。
        // row.displayValue: 原值或聚合统计，用于业务展示。
        // row.drawValue / stackBase: 绘图终点/起点，不是系列自身的数值。
        _ = row.formattedValue
    }
}
model.series[0].data = [110, 130, 95]
chart.update(model: model, viewportPolicy: .preserve)
chart.showCategoryRange(0..<2)
chart.setSeriesVisible(false, for: "power")
chart.resetViewport()
```

首次 `configure` 会重置视口与局部显隐；日常更新使用 `update`。SwiftUI 根据稳定 ID 保留系列身份。[更新规则](docs/charts-update-guide.md) · [命中数据语义](docs/charts-data-semantics-guide.md)

## 堆叠、混合图与双轴

```swift
var model = CartesianChartModel(series: [
    .init(name: "光伏", data: [100, 120], id: "solar", kind: .column, stackID: "supply"),
    .init(name: "电池", data: [50, 40], id: "battery", kind: .column, stackID: "supply"),
    .init(name: "目标", data: [160, 170], yAxisIndex: 1,
          id: "target", kind: .spline, participatesInStack: false)
], secondaryYAxis: .init(kind: .value), stacking: .normal)
// SwiftUI: CombinedChart(model: model)
// UIKit: HYMChartView<CombinedChartRenderer>
```

相同值轴、图形族和 `stackID` 才互相堆叠。正负分别累计；百分比按组计算。`groupID` 仅用于业务展示，不参与堆叠。每系列 `style` 优先于图形预设和主题。[混合与堆叠指南](docs/charts-combined-and-stacks-guide.md)

## 高密度、缺测与固定尺寸

```swift
// 旧宽度模式完整保留，是启用采样后的默认行为。
var sampling = LineChartSampling()
sampling.bucketWidth = 2
sampling.minimumVisiblePoints = 500 // 启动门槛，不是保留点数
theme.lineSampling = sampling
// 可选：每系列、当前视口目标 200 点；端点/极值保护可能超额。
theme.lineSampling?.targetPointCount = 200
// 恢复宽度模式：
theme.lineSampling?.targetPointCount = nil

model.series[0].gapPolicy = .autoGap(maximumMissingPoints: 12)
// Column / Bar / Combined：固定柱尺寸，超出容器自动滚动。
theme.columnSpacing = .init(columnWidth: 12, inner: 4, group: 16)
```

采样只减少绘制点，不改原始值、值域或命中。缩放会从原始数据重新选择；曲线、阶梯、堆叠目前回退原始绘制。Column 时间聚合需 `model.timeAxis`、`model.timeGrouping` 和每条可见系列的 `aggregation`；与折线降采样是不同能力。

[折线采样](docs/charts-line-sampling-guide.md) · [缺测](docs/charts-gap-policy-guide.md) · [颜色分区](docs/charts-color-zones-guide.md) · [时间聚合](docs/charts-time-grouping-guide.md) · [固定尺寸](docs/charts-fixed-column-layout-guide.md)

## 分组提示与图例

```swift
model.groups = [.init(id: "energy", name: "能源")]
model.series[0].groupID = "energy"
chart.tooltipTextOptions.cartesian.groupsByBusinessID = true
chart.tooltipTextOptions.cartesian.showsGroupSubtotals = true
chart.tooltipTextOptions.cartesian.hidesZeroValues = true

theme.legend.itemOverrides["solar"] = .init(
    image: UIImage(systemName: "sun.max.fill"),
    hiddenImage: UIImage(systemName: "sun.max"),
    backgroundColor: .secondarySystemBackground, cornerRadius: 6)
theme.legend.startsNewRowPerGroup = true
chart.update(model: model, theme: theme)
```

小计默认关闭，仅汇总同组、同单位/轴/格式的至少两条原始采样，不自动汇总聚合值。图片和自定义符号使用固定 `symbolSize`，公开测量与真实排版一致。完整示例见 [分组提示与图片图例](docs/charts-grouped-presentation-guide.md)；外部弹窗接口见 [弹窗指南](docs/charts-popup-guide.md)。

分栏和逐点展示可在内置提示中启用：

```swift
var presentation = CartesianTooltipPresentation()
presentation.layout = .columns
presentation.rowStyleProvider = { datum in
    .init(image: UIImage(systemName: "bolt.fill"),
          hidesValue: datum.seriesID == "standby")
}
chart.cartesianTooltipPresentation = presentation
```

过滤和仅名称规则不改变命中原值；仅名称行不参与小计。名称/数值自动换行，超高内容内部滚动。SwiftUI 和 OC 同步支持，详见[富内容提示指南](docs/charts-rich-tooltip-guide.md)。

前值和固定顶部使用独立配置，命中回调仍为当前采样：

```swift
var selection = CartesianTooltipSampleSelection()
selection.offset = -1
selection.boundaryPolicy = .clamp
chart.cartesianTooltipSampleSelection = selection
chart.tooltipTheme.position = .fixedTop
chart.tooltipTheme.offset = CGPoint(x: 12, y: 0)
```

逐系列覆盖、越界/缺测和聚合限制见[前值与置顶指南](docs/charts-tooltip-selection-guide.md)。

## Objective-C

在同一 App target 中导入 Xcode 生成的 `YourProductModuleName-Swift.h`，当前 Demo 对应 `SwiftFunctionProject-Swift.h`。持有 bridge，在主线程配置：

```objc
HYMCartesianSeries *series = [HYMCartesianSeries new];
series.identifier = @"solar";
series.name = @"光伏";
series.unit = @"W";
series.data = @[@100, @150, NSNull.null, @180];
HYMCartesianModel *model = [HYMCartesianModel new];
model.series = @[series];
HYMCartesianChartViewBridge *bridge = [[HYMCartesianChartViewBridge alloc]
    initWithKind:HYMCartesianChartKindLine frame:CGRectMake(0, 0, 350, 300)];
[self.view addSubview:bridge.chartView];
NSError *error = nil;
if (![bridge configureWithModel:model error:&error]) {
    // 将 error 交给项目统一错误处理。
}
// 将 bridge 保存到属性，以接收后续回调和更新。
```

`onHit` 返回 `HYMCartesianDatum` 数组；非法配置通过 NSError 报告。复制配置后修改 OC 模型或 bridge 展示选项，需要再次调用 update。现有桥接不是全部 Swift Theme 属性的完整镜像。[OC 和数据语义指南](docs/charts-data-semantics-guide.md)

## 文档与测试

- [Demo 使用与属性搜索](docs/charts-demo-guide.md)
- [折线指南](docs/charts-line-guide.md)、[柱状/条形指南](docs/charts-column-guide.md)
- [图例尺寸与显隐](docs/charts-legend-guide.md)、[绘制对象复用](docs/charts-rendering-reuse-guide.md)
- [折线 Demo 审计](docs/charts-line-demo-audit-2026-09-29.md)、[堆叠面积接缝边界](docs/charts-stacked-area-seams-guide.md)
- [旧模块迁移评估](docs/charts-legacy-module-migration-audit.md)、[路线图](docs/2026-09-24-charts-status-and-roadmap.md)
- 雷达/热力图的用法及设计记录位于 [docs/superpowers/specs](docs/superpowers/specs)。

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj \
  -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath /tmp/KKChartKit-build \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

当前限制：混合图/Bar 自动时间聚合、曲线/堆叠采样、不等间隔 XY、通用卡片/选点联动/全屏与独立 SDK 分发仍待后续。堆叠面积在不存在共同底边的正负/缺测过渡区间不保证全域无缝。详细验证范围及历史结果见各指南。


## 图表展现配置（2026-10-02）

G2–G5 已同步 UIKit/SwiftUI 主题、Objective-C 桥接与现有 Demo：柱/条阈值整段换色（raw/draw）、各轴独立样式与类目间隔、参考线/色带标签样式及数据标签避让、默认关闭的点/柱/条主体选中反馈。不会静默改变原始数据、堆叠语义或命中身份。

[Color zones](docs/charts-color-zones-guide.md) · [Axis styles](docs/charts-axis-style-guide.md) · [Annotations](docs/charts-annotation-style-guide.md) · [Selection](docs/charts-selection-style-guide.md) · [Validation and boundaries](docs/charts-presentation-g2-g5-2026-10-02.md)
