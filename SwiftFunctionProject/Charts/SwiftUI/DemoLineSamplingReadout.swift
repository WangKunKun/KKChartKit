import SwiftUI

/// 直接显示 renderer 已采用的选择结果，而不是按控件值估算。
struct DemoLineSamplingReadout: View {
    @ObservedObject var report: DemoChartReport
    var body: some View {
        if !report.stackBoundaryText.isEmpty {
            Text(report.stackBoundaryText).font(.caption2).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                .accessibilityIdentifier("demo.stackBoundaryCounts")
        }
        if !report.samplingText.isEmpty {
            Text(report.samplingText).font(.caption2).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                .accessibilityIdentifier("demo.lineSamplingCounts")
        }
    }

    static func text(_ statistics: [LineSamplingStatistics]) -> String {
        statistics.map { s in
            var line = "\(s.seriesName)：可见 \(s.visiblePointCount) → 绘制 \(s.renderedPointCount)"
            let neighbours = max(0, s.sourcePointCount - s.visiblePointCount)
            if neighbours > 0 { line += "（采样前含 \(neighbours) 个边缘邻点）" }
            if let target = s.targetPointCount {
                line += " · 目标 \(target)"
                if s.minimumRequiredPointCount > target {
                    line += "；端点/极值保护至少 \(s.minimumRequiredPointCount) 点，已超目标"
                } else if s.sourcePointCount < target {
                    line += "；不足目标，不补点"
                }
            }
            return line
        }.joined(separator: "\n")
    }
}
