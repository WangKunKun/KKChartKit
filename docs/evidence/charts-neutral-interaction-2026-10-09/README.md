# N4 v6 Tooltip／图例证据（2026-10-09）

范围是可序列化 Tooltip 内容／类目槽位取值／稳定系列规则、图例布局／标题，及对应同页 Demo、Swift 与纯 OC 公开接入。**不包含完整旧模型 mapper、第二实际后端、G6、动态组名、业务小计或通用资源协议。**

环境：Xcode 26.3，arm64 iPhone 16 Pro 模拟器，iOS 18.6，UUID `781C9872-DAE0-4996-A623-36115772B60F`。SDK／宿主使用 Swift 5 语言模式，只有 Foundation-only 中立核心额外以 Swift 6 complete strict concurrency 编译。未做本批真机运行或设备分发验收。

## 正式结果

正式最终结果：**主工程 449/449、公共宿主 2/2，失败与跳过均为 0**。开发期首轮失败单独保留，不计入最终通过数量。

| 验收范围 | 结果 | 原始记录 |
| --- | --- | --- |
| 主工程全部单元 + 六项相关 UI | 443 单元 + 6 UI = **449/449** | [官方摘要](main-summary.json)、[压缩日志](main-test.log.gz) |
| 独立 Release Swift／纯 OC 宿主 | **2/2** | [官方摘要](public-import-summary.json)、[构建日志](public-build.log.gz)、[运行日志](public-test.log.gz) |
| Python 审计回归 | **28/28** | [执行日志](python-tests.log) |

本轮新增 12 项单元和 1 项四页 UI；相关 UI 同时覆盖 N1/N2/N3/G1 与不支持能力恢复，不是全量 UI、真机或设备分发验收。

- Foundation-only：[编译命令与六份 JSON 逐字节复现](core-validation.json)。旧 v1–v5 SHA-256 同本轮开始时完全一致；新增仅 v6 样例。
- 独立 SDK：[公开接口／依赖／资源审计](framework-product-audit.json)。101 份 SDK Swift 文件，新增核心与 Tooltip 适配两个文件；核心仅依赖 Foundation，适配文件依赖 UIKit。生成的 `.abi.json` 是编译器元数据，业务 JSON／Demo／fixture 不进入 framework。
- [旧声明库存](inventory-check.json)、[覆盖矩阵审计](coverage-check.json)、[Python 回归](python-tests.log)、[离线证据检查](offline-evidence-check.json)。矩阵为 197 项、61 主题、18 原生复核；60 已表达／26 schema 待补／104 外层／7 不承接。这不是旧 mapper 已交付数量。

## 四页原始截图

正式截图来自主工程最终结果包的 `ChartDemoUITests/testNeutralTooltipLegendOnFourPagesAndReset()`，不重绘、不拼接、不裁剪。见[原始导出清单](screenshots/manifest.json)和[可移植 SHA-256／测试来源清单](screenshots/screenshots.json)。四张均已逐张目视复核，原始尺寸 1206 × 2622：

| 页面 | 原始截图 | 复核观察 |
| --- | --- | --- |
| Line | [折线图](screenshots/FD3FA66A-4E94-4A5E-BABF-6FD6820CA8E2.png) | 当前 11:00、来源 10:00，缺测 solar 不展示，battery 为上一槽位 -10 W |
| Column | [柱状图](screenshots/963510B1-0B16-453E-B64F-E12CEC1760C9.png) | 同上；不是当前 battery 的 -20 W，也不是整体平移数据 |
| Bar | [条形图](screenshots/88269F1E-AAF2-4A72-8DE4-DD01FC064994.png) | 当前命中与上一槽位来源分离，缺测行省略；既有长单位标签裁剪仍保留 |
| Combined | [混合图](screenshots/71F247F8-CDA2-45D9-8D5C-2E2CFFC635B9.png) | 当前 11:00、来源 10:00，solar -20 W、薄层 8 W；上一槽位 battery 缺测而省略 |

四页均启用 N4 两个总开关，显示 schema v6 及 `columns · 取值 -1 · 图例 top` 状态。表单滚动位置不一，截图不代表所有详情控件同时可见。

截图只证明这四个预设：columns、fixedTop、取值 -1/clamp、顶部图例；不证明所有详情控件或全部布局组合都逐张目视验收。其他边界由单元／原生既有测试覆盖，仍不等于全量 UI。

**已发现且保留的视觉限制**：原生 fixedTop 浮在整个图表顶部，不为标题／顶部图例预留位置，因此会遮挡部分图例；本切片没有修改原生布局政策。当前命中表头／准线与“取值上一槽位”的来源说明是两个不同位置，不是数据平移。既有深色静态文字对比度问题也没有在此批修复。

## 开发期与最终结果隔离

首轮专项：12 项 N4 单元中 **11 通过、1 失败**，N4 四页 UI **1/1 通过**，见[首轮摘要](development-focused-summary.json)与[日志](development-focused.log.gz)。失败是测试把仅支持线／面积的 G1 共享边界同时套到柱／条；测试改为线／混合覆盖三边界、柱／条只用 independent。生产适配器的拒绝逻辑未改变。首轮不额外累计到最终数量。

覆盖矩阵脚本保留原有单元测试证据路径约束：初稿 UI 证据路径被拒绝后，改用核心／适配单测锚点，UI 另附真实运行证据。文档修改造成生成报告行号过期时重新生成，最终静态检查以保存结果为准。

构建仍含既有 existential、未改变量和资源／AppIntents 警告；只宣称构建成功，不宣称全库 Swift 6 或零警告。

## 可追溯性

[源输入散列](source-inputs.json)是限定代码／配置／文档快照，不是完整 checkout 备份；[相对 N3 的差异](source-delta-from-n3.json)避免把前序未提交工作归因于 N4。N3 历史证据保留原状，不重写其散列。原生 renderer、坐标、堆叠与取值算法文件未变。静态证据有[散列清单](artifact-hashes.json)，该文件自身不自哈希。

完整 xcresult 和临时派生数据在本机 `/tmp`，可能被系统清理；仓库保存摘要、压缩日志及四张原始截图，不冒充完整结果包备份。当前 Git 未提交／推送 N3 或 N4 增量；历史已推送 HEAD 为 `a5ace6a`。

## 复跑

在仓库根目录执行，使用新的 resultBundlePath，不覆盖已保存证据：

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralInteractionDerivedData \
  -resultBundlePath /tmp/hym-neutral-interaction-recheck.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralTooltipLegendOnFourPagesAndReset \
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
  -derivedDataPath /tmp/HYMChartNeutralInteractionPublicDerivedData \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralInteractionPublicDerivedData \
  -resultBundlePath /tmp/hym-neutral-interaction-public-recheck.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralInteractionPublicDerivedData/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_chart_evidence.py
git diff --check
```

功能边界、运行时优先级、后续质量切片见 [N4 任务进度](../../charts-neutral-interaction-task-progress-2026-10-09.md)与[模型指南](../../charts-neutral-model-guide.md)。
