import Foundation

/// 内置提示的内容布局，不改变命中方式或手势。
public enum ChartTooltipLayout: String, Codable, CaseIterable, Sendable { case text, columns }
/// automatic 跟随当前锚点；fixedTop 固定顶部但仍随命中更新内容，不锁定选择。
public enum ChartTooltipPosition: String, Codable, CaseIterable, Sendable { case automatic, fixedTop }
/// 偏移越界时的取值政策；缺测始终省略，不搜索下一个有效采样。
public enum ChartTooltipBoundaryPolicy: String, Codable, CaseIterable, Sendable { case omit, clamp, current }

/// 提示取值规则。offset 按域中的类目槽位（非稀疏 samples 数组下标）计数。
/// 不改变当前表头、准线、命中身份或原始数值。实际聚合桶不应用单点偏移。
public struct ChartTooltipSampleSelection: Codable, Equatable, Sendable {
    public var offset: Int = 0
    /// 稳定系列 ID 覆盖；显式 0 表示该系列仍取当前值。
    public var offsetsBySeriesID: [String: Int] = [:]
    public var boundaryPolicy: ChartTooltipBoundaryPolicy = .omit
    public var showsSourceLabel = true
    /// 仅取值位置变化时显示；只替换 {key}，不执行脚本或格式化回调。
    public var sourceLabelTemplate = "取值 {key}"
    public init() {}
}

/// 逐系列提示行覆盖。nil 标题沿用宿主标题或系列名，空标题有效；不改变图形、图例或命中。
/// 图片及逐采样动态覆盖由宿主运行时负责，不序列化进本类型。
public struct ChartTooltipSeriesRule: Codable, Equatable, Sendable {
    public var title: String?
    public var isHidden: Bool
    public var hidesValue: Bool
    public init(title: String? = nil, isHidden: Bool = false, hidesValue: Bool = false) {
        self.title = title; self.isHidden = isHidden; self.hidesValue = hidesValue
    }
}

/// schema v6 的内置提示意图。仅作用于提示展示，不提供业务小计或修改系列格式。
/// ChartSpecification.tooltip == nil 表示由宿主配置；非 nil 时这些字段完整覆盖宿主的内容规则。
/// 图片/provider、颜色/字体、手势仍属于运行时；核心仅依赖 Foundation，可复制跨线程传递。
public struct ChartTooltipSpecification: Codable, Equatable, Sendable {
    public var isEnabled = true
    public var layout: ChartTooltipLayout = .text
    public var position: ChartTooltipPosition = .automatic
    /// nil 不加表头；{key} 始终来自当前命中，不来自偏移后的取值点。
    public var headerTemplate: String?
    /// 过滤精确为零的展示取值；不将负值或缺测视为零。
    public var hidesZeroValues = false
    public var seriesRules: [String: ChartTooltipSeriesRule] = [:]
    public var sampleSelection = ChartTooltipSampleSelection()
    public init() {}
}

/// 图例位于图表的屏幕方向，不随水平图的逻辑轴交换。
public enum ChartLegendPlacement: String, Codable, CaseIterable, Sendable { case top, bottom, left, right }
/// 上下图例行内对齐；左右图例仍为原生单列。
public enum ChartLegendRowAlignment: String, Codable, CaseIterable, Sendable { case leading, center, trailing }
/// expand 按内容测量但仍保护最小绘图区；不会自动改变宿主视图尺寸。
public enum ChartLegendOverflowPolicy: String, Codable, CaseIterable, Sendable { case scroll, expand }

/// schema v6 图例布局。总开关仍为 showsLegend，各系列仍由 showsInLegend/isVisible 控制。
/// 不重新排序系列、不改变堆叠；尺寸为 point。图片与自定义符号不进入中立描述。
public struct ChartLegendSpecification: Codable, Equatable, Sendable {
    public var position: ChartLegendPlacement = .bottom
    public var alignment: ChartLegendRowAlignment = .center
    public var overflow: ChartLegendOverflowPolicy = .scroll
    public var maxRows: Int = 3
    public var maxHeight: Double = 120
    public var maxWidth: Double = 140
    public var allowsToggling = true
    /// 相邻 groupID 改变时换行，不隐式排序或生成分组小计。
    public var startsNewRowPerGroup = false
    /// 稳定系列 ID 对应标题，空标题有效；不改变系列名或提示名称。
    public var titlesBySeriesID: [String: String] = [:]
    public init() {}
}

extension ChartSpecification {
    func interactionValidationIssues() -> [ChartSpecificationIssue] {
        var issues: [ChartSpecificationIssue] = []
        func invalid(_ path: String, _ message: String) {
            issues.append(.init(code: .invalidInput, path: path, message: message))
        }
        let ids = Set(series.map(\.id))
        func references<T>(_ values: [String: T], _ path: String) {
            for id in values.keys.sorted() where id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !ids.contains(id) {
                invalid(path + "[\(id)]", "必须引用存在的非空稳定系列 ID")
            }
        }
        if let tooltip {
            if schemaVersion < 6 { invalid("tooltip", "提示配置要求 schemaVersion 6；降级前必须移除配置") }
            references(tooltip.seriesRules, "tooltip.seriesRules")
            references(tooltip.sampleSelection.offsetsBySeriesID, "tooltip.sampleSelection.offsetsBySeriesID")
            // A slot offset has no portable semantics for numeric/time domains. Never pretend it is elapsed time.
            if case .categories = domain {} else if tooltip.sampleSelection != .init() {
                invalid("tooltip.sampleSelection", "取值偏移配置仅适用于类目域，不代表数值距离或时间间隔")
            }
        }
        if let legend {
            if schemaVersion < 6 { invalid("legend", "图例布局要求 schemaVersion 6；降级前必须移除配置") }
            if legend.maxRows <= 0 { invalid("legend.maxRows", "行数必须为正整数") }
            for (key, value) in [("maxHeight", legend.maxHeight), ("maxWidth", legend.maxWidth)] {
                if !value.isFinite || value < 0 || value > 1e9 { invalid("legend." + key, "尺寸必须有限且在 0...1e9 内") }
            }
            references(legend.titlesBySeriesID, "legend.titlesBySeriesID")
        }
        return issues
    }
}
