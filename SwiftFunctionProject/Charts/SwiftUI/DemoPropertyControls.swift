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
        [number(label + " 字号", Binding(get: { value.wrappedValue.pointSize }, set: { value.wrappedValue = value.wrappedValue.withSize($0) }), 8...40),
         .picker(label: label + " 字体", selection: Binding(get: { value.wrappedValue.fontName }, set: { value.wrappedValue = UIFont(name: $0, size: value.wrappedValue.pointSize) ?? value.wrappedValue }), options: Array(Set([value.wrappedValue.fontName, UIFont.systemFont(ofSize: 12).fontName, UIFont.boldSystemFont(ofSize: 12).fontName, UIFont.monospacedSystemFont(ofSize: 12, weight: .regular).fontName])).sorted())]
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
