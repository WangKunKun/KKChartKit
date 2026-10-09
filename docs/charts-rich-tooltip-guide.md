# 富内容提示与逐点展示规则

2026-09-30，旧模块迁移第 4 阶段的第二个子项。Line / Column / Bar / Combined 共用结构化提示数据，支持图标、名称/数值分栏、逐点改名/隐藏/仅名称，以及超高内容滚动。默认仍为原有文本布局。

## UIKit 与 SwiftUI

```swift
var presentation = CartesianTooltipPresentation()
presentation.layout = .columns
presentation.iconSize = 18
presentation.rowStyleProvider = { datum in
    var style = CartesianTooltipRowStyle()
    style.image = UIImage(systemName: datum.seriesID == "solar" ? "sun.max.fill" : "battery.100")
    // 聚合后的 categoryIndex 不是原始索引。单点规则明确排除聚合项。
    if datum.rawValue != nil, datum.sourceRange.count == 1 {
        style.title = "\(datum.name) · \(datum.sourceRange.lowerBound + 1)"
        style.isHidden = datum.seriesID == "battery" && datum.sourceRange.lowerBound == 0
    }
    style.hidesValue = datum.seriesID == "standby"
    return style
}
chart.cartesianTooltipPresentation = presentation
chart.tooltipTextOptions.cartesian.groupsByBusinessID = true
chart.tooltipTextOptions.cartesian.showsGroupSubtotals = true
chart.showsTooltipOnHit = true
chart.isSharedTooltipOnTapEnabled = true

// 四个轴系 SwiftUI 包装均支持此参数，并在 updateUIView 时同步/移除 provider。
LineChart(model: model, theme: theme, isSharedTooltipOnTapEnabled: true,
          tooltipTextOptions: chart.tooltipTextOptions,
          cartesianTooltipPresentation: presentation)
```

`rowStyleProvider` 在主线程执行，应保持无副作用，不强捕获 chart。可以按 `seriesID` 查表注入名称、图片和规则，nil 返回值沿用默认行；`title = nil` 沿用系列名称，空字符串则保留为空。图片由业务提供，库不假设资源在主 Bundle。

单点、吸附与共享提示使用同一条构建链路。所有样式只影响提示，不改变绘图、准线、数学堆叠、原始模型或 `onHit` 快照。可在模型更新前设置配置，也可仅修改展示选项，在下一次命中生效。要马上清除已显示的旧内容，可调用现有 `update`。

## 结构化快照与数值语义

`CartesianTooltipContent.make(data:options:presentation:header:)` 返回可读的 `header`、`sections` 和 `rows`。行包含 `title`、可选 `value`、`image`、原始 `datum`、实际取值 `displayedDatum` 和 `sourceLabel`；小计行 `datum == nil`、`isSubtotal == true`。`text` 是同一份内容的文本表示，适合外部读数与自定义 UI。

构建顺序：

1. 按全局 `excludedSeriesIDs`、`hidesZeroValues` 过滤。
2. 对剩余每行调用一次 provider，应用隐藏、标题和仅名称规则。
3. 按业务组 ID 首次出现顺序归组，空组不出现。
4. 从展示数值的行计算可选小计；仅名称行不参与。

全过滤时返回 nil，不保留空表头、小计或分组。分组、小计的单位/值轴/格式/索引/聚合限制沿用[分组展示指南](charts-grouped-presentation-guide.md)。隐藏行或数值后，不会通过小计暴露它们；剩余不足两条可计数原始采样时省略小计。

显式系列格式仍优先于全局小数位和后缀，主/次轴标识、聚合时间区间及覆盖率说明继续保留。原始名称与值保存在 datum 中。聚合项只代表区间统计，本模块不补点、寻找前值或把统计值冒充原始采样。

## 排版、滚动与兼容

| 配置 | 默认 | 含义 |
| --- | --- | --- |
| `layout` | `.text` | `.columns` 开启图标与名称/数值分栏 |
| `rowStyleProvider` | nil | 两种布局都应用逐点展示规则，只有 columns 显示图片 |
| `iconSize` | 16 pt | 正方形图片槽，等比缩放；任一行有图片时为所有行预留槽位 |
| `rowSpacing` | 4 pt | 行间距 |
| `columnSpacing` | 10 pt | 图标/文字及名称/数值间距 |
| `sectionSpacing` | 8 pt | 组间距 |
| `showsSectionSeparators` | true | 相邻分组间的分隔线，单组无分隔线 |

间距/图标尺寸为负数时按 0，非有限时使用默认值。内容复用 `tooltipTheme` 的字体、文字色、背景、边距、圆角、箭头和最大宽度。名称与数值可换行；可用文字宽度小于 120 pt 时自动将值移到名称下方，保留完整文字。

columns 外壳宽高受图表 bounds 限制，超高内容在内部 `UIScrollView` 滚动，不截掉最后几组；内容右侧固定预留 8 pt，避免滚动条遮挡数值。用户在内容区滑动时，图表自己的手势不会抢走滚动或改变选中点。该提示是浮层，允许覆盖图表和图例；可通过 tooltipTheme.position 选择固定顶部，见[前值与置顶指南](charts-tooltip-selection-guide.md)；尚无拖动避让或专门关闭按钮。手势在提示外开始时仍操作图表。

普通文本及既有自定义内容默认继续透传触摸。低层 `HYMChartTooltipController.show(contentView:...)` 新增默认关闭的 `allowsContentInteraction`，开启时按容器尺寸约束内容；自定义 view 仍须实现合适的 `sizeThatFits`。`animated: false` 可用于跟手更新；已经显示的自定义/富内容提示不重复播放入场动画。旧隐藏动画的完成回调不会隐藏后来显示的新内容。

外部 `popupContentProvider` / `onHitLocated` 优先级不变；它们接管时不使用内置结构化展示。移除 provider、切回文本或更新模型时清理旧内容视图。每次新命中从滚动顶部开始。

## Objective-C

```objc
bridge.tooltipOptions.layout = HYMCartesianTooltipLayoutColumns;
bridge.tooltipOptions.iconSize = 18;
bridge.tooltipOptions.rowStyleProvider = ^HYMCartesianTooltipRowStyle *(HYMCartesianDatum *datum) {
    HYMCartesianTooltipRowStyle *style = [HYMCartesianTooltipRowStyle new];
    style.image = [UIImage systemImageNamed:@"bolt.fill"];
    style.hidesValue = [datum.seriesID isEqualToString:@"standby"];
    if (datum.rawValue != nil && datum.sourceRange.length == 1) {
        style.title = [NSString stringWithFormat:@"%@ · %lu", datum.name,
                       (unsigned long)datum.sourceRange.location + 1];
    }
    return style;
};
NSError *error = nil;
[bridge updateWithModel:model preserveViewport:YES error:&error];
```

桥接将展示选项复制到 Swift 配置；修改属性/替换 block 后需 configure/update。不要在 block 中强捕获 bridge。OC Demo 的“轴系验证”已实际调用分栏与图片 API。

## Demo 与验收范围

四个轴系页面搜索“富内容提示”，加载“富内容提示与逐点规则场景”。它保留能源/环境/无组样本，添加图片、采样名称；备用项仅显示名称；温度在第二个采样的提示中隐藏，图形仍保留。

交互面板新增 7 个字段：提示内容布局、提示逐点规则预设、提示图标尺寸、提示行间距、提示列间距、提示组间距、提示组分隔线。规则预设包括默认、能源图标、逐点名称、隐藏偶数索引（从 0 开始）、仅名称、综合规则。文本布局禁用图标/间距等排版项；外部接管或关闭弹窗时禁用内置展示项，保留配置值。恢复默认会移除所有展示覆盖。

本次是第 4 阶段的继续交付；同日后续已增加前值/索引偏移/固定顶部，见[取值与位置指南](charts-tooltip-selection-guide.md)。仍不包括多个业务组横向并排、任意富文本、生命周期策略、图例整行模板，也不包含第 5 阶段的卡片/联动/全屏。

测试覆盖结构化快照、过滤顺序与回调次数、正负小计、仅名称、聚合源范围、四渲染器单点/共享一致性、OC 与 SwiftUI 更新/移除配置、多语言长名称、16 行/5 组的窄宽度滚动、旧隐藏动画竞态及 Demo 依赖。UI 测试在四个页面操作富内容预设、调整高度/行距并滚动至末行，保存截图。


### 2026-09-30 验证记录

环境为 Xcode 26.3（17C529）、iPhone 15 Pro / iOS 17.2 模拟器。完整单元回归 **243 项通过**，其中本轮新增 `RichTooltipTests` 9 项；相关 Demo UI 回归 **4 项通过**，覆盖分组图例、富内容与滚动、原有弹窗模式和六类图表基础面板。不是全部 18 项 Demo UI 测试重跑。

面板审计为 248 项字段、2,685 次绑定读写、14² = 196 组场景切换、750 组渲染矩阵。中英文 README 及本指南中的 Swift 示例均通过当前模块的 `swiftc -typecheck`；本地文档链接与空白检查通过。

已检查四类图表的提示截图，以及限高后滚动到末行的截图。UI 用例同时验证末行纵坐标实际移动、末行可访问、命中读数不变。初版 UI 场景受自动追加图例高度影响，没有真正触发滚动；已关闭追加高度并增加实际位移断言。视觉检查还发现滚动条靠近右侧数值，已统一预留 8 pt。

临时结果（未纳入 Git，清理后需重新生成）：

- 单元 + 4 项 UI：`/tmp/SwiftFunctionProject-rich-tooltip-final-20260930.xcresult`，日志为同名 `.log`。
- 清理辅助代码后的 243 项单元复核：`/tmp/SwiftFunctionProject-rich-tooltip-verify-20260930.xcresult`。
- 滚动条留白修正后，9 项富内容单测与 1 项遍历四页面的滚动 UI 再次通过：`/tmp/SwiftFunctionProject-rich-tooltip-layout-20260930.xcresult`。
- 最终 8 张 UI 截图：`/tmp/SwiftFunctionProject-rich-tooltip-layout-evidence-20260930/`；复核了滚动条与右侧数值的留白。

当前截图为暗色模式；未做 VoiceOver 人工走查、真机/多系统性能基准或全配置像素金图。提示仍是可覆盖图表/图例的浮层，其余迁移边界见上文。
