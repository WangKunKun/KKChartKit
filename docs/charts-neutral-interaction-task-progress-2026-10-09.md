# N4 Tooltip／图例通用描述进度（2026-10-09）

> 后续状态：N4 固定顶部提示的布局质量切片已实现，原生可选绘图区边界、N4 fixedTop 自动启用。下文保留 N4 首次验收历史；新验证与限制见[布局质量进度](charts-neutral-tooltip-layout-task-progress-2026-10-09.md)。

## 1. 结论与范围

响应“做 N4”，按[下一任务规划第 8 节](charts-next-task-plan-2026-10-09.md)完成有限可序列化切片：**Tooltip 内容与取值、逐稳定系列 ID 规则、图例布局与标题**。显式 schema v6；默认构造仍为 v1，v1–v5 样例字节不变。N3 本地改动完整保留，本轮没有改动原生 renderer、坐标、G1 堆叠或分母算法。

首次验收状态：**N4 有限可序列化切片已完成并通过验收；当时固定顶部提示与顶部图例的布局避让仍为质量待办，后续状态见文首。** 正式记录位于 [N4 证据](evidence/charts-neutral-interaction-2026-10-09/README.md)。

## 2. 已实现的契约

- **Tooltip 内容**：启用开关、text/columns、automatic/fixedTop、当前表头 `{key}` 模板、零取值过滤；按稳定系列 ID 隐藏行、覆盖标题、只显示名称。图形、图例、命中和百分比分母不随提示过滤改变。
- **取值**：全局与逐系列类目槽位偏移，显式 0 可覆盖全局；omit/clamp/current，来源标签与模板；Int 极值安全，缺测不搜索。当前 header、准线、命中样本身份与取值样本分离，显示值仍为原始数值／系列格式。实际聚合桶复用原生当前桶语义。
- **图例**：屏幕 top/bottom/left/right、leading/center/trailing、scroll/expand、最大行数／宽高、点击显隐、相邻组换行、逐系列标题。沿用 `showsLegend/showsInLegend/isVisible`，不重排输入或创建动态组。
- **版本与失败**：v6 顶层 `tooltip/legend` 必须同时存在，可为 null；v1–v5 拒绝这两个保留键的任何形式。降级必须先移除对象，包括 disabled/default；编码、解码、输入校验和适配失败都有明确路径。隐藏配置仍校验引用和尺寸。
- **运行时边界**：nil Tooltip 表示宿主控制；非 nil 覆盖已建模内容，不启用业务汇总。图片/provider、颜色/字体/动画/偏移和手势不序列化；已匹配规则优先，未覆盖图片与样式继续来自宿主。
- **Swift／OC 一致性**：Swift 的适配输出提供 view 级 Tooltip 配置；OC document/bridge 自动应用，切回旧版/null 时重建宿主基线，失败不污染有效配置，成功更新清理旧提示、按原策略保留／重置视口。
- **同页 Demo**：四个既有中立模型预览新增 Tooltip／图例区，不加平行页面；配置开关独立、详细项折叠、稳定系列 ID 独立规则，关闭／恢复保留值，全局重置回 v1。

## 3. 文件入口

| 层 | 入口 |
| --- | --- |
| Foundation-only 模型 | [ChartInteractionSpecification.swift](../SwiftFunctionProject/Charts/Specification/ChartInteractionSpecification.swift) |
| 版本化与校验 | [VersionCoding](../SwiftFunctionProject/Charts/Specification/ChartSpecificationVersionCoding.swift)、[Validation](../SwiftFunctionProject/Charts/Specification/ChartSpecificationValidation.swift) |
| 原生适配输出 | [HYMChartsSpecificationInteraction.swift](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationInteraction.swift) |
| OC 原子更新／基线恢复 | [HYMCartesianChartViewBridge.swift](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianChartViewBridge.swift) |
| 同页控件与预览 | [InteractionControls](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationInteractionControls.swift)、[Demo](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationDemo.swift) |
| 版本／输入专项 4 项 | [ChartSpecificationInteractionTests.swift](../SwiftFunctionProjectTests/ChartSpecificationInteractionTests.swift) |
| 适配／四 renderer／运行时专项 8 项 | [HYMChartsSpecificationInteractionTests.swift](../SwiftFunctionProjectTests/HYMChartsSpecificationInteractionTests.swift) |
| 相关 UI | [ChartDemoUITests.swift](../SwiftFunctionProjectUITests/ChartDemoUITests.swift) |
| Swift／纯 OC 公共导入 | [独立接入工程](../Examples/ChartsIntegration/README.md)、[共享 v6 JSON](../Examples/ChartSpecifications/energy-interaction-v6.json) |

完整使用示例、优先级、默认值和边界见[模型指南 N4 小节](charts-neutral-model-guide.md)。不要仅应用 model/theme 而漏掉 Tooltip view 配置，也不要将前一次适配后的 presentation 重新当作宿主基线形成闭包链。

## 4. 验证与覆盖记账

**正式主工程 443 项单元 + 6 项相关 UI = 449/449，公共 Release Swift／纯 OC 宿主 2/2，失败与跳过均为 0；Python 审计回归 28/28。** Foundation-only Swift 6 complete strict concurrency 编译通过，六版 JSON 逐字节复现，旧 v1–v5 SHA-256 不变；四张正式原始截图已逐张目视复核。本轮新增 **12 项单元 + 1 项四页 UI**；现有 N1/N2/N3/G1/不支持能力恢复都包含在主工程正式回归范围。独立 Release 宿主额外读取同一份 v6 JSON，SDK 排除 Demo、fixture 与 JSON 资源；不使用 `@testable`。

[197 项覆盖矩阵](charts-neutral-model-coverage.md)现在为 **60 已表达 / 26 schema 待补 / 104 外层 / 7 不承接**，61 个主题、18 个原生复核项。比 N3 增加的五项已表达仅是旧声明 `tooltipPinToTop / tooltipDisable / hideInTooltip / hideNameInTooltip / showPrev` 的可表达语义；**不是已交付旧输入 mapper**。图例布局作为原生复核主题登记，不补造旧声明数量；逐点规则、组级 onlyName 和样式缺口仍明确保留。Python 防回归校验此边界。

开发期首轮 N4 UI 通过，12 项单元中一项失败：测试把线/面积 G1 共享边界套到了不支持该政策的 Column/Bar。修正测试组合为线/混合三种边界、柱/条 independent，不放宽生产能力拒绝；首轮失败不冒充最终通过。静态审计添加 UI 路径时触发既有“单元测试证据锚点”约束，改为引用核心与适配单测，UI 独立记入运行证据；指南变化后的 Markdown 行号报告重新生成。

## 5. 尚未做与质量待办

- 逐 sample ID 表头／行名／隐藏点，动态组标题、组级 onlyName、独立业务小计来源／单位／精度：等待 R2/R3 真实旧页面契约，不按系列规则猜测替代。
- Tooltip 字体／颜色主题、图例图片／符号／背景、可序列化资源协议、自定义视图／回调：仍由宿主运行时处理或后续独立设计。
- **fixedTop + top 图例（首次验收历史，后续已有绘图区边界方案）**：原生提示浮在图表容器顶部，并不预留标题／图例空间；本轮截图可见部分遮挡。自动避让／专用提示预留区尚未实施，不能宣称所有组合视觉完善。宿主可选择其他位置或自行预留容器；应在质量切片中验证窄屏、长文本、多行、旋转后再统一更改原生政策。
- 既有深色静态标题／刻度对比度、Bar 长单位标签裁剪、Swift existential/资源命名等编译警告依然登记。没有以改数据／隐藏单位方式制造修复。
- G6 连续数值／时间 X、反向值轴、次轴独立网格限制、实际第二后端、旧输入 mapper、真实业务接入均未开放。本次不是全量 UI、真机性能／长时生命周期或正式 SDK 分发验收。

## 6. 下一步与 Git

当时建议先做的 **N4 布局质量切片**已在后续授权下执行，见文首链接；原建议为：明确固定顶部提示与标题／图例的避让或预留区政策，保持默认行为兼容，并覆盖四 renderer、OC/Swift、缩放／旋转／窄屏。随后按业务优先级选择已有独立规划 **G6-A 反向值轴**，或收集 R2 首个真实页面契约；不自动扩成所有剩余旧字段，也不虚构 N5。

远端最近已推送的是前序九提交到 `origin/main` 的 `a5ace6a`；**N3 与本次 N4 增量均仍为本地未提交／未推送**。本轮用户仅要求做 N4，没有自动提交、推送、启动下一阶段或执行历史关机操作。
