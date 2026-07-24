import CoreGraphics

/// 通用图表弹窗（tooltip）相对锚点的放置方向。
public enum HYMChartTooltipPlacement {
    /// 弹窗在锚点上方（箭头朝下，指向锚点）。
    case top
    /// 弹窗在锚点下方（箭头朝上，指向锚点）。
    case bottom
}

/// 通用图表弹窗定位纯函数（仅依赖 CoreGraphics，便于 DEBUG 自检）。
public enum HYMChartTooltipGeometry {
    /// 定位结果。
    public struct Result {
        /// 弹窗最终 frame（容器坐标系，已裁进 container）。
        public var frame: CGRect
        /// 实际放置方向。
        public var placement: HYMChartTooltipPlacement
        /// 箭头根部 x（容器坐标系；已 clamp 到弹窗内，避免画出弹窗外）。
        public var arrowX: CGFloat
    }

    /// 根据锚点、弹窗尺寸、容器、偏好方向、间距，计算弹窗最终位置。
    ///
    /// 规则：
    /// 1. 按 `preferred` 顺序找第一个「弹窗完整落在 container 内」的方向；
    ///    `preferred` 为空按 `[.top, .bottom]`。
    /// 2. 都放不下 → 选「垂直超出量更小」的方向，并把 frame 平移裁进 container
    ///    （此即「极端情况与锚点重叠」）。
    /// 3. 水平：居中于 `anchor.midX`；左/右超出 container → 平移贴边。
    /// 4. 箭头 x：默认指向 `anchor.midX`，再 clamp 到弹窗内。
    ///
    /// - Parameters:
    ///   - anchor: 锚点 frame（容器坐标系）
    ///   - size: 弹窗自适应尺寸（由 tooltip `sizeThatFits` 给出）
    ///   - container: 可显示区域
    ///   - preferred: 偏好方向序列
    ///   - gap: 弹窗与锚点间距
    /// - Returns: 定位结果；`size` 为 0 时返回 nil。
    public static func resolve(
        anchor: CGRect, size: CGSize, container: CGRect,
        preferred: [HYMChartTooltipPlacement], gap: CGFloat
    ) -> Result? {
        guard size.width > 0, size.height > 0 else { return nil }
        let prefs = preferred.isEmpty ? [.top, .bottom] : preferred
        let halfW = size.width / 2

        func candidateFrame(_ placement: HYMChartTooltipPlacement) -> CGRect {
            switch placement {
            case .top:
                return CGRect(x: anchor.midX - halfW,
                              y: anchor.minY - gap - size.height,
                              width: size.width, height: size.height)
            case .bottom:
                return CGRect(x: anchor.midX - halfW,
                              y: anchor.maxY + gap,
                              width: size.width, height: size.height)
            }
        }

        // 选方向：优先「完整落在 container 内」(overflow==0)；否则选「垂直超出量最小」。
        var chosenPlacement: HYMChartTooltipPlacement = prefs[0]
        var chosenFrame: CGRect = candidateFrame(prefs[0])
        var bestOverflow: CGFloat = .infinity
        for p in prefs {
            let f = candidateFrame(p)
            let topOver = max(0, container.minY - f.minY)
            let bottomOver = max(0, f.maxY - container.maxY)
            let overflow = topOver + bottomOver
            if overflow == 0 {
                chosenPlacement = p
                chosenFrame = f
                break
            }
            if overflow < bestOverflow {
                bestOverflow = overflow
                chosenPlacement = p
                chosenFrame = f
            }
        }

        var frame = chosenFrame

        // 垂直裁进 container（极端情况可能与锚点重叠）
        if frame.minY < container.minY { frame.origin.y = container.minY }
        if frame.maxY > container.maxY { frame.origin.y = container.maxY - frame.height }

        // 水平：居中后贴边
        if frame.minX < container.minX { frame.origin.x = container.minX }
        if frame.maxX > container.maxX { frame.origin.x = container.maxX - frame.width }

        // 箭头 x：指向锚点中心，clamp 到弹窗内
        let arrowX = max(frame.minX, min(frame.maxX, anchor.midX))
        return Result(frame: frame, placement: chosenPlacement, arrowX: arrowX)
    }
}
