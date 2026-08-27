import UIKit

/// 通用图表弹窗显示管理：持有 tooltip 视图（挂在 host 上），负责定位、显示、隐藏、动画与清理。
///
/// 线程：UI 操作应在主线程。
public final class HYMChartTooltipController {
    private weak var host: UIView?
    private let tooltip: HYMChartTooltip
    public var theme: HYMChartTooltipTheme

    public init(host: UIView, theme: HYMChartTooltipTheme = .default) {
        self.host = host
        self.theme = theme
        self.tooltip = HYMChartTooltip()
        tooltip.isHidden = true
        host.addSubview(tooltip)
    }

    /// 显示弹窗。
    /// - Parameters:
    ///   - anchor: 锚点 frame（host 坐标系）
    ///   - text: 显示文本
    ///   - container: 可显示区域（host 坐标系）
    ///   - preferred: 偏好方向序列
    public func show(anchor: CGRect, text: String,
                     in container: CGRect,
                     preferred: [HYMChartTooltipPlacement]) {
        guard let host = host else { return }
        tooltip.configure(text: text, theme: theme)
        let size = tooltip.sizeThatFits(CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude))
        guard let r = HYMChartTooltipGeometry.resolve(
            anchor: anchor, size: size, container: container,
            preferred: preferred, gap: theme.gap) else {
            tooltip.isHidden = true
            return
        }
        host.bringSubviewToFront(tooltip)   // 确保在标签等子视图之上
        tooltip.frame = r.frame
        tooltip.applyArrow(placement: r.placement, arrowX: r.arrowX)
        tooltip.layoutIfNeeded()

        if theme.showsAnimation {
            tooltip.alpha = 0
            tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            tooltip.isHidden = false
            UIView.animate(withDuration: 0.18, delay: 0, options: []) {
                self.tooltip.alpha = 1
                self.tooltip.transform = .identity
            }
        } else {
            tooltip.alpha = 1
            tooltip.transform = .identity
            tooltip.isHidden = false
        }
    }

    /// 显示「自定义内容 view」弹窗（contentView 模式）。
    /// 复用 HYMChartTooltipGeometry 定位与 show/hide 动画；外壳由 HYMChartTooltip 提供。
    public func show(anchor: CGRect, contentView: UIView,
                     in container: CGRect,
                     preferred: [HYMChartTooltipPlacement]) {
        guard let host = host else { return }
        tooltip.configure(contentView: contentView, theme: theme)
        let size = tooltip.sizeThatFits(CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude))
        guard let r = HYMChartTooltipGeometry.resolve(
            anchor: anchor, size: size, container: container,
            preferred: preferred, gap: theme.gap) else {
            tooltip.isHidden = true
            return
        }
        host.bringSubviewToFront(tooltip)
        tooltip.frame = r.frame
        tooltip.applyArrow(placement: r.placement, arrowX: r.arrowX)
        tooltip.layoutIfNeeded()

        if theme.showsAnimation {
            tooltip.alpha = 0
            tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            tooltip.isHidden = false
            UIView.animate(withDuration: 0.18, delay: 0, options: []) {
                self.tooltip.alpha = 1
                self.tooltip.transform = .identity
            }
        } else {
            tooltip.alpha = 1
            tooltip.transform = .identity
            tooltip.isHidden = false
        }
    }

    /// 隐藏弹窗。
    /// - Parameter animated: 是否播放淡出动画。**手势接管（缩放/平移开始）时必须传 false**：
    ///   弹窗锚点属于旧视口，带动画淡出期间它会悬在原位，与正在平移的内容错开，
    ///   视觉上就是"残影"。
    public func hide(animated: Bool = true) {
        guard !tooltip.isHidden else { return }
        if animated, theme.showsAnimation {
            UIView.animate(withDuration: 0.15, delay: 0, options: [],
                           animations: {
                self.tooltip.alpha = 0
                self.tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
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
