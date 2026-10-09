# 通用模型覆盖核对：2026-10-03 验证证据

本批承接首版通用模型后的覆盖审计，见[任务进度](../../charts-neutral-coverage-task-progress-2026-10-03.md)和[197 项矩阵](../../charts-neutral-model-coverage.md)。没有改动图表 SDK 的运行时实现。

## 结果与范围

| 检查 | 结果 | 保存材料 |
| --- | --- | --- |
| 旧声明清单 | 9 个头文件 / 197 个声明完整 | [inventory-check.log](inventory-check.log) |
| schema 覆盖矩阵 | 197 项 / 58 个主题 / 13 个边界主题，文档同步 | [audit-summary.json](audit-summary.json) |
| Python 回归 | 新审计 20 + 原证据 4 = 24/24 | [unittest-summary.json](unittest-summary.json)、[unittest.log](unittest.log) |
| 模型+HYM 适配器 XCTest | 20/20，无失败或跳过 | [摘要](xctest-summary.json)、[逐项测试树](xctest-tests.json)、[最终构建/测试日志](xctest-verified.log.gz) |
| 纯 Foundation 核心 | Swift 6 complete strict concurrency 编译与执行成功，生成 JSON 与示例逐字节相同 | [core-validation.json](core-validation.json)、[编译日志](core-validation.log) |
| 文档/既有截图完整性 | 本地链接、既有批次截图 manifest/SHA 完整 | [evidence-check.log](evidence-check.log) |

首次 XCTest 过滤器只选中 `ChartSpecificationTests`（11 项）；[首轮日志](xctest-model-only.log.gz)单独保留，不冒充20项，也不与最终20项相加。最终命令同时指定模型和适配器两个测试类。

CoreSimulator 和 xcresulttool 的首次沙箱访问分别因服务访问和 TestReport 缓存写权限失败；获准后重试完成。权限失败不是测试失败或功能修复，不影响最终摘要的 20 项通过结论。

这里的矩阵校验是**结构与证据完整性检查**，不是自动语义证明。锚点代码行为变化时仍需重新人工审计；矩阵中引用但未在最终命令选中的原生 G1–G5 测试，不宣称本次执行过。没有新截图、第二后端、全量 UI、独立 Release 宿主、真机或完整迁移验收。

## 复现

在仓库根目录运行；xcresult 路径须不存在，可替换为可用模拟器 UUID。

```sh
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p 'test_check_chart_*.py' -v
python3 scripts/check_chart_evidence.py

xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartNeutralCoverageDerivedData \
  -resultBundlePath /tmp/HYMChartNeutralCoverageRerun.xcresult \
  -only-testing:SwiftFunctionProjectTests/ChartSpecificationTests \
  -only-testing:SwiftFunctionProjectTests/HYMChartsSpecificationAdapterTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

xcrun swiftc -swift-version 6 -strict-concurrency=complete -parse-as-library \
  -module-cache-path /tmp/hym-neutral-coverage-module-cache \
  SwiftFunctionProject/Charts/Specification/*.swift \
  Examples/ChartSpecifications/GenerateExample.swift -o /tmp/hym-neutral-coverage-example
/tmp/hym-neutral-coverage-example /tmp/hym-neutral-coverage-energy.json
cmp Examples/ChartSpecifications/energy.json /tmp/hym-neutral-coverage-energy.json
```

修改审计分类后运行 `python3 scripts/check_chart_neutral_coverage.py --write` 生成 Markdown；此命令只刷新报告，不修改 JSON 分类、不自动归类新增旧声明。

[source-inputs.json](source-inputs.json) 记录审计直接输入、模型/适配器源码和选中的测试文件等散列，不包含整个 App 的构建依赖快照或所有未提交修改。原始 xcresult 位于 `/tmp`，持久摘要与日志不依赖该临时目录继续存在。
