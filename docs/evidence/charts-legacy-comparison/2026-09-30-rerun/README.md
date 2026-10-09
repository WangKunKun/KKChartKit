# 重跑与补测证据（2026-09-30）

本目录保留第二轮运行结果，不覆盖 [首轮证据](../2026-09-30/README.md)。结论和任务归属见[对照报告](../../../charts-legacy-demo-parity-results.md)与[实施计划](../../../charts-legacy-replacement-plan.md)。

## 运行与输入

- [258 项完整单元测试摘要](native-baseline-summary.json)：通过，执行在审计测试扩展前；SDK 运行源码随后未改动。
- [旧 Demo 11 项 UI 摘要](legacy-summary.json)：通过；原 7 项 + 新增 4 项，包含全部 11 个默认场景。
- [新侧扩展摘要](native-expanded-summary.json)：4 项更新后的对照 + 19 项 ChartDemo UI 全部通过；4 项中含修改后的原 2 项，不能与前面的 258 项直接相加为独立测试数。
- [环境和 Release 构建](environment-and-builds.json)：Xcode 26.3、iPhone 15 Pro / iOS 17.2、arm64、设备 UUID 固定；Locale 读取为 zh_CN。模拟器时区未在 App 内读取，输入时间文字固定，不把宿主时区当作 App 的运行断言。
- [共享 JSON](../../../../Examples/ChartComparisonFixtures/chart-migration-audit-v1.json)：schemaVersion=1，4 个 48 点样本，固定 domainID/series ID；column、面积单组/多组、spline+area。缺测和其他历史输入仍未全部迁入此文件。
- [源码清单与 SHA-256](source-snapshot.json)、[源码归档](source-snapshot.tar.gz)：保存扩展审计使用的工程、源码、资源和测试，共 312 个文件。工作区有未提交改动，不能只凭 Git HEAD 复现本轮。归档不包含临时 xcresult、文档或 Xcode DerivedData。

## 旧侧新证据

| 检查 | 附件与范围 |
| --- | --- |
| 共用柱状输入 | [JSON](audit-signed-column.json)、[截图](audit-signed-column.png) |
| 单组面积与 reverse | [普通 JSON](audit-area-single.json)、[截图](audit-area-single.png)、[reverse JSON](audit-area-single-reversed.json)、[截图](audit-area-single-reversed.png)；确认 2 条业务系列展开为 5 条 |
| 多组面积 | [JSON](audit-area-multi.json)、[截图](audit-area-multi.png)；同一个 stackGroup 跨两个业务组，轴约 ±1980 裁掉 2920/−2480 的累计位置 |
| 混合具体类型 | [JSON](audit-mixed-types.json)、[截图](audit-mixed-types.png)；spline/area 的 stackKey 不同，代表索引各自 draw=raw |
| 拆分空值与复制字段 | [JSON](audit-input-boundaries.json)；原正/负拆分函数均抛 NSNull doubleValue 异常；原函数调用在 Demo 审计入口捕获，未改原实现 |
| 两版原生提示持触 | [v1](audit-held-v1-原生.json)、[v2](audit-held-v2-原生.json)；各 4 份可见文字/frame 状态，v2 漏中间组且右组标题重复左组 |
| 同模型空态恢复 | [JSON](audit-empty-toggle-same-model.json)、[截图](audit-empty-toggle-same-model.png)；showNoData 变回 false，showLegend 仍 false |
| 默认窗口全屏往返 | [之前](audit-dense-before-fullscreen.json)、[之后](audit-dense-after-fullscreen.json)；288 点、0…96，未改变用户缩放窗口 |

[旧侧附件清单](legacy-attachments-manifest.json)记录 45 个文件（30 PNG + 15 JSON）的测试、设备、时间戳、原导出名和内容散列，也包含此次重跑的默认场景、JS 提示、图例、空态与全屏附件。原生提示采样只读视图树，文字存在不自动证明没有遮挡/裁切；最终隐藏状态也不证明准确的抬手时延。

## 新侧数值和交互证据

| 检查 | 附件与结论 |
| --- | --- |
| 柱普通/百分比 | [普通](hym-signed-normal-mapped.json)、[百分比](hym-signed-percent-mapped.json)；映射顺序后各 12 个代表点 draw 最大误差 0 / 约 3.62e−13 |
| 面积业务系列 | [单组](hym-area-single-business-series.json)、[图](hym-area-single-business-series.png)、[多组](hym-area-multi-business-series.json)、[图](hym-area-multi-business-series.png)；原值对齐，跨零累计位置存在已记录差异，新范围 ±3000 包含实际已测点 |
| 混合类型分区 | [直接复用 stackID](hym-mixed-types-unmapped.json)、[加入具体类型](hym-mixed-types-partitioned.json)、[图](hym-mixed-types-partitioned.png)；draw 最大差异从 1800 变为 0，仍需正式适配器承接 |
| 缺测/分区 | [JSON](hym-gaps-independent-zones.json)、[图](hym-gaps-independent-zones.png)；原有断线、缺测位置和分区回归重跑通过，此场景尚未使用共享 JSON |
| UI 回归 | [附件清单](native-attachments-manifest.json)包含 63 张真实 App UI 截图；19 项覆盖现有图表页、OC 回调、窗口/密集、缺测/分区、面积接缝、前值置顶、富提示滚动与分组显隐 |

新侧共导出 79 个附件：8 张 UIView/CALayer 对照渲染图、63 张 UI 截图、8 份运行 JSON。新图仍为 HYM 默认主题，未进行完整旧卡片像素对齐；UI 回归使用原生 Demo 预设，并非 HMAA 适配器集成测试。

[数值复算摘要](numeric-audit-summary.json)保存逐点差异和输入文件散列，可执行：

```sh
python3 docs/evidence/charts-legacy-comparison/2026-09-30-rerun/compare_snapshots.py
```

[脚本](compare_snapshots.py)仅读取已导出 JSON，对 column 和混合类型映射作数值断言；面积按本 fixture 的默认顺序选取对应正/负副本、排除透明辅助系列后核对业务 raw。它明确保留面积 draw 差异，不把旧异常行为当作必须复制的期望值，也不代替正式转换器。

## 复现

```sh
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme LegacyChartDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO

xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=23C39E52-9B21-4992-9121-5730E201718C,arch=arm64' \
  -parallel-testing-enabled NO \
  -only-testing:SwiftFunctionProjectTests/LegacyReferenceComparisonTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests \
  test CODE_SIGNING_ALLOWED=NO
```

本机同名模拟器有两个，因此用 UUID。其他机器需替换设备 UUID。实际本次扩展新侧先 `build-for-testing` 成功，再 `test-without-building`；上面的命令合并两步便于复现。原始结果包路径和最终新侧统计记录在对照报告中。
