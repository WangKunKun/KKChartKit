import CoreGraphics

/// 柱状/条形图沿类目方向的固定间距，单位 pt（不是物理像素）。
/// 设置到 CartesianChartTheme.columnSpacing 后覆盖三个旧比例配置；未固定柱宽时自动平分剩余空间。
/// 缩放不改变间距；仅固定间距时，空间不足不绘制该组；同时固定柱宽时自动滚动查看。
public struct CartesianColumnSpacing {
    /// 固定柱宽/条形厚度（pt）；nil 自动平分剩余空间。
    /// 有效正数时按实际可用空间建立滚动窗口，默认从最早类目开始；无效值视为 nil。
    public var columnWidth: CGFloat?
    /// 同一类目中相邻柱体边缘的距离；堆叠/单系列不使用此值。
    public var inner: CGFloat
    /// 相邻类目柱组边缘的距离；每个槽位两侧各预留一半。
    public var group: CGFloat

    /// 创建固定间距。inner/group 负数按 0 处理，非有限值按 0 处理（渲染时再次校验可变属性）。
    /// 纯值类型；通过图表更新接口应用时须在主线程调用。
    public init(columnWidth: CGFloat? = nil, inner: CGFloat = 4, group: CGFloat = 16) {
        self.columnWidth = columnWidth
        self.inner = Self.valid(inner)
        self.group = Self.valid(group)
    }

    private static func valid(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, value) : 0 }
    var columnWidthPoints: CGFloat? { columnWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } }
    var innerPoints: CGFloat { Self.valid(inner) }
    var groupPoints: CGFloat { Self.valid(group) }

    /// 给定可见系列数与最小柱宽，返回完整类目槽的宽度预算（含全部间距）。
    func requiredSlotWidth(seriesCount: Int, minimumColumnWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(1, seriesCount))
        return count * (columnWidthPoints ?? minimumColumnWidth) + max(0, count - 1) * innerPoints + groupPoints
    }

    /// 返回相对于类目中心的柱起点与厚度；nil 表示间距已占满槽位。
    func placement(slotWidth: CGFloat, seriesCount: Int, seriesIndex: Int) -> (offset: CGFloat, width: CGFloat)? {
        let count = CGFloat(max(1, seriesCount))
        if let width = columnWidthPoints {
            let body = count * width + max(0, count - 1) * innerPoints
            guard body.isFinite, body <= slotWidth - groupPoints + 0.000001 else { return nil }
            return (-body / 2 + CGFloat(seriesIndex) * (width + innerPoints), width)
        }
        let available = slotWidth - groupPoints - max(0, count - 1) * innerPoints
        guard slotWidth.isFinite, available.isFinite, available > 0 else { return nil }
        let width = available / count
        return (-slotWidth / 2 + groupPoints / 2 + CGFloat(seriesIndex) * (width + innerPoints), width)
    }
}

/// 容器据此启用类目滚动，独立于用户是否允许捏合缩放。
protocol HYMChartAutomaticCategoryScrolling: AnyObject {
    var automaticCategoryScrollAxis: HYMChartZoomAxisMode? { get }
}
