# 旧图表模块替换评估

> [参考源码旧图表 Demo](../Examples/LegacyChartDemo/README.md) 的 11 场景运行基线已完成；[对照结果](charts-legacy-demo-parity-results.md)补充本轮真实点值、提示、配置与新侧同输入样本。下方“未运行”等表述属于原静态审计范围，不覆盖本轮运行记录。

更新：2026-09-30。原始静态审计：2026-09-24。本轮重新核对当前源码和旧封装接口，更新第 3 节的现状及第 7 节的实施顺序。后续任务以[老项目替换实施计划](charts-legacy-replacement-plan.md)为唯一执行队列；[三方对比](line-chart-parity-comparison.md)用于技术取舍。

**当前已具备大部分绘图核心和通用提示/图例能力，尚未完成老项目模块替换。** 独立 framework 与 Swift/纯 OC 宿主已通过 Debug/Release；按用户最新要求，接下来先完善图表展现形式；正式旧输入转换、真实页面及外围 UIView 组合后置。

## 1. 范围与结论

本次检查 `SwiftFunctionProject/参考图表/` 下的自定义封装，排除所有 `AAChartKit/` 内容。非 vendor 的 Objective-C 文件共 19 个头文件、18 个实现文件，约 6496 行；另外包含 7 组图标资源。

本审计以本地非 vendor 封装的静态代码与接口为依据，没有运行旧模块，也没有验证旧项目内嵌 AAChartKit/Highcharts 的运行行为。下文“已实现”指自定义封装中存在实际调用链；依赖底层 AAChartKit 的最终显示效果仍需老项目场景验收。在当前工程参考目录之外未找到这些旧类的业务调用点，因此不能确认每个配置在老项目中的使用频率，也不能承诺零改调用代码即可替换。

**具备绘图能力与完成模块替换需要分别验收。** 旧模块实际包含“图表绘制适配 + 分组数据和单位语义 + 原生展示组件 + 老项目业务约定”。必须同时覆盖这几层，不能只对比图表类型。

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

## 3. 和当前库逐项对照（2026-09-30）

“已具备”表示有当前源码及本仓库回归记录，仍需旧输入/真实页面验收；“部分”表示不能直接覆盖旧契约。R 编号对应新的替换计划。Swift 核心、OC 配置和业务适配的状态分别说明，避免将功能存在误认为页面已经可迁移。

| 旧能力 | 当前 HYMCharts | 剩余处理 / 任务 |
| --- | --- | --- |
| 多系列线/曲线/阶梯/面积/柱状 | 已具备，含系列样式 | 默认主题、形态和真实输入对照，R2/R7 |
| 同图 column + line/spline/areaspline | 已具备 CombinedChartRenderer | 旧类型字符串映射与未知值诊断，R2 |
| 多个 stackGroup 分别堆叠 | 已具备 stackID 和按轴/组/正负计算 | 对照百分比分母、显隐、槽位与顺序；展示分组另处理，R2/R3 |
| 每系列样式、marker、填充 | Swift 已具备主要覆盖，OC 仅部分 | 虚线、颜色/填充等逐字段核查透传，R2 |
| X/Y zones、曲线负值颜色 | 已具备，含连续裁剪与面积；[指南](charts-color-zones-guide.md) | 样本对照，R2/R7 |
| autoGap | 已具备数量/时长策略，边界明确；[指南](charts-gap-policy-guide.md) | 旧 12 点断开映射与缺测来源验证，R2 |
| 正负/百分比堆叠与面积 | 已具备；共享边界复用已修复 | 无共同底边过渡仍有限制，按真实样本检查；[接缝指南](charts-stacked-area-seams-guide.md) |
| 双 Y 轴、值域、刻度、单位 | 核心有主/次轴数据配置；独立外观和 OC 配置不完整 | 轴字体/色彩/显隐/格式与指定刻度实际生效，R2 |
| X 类目、刻度间隔、默认范围 | 核心有类目/范围与区间命令；显式类目间隔并非值轴间隔 | 核对 defaultScope 端点与 xAxisType 透传，R2 |
| 标线/色带 | Swift 核心已具备基础 | OC 透传、独立标签样式、次轴绑定核对，R2 |
| 业务组、组名、组汇总 | 已有稳定组 ID、静态名称和受约束的小计 | 逐点 gnames、组自己的单位/格式/fgdata 不能视为已完整覆盖，R3 |
| k/M/G、绝对值、货币、截断、Locale | 已有通用每系列格式 | `fractionDigits=100` 分级精度及组级格式、旧单位表/金额语义，R2/R3 |
| raw/aggregated/draw/base/percentage | 四轴系统一快照，Swift/OC 可读 | 旧回调映射与统计语义验收；[数据语义](charts-data-semantics-guide.md) |
| 分组提示/图标/分栏/逐点行名/过滤/仅名称/前值 | 已具备通用链路，含 SwiftUI/OC/Demo | 独立 xSeriesArray、逐点组标题、分组排布与汇总策略还需映射，R3；[富内容](charts-rich-tooltip-guide.md)、[前值](charts-tooltip-selection-guide.md) |
| Tooltip 置顶/偏移 | 已具备，原始命中与取值来源分开 | 默认布局与原版对照，R3/R7 |
| 抬手/超时消失、表头替换 | 无统一公开生命周期；旧原生分支存在抬手隐藏和 5 秒计时 | 与选择/清除/取消事件统一，R4 |
| 图例布局、顺序、显隐、测量 | 已具备四向/换行/滚动、稳定 ID | 保留统一测量，补组标题/旧整行语义中实际使用部分，R3/R5 |
| 图例图片/开关/背景/业务组分行 | 已有图片与自定义符号/背景/组变化换行 | `gcname/showElementName/stackGroupInterval` 等不能只靠换行等价替代，R3 |
| 主动索引选点、多图联动 | 有内部手势命中，无公开选择/清除和协调器 | 选择来源、防循环、同域/异域映射，R4/R6 |
| 外部垂直滚动 | 图表自身手势已具备，无完整外层方向仲裁契约 | ScrollView 嵌套、拖动开始/结束/取消，R4/R5 |
| 标题/单位、统计表头、日出日落、空态 | 有内部普通标题，无完整卡片 | 通用插槽和统一高度；业务内容/资源由适配层注入，R5 |
| 全屏进入/返回 | 无现成组件和完整公开状态恢复 | 视口/显隐/选择保存与恢复，R4/R6 |
| 深浅色自动更新 | 可传动态 UIColor，但未发现完整轴系 trait 重绘链路 | 图层 CGColor、提示/图例与外层组件同步；closeDarkStyle 映射，R5 |
| 初始化/刷新/渲染完成 | configure/update 已有，保留视口；无明确公开渲染完成事件 | 当前 OC 对象重新转换、完成事件版本与时机，R2/R4 |
| OC 与独立 SDK | 四轴系已有最小桥接；独立 HYMCharts.framework 与 Swift/纯 OC 宿主已通过 | R1 最小验收完成；R2 旧使用字段透传与兼容入口仍待做，见[197 项清单](charts-legacy-field-inventory.md) |
| 截图导出 | 旧实现是占位，新库无标准 API | 不能计为旧已成功能；若真实使用则另列任务 |

当前核对入口：

- [模型和轴](../SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift)、[系列样式](../SwiftFunctionProject/Charts/Cartesian/CartesianSeriesStyle.swift)、[混合渲染](../SwiftFunctionProject/Charts/Combined/CombinedChartRenderer.swift)。
- [格式化](../SwiftFunctionProject/Charts/Cartesian/CartesianValueFormat.swift)、[结构化提示](../SwiftFunctionProject/Charts/Cartesian/CartesianTooltipPresentation.swift)、[取值策略](../SwiftFunctionProject/Charts/Cartesian/CartesianTooltipSampleSelection.swift)、[图例](../SwiftFunctionProject/Charts/Cartesian/ChartLegend.swift)。
- [通用视图/手势/更新](../SwiftFunctionProject/Charts/Core/HYMChartView.swift)、[OC 模型](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianModels.swift)、[OC 桥接](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianChartViewBridge.swift)。

固定柱宽/间距、溢出滚动、区间定位、Column 时间聚合、折线采样和绘制复用继续保留。迁移初始先关闭聚合和采样以核对原始点/索引，再按页面需要启用；不会因为旧模块没有相同优化就删除它们。

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

按新的实施计划分成三层：

1. **HYMCharts 通用核心**：混合图、分组堆叠、系列样式、缺测/分段策略、命中值语义、选择控制、格式化与结构化 Tooltip、图例测量/扩展。
2. **HYMCharts UIKit 组件及 OCBridge**：图表卡片、header/footer/empty 插槽、全屏、选择联动、OC 模型/视图/回调。独立组件可以按需使用，不要求每张图带业务 UI。
3. **老项目兼容适配层**：映射 HMAA 模型与默认样式；能源图标、业务 key 正负方向、国际化 key、日出日落文字、历史金额规则在这里。通用核心不引用 `grid_p_power` 或 `Language(@"k_...")`。

三个 ID 应独立：`seriesID` 标识数据系列；`groupID` 表示 Tooltip/图例业务组；`stackID` 表示数学堆叠组。例如“发电/耗电”可以分成两个 Tooltip 组，但各自又有不同堆叠方式。

高度尤其需要重新定义。旧 `chartHeight` 设置的是内层 HMAAChartView 的总高度，它内部还包含版本 2 标题 44 pt、统计头 62 pt、底部信息 38 pt，并不是纯绘图区高度。外层再追加图例，还会修改自身 frame。

新容器建议提供统一测量结果：

`总高度 = 外层上下内边距 + header 实测高度 + 不含图例的图表视图高度（含轴/图表内部标题）+ 上下图例追加高度 + footer 实测高度 + 各区间距`

图例继续用现有 ChartLegendMeasurer；卡片测量器只组合各区域，不能重复计入图例或标题。左右图例先扣宽度再测量；空态单独定义是否保留 header/footer。外部通过测量值设置约束，组件布局过程中不擅自改变调用方的 frame。若要求“纯 plot 高度固定”，必须另提供轴和内部标题的布局预算，不能把现有 chartHeight 简单改名当作 plotHeight。

## 6. 兼容与接入边界

“功能替换”允许老项目改调用；“直接删目录替换、尽量不改调用”还需要旧 API facade。默认以薄适配层承接实际使用的旧输入和调用，内部转换到 HYM 模型；如需保留同名 facade，必要数据契约归兼容模块，避免重复类定义。旧入口的保留范围由调用清单决定，不复制整套未使用 API。

适配应覆盖：

- NSNumber/数值字符串/NSNull → 有效 Double/缺测，保留原索引；非法字符串不能静默变成业务上的 0。
- `isHidden` 反向映射到 `isVisible`；绑定稳定 ID，不能用刷新后的数组位置作为身份。
- `showFabs` 默认只影响展示值；业务正负变换单独执行且只执行一次。
- `defaultScope` 的旧索引端点与新半开区间转换；固定柱宽模式只是起点定位，显示数量由可用宽度决定，不能承诺任意区间都塞进一屏。
- `reverse` 区分绘制顺序和 Tooltip/图例顺序，避免打乱系列身份。
- 旧各版本 Tooltip 统一到结构化数据，不继续依赖 JS formatter。
- 回调、线程、首次布局完成、数据刷新完成、显示/隐藏和全屏状态返回的契约。

目录之外依赖包括 `Language`、`colorNamed`、`Font_Size_weight`、`CHECK_NULL_EXEC_BLOCK`；空壳图例还使用 Masonry。空态图片 `img_chart_nodata` 和命名颜色依赖老项目资源。提供的七组图片仅包含能源图标和日出日落，不构成完整资源包。应使用资源 Bundle 或外部注入，而非默认主 Bundle 字符串查找。

当前工程最低部署配置是 iOS 15；后续已建立独立 HYMCharts.framework 和 Swift/纯 OC 宿主，最小接入验收通过，尚未正式发布。老项目最低系统、Swift/OC 编译配置、包管理方式、现有调用签名和资源位置仍需后续接入时核对。

参考目录在后续实现中已从 App target 的同步成员中排除，记录位于 `project.pbxproj`。独立库建设时仍须再次核查 source/resource membership，确保 Demo、Debug、参考 OC/vendor 与 JS bundle 不进入库产品。

## 7. 重新规划后的执行入口

原六阶段按“语义 → 绘图 → 缺测/颜色 → 提示/图例 → 卡片/联动 → 分发”推进，已积累可复用的核心能力。独立产物已完成最小验收。按用户最新要求，当前优先 G1–G5 图表本体，正式旧适配、外围组件和真实页面后置。

| 原阶段 | 当前判定 | 新任务去向 |
| --- | --- | --- |
| 1 数据语义与最小 OC | 通用语义已有；旧输入转换及完整 OC 未完成 | R0/R1/R2 |
| 2 绘图核心 | 混合/分组堆叠/系列样式已具备 | G1/G3/G4/G5 先补绘制；后续 R2/R7 接入 |
| 3 缺测与颜色 | 已具备；复杂堆叠过渡边界明确 | G1/G2 绘制完善；后续 R2/R7 接入 |
| 4 提示与图例 | 通用展示已具备；独立表头/组级语义/生命周期仍有缺口 | R3/R4/R5 |
| 5 卡片和联动 | 尚未形成完整能力 | R4/R5/R6，按试点页面需要推进 |
| 6 分发与真实迁移 | R1 最小接入验收完成，真实分发/业务迁移未完成 | R0b 确认约束，R7 尽早试点，R8 最终退出旧依赖 |

当时（2026-09-30）的编码顺序是 G1 面积/堆叠，随后 G2–G5 柱条颜色、坐标轴、标注和选择；这些常用绘制能力现已按文末 2026-10-02 增量交付，此处表格保留历史任务分配。统计表头、卡片、日出日落、空态装饰及全屏 view 可在图表外组合，暂不建设；197 项字段清单保留为后续兼容输入。

完整队列、依赖、字段映射和 F01–F10 验收样本见[老项目替换实施计划](charts-legacy-replacement-plan.md)。目前仍缺真实老项目路径、调用和运行基线，因此只能确认参考源码覆盖情况，不能将本仓库测试通过标记为老项目迁移完成。

每次实现继续同步对应现有 Demo 面板、Swift/OC 入口、使用文档与受影响测试。闭包采用命名预设，每种图表维持单一调试页。独立集成宿主用于验证打包与 OC 接入，不作为重复的产品 Demo 入口。

本轮修改评估与计划文档，没有新增图表运行时代码，也未运行旧项目。后续任务状态和验证结果统一写入替换计划与能力清单。


## 2026-10-02 图表本体增量

G2–G5 已落地柱/条分区、每轴独立样式、标线/色带标签和主体选择，并同步公开 OC 入口；上文日期下的缺口判断保留为历史审计。真实旧字段适配并未因此全部完成。当前范围、验证和未做事项见 [G2–G5 记录](charts-presentation-g2-g5-2026-10-02.md)。
