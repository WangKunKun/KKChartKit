# G1 通用模型 v2：任务进度与继续入口

更新：2026-10-03（Asia/Shanghai）。承接通用模型首版和 197 声明覆盖核对，范围仅为 **G1 堆叠边界的通用入口**，不引入第二绘图库、不实现旧输入 mapper、不改原生几何算法。

## 1. 已实现

- 新增 Foundation-only `ChartStackedAreaBoundary`：independent / followBaseline / diverging，根描述通过 `stackedAreaBoundary` 保存明确意图。
- `latestSchemaVersion=2`；旧构造器仍默认 v1、独立边界。新模式须显式 opt-in v2，不自动把旧图改画成正负分链。
- 顶层 Codable 版本边界单独成文件：v1 无新字段，v2 必填；v1 夹带该字段、v2 缺失/null/未知值、未来版本均拒绝。直接 JSONEncoder 同样执行输入校验，不能把非独立边界静默编码成 v1。
- 非独立模式须启用数学堆叠，并有带 stackID 的线/面积系列；隐藏系列仍可配置，柱族不应用此策略。
- HYM 适配器逐模式映射既有 theme。正负分链的统一断段优先于逐系列缺测连接，采样 ID、原值、业务分组与命中不改写；百分比分母仍为同组贡献绝对值之和。
- 折线/混合现有“通用模型”页加入三段选择器、实际版本/模式状态和恢复默认；没有新增同类型页面。混合样本含柱 + 两条线族系列，一条线族缺测时另一条仍保留原始样本。
- Swift/纯 OC 独立宿主同时载入 v1 与 v2 JSON；JSON 资源只进入宿主，不放入 SDK。
- 覆盖矩阵 G1 从“未建模”更新为“已表达/已映射”。197 项计数仍为 **40 / 46 / 104 / 7**：G1 是另列的原生边界主题，不是新增旧声明，不能虚增迁移完成率。

## 2. 版本使用

```swift
var specification = existingV1Specification
specification.schemaVersion = 2
specification.stackedAreaBoundary = .diverging
let configuration = try HYMChartsSpecificationAdapter().makeConfiguration(from: specification)
```

同一份 [v2 JSON](../Examples/ChartSpecifications/energy-g1-v2.json) 可经 OC `HYMChartSpecificationDocument` 创建或更新 bridge。非独立模式要降级 v1，必须先明确改回 independent；不自动丢语义。

完整说明见[模型指南](charts-neutral-model-guide.md)，原生数值/精度与共同断段约束继续遵守[正负分链契约](charts-diverging-stacks-guide.md)。

## 3. 最终验证（2026-10-03）

| 验证 | 实际结果 |
| --- | --- |
| 主工程所有单元测试 | **395/395**，包含原有 384 项与本轮新增 11 项 |
| 相关 UI | **2/2**：Line/Combined 同页三模式切换与恢复默认；原有通用预览/不支持能力恢复 |
| 主工程正式 xcresult | **397/397，0 失败、0 跳过**；最终运行于 22:26 完成 |
| 独立 Release 公开导入 | **2/2**；Swift 与纯 OC 宿主同时验证 v1/v2 JSON，非 `@testable` |
| Foundation-only 核心 | Swift 6 + complete strict concurrency 编译通过；v1/v2 示例重新生成均逐字节一致 |
| Python 审计回归 | **24/24**；197 项覆盖计数仍为 40 / 46 / 104 / 7 |
| Release framework 产物 | 公开 v2 API/OC 文档桥接存在；无 AA/JS/WebKit/App 依赖或 Demo/JSON 样例资源 |
| 实际 UI 截图 | 最终 Line / Combined 原始截图各 1 张，已目视复核；混合页第三系列改为独立青绿色 |

先前的 31 项专项通过和初次 397 项运行不重复计入最终数字。最终源码版本的主工程与独立宿主测试记录、源码哈希、截图来源、生成命令和离线检查见[本轮证据](evidence/charts-neutral-g1-2026-10-03/README.md)。临时 xcresult 不入库，正式摘要、测试树和压缩日志已保留。

**未声称通过的范围**：其他 UI 测试未全量重跑；无真机、第二绘图库或真实业务页面验收。截图沿用已有静态主题，在深色系统背景上标题/部分标签对比度偏低，非本轮 G1 改动，不视为全主题验收。主工程仍有既有资源命名、协议 existential 等编译警告；本轮不声称 warning-free。

## 4. 下一步边界

本小切片完成后，G1 的原生与通用入口契约均已具备；仍不等于所有图库、输入规模或真实设备完成验收。

1. 选定实际第二后端/宿主，再验证同份描述的身份、原值、缺测、单位、轴绑定、分母和各边界模式；不能默认别的库与 HYM 语义等价。
2. 暂不选库时，可按具体场景补 zones、标注、Tooltip/图例；每次明确版本策略、能力拒绝、Swift/OC、同页 Demo 和测试。
3. 正式 R2 mapper 仍需确定 D06/D07、精度哨兵、旧输入身份和累计政策；业务 UI、真实页面、真机、状态恢复、分发/回退继续分别验收。
4. G6 连续 X/反向值轴仍是通用模型已描述、HYM 明确拒绝，不在本轮扩张。

## 5. 工作区

保留前序未提交改动，不提交、不推送、不重置。历史关机指令不在当前任务重复执行。
