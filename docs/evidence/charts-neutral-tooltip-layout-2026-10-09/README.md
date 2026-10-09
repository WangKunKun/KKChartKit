# N4 固定顶部提示布局质量证据（2026-10-09）

范围：可选原生绘图区边界、N4 fixedTop 自动启用、同页 Demo、Swift／纯 OC 公开 API 与旧默认兼容。不新增 schema 字段，不改变数据／坐标／G1 堆叠算法，也不建立专用提示预留区。任务契约见[进度](../../charts-neutral-tooltip-layout-task-progress-2026-10-09.md)。

环境：Xcode 26.3，arm64 iPhone 16 Pro 模拟器，iOS 18.6，UUID `781C9872-DAE0-4996-A623-36115772B60F`。主工程与 SDK／宿主使用 Swift 5 模式，Foundation-only 核心另外使用 Swift 6 complete strict concurrency。Release framework 编译产物包含模拟器 arm64/x86_64 接口，运行仅为 arm64 模拟器；不宣称真机／设备分发或全库 Swift 6 验收。

## 正式结果

**同一正式主工程批次 458/458，独立公共 Release 宿主 2/2；失败与跳过均为 0。** 不将开发期失败包与最终包拼接计数。

| 范围 | 结果 | 原始记录 |
| --- | --- | --- |
| 全部单元 + 六项相关 UI | **452 + 6 = 458/458** | [官方摘要](main-summary.json)、[压缩日志](main-test.log.gz) |
| 独立 Release Swift／纯 OC 宿主 | **2/2** | [官方摘要](public-import-summary.json)、[构建日志](public-build.log.gz)、[运行日志](public-test.log.gz) |
| Python 审计回归 | **28/28** | [日志](python-tests.log) |

本轮新增 9 项单元；沿用并增强一项 N4 四页 UI，不将同一用例重复计数。六项 UI 覆盖 N1/N2/N3/N4/G1 与不支持能力恢复，不代表全部 Demo UI。96 组布局矩阵及窄屏／横向尺寸、类目视口／显隐由单元直接操作，不等同于真实旋转和缩放手势压力测试。

- [Foundation-only 编译与六版样例逐字节复现](core-validation.json)：v1–v6 SHA-256 均与本轮前 N4 基线一致，默认构造保持 v1。
- [独立产物审计](framework-product-audit.json)：101 份 SDK Swift 源文件，无新增 SDK 文件；公开 Swift interface 与 OC 生成头均有 `fixedTopUsesPlotArea`。业务 JSON／Demo／fixture 不进入 framework；`.abi.json` 是编译器元数据。
- [旧声明库存](inventory-check.json)、[覆盖矩阵](coverage-check.json)：197 项声明、61 项能力、18 项 nativeReview；60 expressed／26 schema_gap／104 external／7 unsupported。没有把本轮布局质量算成 schema 增量。
- [Demo 审计摘要](demo-audit-summary.json)与[原始控件清单](demo-control-inventory.json)：327 项可编辑控件、3,379 次绑定写入、750 组渲染配置检查通过。
- [离线链接／截图检查](offline-evidence-check.json)只验证可读性、链接与哈希，不替代执行和人工目视。

## 四页原始截图

最终截图来自主工程正式结果的 `ChartDemoUITests/testNeutralTooltipLegendOnFourPagesAndReset()` 附件，保存原始像素，不裁剪／合成。四张已逐张目视复核：

| 图表 | 原图 | 观察 |
| --- | --- | --- |
| Line | [折线图](screenshots/88FCD21B-56A2-4200-8CC7-001B13599FEC.png) | 标题／图例完整位于提示上方；当前 11:00，电池取值 10:00 的 -10 W |
| Column | [柱状图](screenshots/2CB45D95-754A-44FB-9E5B-3C1493E41FA1.png) | 与顶部图例分离；正负堆叠仍在原坐标，当前 11:00 与来源 10:00 分开 |
| Bar | [条形图](screenshots/5EC569E6-1AEA-437B-949F-6D2EAF07FD81.png) | 水平布局中 top 仍为屏幕上方；不遮左侧类目标签，提示仍会遮住部分条体 |
| Combined | [混合图](screenshots/7051BD72-DE9C-4E24-8E67-E05CD03F43B3.png) | 三项图例完整；当前 11:00，来源 10:00 的光伏 -20 W／薄层贡献 8 W |

截图映射与 SHA-256 见[清单](screenshots/screenshots.json)，Xcode 原始附件索引见[manifest](screenshots/manifest.json)。这些竖屏截图只证明该路径的 title／top legend 分离、当前命中与前值来源；不能据此宣称所有图例、详情控件或手势均已目视验收。

**仍然存在的限制**：提示体会覆盖绘图区数据，长 columns 内容需要内部滚动，text 超高截断；并没有预留提示栏、拖动或关闭机制。深色静态文字对比度、Bar 长单位裁剪未在本批修复。未做大字体／VoiceOver 人工走查、真机性能或长期生命周期测试。

## 开发期记录（不累计到正式数量）

- 首次沙箱内启动 CoreSimulator 权限失败，未形成验收；改为获准的执行环境后运行成功。见[失败日志](development-sandbox-failure.log.gz)。
- 首轮专项 **28 单元 + 1 四页 UI = 29/29**，见[官方摘要](development-focused-summary.json)及[日志](development-focused.log.gz)。当时新增布局测试仅 7 项，随后新增视口／显隐与无绘图区能力两项，不以该结果冒充最终 9 项验收。
- 完整回归首次编译发现新增测试调用错误标签 `seriesID:`，实际 API 为 `for:`；修正测试调用后重新发起。没有修改生产 API 来迎合测试。该次未执行测试，见[编译失败日志](development-compile-failure.log.gz)。
- 首次完整回归执行了 452 单元 + 6 UI，其中 1 项面板库存期望未同步（实际 327、原期望 326）而失败，其余 457 项通过，包括全部 9 项新增布局测试和 6 UI。同步清单期望与 Demo 文档后重新完整回归；本包不算正式通过。见[摘要](development-inventory-summary.json)与[日志](development-inventory-failure.log.gz)。
- 构建保留既有 existential、未改变量、资源／AppIntents 等警告；构建通过不代表零警告或全库 Swift 6。

## 追溯与历史保护

[源输入散列](source-inputs.json)是限定代码／配置／文档的当前输入集合，不是完整仓库备份；[相对 N4 的差异](source-delta-from-n4.json)明确区分本轮与先前 N3/N4 未提交内容。CartesianRendererBase 只增加已有最终 plotFrame 的内部能力暴露；坐标计算、数据与堆叠算法未改。SDK 源列表与 Foundation-only 规格文件不变。

[历史证据检查](historical-evidence-check.json)确认 N3 的 27 项、N4 的 22 项静态产物仍符合各自哈希清单，未重写原图／摘要或用新结果抹去旧遮挡限制。新批次有[产物哈希](artifact-hashes.json)，清单自身不自哈希。

完整 xcresult、DerivedData 和初期截图在 `/tmp`，可被系统清理；此目录仅保留官方摘要、压缩日志及四张正式原图，不是完整 xcresult 备份。最后已推送的前序 HEAD 为 `a5ace6a`；本轮不提交／推送 N3、N4 或布局改动。

## 复跑

实际执行参数另见[命令记录](commands.json)。仓库根目录运行，换用新的结果路径，不覆盖已经保存的记录：

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralInteractionDerivedData \
  -resultBundlePath /tmp/hym-neutral-layout-recheck.xcresult \
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
  -resultBundlePath /tmp/hym-neutral-layout-public-recheck.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralInteractionPublicDerivedData/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_chart_evidence.py
git diff --check
```
