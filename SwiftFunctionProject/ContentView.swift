//
//  ContentView.swift
//  SwiftFunctionProject
//
//  Created by wangkun on 2026/7/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 雷达图")
                    .font(.headline)
                    .foregroundStyle(.white)
                RadarChart(model: Self.demoModel)
                    .frame(width: 320, height: 320)
            }
            .padding()
        }
        .background(Color.black)
        .onAppear {
            #if DEBUG
            ChartSelfTest.runAll()
            #endif
        }
    }

    private static var demoModel: RadarChartModel {
        let labels = ["进攻", "防守", "速度", "技巧", "体力", "意识"]
        let values: [Double] = [80, 60, 90, 50, 70, 85]
        let dims = zip(labels, values).map { RadarDimension(label: $0, value: $1) }
        // centerScore=nil：自动算归一化均值（≈72.5）
        return RadarChartModel(dimensions: dims, showsCenterScore: true, centerScore: nil)
    }
}

#Preview {
    ContentView()
}
