/// 数据或样式更新时的视口策略。由支持 HYMChartViewportUpdating 的渲染器处理。
public enum HYMChartViewportUpdatePolicy: Equatable {
    /// 保留用户窗口的数值范围；超出新数据域时平移/收窄到有效范围。
    /// 未缩放的轴继续自动适应全量数据。当前不提供追加数据时自动跟随末端。
    case preserve
    /// 更新后显示全部数据，包括次值轴。
    case reset
}

/// 轴系渲染器的数据更新能力：在下一次 render 时原子应用视口策略。
/// 与手势的临时橡皮筋越界分开，避免数据变更后视口停在无数据区域。
public protocol HYMChartViewportUpdating: HYMChartRenderer {
    /// 记录策略，不立即绘制；随后使用新模型和主题调用 render。
    /// - Parameter policy: 保留或重置用户窗口。
    /// - Note: 必须在主线程调用。
    func prepareViewportForUpdate(_ policy: HYMChartViewportUpdatePolicy)
}
