# G2–G5 图表展现：连续实现与验收记录

日期：2026-10-02。工作区保留原有未提交内容，本轮不自动提交或推送。此记录覆盖图表本体，不代表 AAChartKit 真实业务工程已经迁移，也不是独立 SDK 正式发布。

## 1. 已交付范围

| 批次 | 实际实现 | 同步入口 | 明确边界 |
| --- | --- | --- | --- |
| G2 | Column/Bar/Combined 柱族消费 zones；Y 选择 raw/draw，X 使用原始索引；有效配置优先，非法/关闭完整回退旧配色 | Swift、OC、三页现有 Demo、13 项专项单测 | 每个柱/条/堆叠段选一种颜色，不按高度切成多色；时间聚合仍只在 Column |
| G3 | 每轴颜色/字体/线宽与文字/轴线显隐；原始索引对齐的类目候选间隔；有限边带预算、长字截断和防碰撞 | Swift、OC、四页同页 Demo、7 项专项单测 | Bar 无次轴；旋转仅垂直图底部类目；显式间隔不是强制画满所有标签 |
| G4 | 线/带标签独立样式、背景、屏幕方向对齐/偏移与 clamp/hide；可选数据/总量标签避让 | Swift、OC、四页同页 Demo、8 项专项单测 | 标注先占位、总量优先，冲突标签省略；不是全局最优排布，标注之间不自动排布 |
| G5 | 点环、真实柱/条矩形覆盖层、Combined 图形族协调；单点/共享、清理与布局更新 | Swift、OC、四页同页 Demo、10 项专项单测 | 默认关闭；不做整条曲线高亮、圆角精确遮罩或跨更新/跨页选点恢复 |

公共类型按现有模型尾部参数/主题属性扩展，旧 initializer 调用保留。OC 配置仍是 configure/update 时生成的值快照；新数据标签字号默认与 Swift 一致（10pt）。新增配置不会更改原始值、堆叠链、统计范围或命中身份。轴标签隐藏回收留白时屏幕位置会随新布局变化，命中几何同步重算。

指南：[颜色分区](charts-color-zones-guide.md)、[每轴样式](charts-axis-style-guide.md)、[图内标注](charts-annotation-style-guide.md)、[主体选中](charts-selection-style-guide.md)、[统一 Demo](charts-demo-guide.md)。

## 2. 最终验证

环境：Xcode 26.3（17C529）、iOS 17.2 / arm64 模拟器；设备构建为未签名 iOS arm64 Release。测试未覆盖真机运行、长期性能或全部系统版本。

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 完整单元集 | **342 项通过，0 失败** | [最终完整轮摘要](evidence/charts-presentation-2026-10-02/HYMCharts-complete-regression-v2-20261002-summary.txt)，完整包 `/tmp/HYMCharts-complete-regression-v2-20261002.xcresult` |
| 全部现有图表 UI | **28 项通过，0 失败**；包含 G2–G5 四项跨页新增场景及历史图表场景 | 与上一行属于同一完整成功轮；不是拼接专项测试结果 |
| G2–G5 定向验收与原图 | 先前独立一轮 342 项单元 + 4 项跨页 UI，均 0 失败 | [定向轮摘要](evidence/charts-presentation-2026-10-02/HYMCharts-G2-G5-acceptance-20261002-summary.txt)；用于保存原始截图，不叠加到最终总数 |
| G3 稳定横竖屏补验 | **1 项通过，0 失败**，77.515 秒；四页均等待完整窗口内的稳定布局 | [补验摘要](evidence/charts-presentation-2026-10-02/HYMCharts-G3-orientation-v2-20261002-summary.txt)；替换原来采集过早的 12 张 G3 UI 附件 |
| Release 独立 Swift / OC 宿主 | **2 项通过，0 失败**；普通公共导入和反复创建/配置/释放 | [公共宿主摘要](evidence/charts-presentation-2026-10-02/HYMChartsIntegration-G2-G5-release-20261002-summary.txt)；`/tmp/HYMChartsIntegration-G2-G5-release-20261002.xcresult` |
| iOS arm64 Release framework | **BUILD SUCCEEDED**（未签名构建，不是真机运行） | [设备构建摘要](evidence/charts-presentation-2026-10-02/HYMChartsIntegration-G2-G5-device-20261002-summary.txt) |
| Demo 绑定/渲染矩阵 | **326 个可编辑项、3,367 次绑定写入检查、750 次渲染配置检查** | 完整单元集内执行，不是仅统计控件名称 |
| 旧字段清单 | **197 个声明、9 份头文件**全部有明确去向 | `python3 scripts/check_chart_migration_inventory.py` |
| 证据完整性 | 43 张原始附件 SHA-256、当前图表文档本地链接检查通过；校验脚本 **4 项测试通过** | `python3 scripts/check_chart_evidence.py`；包括另补验的 G1 五张图 |

最终完整轮在同一结果包中实际执行 **342 项单元 + 28 项图表 UI，共 370 项，0 失败**。结束时间为 **2026-10-02 21:01（Asia/Shanghai）**；[Xcode 机器汇总](evidence/charts-presentation-2026-10-02/HYMCharts-complete-regression-v2-20261002-result-summary.json)直接确认 370 通过、0 失败、0 跳过。G2–G5 四项跨页场景已包含在这 28 项中；专项复验与早期轮次不累加到此总数。本轮未重新执行旧 AA Demo 的 11 项 UI，也不将主工程其他非图表 UI 测试包含在“全量图表 UI”中。

独立产物包含 **85 个 framework Swift 源文件**，保留六种公共 SwiftUI 包装，排除 Demo、Debug 自检及旧图表参考源码。Swift 宿主通过普通 `import HYMCharts`，OC 宿主通过生成头；没有把 SDK 源码再编进宿主，也没有使用 `@testable`。产物检查同时确认 G2–G5 公开类型、`@rpath`、无 WebKit/AA/JS/HTML/Demo 依赖与资源。

便携产物审计：[Simulator Release](evidence/charts-presentation-2026-10-02/release-simulator-product.json)、[Device Release](evidence/charts-presentation-2026-10-02/release-device-product.json)。记录二进制 SHA-256、接口文件和链接依赖；文件名与 ABI 兼容验证不等于发布签名/安装验收。现有未来 Swift 语言模式的 existential 警告及局部变量提示未在本批扩大重构。

测试基于含未提交改动的工作区；[154 项源码/配置散列](evidence/charts-presentation-2026-10-02/source-inputs.json)标识本轮图表相关输入。它不是完整源码快照，`gitHead` 仅为基线，不能据此还原未提交内容。

## 3. 截图与视觉复核

截图来自真实 UI 测试附件，不是效果示意图。全部原始附件及 SHA-256 清单位于 [证据目录](evidence/charts-presentation-2026-10-02/)。

本批保存 **38 张**：G2 三页 raw/draw/恢复旧规则共 9 张，G3 四页样式/隐藏/横屏共 12 张及 1 张继承恢复单测图，G4 四页避让开/关共 8 张，G5 四页高亮开/关共 8 张。[附件清单](evidence/charts-presentation-2026-10-02/screenshots.json)记录每张图片的测试名、结果包、原附件元数据和 SHA-256。

- G2：比较 [raw 柱状图](evidence/charts-presentation-2026-10-02/g2-raw-柱状图.png) 与 [draw 柱状图](evidence/charts-presentation-2026-10-02/g2-draw-柱状图.png)，第二层颜色随取值依据变化，但累计高度与原值读数不变。
- G3：[混合图竖屏](evidence/charts-presentation-2026-10-02/g3-styled-混合图.png) / [稳定横屏](evidence/charts-presentation-2026-10-02/g3-landscape-混合图.png)；双轴颜色/字体、类目候选步长及旋转保留。Bar 保持左类目/下值轴，不出现不支持的次轴。
- G4：[开启避让](evidence/charts-presentation-2026-10-02/g4-annotations-混合图.png) / [关闭避让](evidence/charts-presentation-2026-10-02/g4-without-avoidance-混合图.png)；开启后标注区域不再被数据文字占用，关闭仍展示既有允许重叠的行为。
- G5：[共享选择](evidence/charts-presentation-2026-10-02/g5-selected-混合图.png) / [关闭主体高亮](evidence/charts-presentation-2026-10-02/g5-disabled-混合图.png)；同一类目同时出现线点环与真实堆叠柱段矩形，关闭只清掉主体覆盖层，提示/读数仍可工作。

逐张复核曾发现：旧 G3 横屏附件截在旋转提交过程中，只看到裁切的竖屏窗口。UI 原本通过不代表这些图片合格。现在等待横/竖屏窗口与图表尺寸连续稳定，断言图表占用正常宽度且位于窗口内，使用 `XCUIScreen.main.screenshot()` 后重新采集。四页补验全部通过，SDK 源码没有为此改动。

单测另外覆盖复用/重配前后 **1×/2×/3×** 像素一致性、稳定 ID、缺测/隐藏系列、清除覆盖层后的原图一致、长文本/窄宽边界以及数据/命中不变；不将源码包含字段或测试截图存在等同于效果通过。

## 4. 本轮发现并修复的问题

- Combined 依赖规则仍将颜色分区和阈值控件禁给柱系列，导致 G2 UI 无法关闭分区。删除过时的仅线族限制，新增可用性断言及三页 off/x/y 往返验收。
- 轴文字测量与 UILabel 实际整像素尺寸不一致，导致候选底部标签被错误淘汰；测量取整后按最终布局预算验收。
- 默认 LineHitTarget 的历史 `kind` 为空字符串，不能直接作为图形族校验。选中覆盖层内部按实际类型识别，不更改旧回调字段契约。
- G4 截图发现参考线标题遮住附近数据标签。避让增加已放置标注的占位，并在标线创建后做最终处理；新增四种渲染器回归。标注自身的位置不变。
- 重播入场动画立即清除旧主体选择、准线和提示，避免归零帧后反馈不一致；四渲染器回归保证未启动 display link 也先清理状态。
- 对齐 OC 新增数据标签默认字号（10pt），以默认 Swift 主题为断言，防止两种语言接入默认外观不一致。

## 5. 未通过/中断轮次的处置

没有把失败轮次合并写成整轮通过：

- `/tmp/HYMCharts-G2-G5-final-20261002.log`：340 项单元测试通过；随后 G3 UI 期间模拟器服务断开、runner 重启，收集阶段停滞，本轮被终止，不能作为完整成功结果包。
- `/tmp/HYMCharts-G2-G5-verified-20261002.log`：342 项单元测试通过；G2/G3/G5 UI 通过，G4 在向 `demo.search` 合成点击事件时超时。之后失败诊断收集停滞，此轮亦被终止；这不等同于四项 UI 全部通过。
- 后续验收使用单一测试会话、`-collect-test-diagnostics never` 和明确超时；测试进程期间短时防空闲睡眠，保留断言与截图。最终结论只采用上节明确完成的结果包。
- 早期默认 DerivedData 中的成功 `.xcresult` 曾被 Xcode 自动轮替删除，因此最终采用独立 `-resultBundlePath`，同时将截图与摘要存入仓库。不会把已丢失的临时包当作可回放证据。

- 全部 28 项图表 UI 首轮：`HYMCharts-complete-regression-20261002` 中 342 项单元测试通过，27 项 UI 通过、1 项失败。失败来自接缝场景仍查找 G1 更新前的提示文案，不是忽略或放宽几何断言；将其改为验证当前兼容边界模式及“不补业务点、缺口不保证全域无缝”的限制提示。修正后的两页专项 UI 通过（33.777 秒），失败轮与专项复验的原始日志均存入[便携证据目录](evidence/charts-presentation-2026-10-02/README.md)。

- 修正后重新从头执行完整单元集与全部 28 项图表 UI，`HYMCharts-complete-regression-v2-20261002` **342 + 28 全部通过**。本记录的最终完整结论采用这一轮；上一轮失败日志继续保存，不被成功结果覆盖。

## 6. 附加闭环：G1 证据与可重复校验

全量文档链接检查发现五处引用同一个未保存的历史百分比面积目录。已于 **2026-10-02** 重新执行 G1 的 8 项专项单元测试与 1 项两页 UI 对照，均通过；[新证据](evidence/charts-legacy-comparison/2026-10-02-g1-percent/README.md)按实际补验日期存放，而不是伪造 9 月 30 日结果。未修改 G1 数学语义，也未新增旧 AA 运行。

新增 `scripts/check_chart_evidence.py`，离线检查图表指南、入口及证据 README 中的本地链接，以及本轮 G1 / G2–G5 图片的来源元数据、PNG 文件、重复项、缺失项、漏列项和 SHA-256；不依赖 `/tmp` 的 xcresult 是否还存在。配套 4 项 Python 测试包含篡改、丢失、重复、失败附件、路径逃逸和非法 JSON 的负向案例。这个工具只验证保存材料完整性，不替代 XCTest 或视觉验收。

## 7. 可重复执行

```sh
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -derivedDataPath /tmp/HYMCharts-G2-20261002 \
  -resultBundlePath /tmp/HYMCharts-G2-G5-rerun.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:SwiftFunctionProjectTests \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 240 \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests \
  test CODE_SIGNING_ALLOWED=NO
```

结果路径必须未存在；换机器时用本机 simulator UUID。上述命令执行 342 项单元和全部 28 项图表 UI；需要定向定位时，再把 UI 类筛选改为具体方法，不将定向通过代替完整回归。独立产物的构建/测试命令见 [Integration README](../Examples/ChartsIntegration/README.md)，检查脚本为 `Examples/ChartsIntegration/check_product.py`；旧字段清单检查：`python3 scripts/check_chart_migration_inventory.py`；便携证据检查：`python3 scripts/check_chart_evidence.py`；校验器测试：`python3 -m unittest discover -s scripts -p 'test_check_chart_evidence.py'`。

## 8. 未做事项与下次入口

- G1：冲突缺测策略、不兼容百分比链和零分母规则仍保留显式回退，不能静默补业务值。
- G6：反向轴、数值 X、范围柱/范围带、逐点图片等继续作为候选，不在本轮临时扩张数据模型。
- R2/R7/R8：真实项目的稳定身份映射、业务原值/旧累计语义、签名和最终发布需要真实调用环境；当前没有据此宣称迁移完成。
- R4：外部程序选点、跨更新恢复、完整生命周期与跨页状态不因 G5 主体反馈已实现而自动完成。
- 开始下一批前先复跑本记录命令；若扩大 G1/G6 范围，先选定具体场景与数据契约。不要再次把 G2–G5 列为“核心缺失”。
