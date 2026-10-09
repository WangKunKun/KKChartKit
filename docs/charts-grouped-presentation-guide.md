# 分组提示与图片、自定义图例

2026-09-30。适用于 Line / Column / Bar / Combined，沿用现有原始命中数据、业务组和图例测量。新增配置均默认关闭或 nil，原有提示与图例行为保持兼容。

## 分组 Tooltip

```swift
var options = HYMChartTooltipTextOptions(header: "{key}")
options.cartesian.groupsByBusinessID = true
options.cartesian.showsGroupSubtotals = true
options.cartesian.hidesZeroValues = true
options.cartesian.excludedSeriesIDs = ["internal-target"]
options.cartesian.ungroupedTitle = "其他"
options.cartesian.subtotalTitle = "净合计"
chart.tooltipTextOptions = options
chart.showsTooltipOnHit = true
chart.isSharedTooltipOnTapEnabled = true
```

模型中用 `CartesianSeriesGroup(id:name:)` 声明组，通过 `series.groupID` 关联。`groupID` 是业务展示组，`stackID` 是数学堆叠组，二者独立。

- 组和组内行按命中数组首次出现的顺序排列；同组非相邻系列合并。图例排序不重排提示行。
- 组名称不存在或为空时显示组 ID；没有 groupID 的项归入“未分组”。空字符串 ID 与 nil 不同。
- 默认平铺；关闭分组仍可使用零值过滤、系列 ID 过滤。过滤只影响内置提示，不修改命中快照、绘图或回调。
- 过滤后无数据时不显示只剩标题的空弹窗；共享准线和命中回调仍有效。
- 单点提示也能显示组名，但只有一行时不显示小计。开启共享提示才能同时查看多条系列。
- 系列显式 `valueFormat` 优先于全局小数位和后缀。聚合行保留时间区间和覆盖率信息。
- 自定义 `popupContentProvider` 或 `onHitLocated` 继续使用现有单点链路，不使用本内置展示配置。两层弹窗开关继续有效。

### 小计的含义

小计默认关闭，只有开启分组和小计后才尝试生成。它只汇总**当前命中、未过滤且显示数值的行**，要求：

1. 存在业务 groupID，至少两行；
2. 所有行都是原始采样，源索引范围相同；
3. 单位、值轴、系列数值格式一致；
4. 求和结果有限。

小计对原始展示数值求代数和，不相加累计绘制终点或百分比。`100 W + (-40 W)` 得到 `60 W`。即使系列打开绝对值展示，小计仍保留合计符号。单位/格式不一致、跨轴、时间聚合、溢出等情况直接省略小计，不擅自换算、猜测或平均。相同单位也不代表业务一定允许相加，因此应由调用方主动开启。标题可本地化。

SwiftUI 现有封装直接传递：

```swift
LineChart(model: model, theme: theme,
          isSharedTooltipOnTapEnabled: true,
          tooltipTextOptions: options)
```

## 图片与自定义图例符号

```swift
theme.legend.isEnabled = true
theme.legend.symbolSize = CGSize(width: 24, height: 18)
theme.legend.startsNewRowPerGroup = true
theme.legend.itemOverrides["solar"] = LegendItemStyle(
    title: "光伏",
    symbolColor: .systemOrange,
    image: UIImage(systemName: "sun.max.fill"),
    hiddenImage: UIImage(systemName: "sun.max"),
    backgroundColor: .secondarySystemBackground,
    cornerRadius: 6
)
theme.legend.itemOverrides["battery"] = LegendItemStyle(
    symbolViewProvider: { visible in
        let label = UILabel()
        label.text = visible ? "开" : "关"
        label.font = .systemFont(ofSize: 10)
        label.textAlignment = .center
        label.backgroundColor = visible ? .systemGreen : .systemGray
        return label
    }
)
chart.update(theme: theme)
```

优先级为 `symbolViewProvider` 返回的视图 > 当前状态图片 > 原有形状。provider 返回 nil 时继续回退；隐藏图片为 nil 时复用正常图片。图片按 `symbolSize` 等比缩放，template 图片使用符号颜色。隐藏态仍沿用 `hiddenAlpha`；恢复可见不改变原系列颜色。

provider 在主线程每次图例更新时调用，输入实际系列显隐状态。请返回该图例项独占的视图，可以复用；不要强捕获图表造成循环引用。容器负责设置符号 frame、裁剪和点击，子视图不独立接收触摸。自定义范围是**图例符号槽**，不是任意整行尺寸或独立开关控件。

`startsNewRowPerGroup` 在**排序后的相邻项 groupID 改变**时另起一行，不重新归并或排序系列；nil 到非 nil 也换行。需同组连续时配置 `legendOrder`。左右图例仍为单列。

图片和自定义视图统一使用固定符号尺寸，不根据图片固有大小/视图 intrinsicContentSize 改变测量。公开 `ChartLegendMeasurer.measure` 和真实图例共用换行规则；需要更大符号时修改 `symbolSize`。背景只影响外观，不增加 padding。已有最大行数、滚动、展开、最小绘图区保护继续生效。

更新覆盖为 nil、清空字典或移除系列时，旧图片、自定义视图和背景会清理。默认图例继续显示原符号并保留可访问性标题与显隐状态。

## Objective-C

```objc
bridge.tooltipOptions.groupsByBusinessID = YES;
bridge.tooltipOptions.showsGroupSubtotals = YES;
bridge.tooltipOptions.hidesZeroValues = YES;
bridge.tooltipOptions.excludedSeriesIDs = @[@"internal-target"];
bridge.legendStartsNewRowPerGroup = YES;
bridge.legendSymbolSize = CGSizeMake(24, 18);
HYMCartesianLegendItemStyle *style = [HYMCartesianLegendItemStyle new];
style.image = [UIImage systemImageNamed:@"sun.max.fill"];
style.hiddenImage = [UIImage systemImageNamed:@"sun.max"];
bridge.legendItemStyles = @{@"solar": style};
NSError *error = nil;
[bridge updateWithModel:model preserveViewport:YES error:&error];
```

桥接属性修改后需 configure/update 才应用。Objective-C 示例的“轴系验证”已接入分组提示、原值小计和图片图例。

## Demo 与验证

首页进入任一轴系图 → 搜索“分组提示” → “分组提示与图片图例场景”。样本包含能源组、环境组和无组系列；能源组有正负数，备用项有零值。

搜索“按业务组”“小计”“提示隐藏零值”“提示排除”验证提示行为。搜索“图例内容预设”可选择默认、图片、自定义状态；SF Symbol 名称可以编辑，无效名称回退默认形状。图片、背景、圆角、分组换行均可以恢复默认。暂时禁用的控件保留原值。

新增 `GroupedPresentationTests` 验证原值小计、顺序、过滤、空结果、单位/轴/格式/聚合边界、溢出、四类渲染器共享命中、四方向图例测量、显隐图片、自定义视图复用与清理、OC 和 Demo 依赖。UI 测试 `testGroupedTooltipAndImageLegendPresetOnAllCartesianPages` 操作四个页面、切换图例显隐和分组，保存截图。

后续同日已补齐图标、名称/数值分栏、逐点名称/隐藏/仅名称和超高内容滚动，见[富内容提示指南](charts-rich-tooltip-guide.md)。前一采样回退/偏移、固定顶部、多个业务组横向并排、任意富文本、分组图例标题或整行模板、卡片/联动/全屏仍待后续。下方字段与测试数量记录本篇基础展示交付时的结果。

### 新增面板字段

| 分组 | 可编辑项 |
| --- | --- |
| 交互与弹窗行为 | 按业务组显示提示、显示组小计、提示隐藏零值、提示排除系列 ID、未分组标题、小计标题 |
| 当前系列 | 图例内容预设、图例图片 SF Symbol、隐藏时图例图片 SF Symbol、自定义图例项背景、图例项背景、图例项圆角 |
| 图例布局 | 业务组变化时另起一行 |

共新增 13 个可编辑项，登记清单由 228 增至 241，绑定遍历为 2,597 次。新增的场景按钮另计，场景隔离由 12² 增为 13² = 169 组。09-29 审计文档保留历史清单，新增部分以本表及测试导出的 JSON 为准。

### 2026-09-30 验证结果

环境：Xcode 26.3（17C529），iPhone 15 Pro 模拟器，iOS 17.2。完整图表回归 `TEST SUCCEEDED`：**234 项单元测试、17 项 Demo UI 测试，0 失败**。其中新增 10 项分组展示单元测试及 1 项遍历四个页面的 UI 测试。241 项控件、2,597 次绑定读写、169 组场景切换、750 组渲染矩阵通过。

首轮极值检查发现原有数值格式化在超出 Int 范围时崩溃，已将标签和轴的整数转换改为可失败的精确转换，并保留回归断言。没有通过削弱极值测试绕过问题。

已查看四类图表 UI 截图，核对分组提示、组小计、图片、自定义“开/关”符号和业务组分行；不是全配置像素级金图，也未进行真机、多系统版本或性能基准。README 中两种语言的 Swift 示例已对当前编译模块通过 `swiftc -typecheck`，文档本地链接检查通过。

临时产物（清理后需重新运行生成，不纳入仓库）：

- 完整回归结果：`/tmp/SwiftFunctionProject-presentation-regression-20260930.xcresult`
- 日志：`/tmp/SwiftFunctionProject-presentation-regression-20260930.log`
- 四页面截图：`/tmp/SwiftFunctionProject-presentation-evidence-20260930/`

收尾补齐新图例控件的禁用原因、非内置弹窗的 Demo 读数行为，以及轴/标签极端值断言后，再次运行 **234 项全部单元测试 + 2 项相关 UI 测试**，结果仍为 0 失败、`TEST SUCCEEDED`。最终结果包：`/tmp/SwiftFunctionProject-presentation-final-20260930.xcresult`；日志为同名 `.log`。
