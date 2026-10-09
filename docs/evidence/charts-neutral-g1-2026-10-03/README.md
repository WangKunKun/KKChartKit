# G1 通用模型 v2：最终验证证据

日期：2026-10-03，Asia/Shanghai。范围为 Foundation-only 描述版本演进、G1 三种堆叠边界的 HYM 映射、同页 Demo 以及公开 Swift/OC 接入；不改写原始值、采样身份或原生几何算法。

## 结果及口径

| 项目 | 结果 | 保存的证据 |
| --- | --- | --- |
| 主工程完整单元 + 相关 UI | **395 + 2 = 397/397**；0 失败、0 跳过 | [正式摘要](main-summary.json)、[测试树](main-tests.json)、[压缩日志](main-xcodebuild.log.gz) |
| 独立 Release Swift/纯 OC 宿主 | **2/2**；两宿主各自要求 v1、v2 共用 JSON 检查通过 | [正式摘要](public-import-summary.json)、[测试树](public-import-tests.json)、[压缩日志](public-import-xcodebuild.log.gz) |
| Foundation 核心、JSON 兼容 | Swift 6 完整严格并发编译；两版例子逐字节一致 | [命令、退出码和 SHA-256](core-validation.json)、[日志](core-validation.log) |
| Release SDK 产物检查 | v2 公开枚举/字段、OC JSON 文档入口存在；无旧引擎、App/Demo/样例资源混入 | [产物审计](framework-audit.json) |
| Python 回归 | **24/24** | [逐项日志](python-tests.log) |
| 197 旧声明覆盖一致性 | **40 已表达 / 46 未建模 / 104 外层职责 / 7 明确不支持** | [覆盖摘要](coverage-summary.json)、[旧字段检查](inventory-check.log) |
| 文档及截图离线完整性 | 已检查本批最终 2 张及两批既有截图；不等价于渲染验收 | [检查日志](evidence-check.log) |

- 主工程最终运行：`/tmp/HYMChartNeutralG1Final-20261003.xcresult`，22:26 完成。初次专项 **31 项**（20 原有 + 11 新增）和初次主工程 **397 项**成功运行仅用于开发，不与最终结果累加。
- 公开导入运行：`/tmp/HYMChartNeutralG1PublicImport-20261003.xcresult`，22:22 完成。Release 测试后只改变 App Demo 的第三系列颜色；SDK/宿主运行时代码未改变，最终主工程已对该颜色改动重跑。
- 两次正式运行均为 iPhone 16 Pro / iOS 18.6 / arm64 模拟器，设备 UUID `781C9872-DAE0-4996-A623-36115772B60F`。平台细节及时间戳以官方摘要为准。
- 主工程仅运行全部单元和两项相关 UI，**不是全部 UI**；Release 测试使用普通 `import HYMCharts` 和生成 OC 公开头，不使用 `@testable`。

## 最终截图与人工复核

- [折线图](screenshots/E0D5BF50-20B3-4ABF-8776-5DA05292282B.png)：显示 `schema v2 · diverging`；基底缺测时面积统一断段，另一层原始点保留。
- [混合图](screenshots/8B0D8008-D46B-4486-AE14-A521130F229E.png)：柱与线族各自计算；第三系列青绿色可与橙色区分，缺测处保留原始点，三段控件选中正负分链。
- [xcresult 原生附件清单](screenshots/manifest.json) 与 [便携哈希/来源清单](screenshots/screenshots.json) 保留成功用例、导出原名、时间戳和设备信息。上述 PNG 是原始附件，不是重新绘制图片。
- UI 用例实际操作三种模式与恢复默认；模型/渲染器测试另核对百分比分母、缺测优先级、身份与命中、失败更新不污染旧图、视口保留/重置。
- 目视范围仅这两个最终页面。已有静态主题在深色系统背景上的标题/部分标签对比度偏低，不是本轮新增，不声称完成全主题无障碍验收。
- [初次运行截图](preliminary-screenshots/README.md) 仅为过程记录；当时混合图两线族同色，最终 Demo 已区分颜色并重跑，不能替代最终证据。

## 复跑

在仓库根执行，下列结果路径必须尚不存在；已有 xcresult 应保留，换新的路径：

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralG1DerivedData \
  -resultBundlePath /tmp/HYMChartNeutralG1Final-20261003.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralG1BoundarySwitchAndResetInExistingPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralG1Integration \
  -resultBundlePath /tmp/HYMChartNeutralG1PublicImport-20261003.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralG1Integration/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 -m unittest discover -s scripts -p 'test_check_chart_*.py' -v
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 scripts/check_chart_evidence.py
```

独立 Foundation 编译及示例复现的准确参数列表保存在 `core-validation.json`，可直接逐条运行。测试摘要与附件由 `xcrun xcresulttool get test-results summary/tests` 及 `export attachments` 从实际结果导出，不通过解析控制台估算成功数量。

## 源码对应与未覆盖边界

[源码输入哈希](source-inputs.json) 保存相关源码、测试、项目、配置、脚本与文档的相对路径和 SHA-256；[产物哈希](artifact-hashes.json) 核对本目录的摘要、日志、截图等静态证据。它们是本轮保存时的内容校验，不是全工作区快照，也不证明未来代码行为。

- 工作区包含大量前序未提交变更；没有提交、推送、清理或覆盖这些工作。历史证据保持原样。
- 本批未做真机、真实业务页面、实际第二绘图库、全量 UI、全主题或分发/回退验收。`RecordingAdapter` 测试替身不是第二生产后端。
- G6 连续 X / 反向值轴仍明确拒绝；zones、标注及 Tooltip/图例的完整通用描述、R2 旧输入 mapper 等仍独立待做。
- 主工程存在既有资源命名、协议 existential 等警告；测试通过不表示 warning-free。
- G1 更新的是另列的原生边界主题，不新增旧声明条目，因此 197 项分类计数不变；不能将该切片称为整库迁移完成。

继续入口：[本轮任务进度](../../charts-neutral-g1-task-progress-2026-10-03.md) · [通用模型指南](../../charts-neutral-model-guide.md) · [覆盖矩阵](../../charts-neutral-model-coverage.md)。
