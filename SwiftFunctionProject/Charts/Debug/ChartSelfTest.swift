#if DEBUG
import Foundation
import CoreGraphics
import UIKit

/// 框架级 DEBUG 断言自检（替代旧 RadarSelfTest）。App 启动调一次。
public enum ChartSelfTest {
    public static func runAll() {
        // —— RadarGeometry —— N=4，ratio=1，radius=10，center=(0,0)
        let top = RadarGeometry.point(index: 0, count: 4, center: .zero, radius: 10, ratio: 1)
        assert(abs(top.x) < 0.001 && abs(top.y - (-10)) < 0.001, "top vertex wrong: \(top)")

        let bottom = RadarGeometry.point(index: 2, count: 4, center: .zero, radius: 10, ratio: 1)
        assert(abs(bottom.x) < 0.001 && abs(bottom.y - 10) < 0.001, "bottom vertex wrong: \(bottom)")

        let right = RadarGeometry.point(index: 1, count: 4, center: .zero, radius: 10, ratio: 1)
        assert(abs(right.x - 10) < 0.001 && abs(right.y) < 0.001, "right vertex wrong: \(right)")

        // 越界 ratio 应裁剪到 [0,1]：ratio=2 等价 ratio=1
        let over = RadarGeometry.point(index: 0, count: 4, center: .zero, radius: 10, ratio: 2)
        assert(abs(over.y - (-10)) < 0.001, "ratio clamp wrong")

        // —— resolvedCenterScore 三态 ——
        let hidden = RadarChartModel(dimensions: [RadarDimension(label: "a", value: 80)],
                                     showsCenterScore: false)
        assert(resolvedCenterScore(hidden) == nil, "hidden should be nil")

        // 两维 80/100、60/100 → 均值 0.7 × 100 = 70
        let auto = RadarChartModel(dimensions: [
            RadarDimension(label: "a", value: 80),
            RadarDimension(label: "b", value: 60),
        ])
        let s = resolvedCenterScore(auto)!
        assert(abs(s - 70) < 0.001, "auto avg should be 70, got \(s)")

        // 手动值优先
        let manual = RadarChartModel(dimensions: [RadarDimension(label: "a", value: 10)],
                                     showsCenterScore: true, centerScore: 88)
        assert(resolvedCenterScore(manual) == 88, "manual should be 88")

        // —— HYMColorInterpolation ——
        let black = UIColor.black, white = UIColor.white
        assertTintsEqual(HYMColorInterpolation.lerp(black, white, 0), (0, 0, 0), eps: 0.001, msg: "lerp t=0")
        assertTintsEqual(HYMColorInterpolation.lerp(black, white, 0.5), (0.5, 0.5, 0.5), eps: 0.01, msg: "lerp mid")

        // —— 交互默认空命中 ——
        let renderer = RadarChartRenderer()
        assert(renderer.hitTest(.zero) == nil, "default hitTest should be nil")

        // —— RadarHitTarget / 通用 kind 槽位 ——
        let rht = RadarHitTarget(category: .dataVertex, dimensionIndex: 3)
        assert(rht.kind == "dataVertex", "dataVertex kind wrong: \(rht.kind)")
        assert(rht.index == 3, "index should equal dimensionIndex")
        assert(rht.identifier == "dataVertex:3", "identifier wrong: \(rht.identifier)")
        assert(RadarHitTarget(category: .labelVertex, dimensionIndex: 2).kind == "labelVertex")
        struct _PlainTarget: HYMChartHitTarget { let identifier = "x"; let index = 0 }
        assert(_PlainTarget().kind == "", "default kind should be empty")

        // —— Radar hitTest / applySelection 基本行为（render 后）——
        let tapRenderer = RadarChartRenderer()
        let tapModel = RadarChartModel(dimensions: [
            RadarDimension(label: "a", value: 80),
            RadarDimension(label: "b", value: 60),
        ])
        tapRenderer.render(model: tapModel, theme: RadarChartTheme(),
                           context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
                                                          center: CGPoint(x: 100, y: 100)))
        assert(tapRenderer.hitTest(CGPoint(x: 100, y: 100)) == nil, "center should not hit any vertex")
        tapRenderer.applySelection(nil)   // 不崩溃即可

        // —— HeatmapGeometry ——
        let hmLayout = HeatmapGeometry.layout(
            bounds: CGRect(x: 0, y: 0, width: 30, height: 30),
            rows: 3, columns: 4, rowSpacing: 0, columnSpacing: 0, alignment: .leading)
        assert(abs(hmLayout.cellSize - 7.0) < 0.001,
               "heatmap cellSize should be min(30/4,30/3)=7, got \(hmLayout.cellSize)")
        let hm00 = HeatmapGeometry.cellFrame(row: 0, col: 0, layout: hmLayout, rowSpacing: 0, columnSpacing: 0)
        assert(abs(hm00.minX) < 0.001 && abs(hm00.minY) < 0.001, "heatmap (0,0) at origin, got \(hm00)")
        let hm12 = HeatmapGeometry.cellFrame(row: 1, col: 2, layout: hmLayout, rowSpacing: 0, columnSpacing: 0)
        assert(abs(hm12.minX - 14.0) < 0.001 && abs(hm12.minY - 7.0) < 0.001, "heatmap (1,2) wrong, got \(hm12)")
        // 行/列间距分开：rowSpacing=2, columnSpacing=4
        let hmSp = HeatmapGeometry.layout(bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                                          rows: 2, columns: 2, rowSpacing: 2, columnSpacing: 4, alignment: .leading)
        let hmSp11 = HeatmapGeometry.cellFrame(row: 1, col: 1, layout: hmSp, rowSpacing: 2, columnSpacing: 4)
        // cellSize = min((100-4)/2, (100-2)/2) = min(48,49) = 48
        assert(abs(hmSp.cellSize - 48.0) < 0.001, "cellSize with spacing wrong: \(hmSp.cellSize)")
        // (1,1): x = 48+4=52? 实际 x = 0 + 1*(48+4)=52, y = 0 + 1*(48+2)=50
        assert(abs(hmSp11.minX - 52.0) < 0.001 && abs(hmSp11.minY - 50.0) < 0.001,
               "(1,1) with split spacing wrong: \(hmSp11)")

        // —— HeatmapChartModel ——
        let hmModel = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell(value: 20), HeatmapCell(value: 30)],
            [HeatmapCell(value: 40), HeatmapCell(value: 50)]   // 锯齿行
        ])
        assert(hmModel.maxColumns == 3, "maxColumns should be 3, got \(hmModel.maxColumns)")
        let hmRange = hmModel.resolvedValueRange
        assert(abs(hmRange.lowerBound - 0) < 0.001 && abs(hmRange.upperBound - 50) < 0.001,
               "resolved range 0...50 (default 0...dataMax), got \(hmRange)")
        // 默认值域 = 0...数据max；显式 valueRange / min,max 优先
        let autoRangeT = HeatmapChartModel(rows: [[HeatmapCell(value: 20)]]).resolvedValueRange
        assert(abs(autoRangeT.lowerBound) < 0.001 && abs(autoRangeT.upperBound - 20) < 0.001,
               "auto range should be 0...dataMax(20), got \(autoRangeT)")
        let fixedRangeT = HeatmapChartModel(rows: [[HeatmapCell(value: 20)]], minValue: 0, maxValue: 90).resolvedValueRange
        assert(abs(fixedRangeT.lowerBound) < 0.001 && abs(fixedRangeT.upperBound - 90) < 0.001,
               "explicit min/max should be 0...90, got \(fixedRangeT)")
        // 用户场景：value=20 在 0...90 值域 + .alpha 色阶 → t≈0.222 → 有颜色（非全透明，即非 emptyColor）
        let uScale = HeatmapColorScale.alpha(.black)
        let uT = (20 - fixedRangeT.lowerBound) / max(1e-9, fixedRangeT.upperBound - fixedRangeT.lowerBound)
        var uA: CGFloat = 0, uR: CGFloat = 0, uG: CGFloat = 0, uB: CGFloat = 0
        uScale.color(at: CGFloat(uT)).getRed(&uR, green: &uG, blue: &uB, alpha: &uA)
        assert(abs(uA - 0.222) < 0.01,
               "value=20 in 0...90 with .alpha → t≈0.22 → should have color, got alpha \(uA)")

        // —— HeatmapColorScale ——
        let hmScale = HeatmapColorScale.gradient(low: .black, high: .white)
        assertTintsEqual(hmScale.color(at: 0), (0, 0, 0), eps: 0.001, msg: "scale t=0 black")
        assertTintsEqual(hmScale.color(at: 1), (1, 1, 1), eps: 0.001, msg: "scale t=1 white")
        assertTintsEqual(hmScale.color(at: 0.5), (0.5, 0.5, 0.5), eps: 0.01, msg: "scale t=0.5 mid")
        let hmStops = HeatmapColorScale.stops([(value: 0, color: .black), (value: 100, color: .white)])
        assertTintsEqual(hmStops.color(at: 0.5), (0.5, 0.5, 0.5), eps: 0.01, msg: "stops t=0.5 mid")

        // —— HeatmapColorScale.alpha：单色 + 透明度按 t ——
        let hmAlpha = HeatmapColorScale.alpha(.black)
        var aA: CGFloat = 0
        var aR: CGFloat = 0, aG: CGFloat = 0, aB: CGFloat = 0
        hmAlpha.color(at: 1).getRed(&aR, green: &aG, blue: &aB, alpha: &aA)
        assert(abs(aA - 1) < 0.001, "alpha t=1 should be opaque, got \(aA)")
        hmAlpha.color(at: 0).getRed(&aR, green: &aG, blue: &aB, alpha: &aA)
        assert(abs(aA) < 0.001, "alpha t=0 should be transparent, got \(aA)")
        hmAlpha.color(at: 0.5).getRed(&aR, green: &aG, blue: &aB, alpha: &aA)
        assert(abs(aA - 0.5) < 0.001, "alpha t=0.5 should be 0.5, got \(aA)")

        // —— Heatmap 命中/选中 ——
        let hmRenderer = HeatmapChartRenderer()
        assert(hmRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil, "renderer without render should miss")
        hmRenderer.render(model: hmModel, theme: HeatmapChartTheme(),
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 300, height: 200),
                                                         center: .zero))
        if let hit = hmRenderer.hitTest(CGPoint(x: 5, y: 5)) as? HeatmapHitTarget {
            assert(hit.row == 0 && hit.column == 0, "should hit (0,0), got \(hit.row),\(hit.column)")
        } else {
            assertionFailure("should hit (0,0) after render")
        }
        hmRenderer.applySelection(HeatmapHitTarget(row: 0, column: 0))   // 选中 (0,0) 不崩溃
        hmRenderer.applySelection(nil)                                    // 取消不崩溃

        // —— HYMChartTooltipGeometry 定位 ——
        // 锚点居中、上方充足 → .top，frame 不越界
        let ttContainer = CGRect(x: 0, y: 0, width: 200, height: 200)
        let ttAnchor = CGRect(x: 90, y: 100, width: 20, height: 20)   // midX=100, minY=100
        let ttSize = CGSize(width: 60, height: 30)
        let ttTop = HYMChartTooltipGeometry.resolve(anchor: ttAnchor, size: ttSize,
                                                    container: ttContainer,
                                                    preferred: [.top, .bottom], gap: 6)
        assert(ttTop?.placement == .top, "should pick .top when room above, got \(String(describing: ttTop?.placement))")
        // .top: 底边 = anchor.minY - gap = 94；frame.minY = 94 - 30 = 64；不越界
        assert(abs((ttTop?.frame.minY ?? 0) - 64) < 0.001, "top frame minY should be 64, got \(String(describing: ttTop?.frame.minY))")
        assert(abs((ttTop?.frame.midX ?? 0) - 100) < 0.001, "top should center on anchor midX")
        assert(ttTop!.arrowX >= ttTop!.frame.minX && ttTop!.arrowX <= ttTop!.frame.maxX,
               "arrowX must stay inside frame")

        // 锚点贴顶（上方不够，gap+size 超出）→ 翻转 .bottom
        let topAnchor = CGRect(x: 90, y: 5, width: 20, height: 20)    // minY=5，上方只剩 5pt < gap+30
        let flip = HYMChartTooltipGeometry.resolve(anchor: topAnchor, size: ttSize,
                                                   container: ttContainer,
                                                   preferred: [.top, .bottom], gap: 6)
        assert(flip?.placement == .bottom, "should flip to .bottom when top overflows")

        // 上下都不够（锚点使两侧都溢出），但容器能容纳 tooltip → 选溢出更少方向并裁进 container 不越界
        // 注：用例须保证 container 高度 ≥ tooltip 高度，否则物理上无法完全裁进 container。
        let sqContainer = CGRect(x: 0, y: 0, width: 200, height: 40)  // height 40 ≥ tooltip 30
        let sqAnchor = CGRect(x: 90, y: 2, width: 20, height: 20)     // minY=2, maxY=22
        let squeezed = HYMChartTooltipGeometry.resolve(anchor: sqAnchor, size: ttSize,
                                                       container: sqContainer,
                                                       preferred: [.top, .bottom], gap: 6)
        assert(squeezed != nil, "must still produce a frame when nothing fits fully")
        assert(squeezed!.frame.minY >= sqContainer.minY - 0.001 && squeezed!.frame.maxY <= sqContainer.maxY + 0.001,
               "squeezed frame must be clipped inside container, got \(squeezed!.frame)")

        // 水平超出 → 贴边
        let sideAnchor = CGRect(x: 180, y: 100, width: 20, height: 20) // midX=190，弹窗会右溢出
        let side = HYMChartTooltipGeometry.resolve(anchor: sideAnchor, size: ttSize,
                                                   container: ttContainer,
                                                   preferred: [.top, .bottom], gap: 6)
        assert(side!.frame.maxX <= ttContainer.maxX + 0.001,
               "right overflow must be clipped, got \(side!.frame.maxX)")

        // size 为 0 → nil
        assert(HYMChartTooltipGeometry.resolve(anchor: ttAnchor, size: .zero,
                                               container: ttContainer,
                                               preferred: [.top], gap: 6) == nil,
               "zero size should return nil")

        // —— 通用 tooltip 槽位默认值 ——
        struct _TipTarget: HYMChartHitTarget { let identifier = "t"; let index = 0 }
        assert(_TipTarget().tooltipText == nil, "default tooltipText should be nil")
        let _tipRenderer = HeatmapChartRenderer()
        assert(_tipRenderer.tooltipAnchor(for: _TipTarget()) == nil,
               "default tooltipAnchor should be nil")

        // —— HeatmapCell 无效占位 ——
        assert(HeatmapCell.placeholder().isValid == false, "placeholder should be invalid")
        assert(HeatmapCell(value: 50).isValid == true, "default cell should be valid")
        // 无效格不参与色阶归一化：[10, placeholder, 30] → range 10...30
        let mixed7 = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell.placeholder(), HeatmapCell(value: 30)]
        ])
        let mixedRange7 = mixed7.resolvedValueRange
        assert(abs(mixedRange7.lowerBound - 0) < 0.001 && abs(mixedRange7.upperBound - 30) < 0.001,
               "invalid cells excluded; default range 0...30, got \(mixedRange7)")

        // —— Heatmap value 默认格式化 ——
        assert(HeatmapChartRenderer.format(80.0) == "80", "80.0 should format to '80'")
        assert(HeatmapChartRenderer.format(80.5) == "80.5", "80.5 should format to '80.5'")
        assert(HeatmapChartRenderer.format(0.0) == "0", "0.0 should format to '0'")

        // —— 无效格不命中、有效格命中带 tooltipText ——
        let nilModel8 = HeatmapChartModel(rows: [
            [HeatmapCell.placeholder(), HeatmapCell(value: 50, tooltipText: "自定义")]
        ])
        let nilRenderer8 = HeatmapChartRenderer()
        nilRenderer8.render(model: nilModel8, theme: HeatmapChartTheme(),
                            context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 300, height: 200),
                                                           center: .zero))
        // theme 默认 rowSpacing=columnSpacing=3, leading, 无 rowLabels/columnLabels → cellBounds=bounds；
        // cellSize=min((300-3)/2, 200)=148；(0,0)=invalid frame(0,0,148,148)；(0,1)=valid frame(151,0,148,148)
        let hitInvalid8 = nilRenderer8.hitTest(CGPoint(x: 5, y: 5))   // 落在 (0,0) 无效格位置 → 未进命中缓存 → nil
        assert(hitInvalid8 == nil, "invalid cell must not be hit, got \(String(describing: hitInvalid8))")
        let hitValid8 = nilRenderer8.hitTest(CGPoint(x: 200, y: 50))  // 落在 (0,1) 有效格
        if let h = hitValid8 as? HeatmapHitTarget {
            assert(h.row == 0 && h.column == 1, "should hit (0,1)")
            assert(h.tooltipText == "自定义", "custom tooltipText should win, got \(String(describing: h.tooltipText))")
        } else {
            assertionFailure("should hit valid cell (0,1)")
        }
        // 默认 value 格式化
        let defModel8 = HeatmapChartModel(rows: [[HeatmapCell(value: 42)]])
        let defRenderer8 = HeatmapChartRenderer()
        defRenderer8.render(model: defModel8, theme: HeatmapChartTheme(),
                            context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                                                           center: .zero))
        let hitDef8 = defRenderer8.hitTest(CGPoint(x: 50, y: 50)) as? HeatmapHitTarget
        assert(hitDef8?.tooltipText == "42", "default tooltipText should be formatted value, got \(String(describing: hitDef8?.tooltipText))")

        // —— HYMChartHitContext 构造 ——
        let _ctx = HYMChartHitContext(target: _PlainTarget(), frame: CGRect(x: 1, y: 2, width: 3, height: 4),
                                      location: CGPoint(x: 5, y: 6))
        assert(abs(_ctx.frame.minX - 1) < 0.001, "HitContext.frame wrong: \(_ctx.frame)")
        assert(abs(_ctx.location.x - 5) < 0.001, "HitContext.location wrong: \(_ctx.location)")
        assert(_ctx.target.identifier == "x", "HitContext.target wrong")

        // —— hitFrame 协议默认 nil ——
        // 未实现 hitFrame 的 renderer（render 前 / 默认实现）应返回 nil
        let _fr = HeatmapChartRenderer()
        assert(_fr.hitFrame(for: _PlainTarget()) == nil,
               "hitFrame default should be nil before implementation")

        // —— Heatmap hitFrame：命中单元返回缓存 frame，且独立于 showsTooltipOnHit ——
        let hfModel = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell(value: 20), HeatmapCell(value: 30)]
        ])
        let hfRenderer = HeatmapChartRenderer()
        var hfTheme = HeatmapChartTheme()
        hfTheme.showsTooltipOnHit = false   // 关键：关掉内置 tooltip，hitFrame 仍必须可用
        hfRenderer.render(model: hfModel, theme: hfTheme,
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 300, height: 200),
                                                         center: .zero))
        let hfClick = CGPoint(x: 5, y: 5)
        if let hfHit = hfRenderer.hitTest(hfClick) {
            let hfFrame = hfRenderer.hitFrame(for: hfHit)
            assert(hfFrame != nil, "heatmap hitFrame should not be nil even with tooltip off")
            assert(hfFrame?.contains(hfClick) == true,
                   "heatmap hitFrame should contain the click point, got \(String(describing: hfFrame))")
        } else {
            assertionFailure("heatmap should hit (0,0)")
        }

        // —— Radar hitFrame：顶点 center+radius → 正方形 frame ——
        let rdModel = RadarChartModel(dimensions: [
            RadarDimension(label: "a", value: 80),
            RadarDimension(label: "b", value: 60),
        ])
        let rdRenderer = RadarChartRenderer()
        rdRenderer.render(model: rdModel, theme: RadarChartTheme(),
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 200, height: 200),
                                                         center: CGPoint(x: 100, y: 100)))
        let rdFrame = rdRenderer.hitFrame(for: RadarHitTarget(category: .dataVertex, dimensionIndex: 0))
        assert(rdFrame != nil, "radar dataVertex hitFrame should not be nil")
        if let rf = rdFrame {
            assert(rf.width > 0 && abs(rf.width - rf.height) < 0.001,
                   "radar hitFrame should be a non-zero square, got \(rf)")
        }
        // 不存在的维度 → nil
        assert(rdRenderer.hitFrame(for: RadarHitTarget(category: .dataVertex, dimensionIndex: 99)) == nil,
               "radar hitFrame for missing dimension should be nil")

        // —— HYMChartTooltip contentView 模式（外壳复用，内容 view 尺寸驱动）——
        let tipLabel = UILabel()
        tipLabel.text = "内容"
        tipLabel.font = .systemFont(ofSize: 16)
        var tipTheme = HYMChartTooltipTheme()
        tipTheme.contentInset = .zero
        tipTheme.showsArrow = false
        let expSize = tipLabel.sizeThatFits(CGSize(width: tipTheme.maxWidth, height: .greatestFiniteMagnitude))
        let tipView = HYMChartTooltip()
        tipView.configure(contentView: tipLabel, theme: tipTheme)
        let tipSize = tipView.sizeThatFits(CGSize(width: tipTheme.maxWidth, height: .greatestFiniteMagnitude))
        assert(abs(tipSize.width - expSize.width) < 0.001 && abs(tipSize.height - expSize.height) < 0.001,
               "contentView mode sizeThatFits should equal contentView size (inset 0, no arrow), got \(tipSize) vs \(expSize)")

        // —— HYMChartTooltipController.show(contentView:) 不崩 ——
        let ctrlHost = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let ctrl = HYMChartTooltipController(host: ctrlHost)
        let popLabel = UILabel()
        popLabel.text = "弹窗内容"
        popLabel.font = .systemFont(ofSize: 14)
        ctrl.show(anchor: CGRect(x: 90, y: 100, width: 20, height: 20),
                  contentView: popLabel,
                  in: ctrlHost.bounds,
                  preferred: [.top, .bottom])

        // —— Cartesian 数据模型 ——
        let cartModel = CartesianChartModel(
            title: "t",
            series: [CartesianSeriesElement(name: "a", data: [3.0, 97.0]),
                     CartesianSeriesElement(name: "b", data: [-5.0])])
        assert(cartModel.maxPointCount == 2, "maxPointCount should be 2, got \(cartModel.maxPointCount)")
        let db = cartModel.dataBounds!
        assert(abs(db.min - (-5.0)) < 0.001 && abs(db.max - 97.0) < 0.001,
               "dataBounds should be (-5, 97), got \(String(describing: db))")
        // 空 series → nil
        assert(CartesianChartModel(series: []).dataBounds == nil, "empty series should have nil bounds")
        // 类目标签：显式优先，空 → 自动数字 1...n
        assert(CartesianChartModel(series: []).categoryLabels == [],
               "empty categories should be []")
        assert(CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: [1, 2, 3])],
                                   xAxis: CartesianAxisModel(kind: .category(labels: ["x", "y", "z"])))
               .categoryLabels == ["x", "y", "z"],
               "explicit category labels should win")
        assert(CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: [1, 2])])
               .categoryLabels == ["1", "2"],
               "auto labels should be 1...n")

        // —— CartesianViewport ——
        let vp = CartesianViewport(xMin: -0.5, xMax: 3.5, yMin: 0, yMax: 100)
        assert(vp.xDomain == -0.5...3.5 && vp.yDomain == 0...100, "domains wrong")
        assert(abs(vp.xSpan - 4) < 0.001 && abs(vp.ySpan - 100) < 0.001, "spans wrong")
        assert(vp.clamp(x: 5) == 3.5 && vp.clamp(x: -9) == -0.5, "x clamp wrong")
        assert(vp.clamp(y: -3) == 0 && vp.clamp(y: 120) == 100, "y clamp wrong")
        // 退化域（span=0）不崩溃：clamp 直接返回界值
        let vp0 = CartesianViewport(xMin: 1, xMax: 1, yMin: 0, yMax: 0)
        assert(vp0.clamp(x: 99) == 1 && vp0.clamp(y: -5) == 0, "degenerate clamp wrong")
        // init 归一化：颠倒传入自动校正
        let vpNorm = CartesianViewport(xMin: 10, xMax: 0, yMin: 50, yMax: -10)
        assert(vpNorm.xMin == 0 && vpNorm.xMax == 10, "x init normalization failed")
        assert(vpNorm.yMin == -10 && vpNorm.yMax == 50, "y init normalization failed")

        // —— NiceScaleGenerator（Heckbert nice numbers，maxTickCount=6）——
        // A: 全正 (3,97) → 含 0 下界 → 0...100 步长 20
        let nsA = NiceScaleGenerator.generate(dataMin: 3, dataMax: 97)
        assert(abs(nsA.min) < 0.001 && abs(nsA.max - 100) < 0.001 && abs(nsA.step - 20) < 0.001,
               "case A should be 0...100 step 20, got \(nsA)")
        assert(nsA.ticks.first! == 0 && nsA.ticks.last! == 100, "case A ticks ends wrong")
        assert(nsA.ticks.count == 6, "case A should have 6 ticks, got \(nsA.ticks.count)")
        // B: 含负 (-37,25) → -40...30 步长 10
        let nsB = NiceScaleGenerator.generate(dataMin: -37, dataMax: 25)
        assert(abs(nsB.min - (-40)) < 0.001 && abs(nsB.max - 30) < 0.001 && abs(nsB.step - 10) < 0.001,
               "case B should be -40...30 step 10, got \(nsB)")
        // C: 平线 (50,50) → 全正 → 0...50 步长 10（顶格，Highcharts 同类行为）
        let nsC = NiceScaleGenerator.generate(dataMin: 50, dataMax: 50)
        assert(abs(nsC.min) < 0.001 && abs(nsC.max - 50) < 0.001 && abs(nsC.step - 10) < 0.001,
               "case C should be 0...50 step 10, got \(nsC)")
        // D: 全零 (0,0) → 0...1 步长 0.2
        let nsD = NiceScaleGenerator.generate(dataMin: 0, dataMax: 0)
        assert(abs(nsD.min) < 0.001 && abs(nsD.max - 1) < 0.001 && abs(nsD.step - 0.2) < 0.001,
               "case D should be 0...1 step 0.2, got \(nsD)")
        // E: NaN 防御 → 0...1
        let nsE = NiceScaleGenerator.generate(dataMin: .nan, dataMax: .nan)
        assert(abs(nsE.min) < 0.001 && abs(nsE.max - 1) < 0.001, "NaN should fall back 0...1")
        // F: 负平线 (-50,-50) → 上浮 10% 后 nice 化（-45 → ceil 至 -45，下界 floor 至 -50）
        let nsF = NiceScaleGenerator.generate(dataMin: -50, dataMax: -50)
        assert(abs(nsF.min - (-50)) < 0.001, "case F niceMin should be -50, got \(nsF.min)")
        assert(abs(nsF.max - (-45)) < 0.001, "case F niceMax should be -45, got \(nsF.max)")
        assert(abs(nsF.step - 1) < 0.001, "case F step should be 1, got \(nsF.step)")
        // G: Infinity 防御 → 0...1
        let nsG = NiceScaleGenerator.generate(dataMin: .infinity, dataMax: 100)
        assert(abs(nsG.min) < 0.001 && abs(nsG.max - 1) < 0.001, "Infinity should fall back 0...1")
        // E 补充：NaN 的 step/ticks
        assert(abs(nsE.step - 1) < 0.001 && nsE.ticks == [0, 1], "NaN fallback step/ticks wrong")

        // —— CartesianGeometry ——
        // 布局：inset(上16,左12,下24,右12) + y刻度宽34 + x刻度高14 + gap4 + 标题高20
        let plot = CartesianGeometry.layout(
            bounds: CGRect(x: 0, y: 0, width: 320, height: 200),
            contentInset: UIEdgeInsets(top: 16, left: 12, bottom: 24, right: 12),
            yAxisTickLabelWidth: 34, xAxisTickLabelHeight: 14,
            axisLabelGap: 4, titleHeight: 20)
        // plot = x: 12+34+4=50, y: 16+20+4=40, w: 320-50-12=258, h: 200-40-24-14-4=118
        assert(abs(plot.minX - 50) < 0.001 && abs(plot.minY - 40) < 0.001, "plot origin wrong: \(plot)")
        assert(abs(plot.width - 258) < 0.001 && abs(plot.height - 118) < 0.001, "plot size wrong: \(plot)")
        // 值→屏幕：类目域 -0.5...3.5、值域 0...100
        let vpG = CartesianViewport(xMin: -0.5, xMax: 3.5, yMin: 0, yMax: 100)
        let p0 = CartesianGeometry.point(x: 0, y: 50, viewport: vpG, plotFrame: plot)
        assert(abs(p0.x - 82.25) < 0.001, "point x should be 82.25, got \(p0.x)")
        assert(abs(p0.y - 99.0) < 0.001, "point y should be 99, got \(p0.y)")
        // 逆映射 roundtrip
        let back = CartesianGeometry.value(at: p0, viewport: vpG, plotFrame: plot)
        assert(abs(back.x - 0) < 0.001 && abs(back.y - 50) < 0.001, "roundtrip wrong: \(back)")
        // 类目 label 抽样
        assert(CartesianGeometry.categoryLabelStride(count: 8) == 1, "8 cats stride 1")
        assert(CartesianGeometry.categoryLabelStride(count: 30) == 3, "30 cats stride 3")
        // 边界：恰等于 maxLabels 不抽样；maxLabels 非法（≤0）回退 1
        assert(CartesianGeometry.categoryLabelStride(count: 10) == 1, "10 cats at boundary stride 1")
        assert(CartesianGeometry.categoryLabelStride(count: 11) == 2, "11 cats stride 2")
        assert(CartesianGeometry.categoryLabelStride(count: 5, maxLabels: 0) == 1, "invalid maxLabels fallback 1")

        // —— CartesianGeometry.zeroAxisPosition ——
        let zpVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
        let zpPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let zY = CartesianGeometry.zeroAxisPosition(viewport: zpVP, plotArea: zpPlot, isHorizontal: false)
        assert(abs(zY - zpPlot.maxY) < 0.001, "全正数据零轴应在底部")

        let znVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -100, yMax: 0)
        let znPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let znY = CartesianGeometry.zeroAxisPosition(viewport: znVP, plotArea: znPlot, isHorizontal: false)
        assert(abs(znY - znPlot.minY) < 0.001, "全负数据零轴应在顶部")

        let zmVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -50, yMax: 100)
        let zmPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let zmY = CartesianGeometry.zeroAxisPosition(viewport: zmVP, plotArea: zmPlot, isHorizontal: false)
        assert(zmY > zpPlot.minY && zmY < zpPlot.maxY, "混合数据零轴应在内部")

        // 水平版本测试
        let zhVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
        let zX = CartesianGeometry.zeroAxisPosition(viewport: zhVP, plotArea: zpPlot, isHorizontal: true)
        assert(abs(zX - zpPlot.minX) < 0.001, "水平图全正值域零轴应在左侧")

        // —— AxisRenderer.format 刻度文本 ——
        assert(AxisRenderer.format(80.0) == "80", "80.0 should format to '80'")
        assert(AxisRenderer.format(0.2) == "0.2", "0.2 should format to '0.2'")
        assert(AxisRenderer.format(-0.0) == "0", "-0.0 should format to '0'")
        assert(AxisRenderer.format(0.30000000000000004) == "0.3", "float noise should collapse to '0.3'")
        assert(AxisRenderer.format(123.456) == "123.5", ">=100 non-integer should avoid scientific notation, got '\(AxisRenderer.format(123.456))'")

        // —— LineChartRenderer ——
        let lineRenderer = LineChartRenderer()
        assert(lineRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil, "no render should miss")
        let lineModel = CartesianChartModel(
            title: "折线",
            series: [CartesianSeriesElement(name: "s", data: [10, 60, 30])])
        lineRenderer.render(model: lineModel, theme: CartesianChartTheme(),
                            context: HYMChartRenderContext(
                                bounds: CGRect(x: 0, y: 0, width: 320, height: 200),
                                center: .zero))
        // 用渲染器自身的屏幕映射反推数据点位置做命中（避免手算布局）
        let p1 = lineRenderer.testScreenPoint(series: 0, index: 1)
        if let hit = lineRenderer.hitTest(CGPoint(x: p1.x, y: p1.y)) as? LineHitTarget {
            assert(hit.seriesIndex == 0 && hit.index == 1, "should hit series0 index1, got \(hit)")
            assert(abs(hit.value - 60) < 0.001, "hit value should be 60")
            assert(hit.tooltipText != nil, "tooltipText should exist")
        } else {
            assertionFailure("should hit data point (0,1)")
        }
        // 点附近 ±8pt 命中；远处不命中
        assert(lineRenderer.hitTest(CGPoint(x: p1.x + 8, y: p1.y)) != nil, "±8pt should hit")
        assert(lineRenderer.hitTest(CGPoint(x: 5, y: 5)) == nil, "far corner should miss")

        print("✅ ChartSelfTest passed")
    }

    /// 比较 UIColor RGB 分量（UIColor == 受色彩空间/精度影响不可靠，一律比分量）。
    static func assertTintsEqual(_ color: UIColor, _ expected: (CGFloat, CGFloat, CGFloat),
                                 eps: CGFloat, msg: String,
                                 file: StaticString = #file, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        assert(abs(r - expected.0) < eps && abs(g - expected.1) < eps && abs(b - expected.2) < eps,
               "\(msg): got r=\(r) g=\(g) b=\(b)", file: file, line: line)
    }
}
#endif
