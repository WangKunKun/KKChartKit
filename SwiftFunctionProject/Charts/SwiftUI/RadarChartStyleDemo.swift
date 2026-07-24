import SwiftUI

/// 雷达图样式测试页面：实时配置 + 预览（覆盖 RadarChartTheme 全部可配置项）。
struct RadarChartStyleDemo: View {
    @State private var theme = RadarChartTheme()
    @State private var labelFontSize: Double = 14
    @State private var scoreFontSize: Double = 36
    @State private var perDimEnabled: Bool = false

    // gridRingFill（enum 不便直接绑）用独立 @State 合成
    @State private var gridRingMode: Int = 0          // 0=none 1=gradient 2=colors
    @State private var gridRingColorA: Color = .red
    @State private var gridRingColorB: Color = .blue
    // decorativeRingRadiusRatio（Optional）用独立 @State 合成
    @State private var decorRatioEnabled: Bool = false
    @State private var decorRatio: Double = 0.9

    // 维度数据；perDimEnabled 时前 3 维用独立 label/数据点/标题顶点 颜色
    private var model: RadarChartModel {
        let labels = ["进攻", "防守", "速度", "技巧", "体力", "意识"]
        let values: [Double] = [80, 60, 90, 50, 70, 85]
        var dims = zip(labels, values).map { RadarDimension(label: $0, value: $1) }
        if perDimEnabled {
            let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue]
            for i in 0..<min(3, dims.count) {
                dims[i].labelColor = colors[i]
                dims[i].dataDotColor = colors[i]
                dims[i].labelDotColor = colors[i]
            }
        }
        return RadarChartModel(dimensions: dims, showsCenterScore: true, centerScore: nil)
    }

    /// 合成最终 theme（字体 + gridRingFill + decorativeRingRadiusRatio）
    private var builtTheme: RadarChartTheme {
        var t = theme
        t.labelFont = .systemFont(ofSize: CGFloat(labelFontSize))
        t.scoreFont = .boldSystemFont(ofSize: CGFloat(scoreFontSize))
        switch gridRingMode {
        case 1: t.gridRingFill = .gradient(from: UIColor(gridRingColorA), to: UIColor(gridRingColorB))
        case 2: t.gridRingFill = .colors([UIColor(gridRingColorA), UIColor(gridRingColorB)])
        default: t.gridRingFill = .none
        }
        t.decorativeRingRadiusRatio = decorRatioEnabled ? CGFloat(decorRatio) : nil
        return t
    }

    var body: some View {
        VStack(spacing: 12) {
            RadarChart(model: model, theme: builtTheme, playsAnimationOnAppear: false)
                .frame(height: 340)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            Form {
                Section("① 数据点（数据值顶点）") {
                    Toggle("显示数据点", isOn: $theme.showsVertexDots)
                    colorRow("点颜色", colorBinding(\.vertexDotColor))
                    colorRow("外圈色", colorBinding(\.vertexDotRingColor))
                    sliderRow("点半径", value: Binding(get: { Double(theme.vertexDotRadius) },
                                                    set: { theme.vertexDotRadius = CGFloat($0) }),
                              range: 1...12, format: "%.0f")
                }

                Section("② 数据连线 / 区域") {
                    Toggle("显示数据多边形", isOn: $theme.showsData)
                    colorRow("连线颜色", colorBinding(\.dataStrokeColor))
                    colorRow("区域填充色", colorBinding(\.dataFillColor))
                    sliderRow("连线线宽", value: Binding(get: { Double(theme.dataLineWidth) },
                                                    set: { theme.dataLineWidth = CGFloat($0) }),
                              range: 0.5...6, format: "%.1f")
                }

                Section("③ 标题顶点圆点（最外圈顶点；per-dim 见 ⑫）") {
                    Toggle("显示标题顶点", isOn: $theme.showsLabelDots)
                    colorRow("标题顶点色（统一）", colorBinding(\.labelDotColor))
                    sliderRow("半径", value: Binding(get: { Double(theme.labelDotRadius) },
                                                    set: { theme.labelDotRadius = CGFloat($0) }),
                              range: 1...12, format: "%.0f")
                }

                Section("④ 标题字体 / 间距") {
                    colorRow("标题颜色", colorBinding(\.labelColor))
                    sliderRow("字号", value: $labelFontSize, range: 8...24, format: "%.0f")
                    sliderRow("外间距 padding", value: Binding(get: { Double(theme.labelOuterPadding) },
                                                    set: { theme.labelOuterPadding = CGFloat($0) }),
                              range: 0...40, format: "%.0f")
                    sliderRow("左右换行宽（<=0 不换行）", value: Binding(get: { Double(theme.labelMaxLineLength) },
                                                    set: { theme.labelMaxLineLength = CGFloat($0) }),
                              range: 0...120, format: "%.0f")
                }

                Section("⑤ 最外圈边框（独立于网格线）") {
                    Toggle("显示最外圈", isOn: $theme.showsOuterRing)
                    colorRow("最外圈色", colorBinding(\.outerRingColor))
                    sliderRow("线宽", value: Binding(get: { Double(theme.outerRingLineWidth) },
                                                    set: { theme.outerRingLineWidth = CGFloat($0) }),
                              range: 0.5...5, format: "%.1f")
                    Picker("最外圈线型", selection: lineStyleBinding(\.outerRingLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                }

                Section("⑥ 网格 / 放射轴") {
                    Toggle("显示内圈网格", isOn: $theme.showsGridLines)
                    colorRow("网格色", colorBinding(\.gridColor))
                    Picker("网格线型", selection: lineStyleBinding(\.gridLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                    Toggle("显示放射轴", isOn: $theme.showsAxes)
                    colorRow("轴色", colorBinding(\.axisColor))
                    Picker("轴线型", selection: lineStyleBinding(\.axisLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                    Stepper("网格圈数 \(theme.gridRingCount)", value: $theme.gridRingCount, in: 1...10)
                }

                Section("⑦ 网格每圈底色（gridRingFill）") {
                    Picker("模式", selection: $gridRingMode) {
                        Text("不填充").tag(0); Text("渐变").tag(1); Text("多色").tag(2)
                    }
                    if gridRingMode != 0 {
                        colorRow("色 A", Binding(get: { gridRingColorA }, set: { gridRingColorA = $0 }))
                        colorRow("色 B", Binding(get: { gridRingColorB }, set: { gridRingColorB = $0 }))
                    }
                }

                Section("⑧ 装饰 ring（最外圈外）") {
                    Toggle("显示装饰 ring", isOn: $theme.showsDecorativeRing)
                    colorRow("装饰 ring 色", colorBinding(\.decorativeRingColor))
                    colorRow("填充色", colorBindingOptional(\.decorativeRingFillColor))
                    sliderRow("线宽", value: Binding(get: { Double(theme.decorativeRingLineWidth) },
                                                    set: { theme.decorativeRingLineWidth = CGFloat($0) }),
                              range: 0.5...5, format: "%.1f")
                    Picker("线型", selection: lineStyleBinding(\.decorativeRingLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                    sliderRow("外间距 inset", value: Binding(get: { Double(theme.decorativeRingInset) },
                                                    set: { theme.decorativeRingInset = CGFloat($0) }),
                              range: 0...30, format: "%.0f")
                    Picker("形状", selection: $theme.decorativeRingSides) {
                        Text("跟随维度").tag(-1); Text("圆形").tag(0); Text("正六边形").tag(6)
                    }
                    Toggle("自定义半径比例", isOn: $decorRatioEnabled)
                    if decorRatioEnabled {
                        sliderRow("比例（相对 viewHalf）", value: $decorRatio, range: 0.1...1, format: "%.2f")
                    }
                }

                Section("⑨ 选中态（顶点点击高亮）") {
                    Toggle("数据顶点可点击", isOn: $theme.dataVertexTappable)
                    Toggle("标题顶点可点击", isOn: $theme.labelVertexTappable)
                    sliderRow("放大倍数", value: Binding(get: { Double(theme.selectionScale) },
                                                    set: { theme.selectionScale = CGFloat($0) }),
                              range: 1...3, format: "%.1f")
                    colorRow("选中描边色", colorBindingOptional(\.selectionStrokeColor))
                    sliderRow("描边线宽", value: Binding(get: { Double(theme.selectionStrokeWidth) },
                                                    set: { theme.selectionStrokeWidth = CGFloat($0) }),
                              range: 0.5...6, format: "%.1f")
                    colorRow("选中变色", colorBindingOptional(\.selectionColor))
                    sliderRow("命中容差", value: Binding(get: { Double(theme.selectionHitPadding) },
                                                    set: { theme.selectionHitPadding = CGFloat($0) }),
                              range: 0...30, format: "%.0f")
                }

                Section("⑩ 中心分数样式") {
                    colorRow("分数颜色", colorBinding(\.scoreColor))
                    sliderRow("分数字号", value: $scoreFontSize, range: 16...48, format: "%.0f")
                }

                Section("⑪ 背景") {
                    Toggle("显示背景渐变", isOn: $theme.showsBackground)
                    colorRow("渐变起始色", colorBinding(\.backgroundGradientStart))
                    colorRow("渐变结束色", colorBinding(\.backgroundGradientEnd))
                    sliderRow("卡片圆角", value: Binding(get: { Double(theme.cardCornerRadius) },
                                                    set: { theme.cardCornerRadius = CGFloat($0) }),
                              range: 0...40, format: "%.0f")
                }

                Section("⑫ per-dimension 独立样式（前 3 维 label/数据点/标题顶点）") {
                    Toggle("启用 per-dim（红/绿/蓝）", isOn: $perDimEnabled)
                }
            }
        }
        .navigationTitle("样式扩展测试")
    }

    // MARK: - 绑定辅助

    private func colorBinding(_ keyPath: WritableKeyPath<RadarChartTheme, UIColor>) -> Binding<Color> {
        Binding(get: { Color(theme[keyPath: keyPath]) },
                set: { theme[keyPath: keyPath] = UIColor($0) })
    }

    private func colorBindingOptional(_ keyPath: WritableKeyPath<RadarChartTheme, UIColor?>) -> Binding<Color> {
        Binding(get: { Color(theme[keyPath: keyPath] ?? .clear) },
                set: { theme[keyPath: keyPath] = UIColor($0) })
    }

    private func lineStyleBinding(_ keyPath: WritableKeyPath<RadarChartTheme, ChartLineStyle>) -> Binding<Int> {
        Binding(get: { if case .dashed = theme[keyPath: keyPath] { return 1 }; return 0 },
                set: { theme[keyPath: keyPath] = ($0 == 1) ? .dashed() : .solid })
    }

    private func colorRow(_ title: String, _ binding: Binding<Color>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker("", selection: binding).labelsHidden().frame(width: 60)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue)).foregroundStyle(.secondary).frame(width: 40)
        }
    }
}
