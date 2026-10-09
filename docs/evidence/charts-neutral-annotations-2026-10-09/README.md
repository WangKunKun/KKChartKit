# N3 值轴标线／色带 v5 验收证据

日期：2026-10-09（Asia/Shanghai）。本批仅为 N3 中立值轴标注，不改旧证据、不重复计算 N1/N2 测试，也不宣称 G6 或旧 mapper 完成。

## 结果与范围

| 检查 | 本批结果 / 证据 |
| --- | --- |
| 主工程全部单元 + 5 项相关 UI | **431 + 5 = 436/436**，零失败／跳过；[摘要](main-summary.json)、[日志](main-test.log.gz) |
| 独立 Release Swift / 纯 OC 宿主 | **2/2**；[摘要](public-import-summary.json)、[构建](public-build.log.gz)、[运行](public-test.log.gz) |
| Foundation-only Swift 6 完整严格并发 | **PASS**；v1–v5 五份 JSON 逐字节复现，v1–v4 未改；[命令/返回码/哈希](core-validation.json) |
| SDK 公开产物 | **PASS**；99 份 Swift 源码，标注 API/生成 OC 头/六个 SwiftUI 封装；无 AA/JS/WebKit/App 依赖或 Demo/fixture 资源；[审计](framework-product-audit.json) |
| 旧字段库存与中立覆盖 | **197 声明 / 59 能力主题 / 15 原生复核主题**；55 已表达 / 31 待补 / 104 外层 / 7 不承接；[库存](inventory-check.json)、[覆盖](coverage-check.json) |
| Python 审计回归 | **27/27**；[日志](python-tests.log) |
| 文档/原始截图离线完整性 | 见[检查结果](offline-evidence-check.json)，只证明文件/链接/来源/哈希一致，不代替真实运行和目视检查 |

环境：Xcode 26.3；iOS 18.6 iPhone 16 Pro arm64 模拟器 `781C9872-DAE0-4996-A623-36115772B60F`。Release 两宿主均要求 v1–v5 五份共享 JSON 的内部断言通过；不以只编译成功替代运行。

主工程相关 UI 为 N3 四页标注开关／复位及折线页次轴关闭／恢复配置隔离、N2 四页轴展示、N1 四页颜色分区、G1 边界切换以及不支持能力恢复。新单元测试覆盖版本/降级/保留键、非法身份/坐标/样式、主次轴重排、四 renderer 裁剪/层次、G1 三模式/百分比/缺测、文字 clamp/hide/缩窄、OC 原子更新/视口，**不是全量 UI、真机、全主题或性能验收**。

## 原始截图与视觉范围

最终 N3 UI 的四张原始 PNG 在 [screenshots](screenshots/screenshots.json)；保留 [xcresulttool 原始清单](screenshots/manifest.json)与[可移植来源/散列清单](screenshots/screenshots.json)。未经裁剪、拼接或合成。

四张最终原图已逐张复核：Line / Column / Combined 显示值 40 的红色虚线与 10–30 的绿色半透明带，Bar 显示对应竖线／竖带；黑字白底标签位于绘图区内，带体在不透明柱条后方，标线和文字在前方。截图中正负数据及缺测仍保留，未通过改写数据制造标注效果；严格的原值／命中不变与层次关系另由单元断言覆盖。既有标题/轴/图例在深色下对比度偏低；本批标注显式黑字白底只改善样例可读性，不修复全局主题。水平 Bar 将逻辑值轴标线转为竖线、色带转为竖带；多个标注之间的文本避让不在本切片内，不能据四张图宣称所有对齐/次轴/长文字组合均已目视验收。

## 开发期与最终结果隔离

- 最初 sandbox 内 xcodebuild 无法访问 CoreSimulator（[环境日志](development-sandbox.log.gz)），没有产生可计数测试结论。获准在沙箱外运行后核心专项 **4/4**（[日志](development-core.log.gz)）。
- 适配／渲染专项 **8/8** + 覆盖四页的 UI **1/1**（[日志](development-adapter.log.gz)）。这些不额外累计到最终主工程数量。
- 详细控件用折叠区避免挤占短 Form；旧 G1 / “不支持能力恢复”UI 使用既有 Form 内定位函数替代全屏滑动，不删除能力拒绝断言。
- 首次完整回归 **436/436**（[摘要](development-main-summary.json)、[日志](development-main.log.gz)）。随后静态复查发现次轴隐藏后 Picker 仍可能引用失效选项，改为显示有效轴的 Binding，并增强 N3 UI 的关闭／恢复次轴独立状态断言。最终结果重新运行，不将首次完整回归额外累计。
- xcresulttool 首次沙箱导出被测试报告缓存写权限阻止；获准后使用同一结果包导出，没有修改 PNG 或伪造结果。

## 可追溯性

[限定范围源输入散列](source-inputs.json)记录代码、配置及文档，不是全 checkout 备份；[相对 N2 输入差异](source-delta-from-n2.json)列出本次变化，不将旧工作归因于 N3。原生 Cartesian renderer / 坐标与堆叠实现保持未修改。静态文件另有[证据散列清单](artifact-hashes.json)；该清单自身不自哈希。

完整 xcresult 位于本机 `/tmp`，可能被系统清理。仓库保留摘要、日志、原始截图及来源清单，可离线核对，但不是完整结果包的替代备份。

## 复跑

在仓库根运行；不要覆盖既有 resultBundlePath。Foundation-only 命令见 [core-validation.json](core-validation.json)。

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAnnotationsDerivedData \
  -resultBundlePath /tmp/hym-neutral-annotations-recheck.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralAnnotationsOnFourPagesAndReset \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralAxisPresentationPerAxisAndResetOnFourPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralValueColorZonesPerSeriesSourceAndResetOnFourPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralG1BoundarySwitchAndResetInExistingPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/generate_project.py
xcodebuild build-for-testing -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAnnotationsPublicDerivedData \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAnnotationsPublicDerivedData \
  -resultBundlePath /tmp/hym-neutral-annotations-public-recheck.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralAnnotationsPublicDerivedData/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_chart_evidence.py
git diff --check
```

当前交接与下一建议 N4 见[任务进度](../../charts-neutral-annotations-task-progress-2026-10-09.md)。本轮已推送原有九提交至 `a5ace6a`，N3 增量仍在本地待提交；不重复历史关机操作。
