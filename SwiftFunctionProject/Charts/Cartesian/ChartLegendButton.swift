import UIKit

/// 图例符号承载与显示；布局尺寸统一由 ChartLegendContentLayout 决定。
final class ChartLegendButton: UIControl {
    private(set) var item: ChartLegendItem?
    private let label = UILabel()
    private let symbolLayer = CAShapeLayer()
    private let markerLayer = CAShapeLayer()
    private let symbolContent = UIView()
    private let imageView = UIImageView()
    private var customSymbol: UIView?
    private var configuration = ChartLegendConfiguration()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        addSubview(symbolContent)
        symbolContent.clipsToBounds = true
        symbolContent.isUserInteractionEnabled = false
        symbolContent.isAccessibilityElement = false
        symbolContent.accessibilityElementsHidden = true
        symbolContent.addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        layer.addSublayer(symbolLayer)
        layer.addSublayer(markerLayer)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: ChartLegendItem, configuration: ChartLegendConfiguration) {
        self.item = item
        self.configuration = configuration
        backgroundColor = item.style.backgroundColor
        layer.cornerRadius = item.style.cornerRadius.isFinite ? max(0, item.style.cornerRadius) : 0
        let nextSymbol = item.style.symbolViewProvider?(item.isVisible)
        if customSymbol !== nextSymbol {
            customSymbol?.removeFromSuperview()
            customSymbol = nextSymbol
            if let nextSymbol { symbolContent.addSubview(nextSymbol) }
        }
        imageView.image = item.isVisible ? item.style.image : (item.style.hiddenImage ?? item.style.image)
        imageView.tintColor = item.color
        imageView.isHidden = customSymbol != nil || imageView.image == nil
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
        symbolContent.frame = rect
        imageView.frame = symbolContent.bounds
        customSymbol?.frame = symbolContent.bounds
        symbolLayer.path = nil
        markerLayer.path = nil
        symbolLayer.fillColor = item.color.cgColor
        symbolLayer.strokeColor = nil
        symbolLayer.lineDashPattern = nil
        markerLayer.fillColor = item.color.cgColor
        guard customSymbol == nil, imageView.image == nil else { return }
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
