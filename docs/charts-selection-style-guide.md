# 轴系主体选中反馈（G5）

更新：2026-10-02。复用既有命中、tap/drag 与 `applySelection` 链路；不引入第二套交互状态机。

## Swift 配置

```swift
var theme = CartesianChartTheme()
theme.selection = CartesianSelectionStyle(
    isEnabled: true,
    color: .systemYellow,
    lineWidth: 3,
    fillOpacity: 0.25,
    pointRadius: 9
)
chart.configure(model: model, theme: theme)
chart.isSharedTooltipOnTapEnabled = true // 若需要一列多系列共同高亮
```

默认 `isEnabled == false` 保持旧外观；不依赖 `showsTooltipOnHit`、`isCrosshairEnabled`。开启后：

- **Line / curve / area**：在被选中原始数据点绘制圆形点环，即便原系列 marker 关闭或采样省略该点。半径不小于该系列配置的 marker 半径；这不是整条曲线高亮。
- **Column / Bar**：按实际柱/条矩形绘制填色和描边覆盖层；不使用扩大后的手势容差矩形，不将堆叠累计高度当作当前段厚度。
- **Combined**：同一父级选择层协调柱/线族；单点使用原命中顺序，共享选择分别突出各自图形，不跨族串位。
- **共享选择**：只处理该列实际有限、可见的系列；缺测和隐藏系列不生成高亮。
- 覆盖层在绘图区裁剪，不覆盖轴和图例；不会改写原系列颜色、zones、path、数据标签、值域、命中或 tooltip 数值。

参数防护：线宽钳在 0...20pt，透明度 0...1，点环半径 1...60pt；非有限值分别回退 2 / 0.16 / 7。高亮填色的 alpha 是高亮颜色 alpha 与 `fillOpacity` 的乘积。

## 生命周期

- 命中另一个对象替换高亮；点击空白的实际未命中、`applySelection(nil)` 清除。
- `configure/update`、图例显隐引发更新、程序区间切换、重置视口都会清除，不将旧快照重新绑定到新数据。
- 拖动视口/捏合开始清除旧反馈，取消拖动也清除；正常滑动选中结束保留最后一次命中。
- 重播入场动画立即清除旧选择、准线和提示；动画期间新命中则按当前柱体几何反馈。单纯布局/旋转仍有同一有效选择时重取当前几何。
- 稳定系列 ID、当前图形族、有限值和可见性共同校验；过期序号不能误选后来占用该序号的系列。
- 覆盖层数量不超过当前实际选中系列数，取消/卸载释放；不为全量点创建选择层。

本批**不承诺**跨数据更新保持选择、公开按 ID 程序选中/清除、完整状态导入导出或多图同步。以上 R4 契约仍后置，不应把 renderer 内部测试入口当作容器公开业务 API。

## Objective-C

```objc
bridge.selectionStyle.isEnabled = YES;
bridge.selectionStyle.color = UIColor.systemYellowColor;
bridge.selectionStyle.lineWidth = 3;
bridge.selectionStyle.fillOpacity = 0.25;
bridge.selectionStyle.pointRadius = 9;
bridge.usesSharedTooltip = YES;
[bridge updateWithModel:model preserveViewport:YES error:&error];
```

`HYMCartesianSelectionStyle` 在 configure/update 时复制为 Swift 值配置。默认关闭。

## 同页 Demo 与测试

四个现有轴系页面搜索“点柱条与共享”，加载“点柱条与共享选中高亮场景”，然后点图；搜索 `selection` 可关闭高亮、调整颜色、线宽、透明度和点环半径。原有单点/共享/滑动选中开关不变，修改属性触发 update 并清除旧选择是设计行为。

`SelectionStyleTests` 覆盖默认兼容、四 renderer 几何、共享/缺测/隐藏、真实 tap 与弹窗开关解耦、稳定 ID/图形族校验、布局/动画/视口、采样原始点/次轴、循环选择层数量、取消后 1x/2x/3x 像素恢复、OC 和 Demo Binding。界面截图与公共 framework 宿主结果见本批验收记录。

最终结果包、成功截图、失败与修复过程见 [2026-10-02 G2–G5 验证记录](charts-presentation-g2-g5-2026-10-02.md)。
