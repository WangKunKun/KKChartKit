import SwiftUI

/// 每种轴系图只有一个页面；配置和面板共用可测试状态。
struct CartesianChartDemo: View {
    @State private var state: CartesianDemoState
    @State private var showsSpecification = false
    @FocusState private var searchFocused: Bool
    init(kind: CartesianDemoKind) { _state = State(initialValue: CartesianDemoState(kind: kind)) }
    var body: some View {
        Group {
            if showsSpecification { ChartSpecificationDemo(kind: state.kind) }
            else { existingDemo }
        }
        .navigationTitle(state.kind.rawValue).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(showsSpecification ? "原生属性" : "通用模型") { showsSpecification.toggle() }
                .accessibilityIdentifier("demo.specification")
        }
    }
    private var existingDemo: some View {
        GeometryReader { geometry in
            let m = state.model
            let t = state.builtTheme
            let measurement = ChartLegendMeasurer.measure(model: m, theme: t, availableWidth: max(0, geometry.size.width - 24 - t.contentInset.left - t.contentInset.right))
            VStack(spacing: 6) {
                preview(model: m, theme: t)
                    .id(state.resetID)
                    .frame(height: min(geometry.size.height * 0.6, state.height + (state.autoLegendHeight ? measurement.additionalChartHeight : 0)))
                    .padding(.horizontal, 12)
                DemoHitReadout(report: state.report)
                if state.kind != .line && state.theme.columnSpacing != nil {
                    Text(state.theme.columnSpacing?.columnWidth != nil
                         ? "固定柱宽与间距：默认从最早数据开始，拖动查看；区间按钮定位起点。"
                         : "间距固定为 pt，柱宽自动分配；放不下时请放大或启用柱状图时间聚合。")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                }
                if state.kind == .line && state.theme.lineSampling != nil {
                    Text(state.samplingStatus)
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                        .accessibilityIdentifier("demo.lineSamplingStatus")
                }
                if (state.kind == .line && state.theme.lineSampling != nil)
                    || ((state.kind == .line || state.kind == .combined) && state.theme.stackedAreaBoundaryMode == .diverging) {
                    DemoLineSamplingReadout(report: state.report)
                }
                HStack {
                    Button("总览") { state.range = nil; state.command += 1 }
                    Button("最近24点") { let n = m.maxPointCount; state.range = max(0, n - 24)..<n; state.command += 1 }
                    if state.kind == .column { Button("所选区间") { if let r = state.report.selectedRange { state.range = r; state.command += 1 } } }
                    Button("重播动画") { state.animation += 1 }
                }.font(.caption).buttonStyle(.bordered)
                TextField("搜索属性名或分组", text: $state.query)
                    .textFieldStyle(.roundedBorder).padding(.horizontal, 16)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($searchFocused).submitLabel(.search)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("demo.search")
                Form {
                    if state.query.isEmpty { Section("布局读数") {
                        Text("图例内容 \(Int(measurement.contentSize.width)) × \(Int(measurement.contentSize.height)) pt · \(measurement.rowCount) 行\n预留高度 \(Int(measurement.additionalChartHeight)) pt · \(measurement.isScrollable ? "滚动" : "完整显示")")
                            .font(.caption)
                        Text("预览最高占页面 60%，给属性面板保留空间。高度不足时可关闭自动追加图例高度或减少图例行数。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    }
                    ChartDemoPanel(sections: CartesianDemoControls.sections($state), query: state.query)
                    Section {
                        Button("恢复默认配置") { state.reset() }.accessibilityIdentifier("demo.reset")
                    }
                }
            }
        }
        .navigationTitle(state.kind.rawValue).navigationBarTitleDisplayMode(.inline)
        .onChange(of: state.seriesCount) { count in state.selectedSeries = min(state.selectedSeries, count - 1) }
        .onChange(of: state.pointCount) { _ in state.report.selectedRange = nil }
    }
    @ViewBuilder private func preview(model: CartesianChartModel, theme: CartesianChartTheme) -> some View {
        switch state.kind {
        case .line: host(LineChartRenderer.self, model, theme)
        case .column: host(ColumnChartRenderer.self, model, theme)
        case .bar: host(BarChartRenderer.self, model, theme)
        case .combined: host(CombinedChartRenderer.self, model, theme)
        }
    }
    private func host<R: HYMChartRenderer>(_ type: R.Type, _ m: CartesianChartModel, _ t: CartesianChartTheme) -> DemoChartHost<R> where R.Model == CartesianChartModel, R.Theme == CartesianChartTheme {
        DemoChartHost(model: m, theme: t, interaction: state.interaction, tooltipTheme: state.tooltipTheme,
            report: state.report, command: state.command, range: state.range, animation: state.animation,
            onVisibility: { id, visible in
                if let index = Int(id.replacingOccurrences(of: "series-", with: "")), state.series.indices.contains(index) { state.series[index].visible = visible }
            })
    }
}
