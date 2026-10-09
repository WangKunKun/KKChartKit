import SwiftUI
import UIKit

/// 仅供 Demo 使用。面板直接绑定配置值，避免控件状态与最终主题之间出现第二份配置。
enum DemoProperty {
    typealias Item = ChartDemoPanel.Item
    static func number<T: BinaryFloatingPoint>(_ label: String, _ value: Binding<T>, _ range: ClosedRange<Double> = 0...40, step: Double = 0.5) -> Item {
        .slider(label: label, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = T($0) }), range: range, step: step)
    }
    static func integer(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Double> = 0...20) -> Item {
        .slider(label: label, value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }), range: range)
    }
    static func index(_ label: String, _ value: Binding<Int>, count: Int) -> Item {
        .picker(label: label, selection: Binding(get: { String(min(value.wrappedValue, count - 1)) }, set: { value.wrappedValue = min(max(0, Int($0) ?? 0), count - 1) }), options: (0..<max(1, count)).map(String.init))
    }
    static func optional<T>(_ value: Binding<T?>, default fallback: T) -> Binding<T> {
        Binding(get: { value.wrappedValue ?? fallback }, set: { value.wrappedValue = $0 })
    }
    static func enabled<T>(_ label: String, _ value: Binding<T?>, default fallback: T) -> Item {
        .toggle(label: label, value: Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? (value.wrappedValue ?? fallback) : nil }))
    }
    static func color(_ label: String, _ value: Binding<UIColor?>) -> [Item] {
        [enabled("自定义 \(label)", value, default: .systemBlue)] + (value.wrappedValue == nil ? [] : [.color(label: label, value: optional(value, default: .systemBlue))])
    }
    static func font(_ label: String, _ value: Binding<UIFont>) -> [Item] {
        // .SFUI-* 是系统私有字体名，不能通过 UIFont(name:) 可靠重建（会退回 Times）。
        // 保存 UIFont/descriptor，并使用公共工厂创建系统字体；调字号仍保留字体类型。
        let size = value.wrappedValue.pointSize
        var choices: [(String, UIFont)] = [
            ("系统常规", .systemFont(ofSize: size)),
            ("系统半粗", .systemFont(ofSize: size, weight: .semibold)),
            ("系统粗体", .boldSystemFont(ofSize: size)),
            ("系统等宽", .monospacedSystemFont(ofSize: size, weight: .regular))
        ]
        if !choices.contains(where: { $0.1.isEqual(value.wrappedValue) }) {
            choices.append(("当前字体 " + value.wrappedValue.fontName, value.wrappedValue))
        }
        let selection = Binding<String>(get: {
            choices.first { $0.1.withSize(value.wrappedValue.pointSize).isEqual(value.wrappedValue) }?.0 ?? choices[0].0
        }, set: { name in
            if let font = choices.first(where: { $0.0 == name })?.1 {
                value.wrappedValue = font.withSize(value.wrappedValue.pointSize)
            }
        })
        return [number(label + " 字号", Binding(get: { value.wrappedValue.pointSize }, set: { value.wrappedValue = value.wrappedValue.withSize($0) }), 8...40),
                .picker(label: label + " 字体", selection: selection, options: choices.map { $0.0 })]
    }
    static func insets(_ label: String, _ value: Binding<UIEdgeInsets>) -> [Item] {
        [number(label + " 上", value.top), number(label + " 左", value.left), number(label + " 下", value.bottom), number(label + " 右", value.right)]
    }
    static func size(_ label: String, _ value: Binding<CGSize>, _ range: ClosedRange<Double> = 0...100) -> [Item] {
        [number(label + " 宽", value.width, range), number(label + " 高", value.height, range)]
    }
    static func choice<T: RawRepresentable & CaseIterable>(_ label: String, _ value: Binding<T>) -> Item where T.RawValue == String {
        .picker(label: label, selection: Binding(get: { value.wrappedValue.rawValue }, set: { if let v = T(rawValue: $0) { value.wrappedValue = v } }), options: T.allCases.map(\.rawValue))
    }
    static func triState(_ label: String, _ value: Binding<Bool?>) -> Item {
        .picker(label: label, selection: Binding(get: { value.wrappedValue.map { $0 ? "开启" : "关闭" } ?? "跟随默认" }, set: { value.wrappedValue = $0 == "跟随默认" ? nil : $0 == "开启" }), options: ["跟随默认", "开启", "关闭"])
    }
    static func lineStyle(_ label: String, _ value: Binding<ChartLineStyle>) -> [Item] {
        let dashed = Binding(get: { if case .dashed = value.wrappedValue { return true }; return false }, set: { value.wrappedValue = $0 ? .dashed() : .solid })
        var items: [Item] = [.toggle(label: label + " 虚线", value: dashed)]
        if case .dashed = value.wrappedValue {
            items.append(number(label + " 线段", Binding(get: { if case .dashed(let d, _) = value.wrappedValue { return d }; return 4 }, set: { if case .dashed(_, let g) = value.wrappedValue { value.wrappedValue = .dashed(dashLength: $0, gap: g) } }), 1...20))
            items.append(number(label + " 间隔", Binding(get: { if case .dashed(_, let g) = value.wrappedValue { return g }; return 3 }, set: { if case .dashed(let d, _) = value.wrappedValue { value.wrappedValue = .dashed(dashLength: d, gap: $0) } }), 1...20))
        }
        return items
    }
    static func shadow(_ label: String, _ value: Binding<CartesianShadowStyle?>) -> [Item] {
        var items = [enabled(label, value, default: CartesianShadowStyle())]
        if value.wrappedValue != nil {
            let s = optional(value, default: CartesianShadowStyle())
            items += [.color(label: "阴影颜色", value: s.color), number("偏移 X", s.offsetX, -10...10), number("偏移 Y", s.offsetY, -10...10), number("模糊半径", s.blurRadius, 0...12), number("透明度", s.opacity, 0...1, step: 0.05)]
        }
        return items
    }
}

/// 精确整数输入：完成编辑时提交，避免逐字输入“123”时中间的“1”被下限钳制。
struct DemoIntegerInput: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField(label, text: $draft).keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focused).submitLabel(.done)
                    .accessibilityIdentifier("demo.input." + label)
                    .onSubmit { commit(); focused = false }
                Button("应用") { commit(); focused = false }
                    .buttonStyle(.bordered).accessibilityIdentifier("demo.apply." + label)
            }
        }
        .onAppear { draft = String(value) }
        .onChange(of: value) { draft = String($0) }
        .onChange(of: focused) { if !$0 { commit() } }
    }

    static func resolved(_ text: String, previous: Int, range: ClosedRange<Int>) -> Int {
        guard let parsed = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return previous }
        return min(range.upperBound, max(range.lowerBound, parsed))
    }
    private func commit() {
        value = Self.resolved(draft, previous: value, range: range)
        draft = String(value)
    }
}
