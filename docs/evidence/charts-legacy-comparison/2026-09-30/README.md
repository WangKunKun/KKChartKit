# 新旧对照证据（2026-09-30）

结论见[对照报告](../../../charts-legacy-demo-parity-results.md)。环境：Xcode 26.3（17C529）、iPhone 15 Pro / iOS 17.2。旧引擎为本地 Highcharts 11.4.3。

旧侧来自 `LegacyChartDemoUITests.testComparisonCapturesStackValuesGapOptionsAndJSTooltip`，原代码真实 WKWebView 运行；新侧来自 `LegacyReferenceComparisonTests`，固定输入的 UIView/CALayer 渲染与数值断言。新图只比较核心，使用 HYM 默认主题，不表示完整卡片、OC 适配或像素一致。所有文件的测试/设备归属在 [manifest.json](manifest.json)。

| 场景/含义 | 旧侧 | 新侧 |
| --- | --- | --- |
| 普通堆叠，映射前后的顺序 | [运行 JSON](comparison-signed-normal.json) | [默认顺序 JSON](hym-signed-default-order.json)、[图](hym-signed-default-order.png)；[映射后 JSON](hym-signed-normal-mapped.json)、[图](hym-signed-normal-mapped.png) |
| 正负百分比点值与轴范围 | [运行 JSON](comparison-signed-percent.json) | [映射后 JSON](hym-signed-percent-mapped.json)、[图](hym-signed-percent-mapped.png) |
| 缺测与颜色分区 | [最终 zones JSON](comparison-gaps-options.json) | [点值 JSON](hym-gaps-independent-zones.json)、[图](hym-gaps-independent-zones.png) |
| 逐点组名/表头/前值与过滤，程序选点 12 | [JS 提示 JSON](comparison-format-programmatic-js.json)、[截图](comparison-format-programmatic-js.png) | 当前能力与缺口见对照报告；未声称完成同输入新提示验收 |

旧普通/百分比快照保留引擎的 `percentage` 字段；普通模式下该字段也可能存在，**不等于图表以百分比绘制**。对照普通模式使用 raw/stackY，新 HYM 普通模式的 percentage 明确为 nil。缺测新侧只列有效 datum，缺测位由输入和测试断言保留，不能把 JSON 中省略的 datum 理解为压缩了输入数组。

已对导出的新旧 JSON 再做逐字段核对，[数值汇总](numeric-comparison-summary.json)记录普通模式 12 组 raw/stackY、百分比模式 12 组 raw/stackY/percentage。最大绝对误差分别为 0 与约 `3.62e-13`，均在 `1e-8` 容差内。该汇总由上述运行附件生成，不替代完整页面验收。

原旧 Demo 的 11 场景及全屏/空态等截图见[原索引](../../../../Examples/LegacyChartDemo/Evidence/2026-09-30/README.md)。
