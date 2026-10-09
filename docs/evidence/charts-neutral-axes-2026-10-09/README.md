# N2 通用轴展示 schema v4：验证证据

日期：2026-10-09，Asia/Shanghai。限定范围：Foundation-only 轴展示契约、版本拦截、HYM G3 映射、Swift/OC 共享 JSON 与现有四页 Demo；不改变原生坐标/渲染算法，不放开 G6。

## 最终运行结果与口径

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 主工程完整单元 + 相关 UI | **419 + 4 = 423/423**，0 失败、0 跳过；新增 13 项轴专项包含在 419 中 | [官方摘要](main-summary.json)、[官方测试树](main-tests.json)、[原始日志 gzip](main.log.gz) |
| 独立 Release Swift / 纯 OC 宿主 | **2/2**，四版共享 JSON 均经过公开导入；先 build-for-testing 再 test-without-building | [官方摘要](public-import-summary.json)、[测试树](public-import-tests.json)、[构建日志](public-import-build.log.gz)、[运行日志](public-import.log.gz) |
| Release framework 产物检查 | 通过，98 份 SDK Swift 源码，不带 App Demo/示例 JSON | [审计 JSON](framework-audit.json) |
| Foundation-only 独立构建与样本 | Swift 6 完整严格并发通过；v1–v4 全部逐字节复现，旧三版不变 | [命令/退出码/JSON 哈希](core-validation.json)、[日志](core-validation.log) |
| Python 审计回归 | **26/26** | [日志](python-tests.log) |
| 旧声明与覆盖矩阵 | 197 声明 / 59 能力 / 15 原生复核主题；47 已表达、39 待补、104 外层、7 不承接 | [旧声明检查](inventory-check.log)、[矩阵摘要](coverage-summary.json) |
| 保存文件检查 | 文档链接、5 批 56 张截图来源/哈希、diff 空白检查通过 | [证据检查](evidence-check.log)、[diff 检查](diff-check.log) |

Xcode 26.3 / iPhone 16 Pro / iOS 18.6 / arm64 模拟器。Release framework 同时含 arm64 与 x86_64 模拟器切片，运行验收**仅 arm64**。四项 UI 是 N2 四页轴展示、N1 四页颜色分区、G1 边界、显式不支持能力与恢复；不是全量 UI。未验真机、业务工程、长时性能/内存或第二生产后端，既有 Swift existential/资源警告未清零。

## 四张原始截图与实际目视结论

均从最终成功的 `ChartDemoUITests/testNeutralAxisPresentationPerAxisAndResetOnFourPages()` 导出，未裁切、改色、修图或重绘。原生导出信息见 [manifest](screenshots/manifest.json)，可离线校验的来源与 SHA-256 见 [screenshots.json](screenshots/screenshots.json)。

| 页面 | 原始 PNG | 复核内容 |
| --- | --- | --- |
| Line | [折线图](screenshots/7083579F-305E-45F3-9F6A-3CF74A798BA8.png) | 左主轴 W / bold，右次轴 °C / light；缺测间隙保留；类目候选 8:00/10:00/12:00 |
| Column | [柱状图](screenshots/5C71C068-0F2F-43E1-BFF7-305E29C8AF4D.png) | 双值轴独立刻度和单位，原始正负值保留，域轴标签间隔生效 |
| Bar | [条形图](screenshots/FFBFE8EF-A781-463B-A921-C6787639ED23.png) | 值轴在底部、类目在左；W 与 bold 生效；右端 `150 W` 沿原生边带策略截成 `15…` |
| Combined | [混合图](screenshots/C931EE28-A7A4-403B-B401-31AAAD5F5C0E.png) | 三个稳定系列；主轴 W、次轴有效域内仅 0 °C，不强行为展示预设刻度扩大域 |

**不是视觉无缺陷**：静态标题和部分刻度在深色背景下仍低对比度；Bar 边缘长文字仍会截断。已复核现有 `AxisRenderer.fit` 会保留锚点并在边带内尾部截断，本批不修改原生留白/锚点政策，也没有删除刻度/单位来掩盖。主次轴字重外观可区分，九种字重的精确映射、nil/空列表/越界和重置由自动断言覆盖，不由四张静态图片单独证明。

## 开发期失败与最终结果隔离

- [首次专项日志](development-focused.log.gz)：13 项中的一个测试错误预期相邻视口边缘标签不存在；调整测试窗口而非更改原生可见区。后续 [focused2](development-focused2.log.gz) 中 13/13 通过，但 UI 定位失败。
- [UI3](development-ui3.log.gz)、[UI5](development-ui5.log.gz)：短 Form 中部分露出的开关/按钮被视为 hittable，整屏手势又可能落在固定预览；改为 Form 内拖动、完整露出后点击、校验开关值确实改变。
- [UI4 日志](development-ui4-runner-crash.log.gz)与[精简崩溃摘要](development-runner-crash.json)：XCTest runner 在连接前 CFBundle/NSUserDefaults 启动崩溃，不记为产品测试通过，未改生产代码绕过。
- [首轮完整摘要](development-main-summary.json)、[日志](development-main.log.gz)：**422 通过 / 1 失败**，失败的是旧 N1 分区 UI 的整屏滚动定位；共用 N2 已验证的 Form 定位函数后重跑全部测试得到上表 **423/423**。没有删掉旧测试或放宽分区语义断言。

这些开发期尝试不累计到最终测试数量；最终只引用 `main-summary.json` 与 `public-import-summary.json`。

## 可追溯性与边界

[限定范围源文件散列](source-inputs.json)记录最终时点的代码、配置、文档；[相对 N1 的限定范围比较](source-delta-from-n1.json)以保存的 N1 清单为基准，未观察到原生 Cartesian renderer/坐标实现变更。清单包括先前工作，**不是全量 checkout 备份，也不把全部未提交改动归因于 N2**。[证据散列清单](artifact-hashes.json)覆盖本目录除该清单自身以外的静态文件。`/tmp` 中的 xcresult 可能被系统清理；这里的摘要、日志、PNG 和校验清单可独立阅读，但不能代替完整结果包重新导出其他附件。

## 复跑命令

在仓库根运行。保留已有结果包，复跑时换新的 resultBundlePath，不覆盖本批证据。

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAxesDerivedData \
  -resultBundlePath /tmp/hym-neutral-axes-final2-20261009.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralAxisPresentationPerAxisAndResetOnFourPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralValueColorZonesPerSeriesSourceAndResetOnFourPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralG1BoundarySwitchAndResetInExistingPages \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

python3 Examples/ChartsIntegration/generate_project.py
xcodebuild build-for-testing -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAxesPublicDerivedData \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralAxesPublicDerivedData \
  -resultBundlePath /tmp/hym-neutral-axes-public-final-20261009.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/HYMChartNeutralAxesPublicDerivedData/Build/Products/Release-iphonesimulator/HYMCharts.framework
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/check_chart_evidence.py
git diff --check
```

Foundation-only 编译命令、每个退出码和四个 JSON 哈希见 [core-validation.json](core-validation.json)；不需要 UIKit/Simulator。重新生成覆盖报告使用 `python3 scripts/check_chart_neutral_coverage.py --write`。


详细契约、未完成项与下一步 N3 值轴标线/色带入口见[任务进度](../../charts-neutral-axes-task-progress-2026-10-09.md)。不提交、推送或清理既有脏工作区，不重复执行历史关机请求。
