import UIKit

/// OC 可持有的不可变通用描述快照。JSON 是跨语言边界，不是 Highcharts options。
/// 解码/编码可在后台完成；nativeChartKind 和图表配置须在主线程调用。
@objcMembers public final class HYMChartSpecificationDocument: NSObject {
    @nonobjc public let specification: ChartSpecification
    public var identifier: String { specification.id }

    /// Swift 入口复制值语义快照，输入无效时抛出带字段路径的错误。
    @nonobjc public init(specification: ChartSpecification) throws {
        try specification.validate()
        self.specification = specification
        super.init()
    }

    /// OC 的 initWithJSONData:error:；JSON 解码或模型校验失败时返回 NSError。
    @objc(initWithJSONData:error:)
    public init(jsonData: Data) throws {
        specification = try ChartSpecification.decodeJSON(jsonData)
        super.init()
    }

    /// 返回包含 schemaVersion 的 JSON；不存在计算缓存、UIView 或平台颜色对象。
    @objc(JSONDataWithError:)
    public func jsonData() throws -> Data { try specification.jsonData() }

    /// 检查原生能力并返回应创建的 renderer 类型；不支持时不猜测其他图形类型。
    @nonobjc
    public func nativeChartKind() throws -> HYMCartesianChartKind {
        try HYMChartsSpecificationAdapter().makeConfiguration(from: specification).kind
    }

    /// OC 一步创建并配置正确类型的原生图表；返回 bridge，调用方持有并添加其 chartView。
    /// 主线程调用。能力检查失败返回 NSError，不创建替代图形。
    @objc(makeNativeBridgeWithFrame:error:)
    public func makeNativeBridge(frame: CGRect) throws -> HYMCartesianChartViewBridge {
        let bridge = HYMCartesianChartViewBridge(kind: try nativeChartKind(), frame: frame)
        try bridge.configure(specification: self)
        return bridge
    }

    /// 根据原生命中索引查回业务样本 ID；空位、未知系列和越界返回 nil。
    @objc(sampleIdentifierForSeriesID:categoryIndex:)
    public func sampleIdentifier(seriesID: String, categoryIndex: Int) -> String? {
        guard case .categories(let categories) = specification.domain,
              categories.indices.contains(categoryIndex),
              let series = specification.series.first(where: { $0.id == seriesID }) else { return nil }
        return series.samples.first { $0.coordinate == .category(categories[categoryIndex].id) }?.id
    }
}
