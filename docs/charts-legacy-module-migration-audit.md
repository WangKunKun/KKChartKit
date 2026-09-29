# 旧图表模块替换评估

> 最新进度：旧模块迁移第 2 步已接入混合图、分组堆叠、系列独立样式和 Demo/OC 调试入口，详见 [混合图指南](charts-combined-and-stacks-guide.md)。下文的缺口描述保留为当时评估基线。

> 后续进度：迁移第 1 步的数据语义、业务组元数据、每系列格式与最小 OC 桥接已接入，见 [实施指南](charts-data-semantics-guide.md)。下文保留实施前的审计基线，不代表这些子项仍全部缺失。

日期：2026-09-24。基准：当前工作区源码，包含尚未提交的固定柱宽、间距、滚动及绘制对象复用功能。

## 1. 范围与结论

本次检查 `SwiftFunctionProject/参考图表/` 下的自定义封装，排除所有 `AAChartKit/` 内容。非 vendor 的 Objective-C 文件共 19 个头文件、18 个实现文件，约 6496 行；另外包含 7 组图标资源。

这是一次静态代码与接口对照，没有运行旧模块，没有读取或验证 AAChartKit 内部实现。下文“已实现”指自定义封装中存在实际调用链；依赖底层 AAChartKit 的最终显示效果仍需老项目场景验收。在当前工程参考目录之外未找到这些旧类的业务调用点，因此不能确认每个配置在老项目中的使用频率，也不能承诺零改调用代码即可替换。

**当前 HYMCharts 可以承接基础图表场景，但还不能完整替换这个目录。** 旧模块实际包含“图表绘制适配 + 分组数据和单位语义 + 原生展示组件 + 老项目业务约定”。必须同时覆盖这几层，不能只对比图表类型。

不需要先实现 AAChartKit 的全部图表类型。本次封装顶层只明确配置曲线面积、柱状、折线；系列类型还有字符串透传扩展。饼图、散点等没有在这批封装中发现专用调用场景，暂不列为替换前置条件。

## 2. 旧模块实际增加了什么

| 组件 | 额外职责 | 实现边界 |
|---|---|---|
| `HMAAChartModel` / `HMAASeries` / `HMAASeriesElement` | 图表 → 业务组 → 子系列；组标题、组总值、逐点名称、单位、显隐、版本配置 | 业务组与绘制堆叠组是不同概念，不能合并为一个 ID |
| `HMAAChartManager` | 转 AA 配置；混合系列、堆叠组、双轴、缺测策略、分段颜色、标线、默认窗口 | 最终绘制依赖 AA；不能算自研的绘图引擎 |
| `HMAASeriesUtil` | 数值字符串处理；k/M/G；绝对值显示；小数精度、舍入/截断、当前 Locale、货币、自定义单位；正负拆分 | 格式化值与绘制值分开；组总值按可见组内系列计算 |
| `HMTooltipTool` / `HMTooltip` / `HMIconTooltip` | JS Tooltip + 两版 UIKit Tooltip；独立横轴标题、分组、图标、分栏、分隔线、明细名称 | 三条路径行为不完全一致；图标版多组分支只取首组和末组 |
| `HMAAChartView` | 无数据占位、原生准线、手势回调、标题/单位、汇总表头、日出日落行、暗色切换 | 表头可被 Tooltip 临时隐藏；日出日落是外部传入文本和图片，不计算天文时间，也不是时间轴注解 |
| `HMLGAAChartView` / `HMChartLGSwitch` | 两版图例、点击显隐、背景/透明度、虚线符号或图片开关、换行、图表高度、全屏入口 | 当前真正使用的图例在此；外层会直接调整自己的 frame |
| `HMChartTool` | 颜色、单位字符串映射、图例高度预计算 | 高度方法使用第一版 24 pt 行高，与第二版 18 pt 行高不一致 |
| `HMMTAAChartView` | 多个图垂直排布，将某图选中的索引传给其他图 | 同步选点，不同步缩放/窗口；不是按时间对齐的通用联动 |
| `HMAAChartFullScreenVC` | 全屏展示与还原 | 新建图表并旋转 90°，不是完整的屏幕方向管理；未显式复制当前缩放窗口和选择状态 |
| `HMAAChartUtil` | 项目默认空态、翻译/字体/颜色、能源指标正负方向与名称映射、AI 数据预处理 | 强业务耦合，宜放迁移适配层 |

关键源码入口：

- [旧系列模型](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h:37>)；[格式化与组汇总](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.m:42>)。
- [绘图配置与系列转换](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m:355>)。
- [原生组件组装](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.m:326>)；[图例与高度布局](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.m:139>)。
- [多图索引联动](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.m:36>)；[全屏实现](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.m:21>)。
- [业务指标适配](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/参考图表/HMAAChartUtil.m:55>)。

## 3. 和当前库逐项对照

“部分”表示已有底层或扩展入口，但不能直接提供旧模块的完整行为。P0 为覆盖相应旧场景的阻塞项；实际启用顺序仍应由老项目调用清单决定。

| 旧能力                                   | HYMCharts 现状                                       | 需要补充/迁移                                                                              | 优先级   |
| ------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------ | ----- |
| 多系列折线、平滑线、阶梯线、面积、柱状                   | 已有                                                 | 默认样式映射、代表场景视觉比对                                                                      | 已有基础  |
| 同图 column + line/spline/areaspline    | 缺失；目前每个 Renderer 一种主体类型                            | 系列级类型、共享坐标/值域/命中/图例、绘制顺序                                                             | P0    |
| 多个 stackGroup 分别堆叠并排                  | 缺失；`StackConfig.grouped` 只是预留                      | 堆叠组 ID、按轴/组/正负累计、组内百分比分母、柱槽位与命中                                                      | P0    |
| 每个系列独立平滑/阶梯、面积开关、填充色/透明度/渐变、隐藏 marker | 部分；连接方式、面积、渐变、marker 显示主要是全图 Theme                 | 加系列覆盖配置；已有系列颜色、虚线、marker 形状保留                                                        | P0    |
| 按 X 或 Y 阈值切换线色和填充色 `zones`            | 缺失；逐柱颜色和 `negativeColor` 不能替代连续线段分区                | 分区配置、边界交点、曲线/面积裁剪；负值曲线换色也需补齐                                                         | P0    |
| `autoGap` 短缺测连接、长缺测断开                 | 部分；只有全连接/全断开 `connectNulls`                        | 按连续缺测数量或时长配置；不伪造补点值                                                                  | P0    |
| 普通/百分比正负堆叠                            | 已有基础                                               | 用老项目正负混合样例核对百分比分母、面积边界与绘制顺序；不复制透明虚拟系列技巧                                              | P0 验收 |
| 双 Y 轴、范围、指定刻度、单位                      | Line/Column 已有基础                                   | 轴独立字号/颜色/显隐、主次轴格式策略；现有轴 Theme 多为共用样式                                                 | P1    |
| X 轴类别、刻度间隔、默认显示范围                     | 部分                                                 | 旧 `defaultScope` 端点与新 `Range` 语义转换；显式类目刻度间隔需核对实现；`xAxisType` 字符串透传无法直接等价             | P1    |
| 标线及文字                                 | 已有线色/宽度/虚线/数值/标签                                   | 独立标签颜色、字号/暗色方案；绘制层次按需求扩展                                                             | P1    |
| 业务分组、组总值、组标题、逐点名称                     | 缺失专用模型；当前系列为扁平列表                                   | `groupID`、稳定系列 ID、逐点展示元数据、分组汇总策略                                                     | P0    |
| 每系列/每组单位、k/M/G、绝对值、货币、截断、Locale       | 部分；有单位字段、轴 formatter、Tooltip 全局后缀/精度               | 可复用格式化策略；每系列独立；原始值与展示值分开                                                             | P0    |
| Tooltip 显示原值、汇总值、百分比                  | 尚未统一                                               | shared target 已给原值，但单点 Column 的 `value` 在堆叠时仍是累计值；统一 `rawValue/drawValue/percentage` | P0    |
| 分组 Tooltip、组小计、图标、双栏、仅名称、逐点名称、前一采样值   | 部分；UIKit 自定义内容与定位回调已有                              | 结构化 Tooltip section/row/presentation；`xSeriesArray` 独立标题、`showPrev` 显示偏移策略           | P0    |
| 不隐藏图形但隐藏 Tooltip 中的系列/点               | 缺失专用配置                                             | Tooltip inclusion/filter 策略，与 `isVisible` 分离                                         | P0    |
| 置顶 Tooltip、表头替换、抬手隐藏/超时消失             | 部分；有锚点上下放置和外部定位                                    | 位置策略、交互生命周期、外部表头联动；`.top` 不是固定图表顶部                                                   | P1    |
| 图例换行、颜色/符号、自定义顺序、显隐、测量                | 已有，且支持四向布局、滚动和真实宽高                                 | 保留现有统一测量引擎                                                                           | 已有基础  |
| 图例图片、开关式样、单项背景、按业务组分行                 | 缺失                                                 | 可扩展图例 item 内容/样式、分组布局；测量与渲染用同一配置                                                     | P0/P1 |
| 主动选择某个索引、多个图同步准线与 Tooltip             | 缺失公开的索引选择入口；已有手势命中与区间定位                            | `select/clearSelection`、选择回调来源、防循环；之后增加可选联动协调器                                       | P0    |
| 垂直 pan 交给外层页面                         | 尚无旧 delegate 对等接口                                  | 方向仲裁、ScrollView 手势协调、触摸开始/结束事件                                                       | P1    |
| 图表标题+单位、统计表头、日出日落信息行、空态               | 只有普通图表标题                                           | 通用卡片容器与 header/footer/empty 插槽；能源 UI 在适配层                                            | P0    |
| 全屏放大/恢复                               | 缺失现成容器                                             | UIKit 全屏组件、尺寸变化、窗口/显隐/选择状态共享与恢复                                                      | P1    |
| 深浅色自动切换                               | 部分；主题可传 UIColor，默认也有系统色                            | 验证并补齐 trait 改变时 CGColor 图层刷新、Tooltip/图例更新，映射旧关闭策略                                    | P1    |
| 初始化、刷新数据、渲染完成回调                       | 有 configure/update，支持保留窗口                          | OC 语义映射、明确 render completion；数据更新不是 append API                                       | P0/P1 |
| OC 调用与 SDK 分发                         | 轴系桥接缺失；现有 OCBridge 只覆盖 Radar/Heatmap；仍是 App target | NSObject 模型、非泛型 UIView facade、block/delegate、独立库产物与资源加载                              | P0    |
| 截图导出                                  | 当前无标准 API；旧实现也未完成                                  | 按新需求另做 snapshot，不算旧已成功能回归                                                            | 后续    |

当前源码核对依据：

- [模型、轴与堆叠预留](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift:5>)。
- [折线按全局主题绘制及负值曲线限制](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Line/LineChartRenderer.swift:129>)。
- [现有图例配置与测量](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Cartesian/ChartLegend.swift:14>)。
- [现有 Tooltip 数据与模板](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Core/HYMChartInteraction.swift:34>)；[单柱命中值语义](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Column/ColumnHitTarget.swift:4>)。
- [通用 UIKit 入口](</Users/hoymiles/Desktop/AI编程项目/Swift/SwiftFunctionProject/SwiftFunctionProject/Charts/Core/HYMChartView.swift:13>)。

当前库已经增加、但不应误算为旧模块迁移缺口的能力：固定 pt 柱宽和间距、溢出自动滚动、可配置初始区间、按系列 reducer 的时间聚合、折线 Min/Max 降采样、绘制对象复用、图例完整尺寸测量。迁移时初始关闭聚合更容易核对原始点、索引、Tooltip；验收后再按指标启用。

## 4. 旧实现中的占位和不一致

不能把头文件注释直接当成已经实现的产品能力，以下情况需单独处理：

1. **截图占位**：`snapClosure`、`triggerSnap` 存在，但 `HMLGAAChartView.m:40` 的 finishLoad 分支为空，未找到截图生成或调用 `snapClosure` 的实现。
2. **独立图例占位**：`HMChartLegengView.m:98` 的 createLegengListView 仅创建数组，主体未实现；有效图例是 HMLGAAChartView 的两版实现。
3. **缺测边界与注释不同**：`HMAAChartManager.m:613` 实际条件是 `len >= 12`，即连续 12 个空点也断开，而注释描述“不超过 12 不截断”。新策略应明确边界，并覆盖 11/12/13 个空点。
4. **多图选点限制**：setTouchPointXIndex 注入 JS 更新底层 crosshair/tooltip，未显式刷新自定义 UIKit Tooltip；原生 Tooltip 模式的联动不能仅凭该接口视为完整支持。也没有同步窗口的代码。
5. **Tooltip 路径不一致**：hidePoints 主要在 JS formatter 中过滤，UIKit 两版没有同等过滤调用；图标版多组只处理 first/last，且右侧标题处误取 firstObject。新实现应统一语义，不照搬漏行行为。
6. **图例高度不统一**：旧测量按第一版计算；版本 2 使用不同尺寸。空数组还会按公式得到负高度。新库已有统一测量，应扩展它而不是引入第二套估算。
7. **部分轴/标线配置未正确传递**：次轴 tickPositions 分支读取主轴数组；标线转换固定 zIndex=3，且没消费模型 dashStyle。应支持合理配置语义，不保留这些错误。
8. **数据刷新入口不等于完整数据更新**：onlyRefreshTheChartData 重用 manager 已打包的 series，未重新转换外部变更后的模型。迁移要明确传入新模型/新数据的时机。
9. **遗留边界问题需用新实现避免**：Tooltip 多处直接按索引访问数组；正负拆分先调用 doubleValue 再检查 NSNull；系列 copy 漏传部分新增字段；旧版图例以 `i*10+j` 编码，组内超过 10 项有碰撞风险。

这些是静态识别到的风险或明确实现差异，不代表已在老项目运行复现。尤其不得将旧 bug 作为新库兼容目标。

## 5. 建议分层与高度语义

建议分成三层：

1. **HYMCharts 通用核心**：混合图、分组堆叠、系列样式、缺测/分段策略、命中值语义、选择控制、格式化与结构化 Tooltip、图例测量/扩展。
2. **HYMCharts UIKit 组件及 OCBridge**：图表卡片、header/footer/empty 插槽、全屏、选择联动、OC 模型/视图/回调。独立组件可以按需使用，不要求每张图带业务 UI。
3. **老项目兼容适配层**：映射 HMAA 模型与默认样式；能源图标、业务 key 正负方向、国际化 key、日出日落文字、历史金额规则在这里。通用核心不引用 `grid_p_power` 或 `Language(@"k_...")`。

三个 ID 应独立：`seriesID` 标识数据系列；`groupID` 表示 Tooltip/图例业务组；`stackID` 表示数学堆叠组。例如“发电/耗电”可以分成两个 Tooltip 组，但各自又有不同堆叠方式。

高度尤其需要重新定义。旧 `chartHeight` 设置的是内层 HMAAChartView 的总高度，它内部还包含版本 2 标题 44 pt、统计头 62 pt、底部信息 38 pt，并不是纯绘图区高度。外层再追加图例，还会修改自身 frame。

新容器建议提供统一测量结果：

`总高度 = 外层上下内边距 + header 实测高度 + 不含图例的图表视图高度（含轴/图表内部标题）+ 上下图例追加高度 + footer 实测高度 + 各区间距`

图例继续用现有 ChartLegendMeasurer；卡片测量器只组合各区域，不能重复计入图例或标题。左右图例先扣宽度再测量；空态单独定义是否保留 header/footer。外部通过测量值设置约束，组件布局过程中不擅自改变调用方的 frame。若要求“纯 plot 高度固定”，必须另提供轴和内部标题的布局预算，不能把现有 chartHeight 简单改名当作 plotHeight。

## 6. 兼容与接入边界

“功能替换”允许老项目改调用；“直接删目录替换、尽量不改调用”还需要旧 API facade。建议先保留/重建 HMAAChartModel/HMAASeries 等数据契约，内部转换到 HYM 模型，逐步迁移业务调用；若目录必须整体移除，facade 可以属于单独的兼容模块。

适配应覆盖：

- NSNumber/数值字符串/NSNull → 有效 Double/缺测，保留原索引；非法字符串不能静默变成业务上的 0。
- `isHidden` 反向映射到 `isVisible`；绑定稳定 ID，不能用刷新后的数组位置作为身份。
- `showFabs` 默认只影响展示值；业务正负变换单独执行且只执行一次。
- `defaultScope` 的旧索引端点与新半开区间转换；固定柱宽模式只是起点定位，显示数量由可用宽度决定，不能承诺任意区间都塞进一屏。
- `reverse` 区分绘制顺序和 Tooltip/图例顺序，避免打乱系列身份。
- 旧各版本 Tooltip 统一到结构化数据，不继续依赖 JS formatter。
- 回调、线程、首次布局完成、数据刷新完成、显示/隐藏和全屏状态返回的契约。

目录之外依赖包括 `Language`、`colorNamed`、`Font_Size_weight`、`CHECK_NULL_EXEC_BLOCK`；空壳图例还使用 Masonry。空态图片 `img_chart_nodata` 和命名颜色依赖老项目资源。提供的七组图片仅包含能源图标和日出日落，不构成完整资源包。应使用资源 Bundle 或外部注入，而非默认主 Bundle 字符串查找。

当前工程最低部署配置是 iOS 15，只有 App/测试 targets，没有独立发布的图表库产物。老项目最低系统、Swift/OC 编译配置、包管理方式、现有调用签名和资源位置仍需后续接入时核对。

另：参考目录位于 Xcode 自动同步的源码根目录内，当前项目配置没有显示针对它的排除记录。后续开始构建或集成前，应检查 target membership，避免参考 OC/vendor 代码意外进入新库编译；本次只记录，不改工程配置。

## 7. 建议实施顺序及验收

| 阶段                 | 交付                                                 | 关键验收                                                   |
| ------------------ | -------------------------------------------------- | ------------------------------------------------------ |
| 1. 数据语义与 OC 接入最小链路 | 统一 raw/draw/percentage；业务组元数据、格式化策略；最小轴系 OC facade | OC 页面显示多系列；堆叠 Tooltip 显示原值；W/Wh/%/金额各自格式正确；NSNull 不变 0 |
| 2. 绘图核心补齐          | 系列独立类型/样式、混合图、分组堆叠                                 | 柱+线+双轴；两个堆叠组并排；显隐后的组宽/值域/分母/命中正确                       |
| 3. 缺测与颜色分区         | autoGap 阈值、X/Y zones、曲线负值颜色                        | 11/12/13 空点，跨零/跨阈值，渐变与面积边界，不能凭空生成采样                    |
| 4. Tooltip 与图例     | 分组/图标/过滤/偏移/置顶；图片或自定义图例、业务组布局、统一测量                 | 原值和组小计、独立单位、隐藏点、长名称、多语言、全隐藏后恢复、宽度变化                    |
| 5. 卡片和联动           | header/footer/empty、选择 API、联动、手势协调、全屏              | 高度测量一致；上下滚动不卡；多图选点不循环；全屏返回保持状态；深浅色实时更新                 |
| 6. 独立分发和真实迁移       | SDK 产物、资源、完整 OC facade、旧 API 映射、逐页面切换              | 老项目编译与代表页面对照；移除旧目录后无 AA/JS 依赖；3000 点真机交互检查             |

每阶段新增配置都进入现有对应图表 Demo 属性面板；混合图需要独立类型入口时只保留一个统一调试页。闭包使用可选择的命名预设。不要新增一堆不可配置的重复场景页面。

验收样例至少包括：双轴混合；正负面积堆叠；两个堆叠组；多单位分组 Tooltip；跨阈值颜色；长短缺测；全部无数据/全部图例隐藏；三个以上业务组；超过 10 项图例；不同长度系列；全屏和深浅色；手动初始区间；288/1440/2000/3000 点及聚合开关。

这里的阶段是本次迁移建议，不表示实现已开始。本次只新增本评估文档，不改图表源码，不提交代码；未运行构建、单元测试或旧项目视觉验收。
