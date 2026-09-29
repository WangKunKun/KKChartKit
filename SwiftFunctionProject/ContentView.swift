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
                    NavigationLink("混合图") { CartesianChartDemo(kind: .combined) }
                }
                Section("语言互操作示例") {
                    NavigationLink("Objective-C 接入") {
                        OCChartDemoHost().toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NavigationLink("轴系验证") { OCChartDemoHost(className: "CartesianOCDemoViewController") }
                            }
                        }
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

#Preview { ContentView() }
