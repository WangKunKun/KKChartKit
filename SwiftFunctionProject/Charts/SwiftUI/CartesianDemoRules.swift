import SwiftUI

/// Demo 的依赖/优先级说明。只装饰控件，不悄悄清除被覆盖的配置。
/// SDK 的优先级仍由 renderer 决定；可恢复条件后，原值继续生效。
enum CartesianDemoRules {
    typealias Item = ChartDemoPanel.Item
    static func apply(to sections: [ChartDemoPanel.DemoSection], state s: CartesianDemoState) -> [ChartDemoPanel.DemoSection] {
        let model = s.model
        let current = s.series[min(s.selectedSeries, s.seriesCount - 1)]
        let element = model.series[min(s.selectedSeries, s.seriesCount - 1)]
        let effective = element.lineTheme(s.builtTheme)
        let visible = model.series.filter(\.isVisible)
        let lines = visible.filter { s.kind == .line || (s.kind == .combined && $0.kind?.isColumn == false) }
        let pointSeries = lines.filter { $0.lineTheme(s.builtTheme).showsPoints }
        let areaSeries = lines.filter { $0.lineTheme(s.builtTheme).showsArea }
        let labelSeries = visible.filter { $0.dataLabelsEnabled ?? s.theme.showsDataLabels }
        let isLine = s.kind == .line || (s.kind == .combined && !current.kind.isColumn)
        let generated = s.series.prefix(s.seriesCount).filter { $0.dataText.isEmpty }.count
        let builtinPopup = s.interaction.popupMode == "内置"
        let hasPopup = s.interaction.tooltip && s.interaction.popupMode != "位置回调"

        func annotate(_ item: Item, _ reason: String, enabled: Bool = true) -> Item {
            .availability(item, reason: reason, enabled: enabled)
        }
        func require(_ item: Item, _ condition: Bool, _ reason: String) -> Item {
            condition ? item : annotate(item, reason, enabled: false)
        }
        func inheritance(_ item: Item, _ inherited: Int, _ count: Int) -> Item {
            guard inherited < count else { return item }
            return annotate(item, "当前 \(count - inherited)/\(count) 条可见系列有更高优先级的覆盖；在逐系列配置中恢复继承后使用本项。", enabled: inherited > 0)
        }
        let decorated = sections.map { section -> ChartDemoPanel.DemoSection in
            let items = section.items.map { item -> Item in
                let label = item.label
                switch section.title {
                case "数据与布局":
                    if ["数据点数", "更新样本数据", "正负混合", "包含缺测"].contains(label) {
                        return annotate(item, "仅影响生成数据；\(s.seriesCount - generated) 条系列使用数据覆盖。实际最长 \(model.maxPointCount) 点。", enabled: generated > 0)
                    }
                    if case .button = item, label != "更新样本数据" {
                        return annotate(item, "场景按钮会恢复默认配置后加载样本；普通属性修改不会清空其它设置。")
                    }
                    if label == "测量并追加图例高度" {
                        return require(item, s.theme.legend.isEnabled && [.top, .bottom].contains(s.theme.legend.position), "仅上下图例需要追加高度；总预览高度仍不超过页面 60%。")
                    }
                case "当前系列（逐系列配置）":
                    if label == "值轴（0 主轴 / 1 次轴）" { return require(item, s.dualAxis, "先启用次值轴；关闭时所有系列使用主轴，设置保留。") }
                    if s.theme.stackedAreaBoundaryMode == .diverging && model.isStacked && current.participatesInStack && isLine,
                       label == "跨空值连线" || label.contains("缺测策略") || label.contains("缺测时长") {
                        return annotate(item, "正负分链模式按同组缺测统一断段；切回其他边界模式后恢复此设置。", enabled: false)
                    }
                    if label == "跨空值连线" { return require(item, current.gapPolicy == nil, "显式缺测策略优先；选择“跟随跨空值连线”后本项生效。") }
                    if label == "缺测时长上限秒（需时间轴）" && !s.timeEnabled {
                        return annotate(item, "未启用时间轴：无法计算时长，当前按缺测断开处理。请先开启时间轴。", enabled: false)
                    }
                    if label.contains("负值颜色"), current.zoneMode != "关闭", isLine {
                        return annotate(item, "显式颜色分区优先于负值颜色；关闭颜色分区后恢复。", enabled: false)
                    }
                    if label == "分区面积渐变" { return require(item, isLine && effective.showsArea, "当前系列未启用面积填充；先开启主题 showsArea 或系列面积填充。") }
                    if label == "堆叠组 stackID（空为默认组）" {
                        return require(item, s.stacking != "无" && current.participatesInStack, "需启用堆叠且当前系列参与堆叠；业务组 ID 不参与数学堆叠。")
                    }
                    if label == "参与堆叠 participatesInStack" { return require(item, s.stacking != "无", "当前未启用堆叠。") }
                    if label == "业务组名称（同 ID 使用首项名称）" { return require(item, !current.groupID.isEmpty, "先设置业务组 ID；同 ID 使用首条系列的名称。") }
                    let legendFields = ["图例排序", "图例标题覆盖（空为系列名）", "图例符号", "图例标记形状", "自定义 图例符号颜色", "图例符号颜色", "图例内容预设", "图例图片 SF Symbol", "隐藏时图例图片 SF Symbol", "自定义 图例项背景", "图例项背景", "图例项圆角"]
                    if legendFields.contains(label) && (!s.theme.legend.isEnabled || !current.showsInLegend) {
                        return annotate(item, "需启用图例并让当前系列加入图例。", enabled: false)
                    }
                    if ["自定义 图例符号颜色", "图例符号颜色"].contains(label) && current.legendContent == "自定义状态" {
                        return annotate(item, "自定义状态预设使用固定开关配色；默认形状和 template 图片才使用此颜色。", enabled: false)
                    }
                    if label.contains("图例图片") { return require(item, current.legendContent == "图片", "选择图片预设后生效；无效图片名称回退内置符号。") }
                    if label == "图例项圆角" { return require(item, current.legendBackground != nil, "先启用图例项背景。") }
                    if label == "图例符号" && current.legendContent != "默认" { return annotate(item, "自定义符号 > 图片 > 内置形状；切回默认后恢复。", enabled: false) }
                    if label == "图例标记形状" { return require(item, current.legendContent == "默认" && ["线和标记", "标记"].contains(current.legendSymbol), "默认预设中仅显式“线和标记 / 标记”图例符号使用本项；自动符号跟随系列点形状。") }
                    if ["图例排序", "图例标题覆盖（空为系列名）", "图例符号", "自定义 图例符号颜色", "图例符号颜色"].contains(label) {
                        return require(item, s.theme.legend.isEnabled && current.showsInLegend, "需启用图例并让当前系列加入图例。")
                    }
                    if ["系列点形状", "自定义系列标记半径", "系列标记半径 pt"].contains(label) {
                        return require(item, isLine && effective.showsPoints, "当前系列不显示标记；系列标记可见覆盖主题 showsPoints。")
                    }
                    if ["自定义系列填充透明度", "系列填充透明度", "自定义系列填充颜色", "系列渐变起色", "系列渐变末色", "恢复系列默认渐变（忽略主题渐变）"].contains(label) {
                        if !isLine || !effective.showsArea { return annotate(item, "先开启当前系列的面积填充。", enabled: false) }
                        if current.zoneMode != "关闭" && current.zoneFill && !label.contains("透明度") {
                            return annotate(item, "分区面积渐变优先；关闭“分区面积渐变”后继承系列/主题渐变。", enabled: false)
                        }
                        if current.style.areaGradientColors?.isEmpty == true && label.contains("渐变") {
                            return annotate(item, "当前为空数组：按系列颜色生成默认渐变，不继承主题；选择颜色后改为显式渐变。")
                        }
                    }
                    if s.kind == .combined && !isLine {
                        let lineOnly = ["系列虚线", "系列点形状", "跨空值连线", "缺测策略 autoGap", "系列连线覆盖", "自定义系列线宽", "系列标记可见", "自定义系列标记半径", "系列面积填充", "自定义系列填充透明度", "自定义系列填充颜色"]
                        if lineOnly.contains(label) || label.hasPrefix("缺测") || label.hasPrefix("系列渐变") || label == "系列线宽 pt" {
                            return annotate(item, "当前系列 kind 为 column；此项仅适用于线/面积系列。", enabled: false)
                        }
                    }
                    if label == "逐柱配色" || label.hasPrefix("调色板") { return require(item, !isLine && (label == "逐柱配色" || current.palette), "仅柱体系列启用逐柱配色时生效。") }
                case "堆叠与双轴":
                    if label.hasPrefix("序号分组数量") { return require(item, s.stacking == "序号分组", "仅“序号分组”使用数量；显式 stackID 优先。") }
                    if label == "固定百分比基准" { return require(item, s.stacking == "固定基准百分比", "仅“固定基准百分比”使用此基准。") }
                case "类目轴":
                    if ["类目下界", "类目上界"].contains(label) {
                        return annotate(item, rangeReason(s.categoryAxis), enabled: s.categoryAxis.manualRange)
                    }
                    if label.hasPrefix("标签覆盖") { return annotate(item, "非空类目标签优先于时间标签；不会关闭时间轴的缺测时长计算。") }
                case "主值轴", "次值轴":
                    let axis = section.title == "主值轴" ? s.primaryAxis : s.secondaryAxis
                    if ["下界", "上界"].contains(label) { return annotate(item, rangeReason(axis), enabled: axis.manualRange) }
                    if label.hasPrefix("固定刻度间隔") { return require(item, axis.manualRange && axis.parsedPositions == nil, "需要固定值域，且刻度位置为空（有效显式位置优先）。") }
                    if label == "刻度间隔" { return require(item, axis.manualRange && axis.intervalOn && axis.parsedPositions == nil, "先启用固定值域和固定刻度间隔，并清空显式刻度位置。") }
                    if label == "自定义刻度数" || label == "刻度数" {
                        return require(item, axis.parsedPositions == nil && !(axis.manualRange && axis.intervalOn) && (label == "自定义刻度数" || axis.countOn), "刻度位置 > 固定值域下的刻度间隔 > 刻度数（目标数量，不保证精确个数）。")
                    }
                    if label.hasPrefix("刻度位置") { return annotate(item, "有限值自动去重排序；无有效值时回到自动配置，域外刻度不显示。") }
                case "时间轴":
                    if label != "启用时间轴" && !s.timeEnabled { return annotate(item, "先启用时间轴；关闭时保留参数但不使用。", enabled: false) }
                    if label.hasPrefix("采样间隔秒") { return require(item, !s.daily, "一天均分会按实际最长系列点数计算间隔，覆盖手动间隔。") }
                    if label == "一天均分采样" { return annotate(item, "当前实际 \(model.maxPointCount) 点；一天均分间隔 \(86400 / Double(max(1, model.maxPointCount))) 秒。") }
                    if !s.customLabels.isEmpty && label == "日期格式" { return annotate(item, "时间轴仍有效，但轴标签被类目标签覆盖。清空标签覆盖后显示时间。", enabled: false) }
                case "高密度折线 Min/Max":
                    if label.contains("targetPointCount") {
                        return annotate(item, "每系列/当前视口的目标绘制点数，含边缘邻点。不受启动门槛和分组宽度影响；分段端点与极值优先保护，可超额。" + (s.samplingEligible ? "" : s.samplingStatus))
                    }
                    if label.contains("bucketWidth") || label.contains("minimumVisiblePoints") {
                        if s.theme.lineSampling?.targetPointCount != nil {
                            return annotate(item, "目标点数模式优先；关闭“按目标点数采样”后恢复此参数，原值保留。", enabled: false)
                        }
                        return annotate(item, label.contains("minimumVisiblePoints")
                            ? "仅决定何时启动，不指定剩余点数；达到门槛后继续调小不会加强采样。" + s.samplingStatus
                            : "宽度模式：增大分组宽度通常减少绘制点数，不保证固定数量。" + s.samplingStatus)
                    }
                    if label.contains("Min/Max") || label.contains("hidesDense") { return annotate(item, s.samplingStatus) }
                    if label == "尖峰与低谷样本" { return annotate(item, "只作用于生成数据；高低峰会产生正负混合。", enabled: generated > 0) }
                case "通用主题（背景/网格/字体/标签）", "折线与数据点外观", "混合图柱体与线型外观":
                    if label.hasPrefix("title") { return require(item, !s.title.isEmpty, "先设置图表标题。") }
                    if label == "showsHorizontalGridlines" && s.primaryAxis.grid != nil { return annotate(item, "主值轴已指定网格覆盖；本项仅控制未覆盖的轴。") }
                    if label == "seriesColor" { return inheritance(item, visible.filter { $0.color == nil }.count, visible.count) }
                    if label == "lineWidth" { return inheritance(item, lines.filter { $0.style.lineWidth == nil }.count, lines.count) }
                    if label == "lineConnectionStyle" { return inheritance(item, lines.filter { $0.kind == nil && $0.style.lineConnectionStyle == nil }.count, lines.count) }
                    if label == "lineDashStyle" { return inheritance(item, lines.filter { $0.lineDashStyle == nil }.count, lines.count) }
                    if label == "showsPoints" { return inheritance(item, lines.filter { $0.style.showsPoints == nil }.count, lines.count) }
                    if label == "showsArea" { return inheritance(item, lines.filter { $0.kind == nil && $0.style.showsArea == nil }.count, lines.count) }
                    if label.hasPrefix("stackedAreaBoundaryMode") {
                        return require(item, s.model.isStacked && !areaSeries.isEmpty,
                            "正负分链统一断段优先于各系列缺测策略，支持混合线型/非面积贡献；沿基线模式保留原有准入与兼容回退。")
                    }
                    if label.hasPrefix("point") || label == "自定义 pointColor" {
                        if pointSeries.isEmpty { return annotate(item, "没有可见标记；主题/系列显示开关及降采样密度共同决定标记显示。", enabled: false) }
                        if label == "pointRadius" { return inheritance(item, pointSeries.filter { $0.style.pointRadius == nil }.count, pointSeries.count) }
                        if label == "pointSymbol" { return inheritance(item, pointSeries.filter { $0.pointSymbol == nil }.count, pointSeries.count) }
                        if label == "pointHoleColor" { return require(item, s.theme.pointHoleRadius > 0, "空心内径为 0 时不绘制内芯；内径不超过有效标记半径。") }
                        if label == "pointColor" || label == "自定义 pointColor" { return annotate(item, "显式点色优先于颜色分区、负值颜色和系列颜色；仅改变点，不改变线。") }
                    }
                    if label == "showsDataLabels" { return inheritance(item, visible.filter { $0.dataLabelsEnabled == nil }.count, visible.count) }
                    if label.hasPrefix("dataLabel") || label == "自定义 dataLabelColor" || label == "数据标签格式" {
                        if labelSeries.isEmpty { return annotate(item, "先启用主题或某系列的数据标签。", enabled: false) }
                        if label == "数据标签格式" { return inheritance(item, labelSeries.filter { $0.valueFormat == nil }.count, labelSeries.count) }
                        return annotate(item, "可见类目 × 可见系列数超过 dataLabelMaxMarkCount 时隐藏；密集降采样也可隐藏标签。0 表示全部隐藏。")
                    }
                    if label == "seriesShadow" { return inheritance(item, visible.filter { $0.shadow == nil }.count, visible.count) }
                case "面积渐变":
                    if areaSeries.isEmpty { return annotate(item, "没有可见面积；先启用主题 showsArea 或系列面积填充。", enabled: false) }
                    if label != "自定义渐变（需 showsArea）" && !s.gradient { return annotate(item, "先启用自定义渐变。", enabled: false) }
                    let inherits = areaSeries.filter { $0.style.areaGradientColors == nil && !($0.colorZones?.zones.contains { $0.areaGradientColors != nil } ?? false) }.count
                    return inheritance(item, inherits, areaSeries.count)
                case "图例布局":
                    if label != "isEnabled" && !s.theme.legend.isEnabled { return annotate(item, "先启用图例 isEnabled。", enabled: false) }
                    if ["maxRows", "maxHeight"].contains(label) { return require(item, !s.expandLegend, "展开完整图例时不使用行数/高度上限；仍保护最小绘图区。") }
                    if label == "maxWidth" { return require(item, [.left, .right].contains(s.theme.legend.position), "仅左右图例使用最大宽度。") }
                case "阈值参考线":
                    if label != "启用参考线" && !s.lineEnabled { return annotate(item, "先启用参考线。", enabled: false) }
                    if label == "参考线值轴" { return require(item, s.dualAxis && s.kind != .bar, "未开启次值轴时按主轴 0 绘制；原轴选择保留。") }
                case "区间色带":
                    if label != "启用色带" && !s.bandEnabled { return annotate(item, "先启用色带。", enabled: false) }
                    if label == "色带值轴" { return require(item, s.dualAxis && s.kind != .bar, "未开启次值轴时按主轴 0 绘制；原轴选择保留。") }
                    if label == "色带起点" || label == "色带终点" { return annotate(item, "起止相反时按较小值到较大值绘制；相等时面积为零。") }
                case "交互与弹窗行为":
                    if ["最大缩放倍率", "最小可见类目", "缩放轴", "惯性", "边界回弹"].contains(label) {
                        return require(item, s.interaction.zoom || (s.kind != .line && s.theme.columnSpacing?.columnWidth != nil), "缩放关闭时手势不使用本项；固定柱宽的自动滚动除外。")
                    }
                    if label == "双向准线" || label.hasPrefix("准线") { return require(item, s.interaction.crosshair, "先开启十字准线；不依赖弹窗开关。") }
                    let presentationFields = ["提示内容布局", "提示逐点规则预设", "提示图标尺寸", "提示行间距", "提示列间距", "提示组间距", "提示组分隔线"]
                    if presentationFields.contains(label) {
                        guard builtinPopup && hasPopup else { return annotate(item, "仅内置提示使用展示规则；不修改图形和命中数据。", enabled: false) }
                        if label == "提示内容布局" { return annotate(item, "text 保持原有文本；columns 提供图标、名称/数值分栏和超高滚动。") }
                        if label == "提示逐点规则预设" { return annotate(item, "规则只修改展示。聚合项不套用单点索引规则；仅名称行不参与小计。") }
                        return require(item, s.interaction.tooltipPresentation.layout == .columns, "先选择 columns 布局。")
                    }
                    let sampleFields = ["提示取值索引偏移", "提示逐系列偏移（ID:偏移，逗号分隔）", "提示越界策略", "提示显示取值来源", "提示取值来源模板"]
                    if sampleFields.contains(label) {
                        guard builtinPopup && hasPopup else { return annotate(item, "仅内置提示使用取值偏移；命中回调仍为当前采样。", enabled: false) }
                        if label == "提示取值来源模板" { return require(item, s.interaction.tooltipSampleSelection.showsSourceLabel, "先启用提示显示取值来源；{key} 取代为来源类目。") }
                        return annotate(item, "-1 为前值，逐系列 ID 覆盖全局偏移。越界 omit 隐藏、clamp 取端点、current 保留当前；缺测不向前搜索。实际聚合时保留当前桶。")
                    }
                    let groupingFields = ["按业务组显示提示", "显示组小计", "提示隐藏零值", "提示排除系列 ID（逗号分隔）", "未分组标题", "小计标题"]
                    if groupingFields.contains(label) {
                        guard builtinPopup && hasPopup else { return annotate(item, "仅内置提示使用分组与过滤；不改变命中回调的数据。", enabled: false) }
                        if label == "小计标题" && !s.interaction.tooltipGrouping.showsGroupSubtotals {
                            return annotate(item, "先开启显示组小计。", enabled: false)
                        }
                        if ["显示组小计", "未分组标题", "小计标题"].contains(label) {
                            return annotate(item, "先开启按业务组显示；小计仅汇总同单位、值轴、格式的至少两条原始采样，保留正负号。聚合数据不自动小计。", enabled: s.interaction.tooltipGrouping.groupsByBusinessID)
                        }
                        return annotate(item, "共享提示可同时查看多个系列；过滤只影响提示，不改变图形与回调。")
                    }
                    if label == "共享提示" { return require(item, builtinPopup, "共享提示只使用内置模式；自定义内容/位置回调使用单点命中。") }
                    if ["表头模板", "数值后缀", "小数位"].contains(label) {
                        if !hasPopup || !builtinPopup { return annotate(item, "仅内置弹窗文本使用全局模板。", enabled: false) }
                        if label != "表头模板" { return inheritance(item, visible.filter { $0.valueFormat == nil }.count, visible.count) }
                    }
                    if label == "容器弹窗" { return annotate(item, "同时控制 Demo 的主题锚点与容器弹窗；位置回调仍会报告命中位置。") }
                case "弹窗外观":
                    if !hasPopup { return annotate(item, "弹窗关闭或位置回调接管时，不绘制容器弹窗。", enabled: false) }
                    if label == "fixedTopInset" { return require(item, s.tooltipTheme.position == .fixedTop, "position 选择 fixedTop 时生效。") }
                    if label == "fixedTopUsesPlotArea" { return require(item, s.tooltipTheme.position == .fixedTop, "仅 fixedTop 生效：限制在绘图区内，避开标题/图例/轴标签；不预留提示栏。") }
                    if label == "showsArrow" || label == "gap" || label.hasPrefix("arrowSize") {
                        guard s.tooltipTheme.position == .automatic else { return annotate(item, "固定顶部提示隐藏箭头，使用 fixedTopInset 定位。", enabled: false) }
                        if label.hasPrefix("arrowSize") { return require(item, s.tooltipTheme.showsArrow, "先启用 showsArrow。") }
                    }
                default:
                    break
                }
                return item
            }
            return .init(title: section.title, items: items)
        }
        var status: [Item] = [
            .note(label: "灰色项表示当前条件不满足，原因显示在控件下方；禁用不清空原值。系列覆盖 > 图形 kind > 全局主题。"),
            .note(label: "生成数据 \(generated) 条 / 数据覆盖 \(s.seriesCount - generated) 条 · 实际最长 \(model.maxPointCount) 点 · 可见系列 \(visible.count) 条。"),
            .note(label: "所有场景按钮从默认配置重新开始。普通属性、图例点击和总览/区间定位不会重新生成配置。")
        ]
        if model.isStacked && !areaSeries.isEmpty && visible.count > 1 {
            let boundaryMode = s.theme.stackedAreaBoundaryMode.rawValue
            if s.theme.stackedAreaBoundaryMode == .diverging {
                status.append(.note(label: "堆叠面积当前边界模式：\(boundaryMode)。按实际过零位置分片，共享正负边界；任一参与系列缺测时同组统一断段，优先于 connectNulls/gapPolicy。marker 与命中保留原始有效点，描边收在各自面积内。"))
                status.append(.note(label: "正负分链百分比：先插值原始贡献再归一化；零分母采样断开。精度/预算不足时整组改用共同直线，保持正负总跨度 100%，不回退独立边界。"))
            } else {
                status.append(.note(label: "堆叠面积当前边界模式：\(boundaryMode)。沿基线叠加时继承下层形态，已解析的前层换链沿正负表面衔接，描边收在各自面积内；零值采样仍属正链。数据点标记独立显示，可关闭 showsPoints 检查接缝。"))
                if model.stacking == .percent {
                    status.append(.note(label: "自动百分比：同链按正负份额绝对值总和共同归一化，正负总跨度为 100%，各侧不超过 ±100%。同链有非面积、缺测分段不一致、零分母或无法满足曲线精度时整链兼容回退；原始采样与命中不变。"))
                }
            }
        }
        if s.theme.stackedAreaBoundaryMode != .diverging && model.isStacked && !areaSeries.isEmpty && visible.count > 1 && visible.contains(where: { series in
            series.data.contains(where: { !$0.isFinite }) || (series.data.contains(where: { $0 < 0 }) && series.data.contains(where: { $0 > 0 }))
        }) {
            status.append(.note(label: "复杂堆叠面积：沿基线模式保留缺测两侧的实际轮廓，仅在缺口直连正负基准并叠加自身厚度。下层仍断开、不补业务点；缺口不保证全域无缝。"))
        }
        return [.init(title: "配置优先级与当前状态", items: status)] + decorated
    }

    private static func rangeReason(_ axis: DemoAxisSettings) -> String {
        guard axis.manualRange else { return "先开启固定范围；关闭时自动计算值域。" }
        return "生效范围 \(axis.normalizedRange.lowerBound)...\(axis.normalizedRange.upperBound)：上下界反向时交换，相等时扩展 0.001。"
    }
}
