# G2–G5：便携验证材料

日期：2026-10-02。实现、限制、失败轮次和重跑命令见[完整记录](../../charts-presentation-g2-g5-2026-10-02.md)。本目录只保存真正执行并审阅过的验证材料，不把模拟器结果扩展为真机或业务迁移结论。

## 测试结果

| 运行 | 结果 | 便携摘要 / 原始日志 |
| --- | --- | --- |
| **最终完整回归** | **同一轮 342 项单元 + 28 项图表 UI，全部 0 失败** | [摘要](HYMCharts-complete-regression-v2-20261002-summary.txt) / [log.gz](HYMCharts-complete-regression-v2-20261002.log.gz) |
| 完整单元集及 G2–G5 UI | 342 项单元 + 4 项 UI，均 0 失败 | [摘要](HYMCharts-G2-G5-acceptance-20261002-summary.txt) / [log.gz](HYMCharts-G2-G5-acceptance-20261002.log.gz) |
| 全量历史 UI 首轮（保留失败） | 342 项单元通过；28 项 UI 中 27 通过、1 失败，旧接缝提示文案断言失配 | [摘要](HYMCharts-complete-regression-20261002-summary.txt) / [log.gz](HYMCharts-complete-regression-20261002.log.gz) |
| 接缝提示断言修正后复验 | 1 项两页 UI，0 失败；不将其与上一行拼成整轮通过 | [摘要](HYMCharts-seams-ui-correction-20261002-summary.txt) / [log.gz](HYMCharts-seams-ui-correction-20261002.log.gz) |
| G3 稳定横竖屏补验 | 1 项四页 UI，0 失败 | [摘要](HYMCharts-G3-orientation-v2-20261002-summary.txt) / [log.gz](HYMCharts-G3-orientation-v2-20261002.log.gz) |
| Release 普通 Swift / OC import 宿主 | 2 项 UI，0 失败 | [摘要](HYMChartsIntegration-G2-G5-release-20261002-summary.txt) / [log.gz](HYMChartsIntegration-G2-G5-release-20261002.log.gz) |
| 未签名 iOS arm64 Release framework | BUILD SUCCEEDED | [摘要](HYMChartsIntegration-G2-G5-device-20261002-summary.txt) / [log.gz](HYMChartsIntegration-G2-G5-device-20261002.log.gz) |

最终 370 项完整结果包位于 `/tmp/HYMCharts-complete-regression-v2-20261002.xcresult`。先前定向与产物结果包位于 `/tmp/HYMCharts-G2-G5-acceptance-20261002.xcresult`、`/tmp/HYMCharts-G3-orientation-v2-20261002.xcresult` 与 `/tmp/HYMChartsIntegration-G2-G5-release-20261002.xcresult`；临时文件清除后要重跑，不能用本目录伪造 xcresult。独立公共产物审计：[模拟器](release-simulator-product.json)、[iOS arm64](release-device-product.json)，记录二进制散列、公开接口、链接依赖和文件清单。

Xcode 结果包直接导出的[机器可读汇总](HYMCharts-complete-regression-v2-20261002-result-summary.json)确认 `totalTestCount=370`、`passedTests=370`、`failedTests=0`、`skippedTests=0`；结束时间 `2026-10-02T21:01:04+08:00`（Asia/Shanghai）。

## 工作区输入识别

[source-inputs.json](source-inputs.json)记录本轮 154 个图表 SDK / Demo、测试、OC 示例、共享 Xcode 配置及校验脚本的 SHA-256。测试基于包含未提交改动的工作区，不能只用 `gitHead` 复现。清单不是源码压缩包，不包括其他 App 模块、媒体、用户级 Xcode 设置及工具链，也不能恢复未提交文件；后续代码修改后需重跑对应测试，不应通过更新散列冒充旧结果。

## 原始截图

[38 张图片清单](screenshots.json)含 SHA-256、测试归属、源结果包和 Xcode 原始附件字段。G3 四页的 12 张 UI 图来自稳定布局补验，其余 26 张来自完整单元 + G2–G5 成功轮。原始 PNG 直接复制，没有改像素、补画或裁剪；横屏 PNG 保留 XCTest 的方向元数据。

| 批次 | 页面 | 文件前缀 | 数量 |
| --- | --- | --- | --- |
| G2 | 柱状 / 条形 / 混合 | `g2-raw` / `g2-draw` / `g2-restored` | 9 |
| G3 | 折线 / 柱状 / 条形 / 混合 | `g3-styled` / `g3-hidden-category` / `g3-landscape` | 12 |
| G3 单测 | 复用与主题继承恢复 | `g3-axis-inheritance` | 1 |
| G4 | 四页 | `g4-annotations` / `g4-without-avoidance` | 8 |
| G5 | 四页 | `g5-selected` / `g5-disabled` | 8 |

逐张复核包括阈值前后不同颜色、不同轴的字体/颜色/标签显隐、四页完整横屏、标注避让开关及共享选中开关。允许的自动抽稀、截断与狭窄布局省略遵循指南，不声称所有文本永远都能显示。

## 离线校验

在仓库根目录：

```sh
python3 scripts/check_chart_evidence.py
python3 -m unittest discover -s scripts -p 'test_check_chart_evidence.py'
python3 scripts/check_chart_migration_inventory.py
```

链接/散列校验不需要 Xcode 或联网，也不要求 `/tmp` 结果包存在；只验证保存材料一致，不代替执行测试和视觉判断。另补验的 G1 百分比面积材料见[独立记录](../charts-legacy-comparison/2026-10-02-g1-percent/README.md)。
