import SwiftUI

/// 热力图 demo：5 行 × 7 列百分比，含行列标签，点击格子带边框选中 + onHit 日志。
struct HeatmapChartDemo: View {
    private static let model: HeatmapChartModel = {
        let values: [[Double]] = [
            [0, 34, 56, 78, 90, 45, 23, 29, 12, 8],
            [67, 89, 12, 34, 56, 78, 90, 34, 56, 78,],
            [45, 23, 67, 89, 12, 34, 56, 45, 23, 67],
            [78, 90, 45, 23, 67, 89, 12],
            [90],
        ]
        let rows = values.map { row in row.map { HeatmapCell(value: $0) } }
        return HeatmapChartModel(
            rows: rows,
            rowLabels: ["W1", "W2", "W3", "W4", "W5"],
            columnLabels: ["一", "二", "三", "四", "五", "六", "日"])
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 热力图（默认绿色梯度）")
                    .font(.headline)
                Text("点击格子选中（边框高亮）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column))")
                }
                .frame(height: 220)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("热力图 demo")
    }
}
