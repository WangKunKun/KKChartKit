# 旧图表字段与入口处置清单

> 历史状态说明：下表保留 2026-09-30 的迁移阶段分类，不应再据此认定 G2–G5 的原生/OC 能力仍缺失。2026-10-03 的模型、原生与适配器分别核对见[通用模型覆盖矩阵](charts-neutral-model-coverage.md)。尤其旧 `HMAAYAxis.unit` 实现为刻度值后缀，并非轴标题；旧标线 zIndex/dashStyle 声明不代表原实现曾按配置生效。

更新：2026-09-30。范围是参考目录中聚合头导出的模型/图表，加上业务工厂、全屏、标线和管理器，共 9 个头文件。AAChartKit 本体及内部 tooltip/view 布局类不作为替换的公开 API 承诺。真实老项目调用清单仍待提供，本清单不代表全部调用方已覆盖。

“能力可映射”表示 HYM 已有公开构件可承接，**不表示正式旧模型适配器已实现**。“需新增能力”包含兼容层、展示组件、交互和核心各层，具体落点见表；不能全部堆进 renderer。一个字段标记最主要阻塞，仍需遵守[转换契约](charts-legacy-replacement-plan.md#5-后续兼容接入的转换契约)。

当前按用户要求优先完善图表展现，执行顺序见[计划 G 队列](charts-legacy-replacement-plan.md#4-当前绘制队列与后续迁移队列)。本表的“需新增能力”还包含外围 view 与兼容层，不应整体视为当前绘图工作；状态保留为后续迁移依据。

数据源：[逐成员 JSON](charts-legacy-field-inventory.json)。运行 `python3 scripts/check_chart_migration_inventory.py` 检查漏项、重复、失效字段与来源位置；头文件有新增必须重新核定状态，不能自动归入“已支持”。枚举值的边界另依转换契约验收，本工具仅检查属性与方法声明。

能力可映射：55 | 需 OC 桥接：21 | 需新增能力：102 | 不承接原入口：5 | 需业务确认：14。共 197 个声明（继承属性不重复计）。

D06 是待选择的正负累计/分链语义；D09–D12 是已定位的缺陷，计划修正。不得用默认“完全兼容”把两类混在一起。


| 旧成员 | 状态 | 新落点 | 边界/处理 |
| --- | --- | --- | --- |
| [`HMAAChartUtil.createlgaaChartView`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L17) | 需新增能力 | R5 project factory | 外部业务预设/资源/语言注入，旧同名 facade 不与旧库同链 |
| [`HMAAChartUtil.createlgaaChartViewWithFrame:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L18) | 需新增能力 | R5 project factory | 外部业务预设/资源/语言注入，旧同名 facade 不与旧库同链 |
| [`HMAAChartUtil.createaaChartView`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L21) | 需新增能力 | R5 project factory | 外部业务预设/资源/语言注入，旧同名 facade 不与旧库同链 |
| [`HMAAChartUtil.createaaChartViewWithFrame:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L22) | 需新增能力 | R5 project factory | 外部业务预设/资源/语言注入，旧同名 facade 不与旧库同链 |
| [`HMAAChartUtil.namesWithKey:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L25) | 需业务确认 | R0b business preprocessing | D07 重叠 key 以第一个分支为准，真实业务意图未知；不下沉 SDK |
| [`HMAAChartUtil.formatNamesWithData:positive:negative:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L28) | 需业务确认 | R0b business preprocessing | D07 重叠 key 以第一个分支为准，真实业务意图未知；不下沉 SDK |
| [`HMAAChartUtil.keyNeedOpposite`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L31) | 需业务确认 | R0b business preprocessing | D07 重叠 key 以第一个分支为准，真实业务意图未知；不下沉 SDK |
| [`HMAAChartUtil.keyNeedFabsAndOpposite`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L34) | 需业务确认 | R0b business preprocessing | D07 重叠 key 以第一个分支为准，真实业务意图未知；不下沉 SDK |
| [`HMAAChartUtil.fixAIChatData:type:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L37) | 需业务确认 | R0b business preprocessing | D07 重叠 key 以第一个分支为准，真实业务意图未知；不下沉 SDK |
| [`HMAAChartViewDelegate.hmaaChartView:handlePan:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L16) | 需新增能力 | R4a interaction lifecycle | 旧 UIPanGestureRecognizer 与新语义事件需明确映射 |
| [`HMAAChartView.delegate`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L23) | 需新增能力 | R4a event facade | 已有 onHit 数据，但旧索引/手势生命周期/清除来源协议尚未完整桥接 |
| [`HMAAChartView.clickBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L25) | 需新增能力 | R4a event facade | 已有 onHit 数据，但旧索引/手势生命周期/清除来源协议尚未完整桥接 |
| [`HMAAChartView.finishLoad`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L26) | 需新增能力 | R4a accepted/layout/animation events | 旧 WebView 加载完成非像素完成；须明确版本、线程、回调次数 |
| [`HMAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L29) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L30) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L31) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L32) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMAAChartView.initChartViewWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L35) | 能力可映射 | configure + R2 snapshot conversion | 原生配置后在布局时绘制 |
| [`HMAAChartView.reloadDataWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L38) | 能力可映射 | configure/update + R2 snapshot conversion | D01 每次读新模型，不能重用旧打包数据；旧入口适配仍未完成 |
| [`HMAAChartView.onlyRefreshTheChartData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L41) | 能力可映射 | configure/update + R2 snapshot conversion | D01 每次读新模型，不能重用旧打包数据；旧入口适配仍未完成 |
| [`HMAAChartView.setTouchPointXIndex:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L44) | 需新增能力 | R4a public selection/clear API | 当前无程序选择公开入口，不能使用 rendererForTesting |
| [`HMAAChartView.showNoData:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L47) | 需新增能力 | R5 forced empty state | 退出空态恢复图例/数据且不修改调用方模型 |
| [`HMLGAAChartViewDelegate.hmlgaaChartView:handlePan:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L15) | 需新增能力 | R4a interaction lifecycle | 旧 UIPanGestureRecognizer 与新语义事件需明确映射 |
| [`HMLGAAChartView.delegate`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L21) | 需新增能力 | R4a event facade | 已有 onHit 数据，但旧索引/手势生命周期/清除来源协议尚未完整桥接 |
| [`HMLGAAChartView.clickBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L23) | 需新增能力 | R4a event facade | 已有 onHit 数据，但旧索引/手势生命周期/清除来源协议尚未完整桥接 |
| [`HMLGAAChartView.legendTapBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L24) | 能力可映射 | onSeriesVisibilityChanged + stable ID lookup | 新回调 ID/visible 映射旧业务 element；无虚拟系列 |
| [`HMLGAAChartView.snapClosure`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L25) | 不承接原入口 | separate export requirement if actually used | 旧实现占位，不算既有可回归能力；需要真实调用证据再立项 |
| [`HMLGAAChartView.triggerSnap`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L27) | 不承接原入口 | separate export requirement if actually used | 旧实现占位，不算既有可回归能力；需要真实调用证据再立项 |
| [`HMLGAAChartView.showEnlargeButton`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L29) | 需新增能力 | R6 host/fullscreen coordinator | 需快照/恢复、横屏、安全区，不在 renderer 做页面跳转 |
| [`HMLGAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L32) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMLGAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L33) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMLGAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L34) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMLGAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L35) | 需新增能力 | R5 empty-state presentation | 外部注入图片/文案/样式，不引入 App 宏 |
| [`HMLGAAChartView.reloadDataWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L38) | 能力可映射 | configure/update + R2 snapshot conversion | D01 每次读新模型，不能重用旧打包数据；旧入口适配仍未完成 |
| [`HMLGAAChartView.onlyRefreshTheChartData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L41) | 能力可映射 | configure/update + R2 snapshot conversion | D01 每次读新模型，不能重用旧打包数据；旧入口适配仍未完成 |
| [`HMLGAAChartView.setTouchPointXIndex:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L44) | 需新增能力 | R4a public selection/clear API | 当前无程序选择公开入口，不能使用 rendererForTesting |
| [`HMChartLGSwitch.element`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L50) | 能力可映射 | legend.itemOverrides.symbolViewProvider + visibility callback | 定制图例外观和稳定 ID 绑定；不是直接类名替换 |
| [`HMChartLGSwitch.on`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L52) | 能力可映射 | legend.itemOverrides.symbolViewProvider + visibility callback | 定制图例外观和稳定 ID 绑定；不是直接类名替换 |
| [`HMChartLGSwitch.tapSwitchBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L54) | 能力可映射 | legend.itemOverrides.symbolViewProvider + visibility callback | 定制图例外观和稳定 ID 绑定；不是直接类名替换 |
| [`HMMTAAChartView.chartModels`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L15) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.width`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L18) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.height`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L19) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L22) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L23) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L24) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L25) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMMTAAChartView.initChartView`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L28) | 需新增能力 | R6 multi-chart container | domainID/sample key 联动，布局/空态外部负责 |
| [`HMAAChartFullScreenVC.chartModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L16) | 需新增能力 | R6 fullscreen host | 保存选择/视口/显隐，返回不重置业务状态 |
| [`HMAAChartFullScreenVC.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L19) | 需新增能力 | R6 fullscreen host | 保存选择/视口/显隐，返回不重置业务状态 |
| [`HMAAChartFullScreenVC.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L20) | 需新增能力 | R6 fullscreen host | 保存选择/视口/显隐，返回不重置业务状态 |
| [`HMAAChartFullScreenVC.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L21) | 需新增能力 | R6 fullscreen host | 保存选择/视口/显隐，返回不重置业务状态 |
| [`HMAAChartFullScreenVC.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L22) | 需新增能力 | R6 fullscreen host | 保存选择/视口/显隐，返回不重置业务状态 |
| [`HMAAChartModel.name`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L36) | 能力可映射 | CartesianChartModel.title / HYMCartesianModel.title | 标题内容可承接；布局由后续卡片负责 |
| [`HMAAChartModel.chartType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L37) | 能力可映射 | series.kind + HYMCartesianChartKind | line/column/areaspline 枚举有承接；未知类型诊断，不能静默回落 |
| [`HMAAChartModel.stackType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L38) | 需业务确认 | R2 compatibility stack policy | D05/D06：绘制、图例、提示顺序分离；面积正负/百分比策略需页面确认 |
| [`HMAAChartModel.xAxisArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L39) | 能力可映射 | xAxis.category / HYMCartesianModel.categories | 保留采样位置；标签不是稳定 sample key |
| [`HMAAChartModel.xSeriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L40) | 需新增能力 | R3 header provider / card presentation | 独立逐点表头未接入内置提示；{key} 模板不能代替另一数组 |
| [`HMAAChartModel.seriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L41) | 能力可映射 | series + groups / OC model | 需 R2 稳定身份转换，不按显示名称生成 ID |
| [`HMAAChartModel.version`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L44) | 需新增能力 | R3/R5 native card preset | 整合 v1/v2 标题、提示和高度预算；不复用 JS 分支 |
| [`HMAAChartModel.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L45) | 需新增能力 | R3/R5 native card preset | 整合 v1/v2 标题、提示和高度预算；不复用 JS 分支 |
| [`HMAAChartModel.reverse`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L48) | 需业务确认 | R2 compatibility stack policy | D05/D06：绘制、图例、提示顺序分离；面积正负/百分比策略需页面确认 |
| [`HMAAChartModel.zoomType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L49) | 需 OC 桥接 | HYMChartView.zoomAxisMode | Swift 支持 X/Y/XY；OC bridge 当前只按图形选择轴 |
| [`HMAAChartModel.yAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L50) | 能力可映射 | primary/secondary axis range / OC model | 副轴仅 0/1；Bar 明确不支持副轴 |
| [`HMAAChartModel.yAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L51) | 能力可映射 | primary/secondary axis range / OC model | 副轴仅 0/1；Bar 明确不支持副轴 |
| [`HMAAChartModel.yAxisTickPositions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L52) | 需 OC 桥接 | CartesianAxisModel.tickPositions | OC 模型缺显式刻度数组 |
| [`HMAAChartModel.titleColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L53) | 需 OC 桥接 | CartesianChartTheme | 颜色/字体/contentInset/gridColor 可承接；OC 需主题入口，旧解析优先级须显式 |
| [`HMAAChartModel.titleFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L54) | 需 OC 桥接 | CartesianChartTheme | 颜色/字体/contentInset/gridColor 可承接；OC 需主题入口，旧解析优先级须显式 |
| [`HMAAChartModel.titleWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L55) | 需 OC 桥接 | CartesianChartTheme | 颜色/字体/contentInset/gridColor 可承接；OC 需主题入口，旧解析优先级须显式 |
| [`HMAAChartModel.yAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L56) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.yAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L57) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.yAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L58) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.xAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L59) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.xAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L60) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.xAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L61) | 需新增能力 | R2 axis style configuration | 现主题 tickLabelColor/font 为共用值，独立主次轴样式需补配置再桥接 |
| [`HMAAChartModel.xAxisType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L62) | 需业务确认 | R0b axis semantics | 当前等距类目/时间，任意数值/对数/不等距时间不得声明兼容 |
| [`HMAAChartModel.xAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L63) | 需 OC 桥接 | CartesianAxisModel.min/max | Swift 能力需 OC 暴露；与 defaultScope 的旧优先级一起核对 |
| [`HMAAChartModel.xAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L64) | 需 OC 桥接 | CartesianAxisModel.min/max | Swift 能力需 OC 暴露；与 defaultScope 的旧优先级一起核对 |
| [`HMAAChartModel.xAxisTickInterval`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L65) | 需新增能力 | R2 category ticks | 当前 tickInterval 针对值轴，类目间隔不可直接映射 |
| [`HMAAChartModel.yAxisHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L66) | 需新增能力 | R2 independent axis visibility | 缺完整单独 Y 轴隐藏语义；不能把所有文字透明当兼容 |
| [`HMAAChartModel.leftMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L67) | 需 OC 桥接 | CartesianChartTheme | 颜色/字体/contentInset/gridColor 可承接；OC 需主题入口，旧解析优先级须显式 |
| [`HMAAChartModel.crosshairColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L68) | 需 OC 桥接 | HYMChartView.crosshairColor | OC 缺该外观入口 |
| [`HMAAChartModel.dashColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L69) | 需 OC 桥接 | CartesianChartTheme | 颜色/字体/contentInset/gridColor 可承接；OC 需主题入口，旧解析优先级须显式 |
| [`HMAAChartModel.toolTipBackgroundColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L70) | 需 OC 桥接 | HYMChartTooltipTheme | OC tooltipOptions 尚未提供完整主题 |
| [`HMAAChartModel.toolTipTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L71) | 需 OC 桥接 | HYMChartTooltipTheme | OC tooltipOptions 尚未提供完整主题 |
| [`HMAAChartModel.closeDarkStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L72) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.tooltipPinToTop`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L73) | 能力可映射 | tooltipOptions.position / bridge.showsTooltip | 原生 fixedTop、显示开关已具备；旧超时/抬手由 R4 补 |
| [`HMAAChartModel.tooltipDisable`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L74) | 能力可映射 | tooltipOptions.position / bridge.showsTooltip | 原生 fixedTop、显示开关已具备；旧超时/抬手由 R4 补 |
| [`HMAAChartModel.yAxisPlotLines`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L75) | 需 OC 桥接 | CartesianChartModel.plotLines | Swift 有线与标签，OC 尚缺；详细标签样式另列 |
| [`HMAAChartModel.nativeTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L76) | 需新增能力 | R3/R5 native card preset | 整合 v1/v2 标题、提示和高度预算；不复用 JS 分支 |
| [`HMAAChartModel.defaultScope`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L77) | 需业务确认 | showCategoryRange / bridge NSRange | 旧闭区间→新半开范围；D08 半槽差异不能标成像素等价 |
| [`HMAAChartModel.headerDatas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L80) | 需新增能力 | R5 card layout/presentation state | 外部卡片、强制空态和布局预算；禁止修改调用方模型 D11 |
| [`HMAAChartModel.sunDatas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L83) | 需新增能力 | R5 card layout/presentation state | 外部卡片、强制空态和布局预算；禁止修改调用方模型 D11 |
| [`HMAAChartModel.titleColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L86) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.crosshairColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L87) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.dashColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L88) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.xAxisTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L89) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.yAxisTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L90) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.toolTipBackgroundColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L91) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.toolTipTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L92) | 需新增能力 | R5 appearance preset | 外部动态色解析、图层刷新和禁用暗色预设；不同用途数组独立 |
| [`HMAAChartModel.subYAxis`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L95) | 能力可映射 | primary/secondary axis range / OC model | 副轴仅 0/1；Bar 明确不支持副轴 |
| [`HMAAChartModel.showLegend`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L98) | 能力可映射 | theme.legend.isEnabled / bridge.showsLegend | 容器级开关；空态退出需恢复 |
| [`HMAAChartModel.showNoData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L99) | 需新增能力 | R5 card layout/presentation state | 外部卡片、强制空态和布局预算；禁止修改调用方模型 D11 |
| [`HMAAChartModel.chartHeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L100) | 需新增能力 | R5 card layout/presentation state | 外部卡片、强制空态和布局预算；禁止修改调用方模型 D11 |
| [`HMAAChartModel.showSeriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L103) | 需业务确认 | R2 visibility snapshot | 旧派生缓存不是第二份真实数据源；显隐覆盖优先级待业务约定 |
| [`HMAAYAxis.yAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L109) | 能力可映射 | secondaryYAxis / OC secondaryMinimum/Maximum | 范围可映射；显式范围裁剪属于调用方配置 |
| [`HMAAYAxis.yAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L110) | 能力可映射 | secondaryYAxis / OC secondaryMinimum/Maximum | 范围可映射；显式范围裁剪属于调用方配置 |
| [`HMAAYAxis.yAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L111) | 需新增能力 | R2/R5 axis presentation | 独立轴样式/轴单位标题未完整承接；系列单位不能替代轴标题 |
| [`HMAAYAxis.yAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L112) | 需新增能力 | R2/R5 axis presentation | 独立轴样式/轴单位标题未完整承接；系列单位不能替代轴标题 |
| [`HMAAYAxis.yAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L113) | 需新增能力 | R2/R5 axis presentation | 独立轴样式/轴单位标题未完整承接；系列单位不能替代轴标题 |
| [`HMAAYAxis.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L114) | 需新增能力 | R2/R5 axis presentation | 独立轴样式/轴单位标题未完整承接；系列单位不能替代轴标题 |
| [`HMAAYAxis.yAxisTickPositions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L115) | 需 OC 桥接 | secondaryYAxis.tickPositions | OC 缺入口 |
| [`HMChartHeaderModel.title`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L121) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartHeaderModel.data`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L122) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartHeaderModel.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L123) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartHeaderModel.topMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L124) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartHeaderModel.leftMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L125) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartHeaderModel.rightMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L126) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartSunModel.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L132) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartSunModel.title`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L133) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartSunModel.time`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L134) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartSunModel.initSunriseModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L136) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMChartSunModel.initSunsetModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L138) | 需新增能力 | R5 functional card | 标题/摘要/日出日落布局与资源注入，不能放入渲染核心 |
| [`HMAASeries.gname`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L40) | 能力可映射 | CartesianSeriesGroup.name / HYMCartesianGroup.name | 静态展示组，与 stackID 分离 |
| [`HMAASeries.gnames`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L41) | 需新增能力 | R3 group title provider | 内置分组只有静态名称，逐采样组名缺入口 |
| [`HMAASeries.element`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L42) | 能力可映射 | series filtered by groupID | 按稳定身份展平，保留成员顺序 |
| [`HMAASeries.unitType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L43) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.otherUnit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L44) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.currencySymbol`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L45) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.showFabs`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L46) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.trunc`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L47) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.fractionDigits`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L50) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.fgdata`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L53) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.formatGroupData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L55) | 需新增能力 | R3 group summary formatter | 旧 float 汇总、独立格式/来源规则不同于通用 subtotal，fractionDigits=100 分支需契约测试 |
| [`HMAASeries.onlyNameIntooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L57) | 能力可映射 | tooltip rowStyleProvider | hidesValue 与 title 空串分别映射；text 冒号/来源标签仍须验收 |
| [`HMAASeries.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L60) | 需新增能力 | R3 group legend/header layout | 现有 series 图例不足以直接承接组图标、分标题和组内分栏 |
| [`HMAASeries.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L61) | 需新增能力 | R3 group legend/header layout | 现有 series 图例不足以直接承接组图标、分标题和组内分栏 |
| [`HMAASeries.gcname`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L62) | 需新增能力 | R3 group legend/header layout | 现有 series 图例不足以直接承接组图标、分标题和组内分栏 |
| [`HMAASeries.showElementName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L63) | 能力可映射 | tooltip rowStyleProvider | hidesValue 与 title 空串分别映射；text 冒号/来源标签仍须验收 |
| [`HMAASeries.stackGroupInterval`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L64) | 需新增能力 | R3 group legend/header layout | 现有 series 图例不足以直接承接组图标、分标题和组内分栏 |
| [`HMAASeriesElement.name`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L70) | 能力可映射 | CartesianSeriesElement / HYMCartesianSeries | 缺测保位，非法输入诊断；无稳定 ID 须由 R2 提供 |
| [`HMAASeriesElement.names`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L71) | 能力可映射 | tooltip rowStyleProvider / OC provider | 只过滤或覆盖提示；hidePoints 当前索引政策需在 R3 明确 |
| [`HMAASeriesElement.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L72) | 能力可映射 | CartesianSeriesElement / HYMCartesianSeries | 缺测保位，非法输入诊断；无稳定 ID 须由 R2 提供 |
| [`HMAASeriesElement.data`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L73) | 能力可映射 | CartesianSeriesElement / HYMCartesianSeries | 缺测保位，非法输入诊断；无稳定 ID 须由 R2 提供 |
| [`HMAASeriesElement.unitType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L74) | 能力可映射 | CartesianValueFormat / OC format + unit | 单位进位白名单在兼容层；金额/原值/展示值分离，禁止 showFabs 改写 raw |
| [`HMAASeriesElement.otherUnit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L75) | 能力可映射 | CartesianValueFormat / OC format + unit | 单位进位白名单在兼容层；金额/原值/展示值分离，禁止 showFabs 改写 raw |
| [`HMAASeriesElement.currencySymbol`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L76) | 能力可映射 | CartesianValueFormat / OC format + unit | 单位进位白名单在兼容层；金额/原值/展示值分离，禁止 showFabs 改写 raw |
| [`HMAASeriesElement.showFabs`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L77) | 能力可映射 | CartesianValueFormat / OC format + unit | 单位进位白名单在兼容层；金额/原值/展示值分离，禁止 showFabs 改写 raw |
| [`HMAASeriesElement.trunc`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L78) | 能力可映射 | CartesianValueFormat / OC format + unit | 单位进位白名单在兼容层；金额/原值/展示值分离，禁止 showFabs 改写 raw |
| [`HMAASeriesElement.fractionDigits`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L81) | 需新增能力 | R2/R3 legacy formatting policy | 100 哨兵非普通精度；旧预舍入和 k/M/G 不同位数尚未完整实现 |
| [`HMAASeriesElement.chartType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L84) | 需业务确认 | R2 concrete type stack partition | series.kind/stackID 已有；D06 Highcharts 具体类型分链与 HYM 图形族不同 |
| [`HMAASeriesElement.stackGroup`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L87) | 需业务确认 | R2 concrete type stack partition | series.kind/stackID 已有；D06 Highcharts 具体类型分链与 HYM 图形族不同 |
| [`HMAASeriesElement.fillColorAlphas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L89) | 能力可映射 | series.style.areaGradientColors/fillOpacity / OC style | 兼容层固定旧优先级，避免重复乘 alpha |
| [`HMAASeriesElement.autoGap`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L91) | 能力可映射 | gapPolicy / colorZones / OC wrappers | >=12 空点断开 → maximumMissingPoints=11；修正 D03 分区覆盖 |
| [`HMAASeriesElement.yAxis`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L93) | 能力可映射 | CartesianSeriesElement / HYMCartesianSeries | 缺测保位，非法输入诊断；无稳定 ID 须由 R2 提供 |
| [`HMAASeriesElement.dashStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L95) | 需 OC 桥接 | series.negativeColor/lineDashStyle | Swift 已支持，OC series 尚缺；非法颜色/虚线必须诊断 |
| [`HMAASeriesElement.zones`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L98) | 能力可映射 | gapPolicy / colorZones / OC wrappers | >=12 空点断开 → maximumMissingPoints=11；修正 D03 分区覆盖 |
| [`HMAASeriesElement.zoneAxisX`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L99) | 能力可映射 | gapPolicy / colorZones / OC wrappers | >=12 空点断开 → maximumMissingPoints=11；修正 D03 分区覆盖 |
| [`HMAASeriesElement.hideInTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L102) | 能力可映射 | tooltip rowStyleProvider / OC provider | 只过滤或覆盖提示；hidePoints 当前索引政策需在 R3 明确 |
| [`HMAASeriesElement.fillAlpha`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L103) | 能力可映射 | series.style.areaGradientColors/fillOpacity / OC style | 兼容层固定旧优先级，避免重复乘 alpha |
| [`HMAASeriesElement.fillColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L104) | 能力可映射 | series.style.areaGradientColors/fillOpacity / OC style | 兼容层固定旧优先级，避免重复乘 alpha |
| [`HMAASeriesElement.negativeColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L105) | 需 OC 桥接 | series.negativeColor/lineDashStyle | Swift 已支持，OC series 尚缺；非法颜色/虚线必须诊断 |
| [`HMAASeriesElement.isStep`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L106) | 能力可映射 | series.style.connection/showsPoints / OC style | 确认 stepAfter 方向，markerHidden 取反；D09 拆分丢字段不复刻 |
| [`HMAASeriesElement.markerHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L107) | 能力可映射 | series.style.connection/showsPoints / OC style | 确认 stepAfter 方向，markerHidden 取反；D09 拆分丢字段不复刻 |
| [`HMAASeriesElement.showPrev`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L108) | 能力可映射 | tooltip sampleOffsetsBySeriesID + clamp | 仅提示值 -1，命中身份/表头/行名保持当前采样 |
| [`HMAASeriesElement.formatData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L111) | 需新增能力 | R2/R3 legacy formatting policy | 100 哨兵非普通精度；旧预舍入和 k/M/G 不同位数尚未完整实现 |
| [`HMAASeriesElement.fdata`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L112) | 需新增能力 | R2/R3 legacy formatting policy | 100 哨兵非普通精度；旧预舍入和 k/M/G 不同位数尚未完整实现 |
| [`HMAASeriesElement.hidePoints`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L113) | 能力可映射 | tooltip rowStyleProvider / OC provider | 只过滤或覆盖提示；hidePoints 当前索引政策需在 R3 明确 |
| [`HMAASeriesElement.legendBgColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L117) | 能力可映射 | legend.itemOverrides / OC legendItemStyles | 资源由宿主解析后注入 UIImage；透明度仅计算一次 |
| [`HMAASeriesElement.legendBgColorAlpha`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L118) | 能力可映射 | legend.itemOverrides / OC legendItemStyles | 资源由宿主解析后注入 UIImage；透明度仅计算一次 |
| [`HMAASeriesElement.isHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L119) | 能力可映射 | series.isVisible + setSeriesVisible | 取反；显式模型变化/用户覆盖优先级已有实现，旧模型适配待做 |
| [`HMAASeriesElement.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L122) | 能力可映射 | legend.itemOverrides / OC legendItemStyles | 资源由宿主解析后注入 UIImage；透明度仅计算一次 |
| [`HMAASeriesElement.hideNameInTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L123) | 能力可映射 | tooltip rowStyleProvider / OC provider | 只过滤或覆盖提示；hidePoints 当前索引政策需在 R3 明确 |
| [`HMAASeriesUtil.doubleWithOriginData:showFabs:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L130) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.formatCarryDouble:trunc:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L133) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.formatDouble:trunc:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L136) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.getUnitWithType:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L139) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.jsonSerializsWithArray:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L142) | 不承接原入口 | remove JS serialization boundary | 原生不需要 JS 字符串；调用者如直接使用须迁移，不能静默空实现 |
| [`HMAASeriesUtil.canTranslateToNum:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L145) | 能力可映射 | R2 validated input snapshot | 保留 null 下标，不转 0；轴范围以全部可见 draw/base 重新计算 D12 |
| [`HMAASeriesUtil.needCarryType:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L148) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.formatNullElements:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L151) | 能力可映射 | R2 validated input snapshot | 保留 null 下标，不转 0；轴范围以全部可见 draw/base 重新计算 D12 |
| [`HMAASeriesUtil.rgbaStringFromHex:withAlpha:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L154) | 能力可映射 | R2 color parser → UIColor | 兼容层解析且错误可见，不把 hex/string 传播到核心 |
| [`HMAASeriesUtil.calculateMaxMinValueWithNumberArray:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L157) | 能力可映射 | R2 validated input snapshot | 保留 null 下标，不转 0；轴范围以全部可见 draw/base 重新计算 D12 |
| [`HMAASeriesUtil.formatMoney:withSymbol:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L160) | 需新增能力 | R2/R3 pure compatibility formatter | 旧精度、单位、负零和进位边界；不直接暴露旧工具类到通用 SDK |
| [`HMAASeriesUtil.positiveSplitFromSeriesElement:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L163) | 需业务确认 | R2 sign policy; preserve business series | D09 空值异常/丢字段必须修正；D06 抵消策略需业务选择，辅助 series 不作为业务身份 |
| [`HMAASeriesUtil.negativeSplitFromSeriesElement:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L166) | 需业务确认 | R2 sign policy; preserve business series | D09 空值异常/丢字段必须修正；D06 抵消策略需业务选择，辅助 series 不作为业务身份 |
| [`HMAAPlotLinesElement.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L15) | 需 OC 桥接 | CartesianPlotLine | Swift 已有，OC 需新增包装 |
| [`HMAAPlotLinesElement.dashStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L29) | 需 OC 桥接 | CartesianPlotLine | Swift 已有，OC 需新增包装 |
| [`HMAAPlotLinesElement.width`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L30) | 需 OC 桥接 | CartesianPlotLine | Swift 已有，OC 需新增包装 |
| [`HMAAPlotLinesElement.value`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L31) | 需 OC 桥接 | CartesianPlotLine | Swift 已有，OC 需新增包装 |
| [`HMAAPlotLinesElement.zIndex`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L32) | 需新增能力 | R2 plot-line label/layer options | 当前标签跟随线色、固定层次；不可宣称支持任意标签样式/层级 |
| [`HMAAPlotLinesElement.text`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L33) | 需 OC 桥接 | CartesianPlotLine | Swift 已有，OC 需新增包装 |
| [`HMAAPlotLinesElement.textColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L34) | 需新增能力 | R2 plot-line label/layer options | 当前标签跟随线色、固定层次；不可宣称支持任意标签样式/层级 |
| [`HMAAPlotLinesElement.textDarkColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L35) | 需新增能力 | R2 plot-line label/layer options | 当前标签跟随线色、固定层次；不可宣称支持任意标签样式/层级 |
| [`HMAAPlotLinesElement.fontSize`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L36) | 需新增能力 | R2 plot-line label/layer options | 当前标签跟随线色、固定层次；不可宣称支持任意标签样式/层级 |
| [`HMAAChartManager.series`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L16) | 不承接原入口 | R2 native adapter output | AASeriesElement/AAOptions 引擎类型退出公开边界；直接调用者须迁移 |
| [`HMAAChartManager.initWithChartModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L19) | 需新增能力 | R2 snapshot adapter | 不以缓存转换结果替代后续更新 |
| [`HMAAChartManager.configureAAChartOptions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L22) | 不承接原入口 | R2 native adapter output | AASeriesElement/AAOptions 引擎类型退出公开边界；直接调用者须迁移 |
