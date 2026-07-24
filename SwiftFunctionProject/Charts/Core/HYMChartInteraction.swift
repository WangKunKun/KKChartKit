import Foundation
import CoreGraphics

/// 交互手势类型（预留扩展）
public enum HYMChartGesture {
    case tap
    // 预留扩展：longPress 等
}

/// 图表中一个可命中的语义单元（关联数据，非绘图细节）
public protocol HYMChartHitTarget {
    /// 业务标识，如 "进攻"
    var identifier: String { get }
    /// 序号
    var index: Int { get }
    /// 通用类别槽位（如 "dataVertex"/"labelVertex"）；默认 "" 表示不分类。
    /// 具体类别值由各图表特有 HitTarget 定义，不污染本通用协议。
    var kind: String { get }
    /// 弹窗显示文本（数据驱动）；默认 nil = 不显示弹窗。
    /// 具体图表的 `XXXHitTarget` 按需覆盖（从自身数据派生）。
    var tooltipText: String? { get }
}

public extension HYMChartHitTarget {
    /// 默认不分类
    var kind: String { "" }
    /// 默认不显示弹窗
    var tooltipText: String? { nil }
}
