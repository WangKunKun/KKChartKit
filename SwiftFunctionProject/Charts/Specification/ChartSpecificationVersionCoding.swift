import Foundation

// 顶层版本边界：v1/v2/v3 输出结构不变；新增保留键不能通过旧版本静默透传。
extension ChartSpecification {
    private enum Keys: String, CodingKey {
        case schemaVersion, id, title, orientation, domain, domainAppearance, valueAxes
        case groups, series, stacking, showsLegend, stackedAreaBoundary, categoryLabelInterval
    }

    private enum SeriesKeys: String, CodingKey { case appearance }
    private enum AppearanceKeys: String, CodingKey { case valueColorZones }

    private enum AxisKeys: String, CodingKey { case appearance, tickPositions, labelFormat }
    private enum AxisAppearanceKeys: String, CodingKey { case labelFontWeight }

    /// 解码版本及结构；完整输入约束仍由 decodeJSON/validate 检查。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard (1...Self.latestSchemaVersion).contains(schemaVersion) else {
            throw ChartSpecificationError(issues: [.init(code: .unsupportedVersion, path: "schemaVersion",
                message: "只支持版本 1...\(Self.latestSchemaVersion)")])
        }
        if schemaVersion == 1 {
            guard !c.contains(.stackedAreaBoundary) else {
                throw ChartSpecificationError(issues: [.init(code: .invalidInput, path: "stackedAreaBoundary",
                    message: "v1 不允许边界字段；请明确升级为 schemaVersion 2")])
            }
            stackedAreaBoundary = .independent
        } else {
            // 缺字段、null、未知枚举都报解码错误，不将损坏的 v2 当作 independent。
            stackedAreaBoundary = try c.decode(ChartStackedAreaBoundary.self, forKey: .stackedAreaBoundary)
        }
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        orientation = try c.decode(ChartOrientation.self, forKey: .orientation)
        domain = try c.decode(ChartDomain.self, forKey: .domain)
        if schemaVersion < 4 {
            func reject(_ path: String) throws {
                throw ChartSpecificationError(issues: [.init(code: .invalidInput, path: path,
                    message: "轴展示扩展要求 schemaVersion 4；旧版本不允许此字段（包括 null）")])
            }
            if c.contains(.categoryLabelInterval) { try reject("categoryLabelInterval") }
            let domainStyle = try c.nestedContainer(keyedBy: AxisAppearanceKeys.self, forKey: .domainAppearance)
            if domainStyle.contains(.labelFontWeight) { try reject("domainAppearance.labelFontWeight") }
            var axes = try c.nestedUnkeyedContainer(forKey: .valueAxes)
            while !axes.isAtEnd {
                let path = "valueAxes[\(axes.currentIndex)]"
                let axis = try axes.nestedContainer(keyedBy: AxisKeys.self)
                for key in [AxisKeys.tickPositions, .labelFormat] where axis.contains(key) {
                    try reject(path + "." + key.rawValue)
                }
                let style = try axis.nestedContainer(keyedBy: AxisAppearanceKeys.self, forKey: .appearance)
                if style.contains(.labelFontWeight) { try reject(path + ".appearance.labelFontWeight") }
            }
        }
        categoryLabelInterval = try c.decodeIfPresent(Int.self, forKey: .categoryLabelInterval)
        domainAppearance = try c.decode(ChartAxisAppearance.self, forKey: .domainAppearance)
        valueAxes = try c.decode([ChartAxisSpecification].self, forKey: .valueAxes)
        groups = try c.decode([ChartGroupSpecification].self, forKey: .groups)
        if schemaVersion < 3 {
            // 检查键的存在性而非值，连 null 也不能冒充旧版本输入；不通过 userInfo 传递可变状态。
            var rows = try c.nestedUnkeyedContainer(forKey: .series)
            while !rows.isAtEnd {
                let index = rows.currentIndex
                let row = try rows.nestedContainer(keyedBy: SeriesKeys.self)
                if row.contains(.appearance) {
                    let appearance = try row.nestedContainer(keyedBy: AppearanceKeys.self, forKey: .appearance)
                    if appearance.contains(.valueColorZones) {
                        throw ChartSpecificationError(issues: [.init(code: .invalidInput,
                            path: "series[\(index)].appearance.valueColorZones",
                            message: "值轴颜色分区要求 schemaVersion 3；旧版本不允许此字段（包括 null）")])
                    }
                }
            }
        }
        series = try c.decode([ChartSeriesSpecification].self, forKey: .series)
        stacking = try c.decode(ChartStackingPolicy.self, forKey: .stacking)
        showsLegend = try c.decode(Bool.self, forKey: .showsLegend)
    }

    /// 不允许静默降级丢失边界/分区/轴展示配置，即使直接使用 JSONEncoder 也必须校验。
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encode(orientation, forKey: .orientation)
        try c.encode(domain, forKey: .domain)
        try c.encode(domainAppearance, forKey: .domainAppearance)
        try c.encodeIfPresent(categoryLabelInterval, forKey: .categoryLabelInterval)
        try c.encode(valueAxes, forKey: .valueAxes)
        try c.encode(groups, forKey: .groups)
        try c.encode(series, forKey: .series)
        try c.encode(stacking, forKey: .stacking)
        try c.encode(showsLegend, forKey: .showsLegend)
        if schemaVersion >= 2 { try c.encode(stackedAreaBoundary, forKey: .stackedAreaBoundary) }
    }
}
