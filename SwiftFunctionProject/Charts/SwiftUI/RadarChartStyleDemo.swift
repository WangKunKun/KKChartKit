import SwiftUI

/// 雷达图样式测试页面：实时配置 + 预览。
struct RadarChartStyleDemo: View {
    @State private var theme = RadarChartTheme()
    @State private var labelFontSize: Double = 14
    @State private var scoreFontSize: Double = 36
    @State private var perDimEnabled: Bool = false

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

    var body: some View {
        VStack(spacing: 12) {
            RadarChart(model: model, theme: themeWithFont(theme), playsAnimationOnAppear: false)
                .frame(height: 340)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            Form {
                Section("① 数据点（数据值顶点）") {
                    Toggle("显示数据点", isOn: $theme.showsVertexDots)
                    colorRow("点颜色", colorBinding(\.vertexDotColor))
                    colorRow("外圈色", colorBinding(\.vertexDotRingColor))
                }

                Section("② 数据连线 / 区域") {
                    Toggle("显示数据多边形", isOn: $theme.showsData)
                    colorRow("连线颜色", colorBinding(\.dataStrokeColor))
                    colorRow("区域填充色", colorBinding(\.dataFillColor))
                }

                Section("③ 标题顶点圆点（最外圈顶点；per-dim 见 ⑦）") {
                    Toggle("显示标题顶点", isOn: $theme.showsLabelDots)
                    colorRow("标题顶点色（统一）", colorBinding(\.labelDotColor))
                    sliderRow("半径", value: Binding(get: { Double(theme.labelDotRadius) },
                                                    set: { theme.labelDotRadius = CGFloat($0) }),
                              range: 1...12, format: "%.0f")
                }

                Section("④ 最外圈边框（独立于网格线）") {
                    Toggle("显示最外圈", isOn: $theme.showsOuterRing)
                    colorRow("最外圈色", colorBinding(\.outerRingColor))
                    sliderRow("线宽", value: Binding(get: { Double(theme.outerRingLineWidth) },
                                                    set: { theme.outerRingLineWidth = CGFloat($0) }),
                              range: 0.5...5, format: "%.1f")
                    Picker("最外圈线型", selection: lineStyleBinding(\.outerRingLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                }

                Section("⑤ 标题字体（统一）") {
                    colorRow("标题颜色", colorBinding(\.labelColor))
                    sliderRow("字号", value: $labelFontSize, range: 8...24, format: "%.0f")
                }

                Section("⑥ 线型（实线 / 虚线）") {
                    Toggle("显示内圈网格", isOn: $theme.showsGridLines)
                    Picker("网格线型", selection: lineStyleBinding(\.gridLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                    Toggle("显示放射轴", isOn: $theme.showsAxes)
                    Picker("轴线型", selection: lineStyleBinding(\.axisLineStyle)) {
                        Text("实线").tag(0); Text("虚线").tag(1)
                    }
                }

                Section("⑦ per-dimension 独立样式（前 3 维 label/数据点/标题顶点）") {
                    Toggle("启用 per-dim（红/绿/蓝）", isOn: $perDimEnabled)
                }

                Section("⑧ 中心分数样式（无副标题）") {
                    colorRow("分数颜色", colorBinding(\.scoreColor))
                    sliderRow("分数字号", value: $scoreFontSize, range: 16...48, format: "%.0f")
                }

                Section("⑨ 装饰 ring（最外圈外）") {
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
                        Text("跟随维度").tag(-1)
                        Text("圆形").tag(0)
                        Text("正六边形").tag(6)
                    }
                }

                Section("其他") {
                    Toggle("显示背景渐变", isOn: $theme.showsBackground)
                }
            }
        }
        .navigationTitle("样式扩展测试")
    }

    private func themeWithFont(_ t: RadarChartTheme) -> RadarChartTheme {
        var t = t
        t.labelFont = .systemFont(ofSize: CGFloat(labelFontSize))
        t.scoreFont = .boldSystemFont(ofSize: CGFloat(scoreFontSize))
        return t
    }

    private func colorBinding(_ keyPath: WritableKeyPath<RadarChartTheme, UIColor>) -> Binding<Color> {
        Binding(get: { Color(theme[keyPath: keyPath]) },
                set: { theme[keyPath: keyPath] = UIColor($0) })
    }

    // 可选颜色（nil → 透明；调色后赋值）
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
            Text(String(format: format, value.wrappedValue)).foregroundStyle(.secondary).frame(width: 32)
        }
    }
}
