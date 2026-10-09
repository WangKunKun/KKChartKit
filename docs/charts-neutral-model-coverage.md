# 通用图表模型覆盖矩阵

审计日期：2026-10-09；`ChartSpecification` schema v6。

> 本文由 `scripts/check_chart_neutral_coverage.py --write` 从逐项审核的 JSON 生成；请先修改 JSON，再生成文档。工具不会自动判定新字段“已支持”。

## 结论与阅读方式

- **197 个旧声明逐项处置**，对应 61 个能力/职责主题；另核对 18 个 G1–G6 / 后端边界主题（与旧字段覆盖有交集，不与 197 相加）。
- “已表达”只指描述语义及 HYMCharts 转换已有，**不表示旧输入 mapper 已交付或旧默认/累计规则完全等价**。真实业务调用仍未提供。
- “外层”细分为业务 UI、运行时命令/事件、兼容解析/格式化与派生缓存，不能都算作 renderer 缺口，也不能都算作已完成。
- “未建模”没有可被适配器检查的字段，**不等于已经返回 unsupportedCapability**。当前 Codable 会忽略额外对象键；mapper 必须在丢失信息前显式诊断，metadata/扩展键不得透传引擎选项。
- G1 三种边界已进入 v2 并由 HYM 显式映射；v1 保留 independent。v3 已接通值轴颜色子集（柱 raw/draw、线/面积 draw），旧 zones 的 X/分区填充仍有缺口。G3 字重/刻度、G4 标注/标签、G5 选中外观已有原生能力，但尚未全部进入通用模型。G6 连续 X/反向轴仍由后端明确拒绝。
- 只审查本清单及列出的原生主题；不是整个 SDK 每个公开参数的穷举，也不是第二后端验证。v2 G1 与 v3 值轴颜色配置已同步现有 Demo 面板；未增加同类型新入口。

| 处置 | 旧声明数 |
| --- | ---: |
| 已表达 | 60 |
| 需新增通用语义 | 26 |
| 外层 UI / 运行时 / 兼容层 | 104 |
| 应报不支持 | 7 |

## 后续实施顺序

1. **共同能力验收**：先选一个实际要用的第二后端；按 ID、原始值、缺测、单位、轴绑定、绝对值分母和错误路径核对，不要求像素一致。未选定前不随意引入依赖。
2. **按场景扩 schema**：G1 边界 v2 与值轴颜色 v3 小切片已接通；后续优先轴展示，再 annotation、tooltip/legend。缺失 schema 字段不能靠 metadata 绕过。
3. **版本策略**：任何扩展先定义旧 v1 读入后的缺省含义、未来版本拒绝及降级错误；G1 v2 和颜色 v3 已落实该规则，旧构造器仍默认 v1；后续扩展继续同步校验、转换、Swift/OC、既有 Demo 与测试。
4. **独立 R2 mapper**：也可在旧页面迁移优先时先做，保持旧字段识别/默认/特殊精度/符号政策在兼容层；未选 D06、D07 等业务政策时不得猜测。
5. **真实工程验收**：R7/R8 需要实际页面、真机、状态恢复、分发/回退约束；本审计不标记完成。

## G1–G6 与后端边界速查

| 主题 | schema 处置 | HYM 原生 | v1/v2/v3 适配器 |
| --- | --- | --- | --- |
| [G1 正负共享边界与统一缺测](#cap-g1-boundary) | 已表达 | 已有 | 已映射 |
| [旧完整 zones（X/Y 与分区填充）](#cap-zones) | 需新增通用语义 | 已有 | 仅部分映射 |
| [N1 值轴颜色子集（柱 raw/draw、线/面积 draw）](#cap-value-color-zones) | 已表达 | 已有 | 已映射 |
| [独立轴颜色、字号与显隐](#cap-axis-basic) | 已表达 | 已有 | 已映射 |
| [轴字体字重](#cap-axis-weight) | 已表达 | 已有 | 已映射 |
| [显式值轴刻度与类目间隔](#cap-ticks) | 已表达 | 已有 | 已映射 |
| [值轴刻度单位/格式](#cap-axis-value-format) | 已表达 | 已有 | 已映射 |
| [标线、色带及文字](#cap-annotations) | 已表达 | 已有 | 已映射 |
| [任意标注层级](#cap-annotation-order) | 应报不支持 | 缺失 | 未建模，尚无对应诊断入口 |
| [数据标签与堆叠总量](#cap-data-labels) | 需新增通用语义 | 已有 | 仅部分映射 |
| [G5 主体选中外观](#cap-selection) | 需新增通用语义 | 已有 | 未建模，尚无对应诊断入口 |
| [G6 连续数值/时间 X](#cap-continuous-domain) | 应报不支持 | 缺失 | 已有显式拒绝 |
| [G6 反向值轴](#cap-reversed-axis) | 应报不支持 | 缺失 | 已有显式拒绝 |
| [轴数与横向图元限制](#cap-backend-limits) | 应报不支持 | 部分/语义有差异 | 已有显式拒绝 |
| [仅次轴网格](#cap-secondary-grid) | 应报不支持 | 部分/语义有差异 | 已有显式拒绝 |
| [提示开关、布局与逐系列内容](#cap-tooltip-basic) | 已表达 | 已有 | 已映射 |
| [提示前值选择](#cap-tooltip-offset) | 已表达 | 已有 | 已映射 |
| [图例布局与稳定系列标题](#cap-legend-layout) | 已表达 | 已有 | 已映射 |

## 逐声明覆盖（按原头文件清单排序）


### HMAAChartUtil

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartUtil.createlgaaChartView`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L17) | 外层 UI / 运行时 / 兼容层 · [业务工厂与主题预设](#cap-host-factory) | 业务工厂组合宿主视图和适配器；不新增同名 SDK facade。 |
| [`HMAAChartUtil.createlgaaChartViewWithFrame:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L18) | 外层 UI / 运行时 / 兼容层 · [业务工厂与主题预设](#cap-host-factory) | 业务工厂组合宿主视图和适配器；不新增同名 SDK facade。 |
| [`HMAAChartUtil.createaaChartView`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L21) | 外层 UI / 运行时 / 兼容层 · [业务工厂与主题预设](#cap-host-factory) | 业务工厂组合宿主视图和适配器；不新增同名 SDK facade。 |
| [`HMAAChartUtil.createaaChartViewWithFrame:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L22) | 外层 UI / 运行时 / 兼容层 · [业务工厂与主题预设](#cap-host-factory) | 业务工厂组合宿主视图和适配器；不新增同名 SDK facade。 |
| [`HMAAChartUtil.namesWithKey:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L25) | 外层 UI / 运行时 / 兼容层 · [业务 key 与符号预处理](#cap-host-business) | D07 名称/符号政策待真实业务调用确认；不按默认堆叠语义改写值。 |
| [`HMAAChartUtil.formatNamesWithData:positive:negative:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L28) | 外层 UI / 运行时 / 兼容层 · [业务 key 与符号预处理](#cap-host-business) | D07 名称/符号政策待真实业务调用确认；不按默认堆叠语义改写值。 |
| [`HMAAChartUtil.keyNeedOpposite`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L31) | 外层 UI / 运行时 / 兼容层 · [业务 key 与符号预处理](#cap-host-business) | D07 名称/符号政策待真实业务调用确认；不按默认堆叠语义改写值。 |
| [`HMAAChartUtil.keyNeedFabsAndOpposite`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L34) | 外层 UI / 运行时 / 兼容层 · [业务 key 与符号预处理](#cap-host-business) | D07 名称/符号政策待真实业务调用确认；不按默认堆叠语义改写值。 |
| [`HMAAChartUtil.fixAIChatData:type:`](../SwiftFunctionProject/参考图表/HMAAChartUtil.h#L37) | 外层 UI / 运行时 / 兼容层 · [业务 key 与符号预处理](#cap-host-business) | D07 名称/符号政策待真实业务调用确认；不按默认堆叠语义改写值。 |

### HMAAChartViewDelegate

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartViewDelegate.hmaaChartView:handlePan:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L16) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 旧 pan 手势对象和新语义事件需单独桥接；非 JSON 字段。 |

### HMAAChartView

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartView.delegate`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L23) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 按稳定 series/sample ID 回传命中；旧索引/生命周期另定契约。 |
| [`HMAAChartView.clickBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L25) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 按稳定 series/sample ID 回传命中；旧索引/生命周期另定契约。 |
| [`HMAAChartView.finishLoad`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L26) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | WebView load 不等于布局/动画/像素完成；R4 需另定回调次数与线程。 |
| [`HMAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L29) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L30) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L31) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L32) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMAAChartView.initChartViewWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L35) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 旧输入先转 ChartSpecification，再由适配配置或 OC 文档创建；不是现成同名入口。 |
| [`HMAAChartView.reloadDataWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L38) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 每次将最新旧输入转换为新快照后更新；旧 mapper 尚未实现。 |
| [`HMAAChartView.onlyRefreshTheChartData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L41) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 每次将最新旧输入转换为新快照后更新；旧 mapper 尚未实现。 |
| [`HMAAChartView.setTouchPointXIndex:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L44) | 外层 UI / 运行时 / 兼容层 · [程序选点与恢复](#cap-runtime-selection) | 待 R4 公共程序选点/清除命令，不能使用测试接口。 |
| [`HMAAChartView.showNoData:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartView.h#L47) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 外部强制空态，退出时恢复图例/显隐且不改调用方模型。 |

### HMLGAAChartViewDelegate

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMLGAAChartViewDelegate.hmlgaaChartView:handlePan:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L15) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 旧 pan 手势对象和新语义事件需单独桥接；非 JSON 字段。 |

### HMLGAAChartView

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMLGAAChartView.delegate`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L21) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 按稳定 series/sample ID 回传命中；旧索引/生命周期另定契约。 |
| [`HMLGAAChartView.clickBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L23) | 外层 UI / 运行时 / 兼容层 · [命中/手势/加载生命周期](#cap-runtime-events) | 按稳定 series/sample ID 回传命中；旧索引/生命周期另定契约。 |
| [`HMLGAAChartView.legendTapBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L24) | 外层 UI / 运行时 / 兼容层 · [图例显隐命令与事件](#cap-runtime-visibility) | 使用 onSeriesVisibilityChanged 的稳定 ID/visible 查回业务对象。 |
| [`HMLGAAChartView.snapClosure`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L25) | 应报不支持 · [旧快照占位入口](#cap-export-placeholder) | 旧占位导出不提供空实现；实际使用须单独立项。 |
| [`HMLGAAChartView.triggerSnap`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L27) | 应报不支持 · [旧快照占位入口](#cap-export-placeholder) | 旧占位导出不提供空实现；实际使用须单独立项。 |
| [`HMLGAAChartView.showEnlargeButton`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L29) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 按钮与全屏控制器由外层宿主实现；保存/恢复状态另验收。 |
| [`HMLGAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L32) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMLGAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L33) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMLGAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L34) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMLGAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L35) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 宿主注入空态资源；不得清空原数据以制造空态。 |
| [`HMLGAAChartView.reloadDataWithModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L38) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 每次将最新旧输入转换为新快照后更新；旧 mapper 尚未实现。 |
| [`HMLGAAChartView.onlyRefreshTheChartData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L41) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 每次将最新旧输入转换为新快照后更新；旧 mapper 尚未实现。 |
| [`HMLGAAChartView.setTouchPointXIndex:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L44) | 外层 UI / 运行时 / 兼容层 · [程序选点与恢复](#cap-runtime-selection) | 待 R4 公共程序选点/清除命令，不能使用测试接口。 |

### HMChartLGSwitch

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMChartLGSwitch.element`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L50) | 外层 UI / 运行时 / 兼容层 · [图例显隐命令与事件](#cap-runtime-visibility) | 外部按钮绑定稳定系列 ID，并使用公开 setSeriesVisible/显隐回调。 |
| [`HMChartLGSwitch.on`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L52) | 外层 UI / 运行时 / 兼容层 · [图例显隐命令与事件](#cap-runtime-visibility) | 外部按钮绑定稳定系列 ID，并使用公开 setSeriesVisible/显隐回调。 |
| [`HMChartLGSwitch.tapSwitchBlock`](../SwiftFunctionProject/参考图表/HMAAChartView/HMLGAAChartView.h#L54) | 外层 UI / 运行时 / 兼容层 · [图例显隐命令与事件](#cap-runtime-visibility) | 外部按钮绑定稳定系列 ID，并使用公开 setSeriesVisible/显隐回调。 |

### HMMTAAChartView

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMMTAAChartView.chartModels`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L15) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 多图布局/更新/联动留宿主；每图独立描述，不能按标签误联动。 |
| [`HMMTAAChartView.width`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L18) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 多图布局/更新/联动留宿主；每图独立描述，不能按标签误联动。 |
| [`HMMTAAChartView.height`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L19) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 多图布局/更新/联动留宿主；每图独立描述，不能按标签误联动。 |
| [`HMMTAAChartView.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L22) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 多图容器外部空态；不属于单图数据模型。 |
| [`HMMTAAChartView.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L23) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 多图容器外部空态；不属于单图数据模型。 |
| [`HMMTAAChartView.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L24) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 多图容器外部空态；不属于单图数据模型。 |
| [`HMMTAAChartView.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L25) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 多图容器外部空态；不属于单图数据模型。 |
| [`HMMTAAChartView.initChartView`](../SwiftFunctionProject/参考图表/HMAAChartView/HMMTAAChartView.h#L28) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 多图布局/更新/联动留宿主；每图独立描述，不能按标签误联动。 |

### HMAAChartFullScreenVC

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartFullScreenVC.chartModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L16) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 全屏宿主持有图表描述及运行时状态；返回恢复不由 schema 单独保证。 |
| [`HMAAChartFullScreenVC.nodImgName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L19) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 全屏宿主注入空态样式，不能影响原值。 |
| [`HMAAChartFullScreenVC.nodText`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L20) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 全屏宿主注入空态样式，不能影响原值。 |
| [`HMAAChartFullScreenVC.nodColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L21) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 全屏宿主注入空态样式，不能影响原值。 |
| [`HMAAChartFullScreenVC.nodFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartFullScreenVC.h#L22) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 全屏宿主注入空态样式，不能影响原值。 |

### HMAAChartModel

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartModel.name`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L36) | 已表达 · [图表标题内容](#cap-title) | v1 图内标题可转 title；旧 version=2 时标题在外部卡片，mapper 须避免内外重复显示。 |
| [`HMAAChartModel.chartType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L37) | 已表达 · [图元、插值及组合](#cap-marks) | areaspline→area+monotone，line→line+linear，column→bar+vertical；系列覆盖优先级需校验。 |
| [`HMAAChartModel.stackType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L38) | 已表达 · [数学堆叠与组键](#cap-stacking) | false→none，normal→sum；percent 仅在接受绝对值总分母契约后映射；不宣称旧净额累计兼容。 |
| [`HMAAChartModel.xAxisArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L39) | 已表达 · [类目身份与标签](#cap-categories) | → domain.categories；保留顺序/重复标签，提供稳定 category ID。 |
| [`HMAAChartModel.xSeriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L40) | 需新增通用语义 · [逐采样提示、动态组名与组级规则](#cap-tooltip) | 独立逐点提示表头；不能拿 category.label 或 metadata 原样塞入后就宣称可展示。 |
| [`HMAAChartModel.seriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L41) | 已表达 · [系列、采样及缺测](#cap-series) | 嵌套成员按稳定组/系列 ID 展平；原始值和 NSNull 位置分别处理。 |
| [`HMAAChartModel.version`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L44) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 旧 v1/v2 是业务布局版本，绝不能映射为 schemaVersion。 |
| [`HMAAChartModel.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L45) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 旧 v2 标题通用单位属于卡片；不是每个系列的数学单位或轴标题。 |
| [`HMAAChartModel.reverse`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L48) | 外层 UI / 运行时 / 兼容层 · [旧绘制反序与三类顺序](#cap-compat-order) | 旧组内绘制反序不等于 isReversed；图例/提示顺序不能随意一起翻转。 |
| [`HMAAChartModel.zoomType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L49) | 外层 UI / 运行时 / 兼容层 · [缩放与初始视口](#cap-runtime-viewport) | 配置宿主缩放轴/是否启用；OC 的 X/Y/XY 完整入口仍需扩展。 |
| [`HMAAChartModel.yAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L50) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | → 主 valueAxes[].maximum；有限数且大于显式 minimum。 |
| [`HMAAChartModel.yAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L51) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | → 主 valueAxes[].minimum；与 maximum 独立自动。 |
| [`HMAAChartModel.yAxisTickPositions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L52) | 已表达 · [显式值轴刻度与类目间隔](#cap-ticks) | v4 valueAxes[].tickPositions 表达显式主轴刻度；有限、严格递增、域外过滤不扩域。 |
| [`HMAAChartModel.titleColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L53) | 需新增通用语义 · [标题排版](#cap-title-style) | 原生 theme 标题样式可配，v1 仅标题内容。 |
| [`HMAAChartModel.titleFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L54) | 需新增通用语义 · [标题排版](#cap-title-style) | 原生 theme 标题样式可配，v1 仅标题内容。 |
| [`HMAAChartModel.titleWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L55) | 需新增通用语义 · [标题排版](#cap-title-style) | 原生 theme 标题样式可配，v1 仅标题内容。 |
| [`HMAAChartModel.yAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L56) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → 主 valueAxes[].appearance.labelColor，颜色解析在 mapper。 |
| [`HMAAChartModel.yAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L57) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → 主 valueAxes[].appearance.labelFontSize，字符串字号先校验。 |
| [`HMAAChartModel.yAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L58) | 已表达 · [轴字体字重](#cap-axis-weight) | v4 labelFontWeight 表达系统字重；R2 仍需解析旧字符串/未知值，不支持自定义字体资源。 |
| [`HMAAChartModel.xAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L59) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → domainAppearance.labelColor，保持与主/次轴独立。 |
| [`HMAAChartModel.xAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L60) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → domainAppearance.labelFontSize，非负有限逻辑点。 |
| [`HMAAChartModel.xAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L61) | 已表达 · [轴字体字重](#cap-axis-weight) | v4 labelFontWeight 表达系统字重；R2 仍需解析旧字符串/未知值，不支持自定义字体资源。 |
| [`HMAAChartModel.xAxisType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L62) | 应报不支持 · [G6 连续数值/时间 X](#cap-continuous-domain) | category 分支可用；number/datetime 的真实连续语义 HYM 目前拒绝；log/未知类型也不能转字符串蒙混。 |
| [`HMAAChartModel.xAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L63) | 需新增通用语义 · [域范围意图](#cap-domain-range) | 无 domain 范围字段；先区分裁剪域与交互视口，真实数值范围等待 G6。 |
| [`HMAAChartModel.xAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L64) | 需新增通用语义 · [域范围意图](#cap-domain-range) | 无 domain 范围字段；先区分裁剪域与交互视口，真实数值范围等待 G6。 |
| [`HMAAChartModel.xAxisTickInterval`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L65) | 已表达 · [显式值轴刻度与类目间隔](#cap-ticks) | v4 categoryLabelInterval 表达正整数类目候选间隔；非值轴间隔，避让不抽样数据。 |
| [`HMAAChartModel.yAxisHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L66) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | 按确认后的旧含义组合 valueAxes[].appearance.showsLabels/showsLine；网格开关独立。 |
| [`HMAAChartModel.leftMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L67) | 需新增通用语义 · [图内边距](#cap-plot-insets) | 图内左边距≠卡片边距；v1 没有该布局配置。 |
| [`HMAAChartModel.crosshairColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L68) | 需新增通用语义 · [准线外观](#cap-crosshair-style) | Swift 原生准线色可配；schema 未建模，不透传 UIColor。 |
| [`HMAAChartModel.dashColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L69) | 需新增通用语义 · [网格颜色与样式](#cap-grid-style) | 旧实际同时设 X 轴线色和 Y 网格色；v1 仅轴线颜色可表达，网格颜色未建模，不能只映射一处后标作全支持。 |
| [`HMAAChartModel.toolTipBackgroundColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L70) | 需新增通用语义 · [提示颜色主题](#cap-tooltip-style) | 原生 Swift 主题可配；通用描述及 OC 完整提示主题尚未覆盖。 |
| [`HMAAChartModel.toolTipTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L71) | 需新增通用语义 · [提示颜色主题](#cap-tooltip-style) | 原生 Swift 主题可配；通用描述及 OC 完整提示主题尚未覆盖。 |
| [`HMAAChartModel.closeDarkStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L72) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.tooltipPinToTop`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L73) | 已表达 · [提示开关、布局与逐系列内容](#cap-tooltip-basic) | v6 position=fixedTop；只固定位置，不锁定选择，不承诺旧超时/抬手行为。 |
| [`HMAAChartModel.tooltipDisable`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L74) | 已表达 · [提示开关、布局与逐系列内容](#cap-tooltip-basic) | v6 isEnabled 取反；不通过隐藏系列模拟，回调命中不受影响。 |
| [`HMAAChartModel.yAxisPlotLines`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L75) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 plotLines 通过稳定 valueAxisID 绑定值轴；旧输入 mapper 未交付。 |
| [`HMAAChartModel.nativeTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L76) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 旧 Web/native 实现选择不成为新数据字段；目标使用原生提示，旧卡片布局单独兼容。 |
| [`HMAAChartModel.defaultScope`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L77) | 外层 UI / 运行时 / 兼容层 · [缩放与初始视口](#cap-runtime-viewport) | 旧闭区间→showCategoryRange 半开范围；保持采样数据不截断，明确半槽差异。 |
| [`HMAAChartModel.headerDatas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L80) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 外部统计/日出日落 view model；图表内部标签/Tooltip 内容不由这组字段冒充。 |
| [`HMAAChartModel.sunDatas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L83) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 外部统计/日出日落 view model；图表内部标签/Tooltip 内容不由这组字段冒充。 |
| [`HMAAChartModel.titleColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L86) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.crosshairColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L87) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.dashColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L88) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.xAxisTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L89) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.yAxisTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L90) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.toolTipBackgroundColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L91) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.toolTipTextColorArr`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L92) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主按用途解析深浅色后更新；对应 schema 外观字段缺口仍单独处理，不因解析颜色而算已覆盖。 |
| [`HMAAChartModel.subYAxis`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L95) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | 创建第二个稳定值轴，系列通过 valueAxisID 绑定；水平 bar 明确拒绝。 |
| [`HMAAChartModel.showLegend`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L98) | 已表达 · [图例和系列显隐](#cap-legend-visible) | → showsLegend；从空态恢复时不能遗留隐藏状态。 |
| [`HMAAChartModel.showNoData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L99) | 外层 UI / 运行时 / 兼容层 · [空态资源与强制空态](#cap-host-empty) | 外层强制空态状态，不能把数据转全零/全缺测。 |
| [`HMAAChartModel.chartHeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L100) | 外层 UI / 运行时 / 兼容层 · [全屏、多图和尺寸容器](#cap-host-container) | 由宿主 UIView/SwiftUI 布局给高度，不写进数学描述。 |
| [`HMAAChartModel.showSeriesArray`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L103) | 外层 UI / 运行时 / 兼容层 · [旧格式化和可见系列缓存](#cap-derived-cache) | 从源系列及显隐状态派生；不能当成新的权威输入。 |

### HMAAYAxis

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAYAxis.yAxisMax`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L109) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | → 次值轴 maximum；不隐式扩大显式范围。 |
| [`HMAAYAxis.yAxisMin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L110) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | → 次值轴 minimum；bar 适配时拒绝副轴。 |
| [`HMAAYAxis.yAxisTextColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L111) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → 次 valueAxes[].appearance.labelColor 的合理意图；旧代码误取主轴色去设 lineColor，不应把这个错误当标签色兼容政策。 |
| [`HMAAYAxis.yAxisTextFont`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L112) | 已表达 · [独立轴颜色、字号与显隐](#cap-axis-basic) | → 次 valueAxes[].appearance.labelFontSize。 |
| [`HMAAYAxis.yAxisTextWeight`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L113) | 已表达 · [轴字体字重](#cap-axis-weight) | v4 labelFontWeight 表达系统字重；R2 仍需解析旧字符串/未知值，不支持自定义字体资源。 |
| [`HMAAYAxis.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L114) | 已表达 · [值轴刻度单位/格式](#cap-axis-value-format) | v4 valueAxes[].labelFormat.unit 表达刻度单位后缀；不是系列单位或轴标题，不承诺旧格式空白/业务换算逐字兼容。 |
| [`HMAAYAxis.yAxisTickPositions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L115) | 已表达 · [显式值轴刻度与类目间隔](#cap-ticks) | v4 按轴 ID 提供独立刻度；R2 不应复制旧次轴分支读取主轴数组的错误。 |

### HMChartHeaderModel

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMChartHeaderModel.title`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L121) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |
| [`HMChartHeaderModel.data`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L122) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |
| [`HMChartHeaderModel.unit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L123) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |
| [`HMChartHeaderModel.topMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L124) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |
| [`HMChartHeaderModel.leftMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L125) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |
| [`HMChartHeaderModel.rightMargin`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L126) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 统计卡片内容/布局在外部 view model；不加入 chart.series。 |

### HMChartSunModel

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMChartSunModel.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L132) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 日出日落资源/时间文字/预设在业务卡片；不自动变成时间坐标采样。 |
| [`HMChartSunModel.title`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L133) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 日出日落资源/时间文字/预设在业务卡片；不自动变成时间坐标采样。 |
| [`HMChartSunModel.time`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L134) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 日出日落资源/时间文字/预设在业务卡片；不自动变成时间坐标采样。 |
| [`HMChartSunModel.initSunriseModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L136) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 日出日落资源/时间文字/预设在业务卡片；不自动变成时间坐标采样。 |
| [`HMChartSunModel.initSunsetModel`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartModel.h#L138) | 外层 UI / 运行时 / 兼容层 · [统计表头、日出日落与版本卡片](#cap-host-card) | 日出日落资源/时间文字/预设在业务卡片；不自动变成时间坐标采样。 |

### HMAASeries

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAASeries.gname`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L40) | 已表达 · [业务展示分组](#cap-groups) | → groups[].name；组名可重复但 ID 不能重复。 |
| [`HMAASeries.gnames`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L41) | 需新增通用语义 · [逐采样提示、动态组名与组级规则](#cap-tooltip) | 逐采样组标题未建模，现原生静态业务组不能自动替代。 |
| [`HMAASeries.element`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L42) | 已表达 · [业务展示分组](#cap-groups) | 按 groupID 关联展平后的 series；保留稳定 ID 和成员顺序。 |
| [`HMAASeries.unitType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L43) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.otherUnit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L44) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.currencySymbol`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L45) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.showFabs`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L46) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.trunc`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L47) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.fractionDigits`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L50) | 需新增通用语义 · [分组小计格式与来源](#cap-group-summary) | 旧组小计有独立格式；现 ChartGroupSpecification 无格式，不能偷用系列 valuePresentation。 |
| [`HMAASeries.fgdata`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L53) | 外层 UI / 运行时 / 兼容层 · [旧格式化和可见系列缓存](#cap-derived-cache) | 旧组格式化派生结果由兼容展示层重新计算，不写入 ChartGroupSpecification。 |
| [`HMAASeries.formatGroupData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L55) | 外层 UI / 运行时 / 兼容层 · [旧格式化和可见系列缓存](#cap-derived-cache) | 旧组格式化派生结果由兼容展示层重新计算，不写入 ChartGroupSpecification。 |
| [`HMAASeries.onlyNameIntooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L57) | 需新增通用语义 · [逐采样提示、动态组名与组级规则](#cap-tooltip) | 需组级隐藏数值规则；逐系列 row provider 不等于已兼容整组。 |
| [`HMAASeries.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L60) | 外层 UI / 运行时 / 兼容层 · [旧分组卡片式图例](#cap-group-legend) | 旧 v2 分组图例卡片/分栏/间距；外部组合，不把显示组误作 stackID。 |
| [`HMAASeries.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L61) | 外层 UI / 运行时 / 兼容层 · [旧分组卡片式图例](#cap-group-legend) | 旧 v2 分组图例卡片/分栏/间距；外部组合，不把显示组误作 stackID。 |
| [`HMAASeries.gcname`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L62) | 外层 UI / 运行时 / 兼容层 · [旧分组卡片式图例](#cap-group-legend) | 旧 v2 分组图例卡片/分栏/间距；外部组合，不把显示组误作 stackID。 |
| [`HMAASeries.showElementName`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L63) | 外层 UI / 运行时 / 兼容层 · [旧分组卡片式图例](#cap-group-legend) | 旧 v2 分组图例卡片/分栏/间距；外部组合，不把显示组误作 stackID。 |
| [`HMAASeries.stackGroupInterval`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L64) | 外层 UI / 运行时 / 兼容层 · [旧分组卡片式图例](#cap-group-legend) | 旧 v2 分组图例卡片/分栏/间距；外部组合，不把显示组误作 stackID。 |

### HMAASeriesElement

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAASeriesElement.name`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L70) | 已表达 · [系列、采样及缺测](#cap-series) | → series[].name；不把显示名称当 ID。 |
| [`HMAASeriesElement.names`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L71) | 需新增通用语义 · [逐采样提示、动态组名与组级规则](#cap-tooltip) | 逐采样提示行名需声明式覆盖；不能直接改系列 name。 |
| [`HMAASeriesElement.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L72) | 已表达 · [系列颜色及负值颜色](#cap-color) | → appearance.color；空值继承明确政策，非法 hex 报错。 |
| [`HMAASeriesElement.data`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L73) | 已表达 · [系列、采样及缺测](#cap-series) | → samples[].value；NSNull→nil 保位，零/负数不改，坐标与样本 ID 单独保留。 |
| [`HMAASeriesElement.unitType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L74) | 已表达 · [系列单位与显示进位](#cap-units) | 白名单解析为 unit + scale/currencySymbol；未知枚举诊断。 |
| [`HMAASeriesElement.otherUnit`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L75) | 已表达 · [系列单位与显示进位](#cap-units) | → unit；只在确认旧 OTHER 分支时采用。 |
| [`HMAASeriesElement.currencySymbol`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L76) | 已表达 · [系列单位与显示进位](#cap-units) | → valuePresentation.currencySymbol；不要放入数学单位。 |
| [`HMAASeriesElement.showFabs`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L77) | 已表达 · [绝对值展示与截断](#cap-number-presentation) | → valuePresentation.showsAbsoluteValue，仅展示 abs。 |
| [`HMAASeriesElement.trunc`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L78) | 已表达 · [绝对值展示与截断](#cap-number-presentation) | → rounding.towardZero/nearest；原始 value 不预舍入。 |
| [`HMAASeriesElement.fractionDigits`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L81) | 外层 UI / 运行时 / 兼容层 · [旧精度哨兵与预舍入](#cap-precision-compatibility) | 普通 0...12 可转 maximumFractionDigits；100 必须独立兼容政策，不钳制为12。 |
| [`HMAASeriesElement.chartType`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L84) | 已表达 · [图元、插值及组合](#cap-marks) | 显式 line/spline/area/areaspline/column 白名单→mark+interpolation；未知字符串拒绝。 |
| [`HMAASeriesElement.stackGroup`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L87) | 已表达 · [数学堆叠与组键](#cap-stacking) | → stackID；必须保留旧未设置时的默认堆叠取舍，不能把所有 nil 自动作一组。 |
| [`HMAASeriesElement.fillColorAlphas`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L89) | 已表达 · [面积纯色或纵向渐变](#cap-area-fill) | 先合成单个 ChartAreaFill；明确三者优先级与透明度一次计算，非 area 使用须报错。 |
| [`HMAASeriesElement.autoGap`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L91) | 已表达 · [系列缺测连接](#cap-gap-policy) | 按实际 >=12 空点断段映射 connectUpTo(11)；false 的旧默认另定，不擅自 connect。 |
| [`HMAASeriesElement.yAxis`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L93) | 已表达 · [值轴绑定与上下界](#cap-axis-range) | 旧 0/1→稳定 valueAxisID；未知下标拒绝，不静默回主轴。 |
| [`HMAASeriesElement.dashStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L95) | 已表达 · [线条与点标记](#cap-stroke-marker) | 仅可明确映射 solid/dashed/dotted；其他旧 dash 值必须诊断或扩展语义。 |
| [`HMAASeriesElement.zones`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L98) | 需新增通用语义 · [旧完整 zones（X/Y 与分区填充）](#cap-zones) | v3 可表达值轴颜色子集；旧 X 分区/分区填充与原值取色必须先判别，不可整字段静默截断后算已覆盖。 |
| [`HMAASeriesElement.zoneAxisX`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L99) | 需新增通用语义 · [旧完整 zones（X/Y 与分区填充）](#cap-zones) | v3 valueColorZones 仅值轴；旧 true 对应类目原始索引，仍未建模，不能借 metadata 透传或当成连续 X。 |
| [`HMAASeriesElement.hideInTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L102) | 已表达 · [提示开关、布局与逐系列内容](#cap-tooltip-basic) | v6 seriesRules[id].isHidden 只过滤提示行，不改变图形或百分比分母。 |
| [`HMAASeriesElement.fillAlpha`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L103) | 已表达 · [面积纯色或纵向渐变](#cap-area-fill) | 先合成单个 ChartAreaFill；明确三者优先级与透明度一次计算，非 area 使用须报错。 |
| [`HMAASeriesElement.fillColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L104) | 已表达 · [面积纯色或纵向渐变](#cap-area-fill) | 先合成单个 ChartAreaFill；明确三者优先级与透明度一次计算，非 area 使用须报错。 |
| [`HMAASeriesElement.negativeColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L105) | 已表达 · [系列颜色及负值颜色](#cap-color) | → appearance.negativeColor；不得 abs 原始数据。 |
| [`HMAASeriesElement.isStep`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L106) | 已表达 · [图元、插值及组合](#cap-marks) | 确认旧方向后设 stepAfter；与 series.chartType 的优先级必须显式。 |
| [`HMAASeriesElement.markerHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L107) | 已表达 · [线条与点标记](#cap-stroke-marker) | true→appearance.marker.none；false 恢复明确 marker/引擎默认，不影响原始样本。 |
| [`HMAASeriesElement.showPrev`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L108) | 已表达 · [提示前值选择](#cap-tooltip-offset) | 仅提示取值偏移 -1 + clamp；命中 ID、当前表头/名字保留，不整体平移数据。 |
| [`HMAASeriesElement.formatData`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L111) | 外层 UI / 运行时 / 兼容层 · [旧格式化和可见系列缓存](#cap-derived-cache) | 旧格式化缓存归兼容展示层；源 raw 值不能替换为格式字符串。 |
| [`HMAASeriesElement.fdata`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L112) | 外层 UI / 运行时 / 兼容层 · [旧格式化和可见系列缓存](#cap-derived-cache) | 旧格式化缓存归兼容展示层；源 raw 值不能替换为格式字符串。 |
| [`HMAASeriesElement.hidePoints`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L113) | 需新增通用语义 · [逐采样提示、动态组名与组级规则](#cap-tooltip) | 按当前命中采样身份过滤提示；与 showPrev 的取值索引必须区分。 |
| [`HMAASeriesElement.legendBgColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L117) | 需新增通用语义 · [逐系列图例符号/背景](#cap-legend-style) | 原生逐项图例外观/图片已有；v1 无图例外观资源协议，alpha 只算一次。 |
| [`HMAASeriesElement.legendBgColorAlpha`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L118) | 需新增通用语义 · [逐系列图例符号/背景](#cap-legend-style) | 原生逐项图例外观/图片已有；v1 无图例外观资源协议，alpha 只算一次。 |
| [`HMAASeriesElement.isHidden`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L119) | 已表达 · [图例和系列显隐](#cap-legend-visible) | 取反→isVisible；不改变 showsInLegend，不删掉业务系列。 |
| [`HMAASeriesElement.icon`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L122) | 需新增通用语义 · [逐系列图例符号/背景](#cap-legend-style) | 原生逐项图例外观/图片已有；v1 无图例外观资源协议，alpha 只算一次。 |
| [`HMAASeriesElement.hideNameInTooltip`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L123) | 已表达 · [提示开关、布局与逐系列内容](#cap-tooltip-basic) | v6 seriesRules[id].title 设空字符串；仅隐藏系列名，不改图例名/来源说明。 |

### HMAASeriesUtil

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAASeriesUtil.doubleWithOriginData:showFabs:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L130) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.formatCarryDouble:trunc:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L133) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.formatDouble:trunc:fractionDigits:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L136) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.getUnitWithType:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L139) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.jsonSerializsWithArray:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L142) | 应报不支持 · [JS/AAOptions 引擎产物](#cap-vendor-output) | 原生无 JS 字符串边界；ChartSpecification.jsonData 是版本化描述，不是同一返回协议。 |
| [`HMAASeriesUtil.canTranslateToNum:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L145) | 外层 UI / 运行时 / 兼容层 · [旧输入校验与转换工具](#cap-compat-input) | R2 输入类型校验，非法字符串报错，不把失败转换为0。 |
| [`HMAASeriesUtil.needCarryType:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L148) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.formatNullElements:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L151) | 外层 UI / 运行时 / 兼容层 · [旧输入校验与转换工具](#cap-compat-input) | 缺测保留采样位置；展示占位与 raw nil 分离。 |
| [`HMAASeriesUtil.rgbaStringFromHex:withAlpha:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L154) | 外层 UI / 运行时 / 兼容层 · [旧输入校验与转换工具](#cap-compat-input) | 解析为 ChartRGBA，不生成 JS rgba 字符串；色值/alpha 校验且只合成一次。 |
| [`HMAASeriesUtil.calculateMaxMinValueWithNumberArray:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L157) | 外层 UI / 运行时 / 兼容层 · [旧输入校验与转换工具](#cap-compat-input) | 重算全部可见 draw/base 的范围；显式值轴上下界优先，不复制旧首数组缓存。 |
| [`HMAASeriesUtil.formatMoney:withSymbol:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L160) | 外层 UI / 运行时 / 兼容层 · [旧单位/金额/舍入工具](#cap-compat-format) | 旧格式化工具不进入 SDK 同名公共边界；单位白名单、预舍入/负零/哨兵按独立兼容政策验收。 |
| [`HMAASeriesUtil.positiveSplitFromSeriesElement:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L163) | 外层 UI / 运行时 / 兼容层 · [旧正负虚拟系列拆分](#cap-compat-sign-split) | 保留一个业务系列及原始符号；内部几何分链不产生新的业务 ID，缺测和字段不能丢失。 |
| [`HMAASeriesUtil.negativeSplitFromSeriesElement:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L166) | 外层 UI / 运行时 / 兼容层 · [旧正负虚拟系列拆分](#cap-compat-sign-split) | 保留一个业务系列及原始符号；内部几何分链不产生新的业务 ID，缺测和字段不能丢失。 |

### HMAAPlotLinesElement

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAPlotLinesElement.color`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L15) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 plotLines[].color 为 sRGB RGBA；nil 保留后端默认。 |
| [`HMAAPlotLinesElement.dashStyle`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L29) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 strokePattern 为 solid/dashed/dotted；旧转换未消费此声明，不继承静默忽略，其他旧枚举仍需 mapper 明确拒绝。 |
| [`HMAAPlotLinesElement.width`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L30) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 lineWidth 为非负有限逻辑点。 |
| [`HMAAPlotLinesElement.value`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L31) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 value 与稳定 valueAxisID 共同定义；不是类目下标，百分比用逻辑百分数。 |
| [`HMAAPlotLinesElement.zIndex`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L32) | 应报不支持 · [任意标注层级](#cap-annotation-order) | 旧声明未被消费（实现写死3），不是既有可回归层级能力；新后端无任意层级契约，未来 mapper 应报差异。 |
| [`HMAAPlotLinesElement.text`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L33) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 label 内容；nil/空字符串不画标签，不自动追加单位。 |
| [`HMAAPlotLinesElement.textColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L34) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 labelStyle.color，与标线颜色独立；nil 继承标注色。 |
| [`HMAAPlotLinesElement.textDarkColor`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L35) | 外层 UI / 运行时 / 兼容层 · [暗色资源与外观解析](#cap-host-appearance) | 宿主选择当前外观颜色后输入 v5 labelStyle.color；主题自动切换仍为外层职责。 |
| [`HMAAPlotLinesElement.fontSize`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAPlotLinesElement.h#L36) | 已表达 · [标线、色带及文字](#cap-annotations) | v5 labelStyle.fontSize 为正有限逻辑点，系统字体九种字重，不含任意字体资源。 |

### HMAAChartManager

| 旧声明 | 处置 / 能力 | 转换规则与边界 |
| --- | --- | --- |
| [`HMAAChartManager.series`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L16) | 应报不支持 · [JS/AAOptions 引擎产物](#cap-vendor-output) | AASeriesElement 引擎输出退出公共输入边界；消费者迁移到中立输入/后端配置。 |
| [`HMAAChartManager.initWithChartModel:`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L19) | 外层 UI / 运行时 / 兼容层 · [配置、刷新与不可变文档](#cap-runtime-create) | 创建旧→中立快照转换器属于 R2；后续更新必须重新读取原模型，不能永远缓存第一次结果。 |
| [`HMAAChartManager.configureAAChartOptions`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.h#L22) | 应报不支持 · [JS/AAOptions 引擎产物](#cap-vendor-output) | AAOptions 不在通用模型中保留；不借 metadata/额外 JSON 键透传。 |

## 能力判定详情

<a id="cap-title"></a>
### 图表标题内容

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.title`
- **判定**：标题内容可表达；标题颜色、字号、字重另列。
- **后续动作**：R2 将 name 转为 title；不把卡片版本或通用单位拼接规则固化到核心。
- **源码/契约入口**：[schema](#evidence-schema) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [identity-test](#evidence-identity-test) · [legacy-title](#evidence-legacy-title)

<a id="cap-marks"></a>
### 图元、插值及组合

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesSpecification.mark`、`ChartSeriesSpecification.interpolation`、`ChartSpecification.orientation`
- **判定**：line/area/bar 与五种连线插值可表达；横向只允许 bar，混合系列由适配器选择 renderer。
- **后续动作**：R2 建立显式类型白名单与图表/系列覆盖优先级；未知类型拒绝，不能回退 line。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [style-test](#evidence-style-test) · [reject-test](#evidence-reject-test)

<a id="cap-stacking"></a>
### 数学堆叠与组键

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.stacking`、`ChartSeriesSpecification.stackID`、`ChartSeriesSpecification.valueAxisID`
- **判定**：正负分开累计；自动百分比分母为同组可见贡献绝对值总和；业务 groupID 不参与数学组键。
- **后续动作**：R2 明确 D06 旧面积净额/具体类型分链与新图形族的取舍，不能声称默认百分比或旧累计等价。G1 插值边界另列。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [percent-test](#evidence-percent-test)

<a id="cap-categories"></a>
### 类目身份与标签

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.domain`、`ChartCategory.id`、`ChartCategory.label`
- **判定**：标签可重复，category ID 唯一，类目按给定顺序展示；标签不能冒充稳定业务 key。
- **后续动作**：R2 从真实采样键生成身份；无键需外部身份策略，不能按本次数组排序或名称随意改 ID。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [sparse-test](#evidence-sparse-test)

<a id="cap-series"></a>
### 系列、采样及缺测

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.series`、`ChartSeriesSpecification.id`、`ChartSeriesSpecification.samples`、`ChartSample.value`
- **判定**：稀疏样本按 category ID 对齐；nil 是缺测；原始符号与数值保留，显式零不是缺测。
- **后续动作**：R2 校验输入类型并保留位置/身份；不直接接受 NSNumber/string 混杂数组或旧派生缓存。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [identity-test](#evidence-identity-test) · [sparse-test](#evidence-sparse-test)

<a id="cap-groups"></a>
### 业务展示分组

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.groups`、`ChartGroupSpecification.name`、`ChartSeriesSpecification.groupID`
- **判定**：静态组名与成员关系可表达，嵌套旧数组需要展平；不自动开启分组 Tooltip 或组小计。
- **后续动作**：R2 保留稳定组/系列 ID 和成员顺序；逐采样组名、组卡片另列。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [identity-test](#evidence-identity-test)

<a id="cap-axis-range"></a>
### 值轴绑定与上下界

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.valueAxes`、`ChartAxisSpecification.minimum`、`ChartAxisSpecification.maximum`、`ChartSeriesSpecification.valueAxisID`
- **判定**：值轴上下界独立自动或显式；纵向最多两轴，横向 bar 一轴；series 以 ID 绑定。
- **后续动作**：R2 将旧 0/1 轴下标绑定明确 ID；超过后端轴数报告错误，不丢弃副轴。
- **源码/契约入口**：[axis-schema](#evidence-axis-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [axis-test](#evidence-axis-test) · [reject-test](#evidence-reject-test)

<a id="cap-axis-basic"></a>
### 独立轴颜色、字号与显隐

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.domainAppearance`、`ChartAxisSpecification.appearance`、`ChartAxisAppearance.labelColor`、`ChartAxisAppearance.labelFontSize`、`ChartAxisAppearance.showsLabels`、`ChartAxisAppearance.showsLine`、`ChartAxisAppearance.showsGridlines`
- **判定**：G3 独立轴颜色、字号和轴线/标签/网格开关已映射；v4 另以 axis-weight / ticks / axis-value-format 主题承接系统字重、显式刻度、类目间隔和数字/后缀格式。
- **后续动作**：R2 解析颜色/字号并明确旧隐藏是否包含网格；不可仅把标签透明视为完整隐藏。
- **源码/契约入口**：[schema](#evidence-schema) · [axis-schema](#evidence-axis-schema) · [appearance](#evidence-appearance) · [adapter](#evidence-adapter) · [axis-native](#evidence-axis-native) · [style-test](#evidence-style-test) · [grid-test](#evidence-grid-test) · [legacy-secondary-color](#evidence-legacy-secondary-color)

<a id="cap-legend-visible"></a>
### 图例和系列显隐

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.showsLegend`、`ChartSeriesSpecification.isVisible`、`ChartSeriesSpecification.showsInLegend`
- **判定**：图例总开关、系列初始显隐、图例成员资格可表达；用户交互后的覆盖是运行时状态。
- **后续动作**：R2 对 isHidden 取反，明确数据更新与用户显隐覆盖优先级；不持久化 showSeriesArray。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [adapter](#evidence-adapter) · [visibility-native](#evidence-visibility-native) · [identity-test](#evidence-identity-test) · [visibility-test](#evidence-visibility-test)

<a id="cap-color"></a>
### 系列颜色及负值颜色

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesAppearance.color`、`ChartSeriesAppearance.negativeColor`
- **判定**：固定 sRGB RGBA 可表达；动态资源、暗色配对、zones 优先级不由这两个字段代替。
- **后续动作**：R2 一次解析 hex/alpha，非法输入报错；保留原值符号，负色不是改值。
- **源码/契约入口**：[appearance](#evidence-appearance) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [style-test](#evidence-style-test)

<a id="cap-units"></a>
### 系列单位与显示进位

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesSpecification.unit`、`ChartValuePresentation.scale`、`ChartValuePresentation.currencySymbol`
- **判定**：单位字符串、货币符号与 none/engineering 展示缩放可表达；不会自动识别旧 unitType 白名单。
- **后续动作**：R2 显式维护旧枚举→单位/进位规则；自定义单位、金额和数学单位不能混淆。
- **源码/契约入口**：[data](#evidence-data) · [format-schema](#evidence-format-schema) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [identity-test](#evidence-identity-test)

<a id="cap-number-presentation"></a>
### 绝对值展示与截断

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartValuePresentation.showsAbsoluteValue`、`ChartValuePresentation.rounding`
- **判定**：只改变显示，不重写业务原值；nearest/towardZero 的旧边界取舍仍需共享样本验证。
- **后续动作**：R2 禁止先 abs/预舍入数据再传 renderer；负零、进位边界进入格式契约测试。
- **源码/契约入口**：[format-schema](#evidence-format-schema) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [identity-test](#evidence-identity-test)

<a id="cap-area-fill"></a>
### 面积纯色或纵向渐变

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesAppearance.areaFill`、`ChartAreaFill`
- **判定**：纯色/屏幕自上而下两端渐变可表达，alpha 一次合成；非 area 图元设置填充会校验失败。
- **后续动作**：R2 明确旧 fillColorAlphas 非空时只取首尾（单值重复），否则走 fillColor/fillAlpha 的优先级；不是任意多色标渐变，alpha 不重复乘。
- **源码/契约入口**：[appearance](#evidence-appearance) · [validation](#evidence-validation) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [style-test](#evidence-style-test) · [legacy-fill](#evidence-legacy-fill)

<a id="cap-gap-policy"></a>
### 系列缺测连接

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesSpecification.missingValues`、`ChartMissingValuePolicy`
- **判定**：断开、全部连接、最多 N 个缺失类目可表达；不补原值。G1 同组统一断段是另一能力。
- **后续动作**：R2 按旧实际实现 >=12 空点断开映射 connectUpTo(11)，不要仅信旧头注释“不超过12”。
- **源码/契约入口**：[data](#evidence-data) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [style-test](#evidence-style-test) · [legacy-gap](#evidence-legacy-gap)

<a id="cap-stroke-marker"></a>
### 线条与点标记

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesAppearance.strokePattern`、`ChartSeriesAppearance.marker`、`ChartSeriesAppearance.lineWidth`、`ChartSeriesAppearance.markerRadius`
- **判定**：solid/dashed/dotted 和基础 marker 可表达；不承诺匹配 Highcharts 全部虚线节奏或图片点。bar 的连线/点样式由适配器拒绝。
- **后续动作**：R2 做虚线白名单，旧未知值报错；markerHidden 取反后配置 .none 或明确图形。
- **源码/契约入口**：[appearance](#evidence-appearance) · [adapter](#evidence-adapter) · [native-model](#evidence-native-model) · [style-test](#evidence-style-test) · [reject-test](#evidence-reject-test)

<a id="cap-title-style"></a>
### 标题排版

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：原生 theme 有标题 UIColor/UIFont；v1–v4 仅含 title 文本，无中立标题外观字段。
- **后续动作**：按实际页面新增文字外观语义并处理字体资源，不直接复制字符串 titleFont/titleWeight。
- **源码/契约入口**：[theme-native](#evidence-theme-native) · [neutral-guide](#evidence-neutral-guide)

<a id="cap-axis-weight"></a>
### 轴字体字重

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartAxisAppearance.labelFontWeight`、`ChartFontWeight`
- **判定**：schema v4 支持九种系统字重，域轴、主/次值轴独立映射 UIFont；仅字重继承原生默认字号，仅字号保持 regular。自定义字体资源/任意名称不在此契约。
- **后续动作**：R2 解析旧字符串并校验别名/未知值；不能将未知名称静默当 regular。本项已表达不代表 mapper 或自定义字体加载已完成。
- **源码/契约入口**：[appearance](#evidence-appearance) · [axis-native](#evidence-axis-native) · [axes-test](#evidence-axes-test) · [axis-presentation-schema](#evidence-axis-presentation-schema) · [axis-presentation-test](#evidence-axis-presentation-test) · [axis-version-test](#evidence-axis-version-test) · [adapter](#evidence-adapter)

<a id="cap-ticks"></a>
### 显式值轴刻度与类目间隔

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartAxisSpecification.tickPositions`、`ChartSpecification.categoryLabelInterval`
- **判定**：schema v4 承接有限严格递增的值轴刻度列表（[] 明确隐藏、nil 自动、域外过滤不扩域）与正整数绝对类目候选间隔；窄屏可按整数倍避让，不抽样数据。不包含值轴 tickInterval/tickCount 或类目旋转。
- **后续动作**：R2 区分旧 xAxisTickInterval 的类目语义与值轴单位；主/次刻度按轴 ID 分别映射，不复制旧分支读取主轴数组的错误。
- **源码/契约入口**：[ticks-native](#evidence-ticks-native) · [native-model](#evidence-native-model) · [cadence-test](#evidence-cadence-test) · [legacy-secondary-ticks](#evidence-legacy-secondary-ticks) · [axis-presentation-schema](#evidence-axis-presentation-schema) · [axis-presentation-test](#evidence-axis-presentation-test) · [axis-version-test](#evidence-axis-version-test) · [adapter](#evidence-adapter)

<a id="cap-domain-range"></a>
### 域范围意图

- **处置**：需新增通用语义。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：v1–v4 没有 domain minimum/maximum；原生类目窗口与真实数值 X 范围不是同一能力。
- **后续动作**：先区分裁剪域、初始视口与缺数据补域；类目窗口走运行时 showCategoryRange，真实数值域等待 G6。
- **源码/契约入口**：[viewport-native](#evidence-viewport-native) · [native-model](#evidence-native-model) · [neutral-guide](#evidence-neutral-guide)

<a id="cap-axis-value-format"></a>
### 值轴刻度单位/格式

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartAxisSpecification.labelFormat`、`ChartAxisLabelFormat`、`ChartValuePresentation`
- **判定**：旧 HMAAYAxis.unit 是刻度 {value} 后缀，非轴标题。schema v4 提供独立 number + unit 标签格式；HYM 编译为 labelFormatter，后缀前加空格，工程缩写前缀置于单位前。不换算数据、不推断系列单位；locale 可显式指定。
- **后续动作**：R2 接入旧 unit 并确认空白/工程前缀差异；任意 JS/闭包不进入通用核心，旧业务单位/金额政策仍属 compat-format，未自动兼容。
- **源码/契约入口**：[native-model](#evidence-native-model) · [axis-schema](#evidence-axis-schema) · [legacy-axis-unit](#evidence-legacy-axis-unit) · [axis-presentation-schema](#evidence-axis-presentation-schema) · [axis-presentation-test](#evidence-axis-presentation-test) · [axis-version-test](#evidence-axis-version-test) · [adapter](#evidence-adapter)

<a id="cap-plot-insets"></a>
### 图内边距

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：原生 contentInset 支持逻辑点边距；v1–v4 不含布局留白，旧 leftMargin 与自动轴测量不能假定像素等价。
- **后续动作**：先定义最小留白/固定留白优先级，再引入通用 inset 配置；外部卡片 margin 另列。
- **源码/契约入口**：[theme-native](#evidence-theme-native)

<a id="cap-grid-style"></a>
### 网格颜色与样式

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：`ChartAxisAppearance.showsGridlines`
- **判定**：旧 dashColor 实际同时影响 X 轴线和 Y 网格。v1–v4 有轴线颜色/网格开关，无网格颜色/虚线；原生 theme 能承接剩余外观。
- **后续动作**：新增网格 stroke 语义，明确按 domain/value 还是屏幕方向配置；保留网格方向契约测试。
- **源码/契约入口**：[appearance](#evidence-appearance) · [theme-native](#evidence-theme-native) · [grid-test](#evidence-grid-test) · [legacy-grid](#evidence-legacy-grid)

<a id="cap-crosshair-style"></a>
### 准线外观

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：原生视图可配 crosshairColor；v1–v4 无中立交互外观字段。
- **后续动作**：与选择反馈/Tooltip 的中立交互配置一并设计，禁止透传 UIColor 或 UIKit 视图。
- **源码/契约入口**：[view-native](#evidence-view-native)

<a id="cap-tooltip"></a>
### 逐采样提示、动态组名与组级规则

- **处置**：需新增通用语义。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：v6 已将通用开关/布局/逐系列规则拆到 tooltip-basic；逐采样表头/行名/隐藏点、动态组名和组级 onlyName 仍无对应通用契约。
- **后续动作**：R3 核对当前 sample ID 与偏移取值身份、整组行为及旧超时，再设计声明式覆盖；回调/图片解析仍为运行时。
- **源码/契约入口**：[tooltip-native](#evidence-tooltip-native) · [tooltip-options](#evidence-tooltip-options) · [tooltip-theme](#evidence-tooltip-theme) · [tooltip-test](#evidence-tooltip-test)

<a id="cap-tooltip-style"></a>
### 提示颜色主题

- **处置**：需新增通用语义。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：Swift 原生 TooltipTheme 支持主题；OC options 仅部分外观，JSON v1–v6 无提示颜色/字体配置。
- **后续动作**：统一中立提示文字/背景语义后补两端转换；不可声称现 OC options 已覆盖完整主题。
- **源码/契约入口**：[tooltip-theme](#evidence-tooltip-theme) · [tooltip-native](#evidence-tooltip-native)

<a id="cap-tooltip-offset"></a>
### 提示前值选择

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartTooltipSpecification.sampleSelection`、`ChartTooltipSampleSelection.offset`、`ChartTooltipSampleSelection.offsetsBySeriesID`、`ChartTooltipSampleSelection.boundaryPolicy`
- **判定**：v6 表达全局/逐稳定系列 ID 的类目槽位偏移与 omit/clamp/current、取值来源标签；保留当前命中/表头/准线与原值，缺测不搜索。聚合桶维持原生当前桶规则。
- **后续动作**：R2 将 showPrev 转为 -1 + clamp；不解释成数值距离/时间间隔，不据此开放 G6。
- **源码/契约入口**：[schema](#evidence-schema) · [interaction-schema](#evidence-interaction-schema) · [interaction-adapter](#evidence-interaction-adapter) · [interaction-test](#evidence-interaction-test) · [interaction-coding-test](#evidence-interaction-coding-test) · [tooltip-offset](#evidence-tooltip-offset) · [offset-test](#evidence-offset-test)

<a id="cap-group-summary"></a>
### 分组小计格式与来源

- **处置**：需新增通用语义。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：`ChartSpecification.groups`
- **判定**：通用组只有 ID/name；原生同单位/同轴/同格式小计不等于旧 float 汇总及独立组格式、fractionDigits=100。
- **后续动作**：R3 明确小计数据来源、数值精度和单位，再扩展语义或外置兼容格式器；不可先套用系列格式。
- **源码/契约入口**：[schema](#evidence-schema) · [tooltip-options](#evidence-tooltip-options) · [tooltip-test](#evidence-tooltip-test) · [legacy-series](#evidence-legacy-series)

<a id="cap-precision-compatibility"></a>
### 旧精度哨兵与预舍入

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartValuePresentation.maximumFractionDigits`
- **判定**：v1–v4 普通精度为 0...12；100 不是100位小数且被校验拒绝。旧 M 以上3位/其他2位和预舍入属于待实现兼容政策。
- **后续动作**：R2/R3 建独立兼容格式器或提出确有复用价值的精度政策扩展；不能钳制100为12或默认2。
- **源码/契约入口**：[format-schema](#evidence-format-schema) · [validation](#evidence-validation) · [format-test](#evidence-format-test) · [legacy-series](#evidence-legacy-series) · [format-native](#evidence-format-native)

<a id="cap-legend-style"></a>
### 逐系列图例符号/背景

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：`ChartSpecification.showsLegend`、`ChartSeriesSpecification.showsInLegend`
- **判定**：原生逐项图片/符号/背景已有；v6 legend-layout 只覆盖布局与标题，未定义资源引用或这些外观字段。
- **后续动作**：先定义中立资源 ID 与图例外观，宿主解析图片；不能把 UIImage/provider 写入 JSON。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [legend-native](#evidence-legend-native)

<a id="cap-group-legend"></a>
### 旧分组卡片式图例

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSpecification.groups`
- **判定**：组图片/分标题/组内分栏/间隔是旧 v2 业务卡片；现逐系列图例不能直接替代整套布局。
- **后续动作**：外部 UIView 组合，按 group/series ID 绑定显隐；确认真实页面后再决定通用图例布局扩展。
- **源码/契约入口**：[schema](#evidence-schema) · [legend-native](#evidence-legend-native) · [migration-plan](#evidence-migration-plan)

<a id="cap-annotations"></a>
### 标线、色带及文字

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.plotLines`、`ChartSpecification.plotBands`、`ChartPlotLine.valueAxisID`、`ChartPlotBand.valueAxisID`、`ChartAnnotationLabelStyle`
- **判定**：schema v5 已表达有限值轴标线/色带、统一唯一 ID、稳定 valueAxisID、显隐、颜色/线宽/三种线型及独立标签样式；HYM 映射复用 G4 固定层次，保留源身份。v1–v4 拒绝标注键；旧 dashStyle 未生效、zIndex 写死的历史不转化为新语义。
- **后续动作**：当前切片不含 X/类目标注、任意 zIndex、自定义字体资源或可执行 formatter；旧输入仍须未来 mapper 明确轴 ID 与线型白名单。
- **源码/契约入口**：[native-model](#evidence-native-model) · [labels-native](#evidence-labels-native) · [annotations-native](#evidence-annotations-native) · [annotation-test](#evidence-annotation-test) · [legacy-plot-line](#evidence-legacy-plot-line) · [annotation-schema](#evidence-annotation-schema) · [schema](#evidence-schema) · [adapter](#evidence-adapter) · [annotation-schema-test](#evidence-annotation-schema-test) · [annotation-adapter-test](#evidence-annotation-adapter-test)

<a id="cap-annotation-order"></a>
### 任意标注层级

- **处置**：应报不支持。**HYM 原生**：缺失。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：旧 zIndex 虽声明但转换实现写死3；不是既有已生效的任意层级。新原生仍只有固定绘制层次，v1–v4 无字段，不能宣称支持任意值。
- **后续动作**：未来 mapper 遇非默认层级需求须诊断；先确定有限前/后景语义及命中规则，不复制任意数值。
- **源码/契约入口**：[native-model](#evidence-native-model) · [labels-native](#evidence-labels-native) · [migration-plan](#evidence-migration-plan) · [legacy-plot-line](#evidence-legacy-plot-line)

<a id="cap-zones"></a>
### 旧完整 zones（X/Y 与分区填充）

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：仅部分映射。
- **已有 schema 落点**：`ChartSeriesAppearance.valueColorZones`
- **判定**：v3 已映射值轴颜色子集：柱/条 raw/draw、线/面积 draw；旧 zones 还含类目 X 原始索引和分区面积填充，不能把整个旧声明算作已表达。
- **后续动作**：R2 必须先判断 zoneAxisX、填充和取值语义再映射；X 与分区渐变仍需新契约。未建模额外 JSON 键不等于已提供拒绝诊断。
- **源码/契约入口**：[value-zones-schema](#evidence-value-zones-schema) · [adapter](#evidence-adapter) · [zones-native](#evidence-zones-native) · [zones-test](#evidence-zones-test) · [value-zones-test](#evidence-value-zones-test)

<a id="cap-value-color-zones"></a>
### N1 值轴颜色子集（柱 raw/draw、线/面积 draw）

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSeriesAppearance.valueColorZones`、`ChartValueColorZones.valueSource`、`ChartValueColorZone.upperBound`、`ChartValueColorZone.color`
- **判定**：显式 v3；半开有序区间，尾部及 nil 颜色继承系列色，不覆盖面积填充。按绑定值轴解释，水平 Bar 同义。线/面积 raw 在 HYM 明确拒绝；不改域、原值、缺测和身份。
- **后续动作**：保持 v1/v2/v3 默认与例子兼容；本子集不增加旧声明已表达数，旧 zones/zoneAxisX 仍需 R2 判别。
- **源码/契约入口**：[value-zones-schema](#evidence-value-zones-schema) · [adapter](#evidence-adapter) · [zones-native](#evidence-zones-native) · [value-zones-test](#evidence-value-zones-test) · [value-zones-reject-test](#evidence-value-zones-reject-test)

<a id="cap-g1-boundary"></a>
### G1 正负共享边界与统一缺测

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.schemaVersion`、`ChartSpecification.stackedAreaBoundary`、`ChartSpecification.stacking`、`ChartSeriesSpecification.missingValues`
- **判定**：v2 显式描述 independent/followBaseline/diverging，HYM 逐项映射；v1 解码与默认构造保持 independent，v1 JSON 不允许夹带新字段。diverging 同组统一断段优先于逐系列缺测规则，保留原始值与身份。
- **后续动作**：本小切片已有版本、校验、Swift/OC、同页 Demo 和契约测试；第二后端仍须逐模式诊断，不能将 shared-chain 退化为独立插值。
- **源码/契约入口**：[schema](#evidence-schema) · [boundary-coding](#evidence-boundary-coding) · [data](#evidence-data) · [g1-native](#evidence-g1-native) · [adapter](#evidence-adapter) · [g1-test](#evidence-g1-test) · [g1-model-test](#evidence-g1-model-test) · [g1-adapter-test](#evidence-g1-adapter-test)

<a id="cap-selection"></a>
### G5 主体选中外观

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：未建模，尚无对应诊断入口。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：原生点环、柱/条覆盖层支持四种轴系图并默认关闭；v1–v4 无选择外观，跨更新恢复是另一未完成运行时契约。
- **后续动作**：按交互外观建中立选择配置；选中对象仍用稳定 ID，不能编码 CALayer。
- **源码/契约入口**：[selection-native](#evidence-selection-native) · [annotations-native](#evidence-annotations-native)

<a id="cap-continuous-domain"></a>
### G6 连续数值/时间 X

- **处置**：应报不支持。**HYM 原生**：缺失。**v1/v2/v3 适配器**：已有显式拒绝。
- **已有 schema 落点**：`ChartSpecification.domain`、`ChartCoordinate.number`、`ChartCoordinate.unixSeconds`
- **判定**：schema 已表达真实数值/时间坐标并检查严格递增，但 HYMCharts 适配器显式拒绝；等距标签时间轴不等价。
- **后续动作**：G6 先实现按真实 X 的几何、命中、视口与 OC，再开启适配；不能先把坐标转字符串画等距图。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [diagnostics](#evidence-diagnostics) · [reject-test](#evidence-reject-test)

<a id="cap-reversed-axis"></a>
### G6 反向值轴

- **处置**：应报不支持。**HYM 原生**：缺失。**v1/v2/v3 适配器**：已有显式拒绝。
- **已有 schema 落点**：`ChartAxisSpecification.isReversed`
- **判定**：schema 已表达反向值轴，HYMCharts 明确拒绝；不能交换上下界或反转数据数组冒充。
- **后续动作**：G6 验证坐标转换/命中/主次轴/横向图后接通，未知后端继续报路径化能力错误。
- **源码/契约入口**：[axis-schema](#evidence-axis-schema) · [diagnostics](#evidence-diagnostics) · [reject-test](#evidence-reject-test)

<a id="cap-backend-limits"></a>
### 轴数与横向图元限制

- **处置**：应报不支持。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：已有显式拒绝。
- **已有 schema 落点**：`ChartSpecification.valueAxes`、`ChartSpecification.orientation`、`ChartSeriesSpecification.mark`
- **判定**：schema 可表达的多轴/横向线图并非当前 HYMCharts 支持范围；超两值轴、横向多轴/非 bar 均拒绝。
- **后续动作**：第二后端逐项给支持集，不因本后端限制而更改原始数据或丢弃系列。
- **源码/契约入口**：[schema](#evidence-schema) · [data](#evidence-data) · [diagnostics](#evidence-diagnostics) · [reject-test](#evidence-reject-test)

<a id="cap-secondary-grid"></a>
### 仅次轴网格

- **处置**：应报不支持。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：已有显式拒绝。
- **已有 schema 落点**：`ChartAxisAppearance.showsGridlines`
- **判定**：模型可分别配置网格，HYMCharts 不能只开次轴而关主轴；已有显式诊断而不是静默无效。
- **后续动作**：原生网格独立性改造前保留诊断；不得用主轴网格假装次轴刻度网格。
- **源码/契约入口**：[appearance](#evidence-appearance) · [diagnostics](#evidence-diagnostics) · [grid-test](#evidence-grid-test)

<a id="cap-data-labels"></a>
### 数据标签与堆叠总量

- **处置**：需新增通用语义。**HYM 原生**：已有。**v1/v2/v3 适配器**：仅部分映射。
- **已有 schema 落点**：`ChartSeriesAppearance.showsValueLabels`
- **判定**：v1–v4 仅逐系列数据标签开关已映射；G4 背景/避让/总量标签等原生能力没有中立字段。
- **后续动作**：按实际标注需求扩充标签格式/布局政策；不得把开关映射写成全套标签已覆盖。
- **源码/契约入口**：[appearance](#evidence-appearance) · [adapter](#evidence-adapter) · [theme-native](#evidence-theme-native) · [annotation-test](#evidence-annotation-test)

<a id="cap-runtime-create"></a>
### 配置、刷新与不可变文档

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：已有。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSpecification`、`ChartSpecification.decodeJSON`
- **判定**：已有 Swift 适配配置和 OC JSON 文档/bridge；旧方法同名 facade 及旧输入 mapper 未实现。失败更新应保留最后有效图。
- **后续动作**：R2 每次读取新快照，不复用旧缓存；R4 另外定义 accepted/layout/animation 回调含义。
- **源码/契约入口**：[schema](#evidence-schema) · [adapter](#evidence-adapter) · [document](#evidence-document) · [oc-test](#evidence-oc-test)

<a id="cap-runtime-events"></a>
### 命中/手势/加载生命周期

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：回调不是可序列化图表数据；原生 onHit 等不等价旧 UIPanGestureRecognizer/WebView finishLoad。
- **后续动作**：R4 定义线程、次数、取消/清除原因及 ID 映射，不能把 closure 或旧 delegate 放进 schema。
- **源码/契约入口**：[view-native](#evidence-view-native) · [oc-native](#evidence-oc-native) · [migration-plan](#evidence-migration-plan)

<a id="cap-runtime-selection"></a>
### 程序选点与恢复

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：缺失。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：当前没有完成旧 setTouchPointXIndex 对应的公开程序选择/清除契约；G5 只解决主体视觉，不解决恢复。
- **后续动作**：R4 新建以稳定身份定位的公共命令与恢复策略，不能调用 rendererForTesting。
- **源码/契约入口**：[view-native](#evidence-view-native) · [selection-native](#evidence-selection-native) · [migration-plan](#evidence-migration-plan)

<a id="cap-runtime-visibility"></a>
### 图例显隐命令与事件

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：已有。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSeriesSpecification.isVisible`
- **判定**：原生有 ID 驱动 setSeriesVisible/onSeriesVisibilityChanged；初始值在 schema，回调和用户覆盖在运行时。
- **后续动作**：用 ID 查回旧 element；外部图例按钮同样使用公开显隐接口，不生成虚拟业务系列。
- **源码/契约入口**：[data](#evidence-data) · [visibility-native](#evidence-visibility-native) · [oc-native](#evidence-oc-native) · [visibility-test](#evidence-visibility-test)

<a id="cap-runtime-viewport"></a>
### 缩放与初始视口

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：Swift 有 X/Y/XY 手势和 showCategoryRange，OC bridge 默认按图形选缩放轴；v1–v4 无视口命令。
- **后续动作**：R4 明确旧闭区间→半开范围及半槽差异、状态恢复；不要把交互窗口误写成数据缺测/删点。
- **源码/契约入口**：[zoom-native](#evidence-zoom-native) · [viewport-native](#evidence-viewport-native) · [oc-native](#evidence-oc-native) · [migration-plan](#evidence-migration-plan)

<a id="cap-host-factory"></a>
### 业务工厂与主题预设

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：工厂创建 UIView、注入业务资源/语言/样式，不属于引擎无关数据模型。
- **后续动作**：R5 保留项目级组合根，使用中立模型+适配器；不发布与旧库冲突的同名类。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan) · [document](#evidence-document)

<a id="cap-host-business"></a>
### 业务 key 与符号预处理

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：旧 key 名称/符号转换存在 D07 重叠分支，真实业务意图未确定；模型不会自动修正业务数据。
- **后续动作**：R0b 用真实调用确认命名/符号政策；与数学堆叠及显示 abs 分离，不下沉 SDK。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan)

<a id="cap-host-empty"></a>
### 空态资源与强制空态

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：图片/文案/字体/强制空态是外层展示，不通过修改原值、清空调用者模型来实现。
- **后续动作**：R5 宿主保存数据及显隐状态，退出空态恢复；资源由业务注入。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan)

<a id="cap-host-container"></a>
### 全屏、多图和尺寸容器

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：页面跳转、布局、安全区、多图协调与状态保存不属于单图 schema。
- **后续动作**：R6 外部容器持有多份 ChartSpecification 和运行时状态；拿到真实页面再验收横屏/返回恢复。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan)

<a id="cap-host-card"></a>
### 统计表头、日出日落与版本卡片

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：headerDatas/sunDatas/版本通用单位及布局是业务卡片；不能把这些缓存当图表采样。
- **后续动作**：R5 外部 view model + UIView 组合；图内轴标题、Tooltip 表头和注释文字分别审查。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan)

<a id="cap-host-appearance"></a>
### 暗色资源与外观解析

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartRGBA`
- **判定**：v1–v4 只存具体 RGBA，不能自动表达动态 UIColor 或深浅色数组；原生主题可由宿主刷新。
- **后续动作**：宿主独立解析各用途颜色并在 trait 改变时更新；后端无对应字段时仍需报告缺口，不能统一混用数组。
- **源码/契约入口**：[appearance](#evidence-appearance) · [theme-native](#evidence-theme-native) · [neutral-guide](#evidence-neutral-guide)

<a id="cap-derived-cache"></a>
### 旧格式化和可见系列缓存

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：showSeriesArray/fdata/fgdata 等是派生结果，不是第二份真实输入；通用核心不持久化这些旧缓存。
- **后续动作**：兼容展示层按最新 raw+规则重新计算，禁止缓存掩盖数据更新或将格式化字符串回填 value。
- **源码/契约入口**：[legacy-series](#evidence-legacy-series) · [migration-plan](#evidence-migration-plan)

<a id="cap-compat-input"></a>
### 旧输入校验与转换工具

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSample.value`、`ChartRGBA`
- **判定**：这些方法属于旧输入→中立值的独立 mapper/helper，非 SDK 同名 API。当前仅有新模型校验，没有旧类型自动转换。
- **后续动作**：R2 处理 NSNull 保位、非法 string/颜色显式错误；min/max 由真实可见 draw/base 重新求，不能照搬旧首行缓存。
- **源码/契约入口**：[data](#evidence-data) · [appearance](#evidence-appearance) · [validation](#evidence-validation) · [native-model](#evidence-native-model) · [migration-plan](#evidence-migration-plan)

<a id="cap-compat-format"></a>
### 旧单位/金额/舍入工具

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartValuePresentation`
- **判定**：普通展示意图已有，旧工具的方法语义、预舍入、负零、单位白名单及哨兵尚未自动兼容。
- **后续动作**：R2/R3 做独立格式兼容政策及边界契约，不把工具类名称或 JS 字符串暴露到通用核心。
- **源码/契约入口**：[format-schema](#evidence-format-schema) · [legacy-series](#evidence-legacy-series) · [migration-plan](#evidence-migration-plan) · [format-native](#evidence-format-native)

<a id="cap-compat-sign-split"></a>
### 旧正负虚拟系列拆分

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSample.value`、`ChartSpecification.stacking`
- **判定**：新模型保留有符号原值与单一业务 ID；原生可以内部正负累计/分链，但旧拆分后的数据和提示顺序不能自动等价。
- **后续动作**：R2 选择 D06 语义、修复 D09 缺测/丢字段，不向业务增加正负两套系列；G1 新边界现可通过 v2 显式选择，但不会自动兼容旧正负拆分政策。
- **源码/契约入口**：[data](#evidence-data) · [schema](#evidence-schema) · [g1-native](#evidence-g1-native) · [g1-test](#evidence-g1-test) · [migration-plan](#evidence-migration-plan)

<a id="cap-compat-order"></a>
### 旧绘制反序与三类顺序

- **处置**：外层 UI / 运行时 / 兼容层。**HYM 原生**：部分/语义有差异。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：`ChartSpecification.series`
- **判定**：输入系列顺序可影响绘制/累计，但 v1–v4 没有独立的绘制、图例、提示顺序；旧 reverse 不是反向值轴。
- **后续动作**：R2 用共享样本明确 D05；需要独立顺序时提出中立扩展，不能直接 reverse 所有数组。
- **源码/契约入口**：[schema](#evidence-schema) · [legend-order](#evidence-legend-order) · [migration-plan](#evidence-migration-plan)

<a id="cap-export-placeholder"></a>
### 旧快照占位入口

- **处置**：应报不支持。**HYM 原生**：缺失。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：旧 snapClosure/triggerSnap 是占位，不能视为已存在的可回归导出功能；schema v1–v4 也不是导出 API。
- **后续动作**：有真实调用后单独设计图像导出及资源/权限边界；迁移前拒绝静默空实现。
- **源码/契约入口**：[migration-plan](#evidence-migration-plan)

<a id="cap-vendor-output"></a>
### JS/AAOptions 引擎产物

- **处置**：应报不支持。**HYM 原生**：非渲染职责。**v1/v2/v3 适配器**：外部处理，不是 schema 字段。
- **已有 schema 落点**：无；不凭空假设新增字段已存在。
- **判定**：AASeriesElement、AAOptions、JS 数组字符串不进入公共中立模型；本任务不提供旧输出对象的伪兼容。
- **后续动作**：迁移直接消费者到 ChartSpecification/适配结果；mapper 遇此依赖明确报告，不以 metadata 透传。
- **源码/契约入口**：[schema](#evidence-schema) · [adapter](#evidence-adapter) · [migration-plan](#evidence-migration-plan)

<a id="cap-tooltip-basic"></a>
### 提示开关、布局与逐系列内容

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.tooltip`、`ChartTooltipSpecification.layout`、`ChartTooltipSpecification.position`、`ChartTooltipSpecification.seriesRules`
- **判定**：v6 可表达开关、text/columns、automatic/fixedTop、当前表头模板、零值过滤和稳定系列 ID 行隐藏/标题/隐藏数值。nil 保留宿主运行时；非 nil 完整覆盖已建模内容，图片/provider 与外观保留运行时。 N4 fixedTop 自动限制在绘图区，避开标题/图例；原生开关默认 false，不新增 schema 字段，仍覆盖数据。
- **后续动作**：R2 对 tooltipDisable 取反、hideInTooltip 映射 isHidden、hideNameInTooltip 使用空标题；不承诺旧超时或逐采样规则。
- **源码/契约入口**：[schema](#evidence-schema) · [interaction-schema](#evidence-interaction-schema) · [interaction-adapter](#evidence-interaction-adapter) · [interaction-test](#evidence-interaction-test) · [interaction-coding-test](#evidence-interaction-coding-test) · [tooltip-layout-test](#evidence-tooltip-layout-test)

<a id="cap-legend-layout"></a>
### 图例布局与稳定系列标题

- **处置**：已表达。**HYM 原生**：已有。**v1/v2/v3 适配器**：已映射。
- **已有 schema 落点**：`ChartSpecification.legend`、`ChartLegendSpecification.position`、`ChartLegendSpecification.titlesBySeriesID`
- **判定**：v6 表达屏幕四方向、行对齐、scroll/expand、最大行数/尺寸、点击显隐与相邻组换行；标题按稳定系列 ID 覆盖，不改变系列顺序或 Tooltip 名称。
- **后续动作**：保留 showsLegend/showsInLegend/isVisible；未覆盖符号/图片/背景/动态组标题/业务卡片，不补造旧字段数量。
- **源码/契约入口**：[schema](#evidence-schema) · [interaction-schema](#evidence-interaction-schema) · [interaction-adapter](#evidence-interaction-adapter) · [interaction-test](#evidence-interaction-test) · [interaction-coding-test](#evidence-interaction-coding-test) · [legend-native](#evidence-legend-native)

## 源码与现有契约入口

以下是审计定位依据。锚点存在不等于功能正确；“test”表示现有契约测试入口，**不表示本批已重新执行这些 XCTest**。本批实际执行范围见任务进度及独立审计证据。

<a id="evidence-schema"></a>
- **schema** (schema)：[`public struct ChartSpecification:`](../SwiftFunctionProject/Charts/Specification/ChartSpecification.swift#L5)
<a id="evidence-data"></a>
- **data** (schema)：[`public struct ChartSeriesSpecification:`](../SwiftFunctionProject/Charts/Specification/ChartDataSpecification.swift#L64)
<a id="evidence-appearance"></a>
- **appearance** (schema)：[`public struct ChartSeriesAppearance:`](../SwiftFunctionProject/Charts/Specification/ChartAppearanceSpecification.swift#L28)
<a id="evidence-axis-schema"></a>
- **axis-schema** (schema)：[`public struct ChartAxisSpecification:`](../SwiftFunctionProject/Charts/Specification/ChartAppearanceSpecification.swift#L59)
<a id="evidence-format-schema"></a>
- **format-schema** (schema)：[`public struct ChartValuePresentation:`](../SwiftFunctionProject/Charts/Specification/ChartAppearanceSpecification.swift#L81)
<a id="evidence-validation"></a>
- **validation** (schema)：[`func validationIssues()`](../SwiftFunctionProject/Charts/Specification/ChartSpecificationValidation.swift#L6)
<a id="evidence-adapter"></a>
- **adapter** (adapter)：[`public func makeConfiguration(from specification:`](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift#L78)
<a id="evidence-diagnostics"></a>
- **diagnostics** (adapter)：[`public func diagnostics(for specification:`](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationAdapter.swift#L33)
<a id="evidence-document"></a>
- **document** (native)：[`public func makeNativeBridge(frame:`](../SwiftFunctionProject/Charts/OCBridge/HYMChartSpecificationDocument.swift#L36)
<a id="evidence-native-model"></a>
- **native-model** (native)：[`public struct CartesianChartModel`](../SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift#L244)
<a id="evidence-axis-native"></a>
- **axis-native** (native)：[`public struct CartesianAxisStyle`](../SwiftFunctionProject/Charts/Cartesian/CartesianAxisStyle.swift#L4)
<a id="evidence-ticks-native"></a>
- **ticks-native** (native)：[`public var categoryLabelInterval: Int?`](../SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift#L51)
<a id="evidence-theme-native"></a>
- **theme-native** (native)：[`public struct CartesianChartTheme`](../SwiftFunctionProject/Charts/Cartesian/CartesianChartTheme.swift#L50)
<a id="evidence-g1-native"></a>
- **g1-native** (native)：[`public enum StackedAreaBoundaryMode:`](../SwiftFunctionProject/Charts/Cartesian/CartesianChartTheme.swift#L22)
<a id="evidence-zones-native"></a>
- **zones-native** (native)：[`public struct CartesianColorZones`](../SwiftFunctionProject/Charts/Cartesian/CartesianColorZones.swift#L36)
<a id="evidence-annotations-native"></a>
- **annotations-native** (native)：[`public final class HYMCartesianPlotLine:`](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianAnnotations.swift#L37)
<a id="evidence-labels-native"></a>
- **labels-native** (native)：[`public struct CartesianAnnotationLabelStyle`](../SwiftFunctionProject/Charts/Cartesian/CartesianAnnotationLabel.swift#L17)
<a id="evidence-selection-native"></a>
- **selection-native** (native)：[`public struct CartesianSelectionStyle`](../SwiftFunctionProject/Charts/Cartesian/CartesianSelectionStyle.swift#L5)
<a id="evidence-tooltip-native"></a>
- **tooltip-native** (native)：[`public struct CartesianTooltipPresentation`](../SwiftFunctionProject/Charts/Cartesian/CartesianTooltipPresentation.swift#L31)
<a id="evidence-tooltip-options"></a>
- **tooltip-options** (native)：[`public struct CartesianTooltipOptions`](../SwiftFunctionProject/Charts/Cartesian/CartesianTooltipOptions.swift#L5)
<a id="evidence-tooltip-offset"></a>
- **tooltip-offset** (native)：[`public struct CartesianTooltipSampleSelection`](../SwiftFunctionProject/Charts/Cartesian/CartesianTooltipSampleSelection.swift#L12)
<a id="evidence-tooltip-theme"></a>
- **tooltip-theme** (native)：[`public struct HYMChartTooltipTheme`](../SwiftFunctionProject/Charts/Core/HYMChartTooltipTheme.swift#L7)
<a id="evidence-legend-native"></a>
- **legend-native** (native)：[`public final class HYMCartesianLegendItemStyle:`](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianPresentation.swift#L95)
<a id="evidence-view-native"></a>
- **view-native** (native)：[`public var onHit:`](../SwiftFunctionProject/Charts/Core/HYMChartView.swift#L26)
<a id="evidence-zoom-native"></a>
- **zoom-native** (native)：[`public var zoomAxisMode:`](../SwiftFunctionProject/Charts/Core/HYMChartView.swift#L73)
<a id="evidence-viewport-native"></a>
- **viewport-native** (native)：[`public func showCategoryRange(`](../SwiftFunctionProject/Charts/Core/HYMChartView.swift#L309)
<a id="evidence-visibility-native"></a>
- **visibility-native** (native)：[`public func setSeriesVisible(`](../SwiftFunctionProject/Charts/Core/HYMChartView.swift#L274)
<a id="evidence-legend-order"></a>
- **legend-order** (native)：[`public var legendOrder:`](../SwiftFunctionProject/Charts/Cartesian/CartesianChartModel.swift#L94)
<a id="evidence-oc-native"></a>
- **oc-native** (native)：[`public func setSeriesVisible(`](../SwiftFunctionProject/Charts/OCBridge/HYMCartesianChartViewBridge.swift#L163)
<a id="evidence-neutral-guide"></a>
- **neutral-guide** (guide)：[`fractionDigits`](../docs/charts-neutral-model-guide.md#L322)
<a id="evidence-migration-plan"></a>
- **migration-plan** (guide)：[`R4`](../docs/charts-legacy-replacement-plan.md#L141)
<a id="evidence-legacy-series"></a>
- **legacy-series** (legacy)：[`fractionDigits=100`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAASeries.h#L49)
<a id="evidence-identity-test"></a>
- **identity-test** (test)：[`func testRoundTripKeepsIdentityMissingSignAndPresentationWithoutUIKit(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L15)
<a id="evidence-sparse-test"></a>
- **sparse-test** (test)：[`func testSparseUnorderedSamplesAlignByCategoryIDWithoutInventingIdentities(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L160)
<a id="evidence-style-test"></a>
- **style-test** (test)：[`func testStyleAndGapConversionPreserveExplicitChoices(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L201)
<a id="evidence-percent-test"></a>
- **percent-test** (test)：[`func testSignedPercentUsesAbsoluteDenominatorAndLeavesRawValuesUnchanged(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L187)
<a id="evidence-axis-test"></a>
- **axis-test** (test)：[`func testSeriesAndAxisReorderingRetainStableBindings(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L175)
<a id="evidence-reject-test"></a>
- **reject-test** (test)：[`func testUnsupportedCoordinatesAxesAndIgnoredBarStylesAreRejected(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L220)
<a id="evidence-grid-test"></a>
- **grid-test** (test)：[`func testAxisGridIntentControlsActualScreenDirectionsAndRejectsSecondaryOnlyGrid(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L236)
<a id="evidence-format-test"></a>
- **format-test** (test)：[`func testInputStyleRangeAndLegacyPrecisionAreNotSilentlyClamped(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L85)
<a id="evidence-oc-test"></a>
- **oc-test** (test)：[`func testObjectiveCDocumentAndBridgeKeepLastChartWhenUpdateFails(`](../SwiftFunctionProjectTests/ChartSpecificationTests.swift#L285)
<a id="evidence-g1-test"></a>
- **g1-test** (test)：[`func testUnifiedGapsKeepValidRawHitsAndDoNotAddZeroCrossingSamples(`](../SwiftFunctionProjectTests/DivergingStackRendererTests.swift#L25)
<a id="evidence-axes-test"></a>
- **axes-test** (test)：[`func testIndependentAxisColorsFontsAndLinesAcrossFourRenderers(`](../SwiftFunctionProjectTests/AxisStyleTests.swift#L38)
<a id="evidence-cadence-test"></a>
- **cadence-test** (test)：[`func testExplicitCategoryCadenceIsAbsoluteAndDensityUsesMultiples(`](../SwiftFunctionProjectTests/AxisStyleTests.swift#L94)
<a id="evidence-annotation-test"></a>
- **annotation-test** (test)：[`func testObjectiveCSnapshotAndDemoBindingsUseSameAnnotationSettings(`](../SwiftFunctionProjectTests/AnnotationStyleTests.swift#L188)
<a id="evidence-tooltip-test"></a>
- **tooltip-test** (test)：[`func testStructuredContentKeepsGroupsMetadataImagesAndSignedSubtotal(`](../SwiftFunctionProjectTests/RichTooltipTests.swift#L28)
<a id="evidence-offset-test"></a>
- **offset-test** (test)：[`func testPreviousValuesKeepCurrentHeaderHitProviderAndAlignedSubtotal(`](../SwiftFunctionProjectTests/TooltipSelectionTests.swift#L30)
<a id="evidence-zones-test"></a>
- **zones-test** (test)：[`func testZonesDoNotFillMissingDataOrChangeHitDomainAndGapPolicy(`](../SwiftFunctionProjectTests/CartesianColorZoneTests.swift#L214)
<a id="evidence-visibility-test"></a>
- **visibility-test** (test)：[`func testVisibilitySurvivesReorderingAndCanBeResetOrDrivenByModel(`](../SwiftFunctionProjectTests/ChartLegendTests.swift#L163)
<a id="evidence-format-native"></a>
- **format-native** (native)：[`public struct CartesianValueFormat`](../SwiftFunctionProject/Charts/Cartesian/CartesianValueFormat.swift#L4)
<a id="evidence-legacy-axis-unit"></a>
- **legacy-axis-unit** (legacy)：[`NSString *format = [NSString stringWithFormat:@"{value}%@", subYAxis.unit];`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L120)
<a id="evidence-legacy-secondary-ticks"></a>
- **legacy-secondary-ticks** (legacy)：[`rightYAxis.tickPositions = _chartModel.yAxisTickPositions;`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L126)
<a id="evidence-legacy-secondary-color"></a>
- **legacy-secondary-color** (legacy)：[`rightYAxis.lineColorSet(_chartModel.yAxisTextColor);`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L111)
<a id="evidence-legacy-plot-line"></a>
- **legacy-plot-line** (legacy)：[`- (AAPlotLinesElement *)packagePlotElementWithObject:(HMAAPlotLinesElement *)obj {`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L563)
<a id="evidence-legacy-fill"></a>
- **legacy-fill** (legacy)：[`NSString *endColorString = [HMAASeriesUtil rgbaStringFromHex:fillColor withAlpha:[obj.fillColorAlphas.lastObject floatValue]];`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L518)
<a id="evidence-legacy-gap"></a>
- **legacy-gap** (legacy)：[`if (len >= maxNulls) {`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L613)
<a id="evidence-legacy-grid"></a>
- **legacy-grid** (legacy)：[`aChartOptions.xAxis.lineColor = _chartModel.dashColor;`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L63)
<a id="evidence-legacy-title"></a>
- **legacy-title** (legacy)：[`if (_chartModel.name.length > 0 && _chartModel.version != 2) {`](../SwiftFunctionProject/参考图表/HMAAChartView/HMAAChartTool/HMAAChartManager.m#L57)
<a id="evidence-boundary-coding"></a>
- **boundary-coding** (schema)：[`if schemaVersion >= 2 { try c.encode(stackedAreaBoundary, forKey: .stackedAreaBoundary) }`](../SwiftFunctionProject/Charts/Specification/ChartSpecificationVersionCoding.swift#L125)
<a id="evidence-g1-model-test"></a>
- **g1-model-test** (test)：[`func testV1CannotSmuggleBoundaryKeyOrSilentlyDowngradeV2(`](../SwiftFunctionProjectTests/ChartSpecificationBoundaryTests.swift#L59)
<a id="evidence-g1-adapter-test"></a>
- **g1-adapter-test** (test)：[`func testDivergingOverridesConnectForGeometryButPreservesRawMissingAndHitIdentity(`](../SwiftFunctionProjectTests/ChartSpecificationBoundaryTests.swift#L127)
<a id="evidence-value-zones-schema"></a>
- **value-zones-schema** (schema)：[`public struct ChartValueColorZones:`](../SwiftFunctionProject/Charts/Specification/ChartValueColorZones.swift#L29)
<a id="evidence-value-zones-test"></a>
- **value-zones-test** (test)：[`func testRaw20Draw70PercentVisibilityAndIdentityInVerticalAndHorizontalBars(`](../SwiftFunctionProjectTests/ChartSpecificationColorZoneTests.swift#L154)
<a id="evidence-value-zones-reject-test"></a>
- **value-zones-reject-test** (test)：[`func testRawLineAndAreaAreExplicitlyRejectedIncludingHiddenSeries(`](../SwiftFunctionProjectTests/ChartSpecificationColorZoneTests.swift#L121)
<a id="evidence-axis-presentation-schema"></a>
- **axis-presentation-schema** (schema)：[`public struct ChartAxisLabelFormat:`](../SwiftFunctionProject/Charts/Specification/ChartAxisPresentation.swift#L12)
<a id="evidence-axis-presentation-test"></a>
- **axis-presentation-test** (test)：[`func testFourRenderersConsumeIndependentAxisTicksFontsAndFormattedLabels(`](../SwiftFunctionProjectTests/ChartSpecificationAxisPresentationTests.swift#L147)
<a id="evidence-axis-version-test"></a>
- **axis-version-test** (test)：[`func testPriorVersionsRejectEveryReservedKeyEvenNullThroughBothDecoders(`](../SwiftFunctionProjectTests/ChartSpecificationAxisPresentationTests.swift#L38)
<a id="evidence-annotation-schema"></a>
- **annotation-schema** (schema)：[`public struct ChartPlotLine:`](../SwiftFunctionProject/Charts/Specification/ChartAnnotationSpecification.swift#L44)
<a id="evidence-annotation-schema-test"></a>
- **annotation-schema-test** (test)：[`func testV5RoundTripAllLabelEnumsVisibilityAndEmptyArrays(`](../SwiftFunctionProjectTests/ChartSpecificationAnnotationTests.swift#L13)
<a id="evidence-annotation-adapter-test"></a>
- **annotation-adapter-test** (test)：[`func testStableAxisAndAnnotationIDsSurviveReorderAndHiddenItemsRemainInSource(`](../SwiftFunctionProjectTests/HYMChartsSpecificationAnnotationTests.swift#L27)
<a id="evidence-interaction-schema"></a>
- **interaction-schema** (schema)：[`public struct ChartTooltipSpecification:`](../SwiftFunctionProject/Charts/Specification/ChartInteractionSpecification.swift#L37)
<a id="evidence-interaction-adapter"></a>
- **interaction-adapter** (adapter)：[`public struct HYMChartsSpecificationTooltipConfiguration`](../SwiftFunctionProject/Charts/Adapters/HYMChartsSpecificationInteraction.swift#L5)
<a id="evidence-interaction-test"></a>
- **interaction-test** (test)：[`func testFourRenderersPreviousRawValuesKeepCurrentHitHeaderG1AndPercentCoordinates(`](../SwiftFunctionProjectTests/HYMChartsSpecificationInteractionTests.swift#L78)
<a id="evidence-interaction-coding-test"></a>
- **interaction-coding-test** (test)：[`func testOldVersionsRejectReservedKeysAndDowngradeEvenDisabledDefaults(`](../SwiftFunctionProjectTests/ChartSpecificationInteractionTests.swift#L43)
<a id="evidence-tooltip-layout-test"></a>
- **tooltip-layout-test** (test)：[`func testOptInPreservesNativeDefaultsPlotViewportHitAndAutomaticPlacement(`](../SwiftFunctionProjectTests/FixedTooltipLayoutTests.swift#L44)

## 离线检查与边界

```sh
python3 scripts/check_chart_migration_inventory.py
python3 scripts/check_chart_neutral_coverage.py
python3 -m unittest discover -s scripts -p "test_check_chart_neutral_coverage.py"
```

检查器核对实际旧声明、重复/遗漏/失效字段、来源位置、矩阵状态组合、源码/测试锚点、schema 版本以及 Markdown 是否同步；拒绝越界路径和重复 JSON 键。
检查器只验证审计材料的一致性，不自动证明语义或发现所有缺失字段；源代码行为变化需人工重新审计并运行相应契约测试。

关联：[机器清单](charts-neutral-model-coverage.json) · [模型指南](charts-neutral-model-guide.md) · [旧字段历史清单](charts-legacy-field-inventory.md) · [后续实施计划](charts-legacy-replacement-plan.md)。
