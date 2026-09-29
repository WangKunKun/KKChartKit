# 折线缺测连接策略（autoGap）

`CartesianSeriesElement.gapPolicy` 控制折线和面积路径是否跨过缺测区间，适用于独立 Line 和 Combined 的线族系列。直线、平滑线、三种阶梯以及面积使用同一分段结果；柱状和条形图不使用此配置。

本页描述旧模块迁移第 3 阶段的缺测连接子项。同日后续已接入 X/Y 颜色分区与平滑曲线负值换色，见 [颜色分区指南](charts-color-zones-guide.md)。

## 兼容性与边界

| 配置 | 行为 |
| --- | --- |
| `gapPolicy = nil`（默认） | 保留原 `connectNulls`：false 全断开，true 全连接 |
| `.breakAll` | 任一连续缺测段都断开，覆盖 `connectNulls` |
| `.connectAll` | 连接所有有效点，覆盖 `connectNulls` |
| `.autoGap(maximumMissingPoints: n)` | 连续缺测数 **≤ n** 时连接；负数上限按 0 处理 |
| `.autoGapDuration(maximumMissingDuration: seconds)` | 有效等间隔时间轴下，缺测数 × `timeAxis.interval` **≤ seconds** 时连接 |

- 上限含等号：旧模块实际在 `len >= 12` 时断开，对应本 API 的 `maximumMissingPoints: 11`。11 个空点连接，12 和 13 个断开。
- NaN、正负 Infinity 都是缺测；0 是有效数据。
- 时长只计算缺失采样槽，不包含两端有效点。例如 5 分钟一个采样，11 个空点对应 55 分钟缺测，两端有效点相隔 60 分钟。
- 时长模式没有有效 `timeAxis`，或时长上限为负数/NaN/Infinity，或计算溢出时，缺测处断开。相邻有效点仍正常连接。
- 前后缺测不会生成端点；全缺测系列不生成线或面积。
- 配置只改变路径分段，**不插入数值、不写回 data、不修改堆叠/百分比分母或值域、不创建缺测点命中**。跨缺测线段只是视觉连接，不表示中间存在业务采样。
- 修改配置后通过现有 `update(model:)` 应用；设置回 nil 恢复 `connectNulls`，无需重建图表。

## Swift

```swift
var samples = [20.0]
samples.append(contentsOf: Array(repeating: .nan, count: 11))
samples.append(50)
samples.append(contentsOf: Array(repeating: .nan, count: 12))
samples.append(30)
samples.append(contentsOf: Array(repeating: .nan, count: 13))
samples.append(70)

let power = CartesianSeriesElement(
    name: "功率", data: samples, id: "power", unit: "W",
    gapPolicy: .autoGap(maximumMissingPoints: 11)
)
var model = CartesianChartModel(series: [power])
// 原始索引分段：[0, 12]、[25]、[39]；缺失索引仍保留在 data 中。

model.timeAxis = CartesianTimeAxis(start: Date(), interval: 300)
model.series[0].gapPolicy = .autoGapDuration(maximumMissingDuration: 55 * 60)
// 与 11 空点上限相同。修改采样间隔后，下次更新会按新时长重新分段。
```

每个系列可独立选择策略，业务组与数学堆叠组不影响策略选择。普通/百分比/固定基准堆叠的上边界仍按本系列的缺测位置分段；堆叠下边界及样式继续遵循既有堆叠面积规则。

## 降采样、视口与对象复用

先在完整原始索引上分段，再对每段执行 Min/Max 降采样，避免把被省略的绘制点误判为缺测。视口裁剪只保留真实邻点：窗口完全落在允许连接的缺测区间中时可保留两端原始点；落在必须断开的区间中时不会生成跨窗口连接。

降采样的既有限制不变：非堆叠直线/面积可以启用，曲线、阶梯和堆叠保持原始绘制。缺测策略与 `reusesRenderingObjects` 正交；更新策略、显隐切换、清空后恢复均重新生成正确的路径和命中缓存。

## Objective-C

`HYMCartesianSeries.gapPolicy` 是可选 NSObject 配置，nil 同样兼容 `connectNulls`。配置在 `configure/update` 时复制成 Swift 值，修改原 OC 对象不会隐式改变正在显示的图表。

```objc
HYMCartesianSeries *series = [HYMCartesianSeries new];
series.identifier = @"power";
series.name = @"功率";
series.data = @[@20, [NSNull null], [NSNull null], @50];
series.gapPolicy = [HYMCartesianGapPolicy new];
series.gapPolicy.mode = HYMCartesianGapModeAutoGap;
series.gapPolicy.maximumMissingPoints = 11;

HYMCartesianModel *model = [HYMCartesianModel new];
model.series = @[series];
// 时长模式需要显式提供等间隔采样时间轴。
model.samplingStart = [NSDate date];
model.samplingInterval = 300;
series.gapPolicy.mode = HYMCartesianGapModeAutoGapDuration;
series.gapPolicy.maximumMissingDuration = 3300;
```

`samplingStart` 默认 nil，不改变已有类目轴行为。启用后按现有 `CartesianTimeAxis` 规则生成时间标签；这不是不等间隔或任意数值 X 轴支持。

## Demo

折线图和混合图页搜索 **autoGap**：

1. 点击“11/12/13 空点 autoGap 场景”，加载 40 个原始位置、4 个有效点的样本。
2. 两个系列分别展示“最多 11 个空点”与“最多 55 分钟缺测”；采样间隔 300 秒，第一段连接、后两段断开。
3. “当前系列”中选择全部断开、全部连接、按空点数量、按缺测时长，或恢复旧的“跨空值连线”配置。
4. 搜索“缺测”修改对应上限；切换编辑系列可独立调整策略。
5. 搜索时间轴可改变采样间隔，观察时长策略变化；关闭时间轴后，时长策略在缺测处断开。

配置与预设直接进入实际模型，没有额外独立场景页面。

## 验证范围

新增 `CartesianGapPolicyTests` 覆盖 11/12/13 边界、无效输入、前后/全缺测、0 值、时长等号与溢出、旧 API 兼容、降采样/裁剪、五种连接形态的面积闭合、缺测命中、堆叠、双轴混合、显隐/更新/空数据恢复、OC 快照及 Demo 绑定。UI 回归在折线与混合页加载预设并切换策略；执行结果见 [当前能力清单](charts-capability-status.md)。
