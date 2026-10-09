import UIKit

/// 轴系内置提示的布局；默认保持原有多行文本。columns 将名称和数值分别对齐。
public enum CartesianTooltipLayout: String, CaseIterable {
    case text
    case columns
}

/// 单行展示覆盖，不修改 datum、图形、准线或命中回调。
public struct CartesianTooltipRowStyle {
    /// nil 沿用系列名称；空字符串允许隐藏名称。聚合区间说明仍保留。
    public var title: String?
    /// 仅 columns 布局显示；图片来源由调用方负责，不查找主 Bundle 资源。
    public var image: UIImage?
    /// 从提示移除该行；与系列 isVisible 无关。
    public var isHidden: Bool
    /// 仅显示名称；该行不参与组小计，避免通过小计泄露被隐藏的数值。
    public var hidesValue: Bool

    public init(title: String? = nil, image: UIImage? = nil,
                isHidden: Bool = false, hidesValue: Bool = false) {
        self.title = title; self.image = image
        self.isHidden = isHidden; self.hidesValue = hidesValue
    }
}

/// 富内容提示配置。UI 和 provider 均在主线程使用。
/// provider 应为无副作用的展示函数，避免强捕获 chart；nil 返回值使用默认行。
/// 全局零值/系列过滤先执行，随后才调用 provider。聚合项请依据 sourceRange 判断，
/// 不要把 categoryIndex 当作原始采样索引；聚合项不会伪造单点名称或前一采样值。
public struct CartesianTooltipPresentation {
    public var layout: CartesianTooltipLayout = .text
    public var rowStyleProvider: ((CartesianDatum) -> CartesianTooltipRowStyle?)?
    /// 正方形图标边长，默认 16 pt。非有限/负数在布局时使用默认值/0。
    public var iconSize: CGFloat = 16
    /// columns 行间距，单位 pt。
    public var rowSpacing: CGFloat = 4
    /// columns 图标/名称/数值之间的水平间距，单位 pt。
    public var columnSpacing: CGFloat = 10
    /// columns 业务组之间的间距，单位 pt。
    public var sectionSpacing: CGFloat = 8
    /// columns 相邻分组之间显示分隔线。
    public var showsSectionSeparators = true
    public init() {}
}

/// 过滤、格式化后的只读展示快照；text 与 columns 使用相同内容，可供外部 UI 复用。
/// 本类型不拥有图表或模型。全过滤时 make 返回 nil，不留下空标题/分组/小计。
public struct CartesianTooltipContent {
    public struct Row {
        public let title: String
        public let value: String?
        public let image: UIImage?
        /// 小计为 nil；普通行保留未经展示覆盖的命中数据。
        public let datum: CartesianDatum?
        /// 实际展示取值的快照；偏移时索引可能与 datum 不同，小计为 nil。
        public let displayedDatum: CartesianDatum?
        public let sourceLabel: String?
        public var isSubtotal: Bool { datum == nil }
        public var text: String { title + (value.map { ": " + $0 } ?? "") }
    }
    public struct Section {
        public let id: String?
        public let title: String?
        public let rows: [Row]
    }
    public let header: String?
    public let sections: [Section]

    /// 图片没有文本替代内容；行名称即其可访问语义。
    public var text: String {
        var lines = header.map { [$0] } ?? []
        for section in sections {
            if let title = section.title { lines.append(title) }
            lines.append(contentsOf: section.rows.map { (section.title == nil ? "" : "  ") + $0.text })
        }
        return lines.joined(separator: "\n")
    }

    public static func make(data: [CartesianDatum], options: HYMChartTooltipTextOptions = .init(),
                            presentation: CartesianTooltipPresentation = .init(),
                            header: String? = nil) -> Self? {
        make(samples: data.map { .init(hitDatum: $0, displayedDatum: $0) }, options: options,
             presentation: presentation, header: header)
    }

    /// 外部 UI 可复用取值解析后的 samples；header 仍来自当前命中类目。
    public static func make(samples: [CartesianTooltipSample], options: HYMChartTooltipTextOptions = .init(),
                            presentation: CartesianTooltipPresentation = .init(), header: String? = nil) -> Self? {
        let rows: [Row] = samples.compactMap { sample in
            let datum = sample.hitDatum
            let displayed = sample.displayedDatum
            guard datum.seriesID == displayed.seriesID else { return nil }
            guard !options.cartesian.excludedSeriesIDs.contains(datum.seriesID),
                  !options.cartesian.hidesZeroValues || displayed.displayValue != 0 else { return nil }
            let style = presentation.rowStyleProvider?(datum) ?? .init()
            guard !style.isHidden else { return nil }
            let detail = datum.timeBucket.map { " · " + $0.detailLabel } ?? ""
            let axis = datum.yAxisIndex == 1 ? " (右轴)" : ""
            let value = displayed.valueFormat != nil ? displayed.formattedValue
                : CartesianDatumText.value(displayed.displayValue, unit: displayed.unit, options: options)
            let source = !style.hidesValue ? sample.sourceLabel.map { " · " + $0 } ?? "" : ""
            return Row(title: (style.title ?? datum.name) + detail + source + (style.hidesValue ? axis : ""),
                       value: style.hidesValue ? nil : value + axis, image: style.image, datum: datum,
                       displayedDatum: displayed, sourceLabel: sample.sourceLabel)
        }
        guard !rows.isEmpty else { return nil }
        let interval = rows.first?.datum?.timeBucket?.intervalLabel
        var headers = interval.map { [$0] } ?? []
        if let template = options.header, let header {
            let title = template.replacingOccurrences(of: "{key}", with: header)
            if title != interval { headers.append(title) }
        }
        var sections: [Section] = []
        if options.cartesian.groupsByBusinessID {
            // 用索引归组，provider 每条数据只执行一次；同名不同 ID 的组保持独立。
            var ids: [String?] = []
            var groupedRows: [[Row]] = []
            for row in rows {
                let id = row.datum?.groupID
                if let index = ids.firstIndex(of: id) { groupedRows[index].append(row) }
                else { ids.append(id); groupedRows.append([row]) }
            }
            for (index, id) in ids.enumerated() {
                var groupRows = groupedRows[index]
                guard let first = groupRows.first?.datum else { continue }
                let title = id.map { first.groupName.flatMap { $0.isEmpty ? nil : $0 } ?? $0 }
                    ?? options.cartesian.ungroupedTitle
                let subtotalData = groupRows.filter { $0.value != nil }.compactMap(\.displayedDatum)
                let group = CartesianTooltipGrouping.Group(id: id, rows: subtotalData)
                if options.cartesian.showsGroupSubtotals,
                   let value = CartesianTooltipGrouping.subtotalValue(group, options: options) {
                    groupRows.append(Row(title: options.cartesian.subtotalTitle, value: value, image: nil,
                                         datum: nil, displayedDatum: nil, sourceLabel: nil))
                }
                sections.append(Section(id: id, title: title, rows: groupRows))
            }
        } else { sections = [Section(id: nil, title: nil, rows: rows)] }
        return Self(header: headers.isEmpty ? nil : headers.joined(separator: "\n"), sections: sections)
    }
}
