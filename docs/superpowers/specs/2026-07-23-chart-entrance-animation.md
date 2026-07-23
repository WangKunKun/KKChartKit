# HYMCharts 入场动画设计与协议层解耦

> 日期：2026-07-23 · 范围：`Charts/Core/HYMChartView`、`HYMChartRenderer`；`Charts/Radar/RadarChartRenderer`；`Charts/SwiftUI/RadarChart`

## 1. 背景

雷达图入场动画曾出现两个问题：

1. 中心分数的「数字滚动」肉眼几乎看不见，只见最后一位跳动；
2. 数据多边形/网格没有「从中心缩放放大」的过程。

经日志定位与多轮实测，定位到根因并最终定型为：**入场动画 = 数据层 opacity 淡入 + 中心分数淡入**（无 scale、无数字滚动）。本文记录根因、方案与架构规则。

## 2. 根因：CATransaction 隐式动画在 layoutSubviews 内被抑制

`HYMChartView.performEntranceAnimation()` 由 `layoutSubviews()` 调用。而 **UIKit 把整个 `layoutSubviews` 包在「禁用隐式动画」的 CATransaction 上下文中执行**。在该上下文内对 layer 属性的修改：

- `CATransaction.setAnimationDuration(...)` 指定的隐式动画**不触发**，layer 直接跳到终态；
- 即使内层 `CATransaction.setDisableActions(false)` 显式重新启用，**依然无效**（已实测）。

因此原先依赖 CATransaction 隐式动画的 scale/opacity 入场动画**没有动画过程**。中心分数之所以「能淡入」，是因为它由 `HYMChartValueAnimator`（CADisplayLink）逐帧驱动，**独立于 CATransaction**，不受 layout 上下文影响——这也是定位该问题的关键线索。

## 3. 方案：DisplayLink 逐帧手动插值

放弃 CATransaction 隐式动画，入场动画全部由 `HYMChartValueAnimator`（CADisplayLink，easeOut）逐帧驱动。

`HYMChartView.performEntranceAnimation()` 两步：

1. **设初始态**（无动画）：`CATransaction.setDisableActions(true)` 下把 `animatableLayers` 的 `opacity = 0`；
2. **逐帧淡入**：`animator.startEaseOut` 的 handler 每帧 `l.opacity = Float(progress)`，并调 `renderer.updateEntranceAnimation(progress:)`。

逐帧手动设值不经 CATransaction 隐式动画通道，**不受 layoutSubviews 抑制**（已实测 opacity 逐帧有效）。

> **结论（通用守则）：** 在 `UIView.layoutSubviews()` 内，凡需要动画的 layer 属性变化，一律用 DisplayLink / 显式 CABasicAnimation 驱动，**不要依赖 CATransaction 隐式动画**。

## 4. 当前入场动画行为（雷达图）

- `animatableLayers`：**仅数据层参与淡入** —— `[dataFillLayer, dataStrokeLayer, vertexDotsContainerLayer]`；背景渐变 / 网格 / 放射轴 / 最外圈 / 装饰 ring 直接显示。
- 动画：数据层 `opacity 0→1`（0.8s easeOut）+ 中心分数同步淡入。
- **无 scale 缩放、无数字滚动**：
  - scale：在 layoutSubviews 内同样受隐式动画抑制；逐帧 scale 方案经评估后未采用，改为纯淡入。
  - 数字滚动：原先 `value = target * progress` 配 `alpha = progress * 1.5`，alpha 到 1 时数值已滚到终值 ~67%，前段滚动发生在半透明阶段导致看不清；产品决定改为「直接显示最终值 + 淡入」。

## 5. 架构规则：协议层只放通用能力

`HYMChartRenderer`（Core 协议）是所有图表的通用契约，**不得定义某类图表特有的数据/动画钩子**。

| | 反例（已删除） | 正解 |
|---|---|---|
| 概念 | `var centerScoreTarget: Double? { get }` —— 雷达图「中心分数」是特有概念，曾被误放进通用协议 | 特有数据放特有 Model；特有动画在特有 Renderer 内部派生 |
| 落点 | `HYMChartRenderer` 协议 + `HYMChartView` 容器判断 | `RadarChartModel`（已有 `centerScore` / `showsCenterScore`）+ `RadarChartRenderer`（用 `resolvedCenterScore(currentModel)`） |

保留在协议层的是**通用逐帧回调** `func updateEntranceAnimation(progress: Double)`（默认空实现）：容器每帧调用，各 Renderer 自行决定如何用（雷达图用它淡入分数）。容器不感知任何具体业务字段。

> **规则：** 新增协议成员前先问「这是所有图表通用的，还是某一类图表特有的？」。特有 → 下沉到 `XXXChartModel` / `XXXChartRenderer`。详见记忆 `chart-protocol-no-chart-specific-hooks`。

## 6. 调试辅助：点击重播

`RadarChart`（SwiftUI）新增 `replayOnTap: Bool = false`：开启后点击图表区域重播入场动画。实现走 `UIViewRepresentable.Coordinator` 持有内部容器弱引用、转发 tap → `chart.playEntranceAnimation()`（`cancelsTouchesInView = false`，不阻断框架自身命中手势）。默认关闭，不影响现有调用方；demo 页开启用于排查动画。

## 7. 关键文件指引

| 文件 | 关注点 |
|------|--------|
| `Charts/Core/HYMChartView.swift` `performEntranceAnimation()` | 入场动画两步（设初始态 + 逐帧淡入） |
| `Charts/Core/HYMChartAnimation.swift` `HYMChartValueAnimator` | CADisplayLink easeOut 驱动器（注意 `stop()` 打破循环引用） |
| `Charts/Core/HYMChartRenderer.swift` | 通用协议（已无 `centerScoreTarget`） |
| `Charts/Radar/RadarChartRenderer.swift` `animatableLayers` / `updateEntranceAnimation` | 雷达图特有：参与淡入的 layer 集合 + 分数淡入逻辑 |
| `Charts/SwiftUI/RadarChart.swift` `replayOnTap` | 点击重播（调试/交互） |

## 8. 后续可扩展（不在本期）

- 若需要 scale 入场，需在 `performEntranceAnimation` 的 handler 内逐帧 `setAffineTransform`（同 opacity 机制），或把整段动画 `async` 移出 `layoutSubviews` 后再用 CATransaction。
- `updateEntranceAnimation` 作为通用逐帧回调，未来其他图表（柱状/折线/饼/热力图）可复用，驱动各自的标签淡入、数值变化等。
