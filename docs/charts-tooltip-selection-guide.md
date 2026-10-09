# 提示前值、索引偏移与固定顶部

2026-09-30，旧模块迁移第 4 阶段的第三个子项。Line / Column / Bar / Combined 的内置提示可以选择相邻原始采样值，通用提示外壳可以固定于图表顶部或调整屏幕位置。默认取当前值、自动沿锚点放置，兼容原有调用。

## 取值与命中分开

```swift
var selection = CartesianTooltipSampleSelection()
selection.offset = -1
selection.offsetsBySeriesID = ["temperature": 0]
selection.boundaryPolicy = .clamp
selection.sourceLabelTemplate = "取值 {key}"
chart.cartesianTooltipSampleSelection = selection
chart.showsTooltipOnHit = true
chart.isSharedTooltipOnTapEnabled = true

var tooltipTheme = HYMChartTooltipTheme()
tooltipTheme.position = .fixedTop
tooltipTheme.fixedTopUsesPlotArea = true // 可选：避开轴系标题、图例和轴标签；原生默认 false
tooltipTheme.offset = CGPoint(x: 12, y: 0)
tooltipTheme.fixedTopInset = 8
chart.tooltipTheme = tooltipTheme

var presentation = CartesianTooltipPresentation()
presentation.layout = .columns
chart.cartesianTooltipPresentation = presentation

// 四个轴系 SwiftUI 包装创建和更新时均透传这些参数。
LineChart(model: model, isSharedTooltipOnTapEnabled: true,
          cartesianTooltipPresentation: presentation,
          cartesianTooltipSampleSelection: selection, tooltipTheme: tooltipTheme)
```

`offset` 是原始数组索引差：-1 前一采样，+1 后一采样，0 当前采样；稳定 `series.id` 的 `offsetsBySeriesID` 覆盖全局配置，显式 0 可保留该系列当前值。逐点、吸附与共享提示使用同一链路。该选择只影响内置提示的数值，不改变图形、准线、表头或 `onHit` 的命中索引及 raw/draw/base/percentage。

例如命中 08:05 的光伏 120 W、电池 20 W，偏移 -1 后提示显示 08:00 的 100 W、-40 W，小计为 60 W；表头仍为 08:05，回调光伏原值仍为 120。默认在发生偏移的行名后显示“取值 08:00”，避免混淆来源。`showsSourceLabel = false` 可隐藏说明，`sourceLabelTemplate` 可本地化，空模板省略说明，`{key}` 替换为来源类目标签。

边界和缺测行为明确区分：

| `boundaryPolicy` | 索引越过系列首尾 |
| --- | --- |
| `.omit`（默认） | 省略该行；所有行省略时隐藏提示，命中与准线继续保留 |
| `.clamp` | 取该系列首/末位置；-1 加 clamp 对应旧 `showPrev` 的首值重复行为 |
| `.current` | 该行使用当前命中值 |

边界按每条系列自身长度计算。指定位置为 NaN/Infinity 时始终省略，不向前搜索有效值；当前命中缺失的系列也不会凭空加入提示。整数偏移溢出按越界处理。来源可以位于当前可见窗口之外，无须移动视口。零值过滤依据实际展示值；仅名称和逐点隐藏规则沿用[富内容提示指南](charts-rich-tooltip-guide.md)，provider 接收当前命中 datum。

组小计依据实际展示快照计算，仍要求至少两条原始采样具有相同单位、值轴、格式和源范围。同组使用不同偏移而落到不同来源索引时不合计。实际时间聚合（stride > 1）保留当前区间统计，整个提示不使用单点偏移，含末尾仅一个原始点的桶；恢复原始粒度后重新应用偏移。此功能不将统计桶的数组位置当成原始采样。

## 展示快照与自定义 UI

```swift
chart.onHit = { [weak chart] target, _ in
    guard let content = chart?.cartesianTooltipContent(for: target) else { return }
    // content.text 与内置提示使用相同解析、过滤、格式和分组结果。
    print(content.text)
}
```

`CartesianTooltipContent.Row.datum` 保留当前命中，`displayedDatum` 为实际取值快照，`sourceLabel` 为来源说明；小计行两个 datum 均为 nil。`CartesianTooltipContent.make(data:...)` 没有模型解析能力，仍表示直接展示传入数据；要复用偏移结果，使用容器的 `cartesianTooltipContent(for:)`，或 renderer 的 `CartesianTooltipSampleProviding.tooltipSamples` 与 `make(samples:...)`。使用当前命中 target，不跨模型版本缓存它。

四个轴系 renderer 基类已经实现取值协议。自定义 renderer 未实现该协议时，容器保留传入值。外部 `popupContentProvider` / `onHitLocated` 接管时不会自动套用内置取值规则，可自行调用内容接口。

## 位置策略

| `HYMChartTooltipTheme` 字段 | 默认 | 行为 |
| --- | --- | --- |
| `position` | `.automatic` | 沿锚点选择上/下；`.fixedTop` 默认使用图表 bounds 顶部 |
| `fixedTopUsesPlotArea` | false | fixedTop 时，轴系使用最终绘图区与 bounds 的交集；不预留空间，automatic 不使用 |
| `offset` | `.zero` | 屏幕坐标 pt 偏移，正 x 向右、正 y 向下；两种策略均支持 |
| `fixedTopInset` | 8 pt | 固定顶部距容器 minY 的间距；automatic 不使用 |

`.fixedTop` 水平居中后叠加 offset，使用 minY + fixedTopInset + offset.y，最终约束于容器边界。它忽略锚点方向和 gap，并隐藏箭头；下一次命中仍更新内容，不锁定选择。容器边界或主题变化后，下一次 layout 重新测量已显示的置顶内容，不重复入场动画；模型更新仍清理旧提示。

`.automatic` 在偏移后选择上/下并执行原有贴边规则，箭头仍指向真实锚点。非有限 offset 分量按 0，负/非有限顶部间距按 0；非法尺寸和容器不显示。

原生默认的固定顶部提示宽高受 bounds 限制；设置 `fixedTopUsesPlotArea = true` 后，四种轴系使用最终绘图区与 bounds 的交集，顶部间距与 offset 相对该容器并限制在其中。该开关不缩小绘图区、不修改坐标或命中，标题／图例及轴标签区不再被内置置顶提示覆盖。无绘图区能力的 renderer（如 Radar/Heatmap）回退到 bounds；绘图区无效或坍缩时隐藏，不回退到标题区，恢复布局后的下一次真实命中可重新显示。直接使用低层 `HYMChartTooltipController` 时仍尊重调用方传入的容器，不自行推断绘图区。

固定顶部提示的宽高受所选容器限制。columns 布局超高时内部滚动；普通 text 布局保持触摸透传，超高文本截断，因此多行/多组内容建议选择 columns。低层自定义内容须实现 `sizeThatFits`，交互仍由 `allowsContentInteraction` 决定。原生默认仍可能覆盖标题／图例；选择绘图区边界后仍可能覆盖数据，操作图表时需在提示外开始手势。此子项没有关闭按钮、拖动避让、抬手隐藏或超时消失配置。

## Objective-C 与 Demo

```objc
bridge.tooltipOptions.sampleOffset = -1;
bridge.tooltipOptions.sampleOffsetsBySeriesID = @{@"temperature": @0};
bridge.tooltipOptions.sampleBoundaryPolicy = HYMCartesianTooltipSampleBoundaryPolicyClamp;
bridge.tooltipOptions.showsSourceLabel = YES;
bridge.tooltipOptions.sourceLabelTemplate = @"取值 {key}";
bridge.tooltipOptions.position = HYMCartesianTooltipPositionFixedTop;
bridge.tooltipOptions.fixedTopUsesPlotArea = YES;
bridge.tooltipOptions.offset = CGPointMake(12, 0);
bridge.tooltipOptions.fixedTopInset = 8;
NSError *error = nil;
[bridge updateWithModel:model preserveViewport:YES error:&error];
```

修改后 configure/update 复制选项，换回默认 options 会移除偏移和固定位置。OC“轴系验证”页面已调用这些接口，回调仍展示当前 raw/draw/base/percentage。

四个轴系页面搜索“前值与置顶”，加载“前值与置顶提示场景”：能源组取前值，温度/备用使用逐系列 0 覆盖，首项采用 clamp；图标分栏提示固定顶部。交互面板提供取值索引偏移、逐系列 ID:偏移（逗号分隔）、越界策略、显示来源和来源模板。弹窗外观面板提供 position、offset.x/y、fixedTopInset 和`fixedTopUsesPlotArea`（置顶限制在绘图区）开关。

外部接管或关闭提示时禁用内置取值控件；来源说明关闭时禁用模板；自动位置禁用 fixedTopInset 和 fixedTopUsesPlotArea，置顶禁用箭头和 gap。禁用保留原值，恢复默认清除配置。通用位置字段也适用于 Radar/Heatmap 提示。

## 2026-10-09 N4 布局质量补充

N4 通用适配的 `.fixedTop` 自动启用绘图区边界，JSON 不增加字段，仍为 schema v6；原生调用默认 false 保持旧行为。通用 tooltip 为 null／切回旧文档时，OC 桥恢复独立宿主选项基线。该补充不是专用提示预留区，也不承诺所有数据都不被遮挡；四 renderer、长内容、窄/宽尺寸、显隐与视口回归及公共宿主验证见[本轮进度](charts-neutral-tooltip-layout-task-progress-2026-10-09.md)。

## 2026-09-30 验证记录（历史）

环境为 Xcode 26.3（17C529）、iPhone 15 Pro / iOS 17.2 模拟器。最终完整 **256 项单元测试通过**，本轮新增 `TooltipSelectionTests` 13 项。最终新增 **1 项 UI 测试通过**，遍历 Line / Column / Bar / Combined，验证当前表头、回调 120、前值 100、组小计 60，以及顶部 8 pt 和调到约 20 pt 后的实际位置。

单元覆盖三种边界、整数溢出、精确缺测、不等长系列、隐藏系列、视口外来源、逐系列覆盖、来源本地化/关闭/空模板、展示零值过滤、不同来源不合计、实际聚合及单点尾桶、四类单点/共享一致性、自动偏移箭头、限高文本、置顶内容缩小后滚动、隐藏/更新清理，以及 OC / SwiftUI 配置更新和默认恢复。OC 位置更新保留已设置的字体外观。

面板审计 **257 项字段、2,793 次绑定读写、15² = 225 组场景切换、750 组渲染矩阵**通过。中英文 README、富内容与本指南的 Swift 示例通过当前模块 `swiftc -typecheck`；本地文档链接及 `git diff --check` 通过。

既有富内容/滚动和原有弹窗模式的 **2 项相关 UI 用例**在前一轮通过。该轮结果包整体因新增测试预期错误而失败：条形图触点误选了第三项；单点一致性用例要求所有系列取前值，却沿用了温度的显式 0 覆盖。修正触点，并为后一用例设置统一偏移后，最终 256 项单元及新四页面 UI 全部通过。没有重新运行全部 19 项 Demo UI 用例。

临时产物（未纳入 Git，清理后需重新生成）：

- 最终 256 项单元 + 新 UI：`/tmp/SwiftFunctionProject-selection-final-20260930.xcresult`，日志为同名 `.log`。
- 既有 2 项 UI 通过记录：`/tmp/SwiftFunctionProject-selection-verify-20260930.xcresult`；此包包含上述新增用例的失败，不能作为整体通过记录。
- 四页面各 2 张截图：`/tmp/SwiftFunctionProject-selection-evidence-20260930/`。已目视复核四类图表的提示、来源说明、分组小计及调整顶部间距后的布局。

本轮交付前值/索引偏移/固定顶部子项，未新增抬手隐藏、超时消失、外部表头联动、图例整行模板或第 5 阶段卡片/选点联动。未做真机、VoiceOver 人工走查或全配置像素金图验收。
