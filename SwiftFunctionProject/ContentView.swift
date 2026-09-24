import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section("图表调试 · 每类一个页面") {
                    NavigationLink("雷达图") { RadarChartStyleDemo() }
                    NavigationLink("热力图") { HeatmapChartDemo() }
                    NavigationLink("折线图") { LineChartDemo() }
                    NavigationLink("柱状图") { ColumnChartDemo() }
                    NavigationLink("条形图") { BarChartDemo() }
                }
                Section("语言互操作示例") {
                    NavigationLink("Objective-C 接入") { OCChartDemoHost() }
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

#Preview { ContentView() }
