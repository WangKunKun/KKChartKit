import UIKit

/// 通用图表弹窗显示管理：持有 tooltip 视图（挂在 host 上），负责定位、显示、隐藏、动画与清理。
///
/// 线程：UI 操作应在主线程。
public final class HYMChartTooltipController {
    private weak var host: UIView?
    private let tooltip: HYMChartTooltip
    private var displayRevision = 0
    public var theme: HYMChartTooltipTheme

    public init(host: UIView, theme: HYMChartTooltipTheme = .default) {
        self.host = host
        self.theme = theme
        self.tooltip = HYMChartTooltip()
        tooltip.isHidden = true
        host.addSubview(tooltip)
        // 弹窗永远压住准线（crosshairLayer zPosition 900）与标签层
        tooltip.layer.zPosition = 1000
    }

    private enum Content {
        case text(String)
        case view(UIView, interactive: Bool)
    }
    private var lastContent: Content?
    private var lastAnchor: CGRect = .zero
    private var lastPreferred: [HYMChartTooltipPlacement] = []
    private var lastContainer: CGRect?

    /// 显示文本提示；animated=false 用于跟手更新，固定顶部模式受容器尺寸约束。
    public func show(anchor: CGRect, text: String, in container: CGRect,
                     preferred: [HYMChartTooltipPlacement], animated: Bool = true) {
        show(content: .text(text), anchor: anchor, in: container, preferred: preferred, animated: animated)
    }

    /// 显示自定义内容。allowsContentInteraction 默认关闭，开启可接收触摸与内嵌滚动。
    /// 内容须实现 sizeThatFits；固定顶部/交互内容受 container 尺寸约束。
    public func show(anchor: CGRect, contentView: UIView, in container: CGRect,
                     preferred: [HYMChartTooltipPlacement],
                     animated: Bool = true, allowsContentInteraction: Bool = false) {
        show(content: .view(contentView, interactive: allowsContentInteraction), anchor: anchor,
             in: container, preferred: preferred, animated: animated)
    }

    /// 容器尺寸变化时重新测量并定位已显示的固定顶部提示，不重播动画。
    /// automatic 的锚点属于原绘图区，不在这里猜测新的点位置。
    public func relayout(in container: CGRect) {
        guard theme.position == .fixedTop, !tooltip.isHidden, lastContainer != container,
              let content = lastContent else { return }
        show(content: content, anchor: lastAnchor, in: container, preferred: lastPreferred, animated: false)
    }

    private func show(content: Content, anchor: CGRect, in container: CGRect,
                      preferred: [HYMChartTooltipPlacement], animated: Bool) {
        guard let host else { return }
        displayRevision += 1
        tooltip.layer.removeAllAnimations()
        tooltip.transform = .identity
        var effectiveTheme = theme
        if theme.position == .fixedTop { effectiveTheme.showsArrow = false }
        let interactive: Bool
        switch content {
        case .text(let text):
            interactive = false
            tooltip.configure(text: text, theme: effectiveTheme)
        case .view(let view, let enabled):
            interactive = enabled
            tooltip.configure(contentView: view, theme: effectiveTheme, allowsInteraction: enabled)
        }
        let constrained = interactive || theme.position == .fixedTop
        let constraint = constrained ? container.size : CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude)
        let size = tooltip.sizeThatFits(constraint)
        guard let result = HYMChartTooltipGeometry.resolve(anchor: anchor, size: size, container: container,
            preferred: preferred, gap: theme.gap, position: theme.position, offset: theme.offset, topInset: theme.fixedTopInset) else {
            hide(animated: false); return
        }
        lastContent = content; lastAnchor = anchor; lastPreferred = preferred; lastContainer = container
        tooltip.accessibilityIdentifier = theme.position == .fixedTop ? "chart.tooltip.fixedTop" : "chart.tooltip.automatic"
        host.bringSubviewToFront(tooltip)
        tooltip.frame = result.frame
        tooltip.applyArrow(placement: result.placement, arrowX: result.arrowX)
        tooltip.layoutIfNeeded()
        let playsEntrance = theme.showsAnimation && animated && tooltip.isHidden
        tooltip.isHidden = false
        if playsEntrance {
            tooltip.alpha = 0
            tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            UIView.animate(withDuration: 0.18) {
                self.tooltip.alpha = 1
                self.tooltip.transform = .identity
            }
        } else {
            tooltip.alpha = 1
            tooltip.transform = .identity
        }
    }

    /// 隐藏弹窗。
    /// - Parameter animated: 是否播放淡出动画。**手势接管（缩放/平移开始）时必须传 false**：
    ///   弹窗锚点属于旧视口，带动画淡出期间它会悬在原位，与正在平移的内容错开，
    ///   视觉上就是"残影"。
    public func hide(animated: Bool = true) {
        lastContent = nil; lastContainer = nil
        guard !tooltip.isHidden else { return }
        displayRevision += 1
        let revision = displayRevision
        if animated, theme.showsAnimation {
            UIView.animate(withDuration: 0.15, delay: 0, options: [],
                           animations: {
                self.tooltip.alpha = 0
                self.tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
                guard revision == self.displayRevision else { return }
                self.tooltip.isHidden = true
                self.tooltip.transform = .identity
            })
        } else {
            // 立即隐藏：中断进行中的淡入/淡出并复位状态
            tooltip.layer.removeAllAnimations()
            tooltip.isHidden = true
            tooltip.alpha = 1
            tooltip.transform = .identity
        }
    }

    /// 从 host 移除（`HYMChartView` unmount/deinit 清理用）。
    public func removeFromSuperview() {
        tooltip.removeFromSuperview()
    }
}
