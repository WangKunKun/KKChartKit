# 内置图例、系列显隐与尺寸分配

> 2026-09-30：新增图片/隐藏态图片、自定义符号视图、背景和业务组换行；参见 [分组提示与图例指南](charts-grouped-presentation-guide.md)。

适用：`LineChart` / `ColumnChart` / `BarChart`，以及对应 `HYMChartView<Renderer>`。图例默认关闭，保持旧页面布局。实现于 2026-09-24。

## 最小接入

```swift
let model = CartesianChartModel(series: [
    CartesianSeriesElement(name: "发电量", data: [20, 35, 28],
                           color: .systemBlue, id: "solar"),
    CartesianSeriesElement(name: "用电量", data: [15, 25, 32],
                           color: .systemOrange, id: "consumption")
])
var theme = CartesianChartTheme()
theme.legend.isEnabled = true
theme.legend.position = .bottom

// UIKit
let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
chart.configure(model: model, theme: theme)
// 由父视图约束决定 chart 的宽高。

// SwiftUI：340 是整个图表（含标题、坐标轴、图例）的高度。
ColumnChart(model: model, theme: theme)
    .frame(height: 340)
```

`id` 应当是唯一且稳定的业务标识，不能用会随排序变化的数组索引。未传时生成 UUID，复制模型会保留；每次重新构造系列则会生成新 ID。因此 SwiftUI 在 `body` 或计算属性中重建模型时，请显式传 ID。重复 ID 会共享同一个显隐开关，不支持独立切换。

## 外部预先测量图例，设置整体高度

新增静态类方法，无需创建 UIView/renderer：

```swift
var theme = CartesianChartTheme()
theme.legend.isEnabled = true
theme.legend.position = .bottom
theme.legend.overflow = .expand // 完整展开；默认 .scroll 为限高滚动

let measurement = ChartLegendMeasurer.measure(
    model: model,
    theme: theme,
    availableWidth: chartWidth - theme.contentInset.left - theme.contentInset.right
)
let baseChartHeight: CGFloat = 280 // 不含图例；已经含标题、坐标轴和上下内边距
let totalHeight = baseChartHeight + measurement.additionalChartHeight
// SwiftUI: ColumnChart(model: model, theme: theme).frame(height: totalHeight)
// UIKit:   heightConstraint.constant = totalHeight
```

测量 API 与实际 renderer 共用排版引擎，单位均为 **pt**，建议在主线程调用。字体、图标尺寸、名称覆盖、图例顺序和 showsInLegend 都参与测量；isVisible 为 false 的项仍计入图例。横竖屏宽度变化、更改字体或内容后重新测量，使用容器实际宽度而非固定屏幕宽度。

| 返回字段 | 含义 |
|---|---|
| `contentSize` | 完整内容的自然宽高：最宽一行的内容宽度 × 全部行高度，含项间距/行距。长文字按可用宽度截断 |
| `size` | 当前 overflow 策略下需要预留的图例容器尺寸；上下图例占满 availableWidth 以便行对齐 |
| `rowCount` | 全部内容行数 |
| `isScrollable` | 展示高度是否不足以容纳完整内容 |
| `additionalChartHeight` | 上下图例的展示高度 + chartSpacing；无需再加间距，关闭/空图例为 0 |
| `additionalChartWidth` | 左右图例的展示宽度 + chartSpacing；上下图例为 0 |

`.scroll` 遵守 `maxRows/maxHeight`；`.expand` 忽略这两个上限，按完整内容给出建议高度。测量不会读取外部总高度，从而避免“先有高度才能测量”的循环。基础图表高度需足够容纳坐标轴、标题和最小绘图区；实际容器不足时 renderer 仍限制图例尺寸并滚动，测量结果不是强制撑大父视图的指令。

左右图例是并排关系，不能把两者高度直接相加。它们不追加总高度（`additionalChartHeight = 0`）；需要为图例预留水平空间，并让内容区域高度容纳图表与图例的较高者。左右测量还应考虑坐标轴和最小绘图区占用宽度，传入实际可分配的图例宽度预算。没有高度限制的上下图例是本接口最直接的使用场景。

演示页新增“测量图例并追加高度”开关，显示测得的完整内容尺寸。开启后高度滑条表示不含图例的基础图表高度，修改字号/系列数会自动增减总高度。

## 颜色、名称、形状如何定制

默认名称来自 `series.name`，颜色来自 `series.color ?? theme.seriesColor`。折线默认显示线条，开启 `showsPoints` 时显示线条加 marker，并跟随系列/主题的虚线和 marker 形状；柱/条默认使用圆角矩形。图例是系列的简化标识，不逐一表示负值换色、逐柱调色板、面积渐变或空心点细节。

```swift
theme.legend.symbolSize = CGSize(width: 24, height: 12)
theme.legend.font = .systemFont(ofSize: 13)
theme.legend.textColor = .secondaryLabel
theme.legend.itemOverrides["solar"] = LegendItemStyle(
    title: "光伏发电",
    symbol: .lineWithMarker(.diamond),
    symbolColor: .systemPurple
)
```

支持 `.line`、`.lineWithMarker(...)`、`.marker(...)`、`.rectangle`、`.roundedRectangle`。marker 支持圆、方、菱形、上/下三角。单项覆盖只修改图例；要同时改变图表主体颜色，应修改 `series.color`，图例即可自动跟随。

- `series.showsInLegend = false`：不显示该图例项，系列仍可绘制。
- `series.isVisible = false`：系列初始隐藏，图例项仍保留，方便点击恢复。
- `series.legendOrder`：数值小的排在前面；同值按原始系列顺序。不会改变绘制顺序或回调中的 `seriesIndex`。
- `theme.legend.allowsToggling = false`：图例仅展示。
- `theme.legend.hiddenAlpha`：隐藏项的透明度，默认 0.35。

## 整体高度如何分配

外部负责总宽高，内部先测量标题、坐标轴，再测量图例，最后确定绘图区。上下图例按宽度自动换行；左右图例按单列测量宽度。没有额外的 `layout = .flow` 配置项。

```text
外部总高度
├─ 上边距 / 标题
├─ 绘图区 + 坐标轴标签
├─ chartSpacing
├─ 图例（按可用宽度测量，限制可见高度）
└─ 下边距
```

| 配置 | 默认 | 语义 |
|---|---:|---|
| `position` | `.bottom` | `.top/.bottom/.left/.right` |
| `alignment` | `.center` | 上下图例每行的 `.leading/.center/.trailing` 对齐 |
| `itemSpacing` / `rowSpacing` | 16 / 4 | 项间距 / 行间距 |
| `symbolTextSpacing` | 6 | 图标与文字的间距 |
| `chartSpacing` | 8 | 图例与图表内容的间距 |
| `overflow` | `.scroll` | 限高滚动；`.expand` 完整展开并忽略 maxRows/maxHeight |
| `maxRows` | 3 | 图例可见行数上限，至少按 1 行计算 |
| `maxHeight` | 120 | 图例可见高度上限；内容较少时取实际高度 |
| `maxWidth` | 140 | 左右图例宽度上限，实际宽度根据内容测量 |
| `minimumPlotSize` | 80 × 80 | 图例预留空间时尽量保证的最小绘图区 |

每行高度为 `max(32, 字体行高/图标高度的较大值 + 8)`。图例的可见高度取实际内容、行数上限、`maxHeight` 和可用预算的最小值。多出的内容在图例内纵向滚动，长名称单行省略；无图例项时不预留间距。

如果连一整行都放不下，自动隐藏整个图例，优先保留绘图区。总尺寸本身不足以容纳坐标轴和最小绘图区时，SDK 不会自行撑大父容器。增加外部高度或减少字体/行数即可调整分配。左右布局保留宽度，上下布局保留高度；标题仍在顶部。

本版提供外部静态测量与完整展开模式，并支持图片和自定义 UIView 符号。仍没有自动 intrinsic height、固定比例分配、图内悬浮图例或任意整行模板；自定义符号固定在 symbolSize 内，详见分组展示指南。

## 点击、状态更新与外部控制

```swift
chart.onSeriesVisibilityChanged = { seriesID, isVisible in
    print(seriesID, isVisible)
}
chart.setSeriesVisible(false, for: "solar")
let visible = chart.isSeriesVisible("solar") // Bool?，不存在返回 nil
chart.resetSeriesVisibility()                // 恢复模型中的 isVisible
```

图例点击与 `setSeriesVisible` 走同一条更新路径：

1. 停止旧动画/惯性，清理选择、准线和弹窗。
2. 按 ID 记录显隐，保留类目视口；值轴窗口按新数据域钳制。
3. 隐藏系列退出绘制、命中、shared tooltip、自动值域、堆叠和总量标签计算。百分比模式重新计算可见系列分母；固定基准百分比保留原固定分母。
4. 分组柱/条重新分配可见系列槽位；原始 `seriesIndex` 不压缩。图例项不会因隐藏消失，全部隐藏后仍可恢复。

容器保留原始数据，渲染时用缺值占位屏蔽隐藏数据，保持系列与类目索引。自动类目数仍依据全部系列，隐藏最长系列不会缩掉类目轴；显式设置的值轴上下界继续生效。

- `update` 按稳定 ID 保留本地图例状态，包括重排和改名。
- 新模型显式改变某系列的 `isVisible` 时，该值覆盖本地状态。
- 移除系列会清理对应状态；以后重新加入同 ID，从新模型状态开始。
- `configure` 清除本地显隐并重置视口；`resetViewport` 只重置视口，不清理显隐。
- `resetSeriesVisibility` 恢复模型状态，不逐项发送回调。回调仅用于有效的点击/`setSeriesVisible` 变更。

三个 SwiftUI 组件均新增尾部可选参数 `onSeriesVisibilityChanged`，每次更新同步最新闭包，也支持移除。需要业务层完全持有显隐状态时，在回调里更新模型的 `isVisible`，如演示页所示。

```swift
LineChart(model: model, theme: theme,
          onSeriesVisibilityChanged: { id, visible in
              // 更新你的 @State / Observable 模型中对应系列的 isVisible。
          })
    .frame(height: 340)
```

逐点 target 新增 `seriesID`（SDK 生成的值非 nil）；shared entries 也提供 `seriesID`。旧的 `identifier` 字段语义暂时保留，跨更新业务关联请使用 `seriesID + 类目索引`。本步不跨更新恢复选中目标；原始值、累计值和百分比的显式多字段命中模型留待下一步。当前逐点堆叠命中/吸附报告累计绘制值，shared tooltip 报各系列原值。

## 验证与演示

App 首页 → **折线图 / 柱状图 / 条形图**：各页“图例布局”可调位置、对齐、字号、溢出策略与尺寸；“当前系列”可独立覆盖标题、颜色、符号与显隐。测量尺寸实时展示在“布局读数”。详见 [统一调试页面](charts-demo-guide.md)。

本步新增 `ChartLegendTests`，验证布局、显隐和模型更新；渲染截图用 XCTest attachment 保留。手势代理将图例触摸从图表 tap/pan/pinch 中排除，图例的 UIScrollView 负责自身滚动。尚未进行真机触摸或 VoiceOver 人工验收；无障碍名称和显隐状态已提供。
