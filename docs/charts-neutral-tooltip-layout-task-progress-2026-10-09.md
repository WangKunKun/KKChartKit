# N4 固定顶部提示布局质量进度（2026-10-09）

## 1. 结论与范围

承接 [N4 首次验收](charts-neutral-interaction-task-progress-2026-10-09.md)后的质量建议，处理固定顶部 Tooltip 覆盖标题／顶部图例的问题。采用**可选绘图区边界**，不是为提示预留一个新区域：原生默认保持旧行为，N4 fixedTop 自动启用。N3/N4 本地内容保留，本轮未提交／推送，也未开始 G6 或执行历史关机请求。

**已完成并通过验收：主工程 452 单元 + 6 项相关 UI = 458/458；独立 Release Swift／纯 OC 宿主 2/2；Python 审计回归 28/28。失败和跳过均为 0。** 六版 JSON 逐字节复现，四张正式原图已逐张目视复核；开发期失败单独保留，不累计为最终通过。

## 2. 明确的布局契约

| 情况 | 行为 |
| --- | --- |
| 原生 `HYMChartTooltipTheme.fixedTopUsesPlotArea` | 新增公开 Bool，默认 false；init 新参数位于末尾且有默认值，旧调用保留整容器固定顶部 |
| fixedTop + true + 四种轴系 renderer | 使用最终 `plotFrame ∩ bounds`；宽高、居中、顶部间距及偏移都受这一边界约束 |
| automatic | 仍用原有锚点／箭头算法；此开关不生效 |
| 无绘图区能力的 renderer | 回退整容器 bounds；没有给公开 renderer 协议增加必实现要求 |
| 无效／坍缩绘图区 | 隐藏提示，不回退到标题区；恢复后等待下一次真实命中 |
| 尺寸／主题改变 | 下一次 layout 重测已显示的置顶内容，不重复入场动画，不伪造 onHit |
| OC | `HYMCartesianTooltipOptions.fixedTopUsesPlotArea` 同名、默认 NO；configure/update 复制选项，默认选项恢复旧行为 |
| N4 v6 fixedTop | 薄适配自动设 true；无新 JSON 字段，无 schema v7 |
| N4 null／旧版文档 | OC bridge 从独立宿主基线重建；不继承上次适配结果留下的 true |
| 直接使用 tooltip controller | 尊重调用者传入的容器，不自行查询 renderer |

该方案**仍会覆盖绘图区数据**。它不缩小 plot、不移动系列、不修改原始／累计／百分比值、坐标映射、堆叠边界或命中语义。长 columns 提示受绘图区限高并可内部滚动；text 仍为触摸透传并截断超高内容。操作数据区的手势应从提示外开始。

## 3. 代码与同页 Demo

- 原生接口：[TooltipTheme](../SwiftFunctionProject/Charts/Core/HYMChartTooltipTheme.swift)、[OC options](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianPresentation.swift)。
- 边界取得：[HYMChartView](../SwiftFunctionProject/Charts/Core/HYMChartView.swift)和内部可选 [renderer 能力](../SwiftFunctionProject/Charts/Core/HYMChartRenderer.swift)；[CartesianRendererBase](../SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift)只暴露已有最终 plotFrame，不调整坐标计算。
- 已显示内容重排：[TooltipController](../SwiftFunctionProject/Charts/Core/HYMChartTooltipController.swift)，主题变化使容器缓存失效。
- 通用适配：[Interaction adapter](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationInteraction.swift)。
- 既有四图页面的弹窗外观区增加 `fixedTopUsesPlotArea`（置顶限制在绘图区）；automatic 禁用但保留值，恢复默认关闭。N4 同页 Tooltip 详情解释绘图区边界与覆盖层含义，不新建页面。
- 使用样例与精确行为：[原生提示指南](charts-tooltip-selection-guide.md)、[通用模型指南](charts-neutral-model-guide.md)。

## 4. 验证范围与可复核证据

正式摘要、日志、四页原始截图、产物审计、输入及产物哈希在[独立证据目录](evidence/charts-neutral-tooltip-layout-2026-10-09/README.md)。旧 N3/N4 截图与验收产物保持原样，不用新图覆盖历史遮挡问题。

新增 [FixedTooltipLayoutTests](../SwiftFunctionProjectTests/FixedTooltipLayoutTests.swift) **9 项**，覆盖：

1. 原生默认兼容、打开／关闭后的旧位置恢复，四 renderer 的绘图区／视口／raw／选择／命中次数不受影响，automatic 不受影响。
2. 四 renderer × 三种尺寸 × 四个图例方向 × text/columns = **96 组布局**；提示框位于 plot∩bounds 内且不与标题／图例相交。
3. 窄小容器的长内容滚动／文本截断；极端 offset 钳制及同 bounds 主题更新。
4. 宽窄尺寸往返重排；零尺寸隐藏、恢复后的下一命中重新显示。
5. N4 自动启用与四种 OC bridge 旧文档／null 的独立运行时 true/false 恢复。
6. 类目视口缩放、图例显隐之后清理旧提示；再次命中使用当前绘图区，切换边界不改视口。
7. 无绘图区能力的 renderer 回退；低层 controller 的显式容器契约。

Demo 面板清单新增 1 项，审计期望由 326 同步为 **327**；正式完整回归通过 **3,379 次绑定写入、750 组渲染配置检查**（见证据中的清单与摘要）；新开关的 fixedTop/automatic 条件状态已有测试。沿用的单元验证同步检查 SwiftUI 四包装 create/update/reset 透传、OC 默认恢复、同页字段条件、N4 当前命中与前值来源。四页 N4 UI 对真实点击后的 frame 增加标题／图例不相交断言，并保留四张原始截图。

开发期完整回归曾因新开关加入后审计期望仍为 326 而失败；同步 327 项清单及 Demo 文档后，重新跑同一范围得到 458/458，不拼接两批结果。此前测试调用标签错误与沙箱启动失败也有独立日志，均不算正式通过。

**范围边界**：横向宽高及缩放由单元直接设置 frame／调用视口接口验证，不等同于模拟器真实旋转或手势压力测试。四页 UI 是竖屏点击／配置／重置路径；本轮不是全部 Demo UI、真机、大字体／VoiceOver 人工走查、性能长测或全配置像素金图验收。

## 5. 版本、记账与下一步

- 默认 schema v1；当前 schema 最高 v6；六版共享 JSON 不变。Foundation-only 模型不添加 UIKit 或布局对象。
- 覆盖矩阵仍为 197 项声明、61 项能力、18 项 nativeReview，60 expressed／26 schema_gap／104 external／7 unsupported；只补布局测试证据，不把外观质量算成新增 schema 能力。
- 公共框架仍为 101 份 SDK Swift 源码。Swift／纯 OC 宿主与产物检查器验证公开开关；不混入 Demo、样例 JSON 或内部测试依赖。
- 专用提示预留区域、关闭／拖动／超时策略、逐 sample 内容、动态组标题及业务小计仍未实施。既有深色静态文字对比度与 Bar 长单位标签裁剪仍待独立质量切片。
- 建议下一独立任务按[下一任务规划第 10 节](charts-next-task-plan-2026-10-09.md)做 **G6-A 原生反向值轴**；连续数值／时间 X 不随之自动放开。如果优先迁移，则需 R2/R3 首个真实页面契约。本轮到布局质量验收为止，不自动扩范围。
