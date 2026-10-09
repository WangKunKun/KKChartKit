# 参考目录旧图表 Demo

直接编译并运行 `SwiftFunctionProject/参考图表` 中的 HMAA/HMLG/HMMT 封装、内嵌 AAChartKit 与本地 Highcharts 11.4.3。目标是先建立可操作、可截图、数据可复现的旧版基线，再用同一组输入比较 HYMCharts 并调整替换计划。

## 运行

1. 打开仓库根目录的 `SwiftFunctionProject.xcodeproj`。
2. 选择共享 Scheme **LegacyChartDemo**，选择 iPhone/iPad 模拟器，运行。
3. 首页选择场景。顶部切换 `v1 JS / v1 原生 / v2 JS / v2 原生`；右上角“配置”展开堆叠、点数、图例、顺序、提示和深浅色控件。

`SwiftFunctionProject` Scheme 仍是现有 HYMCharts Demo。两个应用的入口、Bundle ID、编译成员和资源独立。旧源码与 JS 只加入 `LegacyChartDemo` target。

## 场景与旧调用链

| 场景 | 固定输入与覆盖 | 实际组件 |
| --- | --- | --- |
| 功率曲线与业务卡片 | 三业务组、统计表头、日出日落、图标提示 | HMLGAAChartView → HMAAChartView；HMChartTitle/Header/SunView、HMIconTooltip |
| 折线、阶梯与前值 | 直线、虚线、marker、阶梯、showPrev | 旧系列转换器、JS / HMTooltip |
| 电量柱状与分组堆叠 | 两个 stackGroup、四条系列、并排/普通/百分比 | HMAAChartManager、原图例显隐 |
| 正负堆叠与百分比 | 同组跨零、正负成员、绝对值展示 | 旧堆叠与数值格式化 |
| 组内分栏与长图例 | 12 系列、gcname、stackGroupInterval、长名称 | HMIconTooltip 分栏、两版图例 |
| 混合图与双 Y 轴 | column + areaspline + spline、功率/温度、标线 | 旧类型透传、主次轴 |
| 缺测、分区和正负颜色 | 连续 5 / 12 个 NSNull、autoGap、X zones、negativeColor | 旧缺测处理与 Highcharts 绘制 |
| 提示分组与数值格式 | 独立提示表头、逐点行/组名、fractionDigits=100、金额、截断、过滤、仅名称 | 旧格式化与三种提示路径 |
| 长序列与默认窗口 | 288 / 1440 / 3000 点、defaultScope=[0,96]、X 缩放 | 旧窗口与 WebView 手势 |
| 无数据与恢复 | 空数组、强制空态、恢复数据、全零、显隐 | 旧无数据组件与完整模型刷新 |
| 旧组件多图联动 | 三图、48 点、同采样域；JS/原生可切换 | 原 HMMTAAChartView 索引广播 |

每页的 **Enlarge / Restore** 使用参考目录的 `HMAAChartFullScreenVC`。

## 可重复操作

- **完整刷新 +125**：在当前模型上更新数据，每次增加固定数值，调用 `reloadDataWithModel:`。温度系列每次增加 1 ℃。配置与显隐保留。
- **仅刷新数据**：同样更新调用方模型，随后调用旧 `onlyRefreshTheChartData`。与完整刷新对照，读取 Highcharts 实际数据核查是否接受更新。
- **程序选点 12**：调用旧 `setTouchPointXIndex:`，检查 JS、原生提示和回调各自的响应。操作文案与 `clickBlock` 回调分别记录。
- **图例**：直接点原图例开关；事件区记录 `legendTapBlock` 的系列和显隐。运行状态显示旧转换器输出的系列数。
- **读取运行状态**：只读地查询真实 Highcharts 实例，包括版本、点数、系列类型/可见性/首值/缺测数、轴范围、堆叠模式和 JS 提示内容。
- **切换版本/提示、点数或尺寸**：重建旧容器；完整刷新、堆叠、图例、反转和置顶继续走已有容器的旧刷新入口。切换点数会恢复该场景的默认配置。

基础样本由 `LCScenario.m` 生成：固定日期、统一时间轴、确定性函数，无随机数或在线数据。日出日落与统计表头是明确的示例输入，不是计算结果。后续新旧对照应复用这些输入，按实际原值与索引验收。

补测入口仍在现有页面内：

- “正负堆叠与百分比”→ 配置 → **柱 / 面积单组 / 面积多组 / 混合类型**：读取 [共享 fixture](../ChartComparisonFixtures/chart-migration-audit-v1.json)，固定 48 点；切换点数退出审计预设。完整刷新与仅数据刷新保留当前预设。
- **采样原生提示**：点击后在图内按住横移，9 秒后在页面底部输出可见原生提示的文字/frame 状态；不替换旧 delegate，不合成内部触摸回调。最终隐藏状态不能用来精确测量抬手延迟。
- 配置 → **检查转换边界**：调用旧正负拆分函数检查 NSNull 异常与复制字段，异常仅在审计入口捕获并记录，不修改旧函数。

48 点柱状正负样本和新增三个堆叠/类型预设与新侧 `LegacyReferenceComparisonTests` 共用 JSON，缺测等其他原有场景仍由工厂生成。共享资源只进入旧 Demo 和新单元测试 bundle，不进入 HYM App 的发布资源，也不代表正式旧模型适配器已经完成。

## 环境补齐和保真边界

参考目录原样参与编译，未修改绘制算法、提示 formatter、图例布局、选点或刷新实现。

- `LCProjectEnvironment.h` 为参考代码依赖的 `Language`、`colorNamed`、`Font_Size_weight`、`CHECK_NULL_EXEC_BLOCK` 提供 Demo 环境；翻译是示例文案，颜色回退为系统次要文字色。
- 旧七组能源/日出日落图片来自原资源目录。参考目录没有 `img_chart_nodata`，Demo 提供一个明确的示例 SVG 空态图；它不是老项目原图。
- `HMChartLegengView.m` 是未被实际组件引用的未完成图例，依赖目录中缺失的 Masonry；此文件不加入 Demo target。运行的两版图例均来自 `HMLGAAChartView.m`。
- 宿主使用 frame 布局适配旧组件自行调整高度的行为，并接收其垂直拖动委托；不把宿主行为算成旧图表核心能力。
- `LCChartProbe` 是只读观察工具，不改写 Highcharts 实例、旧 delegate 或提示内容。状态“已渲染”以真实 JS 实例、系列和有效 plot 高度确认，区别于仅收到页面加载回调。

这是参考源码与固定输入的运行基线；真实老项目的主题资源、调用数据和版本配置仍须单独核对。

基线后的逐场景结论见[新旧对照结果](../../docs/charts-legacy-demo-parity-results.md)。新增只读探针记录代表点的 raw/stackY/percentage 和最终 zones/connectNulls；对应 UI 用例保存运行 JSON 与程序选点 JS 截图。堆叠与缺测输入已用于新侧核心断言，完整 OC 适配与页面对等仍未完成。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `Sources/LCScenario.m` | 场景、旧模型与确定性数据 |
| `Sources/LCCatalogViewController.m` | 场景目录 |
| `Sources/LCScenarioViewController.m` | 控件、宿主布局、旧公开入口和事件显示 |
| `Sources/LCChartProbe.m` | 只读运行数据检查 |
| `Sources/LCProjectEnvironment.h` | 缺失项目环境的 Demo 替代 |
| `UITests/LegacyChartDemoUITests.swift` | 渲染和交互验收，保存截图 |

## 首轮验证记录

2026-09-30，Xcode 26.3（17C529），iPhone 15 Pro / iOS 17.2 模拟器：

- 最终 **6 项 UI 用例全部通过**。其中场景用例遍历全部 **11 组默认输入**，核对真实 Highcharts 版本、图数、类目数和有效绘图区。
- 验证四种提示模式切换与原图例显隐、完整/仅数据刷新、空态恢复与全零、1440/3000 点、堆叠/深浅色切换、旧全屏进入与返回。
- Demo 的 **Debug、Release（模拟器）构建通过**；现有 `SwiftFunctionProject` 应用 Debug 构建通过，产物中没有 AAJS bundle。
- 最终保存 **23 张运行截图**，见[截图索引](Evidence/2026-09-30/README.md)。已目视检查业务卡片、混合双轴、缺测/颜色、长图例、提示模式和全屏的代表截图。

实际观察：

1. 参考内嵌版本在运行中确认为 **Highcharts 11.4.3**，后续对比可锁定这一版本。
2. 折线样本首值从 400 经完整刷新变为 525；随后仅刷新入口的输入已改为 650，图表运行值仍为 525。此差异已用断言复现，不能继续把该入口视为等价的完整数据更新。
3. 全零输入可绘制并保持数据状态；强制空态与恢复数据分别验证。
4. 旧全屏能进入和返回，使用 90° 旋转与固定白底；截图中深色主题下标题/图例对比不足。窗口、显隐和选择的完整恢复仍需单独验收。
5. 缺测场景同时配置 autoGap 与手工 X zones；其输出应作为组合行为记录，不能凭两个字段的存在就认为同时按预期生效。

本轮确认提示模式可切换并完成渲染；触摸释放后拍摄的原生模式截图中，提示可能已隐藏。长按过程中的原生提示逐行内容、三组完整性及跨图原生提示同步，仍需继续采样。图表绘制/交互运行通过与业务语义完全对等分别记录。

最终结果包为 `/tmp/LegacyChartDemo-final-20260930.xcresult`，日志为 `/tmp/LegacyChartDemo-final.log`。初次运行曾因 Demo 宿主布局时机导致空白，后因 UI 测试查询了不支持的 `hittable` predicate 而失败；这两处均已修正，最终结果包完整通过。参考源码未改动。

后续对照采集另运行新增 **1 项 UI 用例通过**，结果 `/tmp/LegacyChartDemo-comparison-20260930.xcresult`。记录了旧百分比轴 0…1、autoGap 覆盖手工 zones、程序选点仍显示隐藏提示行等实际差异，见[对照证据](../../docs/evidence/charts-legacy-comparison/2026-09-30/README.md)。此结果与上述 6 项基线分属不同执行，本轮未重跑全部 7 项。

## 2026-09-30 重跑与补测

本次将原有 7 项与新增 4 项一起执行，**11 项 UI 全部通过**，结果 `/tmp/ChartsAudit-legacy-expanded-20260930.xcresult`。Debug 测试构建及 Release（模拟器）构建均通过。共保存 30 张截图、15 份运行/采样 JSON，见[新证据索引](../../docs/evidence/charts-legacy-comparison/2026-09-30-rerun/README.md)，首轮附件继续保留。

新增运行结果：

1. 面积单组 2 条业务系列展开为 5 条引擎系列，多组为 3 条；reverse 可改变副本顺序。混合正负累计位置需要独立契约，同 stackGroup 跨业务组的旧自动轴范围还会裁剪面积。
2. 同 stackGroup 的 spline 与 area 在旧引擎分属不同 stackKey，代表点各自 draw=raw。
3. `[1, NSNull, -1]` 触发原正/负拆分函数的 `NSInvalidArgumentException`；正拆分副本丢失提示过滤、前值、marker 和负值颜色字段。这里只记录函数异常，不声称执行了整个 App 崩溃恢复测试。
4. 实际持触采样中，功率三组场景的 v1 原生提示完整；v2 缺中间负载组，右组标题误用左组名称。12 系列分栏、format 全部原生字段和多图原生同步仍未验完。
5. 同模型强制空态开/关后，showLegend 仍为 NO；旧默认窗口 0…96 全屏往返通过，但不代表用户缩放、显隐和选择都能恢复。

旧参考组件及 HYM SDK 的运行源码均未因本次审计而修改；变化限于 Demo 预设/只读探针、共享数据、测试和资源归属。完整源码快照、字段指纹、测试摘要随本轮证据保存。

可重复执行：

```sh
xcodebuild -project SwiftFunctionProject.xcodeproj \
  -scheme LegacyChartDemo -configuration Debug \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

此 UUID 为本轮设备。本机有两个同名 iPhone 15 Pro / iOS 17.2，按名称选择会歧义；在其他机器请替换为可用设备 UUID。

## 共享输入补充（2026-09-30）

缺测与提示场景在 48 点时读取 [audit v2](../ChartComparisonFixtures/README.md)，保留其他点数原公式生成。改用共享输入后的四份旧引擎 JSON 与上一轮完全相同，详见[基础批次证据](../../docs/evidence/charts-legacy-comparison/2026-09-30-foundation/README.md)。读取代码仅为 Demo fixture 工厂，正式迁移适配器仍待实现。
