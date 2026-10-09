# 通用模型覆盖核对：任务进度与继续入口

> 后续更新：G1 通用边界已进入 schema v2，见[本轮增量进度](charts-neutral-g1-task-progress-2026-10-03.md)。本文的首版/覆盖核对测试结果及“G1 未建模”描述保留为当时快照；当前 API 和支持状态以模型指南及覆盖矩阵为准。

更新：2026-10-03（Asia/Shanghai）。承接[首版模型交接](charts-neutral-model-task-progress-2026-10-03.md)第 5 节的第 1 项任务。

## 1. 本轮完成什么

**覆盖核对已完成；没有修改 schema v1 或任何渲染行为。** 本轮不是第二后端、旧 mapper 或真实页面迁移的实现批次。

| 产物 | 内容 |
| --- | --- |
| [覆盖矩阵](charts-neutral-model-coverage.md) | 197 个旧属性/方法逐项处置；58 个能力/职责主题；单列 13 个 G1–G6 / 后端边界主题 |
| [机器可读清单](charts-neutral-model-coverage.json) | 每个旧声明明确关联能力、转换规则；每个能力分别记录 schema、原生与适配器状态及源码/契约依据 |
| [校验器](../scripts/check_chart_neutral_coverage.py) | 核对旧头文件实际声明、来源位置、遗漏/重复/失效字段、状态组合、源码锚点、schema 版本、Markdown 同步；新字段不会自动获得“已支持”分类 |
| [20 项脚本测试](../scripts/test_check_chart_neutral_coverage.py) | 含漏项/伪支持/错误证据/版本漂移/越界路径/重复 JSON 键/陈旧文档等负向场景 |
| [持久证据](evidence/charts-neutral-coverage-2026-10-03/README.md) | 实际 XCTest 摘要与逐项结果、离线检查日志、纯 Foundation 编译/样本比对、输入散列 |

旧声明按**主要处置**分为：

- **40 项已表达**：现 schema 与 HYM 转换能承接指定语义；旧输入 mapper 仍待实现，旧默认与累计规则不自动兼容。
- **46 项需新增通用语义**：例如 zones、标注、提示、图例样式、显式刻度、字重和轴刻度单位格式；部分已有原生能力，不能重复记作原生绘制缺失。
- **104 项留在外层**：包括业务 UI、运行时命令/事件、旧格式/类型兼容和派生缓存；不是“104 项都已完成”，也不是“104 项 renderer 缺口”。
- **7 项应明确不承接或拒绝**：包括旧占位导出/引擎产物、任意标注层级及旧 xAxisType 的连续/未知分支。分类是迁移要求，不能声称已实现整个旧字段诊断器。

58 个主题和 13 个边界主题与 197 个声明有交集，**不能相加作为功能数量，也不能据此计算迁移完成率**。

## 2. 核对得到的关键边界

1. **G1 原生完成不等于通用入口完成**：原生有 `independent / followBaseline / diverging`；v1 无对应字段，适配器继续默认 independent。单独设置 sum/percent 不会自动启用正负共享边界或同组统一断段。
2. **G6 恰好相反**：模型已描述数值/时间 X 和反向值轴，但当前 HYM 适配器返回能力错误；不能把真实 X 转成等距标签“接通”。
3. **未建模不等于已有拒绝诊断**：额外 JSON 对象键当前仍会被 Codable 忽略；未来旧 mapper 要在转换之前报告缺失能力，不得通过 metadata 或引擎 options 透传。
4. **旧实现与头文件注释不能混看**：核对 `HMAAChartManager.m` 后，`HMAAYAxis.unit` 实际拼到刻度标签 `{value}` 后面，轴标题为空；原生 labelFormatter 可承接意图，但 v1 无轴格式。旧历史清单中的“轴标题”表述不能作为映射依据。
5. **旧缺陷不是兼容目标**：副轴刻度分支误读主轴数组；副轴颜色分支误取主轴色设置轴线；标线 zIndex 写死 3、dashStyle 未消费。矩阵已分别说明，不把这些错误复制到新模型，也不声称原系统曾完整支持声明的功能。
6. **需要明确的旧默认**：`fillColorAlphas` 旧实现只取首尾，不是任意多色标；autoGap 实际以 `>=12` 空点断段；dashColor 同时影响 X 轴线与 Y 网格。R2 应按这些实际行为建立显式规则，而不是直接复制字段名。

本批没有新增公开绘制参数，因此没有更改 Demo；未来扩 schema 必须同步既有页面面板、Swift/OC 入口与版本迁移契约。

## 3. 本轮实际验证

- 新审计脚本：**20/20**；原有证据脚本：**4/4**；合计 **24 个 Python 测试通过**。
- 模型与 HYM 适配器：**20/20 XCTest 通过**，包括身份、缺测/百分比、样式/网格、能力拒绝及 OC 失败更新保留最后有效配置。
- 首次过滤器只选中 `ChartSpecificationTests` 的 11 项；发现另有 `HYMChartsSpecificationAdapterTests` 9 项后，最终两个类一起重跑 20 项全通过。**不是 31 项独立测试**。
- Foundation-only 核心以 Swift 6 + complete strict concurrency 独立编译；重新生成示例 JSON，与仓库 `energy.json` **逐字节一致**。
- 旧字段完整性检查、矩阵/Markdown 同步检查及图表文档/既有截图证据完整性检查通过。
- **本批没有重跑全部 384 单元、34 UI、独立 Release Swift/OC 宿主或真机测试**。既有完整结果仍看首版交接，不用本批 20 项替代全量验收。没有运行第二绘图库，也没有新截图/视觉验收声明。

## 4. 下一步怎样继续

覆盖核对之后有两条清晰路径，不需要再从“197 项原生缺口”重新开始：

1. **选定实际第二后端及宿主**：确定 iOS 原生还是 Web 容器、目标产品/分发约束，再以同一份描述验 ID、原值、缺测、单位、轴绑定、百分比分母和能力诊断。没有实际目标前不擅自引入新依赖。
2. **先补已确定场景或 R2**：若暂不选后端，可把 G1 边界作为优先小切片，或按旧页面迁移需求推进独立 mapper。G1 先明确新语义和版本策略，旧 v1 文档默认保持 independent；补校验、HYM 转换、Swift/OC、现有 Demo、契约测试后才算通用入口完成。R2 必须显式处理 D06/D07、精度哨兵和输入身份，不能猜测真实业务政策。

zones、annotation、tooltip/legend 的扩展由实际场景排序。真实页面、真机、状态恢复、分发/回退继续留在 R7/R8；未取得真实工程前不标记完成。

## 5. 工作区与复现

- 所有改动保留在原工作区，**未提交/推送、未重置前序修改**；本轮没有改 SDK Swift、OC、Xcode 工程或样本 JSON。
- `check_chart_migration_inventory.py` 仅让声明读取函数可传入 root，以便在临时 fixture 中测试；原命令行为不变。原 197 项历史 JSON 分类未重写，历史 Markdown 只追加“请读新矩阵”的说明。
- 持久证据的 [source-inputs.json](evidence/charts-neutral-coverage-2026-10-03/source-inputs.json) 记录本次检查涉及的文件散列及范围；不是整个工作区快照，不把 Git HEAD 当作测试输入。
- 临时完整结果：`/tmp/HYMChartNeutralCoverageVerified-20261003.xcresult`；可能被系统清理，仓库已保存摘要与测试树。
- 阅读顺序：本文 → [覆盖矩阵结论/边界](charts-neutral-model-coverage.md) → 对应能力主题的源码入口 → [模型指南](charts-neutral-model-guide.md) → [实施计划](charts-legacy-replacement-plan.md)。
- 历史 G1 关机安排属于当时已结束任务；本轮没有新的关机要求，不重复执行。
