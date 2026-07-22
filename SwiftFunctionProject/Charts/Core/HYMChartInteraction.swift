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
}
