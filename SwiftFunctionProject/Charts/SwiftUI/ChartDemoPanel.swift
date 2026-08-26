import SwiftUI
import UIKit

/// demo 专用实时属性面板（规格 §8.3）：声明式描述属性项，自动生成控件。
/// 变更经 Binding 直改 demo 的 @State，驱动图表 `configure` 重绘——
/// 面板即数据流的压力测试工具。不进入 SDK API 承诺面。
struct ChartDemoPanel: View {
    struct DemoSection: Identifiable {
        let title: String
        let items: [Item]
        var id: String { title }
    }

    enum Item {
        case slider(label: String, value: Binding<Double>,
                   range: ClosedRange<Double>, step: Double = 1)
        case stepper(label: String, value: Binding<Double>, step: Double)
        case toggle(label: String, value: Binding<Bool>)
        case picker(label: String, selection: Binding<String>, options: [String])
        case color(label: String, value: Binding<UIColor>)
        case textField(label: String, value: Binding<String>)
        case button(label: String, action: () -> Void)
    }

    let sections: [DemoSection]

    var body: some View {
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    row(item)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .slider(let label, let value, let range, let step):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                    Spacer()
                    Text("\(value.wrappedValue, specifier: step < 1 ? "%.1f" : "%.0f")")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: value, in: range, step: step)
            }
        case .stepper(let label, let value, let step):
            Stepper("\(label)：\(value.wrappedValue, specifier: "%.0f")",
                    value: value, step: step)
        case .toggle(let label, let value):
            Toggle(label, isOn: value)
        case .picker(let label, let selection, let options):
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0) }
            }
        case .color(let label, let value):
            HStack {
                Text(label)
                Spacer()
                ColorPicker("",
                            selection: Binding(
                                get: { Color(uiColor: value.wrappedValue) },
                                set: { value.wrappedValue = UIColor($0) }),
                            supportsOpacity: false)
            }
        case .textField(let label, let value):
            TextField(label, text: value)
        case .button(let label, let action):
            Button(label, action: action)
        }
    }
}
