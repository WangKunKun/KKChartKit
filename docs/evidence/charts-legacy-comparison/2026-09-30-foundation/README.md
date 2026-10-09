# 2026-09-30 基础接入批次证据

本目录记录 R0a 首批字段/输入与 R1 最小独立产物。上一轮 `2026-09-30-rerun` 证据和 fixture v1 保持不变。未修改 Charts 或参考图表运行源码；相对于上一轮归档，255 份这两部分输入散列相同。

## 运行与结果

环境：Xcode 26.3（17C529），iPhone 15 Pro / iOS 17.2 模拟器，UUID `23C39E52-9B21-4992-9121-5730E201718C`，运行架构 arm64。独立产品 deployment target iOS 15、Swift 5 语言模式，非真实业务工程版本承诺。截图为当前模拟器深色外观，未单独验证 trait 切换。

| 执行 | 结果 | 原始结果包 | 保存摘要 |
| --- | --- | --- | --- |
| 独立 Swift/OC，Debug，修正 @rpath 后 | 2 通过 | `/tmp/ChartsIntegration-debug-rpath-20260930.xcresult` | [debug-summary.json](debug-summary.json) |
| 独立 Swift/OC，Release，修正 @rpath 后 | 2 通过 | `/tmp/ChartsIntegration-release-rpath-20260930.xcresult` | [release-summary.json](release-summary.json) |
| HYM v1/v2 同输入对照 | 6 通过 | `/tmp/ChartsBatch-native-fixed-20260930.xcresult` | [native-summary.json](native-summary.json) |
| 旧 Demo v2 缺测/提示与原 v1 堆叠 | 1 通过 | `/tmp/ChartsBatch-legacy-v2-20260930.xcresult` | [legacy-summary.json](legacy-summary.json) |
| HYMCharts iPhone arm64 Release | BUILD SUCCEEDED | `/tmp/ChartsIntegration-device-rpath-20260930.log` | [device-product-audit.json](device-product-audit.json) |

Debug/Release 的宿主用例是同两项在不同构建配置运行；原生 6 项包括原有 4 项，不与上一轮总数累加成独立覆盖数。本批次没有重新跑全部 258 单元和 19 项 ChartDemo UI，因为未改 SDK 运行源码或 Demo 配置面板。

两个公开宿主验证配置、更新到 500、稳定 ID 显隐保持/回调、真实点击返回新数值，以及各 30 次同步创建/布局/释放。OC 宿主另验非法重复 ID 返回 NSError 并保留有效数据。Swift 宿主也通过普通 import 实例化 SwiftUI LineChart；其他五个包装随产品编译并在导出 interface 中检查存在，未逐个做 UI 运行。

原生补测用 area-single / area-multi / area-missing，在 normal / percent 下依次显示、隐藏 aux、恢复 aux；全 48 个类目验 raw/base/draw 和自动范围。它验证目标正负独立策略，不证明旧面积百分比同值。提示样本测试覆盖 0/10/11/12/47 的整行隐藏、仅名称、逐点名称/过滤、前值及命中源索引；独立表头是测试内容构造处显式传入，动态组名和特殊精度仍未正式接入。

首次提示测试未配置 `header="{key}"`，6 项中 1 项出现 5 条断言失败；补齐测试配置后全过，未改 SDK。首次失败触发的 simctl 自动诊断长时间未结束，已停止该次 xcodebuild/诊断进程；保留 [native-initial-failure.log.gz](native-initial-failure.log.gz)。该不完整结果包不作为最终通过证据。初次产物审计发现固定 install name，已修正为 `@rpath` 并重跑两个配置和设备构建。

## 留存材料

- `debug/`、`release/`：各 2 张实际接入截图；`native/`：10 PNG + 10 JSON；`legacy/`：1 PNG + 4 JSON，共 29 附件。对应 `*-attachments-manifest.json` 保存用例、设备、原始文件名和 SHA-256。
- [legacy-fixture-equivalence.json](legacy-fixture-equivalence.json)：4 份旧 JSON 与上一轮逐对象完全一致，包括 gaps/format；不将此结论扩大为全页面像素一致。
- [simulator-product-audit.json](simulator-product-audit.json)、[device-product-audit.json](device-product-audit.json)：实际产物文件与动态链接依赖；无 AA/JS/WebKit/App 依赖或 Demo/fixture 资源，存在生成 OC 头、六个 SwiftUI 包装和 @rpath install name。模拟器 Release 包含 arm64/x86_64，实际运行仅 arm64。
- [source-snapshot.json](source-snapshot.json) + [source-snapshot.tar.gz](source-snapshot.tar.gz)：326 份源码/工程/输入归档及逐文件散列；沿用上次 312 份输入并加入本批次文件。仓库有未提交改动，不能只靠 HEAD 重放。归档包含文档/检查器等构建后加入的非运行文件，编译输入未再改动。
- `debug.log.gz`、`release.log.gz`、`device.log.gz`、`native.log.gz`、`legacy.log.gz`：最终运行构建日志。最初完整独立编译的日志留存在 `initial-framework-compile.log.gz`，现有协议 existential 写法有未来 Swift 语言模式警告，增量重链日志不会重复显示全部编译警告。
- [verify_evidence.py](verify_evidence.py)：检查摘要、29 附件散列、4 份旧 JSON 等价和源码归档；只读保存材料，不代替实际重跑。

```sh
python3 docs/evidence/charts-legacy-comparison/2026-09-30-foundation/verify_evidence.py
python3 scripts/check_chart_migration_inventory.py
```

复现独立产品见[接入工程说明](../../../../Examples/ChartsIntegration/README.md)。原生用主工程 `SwiftFunctionProject` scheme，筛选 `SwiftFunctionProjectTests/LegacyReferenceComparisonTests`；旧侧用 `LegacyChartDemo` scheme，筛选 `LegacyChartDemoUITests/LegacyChartDemoUITests/testComparisonCapturesStackValuesGapOptionsAndJSTooltip`。都使用上面的 UUID，`-parallel-testing-enabled NO`，结果包用未存在的新路径。

没有真机运行、签名发布、长期任务释放/内存峰值或性能比较证据。业务工程、真实调用和正式分发条件仍待 R0b；R2 正式旧模型适配尚未完成。
