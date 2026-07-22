import Foundation

/// 图表框架统一错误模型。
///
/// 设计说明：本期数据层为纯值类型（struct），`configure`/`render` 对非法输入采用防御式
/// 兜底（如空 dimensions → 不绘制、`maxValue<=0` → 归一化兜底），不做 throws 校验，
/// 以保持 Swift 值类型构造的简洁。本错误模型预留给未来 throws 形式的校验 API 使用。
public enum HYMChartError: Error {
    /// 维度数据为空
    case emptyDimensions
    /// 数据非法（如 maxValue <= 0）
    case invalidData(String)
    /// 主题缺少必要配置
    case invalidTheme(String)
}
