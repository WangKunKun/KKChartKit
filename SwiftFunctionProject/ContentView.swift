//
//  ContentView.swift
//  SwiftFunctionProject
//
//  Created by wangkun on 2026/7/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section("雷达图") {
                    NavigationLink("默认主题 demo") {
                        RadarChartBasicDemo()
                    }
                    NavigationLink("样式扩展测试") {
                        RadarChartStyleDemo()
                    }
                }
                Section("热力图") {
                    NavigationLink("默认 demo") {
                        HeatmapChartDemo()
                    }
                }
                Section("折线图") {
                    NavigationLink("折线图 demo（实时属性面板）") {
                        LineChartDemo()
                    }
                }
                Section("柱状图") {
                    NavigationLink("柱状图 demo（实时属性面板）") {
                        ColumnChartDemo()
                    }
                }
                Section("条形图") {
                    NavigationLink("条形图 demo（实时属性面板）") {
                        BarChartDemo()
                    }
                }
                Section("OC demo") {
                    NavigationLink("蛛网图 + 热力图（OC）") {
                        OCChartDemoHost()
                    }
                }
            }
            .navigationTitle("HYMCharts")
            .onAppear {
                #if DEBUG
                ChartSelfTest.runAll()
                #endif
            }
        }
    }
}

/// 默认主题雷达图 demo
struct RadarChartBasicDemo: View {
    private static let demoModel: RadarChartModel = {
        let labels = ["进攻", "防守", "速度", "技巧", "体力", "意识"]
        let values: [Double] = [80, 60, 90, 50, 70, 85]
        return RadarChartModel(
            dimensions: zip(labels, values).map { RadarDimension(label: $0, value: $1) },
            showsCenterScore: true, centerScore: nil)
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 雷达图（默认主题）")
                    .font(.headline)
                    .foregroundStyle(.white)
                RadarChart(model: Self.demoModel) { target, _ in
                    print("🎯 radar hit: kind=\(target.kind) dim=\(target.dimensionIndex)")
                }
                .frame(width: 320, height: 320)
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("默认 demo")
    }
}

#Preview {
    ContentView()
}
