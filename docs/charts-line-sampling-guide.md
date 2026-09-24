# 折线图 Min/Max 降采样

`CartesianChartTheme.lineSampling` 是可选的绘制优化，默认 nil（关闭）。首版支持非堆叠直线，以及使用直线连接的面积图；支持多系列、双值轴、负值配色与缺测。平滑曲线、阶梯线、普通/百分比/固定基准堆叠和预留 grouped 模式保持原始绘制，避免改变曲线切线、阶梯跳变时刻或堆叠面积边界。

## 接入

```swift
var sampling = LineChartSampling()
sampling.bucketWidth = 2
sampling.minimumVisiblePoints = 500
sampling.hidesDenseMarkers = true
sampling.hidesDenseDataLabels = true

var theme = CartesianChartTheme(lineSampling: sampling)
theme.lineConnectionStyle = .straight

// UIKit
chartView.update(theme: theme)
// SwiftUI
LineChart(model: model, theme: theme)
```

关闭时设置 `theme.lineSampling = nil`。配置同时适用于索引类目和已有等间隔时间轴，无需指定 reducer；它与 Column 的时间段求和/平均是不同能力。

## 算法与语义

- 根据实际绘图区宽度、可见 X 跨度及 `bucketWidth` 算出分组跨度。单位为 UIKit point，不是物理像素。
- 按原始索引 0 锚定等宽分组；同跨度平移不会移动内部桶边界。
- 每个有效连续段在各组内保留首、尾、最小、最大值的原始索引，去重后按原顺序连接。峰值不会被平均抹平。
- 可见范围外各保留一个邻点，使穿过视口边缘的线段完整衔接。`connectNulls = false` 保留所有缺测断点；true 继续遵循原来的跨空值连接语义。
- 各系列独立采样，不改变 `series.data`、稳定 ID、原始索引、时间轴或由原始数据计算的值域。
- 点击只在触点容差覆盖的原始索引范围内查找；被省略的绘制点仍可命中。吸附、共享提示、准线和 tooltip 使用原始值/索引。重叠系列仍优先后绘制的系列，同系列优先距离最近的原始点。

降采样后的路径是近似表示，不保留组内所有细小振荡或每一次过零时刻。尖峰位置仍对应真实索引；缺测分段端点也必须保留，因此点数上限不是“固定最多 N 点”。缺测极多时降采样收益会减小。

## 标记和标签

| 配置 | 默认 | 行为 |
| --- | --- | --- |
| `bucketWidth` | 2 pt | 增大可减少分组数，每段每组最多保留四个原始点；最小 1，无效值使用 2 |
| `minimumVisiblePoints` | 500 | 单系列可见有效点达到门槛且每组覆盖多个采样时进入密集模式；最小 2 |
| `hidesDenseMarkers` | true | 密集时隐藏多点连续段的 marker；若 showsPoints 开启，孤立有效点仍保留 marker，避免全图空白 |
| `hidesDenseDataLabels` | true | 密集时关闭数值标签；恢复后仍遵循原有标签开关和总量限制 |

放大到较稀疏窗口后自动恢复全部可见原始点和标记。关闭隐藏策略时，密集模式只在选中的原始索引处绘制 marker/标签，而不会重新绘制全部原始点。`showsPoints = false` 仍然关闭所有 marker。

## Demo 调试

首页 → **折线图** → 搜索 **Min/Max**，在“高密度折线 Min/Max”分组中调节四个参数与启用开关。

- **3000 点尖峰降采样场景**：三系列、尖峰/低谷、缺测和图例，自动启用 Min/Max。
- **查看尖峰附近原始点**：放大到尖峰周围 24 点；“总览”回到全量。
- 关闭/开启采样作视觉对照；切换成曲线或堆叠后，预览下方提示当前保持原始绘制。

## 验证与边界

测试覆盖峰值/端点/顺序、每组极值、固定桶边界、缺测、孤立点、邻点裁剪、缩放恢复、双轴、短数组、显隐更新、原始点命中和不支持组合的回退。包含 Demo 开关、预设、尖峰明细的界面操作和截图。

性能对照记录为 [3000 点折线布局对照](benchmarks/2026-09-24-line-minmax-layout-simulator.csv)：两个系列，原始绘制、采样但保留 marker、采样并隐藏密集 marker 三种模式。记录 Debug 模拟器单次 UIView 创建到 layout 的 CPU 时间、实际路径点数和系列图层数。不是实际触控 FPS、GPU 时间或真机内存基准。

当前仍按原始数组扫描有效段，手势会重算可见范围的采样选择。已有基础数据/时间标签缓存继续复用，尚无采样金字塔或跨层级索引缓存。平滑/阶梯/堆叠降采样、LTTB、不等间隔 XY 坐标、图层复用和真机性能分析继续按后续路线图推进。
