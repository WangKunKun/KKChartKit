# HYMCharts 独立接入验证

2026-10-09 N4 v6：Swift 与纯 OC 宿主同时载入 v1–v6 六份 `energy*.json`；新增 `energy-interaction-v6.json` 表达 Tooltip 内容／取值及图例布局。`neutral=true` 必须六份文档的检查均通过；JSON 只进入宿主，不打入 SDK framework。版本及降级规则见[模型指南](../../docs/charts-neutral-model-guide.md)。

同一个 `HYMCharts.framework` 由现有 Charts 源码构建，SwiftHost 仅 `import HYMCharts`，OCHost 仅 `#import <HYMCharts/HYMCharts-Swift.h>`。两个宿主不编译 SDK 源码，不使用 `@testable`、App bridging header 或测试专用 renderer。此工程验证独立导入，不承诺旧模型适配已完成。

目录：

- `ChartsIntegration.xcodeproj`：独立于原 Demo 工程的 framework、两个 App 和 UI 测试 target。
- `SwiftHost/`：公开 Swift 接口配置、更新、显隐、真实点击；另实例化公开 SwiftUI LineChart 包装。
- `OCHost/`：全部业务源码为 Objective-C；通过生成头调用，验证错误保留有效数据与桥接对象释放。
- `UITests/`：启动两个 App，读取其验证结果，再点击图表检查更新后的值 `500`。
- `generate_project.py`：使用 Python 标准库重建工程，按确定顺序引用当前 101 份图表源码。保留 6 种 SwiftUI 包装；framework 排除 Demo/Debug/参考目录及资源。两个宿主额外携带共用的 `ChartSpecifications/energy*.json`，不把样本打进 framework。新增 SDK 文件后重新运行并审阅工程差异。
- `check_product.py`：检查生成 OC 头、SwiftUI 公开类型、`@rpath` 加载路径，以及无 AA/JS/WebKit/App 依赖或 Demo/fixture 资源。

当前使用 iOS 15 deployment target、Swift 5 语言模式和 Xcode 26.3。真实业务工程的最低版本和交付方式待核对。这里只维护 Xcode framework 这一种产物；尚未打包发行版 XCFramework、SPM 或 CocoaPods。

2026-10-03：两个宿主新增同一份通用模型 JSON 的公开导入验证，Release **2/2 通过**，原命中/释放断言保留。Swift 使用 ChartSpecification + HYMChartsSpecificationAdapter；纯 OC 使用 HYMChartSpecificationDocument + makeNativeBridge。当前 framework 共 95 份 SDK Swift 文件，详见 [通用模型证据](../../docs/evidence/charts-neutral-model-2026-10-03/README.md)。

在仓库根目录运行（替换成可用的模拟器 UUID，避免重名设备）：

```sh
python3 Examples/ChartsIntegration/generate_project.py
xcodebuild -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Debug \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -derivedDataPath /tmp/HYMChartsIntegration -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO
```

将 `Debug` 改为 `Release` 可在优化产物上运行相同测试。纯框架设备构建：

```sh
xcodebuild -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -target HYMCharts -configuration Release -sdk iphoneos build \
  SYMROOT=/tmp/HYMChartsDevice/products OBJROOT=/tmp/HYMChartsDevice/objects CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartsDevice/products/Release-iphoneos/HYMCharts.framework
```

业务宿主可将此工程加入 workspace，对 `HYMCharts` 建立 target 依赖并 Embed & Sign framework；Objective-C 宿主也需嵌入 Swift 运行库。不得把模拟器 framework 用于设备。当前验证为未签名构建和模拟器运行，发布签名/设备安装仍需业务工程验证。

2026-09-30：Debug 与 Release 各 2 项 UI 测试通过。两个宿主分别验证 30 次同步创建/配置/布局/释放；这不等同于长时间滚动、动画、离屏任务或内存峰值测试。iPhone arm64 Release 构建通过。独立编译仍有现有协议 existential 写法的未来 Swift 语言模式警告，迁至 Swift 6 时须处理。

[本批次证据](../../docs/evidence/charts-legacy-comparison/2026-09-30-foundation/README.md) · [字段处置清单](../../docs/charts-legacy-field-inventory.md) · [实施计划](../../docs/charts-legacy-replacement-plan.md)

2026-09-30 G1：宿主增加 `theme.stackedAreaBoundaryMode` / `bridge.stackedAreaFollowsBaseline` 的公开调用，产物检查器核对新 Swift 类型和 OC 头属性；本批 Release 编译/运行记录见 [G1 证据](../../docs/evidence/charts-legacy-comparison/2026-09-30-g1/README.md)。宿主本身仍使用原基础输入，面积几何由主工程定向用例验证。

2026-09-30 G1 跨零：新增内部 `LineStackedAreaTransitions.swift`，工程已重新生成，框架现含 76 份 Swift 源码；复用既有 Swift / OC 开关，无新增公开签名。运行证据见[跨零批次](../../docs/evidence/charts-legacy-comparison/2026-09-30-g1-crossing/README.md)。

2026-09-30 G1 前层换链：新增内部 `LineStackedAreaSignEnvelope.swift`，工程重新生成后现含 77 份 Swift 源码；配置继续复用同一开关。该文件保留已解析区间的正负连续边界，不包含 Demo fixture 或旧 AA 依赖。

2026-09-30 G1 缺测底边：新增内部 `LineStackedAreaGapBaseline.swift`，工程重新生成后现含 78 份 Swift 源码。公开 Swift / OC 开关不变；[本批构建与几何验证](../../docs/evidence/charts-legacy-comparison/2026-09-30-g1-gaps/README.md)。

2026-09-30 G1 自动百分比：新增 `LinePercentStackedAreaGeometry.swift` 与 `LinePercentAreaNormalizer.swift`，当时工程含 80 份 Swift 源码；复用既有 Swift / OC 开关。历史百分比证据目录未保存，已在 [2026-10-02 补验](../../docs/evidence/charts-legacy-comparison/2026-10-02-g1-percent/README.md)中重跑主工程的专项单元与 UI 测试；该目录不冒充 9 月 30 日构建记录，最新独立产物验证见下一节。


## 2026-10-02 G2–G5 公共入口维护

G2–G5 批次的 framework 源列表为 85 个 Swift 文件。Swift 和纯 OC 宿主均使用柱/条颜色分区取值源、独立轴样式、参考线/色带文字样式以及主体选择主题；`check_product.py` 检查这些类型出现在公开接口/生成头中。新 Release 模拟器运行和未签名 iOS 设备编译、产物 SHA-256 与边界见 [G2–G5 验证记录](../../docs/charts-presentation-g2-g5-2026-10-02.md)。


## 2026-10-02 G1 正负分链入口

工程已重新生成，当前为 87 份 SDK Swift 源码。Swift 宿主编译 `.diverging`，纯 OC 宿主通过生成头调用 `stackedAreaUsesDivergingChains`；两个宿主的 30 次配置/布局/释放循环使用含正负、缺测的自动百分比堆叠。产物检查新增枚举 case、OC 开关及公开降级诊断字段。[本批独立构建与运行记录](../../docs/evidence/charts-legacy-comparison/2026-10-02-g1-diverging/README.md)。

## 2026-10-09 N1 schema v3 验收

本批使用 Release `build-for-testing` 后 `test-without-building`，Swift 与纯 OC 公开导入 **2/2 通过**；每个宿主的 `neutral=true` 都要求 v1、v2、v3 三份 JSON 通过。v3 覆盖逐系列值轴颜色分区，沿用已有不可变 OC document/bridge，不导入 App Demo。产物审计通过；仅允许 Swift 编译器的 `.abi.json` 元数据，样例 JSON 不进入 framework。官方结果、构建和运行日志见 [N1 证据](../../docs/evidence/charts-neutral-zones-2026-10-09/README.md)。

## 2026-10-09 N2 schema v4 验收

Release framework 构建和公开产物审计通过，Swift / 纯 OC 宿主 **2/2 通过**。N2 当时每个宿主的 `neutral=true` 都要求 v1–v4 四份共享 JSON 通过；v4 新增值轴显式刻度、标签数字格式与单位、域/值轴系统字重及类目标签候选间隔。Swift 宿主检查公开映射结果、字重与格式化输出；OC 宿主检查 document 往返、样本身份以及 bridge 创建/更新。普通公开导入不使用 `@testable`，不包含 App Demo；运行环境仍仅 arm64 模拟器，并非真机或正式分发验收。见 [N2 任务进度](../../docs/charts-neutral-axes-task-progress-2026-10-09.md)与[证据](../../docs/evidence/charts-neutral-axes-2026-10-09/README.md)。

## 2026-10-09 N3 schema v5 验收

Release framework 包含 99 份 Swift 源码。公开 Swift 与纯 OC 宿主 **2/2 通过**，该批 `neutral=true` 要求 v1–v5 五份文档通过。Swift 检查主次轴映射、隐藏源项、线型、文字字号/字重、色带范围及 JSON 往返；OC 检查 document 往返、隐藏标志、轴身份、样本身份和 bridge 创建／更新。新 JSON 仅进入宿主资源，SDK 无 Demo／fixture／JS／WebKit 依赖。见 [N3 进度](../../docs/charts-neutral-annotations-task-progress-2026-10-09.md)与[证据](../../docs/evidence/charts-neutral-annotations-2026-10-09/README.md)。仅 arm64 模拟器运行，不宣称真机或正式分发。

## 2026-10-09 N4 schema v6 验收

Release framework 包含 101 份 SDK Swift 源码。普通公开 Swift 与纯 OC 宿主 **2/2 通过**；`neutral=true` 要求 v1–v6 六份共享 JSON 全部通过。Swift 检查公开 Tooltip view 配置、布局／取值策略、图例映射、原值不变及 JSON 往返；纯 OC 通过字典／document 创建和更新 bridge，验证恢复旧 v5 时不残留 N4 提示覆盖。公开接口、依赖与资源审计通过，新增 JSON 仅进入宿主而非 SDK。见 [N4 进度](../../docs/charts-neutral-interaction-task-progress-2026-10-09.md)与[证据](../../docs/evidence/charts-neutral-interaction-2026-10-09/README.md)。仅 arm64 模拟器运行，不宣称真机／正式分发或全部视觉布局已完善。

## 2026-10-09 N4 固定顶部布局公共接口补充

框架仍包含 101 份 SDK Swift 源码。Swift 宿主验证 N4 转换后的 `fixedTopUsesPlotArea == true`；纯 OC 宿主通过生成头读写该选项并在旧版文档更新时恢复原生基线。产物检查器同时核对公开 Swift interface 和 OC 生成头。六版共享 JSON 不变，无 schema 升级；Release 构建／运行及范围见[布局质量证据](../../docs/evidence/charts-neutral-tooltip-layout-2026-10-09/README.md)。这不是图例／提示的所有组合像素金图、真机或正式分发验收。
