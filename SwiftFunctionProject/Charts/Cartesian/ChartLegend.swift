import UIKit

public enum ChartLegendPosition: String, CaseIterable { case top, bottom, left, right }
public enum ChartLegendAlignment: String, CaseIterable { case leading, center, trailing }

public enum ChartLegendOverflow: Equatable {
    /// 遵守 maxRows / maxHeight，超出内容在图例内滚动。
    case scroll
    /// 按完整内容测量；外部应为返回高度预留空间。仍保护最小绘图区。
    case expand
}

/// 图例符号只控制图例；系列本身的颜色、marker 仍由系列/主题配置。
public enum ChartLegendSymbol {
    case line
    case lineWithMarker(PointMarkerSymbol)
    case marker(PointMarkerSymbol)
    case rectangle
    case roundedRectangle
}

public struct LegendItemStyle {
    public var title: String?
    public var symbol: ChartLegendSymbol?
    public var symbolColor: UIColor?
    public init(title: String? = nil, symbol: ChartLegendSymbol? = nil, symbolColor: UIColor? = nil) {
        self.title = title
        self.symbol = symbol
        self.symbolColor = symbolColor
    }
}

/// 图例包含在外部指定的图表尺寸内。上下自动换行，左右单列；溢出后纵向滚动。
public struct ChartLegendConfiguration {
    /// 默认关闭，兼容已有图表布局。
    public var isEnabled = false
    public var position: ChartLegendPosition = .bottom
    public var alignment: ChartLegendAlignment = .center
    public var itemSpacing: CGFloat = 16
    public var rowSpacing: CGFloat = 4
    public var symbolSize = CGSize(width: 22, height: 12)
    public var symbolTextSpacing: CGFloat = 6
    public var font: UIFont = .systemFont(ofSize: 12)
    public var textColor: UIColor = .secondaryLabel
    public var hiddenAlpha: CGFloat = 0.35
    public var chartSpacing: CGFloat = 8
    public var overflow: ChartLegendOverflow = .scroll
    public var maxRows: Int = 3
    public var maxHeight: CGFloat = 120
    /// 左/右图例的最大宽度。
    public var maxWidth: CGFloat = 140
    public var minimumPlotSize = CGSize(width: 80, height: 80)
    public var allowsToggling = true
    /// key 必须是唯一、稳定的 series.id。
    public var itemOverrides: [String: LegendItemStyle] = [:]
    public init() {}
}

struct ChartLegendItem {
    let id: String
    let title: String
    let symbol: ChartLegendSymbol
    let color: UIColor
    let dashStyle: LineDashStyle
    let isVisible: Bool

    static func orderedSeries(in model: CartesianChartModel) -> [CartesianSeriesElement] {
        model.series.enumerated().filter { $0.element.showsInLegend }.sorted {
            $0.element.legendOrder == $1.element.legendOrder
                ? $0.offset < $1.offset : $0.element.legendOrder < $1.element.legendOrder
        }.map(\.element)
    }
}

/// 内部协议让通用容器管理更新/清理交互，renderer 仅发出显隐请求。
protocol HYMChartLegendProviding: AnyObject {
    var onLegendToggle: ((String, Bool) -> Void)? { get set }
}

/// 测量单位均为 UIKit point。size 是图例容器尺寸，contentSize 是完整内容的自然尺寸。
public struct ChartLegendMeasurement {
    /// 当前 overflow/maxRows/maxHeight 配置下应预留的图例尺寸（不含 chartSpacing）。
    /// 上下图例的宽度为传入的可用宽度，以保持行对齐。
    public let size: CGSize
    /// 最宽一行的实际内容宽度 × 全部行高度（含项/行间距，不含 chartSpacing；长标题按可用宽度截断）。
    public let contentSize: CGSize
    public let rowCount: Int
    public let isScrollable: Bool
    /// 上下图例需要追加的图表高度，已含 chartSpacing；左右图例为 0。
    public let additionalChartHeight: CGFloat
    /// 左右图例需要预留的水平空间，已含 chartSpacing；上下图例为 0。
    public let additionalChartWidth: CGFloat

    static let zero = ChartLegendMeasurement(size: .zero, contentSize: .zero, rowCount: 0,
                                            isScrollable: false, additionalChartHeight: 0,
                                            additionalChartWidth: 0)
}

/// 无需创建图表/renderer 即可测量。请在主线程使用，与 UIKit 字体、主题保持同一环境。
public final class ChartLegendMeasurer {
    private init() {}

    /// - Parameter availableWidth: 图例可用宽度（外部图表宽度减去 theme.contentInset 左右值）。
    /// - Returns: 未施加图表总高度约束的尺寸。使用 .expand 可获得完整展开高度。
    /// - Note: 若实际容器过小，renderer 仍会为 minimumPlotSize 限制图例；
    ///   左右图例还会受坐标轴宽度影响，调用方应传入实际可分配的图例宽度预算。
    public static func measure(model: CartesianChartModel, theme: CartesianChartTheme,
                               availableWidth: CGFloat) -> ChartLegendMeasurement {
        let titles = ChartLegendItem.orderedSeries(in: model).map {
            theme.legend.itemOverrides[$0.id]?.title ?? $0.name
        }
        return ChartLegendContentLayout.make(titles: titles, configuration: theme.legend,
                                              availableWidth: availableWidth).measurement
    }
}

/// 公开测量和 renderer 共享的排版引擎，避免字体/换行规则产生两套结果。
private struct ChartLegendContentLayout {
    let measurement: ChartLegendMeasurement
    let itemFrames: [CGRect]
    var scrollContentSize: CGSize {
        CGSize(width: measurement.size.width, height: measurement.contentSize.height)
    }

    static func make(titles: [String], configuration c: ChartLegendConfiguration,
                     availableWidth: CGFloat,
                     maximumHeight: CGFloat = .greatestFiniteMagnitude) -> ChartLegendContentLayout {
        let empty = ChartLegendContentLayout(measurement: .zero, itemFrames: [])
        guard c.isEnabled, !titles.isEmpty, availableWidth.isFinite, availableWidth > 0 else { return empty }
        let side = c.position == .left || c.position == .right
        let rowHeight = max(32, max(c.font.lineHeight, max(0, c.symbolSize.height)) + 8)
        let spacing = max(0, c.rowSpacing)
        let itemWidths = titles.map {
            ceil(($0 as NSString).size(withAttributes: [.font: c.font]).width)
                + max(0, c.symbolSize.width) + max(0, c.symbolTextSpacing) + 8
        }
        let width = side ? min(max(0, c.maxWidth), availableWidth, itemWidths.max() ?? 0) : availableWidth
        guard width > 0 else { return empty }
        var frames: [CGRect] = []
        var rows: [Range<Int>] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowStart = 0
        for naturalWidth in itemWidths {
            let itemWidth = min(width, naturalWidth)
            if x > 0 && (side || x + itemWidth > width) {
                rows.append(rowStart..<frames.count)
                rowStart = frames.count
                y += rowHeight + spacing
                x = 0
            }
            frames.append(CGRect(x: x, y: y, width: side ? width : itemWidth, height: rowHeight))
            x += itemWidth + max(0, c.itemSpacing)
        }
        rows.append(rowStart..<frames.count)
        var contentWidth: CGFloat = 0
        for row in rows {
            let used = frames[row.upperBound - 1].maxX
            contentWidth = max(contentWidth, used)
            guard !side else { continue }
            let offset: CGFloat
            switch c.alignment {
            case .leading: offset = 0
            case .center: offset = (width - used) / 2
            case .trailing: offset = width - used
            }
            for i in row { frames[i].origin.x += offset }
        }
        let fullHeight = y + rowHeight
        let rowLimit = CGFloat(max(1, c.maxRows)) * (rowHeight + spacing) - spacing
        let configuredHeight = c.overflow == .expand ? fullHeight : min(fullHeight, max(0, c.maxHeight), rowLimit)
        let height = min(configuredHeight, max(0, maximumHeight))
        // 放不下一整行时不预留残缺图例；仍提供完整内容尺寸供调用方调整。
        let fits = height >= rowHeight
        let measurement = ChartLegendMeasurement(
            size: fits ? CGSize(width: width, height: height) : .zero,
            contentSize: CGSize(width: contentWidth, height: fullHeight), rowCount: rows.count,
            isScrollable: fits && fullHeight > height,
            additionalChartHeight: fits && !side ? height + max(0, c.chartSpacing) : 0,
            additionalChartWidth: fits && side ? width + max(0, c.chartSpacing) : 0)
        return ChartLegendContentLayout(measurement: measurement, itemFrames: fits ? frames : [])
    }
}

struct ChartLegendLayout {
    let frame: CGRect
    let itemFrames: [CGRect]
    let contentSize: CGSize
    let plotFrame: CGRect

    static func make(items: [ChartLegendItem], configuration c: ChartLegendConfiguration,
                     available: CGRect, plot: CGRect) -> ChartLegendLayout {
        let empty = ChartLegendLayout(frame: .zero, itemFrames: [], contentSize: .zero, plotFrame: plot)
        guard available.width > 0, available.height > 0 else { return empty }
        let side = c.position == .left || c.position == .right
        let gap = max(0, c.chartSpacing)
        let widthBudget = max(0, plot.width - max(0, c.minimumPlotSize.width) - gap)
        let heightBudget = side ? available.height : max(0, plot.height - max(0, c.minimumPlotSize.height) - gap)
        let content = ChartLegendContentLayout.make(titles: items.map(\.title), configuration: c,
                                                     availableWidth: side ? min(widthBudget, available.width) : available.width,
                                                     maximumHeight: heightBudget)
        guard !content.itemFrames.isEmpty else { return empty }
        var frame = CGRect(origin: available.origin, size: content.measurement.size)
        var resultPlot = plot
        switch c.position {
        case .top:
            resultPlot.origin.y += content.measurement.additionalChartHeight
            resultPlot.size.height -= content.measurement.additionalChartHeight
        case .bottom:
            frame.origin.y = available.maxY - frame.height
            resultPlot.size.height -= content.measurement.additionalChartHeight
        case .left:
            resultPlot.origin.x += content.measurement.additionalChartWidth
            resultPlot.size.width -= content.measurement.additionalChartWidth
        case .right:
            frame.origin.x = available.maxX - frame.width
            resultPlot.size.width -= content.measurement.additionalChartWidth
        }
        return ChartLegendLayout(frame: frame, itemFrames: content.itemFrames,
                                 contentSize: content.scrollContentSize, plotFrame: resultPlot)
    }
}

final class ChartLegendView: UIScrollView {
    private(set) var buttons: [ChartLegendButton] = []
    var onToggle: ((String, Bool) -> Void)?
    private var ids: [String] = []

    init() {
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = false
        clipsToBounds = true
        layer.zPosition = 910
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(items: [ChartLegendItem], configuration: ChartLegendConfiguration, layout: ChartLegendLayout) {
        isHidden = layout.itemFrames.isEmpty
        guard !isHidden else {
            buttons.forEach { $0.removeFromSuperview() }
            buttons = []
            ids = []
            return
        }
        let newIDs = items.map(\.id)
        if ids != newIDs {
            buttons.forEach { $0.removeFromSuperview() }
            buttons = items.map { _ in
                let button = ChartLegendButton()
                button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                addSubview(button)
                return button
            }
            ids = newIDs
            contentOffset = .zero
        }
        frame = layout.frame
        contentSize = layout.contentSize
        contentOffset.y = min(max(0, contentOffset.y), max(0, contentSize.height - bounds.height))
        for (i, item) in items.enumerated() {
            buttons[i].frame = layout.itemFrames[i]
            buttons[i].configure(item: item, configuration: configuration)
        }
    }
    @objc private func tapped(_ button: ChartLegendButton) {
        guard let item = button.item else { return }
        onToggle?(item.id, !item.isVisible)
    }
}

final class ChartLegendButton: UIControl {
    private(set) var item: ChartLegendItem?
    private let label = UILabel()
    private let symbolLayer = CAShapeLayer()
    private let markerLayer = CAShapeLayer()
    private var configuration = ChartLegendConfiguration()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        layer.addSublayer(symbolLayer)
        layer.addSublayer(markerLayer)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: ChartLegendItem, configuration: ChartLegendConfiguration) {
        self.item = item
        self.configuration = configuration
        label.text = item.title
        label.font = configuration.font
        label.textColor = configuration.textColor
        label.lineBreakMode = .byTruncatingTail
        alpha = item.isVisible ? 1 : min(1, max(0, configuration.hiddenAlpha))
        isEnabled = configuration.allowsToggling
        accessibilityLabel = item.title
        accessibilityValue = item.isVisible ? "已显示" : "已隐藏"
        accessibilityHint = configuration.allowsToggling ? "双击切换系列显示" : nil
        accessibilityTraits = configuration.allowsToggling ? .button : .staticText
        if item.isVisible { accessibilityTraits.insert(.selected) }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let item else { return }
        let w = min(max(0, configuration.symbolSize.width), bounds.width)
        let h = min(max(0, configuration.symbolSize.height), bounds.height)
        let rect = CGRect(x: 0, y: (bounds.height - h) / 2, width: w, height: h)
        let labelX = min(bounds.width, w + max(0, configuration.symbolTextSpacing))
        label.frame = CGRect(x: labelX, y: 0, width: max(0, bounds.width - labelX), height: bounds.height)
        symbolLayer.path = nil
        markerLayer.path = nil
        symbolLayer.fillColor = item.color.cgColor
        symbolLayer.strokeColor = nil
        symbolLayer.lineDashPattern = nil
        markerLayer.fillColor = item.color.cgColor
        let center = CGPoint(x: rect.midX, y: rect.midY)
        switch item.symbol {
        case .rectangle: symbolLayer.path = UIBezierPath(rect: rect).cgPath
        case .roundedRectangle: symbolLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: 3).cgPath
        case .marker(let marker): symbolLayer.path = marker.path(center: center, radius: min(w, h) / 2)
        case .line, .lineWithMarker:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            symbolLayer.path = path.cgPath
            symbolLayer.strokeColor = item.color.cgColor
            symbolLayer.fillColor = nil
            symbolLayer.lineWidth = 2
            symbolLayer.lineDashPattern = item.dashStyle.dashPattern
            if case .lineWithMarker(let marker) = item.symbol {
                markerLayer.path = marker.path(center: center, radius: min(w, h) / 2)
            }
        }
    }
}
