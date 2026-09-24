import SwiftUI

/// Demo 的闭包配置采用有名称的预设；业务仍可以直接传自定义闭包。
struct DemoAxisSettings {
    var manualRange = false
    var lower = 0.0
    var upper = 100.0
    var intervalOn = false
    var interval = 20.0
    var countOn = false
    var count = 6
    var positions = ""
    var suffix = ""
    var grid: Bool?
    var rotation: CGFloat = 0
    func axis(kind: CartesianAxisKind) -> CartesianAxisModel {
        CartesianAxisModel(kind: kind, min: manualRange ? lower : nil,
            max: manualRange ? max(lower + 0.001, upper) : nil,
            tickInterval: intervalOn ? interval : nil, tickCount: countOn ? count : nil,
            tickPositions: positions.isEmpty ? nil : positions.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.filter(\.isFinite),
            labelFormatter: suffix.isEmpty ? nil : { AxisRenderer.format($0) + suffix },
            showsGridlines: grid, tickLabelRotation: rotation)
    }
    static func categoryItems(_ b: Binding<Self>, isHorizontal: Bool) -> [ChartDemoPanel.Item] {
        [.toggle(label: "固定类目范围", value: b.manualRange), DemoProperty.number("类目下界", b.lower, -0.5...3000), DemoProperty.number("类目上界", b.upper, 0.5...3000)] + (isHorizontal ? [] : [DemoProperty.number("类目标签旋转", b.rotation, -90...90)])
    }
    static func items(_ b: Binding<Self>) -> [ChartDemoPanel.Item] {
        [.toggle(label: "固定值域", value: b.manualRange),
         DemoProperty.number("下界", b.lower, -500...500), DemoProperty.number("上界", b.upper, -400...10000, step: 10),
         .toggle(label: "固定刻度间隔（需固定值域）", value: b.intervalOn), DemoProperty.number("刻度间隔", b.interval, 1...500),
         .toggle(label: "自定义刻度数", value: b.countOn), DemoProperty.integer("刻度数", b.count, 2...20),
         .textField(label: "刻度位置（逗号分隔，空为自动）", value: b.positions),
         .textField(label: "刻度后缀（格式化预设）", value: b.suffix),
         DemoProperty.triState("网格覆盖", b.grid)]
    }
}

struct DemoSeriesSettings {
    var name: String
    var color: UIColor?
    var negativeColor: UIColor?
    var visible = true
    var showsInLegend = true
    var legendOrder = 0
    var axis = 0
    var dash = "跟随主题"
    var marker = "跟随主题"
    var connectNulls = false
    var labels: Bool?
    var shadow: CartesianShadowStyle?
    var palette = false
    var paletteA = UIColor.systemBlue
    var paletteB = UIColor.systemOrange
    var aggregation = "平均"
    var unit = "kW"
    var legendTitle = ""
    var legendSymbol = "自动"
    var legendMarker: PointMarkerSymbol = .circle
    var legendColor: UIColor?
    var dataText = ""
    var reducer: CartesianAggregation? {
        switch aggregation {
        case "求和": return .sum
        case "平均": return .average
        case "最小": return .min
        case "最大": return .max
        case "末值": return .last
        case "自定义：极差": return .custom(name: "极差") { samples in
            guard let lo = samples.map(\.value).min(), let hi = samples.map(\.value).max() else { return nil }; return hi - lo
        }
        default: return nil
        }
    }
    var legendStyle: LegendItemStyle {
        let symbol: ChartLegendSymbol?
        switch legendSymbol {
        case "线": symbol = .line
        case "线和标记": symbol = .lineWithMarker(legendMarker)
        case "标记": symbol = .marker(legendMarker)
        case "矩形": symbol = .rectangle
        case "圆角矩形": symbol = .roundedRectangle
        default: symbol = nil
        }
        return LegendItemStyle(title: legendTitle.isEmpty ? nil : legendTitle, symbol: symbol, symbolColor: legendColor)
    }
    static func items(_ b: Binding<Self>, kind: CartesianDemoKind) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = [.textField(label: "名称", value: b.name), .toggle(label: "显示系列", value: b.visible), .toggle(label: "加入图例", value: b.showsInLegend), DemoProperty.integer("图例排序", b.legendOrder, 0...10)]
        items += DemoProperty.color("系列颜色", b.color) + DemoProperty.color("负值颜色", b.negativeColor)
        if kind != .bar { items.append(DemoProperty.integer("值轴（0 主轴 / 1 次轴）", b.axis, 0...1)) }
        if kind == .line {
            items += [.picker(label: "系列虚线", selection: b.dash, options: ["跟随主题"] + LineDashStyle.allCases.map(\.rawValue)), .picker(label: "系列点形状", selection: b.marker, options: ["跟随主题"] + PointMarkerSymbol.allCases.map(\.rawValue)), .toggle(label: "跨空值连线", value: b.connectNulls)]
        } else {
            items += [.toggle(label: "逐柱配色", value: b.palette), .color(label: "调色板 A", value: b.paletteA), .color(label: "调色板 B", value: b.paletteB)]
        }
        items += [DemoProperty.triState("数据标签", b.labels)] + DemoProperty.shadow("系列阴影", b.shadow)
        if kind == .column {
            items += [.picker(label: "聚合规则", selection: b.aggregation, options: ["不配置", "求和", "平均", "最小", "最大", "末值", "自定义：极差"]), .textField(label: "单位", value: b.unit)]
        }
        items += [.textField(label: "图例标题覆盖（空为系列名）", value: b.legendTitle), .picker(label: "图例符号", selection: b.legendSymbol, options: ["自动", "线", "线和标记", "标记", "矩形", "圆角矩形"]), DemoProperty.choice("图例标记形状", b.legendMarker)]
        items += DemoProperty.color("图例符号颜色", b.legendColor)
        items += [.textField(label: "数据覆盖：逗号分隔，nan 缺测，空为生成数据", value: b.dataText)]
        return items
    }
}

enum CartesianDemoKind: String, CaseIterable {
    case line = "折线图", column = "柱状图", bar = "条形图"
}

struct DemoInteractionSettings {
    var zoom = true
    var maxZoom: CGFloat = 1000
    var minimumVisible = 2
    var zoomAxis: HYMChartZoomAxisMode = .x
    var deceleration = true
    var highlight = true
    var rubberBand = true
    var shared = false
    var crosshair = true
    var dualCrosshair = false
    var crosshairColor = UIColor.secondaryLabel
    var crosshairWidth: CGFloat = 0.75
    var crosshairDash: LineDashStyle = .solid
    var preserve = true
    var tooltip = true
    var header = "{key}"
    var suffix = ""
    var decimals = "自动"
    var popupMode = "内置"
    static func items(_ b: Binding<Self>) -> [ChartDemoPanel.Item] {
        [.toggle(label: "缩放", value: b.zoom), DemoProperty.number("最大缩放倍率", b.maxZoom, 1...3000, step: 1), DemoProperty.integer("最小可见类目", b.minimumVisible, 1...30),
         .picker(label: "缩放轴", selection: Binding(get: { b.wrappedValue.zoomAxis.rawValue }, set: { b.wrappedValue.zoomAxis = HYMChartZoomAxisMode(rawValue: $0) ?? .x }), options: ["x", "y", "xy"]),
         .toggle(label: "惯性", value: b.deceleration), .toggle(label: "拖动选中", value: b.highlight), .toggle(label: "边界回弹", value: b.rubberBand), .toggle(label: "共享提示", value: b.shared),
         .toggle(label: "十字准线", value: b.crosshair), .toggle(label: "双向准线", value: b.dualCrosshair), .color(label: "准线颜色", value: b.crosshairColor), DemoProperty.number("准线宽度", b.crosshairWidth, 0.5...5), DemoProperty.choice("准线样式", b.crosshairDash),
         .toggle(label: "属性更新时保留视口", value: b.preserve), .toggle(label: "容器弹窗", value: b.tooltip),
         .picker(label: "弹窗回调预设", selection: b.popupMode, options: ["内置", "自定义内容", "位置回调"]),
         .textField(label: "表头模板", value: b.header), .textField(label: "数值后缀", value: b.suffix), .picker(label: "小数位", selection: b.decimals, options: ["自动", "0", "1", "2", "3"])]
    }
}
