import UIKit

/// 结构化提示的 UIKit 内容区。测量与绘制共用同一路径；高度受外壳限制时可纵向滚动。
final class CartesianTooltipContentView: UIScrollView {
    private struct Block { let view: UIView; let gap: CGFloat }
    private var blocks: [Block] = []
    // 始终预留滚动条槽，避免滚动条覆盖右对齐数值，也避免溢出临界点反复换行。
    private let indicatorGutter: CGFloat = 8

    init(content: CartesianTooltipContent, presentation: CartesianTooltipPresentation, theme: HYMChartTooltipTheme) {
        super.init(frame: .zero)
        accessibilityIdentifier = "chart.tooltip.columns"
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        indicatorStyle = .white
        let rowGap = Self.spacing(presentation.rowSpacing, fallback: 4)
        let sectionGap = Self.spacing(presentation.sectionSpacing, fallback: 8)
        let hasImages = content.sections.flatMap(\.rows).contains { $0.image != nil }
        func append(_ view: UIView, gap: CGFloat) {
            addSubview(view); blocks.append(Block(view: view, gap: blocks.isEmpty ? 0 : gap))
        }
        func label(_ text: String) -> UILabel {
            let label = UILabel()
            label.text = text; label.numberOfLines = 0
            label.textColor = theme.textColor; label.font = Self.bold(theme.font)
            return label
        }
        if let header = content.header { append(label(header), gap: 0) }
        for (index, section) in content.sections.enumerated() {
            if index > 0, presentation.showsSectionSeparators {
                let divider = Divider()
                divider.backgroundColor = theme.textColor.withAlphaComponent(0.25)
                append(divider, gap: sectionGap / 2)
            }
            let groupGap = index > 0 && presentation.showsSectionSeparators ? sectionGap / 2 : sectionGap
            if let title = section.title { append(label(title), gap: groupGap) }
            for (rowIndex, row) in section.rows.enumerated() {
                let rowView = RowView(row: row, reservesIcon: hasImages, presentation: presentation, theme: theme)
                append(rowView, gap: rowIndex == 0 && section.title == nil ? groupGap : rowGap)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(0, size.width)
        return CGSize(width: width, height: min(max(0, size.height), layoutContent(width: max(0, width - indicatorGutter), apply: false)))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = layoutContent(width: max(0, bounds.width - indicatorGutter), apply: true)
        let size = CGSize(width: bounds.width, height: height)
        if contentSize != size { contentSize = size }
        isScrollEnabled = height > bounds.height + 0.5
        showsVerticalScrollIndicator = isScrollEnabled
    }

    private func layoutContent(width: CGFloat, apply: Bool) -> CGFloat {
        var y: CGFloat = 0
        for block in blocks {
            y += block.gap
            let height = ceil(block.view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            if apply { block.view.frame = CGRect(x: 0, y: y, width: width, height: height) }
            y += height
        }
        return y
    }

    private static func spacing(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : fallback
    }
    private static func bold(_ font: UIFont) -> UIFont {
        UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor, size: font.pointSize)
    }
    private final class Divider: UIView {
        override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: 1) }
    }

    private final class RowView: UIView {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        private let icon = UIImageView()
        private let reservesIcon: Bool
        private let iconSize: CGFloat
        private let gap: CGFloat
        private let hasValue: Bool

        init(row: CartesianTooltipContent.Row, reservesIcon: Bool,
             presentation: CartesianTooltipPresentation, theme: HYMChartTooltipTheme) {
            self.reservesIcon = reservesIcon
            iconSize = CartesianTooltipContentView.spacing(presentation.iconSize, fallback: 16)
            gap = CartesianTooltipContentView.spacing(presentation.columnSpacing, fallback: 10)
            hasValue = row.value != nil
            super.init(frame: .zero)
            isAccessibilityElement = true
            accessibilityLabel = row.text
            accessibilityTraits = .staticText
            for label in [titleLabel, valueLabel] {
                label.numberOfLines = 0
                label.font = row.isSubtotal ? CartesianTooltipContentView.bold(theme.font) : theme.font
                label.textColor = theme.textColor
                label.isAccessibilityElement = false
                addSubview(label)
            }
            titleLabel.text = row.title; valueLabel.text = row.value
            valueLabel.textAlignment = .right
            icon.image = row.image; icon.tintColor = theme.textColor
            icon.contentMode = .scaleAspectFit; icon.isAccessibilityElement = false
            addSubview(icon)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func sizeThatFits(_ size: CGSize) -> CGSize {
            CGSize(width: size.width, height: layoutRow(width: size.width, apply: false))
        }
        override func layoutSubviews() { super.layoutSubviews(); _ = layoutRow(width: bounds.width, apply: true) }

        private func layoutRow(width: CGFloat, apply: Bool) -> CGFloat {
            let width = max(0, width)
            let side = reservesIcon ? min(iconSize, width / 4) : 0
            let iconGap = side > 0 ? min(gap, width / 8) : 0
            let x = side + iconGap
            let available = max(0, width - x)
            let stacksValue = available < 120
            let columnGap = hasValue && !stacksValue ? min(gap, available / 4) : 0
            let naturalValue = ceil(valueLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width)
            let valueWidth = hasValue ? (stacksValue ? available : min(naturalValue, (available - columnGap) * 0.48)) : 0
            let titleWidth = stacksValue ? available : max(0, available - columnGap - valueWidth)
            let titleHeight = ceil(titleLabel.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height)
            let valueHeight = hasValue ? ceil(valueLabel.sizeThatFits(CGSize(width: valueWidth, height: .greatestFiniteMagnitude)).height) : 0
            let height = max(side, stacksValue ? titleHeight + valueHeight : max(titleHeight, valueHeight))
            if apply {
                icon.frame = CGRect(x: 0, y: 0, width: side, height: side)
                titleLabel.frame = CGRect(x: x, y: 0, width: titleWidth, height: titleHeight)
                valueLabel.textAlignment = stacksValue ? .left : .right
                valueLabel.frame = CGRect(x: stacksValue ? x : width - valueWidth,
                                          y: stacksValue ? titleHeight : 0, width: valueWidth, height: valueHeight)
            }
            return height
        }
    }
}
