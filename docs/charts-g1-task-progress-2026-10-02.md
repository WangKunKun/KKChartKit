# G1 任务进度与关机前交接

> 历史记录：本文保存 2026-10-02 的 G1 验收与当时安排。当前状态及下一步请先阅读 [2026-10-03 通用模型任务交接](charts-neutral-model-task-progress-2026-10-03.md)；下文“用户最新要求”和关机安排仅属于当时任务。

最终验收与归档时间：2026-10-02 23:36:50 +0800（Asia/Shanghai）。

用户最新要求：继续完成 G1；任务完成或 token 额度用完时保存进度文档，然后关机。本文是本轮持久化交接入口，不依赖聊天历史和 `/tmp` 才能理解当前状态。

## 1. 当前结论

**G1“正负分链、共享边界、统一断段”的实现、定向验收、全 UI 回归和证据归档已完成。** 未把“G1 完善”解释为修改全部旧模式、支持所有任意输入，或整个旧项目迁移已经完成。

- 原始业务数据不拆分、不改符号，不虚构业务点/系列 ID。
- 显式新模式：Swift `StackedAreaBoundaryMode.diverging`，OC `stackedAreaUsesDivergingChains`。
- 默认仍为 `.independent`；原 `.followBaseline` 保留，关闭新模式后兼容恢复。
- 本批没有继续扩张 G6，也没有擅自提交/推送 Git。

完整契约：[G1 使用指南](charts-diverging-stacks-guide.md)。
验证原始摘要、日志、11 张截图和输入/产物散列：[本轮证据](evidence/charts-legacy-comparison/2026-10-02-g1-diverging/README.md)。

## 2. 已完成的实现

### 2.1 正负分链不是“把端点强制改成两份数据”

原数值堆叠已分别累计正负。此次修复的是采样点之间各层边界独立插值产生的穿入/接缝问题：先构造每层自身贡献曲线，在真实过零点和阶梯跳变处建立共同区间，然后在每个区间内分别累计正、负链，相邻层复用同一边界控制点。面积按符号片闭合，描边不横跨正负链，描边裁在本层内部。

支持直线、单调平滑、三种阶梯及同组混合。按轴、stackID、grouped 序号、图形族隔离；Combined 柱族缺口不传播到线族。非面积折线只要参与堆叠，仍影响基线和百分比分母。

### 2.2 缺测与百分比有明确、可解释的规则

- 同组任一可见参与系列缺测、非有限、短尾或空数组时，共同断段。不使用虚构零值，也不在同一严格链内允许互相矛盾的独立跨空策略。
- `connectNulls/gapPolicy/autoGap` 值不被删除；新模式下统一规则优先，切回旧模式恢复。
- 自动百分比先插值原始贡献，再用共同绝对值分母归一化：正负总跨度为 100%，不是正侧和负侧各 100%。固定百分比保持已有固定分母语义。
- 原始零分母采样断开；区间内部共同过零允许各自单侧比例极限；整段恒零没有面积或桥接描边。
- 正常百分比累计边界误差目标 0.05 屏幕 pt；预算/数值条件不足时整组共享直线降级，不逐层退回独立曲线。实际降级可诊断。
- 自动值域覆盖混合线型的采样间峰值；用户显式范围和 Y 视口仍优先。

### 2.3 原值和现有入口保持稳定

原始 marker、命中、series ID、索引及 raw/base/draw 不因几何分段而重写。共同缺口内仍可能保留其他系列自己的有效原始点，属于约定行为。

现有 SwiftUI 折线/混合页新增场景和规则说明，实际 renderer 回报参与/降级数。OC 现有轴系页新增三模式选择及启用恢复。独立 framework 重新生成，含 87 份 SDK Swift 文件；Swift 与纯 OC 宿主验证公开入口，没有把 Demo 编入库。

## 3. 核心文件定位

以下路径相对于仓库根目录。

| 路径 | 内容 |
|---|---|
| `SwiftFunctionProject/Charts/Line/LineDivergingStackGeometry.swift` | 组级严格契约、共同有效段、范围估计、原子降级 |
| `SwiftFunctionProject/Charts/Line/LineDivergingStackMesh.swift` | 真实根/共享网格、正负累计、零因子消除、共享直线回退 |
| `SwiftFunctionProject/Charts/Line/LinePercentAreaNormalizer.swift` | 百分比共享归一化及极小负贡献符号修复 |
| `SwiftFunctionProject/Charts/Line/LineChartRenderer.swift` | 新轮廓接入、填充/描边、公开诊断 |
| `SwiftFunctionProject/Charts/Cartesian/CartesianChartTheme.swift` | 新显式枚举 case，默认兼容 |
| `SwiftFunctionProject/Charts/Cartesian/CartesianRendererBase.swift`、`SwiftFunctionProject/Charts/Combined/CombinedChartRenderer.swift` | 自动值域与线族分区接入 |
| `SwiftFunctionProject/Charts/OCBridge/HYMCartesianChartViewBridge.swift` | 新 OC 配置入口 |
| `SwiftFunctionProject/Charts/Core/HYMChartView.swift` | renderer 实际诊断观测 |
| `SwiftFunctionProject/Charts/SwiftUI/CartesianDemoState.swift`、`CartesianDemoRules.swift`、`CartesianDemoControls.swift` | 现有场景和冲突规则 |
| `SwiftFunctionProject/Charts/SwiftUI/DemoChartHost.swift`、`DemoLineSamplingReadout.swift`、`CartesianChartDemo.swift` | 实際诊断展示，不依赖 sampling 是否启用 |
| `SwiftFunctionProject/OCDemo/CartesianOCDemoViewController.m` | OC 模式、分段控件状态和正负场景 |
| `SwiftFunctionProjectTests/DivergingStackGeometryTests.swift`、`DivergingStackRendererTests.swift` | 14 + 8 个新专项测试 |
| `SwiftFunctionProjectTests/StackedAreaStrokeTests.swift` | 两边界模式的 1×/2×/3× 像素覆盖 |
| `SwiftFunctionProjectUITests/ChartDemoUITests.swift` | 两个新 UI 用例，覆盖 SwiftUI/OC 现有页 |
| `Examples/ChartsIntegration/` | 独立框架、公开宿主、产物审计与运行验证 |

## 4. 验证结果

| 项目 | 结果 |
|---|---|
| 最终主工程：全部单元 + 新 G1 UI | **366/366 通过** = 364 单元 + 2 UI |
| 最终版本全 UI 重跑 | **33/33 唯一用例通过** = 30 个 ChartDemo + 3 个模板 UI；参数化启动共 36 次执行 |
| 独立 Release Swift / 纯 OC 公开导入 | **2/2 通过**，各自 30/30 释放，实际命中 `hit:power:500` |
| Release 模拟器框架/宿主 | 构建通过 |
| Release iOS 设备框架 | 未签名编译通过；未做真机安装/运行 |
| framework 产物审计 | 两套产物通过；公开 Swift/OC 入口、六个 SwiftUI 包装和依赖边界正常 |
| 截图 | 11 张归档；已打开实际几何、SwiftUI、OC 页面进行目视复核 |

**最终主工程覆盖 397 个独立用例（364 单元 + 33 UI），分批运行；其中 2 个新增 G1 UI 重复执行，不重复计数。另有 2 个独立接入用例。**

几何矩阵：普通/自动百分比各 125 种混合线型组合；极小负值、共同过零、零分母、强制回退、空数组/短尾、双轴/分组隔离、原始命中、复用/显隐/视口、采样间峰值、1,500 点 × 6 系列。描边测试覆盖五种线型、两种线宽、1×/2×/3×。

先前完整回归曾为 394 个唯一测试、393 通过、1 个新增 UI 失败；没有将其伪称为全通过。收尾发现并修复：诊断错误依赖 sampling 开关、全空输入值域越界、百分比补齐行与原始短尾长度不一致、OC segment 的可访问启用状态。最终 366 项已包含相应修复和回归，随后最终版本完整 33 项 UI 也全部通过。

## 5. 完成边界与后续待办

以下不是本批已完成项，不能因为 G1 新模式通过就自动划掉：

1. **真实业务/真机验收**：项目自己的主题、半透明渐变、超薄层与系统栅格差异，真实数据规模/长时间操作、业务页组合。当前 iOS 设备只有 Release 未签名编译。
2. **旧模式取舍**：兼容默认和沿基线模式仍有各自已记录的规则；需严格贴合和统一缺测的调用应显式选择新模式，不能静默切换全部旧页面。
3. **G6 扩展形态候选**：自定义填充基线、任意两线间填充/范围带、逐点 marker 色/图片、反向轴、真实数值 X、悬浮/范围柱等均未在本轮扩展；各自确认数据/几何定义后再按价值选做。
4. **正式旧模块替换**：R2 旧模型适配、真实页面接入、业务汇总/外围 UIView、签名与发行方式仍后置，见[替换计划](charts-legacy-replacement-plan.md)。
5. **后续语言模式维护**：现有 Swift existential/变量警告尚存，当前构建通过；未在本轮宣称 Swift 6 零警告兼容。

建议下次先阅读本文件、G1 指南和证据，再按真实业务需求继续 G6 或 R2，而不是重新改业务数据符号或删除新模式契约。

## 6. 工作区与证据保存

- 改动保存在当前工作区；没有 Git commit/push，没有重置、清理或覆盖前序未提交任务。
- 工作区原已有 G2–G5 等大量改动和未跟踪文件，不能把整个 `git diff` 当成仅 G1 的变更清单。
- 已校验文档本地链接、154 份源码/测试/工程输入散列和 11 张截图散列；`git diff --check` 通过。
- 本轮证据目录保留摘要、压缩日志、截图、源码输入散列和 framework 二进制散列。完整 xcresult 和构建产物在 `/tmp`，可能被系统清理；归档没有假称保存了它们的完整副本。
- 若需提交，请先审阅前序与本批改动，再按项目流程拆分；本轮未擅自创建提交或发行版本。

## 7. 关机状态

**关机前保存已完成，准备发送请求**：全部验收与证据归档完成，接下来按用户明确要求发送 macOS 正常关机请求。不强制结束其他应用、不丢弃其未保存文档、不绕过系统权限。

请求发出后的实际状态以系统行为为准；若应用保存对话框或权限阻止关机，将记录并说明，不把“发送请求”冒充“硬件已经断电”。若关机时进程立即结束、下方没有执行回执，本文件只能证明关机前保存已完成，不能单凭缺少回执推断关机成功或失败。

### 正常关机请求执行记录

- 开始调用：2026-10-02 23:39:57 CST。用户已明确授权；只发送正常关机，不强制丢弃其他应用文档。

- 系统脚本返回成功：2026-10-02 23:39:58 CST。已发送关机请求；此回执不证明硬件已经断电，其他应用仍可能要求保存确认。
