import UIKit

/// 屏幕方向对齐；automatic 保留线标签端部/带标签中央的原布局。
public enum CartesianAnnotationAlignment: String, CaseIterable {
    case automatic = "自动", leading = "起点", center = "居中", trailing = "终点"
}
public enum CartesianAnnotationVerticalAlignment: String, CaseIterable {
    case automatic = "自动", top = "顶部", center = "居中", bottom = "底部"
}
public enum CartesianAnnotationBounds: String, CaseIterable {
    /// 限宽并钳入绘图区；高度放不下则隐藏。
    case clamp = "限制在绘图区"
    /// 完整文本越界即隐藏，不截断。
    case hide = "越界隐藏"
}

public struct CartesianAnnotationLabelStyle {
    public var color: UIColor?
    public var font: UIFont?
    public var backgroundColor: UIColor?
    public var alignment: CartesianAnnotationAlignment
    public var verticalAlignment: CartesianAnnotationVerticalAlignment
    /// 屏幕 pt，非有限分量忽略。对齐后应用，最后执行边界策略。
    public var offset: CGSize
    public var bounds: CartesianAnnotationBounds
    public init(color: UIColor? = nil, font: UIFont? = nil, backgroundColor: UIColor? = nil,
                alignment: CartesianAnnotationAlignment = .automatic,
                verticalAlignment: CartesianAnnotationVerticalAlignment = .automatic,
                offset: CGSize = .zero, bounds: CartesianAnnotationBounds = .clamp) {
        self.color = color; self.font = font; self.backgroundColor = backgroundColor
        self.alignment = alignment; self.verticalAlignment = verticalAlignment
        self.offset = offset; self.bounds = bounds
    }
}

/// 布局只改变标注，不参与值域、命中与数据几何。
enum CartesianAnnotationLabelGeometry {
    static func frame(size: CGSize, defaultCenter: CGPoint, reference: CGRect,
                      plot: CGRect, style: CartesianAnnotationLabelStyle) -> CGRect? {
        let available = plot.insetBy(dx: 2, dy: 2)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              available.width > 0, size.height <= available.height else { return nil }
        var size = size
        if style.bounds == .clamp { size.width = min(size.width, available.width) }
        var center = defaultCenter
        switch style.alignment {
        case .automatic: break
        case .leading: center.x = reference.minX + size.width / 2 + 4
        case .center: center.x = reference.midX
        case .trailing: center.x = reference.maxX - size.width / 2 - 4
        }
        switch style.verticalAlignment {
        case .automatic: break
        case .top: center.y = reference.minY + size.height / 2 + 3
        case .center: center.y = reference.midY
        case .bottom: center.y = reference.maxY - size.height / 2 - 3
        }
        // 限制偏移范围避免有限极大值在加法时溢出。
        if style.offset.width.isFinite { center.x += min(max(style.offset.width, -1e9), 1e9) }
        if style.offset.height.isFinite { center.y += min(max(style.offset.height, -1e9), 1e9) }
        if style.bounds == .clamp {
            center.x = min(max(center.x, available.minX + size.width / 2), available.maxX - size.width / 2)
            center.y = min(max(center.y, available.minY + size.height / 2), available.maxY - size.height / 2)
        }
        let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                           width: size.width, height: size.height)
        return available.insetBy(dx: -0.001, dy: -0.001).contains(frame) ? frame : nil
    }
}
