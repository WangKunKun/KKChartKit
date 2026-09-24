# 数据与样式更新：保留视口

更新：2026-09-24。适用于 Line / Column / Bar 的 UIKit 容器及 SwiftUI 封装。

## UIKit

```swift
let chart = HYMChartView<LineChartRenderer>()
chart.configure(model: initialModel, theme: initialTheme)

// 默认保留用户当前的缩放/平移窗口。
chart.update(model: newModel)
chart.update(theme: newTheme)
chart.update(model: newModel, theme: newTheme)

// 显式显示全量数据，含主/次值轴。
chart.update(model: newModel, viewportPolicy: .reset)
chart.resetViewport()
```

- 所有视图 API 在主线程调用；绘制在下一次布局完成，必要时可 `layoutIfNeeded()`。
- `configure(model:theme:)` 保留原先的“重置到全量”语义。
- `update(model:theme:viewportPolicy:)` 可作为首次配置入口。
- 只传 model 或只传 theme 的重载依赖已有配置；首次配置前调用不生效。
- 两种更新策略均停止旧的入场动画/惯性/回弹，不自动播放新的入场动画。需要时显式 `playEntranceAnimation()`。

## 视口策略

| 情况 | `.preserve`（默认） |
|---|---|
| 用户已缩放，数据或样式刷新 | 保留当前窗口的数值范围，受新数据域和缩放下限约束 |
| 未缩放或已经恢复全量 | 继续适应全量数据 |
| 数据追加 | 保持当前历史窗口；不自动跳到最新点 |
| 数据减少，旧窗口越界 | 尽量保持跨度并平移到有效域；跨度太大则收窄为全量 |
| 正在橡皮筋越界 | 更新后严格收回有效域，不保留临时越界余量 |
| 数据清空后重新加载 | 使用新的全量域，不恢复清空前的旧窗口 |
| 次值轴删除后重新添加 | 新次轴使用全量域，不恢复已删除轴的窗口 |

Line/Column 的 X 是类目、Y 是数值；Bar 的 X 是数值、Y 是类目。双值轴窗口分别按自己的域约束。

当前类目以数组索引表示。“保留窗口”不意味着在头部插入/删除数据后仍追踪相同业务数据点；稳定数据身份和跟随最新数据属于后续工作。

## SwiftUI

```swift
LineChart(model: model, theme: theme, onHit: { hit, gesture in
    // 回调随 SwiftUI 状态刷新，使用最新闭包。
}, isZoomEnabled: true)

// 如需每次 SwiftUI 更新都恢复全量，可显式选择旧行为。
ColumnChart(model: model, viewportUpdatePolicy: .reset)
BarChart(model: model, viewportUpdatePolicy: .preserve)
```

三个轴系组件默认使用 `.preserve`；已有初始化调用不需要增加参数。`onHit` 更新与删除均同步到复用的 UIView，不再继续调用初次创建时捕获的旧闭包。

`.reset` 表示每次 updateUIView 都重置，不是一次性按钮事件。UIKit 的一次性操作使用 `resetViewport()`。

## 选择和弹窗边界

本步保留视口，不保留跨更新的选中目标：更新会清除旧的选中视觉、准线和 SDK 弹窗，避免旧数值/旧位置继续显示。下次点击立即读取最新模型。

曾通过 `onHitLocated` 显示外部弹窗时，更新会同步发送一次 `nil` 上下文作为失效通知（手势参数沿用此前命中事件）。该回调应关闭外部弹窗；若在 SwiftUI 更新阶段接入低层回调，不要同步修改正在更新的 SwiftUI 状态，应由调用方安排到后续事件循环。

后续稳定系列 ID 与选择状态工作完成后，再提供跨数据更新保持选择的策略。本步仍使用现有整体重绘路径，不宣称已经完成增量渲染。

## 测试入口

`SwiftFunctionProjectTests/ChartUpdateTests.swift` 覆盖 UIKit 窗口更新与真实 UIHostingController 更新链路。完整执行结果记录在 [当前能力清单](charts-capability-status.md)。
