import QuartzCore
import UIKit

/// 数值插值动画器（DisplayLink 驱动）。
/// 注意：CADisplayLink 强引用其 target（即本实例）；本实例持有 displayLink，
/// 形成 displayLink ↔ animator 循环，必须由调用方在 deinit / 重入时调 `stop()` 打破。
public final class HYMChartValueAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0
    private var handler: ((Double) -> Void)?
    private var completion: (() -> Void)?

    public init() {}

    /// 启动一次 0→1 的 easeOut 动画。
    /// - Parameters:
    ///   - duration: 时长（秒）
    ///   - handler: 每帧回调已 ease 的归一化进度 0...1
    ///   - completion: 结束回调（在 handler 最后一次之后）
    public func startEaseOut(duration: CFTimeInterval,
                             handler: @escaping (Double) -> Void,
                             completion: @escaping () -> Void) {
        stop()
        self.duration = max(0.0001, duration)
        self.handler = handler
        self.completion = completion
        self.startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: RunLoop.main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let t = max(0, min(1, elapsed / duration))
        let eased = 1 - (1 - t) * (1 - t)   // easeOut
        handler?(eased)
        if t >= 1 {
            let cb = completion
            stop()
            cb?()
        }
    }

    /// 停止并释放 DisplayLink（打破循环引用）
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        handler = nil
        completion = nil
    }
}
