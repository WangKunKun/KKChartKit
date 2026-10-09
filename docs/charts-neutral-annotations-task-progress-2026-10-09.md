# N3 值轴标线／色带：任务进度与交接

日期：2026-10-09（Asia/Shanghai）。本轮先将既有九次提交推送到 `origin/main`（`bbdea76..a5ace6a`），随后实施 N3。以下增量尚未提交／推送，不重复历史关机操作。

## 1. 交付边界

新增显式 **schema v5** 的 `plotLines` / `plotBands` 与 `ChartAnnotationLabelStyle`，核心仍只依赖 Foundation。默认构造保持 v1；v1–v4 共享 JSON 不改写。HYM 适配器复用现有 G4 绘制，不改原生坐标、堆叠或命中算法。

- 每个标注有非空稳定 ID，跨标线和色带统一唯一；通过稳定 `valueAxisID` 绑定轴，数组重排不改业务身份。输出 source 保存隐藏项，原生数组只接收可见项。
- 标线值有限；色带必须有限且 `from < to`，不自动交换端点或扩大区间。坐标用绑定值轴单位，百分比图直接用百分数，不二次归一化，也不扩大域。
- 颜色为 sRGB RGBA；线宽非负有限，线型 solid / dashed / dotted。nil 继承原生默认。带体在系列后、标线和文字在系列前，不承接任意 zIndex。
- 标签支持文字、前景／背景色、正有限字号和九种系统字重，水平／垂直屏幕对齐、有限偏移（绝对值 ≤ 1e9）、clamp / hide。clamp 限宽尾截并钳入绘图区，高度不足隐藏；hide 需要完整文本可容纳。无自动单位、回调 formatter 或自定义字体资源。
- v5 JSON 必填两个数组（可空）；缺失／null／类型错误拒绝。v1–v4 出现任一保留键即拒绝，包括空数组、null、错误类型。非空标注禁止降级，隐藏也不能绕过校验；只有清空两个数组才可继续按其余字段的版本规则降级。
- 主次轴适用 Line / Column / Combined；Bar 仍只有主值轴。类目／连续 X 标注、G6 数值／时间域和反向轴未因此开放。

## 2. 实现入口

| 范围 | 入口 |
| --- | --- |
| 模型与完整校验 | [ChartAnnotationSpecification.swift](../SwiftFunctionProject/Charts/Specification/ChartAnnotationSpecification.swift)、[版本编解码](../SwiftFunctionProject/Charts/Specification/ChartSpecificationVersionCoding.swift) |
| 薄适配 | [HYMChartsSpecificationAdapter.swift](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift) |
| 同页 Demo | [ChartSpecificationAnnotationControls.swift](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationAnnotationControls.swift)、[描述组装](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationDemo.swift) |
| Foundation 契约测试 | [ChartSpecificationAnnotationTests.swift](../SwiftFunctionProjectTests/ChartSpecificationAnnotationTests.swift) |
| 适配／渲染／更新测试 | [HYMChartsSpecificationAnnotationTests.swift](../SwiftFunctionProjectTests/HYMChartsSpecificationAnnotationTests.swift) |
| 共享 JSON / 公开接入 | [energy-annotations-v5.json](../Examples/ChartSpecifications/energy-annotations-v5.json)、[独立 Swift/OC 工程](../Examples/ChartsIntegration/README.md) |

四个既有页面右上角“通用模型”内新增同一配置区，按轴 ID 保存标线／色带独立设置；关闭再打开次轴保留配置，恢复默认清空全部标注并回到 v1。详细颜色、线型与文字设置放入折叠区，不占满有限 Form；无效区间保留输入并显示诊断，不偷偷修正。未建立第二个同类型 Demo。

## 3. 验证

最终回归通过：**431 项全部单元 + 5 项相关 UI = 436/436**，零失败／跳过；Release Swift／纯 OC 双宿主 **2/2**；Python 审计回归 **27/27**。Foundation-only Swift 6 完整严格并发编译、v1–v5 五份 JSON 逐字节复现、公开 framework 产物审计均通过，v1–v4 示例与已推送基线逐字节一致。四页原始截图已逐张复核；结果摘要、日志、截图及离线来源／散列检查见[本批证据](evidence/charts-neutral-annotations-2026-10-09/README.md)。开发期专项不额外累计到最终数量。

回归覆盖轴／系列／标注重排、隐藏恢复、裁剪与固定层次、次轴位置、长文本和缩窄、极端偏移、三种 G1 模式与百分比／缺测、原值／命中不变、OC 无效更新原子性及视口保留。UI 验证四页的开启、成功状态与复位，并检查折线页次轴关闭／恢复时的独立配置；其余边界主要由单元断言验证，不把静态截图当作所有组合的证明。

覆盖矩阵仍是 **197 个声明 / 59 个主题 / 15 个原生复核主题**；其中声明处置为 **55 已表达 / 31 待补 / 104 外层 / 7 不承接**。本轮 8 个旧标线相关声明已有中立表达，但不表示旧 mapper 已实现。色带本身无额外旧声明，不能为了数字而计入新分母。

## 4. 仍未完成

- 固定层次内重叠标签没有避让策略；clamp 不保证多个标注互不遮挡。不扩大到自由画布、X 标注或任意 zIndex。
- 深色标题／轴／图例低对比度、Bar 长单位刻度截断仍是既有视觉债；本批显式黑字白底仅让标注样例可读，不宣称全主题修复。
- 既有 Swift existential、资源命名／未变变量等编译警告仍在；Foundation 严格并发通过不等于全 SDK Swift 6 迁移或零警告。
- 未跑全量 UI、真机、全系统版本、性能或长时生命周期；独立模拟器宿主不等于正式签名／分发／真实旧业务接入。
- G6、旧输入 R2/D06/D07、第二生产后端与 R7/R8 仍未交付，不添加未知依赖、不猜业务政策。

## 5. 下一步建议：N4 先限定 Tooltip / 图例切片

按[下一步计划](charts-next-task-plan-2026-10-09.md)核对原生 tooltip / legend 与旧声明：先区分可序列化展示／取值规则、运行时回调、图片资源解析和业务汇总。优先选择一个小切片，明确默认值、版本／降级与 unsupported；再做稳定 ID 绑定、Swift/OC、同页 Demo 和回归。不要将现有 `showsLegend` 布尔升级描述成完整图例，也不要把业务组名或能源合计默认为通用政策。N4 本轮未启动。
