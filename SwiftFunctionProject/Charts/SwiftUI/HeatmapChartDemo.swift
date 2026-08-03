import SwiftUI

/// 热力图 demo：5 行百分比，含 nil 占位格 + 部分自定义 tooltip 文本。
/// 点击有效格子：上方/下方自动避让弹窗；无效格不绘制、不可点。
struct HeatmapChartDemo: View {
    private static let model: HeatmapChartModel = {
        let values: [[Double?]] = [
            [0, 34, 56, nil, 90, 45, 23, 29, 12, 8],
            [67, 89, 12, 34, 56, 78, 90, 34, 56, 78],
            [45, 23, 67, nil, 12, 34, 56, 45, 23, 67],
            [78, 90, 45, 23, 67, 89, 12, nil, nil, nil],
            [90],
        ]
        let rows = values.map { row in
            row.map { v -> HeatmapCell in
                guard let v else { return HeatmapCell.placeholder() }
                // 个别格子演示自定义 tooltip 文本
                if v == 90 { return HeatmapCell(value: v, tooltipText: "满分 \(Int(v))") }
                return HeatmapCell(value: v)
            }
        }
        return HeatmapChartModel(
            rows: rows,
            rowLabels: ["W1", "W2", "W3", "W4", "W5"],
            columnLabels: ["一", "二", "三", "四", "五", "六", "日"])
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 热力图（默认绿色 + 点击弹窗）")
                    .font(.headline)
                Text("点击有效格子弹窗（上下避让）；nil 格子占位不绘制")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column)) tip=\(target.tooltipText ?? "nil")")
                } popup: { context in
                    if let h = context.target as? HeatmapHitTarget {
                        AnyView(
                            VStack(spacing: 2) {
                                Text("(\(h.row),\(h.column))")
                                    .font(.system(size: 13, weight: .semibold))
                                if let tip = h.tooltipText { Text(tip).font(.system(size: 11)) }
                            }
                            .foregroundStyle(.white)
                        )
                    } else {
                        AnyView(EmptyView())
                    }
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
