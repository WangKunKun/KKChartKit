import UIKit

/// 通用图表弹窗视图：背景圆角 + 可选阴影 + 文字（支持多行）/ 自定义内容 view + 可选箭头。
///
/// 背景为「圆角矩形 + 箭头三角形」**合成形状**（一个 `CAShapeLayer` path），箭头从矩形边缘
/// 伸出指向锚点，与背景同色一体（避免箭头被同色矩形覆盖而不可见）。尺寸由 `sizeThatFits(_:)`
/// 按内容自适应；箭头方向与位置由 `applyArrow(placement:arrowX:)` 在外部定位后注入。
public final class HYMChartTooltip: UIView {
    private let backgroundLayer = CAShapeLayer()
    private let textLabel = UILabel()
    private var theme: HYMChartTooltipTheme = .default
    private var placement: HYMChartTooltipPlacement = .top
    private var arrowX: CGFloat = 0
    private var lastText: String = ""
    private var contentView: UIView?

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
        addSubview(textLabel)
    }

    /// 应用背景合成形状的外观（fill + shadow）。configure(text/contentView) 共用。
    private func applyBackgroundAppearance(_ theme: HYMChartTooltipTheme) {
        backgroundLayer.fillColor = theme.backgroundColor.cgColor
        backgroundLayer.strokeColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 0
        if let sc = theme.shadowColor {
            backgroundLayer.shadowColor = sc.cgColor
            backgroundLayer.shadowOpacity = 1
            backgroundLayer.shadowOffset = CGSize(width: 0, height: 1)
            backgroundLayer.shadowRadius = 3
        } else {
            backgroundLayer.shadowOpacity = 0
        }
    }

    /// 设置内容与外观（text 模式）。
    public func configure(text: String, theme: HYMChartTooltipTheme) {
        self.theme = theme
        self.lastText = text
        // 恢复 textLabel（contentView 模式会移除它），并清理可能残留的 contentView
        if textLabel.superview == nil { addSubview(textLabel) }
        self.contentView?.removeFromSuperview()
        self.contentView = nil

        textLabel.text = text
        textLabel.textColor = theme.textColor
        textLabel.font = theme.font
        textLabel.preferredMaxLayoutWidth = theme.maxWidth - theme.contentInset.left - theme.contentInset.right
        applyBackgroundAppearance(theme)
    }

    /// 设置自定义内容 view 与外观（contentView 模式）。外壳(背景合成形状/阴影/箭头)复用，
    /// 内容区装外部 view（替代 textLabel）。与 configure(text:) 互斥使用（由调用方保证不同时）。
    public func configure(contentView: UIView, theme: HYMChartTooltipTheme) {
        self.theme = theme
        textLabel.removeFromSuperview()
        self.contentView?.removeFromSuperview()
        self.contentView = contentView
        addSubview(contentView)
        applyBackgroundAppearance(theme)
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
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0

        // 内容区（让出 arrowH）
        var contentFrame = bounds.inset(by: inset)
        if theme.showsArrow {
            // .top（弹窗在锚点上方，箭头在底部）→ 内容区上移让出底部箭头；
            // .bottom（弹窗在锚点下方，箭头在顶部）→ 内容区下移让出顶部箭头。
            contentFrame.size.height -= arrowH
            if placement == .bottom { contentFrame.origin.y += arrowH }
        }
        if let cv = contentView {
            cv.frame = contentFrame
        } else {
            textLabel.frame = contentFrame
        }

        // 背景合成 path（圆角矩形 + 箭头三角形，同色一体）
        backgroundLayer.frame = bounds
        let path = makeBackgroundPath(arrowH: arrowH)
        backgroundLayer.path = path.cgPath
        // shadow 沿合成形状（含箭头），否则阴影只跟矩形
        backgroundLayer.shadowPath = theme.shadowColor != nil ? path.cgPath : nil
    }

    /// 合成背景 path：圆角矩形（bounds 让出 arrowH）+ 箭头三角形（arrowH 区，指向锚点）。
    /// 箭头从矩形边缘伸出，与矩形同色一体（一个 path fill）→ 箭头可见，不再被矩形覆盖。
    private func makeBackgroundPath(arrowH: CGFloat) -> UIBezierPath {
        var bgRect = bounds
        if theme.showsArrow {
            if placement == .top {
                bgRect.size.height -= arrowH          // 底部让出箭头
            } else {
                bgRect.origin.y += arrowH             // 顶部让出箭头
                bgRect.size.height -= arrowH
            }
        }
        let path = UIBezierPath(roundedRect: bgRect, cornerRadius: theme.cornerRadius)
        guard theme.showsArrow else { return path }

        let w = theme.arrowSize.width
        // arrowX 为容器坐标系（由 HYMChartTooltipGeometry.resolve 注入），转为 tooltip 局部坐标
        let localArrowX = arrowX - frame.minX
        let cx = max(bgRect.minX + w / 2, min(bgRect.maxX - w / 2, localArrowX))
        let arrow = UIBezierPath()
        switch placement {
        case .top:
            // 箭头在底部，尖朝下（指向下方锚点）：根部接 bgRect 底边，尖到 bounds.maxY
            arrow.move(to: CGPoint(x: cx - w / 2, y: bgRect.maxY))
            arrow.addLine(to: CGPoint(x: cx + w / 2, y: bgRect.maxY))
            arrow.addLine(to: CGPoint(x: cx, y: bounds.maxY))
        case .bottom:
            // 箭头在顶部，尖朝上（指向上方锚点）：根部接 bgRect 顶边，尖到 bounds.minY
            arrow.move(to: CGPoint(x: cx - w / 2, y: bgRect.minY))
            arrow.addLine(to: CGPoint(x: cx + w / 2, y: bgRect.minY))
            arrow.addLine(to: CGPoint(x: cx, y: bounds.minY))
        }
        arrow.close()
        path.append(arrow)
        return path
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inset = theme.contentInset
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        if let cv = contentView {
            let maxW = max(0, theme.maxWidth - inset.left - inset.right)
            let s = cv.sizeThatFits(CGSize(width: maxW, height: .greatestFiniteMagnitude))
            return CGSize(width: s.width + inset.left + inset.right,
                          height: s.height + inset.top + inset.bottom + arrowH)
        }
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
