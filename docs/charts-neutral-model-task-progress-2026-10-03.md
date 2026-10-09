# 通用图表模型任务进度与交接

> 2026-10-09 后续：[N4 固定顶部提示布局质量](charts-neutral-tooltip-layout-task-progress-2026-10-09.md)新增默认关闭的原生绘图区边界，N4 fixedTop 自动启用。仍为数据覆盖层，不新增 schema 或开放 G6。

> **2026-10-09 最新入口**：[N4 Tooltip／图例 v6](charts-neutral-interaction-task-progress-2026-10-09.md)有限可序列化切片已验收（443 单元 + 6 UI、公共宿主 2、Python 28 全通过），固定顶部提示／顶部图例避让留作质量待办；N1 v3、N2 v4、N3 v5 与 G1 v2 保留。矩阵为 **60 已表达 / 26 待补 / 104 外层 / 7 不承接**。下文保留历史规划／交接；最新验证和下一建议以 N4 进度为准。

> 后续更新：G1 通用边界已进入 schema v2，见[本轮增量进度](charts-neutral-g1-task-progress-2026-10-03.md)。本文的首版/覆盖核对测试结果及“G1 未建模”描述保留为当时快照；当前 API 和支持状态以模型指南及覆盖矩阵为准。

更新：2026-10-03（Asia/Shanghai）。本文是当前任务状态入口；上一批 [G1 交接](charts-g1-task-progress-2026-10-02.md)保留为历史验收记录。

> **同日续做更新**：[197 项覆盖矩阵](charts-neutral-model-coverage.md)及离线校验已完成。新批次的实际验证、旧实现核对发现与剩余任务见[覆盖核对进度](charts-neutral-coverage-task-progress-2026-10-03.md)。本文第 3 节保留首版验证范围，不与续做结果混算。

## 1. 当前结论

用户要求：优化从旧项目迁入、依赖 Highcharts 配置方式的模型，设计一个能够通过适配层接入不同绘图库的新模型。

**首版通用轴系模型、适配协议、HYMCharts 适配器、Swift/OC 接入和 Demo 已完成并通过验证。** 核心模型只依赖 Foundation，使用自己的数据与样式契约；不同绘图库通过适配器转换并报告能力差异。

当前链路为：业务输入 → `ChartSpecification` → `ChartAdapter` → 绘图库。旧输入将由单独的旧模型 mapper 转成 `ChartSpecification`；这个 mapper 尚未实现。已有 HYMCharts 适配器，尚无 Highcharts、ECharts 或 DGCharts 适配器，因此本次完成不代表“所有第三方库已兼容”或正式旧模型迁移 R2 完成。

前序 G1–G5 绘制成果继续保留；G6 扩展形态、真实页面迁移、外围 UIView 和正式分发仍按各自边界待办。

## 2. 已交付内容

| 内容 | 当前实现与入口 |
| --- | --- |
| 通用模型 | [Specification/](../SwiftFunctionProject/Charts/Specification/)：值类型、稳定类目/系列/样本 ID、数据与外观分离、轴引用、业务组与数学堆叠组分离 |
| 数据契约 | `nil` 表示缺测，0 和负数保留原义；支持稀疏类目输入；数值/时间坐标有独立类型；百分比策略明确分母，不覆盖原始值 |
| 校验与持久化 | 版本化 JSON、显式 `kind/mode` 判别字段；校验身份、引用、有限数值、范围、样式和同栈单位；错误包含字段路径和原因 |
| 适配协议 | `ChartAdapter` 定义输入、输出、后端标识、诊断和转换；其他图表家族可使用独立输入类型，无需把所有图种塞进轴系模型 |
| HYMCharts 转换 | [HYMChartsSpecificationAdapter.swift](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift)：Line/Column/Bar/Combined；按类目 ID 对齐，保留来源身份，转换轴/样式/缺测/百分比及横纵网格方向 |
| OC 接入 | [HYMChartSpecificationDocument.swift](../SwiftFunctionProject/Charts/OCBridge/HYMChartSpecificationDocument.swift)：不可变 JSON 文档、创建原生 bridge；bridge 新增配置/更新入口，转换失败保留原图 |
| 同页 Demo | [ChartSpecificationDemo.swift](../SwiftFunctionProject/Charts/SwiftUI/ChartSpecificationDemo.swift)：现有轴系页面切换“通用模型 / 原生属性”，包含有效配置、不支持诊断与恢复 |
| 示例与公开导入 | [energy.json](../Examples/ChartSpecifications/energy.json)及[独立接入工程](../Examples/ChartsIntegration/README.md)：Swift 普通 import 与纯 OC 生成头均使用同一份 JSON 验证 |

完整设计、API 示例和旧字段处置原则见[通用模型指南](charts-neutral-model-guide.md)。本次没有删除旧原生 API，也没有让业务代码继续直接传 Highcharts options。

## 3. 验证结果

以下是模型实现批次的最终结果，本次任务文档更新没有重新运行构建或测试。

| 验证范围 | 最终结果 | 持久证据 |
| --- | --- | --- |
| 主工程全部单元测试 + 两项相关 UI | **386/386 通过**：384 项单元（含新增 20 项）+ 2 项 UI；0 失败、0 跳过 | [主工程摘要](evidence/charts-neutral-model-2026-10-03/main-summary.json) |
| 独立 Release Swift / 纯 OC 宿主 | **2/2 通过**；通用 JSON、真实命中和 30/30 释放断言通过 | [宿主摘要](evidence/charts-neutral-model-2026-10-03/public-import-summary.json) |
| 独立 Release framework / 宿主 | 构建通过；95 份 SDK Swift 源文件、6 个公共 SwiftUI 包装；公开接口与依赖审计通过 | [产物审计](evidence/charts-neutral-model-2026-10-03/framework-audit.json) |
| Foundation-only 核心 | Swift 6 严格并发独立编译与 JSON 示例生成通过 | [核心校验](evidence/charts-neutral-model-2026-10-03/core-validation.json) |
| 可视检查 | 两张最终 Line/Combined 通用模型截图已复核，网格关闭、缺测和正负方向正确 | [截图清单](evidence/charts-neutral-model-2026-10-03/screenshots/manifest.json) |

环境：Xcode 26.3，iPhone 16 Pro / iOS 18.6 / arm64 模拟器。主工程 Debug，独立宿主 Release。**本批未跑全部 34 个主工程 UI 用例，未做真机运行或第三方引擎运行验收。** 核心通过 Swift 6 不代表整个既有 SDK 已完成 Swift 6 迁移。

首次构建的 OC throwing 返回类型问题，以及预览中发现的网格主题开关映射问题均已修复并纳入最终验证。早期轮次不累加进最终测试数量。复现命令、失败记录、完整压缩日志和截图见[验收记录](evidence/charts-neutral-model-2026-10-03/README.md)。

## 4. 当前边界

- 首版模型覆盖轴系图表；Radar/Heatmap 继续使用原有 API，尚未纳入新模型。
- 通用模型能表达真实数值/时间 X 和反向值轴，但 HYMCharts 适配器明确拒绝这些配置；不会转换成等距类目或静默忽略。纵向最多两根值轴，横向 Bar 仅一根；“仅开次轴网格、关闭主轴网格”当前也会返回不支持诊断。
- zones、标线/色带、完整 Tooltip/图例配置、G1 面积边界模式等尚未进入通用 schema。原生能力仍在，但不能据此认定新模型已经覆盖；新适配器沿用原生默认独立面积边界，不自动启用 G1 `.diverging`。
- 旧 197 字段的自动转换、`fractionDigits=100` 特殊语义、旧面积累计取舍、业务提示汇总和真实调用映射未交付。统计卡片、全屏、日出日落等仍放在业务/外层 UI。
- OC 首版通过 JSON 文档使用新模型，没有完整的可变 NSObject builder。JSON 未知版本/枚举值拒绝，额外对象键遵循 Codable 默认忽略行为；额外键和 metadata 不能作为引擎配置透传通道。
- Demo 切回原生属性时保留面板配置，但会重建图表；不承诺保留该次手势视口和选择状态。

## 5. 接下来需要做什么

**第 1 项覆盖核对现已完成；接下来需要选一个具体接入目标形成完整验证。** 下表记录完成情况及剩余进入条件；本次覆盖核对没有引入第二后端或实现旧输入 mapper。

| 顺序 | 后续工作 | 完成标准 |
| --- | --- | --- |
| 1（完成） | [通用 schema 覆盖矩阵](charts-neutral-model-coverage.md)：197 个旧声明、58 个能力主题、13 个原生/后端边界主题 | 40 已表达 / 46 需通用语义 / 104 外层 UI、运行时或兼容 / 7 应报不支持；含逐项规则、源码依据、自动检查和负向测试，不等于旧 mapper 完成 |
| 2 | 选定第二个实际使用的绘图库，做共同能力范围的适配验证 | 同一份 `ChartSpecification` 在 HYMCharts 和该后端运行；稳定 ID、原始值、缺测、单位、轴绑定和百分比语义一致；独有能力明确诊断，不要求像素完全相同 |
| 3 | 按实际场景逐项补充通用 schema | 优先补所选场景需要的 zones、标注、提示或 G1 边界语义；同时提供模型校验、后端转换、Swift/OC 示例和契约测试，版本变更明确迁移策略 |
| 4 | 恢复正式旧模型迁移 R2 时实现独立 mapper | 旧输入 → 通用模型；使用现有共享样本核对身份/值/单位/缺测，明确旧特殊默认值和累计取舍，不让兼容规则侵入通用核心 |
| 5 | 真实页面与发布验收 | 取得实际调用与工程约束后完成页面试点、真机、状态恢复、分发和回退；没有真实工程前不标记 R7/R8 完成 |

若后续以旧页面迁移为首要目标，可先用已有 HYMCharts 后端推进第 4 项，再安排第二后端。G6 的真实数值 X、反向轴等属于原生渲染能力建设，需要单独实现与验收；新增模型字段本身不等于后端已经支持。

## 6. 工作区与继续工作入口

- 当前改动尚未提交/推送；工作区同时包含前序 G1–G5、独立接入和本次模型工作，不应把整个 diff 当成本批独有改动或回退前序成果。
- [source-inputs.json](evidence/charts-neutral-model-2026-10-03/source-inputs.json)记录本批直接相关输入散列，不是整个工作区源码快照，也不代表 Git HEAD 即测试输入。
- 完整结果包暂存 `/tmp/HYMChartSpecificationVerified.xcresult` 和 `/tmp/HYMChartSpecificationPublicImport.xcresult`，可能被系统清理；持久证据已保存在仓库 `docs/evidence/charts-neutral-model-2026-10-03/`。
- 下次阅读顺序：本文 → [模型指南](charts-neutral-model-guide.md) → [实施计划](charts-legacy-replacement-plan.md) → [验收记录](evidence/charts-neutral-model-2026-10-03/README.md)。历史 G1 文档中的关机安排只记录当时任务，不作为当前执行指令。
