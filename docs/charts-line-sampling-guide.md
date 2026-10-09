# 折线图 Min/Max 降采样

`CartesianChartTheme.lineSampling` 是可选的绘制优化，默认 nil（关闭）。目前支持非堆叠直线，以及使用直线连接的面积图；支持多系列、双值轴、负值配色与缺测。平滑曲线、阶梯线、普通/百分比/固定基准堆叠和预留 grouped 模式保持原始绘制，避免改变曲线切线、阶梯跳变时刻或堆叠面积边界。

## 接入：按分组宽度自动采样

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

## 接入：按目标点数采样

需要直接控制采样后保留数量时，设置 `targetPointCount`：

```swift
var sampling = LineChartSampling()
sampling.targetPointCount = 200          // 每条可见系列、当前视口目标 200 个绘制点
sampling.hidesDenseMarkers = false       // 想看保留下来的圆点时关闭隐藏策略

var theme = CartesianChartTheme(lineSampling: sampling)
theme.lineConnectionStyle = .straight
theme.showsPoints = true
chartView.update(theme: theme, viewportPolicy: .preserve)

// 改为每系列 50 点，保留当前视口
theme.lineSampling?.targetPointCount = 50
chartView.update(theme: theme, viewportPolicy: .preserve)

// 恢复按分组宽度/启动门槛自动采样；不是关闭采样
theme.lineSampling?.targetPointCount = nil
chartView.update(theme: theme)
// 完全关闭则用 theme.lineSampling = nil
```

### 两种模式互斥，不叠加

| 模式 | 如何启用 | 数量由谁决定 | 另两个参数 |
| --- | --- | --- | --- |
| 宽度模式（旧行为） | `targetPointCount = nil` | 屏幕宽度、可见跨度、`bucketWidth` 和有效段 | `minimumVisiblePoints` 只控制启动，不是保留数量 |
| 目标点数模式 | `targetPointCount = N` | 每系列目标 N（最小按 2 处理），及必须保护的点 | 忽略 `bucketWidth`、`minimumVisiblePoints`；Demo 禁用这两项但保留原值 |

**目标按每条系列独立计算，不是所有系列合计。** 3 条系列各 3000 点、目标 200，通常合计绘制 600 个点。这里的点数指选入折线路径的原始索引数量，不是数据总量，也不是可见圆点图层数。

**目标包含视口边缘衔接邻点。** 例如窗口内有 24 个有效点、左右各 1 个衔接点，原始待绘制数量为 26；目标 200 时保留这 26 点，不插值、不复制、不补足到 200。实时读数分别显示窗口内有效点数、实际绘制数，并注明原始候选中的邻点数量。

### 为什么少数情况下会超过目标

缺测不能被采样误连，显著峰谷也不能被静默删掉。因此先保护**每个连续有效段的首点、尾点、最低点和最高点**（重复索引去重），再分配剩余预算。设：

- `C`：裁剪后待绘制的原始有效点数量，含边缘邻点；
- `P`：所有有效段的必保点总数；
- `N`：请求的目标点数。

目标模式实际生效且视口有效时，绘制数量严格为 **`min(C, max(P, max(2, N)))`**。通常 `P ≤ N ≤ C`，因此就是 N；不足不补点，保护点超过目标时允许超额。

例如存在 100 个互不连接、至少两个点的有效段，单保留各段首尾就至少需要 200 点，不能无损压成 50 点。Demo 会明确显示 **“端点/极值保护至少 … 点，已超目标”**。不要为了凑数自动跨越缺测；只有业务上允许连接时，才主动改变缺测连接策略。

预算分配按各段剩余候选点数进行比例分配，处理舍入余量后保证总数；每段再划分双点组保留组内最低/最高，奇数余量保留单组绝对幅值最大的点。全段端点与极值始终保留。不会保留每一次小幅振荡、过零位置或所有局部尖峰。

目标模式对同一视口/数据/目标是确定性的，不受屏幕宽度影响；平移或缩放后按新的裁剪片段重新分配预算，**不承诺像宽度模式一样固定桶边界**，所选索引可能变化。

## 宽度模式的算法与两种模式的共同语义

- **宽度模式**：根据实际绘图区宽度、可见 X 跨度及 `bucketWidth` 算出分组跨度。单位为 UIKit point，不是物理像素。
- **宽度模式**：按原始索引 0 锚定等宽分组；同跨度平移不会移动内部桶边界。
- **宽度模式**：每个有效连续段在各组内保留首、尾、最小、最大值的原始索引，去重后按原顺序连接。峰值不会被平均抹平。
- 可见范围外各保留一个邻点，使穿过视口边缘的线段完整衔接。`connectNulls = false` 保留所有缺测断点；true 继续遵循原来的跨空值连接语义。
- 各系列独立采样，不改变 `series.data`、稳定 ID、原始索引、时间轴或由原始数据计算的值域。
- 点击只在触点容差覆盖的原始索引范围内查找；被省略的绘制点仍可命中。吸附、共享提示、准线和 tooltip 使用原始值/索引。重叠系列仍优先后绘制的系列，同系列优先距离最近的原始点。

降采样后的路径是近似表示，不保留组内所有细小振荡或每一次过零时刻。尖峰位置仍对应真实索引；缺测分段端点也必须保留，因此宽度模式没有固定点数上限，目标模式则遵守上述必保点约束。缺测极多时降采样收益会减小。

## 标记和标签

| 配置 | 默认 | 行为 |
| --- | --- | --- |
| `targetPointCount` | nil | 非 nil 时使用目标点数模式，最小 2；优先于宽度/启动门槛，每段端点与极值可使结果超额 |
| `bucketWidth` | 2 pt | 增大可减少分组数，每段每组最多保留四个原始点；最小 1，无效值使用 2 |
| `minimumVisiblePoints` | 500 | 仅宽度模式：单系列可见有效点达到门槛且每组覆盖多个采样时进入密集模式；不是目标点数，最小 2 |
| `hidesDenseMarkers` | true | 密集时隐藏多点连续段的 marker；若 showsPoints 开启，孤立有效点仍保留 marker，避免全图空白 |
| `hidesDenseDataLabels` | true | 密集时关闭数值标签；恢复后仍遵循原有标签开关和总量限制 |

目标模式仅在实际省略了原始待绘制点时应用密集隐藏策略；必保点超额但一个点也未省略时不会因模式开关而隐藏 marker。放大到较稀疏窗口后自动恢复全部可见原始点和标记。关闭隐藏策略时，密集模式只在选中的原始索引处绘制 marker/标签，而不会重新绘制全部原始点。`showsPoints = false` 仍然关闭所有 marker。

## Demo 调试

首页 → **折线图** → 搜索 **Min/Max**，在“高密度折线 Min/Max”分组中切换采样模式及相关参数。

- **3000 点目标点数采样场景**：三系列各 3000 个有效点，无缺测，目标 200，保留 marker。建议首先用这个场景观察 200 → 50 → 500 的确定数量变化。
- 搜索 **每系列目标绘制点数**，直接输入整数并点击“应用”或键盘完成；Demo 范围 2...3000，超界钳制，空/非法/溢出文本保留上次值。SDK 不限制最大值，超过当前数据量时自然保留全部。
- 预览下方逐系列显示 **可见原始点数 → 实际绘制点数**，随参数、视口、显隐变化更新；不是用目标值估算。
- **3000 点尖峰降采样场景**：原有宽度模式场景，三系列、尖峰/低谷、每 13 点缺测一次和图例，自动启用 Min/Max。在此场景启用目标 200 很可能超额，这是分段端点/极值保护，而不是目标值没传入。
- 关闭“按目标点数采样”回到宽度模式，分组宽度和启动门槛恢复可编辑；关闭顶层“启用 Min/Max”才是原始绘制。
- **查看尖峰附近原始点**：放大到尖峰周围 24 点；“总览”回到全量。
- 关闭/开启采样作视觉对照；切换成曲线或堆叠后，预览下方提示当前保持原始绘制。

## 验证与边界

测试覆盖峰值/端点/顺序、每组极值、固定桶边界、缺测、孤立点、邻点裁剪、缩放恢复、双轴、短数组、显隐更新、原始点命中和不支持组合的回退。包含 Demo 开关、预设、尖峰明细的界面操作和截图。

目标模式另有 `LineTargetPointSamplingTests`：800 组单段预算/数据形态组合、2,241 组缺测片段预算组合，覆盖奇偶数量、平台、单调、极值、非法目标、邻点裁剪、原始命中、多系列/双轴、显隐、实时目标更新、视口保留、稀疏标记恢复和诊断快照。Demo 审计增加模式优先级与旧值恢复；UI 测试输入 50、读取实际结果、放大/总览、检查灰置规则及超额提示。

### 2026-09-29 目标点数模式验证结果

环境：Xcode 26.3（17C529），iPhone 15 Pro 模拟器，iOS 17.2。完整 `xcodebuild test` 返回 `TEST SUCCEEDED`：

| 检查 | 结果 |
| --- | --- |
| 单元测试 | 224 项通过，0 失败；其中目标采样专项 12 项 |
| 界面测试 | 22 项通过，0 失败；包含 16 项图表 Demo 测试和 6 项基础/启动测试 |
| Demo 控件绑定 | 228 个可编辑项，2,450 次绑定读写检查；12 个预设的 144 组有序切换通过 |
| 精确数量 | 无缺测预设的三条系列均由 `3000 → 200` 更新为 `3000 → 50`；放大后不足目标则保留全部候选点 |
| 超额提示 | 原尖峰预设含频繁缺测，目标 200 时三条系列实际绘制 475、475、474 点；均显示端点/极值保护超额原因 |
| 模式切换 | 目标模式禁用宽度/启动门槛，关闭后恢复可编辑且原值不丢失 |

本机结果包：`/tmp/SwiftFunctionProject-target-sampling-final-20260929.xcresult`；日志：`/tmp/SwiftFunctionProject-target-sampling-final-20260929.log`。均为临时验证产物，不纳入仓库。UI 用例 `testLineTargetPointCountInputLiveCountsAndModePriority` 内附精确 50 点和超额提示截图，已核对可读性；不是全部配置的像素级金图测试，也未做真机性能基准。

### 性能与尚未覆盖的能力

以下是原宽度模式的历史性能对照，不是目标点数模式的性能基准：[3000 点折线布局对照](benchmarks/2026-09-24-line-minmax-layout-simulator.csv)：两个系列，原始绘制、采样但保留 marker、采样并隐藏密集 marker 三种模式。记录 Debug 模拟器单次 UIView 创建到 layout 的 CPU 时间、实际路径点数和系列图层数。不是实际触控 FPS、GPU 时间或真机内存基准。

当前仍按原始数组扫描有效段，手势会重算可见范围的采样选择。已有基础数据/时间标签缓存继续复用，尚无采样金字塔或跨层级索引缓存。已有绘制对象复用能力见 [复用指南](charts-rendering-reuse-guide.md)。平滑/阶梯/堆叠降采样、LTTB、不等间隔 XY 坐标和真机性能分析继续按后续路线图推进。
