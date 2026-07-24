import UIKit

/// 通用图表弹窗视图：背景圆角 + 可选阴影 + 文字（支持多行）+ 可选箭头。
///
/// 尺寸由 `sizeThatFits(_:)` 按内容自适应；箭头方向与位置由
/// `applyArrow(placement:arrowX:)` 在外部定位后注入（`arrowX` 为容器坐标系 x）。
public final class HYMChartTooltip: UIView {
    private let backgroundLayer = CALayer()
    private let arrowLayer = CAShapeLayer()
    private let textLabel = UILabel()
    private var theme: HYMChartTooltipTheme = .default
    private var placement: HYMChartTooltipPlacement = .top
    private var arrowX: CGFloat = 0
    private var lastText: String = ""

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        backgroundColor = .clear
        // 不拦截触摸：弹窗下方的格子仍可点击
        isUserInteractionEnabled = false
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(arrowLayer)
        addSubview(textLabel)
    }

    /// 设置内容与外观。
    public func configure(text: String, theme: HYMChartTooltipTheme) {
        self.theme = theme
        self.lastText = text
        textLabel.text = text
        textLabel.textColor = theme.textColor
        textLabel.font = theme.font
        textLabel.preferredMaxLayoutWidth = theme.maxWidth - theme.contentInset.left - theme.contentInset.right

        backgroundLayer.backgroundColor = theme.backgroundColor.cgColor
        backgroundLayer.cornerRadius = theme.cornerRadius
        if let sc = theme.shadowColor {
            backgroundLayer.shadowColor = sc.cgColor
            backgroundLayer.shadowOpacity = 1
            backgroundLayer.shadowOffset = CGSize(width: 0, height: 1)
            backgroundLayer.shadowRadius = 3
        } else {
            backgroundLayer.shadowOpacity = 0
        }
        arrowLayer.isHidden = !theme.showsArrow
        arrowLayer.fillColor = theme.backgroundColor.cgColor
    }

    /// 注入箭头方向与位置（容器坐标系下的 `arrowX`）。在 `sizeThatFits` 后、显示前调用。
    public func applyArrow(placement: HYMChartTooltipPlacement, arrowX: CGFloat) {
        self.placement = placement
        self.arrowX = arrowX
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let inset = theme.contentInset
        backgroundLayer.frame = bounds
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        var labelFrame = bounds.inset(by: inset)
        if theme.showsArrow {
            // .top（弹窗在锚点上方，箭头在底部）→ 文字区上移让出底部箭头；
            // .bottom（弹窗在锚点下方，箭头在顶部）→ 文字区下移让出顶部箭头。
            labelFrame.size.height -= arrowH
            if placement == .bottom { labelFrame.origin.y += arrowH }
        }
        textLabel.frame = labelFrame
        rebuildArrow()
    }

    private func rebuildArrow() {
        guard theme.showsArrow else { arrowLayer.path = nil; return }
        let w = theme.arrowSize.width
        let h = theme.arrowSize.height
        let cx = max(bounds.minX + w / 2, min(bounds.maxX - w / 2, arrowX))
        let path = UIBezierPath()
        switch placement {
        case .top:
            // 箭头在底部，尖朝下（指向下方锚点）
            path.move(to: CGPoint(x: cx - w / 2, y: bounds.maxY - h))
            path.addLine(to: CGPoint(x: cx + w / 2, y: bounds.maxY - h))
            path.addLine(to: CGPoint(x: cx, y: bounds.maxY))
        case .bottom:
            // 箭头在顶部，尖朝上（指向上方锚点）
            path.move(to: CGPoint(x: cx - w / 2, y: bounds.minY + h))
            path.addLine(to: CGPoint(x: cx + w / 2, y: bounds.minY + h))
            path.addLine(to: CGPoint(x: cx, y: bounds.minY))
        }
        path.close()
        arrowLayer.path = path.cgPath
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inset = theme.contentInset
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        let maxTextWidth = max(0, theme.maxWidth - inset.left - inset.right)
        let textBounds = (lastText as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: theme.font],
            context: nil)
        let textH = ceil(textBounds.height)
        let w = ceil(textBounds.width + inset.left + inset.right)
        let h = textH + inset.top + inset.bottom + arrowH
        return CGSize(width: max(w, inset.left + inset.right), height: h)
    }
}
