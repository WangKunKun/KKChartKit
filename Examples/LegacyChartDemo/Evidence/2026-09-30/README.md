# 旧图表运行截图（2026-09-30）

来自最终通过的 `LegacyChartDemo` XCTest 运行：Xcode 26.3（17C529），iPhone 15 Pro / iOS 17.2，6 项用例全部通过。固定输入见 [LCScenario.m](../../Sources/LCScenario.m)；原代码直接编译，截图中显示的是旧图表实际输出。

默认场景截图用于检查绘制与布局。提示截图在触摸释放后拍摄，原生提示可能已经按旧手势生命周期隐藏；不能据此声称长按过程中的提示内容已经逐行验收。全屏截图展示旧组件旋转后的布局，不代表完成新 SDK 的状态恢复。

结果包：`/tmp/LegacyChartDemo-final-20260930.xcresult`。截图文件与测试归属见 [manifest.json](manifest.json)。

| 截图 | 对应场景/操作 |
| --- | --- |
| [all-zero-data.png](all-zero-data.png) | all-zero-data |
| [baseline-column.png](baseline-column.png) | baseline-column |
| [baseline-dense.png](baseline-dense.png) | baseline-dense |
| [baseline-empty.png](baseline-empty.png) | baseline-empty |
| [baseline-format.png](baseline-format.png) | baseline-format |
| [baseline-gaps.png](baseline-gaps.png) | baseline-gaps |
| [baseline-legendGroups.png](baseline-legendGroups.png) | baseline-legendGroups |
| [baseline-line.png](baseline-line.png) | baseline-line |
| [baseline-mixed.png](baseline-mixed.png) | baseline-mixed |
| [baseline-multi-lower-charts.png](baseline-multi-lower-charts.png) | baseline-multi-lower-charts |
| [baseline-multi.png](baseline-multi.png) | baseline-multi |
| [baseline-power.png](baseline-power.png) | baseline-power |
| [baseline-signed.png](baseline-signed.png) | baseline-signed |
| [forced-empty-state.png](forced-empty-state.png) | forced-empty-state |
| [legacy-data-only-retains-packed-data.png](legacy-data-only-retains-packed-data.png) | legacy-data-only-retains-packed-data |
| [legacy-fullscreen.png](legacy-fullscreen.png) | legacy-fullscreen |
| [legend-hidden.png](legend-hidden.png) | legend-hidden |
| [signed-normal.png](signed-normal.png) | signed-normal |
| [signed-percent-theme-change.png](signed-percent-theme-change.png) | signed-percent-theme-change |
| [tooltip-v1-js.png](tooltip-v1-js.png) | tooltip-v1 JS |
| [tooltip-v1-native.png](tooltip-v1-native.png) | tooltip-v1 原生 |
| [tooltip-v2-js.png](tooltip-v2-js.png) | tooltip-v2 JS |
| [tooltip-v2-native.png](tooltip-v2-native.png) | tooltip-v2 原生 |
