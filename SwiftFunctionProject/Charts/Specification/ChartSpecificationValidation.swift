import Foundation

public extension ChartSpecification {
    /// 检查版本、唯一身份、引用、缺测、坐标和样式数值；不依赖任何渲染引擎。
    /// 返回所有可定位的问题，空数组表示通用模型有效，不代表某后端一定支持。
    func validationIssues() -> [ChartSpecificationIssue] {
        var issues: [ChartSpecificationIssue] = []
        func invalid(_ path: String, _ message: String) {
            issues.append(.init(code: .invalidInput, path: path, message: message))
        }
        func isBlank(_ value: String) -> Bool { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func identifiers(_ values: [String], _ path: String) {
            var seen = Set<String>()
            for (index, value) in values.enumerated() {
                if isBlank(value) || !seen.insert(value).inserted {
                    invalid("\(path)[\(index)].id", "身份必须非空且唯一，不能使用显示名称自动去重")
                }
            }
        }
        func finite(_ value: Double?, _ path: String) {
            if let value, !value.isFinite { invalid(path, "必须是有限数值；缺测请使用 nil") }
        }
        func dimension(_ value: Double?, _ path: String, positive: Bool = false) {
            if let value, !value.isFinite || (positive ? value <= 0 : value < 0) {
                invalid(path, positive ? "必须是正有限值" : "必须是非负有限值")
            }
        }
        func color(_ value: ChartRGBA?, _ path: String) {
            if let value, [value.red, value.green, value.blue, value.alpha].contains(where: { !$0.isFinite || !(0...1).contains($0) }) {
                invalid(path, "sRGB/alpha 分量必须在 0...1 内")
            }
        }
        func requiresV4(_ path: String) {
            if schemaVersion < 4 { invalid(path, "轴展示扩展要求 schemaVersion 4；不能静默降级") }
        }
        func axisAppearance(_ value: ChartAxisAppearance, _ path: String) {
            color(value.labelColor, path + ".labelColor"); color(value.lineColor, path + ".lineColor")
            dimension(value.lineWidth, path + ".lineWidth")
            dimension(value.labelFontSize, path + ".labelFontSize", positive: true)
            if value.labelFontWeight != nil { requiresV4(path + ".labelFontWeight") }
        }
        if !(1...Self.latestSchemaVersion).contains(schemaVersion) {
            issues.append(.init(code: .unsupportedVersion, path: "schemaVersion", message: "只支持版本 1...\(Self.latestSchemaVersion)"))
        }
        if stackedAreaBoundary != .independent {
            if schemaVersion == 1 { invalid("stackedAreaBoundary", "非独立边界要求 schemaVersion 2 或更高；不能静默降级到 v1") }
            if stacking == .none { invalid("stackedAreaBoundary", "非独立边界要求启用数学堆叠") }
            if !series.contains(where: { $0.mark != .bar && $0.stackID != nil }) {
                invalid("stackedAreaBoundary", "非独立边界需要带 stackID 的线/面积系列；柱族不适用")
            }
        }
        if isBlank(id) { invalid("id", "图表 ID 必须非空") }
        identifiers(valueAxes.map(\.id), "valueAxes")
        identifiers(groups.map(\.id), "groups")
        identifiers(series.map(\.id), "series")
        if valueAxes.isEmpty { invalid("valueAxes", "至少声明一个值轴") }
        axisAppearance(domainAppearance, "domainAppearance")
        for (index, axis) in valueAxes.enumerated() {
            let path = "valueAxes[\(index)]"
            finite(axis.minimum, path + ".minimum"); finite(axis.maximum, path + ".maximum")
            if let minimum = axis.minimum, let maximum = axis.maximum, minimum >= maximum {
                invalid(path, "minimum 必须小于 maximum；反向请使用 isReversed")
            }
            axisAppearance(axis.appearance, path + ".appearance")
        }
        var categoryIDs = Set<String>()
        if case .categories(let categories) = domain {
            identifiers(categories.map(\.id), "domain.categories")
            categoryIDs = Set(categories.map(\.id))
        }
        if case .percentOfFixedTotal(let total) = stacking, !total.isFinite || total <= 0 {
            invalid("stacking", "固定百分比分母必须是正有限值")
        }
        if let interval = categoryLabelInterval {
            requiresV4("categoryLabelInterval")
            if interval <= 0 { invalid("categoryLabelInterval", "类目标签候选间隔须为正整数；自动请使用 nil") }
            if case .categories = domain {} else { invalid("categoryLabelInterval", "仅适用于类目域；不是数值/时间刻度间隔") }
        }
        for (index, axis) in valueAxes.enumerated() {
            let path = "valueAxes[\(index)]"
            if let positions = axis.tickPositions {
                requiresV4(path + ".tickPositions")
                var previous = -Double.infinity
                for (offset, position) in positions.enumerated() {
                    if !position.isFinite || position <= previous {
                        invalid(path + ".tickPositions[\(offset)]", "刻度必须是严格递增的有限数值；不静默排序或去重")
                    }
                    previous = position
                }
            }
            if let format = axis.labelFormat {
                requiresV4(path + ".labelFormat")
                if !(0...12).contains(format.number.maximumFractionDigits) {
                    invalid(path + ".labelFormat.number.maximumFractionDigits", "小数位范围为 0...12；不接受旧业务特殊值 100")
                }
            }
        }
        let axisIDs = Set(valueAxes.map(\.id)), groupIDs = Set(groups.map(\.id))
        // 使用复合数组键，避免业务 ID 中包含分隔符时发生字符串拼接碰撞。
        var stackUnits: [[String]: String] = [:]
        for (index, row) in series.enumerated() {
            let path = "series[\(index)]"
            if !axisIDs.contains(row.valueAxisID) { invalid(path + ".valueAxisID", "引用的值轴不存在") }
            if let groupID = row.groupID, !groupIDs.contains(groupID) { invalid(path + ".groupID", "引用的业务组不存在") }
            if let stackID = row.stackID {
                if isBlank(stackID) { invalid(path + ".stackID", "显式堆叠 ID 不可为空；独立系列使用 nil") }
                if stacking != .none {
                    let key = [row.valueAxisID, row.mark == .bar ? "bar" : "line", stackID]
                    let unit = row.unit ?? ""
                    if let existing = stackUnits[key], existing != unit { invalid(path + ".unit", "同一数学堆叠组不能混合不同单位") }
                    stackUnits[key] = unit
                }
            }
            if !(0...12).contains(row.valuePresentation.maximumFractionDigits) {
                invalid(path + ".valuePresentation.maximumFractionDigits", "小数位范围为 0...12；旧值 100 需要迁移规则")
            }
            if case .connectUpTo(let count) = row.missingValues {
                if count < 0 { invalid(path + ".missingValues", "缺测类目数不能为负") }
                if case .categories = domain {} else { invalid(path + ".missingValues", "按缺测类目数连接只适用于类目坐标") }
            }
            let appearance = row.appearance
            color(appearance.color, path + ".appearance.color")
            color(appearance.negativeColor, path + ".appearance.negativeColor")
            if let config = appearance.valueColorZones {
                let zonePath = path + ".appearance.valueColorZones"
                if schemaVersion < 3 { invalid(zonePath, "值轴颜色分区要求 schemaVersion 3；不能静默降级") }
                if config.zones.isEmpty { invalid(zonePath + ".zones", "分区至少一段；关闭请使用 nil") }
                var previous = -Double.infinity
                for (zoneIndex, zone) in config.zones.enumerated() {
                    let itemPath = zonePath + ".zones[\(zoneIndex)]"
                    if let upper = zone.upperBound {
                        if !upper.isFinite || upper <= previous {
                            invalid(itemPath + ".upperBound", "阈值必须是严格递增的有限数值")
                        }
                        previous = upper
                    } else if zoneIndex != config.zones.count - 1 {
                        invalid(itemPath + ".upperBound", "nil 上界只允许出现在最后一段")
                    }
                    color(zone.color, itemPath + ".color")
                }
            }
            dimension(appearance.lineWidth, path + ".appearance.lineWidth")
            dimension(appearance.markerRadius, path + ".appearance.markerRadius")
            switch appearance.areaFill {
            case .solid(let c): color(c, path + ".appearance.areaFill")
            case .verticalGradient(let top, let bottom):
                color(top, path + ".appearance.areaFill.top"); color(bottom, path + ".appearance.areaFill.bottom")
            case nil: break
            }
            if appearance.areaFill != nil && row.mark != .area { invalid(path + ".appearance.areaFill", "面积填充仅用于 area 图元") }
            identifiers(row.samples.map(\.id), path + ".samples")
            var coordinates = Set<ChartCoordinate>()
            var previousNumericCoordinate: Double?
            for (sampleIndex, sample) in row.samples.enumerated() {
                let samplePath = path + ".samples[\(sampleIndex)]"
                finite(sample.value, samplePath + ".value")
                if !coordinates.insert(sample.coordinate).inserted { invalid(samplePath + ".coordinate", "同系列坐标不可重复") }
                var numericCoordinate: Double?
                switch (domain, sample.coordinate) {
                case (.categories, .category(let categoryID)):
                    if !categoryIDs.contains(categoryID) { invalid(samplePath + ".coordinate", "引用的类目不存在") }
                case (.numeric, .number(let value)), (.time, .unixSeconds(let value)):
                    numericCoordinate = value
                default: invalid(samplePath + ".coordinate", "采样坐标类型与 domain 不匹配")
                }
                if let value = numericCoordinate {
                    finite(value, samplePath + ".coordinate")
                    if let previous = previousNumericCoordinate, value <= previous { invalid(samplePath + ".coordinate", "数值/时间坐标须严格递增") }
                    previousNumericCoordinate = value
                }
            }
        }
        issues.append(contentsOf: annotationValidationIssues())
        issues.append(contentsOf: interactionValidationIssues())
        return issues
    }

    /// 输入无效时抛出 ChartSpecificationError；可在后台调用，不会修改源模型。
    func validate() throws {
        let issues = validationIssues()
        if !issues.isEmpty { throw ChartSpecificationError(issues: issues) }
    }
}
