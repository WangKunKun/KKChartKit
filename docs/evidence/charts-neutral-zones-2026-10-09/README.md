# N1 值轴阈值颜色 schema v3：最终验证证据

日期：2026-10-09，Asia/Shanghai。范围是逐系列值轴阈值颜色的 Foundation-only 契约、HYM 映射、Swift/OC 公开入口及四页现有 Demo。复用原生分区能力，不改渲染器算法、原始贡献、缺测或命中身份；不覆盖面积填充。

## 最终结果及口径

| 项目 | 结果 | 保存的证据 |
| --- | --- | --- |
| 主工程完整单元 + 相关 UI | **406 + 3 = 409/409**；0 失败、0 跳过 | [官方摘要](main-summary.json)、[测试树](main-tests.json)、[完整日志](main-xcodebuild.log.gz) |
| 独立 Release Swift / 纯 OC 宿主 | **2/2**；每个宿主都要求 v1/v2/v3 共享 JSON 检查通过 | [官方摘要](public-import-summary.json)、[测试树](public-import-tests.json)、[构建日志](public-import-build.log.gz)、[运行日志](public-import-xcodebuild.log.gz) |
| Foundation 核心与 JSON | Swift 6 完整严格并发编译；三版示例逐字节复现，旧两版不变 | [命令、退出码及哈希](core-validation.json)、[日志](core-validation.log) |
| Release SDK 产物 | 新值轴分区类型/字段可公开导入，OC 文档入口保留；无旧引擎、Demo 或样例资源混入 | [产物审计](framework-audit.json) |
| Python 审计回归 | **25/25** | [逐项日志](python-tests.log) |
| 197 旧声明覆盖一致性 | **40 已表达 / 46 未建模 / 104 外层职责 / 7 不支持或不承接**；59 主题 / 14 原生复核主题 | [覆盖摘要](coverage-summary.json)、[旧声明检查](inventory-check.log) |
| 文档及截图完整性 | 本批 7 张及既有三批 45 张，共 52 张原始 PNG；离线完整性不等价于渲染验收 | [检查日志](evidence-check.log)、[差异空白检查](diff-check.log) |

- 主工程正式结果：`/tmp/hym-neutral-zones-final-20261009.xcresult`，10:18 完成。全部单元与三项相关 UI，不是全部 UI。
- 公开导入正式结果：`/tmp/hym-neutral-zones-public-final-20261009.xcresult`，10:19 完成。先 Release build-for-testing 成功，再 test-without-building；普通 `import HYMCharts` / 生成的 Objective-C 公开头，不使用 `@testable`。
- 两次均使用 Xcode26_3、iPhone 16 Pro / iOS 18.6 / arm64 模拟器，UUID `781C9872-DAE0-4996-A623-36115772B60F`。精确平台/时间以官方摘要为准。没有真机运行或本批设备构建验收。
- 正式编译后没有修改 SDK、Demo、宿主或 XCTest 代码；随后仅补充文档、离线审计脚本和证据。

## 契约与回归范围

- 显式 schema v3、构造器默认 v1；v2/v3 必填 G1 边界。v1/v2 夹带保留分区键（包括 null）、带分区降级、未知版本均拒绝。其他未知键仍遵循已有 Codable 行为，不据此宣称未建模能力有诊断。
- 阈值有限且严格递增，区间左闭右开；等于阈值进入下一段；nil 上界只能末段；nil 颜色/未覆盖尾部继承系列色，不重启负值色策略。非法 RGBA、阈值和结构有逐项字段路径。
- 柱/条 raw/draw、水平/垂直、主次轴及 Combined 图形族；无堆叠、普通、自动/固定百分比、隐藏/恢复。专项测试核对 raw=20 与 draw=70，以及百分比 draw=100/35 等差异。
- 线/面积仅 draw；raw 明确拒绝，隐藏系列也不绕过。G1 三种边界、缺测、稳定系列/样本身份保持；颜色映射不覆盖面积填充。
- OC JSON 文档及 bridge 创建/更新/重排、失败更新保持旧图与视口、显式保留/重置视口。两个独立宿主复用同一 v3 示例并继续检查 v1/v2。
- 三项 UI 分别验证四页分区开关/逐系列 ID/柱族来源与 reset、G1 切换/reset、不支持能力诊断与恢复。

## 原始截图与人工复核

以下 7 张均来自正式 N1 UI 用例成功附件，已逐张查看，没有重绘或修改：

| 页面 / 取值 | 原始 PNG |
| --- | --- |
| Line / draw | [折线图](screenshots/AC3EB33B-F57C-4F8E-8470-81F3D3A037E8.png) |
| Column / draw | [柱状图](screenshots/74628E7E-7175-4202-A224-406B3E006A25.png) |
| Column / raw | [柱状图原始值](screenshots/6132FD72-1678-400E-83FB-D4ABD46778C7.png) |
| Bar / draw | [条形图](screenshots/05538A52-11CF-4C21-8775-D0F6ED414929.png) |
| Bar / raw | [条形图原始值](screenshots/7708F2B0-230E-47F8-9FF8-4E759D2F34AA.png) |
| Combined / draw | [混合图](screenshots/0258D6CF-F9FE-4EAF-B2AB-22C1FE55E285.png) |
| Combined / raw | [混合图原始值](screenshots/659EFB83-AD82-455B-8D05-49FEDD97B44F.png) |

- [原生附件清单](screenshots/manifest.json)与[便携哈希/来源清单](screenshots/screenshots.json)保存测试名、设备、原始导出名、成功状态及时间戳。
- 四页均显示 schema v3 与正确来源状态；柱/条方向正确，Line 描边/点颜色分区生效，原面积色保留，缺测处断开且另一原始点保留；Combined 图形族未串色。
- **这些截图不是 raw/draw 差异的视觉证明**：保存的 source-0 是首层，raw/draw 相同；差异由上述专项测试中的上层系列证明。逐系列选择状态另由 UI 断言验证。
- 柱/条/混合页为滚动后的表单位置，分区开关部分在可视范围外，来源控件和状态仍可见；不是把裁切截图当作控件缺失。
- 已有深色背景下静态标题/部分标签对比度偏低，本批未修复，未做全主题无障碍验收。没有把这 7 张图外推为全部组合的像素验收。

## 开发失败与修正（非正式通过结果）

- [首次专项日志](development-focused.log.gz)：15 项中 1 项因 UIKit 灰度黑与 sRGB 黑对象比较不等失败，修正测试的预期 RGBA；不是运行时颜色算法变更。
- [首次完整回归日志](development-main.log.gz)：406 单元中旧“未来版本”测试硬编码 3 导致一个测试两条断言失败，三项 UI 通过。改为 `latestSchemaVersion + 1` 后正式重跑 409/409。
- 覆盖审计的旧编码锚点失效，改用真实边界编码语句；新增 Y 子集不冒充完整 zones 的检查后，最终 Python 25/25。
- 产物审计初次误拒编译器 `.abi.json`；仅放行 `Modules/HYMCharts.swiftmodule` 内 ABI 元数据，样例 JSON 资源仍拒绝。
- 开发运行不与最终数量累加。既有 Swift existential、资源等警告仍在，测试通过不表示 warning-free。

## 复跑命令

在仓库根执行。已存在的结果包应保留，复跑须换新的 resultBundlePath；不覆盖本批结果。

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralZonesDerivedData \
  -resultBundlePath /tmp/hym-neutral-zones-final-20261009.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralValueColorZonesPerSeriesSourceAndResetOnFourPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralG1BoundarySwitchAndResetInExistingPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

xcodebuild build-for-testing -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralZonesIntegration \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO

xcodebuild test-without-building -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralZonesIntegration \
  -resultBundlePath /tmp/hym-neutral-zones-public-final-20261009.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralZonesIntegration/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 -m unittest discover -s scripts -p 'test_check_chart_*.py' -v
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 scripts/check_chart_evidence.py
git diff --check
```

核心编译及逐字节复现参数见 `core-validation.json`。官方摘要/测试树由 `xcrun xcresulttool get test-results summary/tests` 导出；附件由 `export attachments --test-id 'ChartDemoUITests/testNeutralValueColorZonesPerSeriesSourceAndResetOnFourPages()'` 导出。不通过统计控制台 passed 文本估算最终数量。

## 输入对应与尚未交付

[源码输入哈希](source-inputs.json)保存相关源码、测试、项目、脚本、文档与例子的 SHA-256；[证据哈希](artifact-hashes.json)覆盖本目录除自身外的静态文件。只是保存时的作用域内容校验，包含前序未提交工作，不是整仓库快照或本批全部改动归因。

- 旧 `zones` / `zoneAxisX` 仍是 schema_gap / partial；N1 只完成另列的 `value-color-zones` 子集。197 旧声明处置计数不变，不能据此说旧图表模块已全部替换。
- 尚未表达 X 索引/连续 X 分区、分区面积渐变；HYM 线/面积 raw 明确拒绝。G6 连续 X/反向轴拒绝保持不变。
- 未做全量 UI、真机性能/长期生命周期、真实业务页面、第二生产后端、旧 R2 mapper、分发/回退或全主题验收。
- 未提交/推送/清理工作区；历史证据保持原样；不重复执行已结束的历史关机指令。

继续入口：[N1 进度与 N2 下一步](../../charts-neutral-zones-task-progress-2026-10-09.md) · [通用模型指南](../../charts-neutral-model-guide.md) · [覆盖矩阵](../../charts-neutral-model-coverage.md)。
