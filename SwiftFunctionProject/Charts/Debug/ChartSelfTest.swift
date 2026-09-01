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
        let db = cartModel.dataBounds()!
        assert(abs(db.min - (-5.0)) < 0.001 && abs(db.max - 97.0) < 0.001,
               "dataBounds should be (-5, 97), got \(String(describing: db))")
        // 空 series → nil
        assert(CartesianChartModel(series: []).dataBounds() == nil, "empty series should have nil bounds")
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
        // 类目 label 抽稀（宽度自适应）：短标签全显示；标签宽超过槽宽才隔 N 取 1
        assert(CartesianGeometry.categoryLabelStride(labelWidth: 10, slotWidth: 24) == 1,
               "narrow labels in wide slots → stride 1")
        assert(CartesianGeometry.categoryLabelStride(labelWidth: 10, slotWidth: 6) == 3,
               "wide labels → stride ceil((10+4)/6)=3")
        assert(CartesianGeometry.categoryLabelStride(labelWidth: 20, slotWidth: 24) == 1,
               "label+gap == slotWidth fits → stride 1")
        assert(CartesianGeometry.categoryLabelStride(labelWidth: 30, slotWidth: 24) == 2,
               "month-like labels → stride 2")
        assert(CartesianGeometry.categoryLabelStride(labelWidth: 10, slotWidth: 0) == 1,
               "invalid slotWidth fallback 1")

        // —— CartesianGeometry.steppedScreenPoints / appendSmoothCurve ——
        let sp = [CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 30), CGPoint(x: 20, y: 20)]
        // straight/smooth 原样返回
        assert(CartesianGeometry.steppedScreenPoints(sp, style: .straight) == sp, "straight should return as-is")
        assert(CartesianGeometry.steppedScreenPoints(sp, style: .smooth) == sp, "smooth returns raw points (curve at path level)")
        // stepAfter：保持前值水平前进到下一 x，再垂直跳变
        let after = CartesianGeometry.steppedScreenPoints(sp, style: .stepAfter)
        assert(after == [CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 30),
                         CGPoint(x: 20, y: 30), CGPoint(x: 20, y: 20)],
               "stepAfter wrong: \(after)")
        // stepBefore：先垂直跳到新值，再水平前进
        let before = CartesianGeometry.steppedScreenPoints(sp, style: .stepBefore)
        assert(before == [CGPoint(x: 0, y: 10), CGPoint(x: 0, y: 30), CGPoint(x: 10, y: 30),
                          CGPoint(x: 10, y: 20), CGPoint(x: 20, y: 20)],
               "stepBefore wrong: \(before)")
        // stepCenter：垂直段在中点
        let center = CartesianGeometry.steppedScreenPoints(sp, style: .stepCenter)
        assert(center == [CGPoint(x: 0, y: 10), CGPoint(x: 5, y: 10), CGPoint(x: 5, y: 30), CGPoint(x: 10, y: 30),
                          CGPoint(x: 15, y: 30), CGPoint(x: 15, y: 20), CGPoint(x: 20, y: 20)],
               "stepCenter wrong: \(center)")
        // 单点/空序列防御
        assert(CartesianGeometry.steppedScreenPoints([CGPoint(x: 1, y: 1)], style: .stepAfter).count == 1, "single point as-is")
        // 平滑曲线：两点退化直线；三点起有曲线段
        let twoPtPath = UIBezierPath()
        twoPtPath.move(to: CGPoint(x: 0, y: 0))
        CartesianGeometry.appendSmoothCurve(to: twoPtPath, points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        assert(!twoPtPath.isEmpty, "2-point smooth should degrade to a line")
        // 无过冲契约（Fritsch-Carlson 单调插值）：陡变数据下曲线不得冲出相邻点值域。
        // 依贝塞尔凸包性质，断言每段控制点 y 落在该段两端点 [min, max] 内即可。
        //   Catmull-Rom 在此数据下段 2 控制点会到 ~106.7（冲过 100 的假峰）。
        do {
            let spikes = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 90),
                          CGPoint(x: 20, y: 100), CGPoint(x: 30, y: 0)]
            let monotonePath = UIBezierPath()
            monotonePath.move(to: spikes[0])
            CartesianGeometry.appendSmoothCurve(to: monotonePath, points: spikes)
            var segIndex = 0
            monotonePath.cgPath.applyWithBlock { elem in
                let e = elem.pointee
                if e.type == .addCurveToPoint {
                    let c1 = e.points[0]
                    let c2 = e.points[1]
                    let lo = min(spikes[segIndex].y, spikes[segIndex + 1].y)
                    let hi = max(spikes[segIndex].y, spikes[segIndex + 1].y)
                    assert(c1.y >= lo - 0.001 && c1.y <= hi + 0.001,
                           "smooth cp1 overshoot at seg \(segIndex): \(c1.y) not in \(lo)...\(hi)")
                    assert(c2.y >= lo - 0.001 && c2.y <= hi + 0.001,
                           "smooth cp2 overshoot at seg \(segIndex): \(c2.y) not in \(lo)...\(hi)")
                    segIndex += 1
                }
            }
            assert(segIndex == spikes.count - 1,
                   "should have \(spikes.count - 1) curve segments, got \(segIndex)")
        }

        // —— X 轴标签与柱子组中心对齐契约 ——
        // 每个显示的标签必须正对所属类目中心（柱子组中心）：12 类目全量视口下
        // 全部 12 个短标签显示且 center.x == 类目中心映射（曾有双重偏移/抽稀错位回归）。
        do {
            let alignVP = CartesianViewport(xMin: -0.5, xMax: 11.5, yMin: 0, yMax: 100)
            let alignPlot = CGRect(x: 50, y: 40, width: 264, height: 160)
            let alignLabels = Array(1...12).map { String($0) }
            let made = AxisRenderer.makeCategoryLabels(labels: alignLabels,
                                                       viewport: alignVP,
                                                       plotFrame: alignPlot,
                                                       theme: CartesianChartTheme())
            assert(made.count == 12, "12 short labels should all show, got \(made.count)")
            for (idx, lbl) in made.enumerated() {
                let center = CartesianGeometry.point(x: Double(idx), y: 0,
                                                     viewport: alignVP, plotFrame: alignPlot).x
                assert(abs(lbl.center.x - center) < 0.001,
                       "label \(idx) center should align to category center \(center), got \(lbl.center.x)")
            }
            // 长标签（如月份）槽宽不足 → 抽稀，但显示的仍须对齐各自类目中心
            let monthLabels = (1...12).map { "\($0)月" }
            let monthMade = AxisRenderer.makeCategoryLabels(labels: monthLabels,
                                                            viewport: alignVP,
                                                            plotFrame: alignPlot,
                                                            theme: CartesianChartTheme())
            assert(monthMade.count < 12, "wide month labels should be thinned, got \(monthMade.count)")
            assert(monthMade.count >= 4, "thinned labels should keep reasonable density, got \(monthMade.count)")
        }

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

        // —— CartesianGeometry.stackedValues ——
        let s1 = CartesianSeriesElement(name: "a", data: [10, 20, 30])
        let s2 = CartesianSeriesElement(name: "b", data: [5, 15, 25])
        let stacked = CartesianGeometry.stackedValues(series: [s1, s2])
        assert(stacked.count == 2, "应返回 2 个系列")
        assert(stacked[0][2] == 30, "第一个系列应保持原值")
        assert(stacked[1][2] == 55, "第二个系列应累计: 30+25=55")

        // 锯齿 series 测试
        let s3 = CartesianSeriesElement(name: "c", data: [100])
        let s4 = CartesianSeriesElement(name: "d", data: [10, 20, 30, 40])
        let stacked2 = CartesianGeometry.stackedValues(series: [s3, s4])
        assert(stacked2[0].count == 4, "应归一化到最长长度 4")
        assert(stacked2[0][1] == 0, "短系列空位应补零")
        assert(stacked2[1][0] == 110, "第一个位置应累计: 100+10=110")
        assert(stacked2[1][1] == 20, "第二个位置应累计: 0+20=20")

        // 空 series 边界情况
        let emptyStacked = CartesianGeometry.stackedValues(series: [])
        assert(emptyStacked.isEmpty, "空 series 应返回空数组")

        // —— CartesianGeometry.zoomedXRange / pannedXRange / visibleCategoryRange ——
        let fullX = -0.5...3.5   // 4 类目全量域
        // 中心锚点放大 2 倍：span 4→2，窗口围绕锚点 1.5
        let zr = CartesianGeometry.zoomedXRange(from: fullX, factor: 2, anchorValue: 1.5,
                                                fullDomain: fullX, minSpan: 2, maxSpan: 4)
        assert(abs(zr.lowerBound - 0.5) < 1e-9 && abs(zr.upperBound - 2.5) < 1e-9,
               "center zoom 2x should be 0.5...2.5, got \(zr)")
        // 放大到 minSpan（倍数无限制时按最小跨度收敛）
        let zrMin = CartesianGeometry.zoomedXRange(from: fullX, factor: 4, anchorValue: 1.5,
                                                   fullDomain: fullX, minSpan: 1, maxSpan: 4)
        assert(abs(zrMin.upperBound - zrMin.lowerBound - 1) < 1e-9, "factor beyond minSpan should clamp span")
        // 超量继续放大：span 不再小于 minSpan
        let zrOver = CartesianGeometry.zoomedXRange(from: zrMin, factor: 10, anchorValue: 1.5,
                                                    fullDomain: fullX, minSpan: 1, maxSpan: 4)
        assert(abs(zrOver.upperBound - zrOver.lowerBound - 1) < 1e-9, "over-zoom should clamp to minSpan")
        // 缩小 factor<1 但不允许超过全量：回全量
        let zrOut = CartesianGeometry.zoomedXRange(from: zr, factor: 0.1, anchorValue: 1.5,
                                                   fullDomain: fullX, minSpan: 2, maxSpan: 4)
        assert(zrOut == fullX, "zoom-out should clamp back to full domain, got \(zrOut)")
        // 边界锚点：窗口不越出全量域
        let zrEdge = CartesianGeometry.zoomedXRange(from: fullX, factor: 2, anchorValue: -0.5,
                                                    fullDomain: fullX, minSpan: 2, maxSpan: 4)
        assert(zrEdge.lowerBound == fullX.lowerBound && abs(zrEdge.upperBound - 1.5) < 1e-9,
               "edge anchor should clamp to lower bound, got \(zrEdge)")
        // 大数据量场景：minSpan 按类目数约束（1440 点放大到底可见 2 类目）
        let bigX = -0.5...1439.5
        let bigZoomed = CartesianGeometry.zoomedXRange(from: bigX, factor: 1000, anchorValue: 700,
                                                       fullDomain: bigX, minSpan: 2, maxSpan: 1440)
        assert(abs(bigZoomed.upperBound - bigZoomed.lowerBound - 2) < 1e-9,
               "1440 cats should bottom out at 2-category span, got \(bigZoomed)")
        // 平移：半幅右滑 → 窗口左移一半 span，clamp 到下界
        let pr = CartesianGeometry.pannedXRange(from: zr, screenDeltaX: 100, plotWidth: 200,
                                                fullDomain: fullX)
        assert(abs(pr.lowerBound - (-0.5)) < 1e-9 && abs(pr.upperBound - 1.5) < 1e-9,
               "pan right by half width should clamp to domain start, got \(pr)")
        // 平移中段不触边界：窗口整体平移 span/2
        let prMid = CartesianGeometry.pannedXRange(from: 1.0...3.0, screenDeltaX: -50, plotWidth: 200,
                                                   fullDomain: fullX)
        assert(abs(prMid.lowerBound - 1.5) < 1e-9 && abs(prMid.upperBound - 3.5) < 1e-9,
               "mid pan should shift range by span/2, got \(prMid)")
        // 可见类目：全量视口 = 0..<count
        let vrFull = CartesianGeometry.visibleCategoryRange(
            viewport: CartesianViewport(xMin: -0.5, xMax: 3.5, yMin: 0, yMax: 1), count: 4)
        assert(vrFull == 0..<4, "full viewport should show all, got \(vrFull)")
        // 放大视口 0.3...2.3：类目 0/1/2 可见（band 与视口相交即计入），类目 3 不相交
        let vrZoom = CartesianGeometry.visibleCategoryRange(
            viewport: CartesianViewport(xMin: 0.3, xMax: 2.3, yMin: 0, yMax: 1), count: 4)
        assert(vrZoom == 0..<3, "zoomed viewport should show 0..<3, got \(vrZoom)")
        // 窄视口 1.2...1.8：类目 1、2 的 band 都与视口相交（2 的 band [1.5,2.5) 左缘入视口）
        let vrNarrow = CartesianGeometry.visibleCategoryRange(
            viewport: CartesianViewport(xMin: 1.2, xMax: 1.8, yMin: 0, yMax: 1), count: 4)
        assert(vrNarrow == 1..<3, "narrow viewport should show 1..<3, got \(vrNarrow)")

        // —— pannedXRange 橡皮筋（越界阻尼 + 余量上限；硬模式行为不变）——
        let rbFull = 0.0...100.0
        // 硬模式回归：窗口=全量域、再往左推 → 原地不动
        assert(CartesianGeometry.pannedXRange(from: rbFull, screenDeltaX: 100, plotWidth: 200,
                                              fullDomain: rbFull) == rbFull,
               "硬 clamp 模式贴边推动应原地不动")
        // 橡皮筋：同上推动 100px（值 50）→ 贴边阻尼 0.4 → 越界 20，余量上限 25
        let rb = CartesianGeometry.pannedXRange(from: rbFull, screenDeltaX: 100, plotWidth: 200,
                                                fullDomain: rbFull, overshootMargin: 25)
        assert(abs(rb.lowerBound - (-20)) < 1e-9 && abs(rb.upperBound - 80) < 1e-9,
               "橡皮筋越界应为 -20...80（阻尼 0.4），got \(rb)")
        // 余量上限：巨大位移也越不过 25
        let rbMax = CartesianGeometry.pannedXRange(from: rbFull, screenDeltaX: 10000, plotWidth: 200,
                                                   fullDomain: rbFull, overshootMargin: 25)
        assert(abs(rbMax.lowerBound - (-25)) < 1e-9, "越界不得超出余量 25，got \(rbMax)")
        // 域内正常平移不受阻尼影响
        let rbMid = CartesianGeometry.pannedXRange(from: 25.0...75.0, screenDeltaX: 100, plotWidth: 200,
                                                   fullDomain: rbFull, overshootMargin: 25)
        assert(abs(rbMid.lowerBound) < 1e-9 && abs(rbMid.upperBound - 50) < 1e-9,
               "域内平移不受橡皮筋影响，got \(rbMid)")

        // —— CartesianGeometry.columnRect ——
        let colVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
        let colPlot = CGRect(x: 50, y: 40, width: 200, height: 160)
        let colTheme = CartesianChartTheme()

        // 正值柱测试
        let posRect = CartesianGeometry.columnRect(
            dataPoint: 80,
            categoryIndex: 1,
            viewport: colVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroY: colPlot.maxY
        )
        assert(posRect.minY < colPlot.maxY && posRect.maxY <= colPlot.maxY, "正值柱应在零轴上方")
        assert(abs(posRect.maxY - colPlot.maxY) < 0.001, "正值柱底部应接触零轴")

        // 负值柱测试
        let negVP = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: -100, yMax: 0)
        let negZeroY = CartesianGeometry.zeroAxisPosition(viewport: negVP, plotArea: colPlot, isHorizontal: false)
        let negRect = CartesianGeometry.columnRect(
            dataPoint: -60,
            categoryIndex: 1,
            viewport: negVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroY: negZeroY
        )
        assert(negRect.minY >= negZeroY && negRect.maxY > negZeroY, "负值柱应在零轴下方")
        assert(abs(negRect.minY - negZeroY) < 0.001, "负值柱顶部应接触零轴")

        // 柱体宽度测试
        let expectedWidth = colPlot.width / 3 * 0.8
        assert(abs(posRect.width - expectedWidth) < 0.001, "柱宽应按比例计算")

        // 柱体 X 位置测试（第二个柱应在中间偏右）
        let secondColumnX = colPlot.minX + colPlot.width / 3 * 1 + (colPlot.width / 3 * 0.2) / 2
        assert(abs(posRect.minX - secondColumnX) < 0.001, "柱体 X 位置应正确")

        // —— 柱间距自定义（组内间距 / 组间距；默认值必须与旧行为逐点一致）——
        // 双系列默认布局（老行为）：每柱居子槽中心，组内间隙 = 子槽 × (1-ratio)
        let twoVP = CartesianViewport(xMin: -0.5, xMax: 1.5, yMin: 0, yMax: 100)
        let twoSlot = colPlot.width / 2
        let twoSub = twoSlot / 2
        let r0 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                               plotArea: colPlot, theme: colTheme,
                                               zeroY: colPlot.maxY, seriesIndex: 0, seriesCount: 2)
        let r1 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                               plotArea: colPlot, theme: colTheme,
                                               zeroY: colPlot.maxY, seriesIndex: 1, seriesCount: 2)
        let oldX0 = colPlot.minX + (twoSub - twoSub * 0.8) / 2
        let oldX1 = colPlot.minX + twoSub + (twoSub - twoSub * 0.8) / 2
        assert(abs(r0.minX - oldX0) < 0.001 && abs(r1.minX - oldX1) < 0.001,
               "默认（nil 内距）双系列布局应与旧行为一致，got \(r0.minX) vs \(oldX0)")

        // 组内间距显式 0：两柱紧贴（组整体居中）
        var tGap0 = colTheme
        tGap0.columnInnerSpacingRatio = 0
        let g0 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                              plotArea: colPlot, theme: tGap0,
                                              zeroY: colPlot.maxY, seriesIndex: 0, seriesCount: 2)
        let g1 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                              plotArea: colPlot, theme: tGap0,
                                              zeroY: colPlot.maxY, seriesIndex: 1, seriesCount: 2)
        assert(abs(g1.minX - g0.maxX) < 0.001, "组内间距 0 时相邻柱应紧贴，got \(g0) \(g1)")

        // 组内间距显式 0.5：间隙 = 0.5 × 子槽，但柱宽优先（clamp 到组恰好放满：80+20=100）
        var tGapH = colTheme
        tGapH.columnInnerSpacingRatio = 0.5
        let h0 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                              plotArea: colPlot, theme: tGapH,
                                              zeroY: colPlot.maxY, seriesIndex: 0, seriesCount: 2)
        let h1 = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                              plotArea: colPlot, theme: tGapH,
                                              zeroY: colPlot.maxY, seriesIndex: 1, seriesCount: 2)
        let fitGap = (twoSlot - twoSub * 0.8 * 2) / 1   // 柱宽不变前提下的最大间隙
        assert(abs((h1.minX - h0.maxX) - fitGap) < 0.001,
               "组内间距 0.5 应为柱宽优先的 clamp 值，got \(h1.minX - h0.maxX) vs \(fitGap)")
        assert(abs(h0.width - twoSub * 0.8) < 0.001, "柱宽不应受组内间距影响")

        // 组间距 0.5：组区域收窄一半并居中（单系列下柱中心不变）
        var tGroup = colTheme
        tGroup.columnGroupSpacingRatio = 0.5
        let grp = CartesianGeometry.columnRect(dataPoint: 50, categoryIndex: 0, viewport: twoVP,
                                               plotArea: colPlot, theme: tGroup,
                                               zeroY: colPlot.maxY, seriesIndex: 0, seriesCount: 1)
        let catCenter = CartesianGeometry.point(x: 0, y: 0, viewport: twoVP, plotFrame: colPlot).x
        assert(abs(grp.midX - catCenter) < 0.001, "组间距下柱仍应居类目中心，got \(grp.midX) vs \(catCenter)")
        assert(grp.width < twoSlot, "组间距应使柱变窄（组区域收窄），got \(grp.width)")

        // —— CartesianGeometry.barRect ——
        let barVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
        let barZeroX = CartesianGeometry.zeroAxisPosition(viewport: barVP, plotArea: colPlot, isHorizontal: true)

        // 正值条测试
        let posBar = CartesianGeometry.barRect(
            dataPoint: 70,
            categoryIndex: 1,
            viewport: barVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroX: barZeroX
        )
        assert(posBar.minX >= barZeroX, "正值条应在零轴右侧")
        assert(abs(posBar.minX - barZeroX) < 0.001, "正值条左侧应接触零轴")

        // 负值条测试
        let negBarVP = CartesianViewport(xMin: -100, xMax: 0, yMin: -0.5, yMax: 2.5)
        let negBarZeroX = CartesianGeometry.zeroAxisPosition(viewport: negBarVP, plotArea: colPlot, isHorizontal: true)
        let negBar = CartesianGeometry.barRect(
            dataPoint: -50,
            categoryIndex: 1,
            viewport: negBarVP,
            plotArea: colPlot,
            theme: colTheme,
            zeroX: negBarZeroX
        )
        assert(negBar.maxX <= negBarZeroX, "负值条应在零轴左侧")
        assert(abs(negBar.maxX - negBarZeroX) < 0.001, "负值条右侧应接触零轴")

        // 条形高度测试
        let expectedHeight = colPlot.height / 3 * 0.8
        assert(abs(posBar.height - expectedHeight) < 0.001, "条高应按比例计算")

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

        // —— HYMChartXAxisZoomable conformance 契约 ——
        // 手势链路依赖 `renderer as? HYMChartXAxisZoomable` 能力检查：
        // 方法都实现了但类声明漏写 conformance 时 `as?` 静默失败（编译不报错），手势全部无效。
        // 此处断言所有轴系子类确实遵循协议。
        assert((lineRenderer as HYMChartRenderer) is HYMChartXAxisZoomable,
               "LineChartRenderer should conform to HYMChartXAxisZoomable")
        assert((ColumnChartRenderer() as HYMChartRenderer) is HYMChartXAxisZoomable,
               "ColumnChartRenderer should conform to HYMChartXAxisZoomable")
        assert((BarChartRenderer() as HYMChartRenderer) is HYMChartXAxisZoomable,
               "BarChartRenderer should conform to HYMChartXAxisZoomable")
        // 雷达图不遵循（能力协议按需实现）
        assert(!((RadarChartRenderer() as HYMChartRenderer) is HYMChartXAxisZoomable),
               "RadarChartRenderer should NOT conform to HYMChartXAxisZoomable")

        // —— 条形图水平轴系（值轴在 X、类目轴在 Y；渲染级契约，todo-bar-axis-fix）——
        runHorizontalAxisSelfTest()

        // —— 值轴刻度自定义（tickCount / tickPositions / labelFormatter）——
        runTickCustomizationSelfTest()

        // —— 双轴/堆叠模型与几何纯函数 ——
        runDualAxisGeometrySelfTest()

        // —— 双值轴渲染（右侧刻度、独立值域、次轴网格）——
        runDualAxisRenderSelfTest()

        // —— 双轴系列映射与命中 ——
        runDualAxisSeriesSelfTest()

        // —— 折线/面积堆叠 ——
        runLineStackingSelfTest()

        // —— 正负分开堆叠（上下镜像）——
        runSignSeparatedStackingSelfTest()

        // —— 线条虚线样式 ——
        runDashStyleSelfTest()

        // —— 空值处理（NaN 断线 / connectNulls 连线）——
        runNullValueSelfTest()

        // —— 数据点标记符号 + 十字准线 ——
        runMarkerSymbolSelfTest()

        // —— 百分比堆叠 ——
        runPercentStackingSelfTest()

        // —— 整列命中（shared tooltip）——
        runSharedHitSelfTest()

        // —— 数据标签（数值标注）——
        runDataLabelSelfTest()

        // —— 标线 / 折线负值换色 / 空心圆点 ——
        runPlotLineSelfTest()

        // —— Y 轴缩放（zoomAxisMode .y/.xy）——
        runYAxisZoomSelfTest()

        // —— 准线双向 + 弹窗文本模板 ——
        runCrosshairAndTooltipSelfTest()

        // —— 橡皮筋越界余量（窗口相对口径）——
        runRubberBandMarginSelfTest()

        // —— 堆叠 + 平滑 + 面积（下边界倒序曲线，层间无露白/叠色）——
        runSmoothStackedAreaSelfTest()

        // —— 最小柱高/条长 + 逐柱颜色 ——
        runColumnParitySelfTest()

        // —— 色带（plotBands）+ 系列阴影 ——
        runPlotBandShadowSelfTest()

        print("✅ ChartSelfTest passed")
    }


    static func runColumnParitySelfTest() {
        // 纯几何：viewport y 0...100 → plot 高 160（值→像素 1.6x）
        var theme = CartesianChartTheme()
        theme.columnMinPointLength = 8
        let vp = CartesianViewport(xMin: -0.5, xMax: 2.5, yMin: 0, yMax: 100)
        let plot = CGRect(x: 50, y: 40, width: 200, height: 160)

        // 1) 小正值（0.5 → 0.8px < 8）→ 柱高 = 8；方向从零轴向上
        let tiny = CartesianGeometry.columnRect(
            dataPoint: 0.5, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: theme, zeroY: 200)
        assert(abs(tiny.height - 8) < 1e-6 && abs(tiny.maxY - 200) < 1e-6,
               "小正值 clamp 到最小柱高且贴零轴，got \(tiny)")
        // 2) 0 值不画（不给最小高）
        let zeroRect = CartesianGeometry.columnRect(
            dataPoint: 0, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: theme, zeroY: 200)
        assert(zeroRect.height < 0.5, "0 值不画，got \(zeroRect)")
        // 3) 正常值不受影响（50 → 80px > 8）
        let normal = CartesianGeometry.columnRect(
            dataPoint: 50, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: theme, zeroY: 200)
        assert(abs(normal.height - 80) < 1e-6, "正常柱高不受 min 影响，got \(normal)")
        // 4) 负值向下 clamp
        let tinyNeg = CartesianGeometry.columnRect(
            dataPoint: -0.5, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: theme, zeroY: 200)
        assert(abs(tinyNeg.height - 8) < 1e-6 && abs(tinyNeg.minY - 200) < 1e-6,
               "小负值向下 clamp，got \(tinyNeg)")
        // 5) 堆叠（baselineValue 非 nil）不 clamp
        let stacked = CartesianGeometry.columnRect(
            dataPoint: 10.5, categoryIndex: 0, viewport: vp, plotArea: plot,
            theme: theme, zeroY: 200, baselineValue: 10)
        assert(stacked.height < 8 + 1e-6, "堆叠段不受 min 影响，got \(stacked)")

        // 6) Bar 最小条长（值轴在 X：视口 x 域传值域 0...100，y 域为类目）
        let barVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 2.5)
        let barTiny = CartesianGeometry.barRect(
            dataPoint: 0.5, categoryIndex: 0, viewport: barVP, plotArea: plot,
            theme: theme, zeroX: 50)
        assert(abs(barTiny.width - 8) < 1e-6 && abs(barTiny.minX - 50) < 1e-6,
               "Bar 小正值 clamp 最小条长且贴零轴，got \(barTiny)")

        // 7) 堆叠圆角回归 + 层详情（此前色组重构曾致圆角层消失——若挂看 report）
        let rc = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rc.mount(into: hostC)
        rc.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])],
            stacking: .normal),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        var layerReport = ""
        var rounded = 0
        for l in rc.seriesLayerSublayersForTesting() {
            var c = 0, ln = 0
            (l as? CAShapeLayer)?.path?.applyWithBlock { e in
                if e.pointee.type == .addCurveToPoint { c += 1 }
                if e.pointee.type == .addLineToPoint { ln += 1 }
            }
            if c > 0 { rounded += 1 }
            layerReport += "[\(type(of: l)) c=\(c) l=\(ln) fill=\((l as? CAShapeLayer).map { String(describing: $0.fillColor) } ?? "-")] "
        }
        assert(rounded == 1, "堆叠圆角回归：应 1 层带圆角，got \(rounded) \(layerReport)")

        // 8) 逐柱颜色 → 按色分组层；nil → 单层
        let r = ColumnChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30, 40],
                                            barColors: [.systemRed, .systemGreen])]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let fillLayers = r.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor != nil }
        assert(fillLayers.count == 2, "两色循环 → 两层，got \(fillLayers.count) \(layerReport)")
        let fills = Set(fillLayers.map { String(describing: $0.fillColor) })
        assert(fills.count == 2, "层色互不相同，got \(fills)")

        let r2 = ColumnChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r2.mount(into: host2)
        r2.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30, 40])]),
                   theme: CartesianChartTheme(),
                   context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        let fillLayers2 = r2.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor != nil }
        assert(fillLayers2.count == 1, "无逐柱色 → 单层（回归），got \(fillLayers2.count)")
    }

    /// 色带（plotBands）：方向/越界/裁剪/z 序（网格上、系列下）+ 系列阴影（柱/线层 shadowPath）。
    static func runPlotBandShadowSelfTest() {
        func walkLayers(_ l: CALayer, _ visit: (CALayer) -> Void) {
            visit(l)
            l.sublayers?.forEach { walkLayers($0, visit) }
        }
        func allLayers(of host: UIView) -> [CALayer] {
            var out: [CALayer] = []
            walkLayers(host.layer) { out.append($0) }
            return out
        }

        // 1) Column：水平横带（宽 = plot 宽）+ 越界不画 + 反序 from/to 归一 + 标签存在
        let rc = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rc.mount(into: hostC)
        let bandGreen = UIColor.systemGreen.withAlphaComponent(0.12)
        rc.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 55, 45, 30])],
            plotBands: [CartesianPlotBand(from: 40, to: 70, color: bandGreen, label: "达标区"),
                        CartesianPlotBand(from: 500, to: 600, color: .systemOrange),  // 域外（不画）
                        CartesianPlotBand(from: 35, to: 15, color: .systemBlue)]),    // 反序 → 15...35
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        let layersC = allLayers(of: hostC)
        let bandLayers = layersC.filter {
            $0 is CALayer && !($0 is CAShapeLayer) && !($0 is CATextLayer) && !($0 is CAGradientLayer)
                && $0.backgroundColor != nil
        }
        assert(bandLayers.count == 2, "域内两条带（90-95 越界不画；反序算一条），got \(bandLayers.count)\n"
               + bandLayers.map { String(describing: $0.backgroundColor) }.joined(separator: ","))
        let wideBands = bandLayers.filter { $0.frame.width > 200 && $0.frame.height > 10 && $0.frame.height < 100 }
        assert(wideBands.count == 2, "两条都应为贯穿 plot 的水平横带，got \(wideBands.count)")
        let labelTexts = layersC.compactMap { ($0 as? CATextLayer)?.string as? String }
        assert(labelTexts.contains("达标区"), "色带标签文本存在")
        // z 序：带层在 rootLayer 中的索引 < seriesLayer（画在系列之下）
        let seriesBody = rc.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .first { $0.fillColor != nil }
        let rootChildren = (seriesBody?.superlayer?.superlayer?.sublayers ?? [])
        if let seriesIdx = rootChildren.firstIndex(where: { $0 === seriesBody?.superlayer }),
           let bandIdx = rootChildren.firstIndex(where: { $0 === bandLayers[0] }) {
            assert(bandIdx < seriesIdx, "色带应在系列层之下：band=\(bandIdx) series=\(seriesIdx)")
        } else {
            assertionFailure("rootLayer 里应能找到带层与系列层")
        }

        // 2) Bar：竖带（值轴在 X → 高 = plot 高、宽随值区间）
        let rb = BarChartRenderer()
        let hostB = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rb.mount(into: hostB)
        rb.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 55, 45])],
            plotBands: [CartesianPlotBand(from: 40, to: 70, color: bandGreen)]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostB.bounds, center: hostB.center))
        let bandB = allLayers(of: hostB).filter {
            !($0 is CAShapeLayer) && !($0 is CATextLayer) && $0.backgroundColor == bandGreen.cgColor
        }
        assert(bandB.count == 1 && bandB[0].frame.height > 100 && bandB[0].frame.width > 10,
               "Bar 色带应为竖带（高 ≈ plot 高），got \(bandB.count) \(bandB.map { $0.frame })")

        // 3) 部分越界裁剪：band 90...150 只留域内部分，frame 不超出宿主 bounds
        let rc2 = ColumnChartRenderer()
        let hostC2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rc2.mount(into: hostC2)
        rc2.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 55, 45, 30])],
            yAxis: CartesianAxisModel(kind: .value, min: 0, max: 100),
            plotBands: [CartesianPlotBand(from: 90, to: 150, color: .systemOrange)]),
                   theme: CartesianChartTheme(),
                   context: HYMChartRenderContext(bounds: hostC2.bounds, center: hostC2.center))
        let clipped = allLayers(of: hostC2).filter {
            !($0 is CAShapeLayer) && !($0 is CATextLayer) && $0.backgroundColor == UIColor.systemOrange.cgColor
        }
        assert(clipped.count == 1 && hostC2.bounds.contains(clipped[0].frame),
               "部分越界带应裁剪回 plot 区，got \(clipped.map { $0.frame })")

        // 4) 次轴色带（yAxisIndex=1）：按次值域换算并绘制
        let rc3 = ColumnChartRenderer()
        let hostC3 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rc3.mount(into: hostC3)
        var themeD = CartesianChartTheme()
        themeD.seriesShadow = CartesianShadowStyle()
        rc3.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 40, 30]),
                     CartesianSeriesElement(name: "b", data: [10, 20, 12], yAxisIndex: 1)],
            secondaryYAxis: CartesianAxisModel(kind: .value),
            plotBands: [CartesianPlotBand(from: 5, to: 15, yAxisIndex: 1, color: .systemPurple)]),
                   theme: themeD,
                   context: HYMChartRenderContext(bounds: hostC3.bounds, center: hostC3.center))
        let secBand = allLayers(of: hostC3).filter {
            !($0 is CAShapeLayer) && !($0 is CATextLayer) && $0.backgroundColor == UIColor.systemPurple.cgColor
        }
        assert(secBand.count == 1, "次轴色带按次值域绘制，got \(secBand.count)")

        // 5) 阴影：theme.seriesShadow → 每系列一根隐形 caster（挂 rootLayer、
        //    seriesLayer 之下——贴轴柱底的投影不能被 masksToBounds 裁掉）
        let casters3 = allLayers(of: hostC3).compactMap { $0 as? CAShapeLayer }
            .filter { $0.shadowPath != nil && $0.shadowOpacity > 0 }
        assert(casters3.count == 2, "两个系列各一根 caster，got \(casters3.count)")
        let bodies3 = rc3.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor != nil }
        assert(bodies3.allSatisfy { $0.shadowOpacity == 0 },
               "柱体本体层不带阴影（投影全由 caster 出）")
        let seriesBody3 = rc3.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .first { $0.fillColor != nil }
        let rootChildren3 = seriesBody3?.superlayer?.superlayer?.sublayers ?? []
        if let sIdx = rootChildren3.firstIndex(where: { $0 === seriesBody3?.superlayer }),
           let cIdx = rootChildren3.firstIndex(where: { $0 === casters3.first }) {
            assert(cIdx < sIdx, "caster 应在系列层之下：caster=\(cIdx) series=\(sIdx)")
        }
        let rc4 = ColumnChartRenderer()
        let hostC4 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rc4.mount(into: hostC4)
        rc4.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30])]),
                   theme: CartesianChartTheme(),
                   context: HYMChartRenderContext(bounds: hostC4.bounds, center: hostC4.center))
        let casters4 = allLayers(of: hostC4).compactMap { $0 as? CAShapeLayer }
            .filter { $0.shadowPath != nil && $0.shadowOpacity > 0 }
        assert(casters4.isEmpty, "默认无阴影 → 无 caster，got \(casters4.count)")

        // 6) 折线阴影：系列级 shadow 覆盖主题 nil → 一根 caster（半径取系列级样式）
        let rl = LineChartRenderer()
        let hostL = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rl.mount(into: hostL)
        rl.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 30, 20, 40],
                                            shadow: CartesianShadowStyle(offsetY: 2.5, blurRadius: 3, opacity: 0.35))]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostL.bounds, center: hostL.center))
        let castersL = allLayers(of: hostL).compactMap { $0 as? CAShapeLayer }
            .filter { $0.shadowPath != nil && $0.shadowOpacity > 0 }
        assert(castersL.count == 1 && abs(castersL[0].shadowRadius - 3) < 1e-6,
               "折线一根 caster 且半径取系列级样式，got \(castersL.count)")
    }

    /// 堆叠平滑面积：下边界 = 前一层平滑曲线的倒序回走（旧实现为直连线，
    /// 层间曲线拱起处露白、下凹处叠色）。
    static func runSmoothStackedAreaSelfTest() {
        // 1) 纯几何：倒序曲线与正向曲线元素数相同、终点回到首点、包围盒一致
        let pts = [CGPoint(x: 0, y: 100), CGPoint(x: 50, y: 40),
                   CGPoint(x: 100, y: 60), CGPoint(x: 150, y: 10)]
        func counts(_ path: UIBezierPath) -> (curves: Int, end: CGPoint, bbox: CGRect) {
            var c = 0
            var end = CGPoint.zero
            var bbox = CGRect.null
            path.cgPath.applyWithBlock { e in
                let el = e.pointee
                if el.type == .addCurveToPoint { c += 1 }
                // 曲线元素 points = [控制点1, 控制点2, 终点]；线/移动 = [终点]
                let idx = el.type == .addCurveToPoint ? 2 : 0
                end = CGPoint(x: el.points[idx].x, y: el.points[idx].y)
                bbox = bbox.union(CGRect(origin: end, size: .zero))
            }
            return (c, end, bbox)
        }
        let fwd = UIBezierPath()
        fwd.move(to: pts[0])
        CartesianGeometry.appendSmoothCurve(to: fwd, points: pts)
        let rev = UIBezierPath()
        rev.move(to: pts[pts.count - 1])
        CartesianGeometry.appendSmoothCurveReversed(to: rev, points: pts)
        let f = counts(fwd), r = counts(rev)
        assert(f.curves == 3 && r.curves == 3, "正/反向各 3 段三次曲线，got \(f.curves)/\(r.curves)")
        assert(abs(r.end.x - pts[0].x) < 1e-6 && abs(r.end.y - pts[0].y) < 1e-6,
               "倒序回走终点 = 首点，got \(r.end)")
        assert(abs(r.bbox.minX - f.bbox.minX) < 1e-6 && abs(r.bbox.maxX - f.bbox.maxX) < 1e-6,
               "倒序曲线 x 范围与正向一致")

        // 2) 渲染级：两系列堆叠 + 平滑 + 面积 → 第 2 系列的 mask 曲线数 = 2×(n-1)
        //    （正向 n-1 + 倒序下边界 n-1；旧实现的下边界是直线 → 只有 n-1）
        var theme = CartesianChartTheme()
        theme.lineConnectionStyle = .smooth
        theme.showsArea = true
        let r2 = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r2.mount(into: host)
        r2.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 30, 20, 40]),
                     CartesianSeriesElement(name: "b", data: [15, 10, 25, 5])],
            stacking: .normal),
                  theme: theme,
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let masks = r2.seriesLayerSublayersForTesting()
            .compactMap { $0 as? CAGradientLayer }
            .compactMap { $0.mask as? CAShapeLayer }
        assert(masks.count == 2, "两系列各一个渐变面积，got \(masks.count)")
        var curves = 0
        masks[1].path?.applyWithBlock { e in
            if e.pointee.type == .addCurveToPoint { curves += 1 }
        }
        assert(curves == 6, "第 2 系列 mask = 正向 3 + 倒序 3 = 6 段曲线（下边界非直线），got \(curves)")
    }

    /// 橡皮筋余量按**当前窗口跨度** 25% 计算（曾按全量域算：放大后 00:00 可一路拖到最右侧）。
    /// 未缩放（窗口=全量）时与旧行为一致（全量跨度 25%）。
    static func runRubberBandMarginSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: (0..<100).map { Double($0) })]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let full = r.fullXAxisDomain
        let fullSpan = full.upperBound - full.lowerBound

        // 1) 未缩放：巨大拖拽 → 越界 = 全量跨度 25%（旧口径，回归保护）。
        //    正位移 = 手指右滑 = 内容右移 = 窗口推向数值小端（拖出下界，即用户"把 00:00 往右拖"）
        r.panXAxis(screenDeltaX: 100000, allowsRubberBand: true)
        let loUnzoomed = r.xAxisViewport.lowerBound
        assert(abs((full.lowerBound - loUnzoomed) - fullSpan * 0.25) < 1e-6,
               "未缩放越界 = 全量 25%，got \(full.lowerBound - loUnzoomed) vs \(fullSpan * 0.25)")
        r.resetXAxisViewport()

        // 2) 放大 10 倍：越界 ≤ 窗口跨度 25%（远小于全量 25%）
        r.zoomXAxis(factor: 10, anchorScreenX: r.currentPlotFrame.midX)
        let windowSpan = r.xAxisViewport.upperBound - r.xAxisViewport.lowerBound
        assert(windowSpan < fullSpan / 9, "前置：已放大")
        r.panXAxis(screenDeltaX: 100000, allowsRubberBand: true)
        let overshoot = full.lowerBound - r.xAxisViewport.lowerBound
        assert(overshoot <= windowSpan * 0.25 + 1e-6,
               "放大后越界 ≤ 窗口 25%（\(windowSpan * 0.25)），got \(overshoot)")
        assert(r.isXAxisOvershooting, "越界态松手须回弹")

        // 3) Y 轴同口径
        r.resetXAxisViewport()
        r.zoomYAxis(factor: 10, anchorScreenY: r.currentPlotFrame.midY)
        let ySpan = r.yAxisViewport.upperBound - r.yAxisViewport.lowerBound
        r.panYAxis(screenDeltaY: 100000, allowsRubberBand: true)    // 下滑 → 拖出值域下界
        let yOver = r.fullYAxisDomain.lowerBound - r.yAxisViewport.lowerBound
        assert(yOver <= ySpan * 0.25 + 1e-6, "Y 越界 ≤ 窗口 25%，got \(yOver) vs \(ySpan * 0.25)")
    }

    /// 准线双向（值向分量几何）+ 弹窗文本模板（数据源/格式化/表头）。
    static func runCrosshairAndTooltipSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 30, 20])]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))

        // 1) 值向准线：LineHitTarget → 过命中值的横线（高 1、宽 = plot 宽）
        let target = r.hitTest(CGPoint(x: 200, y: 80)) ?? r.snapHit(at: CGPoint(x: 200, y: 80))!
        let vRect = r.valueCrosshairRect(for: target)
        assert(vRect != nil, "Line target 应支持值向准线")
        assert(vRect!.height == 1 && vRect!.width > 200, "垂直图值向准线 = 全宽横线")
        let hitY = r.screenPoint(x: 0, y: (target as! LineHitTarget).value,
                                 yAxisIndex: (target as! LineHitTarget).yAxisIndex).y
        assert(abs(vRect!.minY + 0.5 - hitY) < 0.5, "值向准线过命中值")

        // 2) sharedHit 四元组：值向分量跟触点走（钳制 plot 内）
        let shared = r.sharedHit(at: CGPoint(x: 200, y: 90))!
        assert(abs(shared.valueCrosshair.minY + 0.5 - 90) < 0.5,
               "整列命中值向准线过触点 y")
        assert(shared.valueCrosshair.width > 200 && shared.valueCrosshair.height == 1,
               "值向准线全宽 1pt")
        // 表头键：无类目标签时 nil；有标签时代入
        // 无显式标签时 categoryLabels 自动生成序号（"1","2",…）→ headerKey 默认可用
        assert((shared.target as! HYMChartTooltipDataSource).tooltipHeaderKey != nil,
               "headerKey 默认有值（自动序号）")
        let r2 = LineChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r2.mount(into: host2)
        let m2 = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 30, 20])],
            xAxis: CartesianAxisModel(kind: .category(labels: ["一月", "二月", "三月"])))
        r2.render(model: m2, theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        let shared2 = r2.sharedHit(at: CGPoint(x: 200, y: 90))!
        assert((shared2.target as! HYMChartTooltipDataSource).tooltipHeaderKey == "二月", "headerKey 代入类目标签")

        // 3) Bar 值向准线 = 竖线
        let b = BarChartRenderer()
        let hostB = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        b.mount(into: hostB)
        b.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30])]),
                 theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: hostB.bounds, center: hostB.center))
        let bTarget = b.hitTest(CGPoint(x: 200, y: 100)) ?? b.snapHit(at: CGPoint(x: 200, y: 100))!
        let bRect = b.valueCrosshairRect(for: bTarget)!
        assert(bRect.width == 1 && bRect.height > 100, "Bar 值向准线 = 全高竖线")

        // 4) 文本模板：格式化 + 数据源行
        assert(HYMChartTooltipTextOptions.formatValue(3.14159, decimals: 2) == "3.14")
        assert(HYMChartTooltipTextOptions.formatValue(3.14159, decimals: 0) == "3")
        assert(HYMChartTooltipTextOptions.formatValue(20.0, decimals: nil) == "20")
        assert(HYMChartTooltipTextOptions.formatValue(3.5, decimals: nil) == "3.5")
        var options = HYMChartTooltipTextOptions()
        assert(options.isDefault)
        options = HYMChartTooltipTextOptions(header: "{key}", valueSuffix: " 万元", valueDecimals: 1)
        assert(!options.isDefault, "配置后不再是默认模板")
        let ds = shared2.target as! HYMChartTooltipDataSource
        assert(ds.tooltipRows.count == 1 && ds.tooltipRows[0].name == "a")
        // 模板组装（与 HYMChartView.formattedTooltipText 同逻辑的自检版）
        let text = ([ds.tooltipHeaderKey.map { options.header!.replacingOccurrences(of: "{key}", with: $0) } ?? nil].compactMap { $0 }
            + ds.tooltipRows.map { "\($0.name): \(HYMChartTooltipTextOptions.formatValue($0.value, decimals: options.valueDecimals))\(options.valueSuffix!)" })
            .joined(separator: "\n")
        assert(text == "二月\na: 30.0 万元", "模板组装结果，got \(text)")
    }

    /// 标线（阈值参考线）、折线负值换色（跨零切分）、空心圆点。
    static func runPlotLineSelfTest() {
        func walkLayers(_ l: CALayer, _ visit: (CALayer) -> Void) {
            visit(l)
            l.sublayers?.forEach { walkLayers($0, visit) }
        }
        func allLayers(of host: UIView) -> [CALayer] {
            var out: [CALayer] = []
            walkLayers(host.layer) { out.append($0) }
            return out
        }

        // 1) 标线：垂直图 = 水平横线（带虚线 pattern + 标签文本层）；越界自动隐藏
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30, 40])],
            plotLines: [CartesianPlotLine(value: 25, color: .systemRed, dashStyle: .dash, label: "阈值 25"),
                        CartesianPlotLine(value: 999)]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let layers = allLayers(of: host)
        let plotLineLayers = layers.compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor == nil && !($0.lineDashPattern ?? []).isEmpty
                      && $0.strokeColor == UIColor.systemRed.cgColor }
        assert(plotLineLayers.count == 1, "域内一条红色虚线标线（999 越界不画），got \(plotLineLayers.count)")
        let labelTexts = layers.compactMap { ($0 as? CATextLayer)?.string as? String }
        assert(labelTexts.contains("阈值 25"), "标线标签文本存在")
        // 横线：boundingBox 宽 ≈ plot 宽、高 ≈ 0
        let bbox = plotLineLayers[0].path!.boundingBoxOfPath
        assert(bbox.width > 200 && bbox.height < 1, "标线应为贯穿 plot 的水平线，got \(bbox)")

        // 2) Bar：标线 = 竖线（值轴在 X）
        let b = BarChartRenderer()
        let hostB = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        b.mount(into: hostB)
        b.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30])],
            plotLines: [CartesianPlotLine(value: 15, color: .systemRed, dashStyle: .dash)]),
                 theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: hostB.bounds, center: hostB.center))
        let bboxB = allLayers(of: hostB).compactMap { $0 as? CAShapeLayer }
            .first { $0.strokeColor == UIColor.systemRed.cgColor }?.path?.boundingBoxOfPath
        assert(bboxB != nil && bboxB!.height > 100 && bboxB!.width < 1,
               "Bar 标线应为竖线，got \(String(describing: bboxB))")

        // 3) 折线负值换色：直线形态在跨零处切分 → 正/负两条线层，负层为 negativeColor
        let rn = LineChartRenderer()
        let hostN = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rn.mount(into: hostN)
        rn.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, -10, -30, 25],
                                            negativeColor: .systemRed)]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostN.bounds, center: hostN.center))
        let lineLayers = rn.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.strokeColor != nil && $0.fillColor == nil }
        assert(lineLayers.count == 2, "正/负两条线层，got \(lineLayers.count)")
        assert(lineLayers.contains { $0.strokeColor == UIColor.systemRed.cgColor },
               "负段线层应为 negativeColor")
        // 负值点填充红
        let negDots = rn.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor == UIColor.systemRed.cgColor }
        assert(negDots.count == 2, "两个负值数据点为红色，got \(negDots.count)")

        // 4) 空心圆点：点层双叠（外环 + 内芯），内芯更小
        var theme = CartesianChartTheme()
        theme.pointHoleRadius = 1.5
        theme.pointRadius = 4
        let rh = LineChartRenderer()
        let hostH = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        rh.mount(into: hostH)
        rh.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30])]),
                  theme: theme,
                  context: HYMChartRenderContext(bounds: hostH.bounds, center: hostH.center))
        let dotLayers = rh.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor != nil }
        assert(dotLayers.count == 6, "3 点 × (外环+内芯) = 6 层，got \(dotLayers.count)")
        let radii = dotLayers.map { $0.path!.boundingBoxOfPath.width }.sorted()
        assert(radii[0] < radii[5] && radii[5] < 10, "内芯层半径小于外层")
    }

    /// 数据标签：默认格式化、三种位置的几何中心、渲染级层计数与系列级覆盖、总量超限跳过。
    static func runDataLabelSelfTest() {
        // 1) 默认格式化：整数无小数、非整数两位去尾零、formatter 优先、NaN 占位符
        assert(CartesianDataLabelGeometry.labelText(20) == "20")
        assert(CartesianDataLabelGeometry.labelText(3.5) == "3.5")
        assert(CartesianDataLabelGeometry.labelText(-4) == "-4")
        assert(CartesianDataLabelGeometry.labelText(0.25) == "0.25")
        assert(CartesianDataLabelGeometry.labelText(Double.nan) == "–")
        assert(CartesianDataLabelGeometry.labelText(7, formatter: { "¥\($0)" }) == "¥7.0")

        // 2) 折线点标签：outsideEnd 在点上方、center 在点右侧、insideEnd 在点下方（三档两两不同）
        let size = CGSize(width: 14, height: 10)
        let p = CGPoint(x: 100, y: 60)
        let above = CartesianDataLabelGeometry.labelCenter(
            point: p, textSize: size, position: .outsideEnd, pointRadius: 3)
        let right = CartesianDataLabelGeometry.labelCenter(
            point: p, textSize: size, position: .center, pointRadius: 3)
        let below = CartesianDataLabelGeometry.labelCenter(
            point: p, textSize: size, position: .insideEnd, pointRadius: 3)
        assert(above == CGPoint(x: 100, y: 60 - 3 - 5 - 2), "点上方 y = 点y-半径-h/2-2")
        assert(right == CGPoint(x: 100 + 3 + 7 + 4, y: 60),
               "center = 点右侧 x = 点x+半径+w/2+4（与 insideEnd 不同）")
        assert(below == CGPoint(x: 100, y: 60 + 3 + 5 + 2), "点下方 y = 点y+半径+h/2+2")

        // 3) 柱段标签：正值 outsideEnd 在顶外、center 在中心、负值在底外；条形水平镜像
        let rect = CGRect(x: 40, y: 50, width: 20, height: 30)
        let colOut = CartesianDataLabelGeometry.labelCenter(
            rect: rect, textSize: size, position: .outsideEnd, isHorizontal: false, isPositive: true)
        let colCtr = CartesianDataLabelGeometry.labelCenter(
            rect: rect, textSize: size, position: .center, isHorizontal: false, isPositive: true)
        let colNeg = CartesianDataLabelGeometry.labelCenter(
            rect: rect, textSize: size, position: .outsideEnd, isHorizontal: false, isPositive: false)
        let barOut = CartesianDataLabelGeometry.labelCenter(
            rect: rect, textSize: size, position: .outsideEnd, isHorizontal: true, isPositive: true)
        assert(colOut.y == rect.minY - 5 - 3 && colOut.x == rect.midX, "正值柱顶外侧")
        assert(colCtr == CGPoint(x: rect.midX, y: rect.midY), "柱段中心")
        assert(colNeg.y == rect.maxY + 5 + 3, "负值柱底外侧")
        assert(barOut.x == rect.maxX + 7 + 3 && barOut.y == rect.midY, "正条端右侧")

        // 4) 渲染级：Line 开标签 → 每个有效点一个 CATextLayer；空值点不标
        func textLayers(of host: UIView) -> [CATextLayer] {
            var out: [CATextLayer] = []
            func walk(_ l: CALayer) {
                if let t = l as? CATextLayer { out.append(t) }
                l.sublayers?.forEach(walk)
            }
            walk(host.layer)
            return out
        }
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        var theme = CartesianChartTheme()
        theme.showsDataLabels = true
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, .nan, 40])]),
                  theme: theme,
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        assert(textLayers(of: host).count == 3, "4 点中 1 空值 → 3 个标签，got \(textLayers(of: host).count)")
        assert(textLayers(of: host).compactMap { $0.string as? String }.sorted() == ["10", "20", "40"])

        // 5) 系列级覆盖：主题关、系列开 → 仍标注
        let r2 = ColumnChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r2.mount(into: host2)
        r2.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20], dataLabelsEnabled: true)]),
                  theme: CartesianChartTheme(),   // showsDataLabels = false
                  context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        assert(textLayers(of: host2).count == 2, "系列级覆盖应标注 2 个")

        // 6) 总量超限整图跳过（默认 200；缩放后可见数变少会自动恢复）
        var theme3 = CartesianChartTheme()
        theme3.showsDataLabels = true
        let big = CartesianChartModel(
            series: (0..<3).map { CartesianSeriesElement(name: "s\($0)", data: (0..<80).map { Double($0) }) })
        let r3 = LineChartRenderer()
        let host3 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r3.mount(into: host3)
        r3.render(model: big, theme: theme3,
                  context: HYMChartRenderContext(bounds: host3.bounds, center: host3.center))
        assert(textLayers(of: host3).isEmpty, "240 标注 > 200 上限 → 整图跳过")
    }

    /// Y 轴缩放：锚点跟手（缩放后锚点值屏幕位置不变）、倍率、次轴同步、橡皮筋越界、重置。
    static func runYAxisZoomSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [0, 20, 40, 60, 80]),
                     CartesianSeriesElement(name: "b", data: [10, 30, 50, 70, 90],
                                            yAxisIndex: 1)],
            secondaryYAxis: CartesianAxisModel(kind: .value, min: 0, max: 100))
        r.render(model: model, theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        assert(abs(r.yAxisZoomScale - 1) < 1e-6, "初始倍率 1")
        let fullSpan = r.fullYAxisDomain.upperBound - r.fullYAxisDomain.lowerBound

        // 1) 中心锚点放大 2 倍：span 减半、域中点不动、锚点屏幕位置不变
        let midY = r.currentPlotFrame.midY
        let midValue = (r.yAxisViewport.lowerBound + r.yAxisViewport.upperBound) / 2
        let secFullSpan = (r.currentSecondaryYDomain?.upperBound ?? 0) - (r.currentSecondaryYDomain?.lowerBound ?? 0)
        r.zoomYAxis(factor: 2, anchorScreenY: midY)
        assert(abs(r.yAxisZoomScale - 2) < 1e-6, "放大 2 倍，got \(r.yAxisZoomScale)")
        assert(abs((r.yAxisViewport.upperBound - r.yAxisViewport.lowerBound) - fullSpan / 2) < 1e-6,
               "主轴 span 减半")
        assert(abs((r.yAxisViewport.lowerBound + r.yAxisViewport.upperBound) / 2 - midValue) < 1e-6,
               "锚点值（域中点）保持")
        let p = r.screenPoint(x: 0, y: midValue)
        assert(abs(p.y - midY) < 0.5, "锚点值屏幕位置不变（跟手），got \(p.y) vs \(midY)")
        // 次轴同倍率缩放（各自域独立换算，span 同步减半）
        let secNow = (r.currentSecondaryYDomain?.upperBound ?? 0) - (r.currentSecondaryYDomain?.lowerBound ?? 0)
        assert(abs(secNow - secFullSpan / 2) < 1e-6, "次轴 span 同步减半")

        // 2) 平移：上滑（负 dy）→ 视口向数值大端移动
        let before = r.yAxisViewport.lowerBound
        r.panYAxis(screenDeltaY: -40, allowsRubberBand: false)
        assert(r.yAxisViewport.lowerBound > before, "上滑后视口下界上移（数值大端）")

        // 3) 橡皮筋：越界平移后 isYAxisOvershooting，setYAxisViewport 钳回
        r.panYAxis(screenDeltaY: 100000, allowsRubberBand: true)
        assert(r.isYAxisOvershooting, "大幅平移应越界")
        r.setYAxisViewport(r.fullYAxisDomain)
        assert(!r.isYAxisOvershooting, "setYAxisViewport 到全量域后不越界")

        // 4) 重置：倍率回 1、次轴域回全量
        r.resetYAxisViewport()
        assert(abs(r.yAxisZoomScale - 1) < 1e-6, "重置后倍率 1")
        let secReset = (r.currentSecondaryYDomain?.upperBound ?? 0) - (r.currentSecondaryYDomain?.lowerBound ?? 0)
        assert(abs(secReset - secFullSpan) < 1e-6, "次轴域回全量")

        // 5) 水平图（Bar）：Y 缩放作用于类目轴——放大后类目域收窄
        let b = BarChartRenderer()
        let hostB = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        b.mount(into: hostB)
        b.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30, 40, 50, 60])]),
                 theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: hostB.bounds, center: hostB.center))
        b.zoomYAxis(factor: 2, anchorScreenY: b.currentPlotFrame.midY)
        assert(abs(b.yAxisZoomScale - 2) < 1e-6, "Bar 纵向类目轴可缩放，got \(b.yAxisZoomScale)")
    }

    /// 标记符号：五种形状的 path 元素结构 + 渲染级点层形状；十字准线 frame 贯穿绘图区。
    static func runMarkerSymbolSelfTest() {
        // 1) 纯函数：circle = 4 曲线；square/diamond = 4 直线；triangle* = 3 直线
        func counts(_ sym: PointMarkerSymbol) -> (lines: Int, curves: Int) {
            var l = 0, c = 0
            sym.path(center: CGPoint(x: 10, y: 10), radius: 3).applyWithBlock { e in
                switch e.pointee.type {
                case .addLineToPoint: l += 1
                case .addCurveToPoint, .addQuadCurveToPoint: c += 1
                default: break
                }
            }
            return (l, c)
        }
        assert(counts(.circle).curves == 4, "circle 应为 4 段曲线")
        assert(counts(.square).lines == 3, "square = move+3 线段+close（4 顶点），got \(counts(.square))")
        // diamond/triangle 的"回到起点"末线段会被 UIBezierPath 折叠进 close（不再单独输出）
        assert(counts(.diamond).lines == 3, "diamond 应为 3 线段+close（末段折叠），got \(counts(.diamond))")
        assert(counts(.triangle).lines == 2, "triangle = 2 线段+close（末段折叠），got \(counts(.triangle))")
        assert(counts(.triangleDown).lines == 2, "triangleDown = 2 线段+close")
        assert(PointMarkerSymbol.allCases.count == 5, "五种标记符号")

        // 2) 渲染级：系列级 triangle 覆盖主题 circle；点层为填充形状层
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20], pointSymbol: .triangle)]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let dotLayers = r.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.fillColor != nil }   // 点层（线层 fillColor = nil）
        assert(dotLayers.count == 2, "两个数据点应有两个点层，got \(dotLayers.count)")
        var triLines = 0
        dotLayers.forEach { $0.path?.applyWithBlock { e in
            if e.pointee.type == .addLineToPoint { triLines += 1 }
        } }
        assert(triLines == 4, "两个三角点层应各 2 线段（末段折叠进 close），got \(triLines)")

        // 3) 十字准线：贯穿绘图区、x 对齐类目中心
        let sh = LineChartRenderer()
        let hostS = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        sh.mount(into: hostS)
        sh.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostS.bounds, center: hostS.center))
        let plotS = sh.currentPlotFrame
        let cat1 = CartesianGeometry.point(x: 1, y: 0, viewport: sh.currentViewport,
                                           plotFrame: plotS).x
        if let hit = sh.sharedHit(at: CGPoint(x: cat1, y: plotS.midY)) {
            let ch = hit.crosshair
            assert(abs(ch.minX - cat1) < 1.0, "准线 x 应对齐类目中心，got \(ch.minX) vs \(cat1)")
            assert(abs(ch.minY - plotS.minY) < 0.01 && abs(ch.height - plotS.height) < 0.01,
                   "准线应贯穿绘图区全高，got \(ch)")
        } else {
            assertionFailure("应产生整列命中")
        }
    }

    /// 空值（NaN）：断线成多段子路径、connectNulls 直连、柱状跳过、堆叠链不被空值破坏。
    static func runNullValueSelfTest() {
        // 1) dataBounds 过滤 NaN：[10, NaN, 30] → 10...30
        let nullModel = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, .nan, 30])])
        let nb = nullModel.dataBounds()!
        assert(abs(nb.min - 10) < 1e-9 && abs(nb.max - 30) < 1e-9,
               "dataBounds 应跳过 NaN，got \(nb)")

        // 2) 堆叠链不被空值破坏：a=[10,NaN,30]、b=[1,2,3] → b 累计 [11,2,33]、a 空点 NaN
        let chain = CartesianGeometry.stackedValuesByAxis(series: [
            CartesianSeriesElement(name: "a", data: [10, .nan, 30]),
            CartesianSeriesElement(name: "b", data: [1, 2, 3])])
        assert(chain[0][1].isNaN, "空值点自身应为 NaN")
        assert(chain[1] == [11, 2, 33], "后续系列累计应视空值为缺位，got \(chain[1])")

        // 3) 折线断线：NaN 处线断成两段（path 两个子路径）
        func lineSubpathCount(_ connectNulls: Bool) -> Int {
            let r = LineChartRenderer()
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
            r.mount(into: host)
            r.render(model: CartesianChartModel(
                series: [CartesianSeriesElement(name: "a", data: [10, 20, .nan, 40, 50],
                                                connectNulls: connectNulls)]),
                     theme: CartesianChartTheme(),
                     context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
            var moves = 0
            for layer in r.seriesLayerSublayersForTesting() {
                // 线层 = 有描边无填充（点层为填充形状层，单点 1 子路径会虚高计数）
                guard let sl = layer as? CAShapeLayer,
                      sl.strokeColor != nil, sl.fillColor == nil else { continue }
                sl.path?.applyWithBlock { elem in
                    if elem.pointee.type == .moveToPoint { moves += 1 }
                }
            }
            return moves
        }
        assert(lineSubpathCount(false) == 2, "NaN 断线应有 2 个子路径，got \(lineSubpathCount(false))")
        assert(lineSubpathCount(true) == 1, "connectNulls 应连成 1 段，got \(lineSubpathCount(true))")

        // 4) 柱状：空值类目不画柱、不可命中
        let c = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        c.mount(into: hostC)
        c.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, .nan, 30])]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        var columnMoves = 0
        for layer in c.seriesLayerSublayersForTesting() {
            (layer as? CAShapeLayer)?.path?.applyWithBlock { elem in
                if elem.pointee.type == .moveToPoint { columnMoves += 1 }
            }
        }
        assert(columnMoves == 2, "3 类目含 1 空值应只画 2 柱，got \(columnMoves)")

        // 5) 整列命中：空值系列不出现在弹窗（entries 为空 → 该列回落逐点/无命中）
        let sh = LineChartRenderer()
        let hostS = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        sh.mount(into: hostS)
        sh.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [.nan]),
                     CartesianSeriesElement(name: "b", data: [5])]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostS.bounds, center: hostS.center))
        if let hit = sh.sharedHit(at: CGPoint(x: sh.currentPlotFrame.midX,
                                              y: sh.currentPlotFrame.midY)) {
            let t = hit.target as! CartesianSharedHitTarget
            assert(t.entries.count == 1 && t.entries[0].name == "b",
                   "空值系列应被跳过，got \(t.entries)")
        } else {
            assertionFailure("含空值列也应可整列命中（只含有效系列）")
        }
    }

    /// 虚线样式：11 种 dashStyle 的 pattern 纯函数 + 渲染级 lineDashPattern 接线（系列级覆盖主题）。
    static func runDashStyleSelfTest() {
        // 1) 纯函数：solid → nil；非 solid → 交替偶数段非空
        assert(LineDashStyle.solid.dashPattern == nil, "solid 应无 pattern")
        for style in LineDashStyle.allCases where style != .solid {
            let p = style.dashPattern!
            assert(!p.isEmpty && p.count % 2 == 0, "\(style) pattern 应为非空偶数段，got \(p)")
            assert(p.allSatisfy { $0.doubleValue > 0 }, "\(style) pattern 段长应为正")
        }
        assert(LineDashStyle.allCases.count == 11, "应对齐 Highcharts 的 11 种样式")

        // 2) 渲染级：系列级 dash 生效、其余系列实线（覆盖主题）
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "实际", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "预测", data: [15, 25, 35],
                                            lineDashStyle: .longDashDot)]),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        // 线层 = 有描边无填充（点层是填充形状层，无 dashPattern）
        let shapeLayers = r.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.strokeColor != nil && $0.fillColor == nil }
        let dashed = shapeLayers.filter { $0.lineDashPattern?.isEmpty == false }
        assert(dashed.count == 1, "应只有 1 条虚线（预测系列），got \(dashed.count)")
        if let d = dashed.first {
            assert(d.lineDashPattern == LineDashStyle.longDashDot.dashPattern,
                   "系列级样式应为 longDashDot，got \(String(describing: d.lineDashPattern))")
        }

        // 3) 主题级默认：不设系列样式时全部跟随主题
        var theme = CartesianChartTheme()
        theme.lineDashStyle = .dot
        let r2 = LineChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r2.mount(into: host2)
        r2.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20]),
                     CartesianSeriesElement(name: "b", data: [5, 15])]),
                  theme: theme,
                  context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        let shape2 = r2.seriesLayerSublayersForTesting().compactMap { $0 as? CAShapeLayer }
            .filter { $0.strokeColor != nil && $0.fillColor == nil }
        assert(shape2.count == 2 && shape2.allSatisfy { $0.lineDashPattern == LineDashStyle.dot.dashPattern },
               "主题级 dot 应应用到全部系列，got \(shape2.map { String(describing: $0.lineDashPattern) })")
    }

    /// 百分比堆叠：同列归一到 0...100（按符号分链），渲染域 0...100，命中报百分比累计。
    static func runPercentStackingSelfTest() {
        // 1) 纯函数：80/20 → 80%/100%；列内全零 → 0
        let a0 = CartesianSeriesElement(name: "a", data: [80])
        let b0 = CartesianSeriesElement(name: "b", data: [20])
        let a = CartesianSeriesElement(name: "a", data: [80, 0])
        let b = CartesianSeriesElement(name: "b", data: [20, 0])
        let pct = CartesianGeometry.stackedPercentValues(series: [a, b])
        assert(pct[0] == [80, 0] && pct[1] == [100, 0],
               "百分比累计应为 80/100 与全零列 0，got \(pct)")

        // 2) 正负混合：75/-25 → 75% 向上、-25% 向下（|v| 总和为分母）
        let m = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [75]),
                     CartesianSeriesElement(name: "b", data: [-25])],
            stacking: .percent)
        let mp = CartesianGeometry.stackedPercentValues(series: m.series)
        assert(mp[0] == [75] && mp[1] == [-25],
               "正负混合应按 |v| 归一各走各链，got \(mp)")
        let mb = m.dataBounds(yAxisIndex: 0)!
        assert(abs(mb.min + 25) < 1e-9 && abs(mb.max - 75) < 1e-9,
               "percent 边界应为 -25...75，got \(mb)")

        // 2.5) 统一基准 percentFixed：a=80,b=20、max=200 → 累计 40%/50%（不满 100）
        let fixed = CartesianGeometry.stackedPercentValues(
            series: [a0, b0], fixedMax: 200)
        assert(fixed[0] == [40] && fixed[1] == [50],
               "统一基准 200 应得累计 40/50（不满 100），got \(fixed)")
        let fixedModel = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [80]),
                     CartesianSeriesElement(name: "b", data: [20])],
            stacking: .percentFixed(max: 200))
        assert(fixedModel.isStacked, "percentFixed 应视为堆叠形态")
        let fb = fixedModel.dataBounds(yAxisIndex: 0)!
        assert(abs(fb.max - 50) < 1e-9, "统一基准边界应为 50%，got \(fb)")

        // 3) 渲染级（折线）：正值百分比堆叠域 0...100，顶线在 plot 顶部
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [80, 30]),
                     CartesianSeriesElement(name: "b", data: [20, 70])],
            stacking: .percent),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        assert(abs(r.currentViewport.yMax - 100) < 0.001 && abs(r.currentViewport.yMin) < 0.001,
               "percent 域应 nice 到 0...100，got \(r.currentViewport.yDomain)")
        let top = r.testScreenPoint(series: 1, index: 0)
        assert(abs(top.y - r.currentPlotFrame.minY) < 1.0, "百分比累计 100 应在顶部，got \(top.y)")

        // 4) 渲染级（柱状）：柱高比例 = 百分比，命中报百分比累计
        let c = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        c.mount(into: hostC)
        c.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [80]),
                     CartesianSeriesElement(name: "b", data: [20])],
            stacking: .percent),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        let plotC = c.currentPlotFrame
        if let hit = c.hitTest(CGPoint(x: plotC.midX, y: plotC.minY + plotC.height * 0.05)) as? ColumnHitTarget {
            assert(hit.seriesIndex == 1 && abs(hit.value - 100) < 0.001,
                   "顶部应命中 b 的百分比累计 100，got series=\(hit.seriesIndex) value=\(hit.value)")
        } else {
            assertionFailure("percent 顶部柱段应可命中")
        }
    }

    /// 点击按 X 类目取整列：任意 x 归到最近类目，弹窗文本含所有系列值；绘图区外回落。
    static func runSharedHitSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        r.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25], yAxisIndex: 1)],
            secondaryYAxis: CartesianAxisModel(kind: .value, min: 0, max: 100)),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame

        // 点在类目 1 的带内任意高度（避开数据点也可）→ 归到类目 1，两系列值都在文本里
        let tapY = plot.minY + plot.height * 0.3
        let cat1x = CartesianGeometry.point(x: 1, y: 0, viewport: r.currentViewport,
                                            plotFrame: plot).x
        if let hit = r.sharedHit(at: CGPoint(x: cat1x + 3, y: tapY)) {
            let t = hit.target as! CartesianSharedHitTarget
            assert(t.categoryIndex == 1, "应归到最近类目 1，got \(t.categoryIndex)")
            assert(t.entries.count == 2, "两个系列都应有值，got \(t.entries)")
            assert(t.entries[0].value == 20 && t.entries[1].value == 15,
                   "类目 1 各系列值应为 20/15，got \(t.entries)")
            assert(t.entries[1].isSecondaryAxis, "次轴系列应标注")
            assert(hit.target.tooltipText?.contains("b: 15") == true,
                   "组合文本应含各系列值，got \(String(describing: hit.target.tooltipText))")
            assert(hit.anchor.frame.minX < plot.maxX && hit.anchor.frame.minX > plot.minX,
                   "锚点十字线应在 plot 内")
            // 锚点应在触点位置（跟手弹窗），而非固定在 plot 顶部
            assert(abs(hit.anchor.frame.minY - tapY) < 2,
                   "锚点 y 应在触点处，got \(hit.anchor.frame.minY) vs \(tapY)")
        } else {
            assertionFailure("绘图区内点击应产生整列命中")
        }

        // 绘图区外（左上角标签区）→ nil（回落逐点命中）
        assert(r.sharedHit(at: CGPoint(x: 2, y: 2)) == nil, "plot 外应返回 nil")

        // 锯齿数据集：短系列缺值被跳过
        let jag = LineChartRenderer()
        jag.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5])]),
                   theme: CartesianChartTheme(),
                   context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        if let hit2 = jag.sharedHit(at: CGPoint(x: jag.currentPlotFrame.midX,
                                                y: jag.currentPlotFrame.midY)) {
            let t2 = hit2.target as! CartesianSharedHitTarget
            assert(t2.entries.allSatisfy { $0.seriesIndex == 0 || t2.categoryIndex == 0 },
                   "短系列在缺值类目应被跳过，got \(t2.entries)")
        } else {
            assertionFailure("锯齿数据集也应可整列命中")
        }

        // 吸附命中：点空（远离数据点）→ 横向最近类目上最近的系列点，永远有反馈
        let snap = LineChartRenderer()
        let hostS = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        snap.mount(into: hostS)
        snap.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "低值", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "高值", data: [60, 80, 90])]),
                   theme: CartesianChartTheme(),
                   context: HYMChartRenderContext(bounds: hostS.bounds, center: hostS.center))
        let plotS = snap.currentPlotFrame
        // 点在类目 1 上方的空白处（两系列都够不着）→ 吸附到屏幕距离更近的"高值"
        let cat1 = CartesianGeometry.point(x: 1, y: 0, viewport: snap.currentViewport,
                                           plotFrame: plotS).x
        assert(snap.hitTest(CGPoint(x: cat1, y: plotS.minY + 5)) == nil,
               "空白处逐点命中应为 nil（吸附前提）")
        if let t = snap.snapHit(at: CGPoint(x: cat1, y: plotS.minY + 5)) as? LineHitTarget {
            assert(t.seriesIndex == 1 && t.index == 1 && t.value == 80,
                   "应吸附到类目 1 屏幕距离最近的高值系列 80，got series=\(t.seriesIndex) value=\(t.value)")
        } else {
            assertionFailure("空白处点击应吸附到最近数据点")
        }
        // plot 区外不吸附
        assert(snap.snapHit(at: CGPoint(x: 2, y: 2)) == nil, "plot 外不应吸附")
    }

    /// 符号分组堆叠：正链从 0 向上、负链从 0 向下（Highcharts 同款）；面积/柱基准贴所属链。
    static func runSignSeparatedStackingSelfTest() {
        // 1) 纯函数：正负各走各链，不混合
        let pos = CartesianSeriesElement(name: "a", data: [100, 50])
        let neg = CartesianSeriesElement(name: "b", data: [-30, -20])
        let pos2 = CartesianSeriesElement(name: "c", data: [10, 10])
        let r = CartesianGeometry.stackedValuesByAxis(series: [pos, neg, pos2])
        assert(r[0] == [100, 50], "首正系列 = 原值")
        assert(r[1] == [-30, -20], "负系列应从 0 向下累计，不与正链混合，got \(r[1])")
        assert(r[2] == [110, 60], "第二正系列接正链：100+10, 50+10，got \(r[2])")

        // 2) 渲染级（折线）：负系列点在零轴下方、正系列在上方
        let lr = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        lr.mount(into: host)
        var theme = CartesianChartTheme()
        theme.showsArea = true
        lr.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "收入", data: [40, 60], color: .systemBlue),
                     CartesianSeriesElement(name: "支出", data: [-30, -20], color: .systemOrange)],
            stacking: .normal),
                  theme: theme,
                  context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: lr.currentViewport, plotArea: lr.currentPlotFrame, isHorizontal: false)
        let pPos = lr.testScreenPoint(series: 0, index: 0)
        let pNeg = lr.testScreenPoint(series: 1, index: 0)
        assert(pPos.y < zeroY - 1, "正值系列应在零轴上方，got \(pPos.y) vs zero \(zeroY)")
        assert(pNeg.y > zeroY + 1, "负值系列应在零轴下方（镜像），got \(pNeg.y) vs zero \(zeroY)")

        // 3) 渲染级（柱状）：负系列柱在零轴下方且可命中
        let cr = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        cr.mount(into: hostC)
        cr.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "收入", data: [60, 40]),
                     CartesianSeriesElement(name: "支出", data: [-30, -25])],
            stacking: .normal),
                  theme: CartesianChartTheme(),
                  context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        let plotC = cr.currentPlotFrame
        let zeroC = CartesianGeometry.zeroAxisPosition(
            viewport: cr.currentViewport, plotArea: plotC, isHorizontal: false)
        // 与 seriesHitTest 同源几何：负系列（index 1）柱 rect = 零轴 → 累计值
        let negCum = CartesianGeometry.stackedValuesByAxis(series: [
            CartesianSeriesElement(name: "收入", data: [60, 40]),
            CartesianSeriesElement(name: "支出", data: [-30, -25])])[1][0]
        let negRect = CartesianGeometry.columnRect(
            dataPoint: negCum, categoryIndex: 0, viewport: cr.currentViewport,
            plotArea: plotC, theme: CartesianChartTheme(), zeroY: zeroC,
            seriesIndex: 0, seriesCount: 1)
        assert(negRect.midY > zeroC + 1, "负值堆叠柱应在零轴下方，got \(negRect) vs zero \(zeroC)")
        if let hit = cr.hitTest(CGPoint(x: negRect.midX, y: negRect.midY)) as? ColumnHitTarget {
            assert(hit.seriesIndex == 1 && hit.value < 0,
                   "零轴下方应命中负值系列（累计 \(negCum)），got series=\(hit.seriesIndex) value=\(hit.value)")
        } else {
            assertionFailure("负值堆叠柱（零轴下方）应可命中")
        }

        // 4) 全非负数据回归：与旧链式求和一致（既有断言依赖）
        let allPos = CartesianGeometry.stackedValuesByAxis(
            series: [CartesianSeriesElement(name: "a", data: [10, 20]),
                     CartesianSeriesElement(name: "b", data: [5, 15])])
        assert(allPos == [[10, 20], [15, 35]], "全非负时应保持链式累计，got \(allPos)")

        // 5) 堆叠圆角：只有链末段（正链最上段）带圆角，中间段直角——
        //    统计 seriesLayer 各 path 的曲线元素数：3 类目 × 顶段 2 个圆角曲线 = 6
        let stackCornerRenderer = ColumnChartRenderer()
        let stackCornerHost = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        stackCornerRenderer.mount(into: stackCornerHost)
        stackCornerRenderer.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])],
            stacking: .normal),
                                  theme: CartesianChartTheme(),
                                  context: HYMChartRenderContext(bounds: stackCornerHost.bounds,
                                                                 center: stackCornerHost.center))
        do {
            var perLayer: [Int] = []
            for layer in stackCornerRenderer.seriesLayerSublayersForTesting() {
                var c = 0
                (layer as? CAShapeLayer)?.path?.applyWithBlock { elem in
                    if elem.pointee.type == .addCurveToPoint || elem.pointee.type == .addQuadCurveToPoint { c += 1 }
                }
                perLayer.append(c)
            }
            print("🧪 stack corner curves per layer: \(perLayer), total \(perLayer.reduce(0, +))")
        }
        // UIKit 每 2 圆角矩形产生 6 条曲线元素（多段三次逼近），断言改为按层：
        // 堆叠时只有顶段所在层有圆角曲线，中间段层为 0
        let roundedLayerCount = stackCornerRenderer.seriesLayerSublayersForTesting()
            .filter { layer in
                var c = 0
                (layer as? CAShapeLayer)?.path?.applyWithBlock { elem in
                    if elem.pointee.type == .addCurveToPoint || elem.pointee.type == .addQuadCurveToPoint { c += 1 }
                }
                return c > 0
            }.count
        assert(roundedLayerCount == 1,
               "堆叠时应只有顶段 1 个层带圆角，got \(roundedLayerCount)")
        // 非堆叠对照：每根柱独立圆角 → 2 系列 × 3 类目 × 2 = 12
        let plainCornerRenderer = ColumnChartRenderer()
        let plainCornerHost = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        plainCornerRenderer.mount(into: plainCornerHost)
        plainCornerRenderer.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])]),
                                   theme: CartesianChartTheme(),
                                   context: HYMChartRenderContext(bounds: plainCornerHost.bounds,
                                                                  center: plainCornerHost.center))
        let plainRoundedLayerCount = plainCornerRenderer.seriesLayerSublayersForTesting()
            .filter { layer in
                var c = 0
                (layer as? CAShapeLayer)?.path?.applyWithBlock { elem in
                    if elem.pointee.type == .addCurveToPoint || elem.pointee.type == .addQuadCurveToPoint { c += 1 }
                }
                return c > 0
            }.count
        assert(plainRoundedLayerCount == 2,
               "非堆叠两个系列层都应有圆角，got \(plainRoundedLayerCount)")
    }

    /// 堆叠折线：累计线位置正确；面积分层（第 2 系列面积下边界 = 第 1 系列累计线）；命中报累计值。
    static func runLineStackingSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        var theme = CartesianChartTheme()
        theme.showsArea = true
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 40]),
                     CartesianSeriesElement(name: "b", data: [10, 20])],
            stacking: .normal)
        r.render(model: model, theme: theme,
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame
        // 域 = 累计边界 (10...60) → nice 0...60
        assert(abs(r.currentViewport.yMax - 60) < 0.001,
               "堆叠域应按累计值 0...60，got \(r.currentViewport.yDomain)")

        // 系列 1（上层）在 index1 的累计值 = 40+20 = 60 → 顶部
        let top = r.testScreenPoint(series: 1, index: 1)
        assert(abs(top.y - plot.minY) < 1.0, "累计 60 应在 plot 顶部，got \(top.y)")
        // 系列 0 在 index1 = 40 → 底部起 2/3 高
        let mid = r.testScreenPoint(series: 0, index: 1)
        assert(abs(mid.y - (plot.maxY - plot.height * (40.0 / 60.0))) < 1.0,
               "系列0 累计 40 应按 40/60 映射，got \(mid.y)")

        // 命中报累计值（与柱状一致）：点系列1 index1 → 60
        if let hit = r.hitTest(top) as? LineHitTarget {
            assert(abs(hit.value - 60) < 0.001, "堆叠命中应报累计值 60，got \(hit.value)")
        } else {
            assertionFailure("堆叠折线顶层点应可命中")
        }

        // 面积分层：两个系列 → 两层面积渐变
        let seriesLayers = r.seriesLayerSublayersForTesting()
        assert(seriesLayers.count { $0 is CAGradientLayer } == 2, "两层面积渐变")
    }

    /// 次轴系列按次轴域映射：同一数值、不同轴 → 不同屏幕高度；命中 target 带轴索引。
    static func runDualAxisSeriesSelfTest() {
        let r = LineChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        var sec = CartesianAxisModel(kind: .value, min: 0, max: 100)
        sec.tickPositions = [0, 50, 100]
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "温度", data: [15, 25]),
                     CartesianSeriesElement(name: "湿度", data: [15, 25], yAxisIndex: 1)],
            secondaryYAxis: sec)
        r.render(model: model, theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame

        // 1) 主轴系列：25 按主轴域（nice 0...25）映到 plot 顶部
        let pMain = r.testScreenPoint(series: 0, index: 1)
        let expectedMain = plot.maxY - plot.height
                * (25.0 / max(r.currentViewport.yMax - r.currentViewport.yMin, 1e-9))
        assert(abs(pMain.y - expectedMain) < 1.0,
               "主轴系列应按主轴域映射，got \(pMain.y) vs \(expectedMain)")
        // 2) 次轴系列：25 在域 0...100 → 底部起 1/4 高度
        let pSec = r.testScreenPoint(series: 1, index: 1)
        assert(abs(pSec.y - (plot.maxY - plot.height * 0.25)) < 1.0,
               "次轴系列应按次轴域映射到 1/4 高度，got \(pSec.y)")

        // 3) 命中 target 带 yAxisIndex
        if let hit = r.hitTest(pSec) as? LineHitTarget {
            assert(hit.yAxisIndex == 1, "次轴系列命中应带 yAxisIndex=1，got \(hit.yAxisIndex)")
            assert(abs(hit.value - 25) < 0.001, "命中值应为原始值 25")
        } else {
            assertionFailure("次轴数据点应可命中")
        }

        // 4) Column 双轴负值零轴：次轴域 -50...50、值 -25 → 柱在零轴（半高）下方
        let c = ColumnChartRenderer()
        let hostC = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        c.mount(into: hostC)
        var secNeg = CartesianAxisModel(kind: .value, min: -50, max: 50)
        secNeg.tickPositions = [-50, 0, 50]
        c.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "s", data: [-25], yAxisIndex: 1)],
            secondaryYAxis: secNeg),
                 theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: hostC.bounds, center: hostC.center))
        let plotC = c.currentPlotFrame
        if let hitC = c.hitTest(CGPoint(x: plotC.midX, y: plotC.midY + plotC.height * 0.2)) as? ColumnHitTarget {
            assert(hitC.yAxisIndex == 1, "次轴柱命中应带 yAxisIndex=1")
        } else {
            assertionFailure("次轴负值柱（零轴下方）应可命中")
        }
    }

    /// 双轴渲染契约：两轴值域独立、右侧让宽并画右侧刻度、次轴网格默认关。
    static func runDualAxisRenderSelfTest() {
        let r = ColumnChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        r.mount(into: host)
        // 主轴：温度 0...30；次轴：湿度 0...100（显式域，formatter 加 %）
        var sec = CartesianAxisModel(kind: .value, min: 0, max: 100)
        sec.labelFormatter = { "\(Int($0))%" }
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "温度", data: [5, 15, 25]),
                     CartesianSeriesElement(name: "湿度", data: [40, 70, 90], yAxisIndex: 1)],
            secondaryYAxis: sec)
        r.render(model: model, theme: CartesianChartTheme(),
                 context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = r.currentPlotFrame

        // 1) 主轴域只由 axis0 系列决定（5...25 → nice 0...25）
        assert(abs(r.currentViewport.yMin) < 0.001 && abs(r.currentViewport.yMax - 25) < 0.001,
               "主轴域应为 0...25，got \(r.currentViewport.yDomain)")
        // 2) 次轴域独立（显式 0...100）
        assert(r.currentSecondaryYDomain == 0...100,
               "次轴域应为显式 0...100，got \(String(describing: r.currentSecondaryYDomain))")
        assert(!r.currentSecondaryValueTicks.isEmpty, "次轴刻度不应为空")

        // 3) 右侧让宽：plot 右缘远离 view 右缘（右侧刻度列存在）
        assert(host.bounds.maxX - plot.maxX > 20,
               "右侧应为次轴刻度让宽，plot.maxX=\(plot.maxX)")

        // 4) 右侧刻度存在且带 formatter 文本、位于 plot 右侧
        let labels = host.subviews.compactMap { $0 as? UILabel }
        let pct = labels.first { $0.text == "100%" }
        assert(pct != nil, "右侧应有刻度文本 100%，got \(labels.map { $0.text ?? "" })")
        if let p = pct {
            assert(p.center.x > plot.maxX, "右侧刻度应在 plot 右侧，got \(p.center.x)")
        }

        // 5) 单轴回归：secondaryYAxis 为 nil 时次轴状态为空、无右侧让宽
        let single = ColumnChartRenderer()
        let host2 = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        single.mount(into: host2)
        single.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "s", data: [5, 15, 25])]),
                      theme: CartesianChartTheme(),
                      context: HYMChartRenderContext(bounds: host2.bounds, center: host2.center))
        assert(single.currentSecondaryYDomain == nil && single.currentSecondaryValueTicks.isEmpty,
               "单轴时次轴状态应为空")
        assert(single.currentPlotFrame.maxX > plot.maxX,
               "单轴 plot 应比双轴更靠右（无右轴让宽）")
    }

    /// 双轴分组边界、按轴堆叠、几何函数 domain 参数。
    static func runDualAxisGeometrySelfTest() {
        // 1) yAxisIndex clamp：越界回落 0/1
        let s0 = CartesianSeriesElement(name: "a", data: [1])
        assert(s0.effectiveYAxisIndex == 0, "默认绑主轴")
        assert(CartesianSeriesElement(name: "b", data: [1], yAxisIndex: 1).effectiveYAxisIndex == 1,
               "1 绑次轴")
        assert(CartesianSeriesElement(name: "c", data: [1], yAxisIndex: 7).effectiveYAxisIndex == 0,
               "越界回落主轴")

        // 2) dataBounds(yAxisIndex:) 分组（堆叠按轴分组累计）
        let mA = CartesianSeriesElement(name: "a", data: [10, 40])
        let mB = CartesianSeriesElement(name: "b", data: [20, 30], yAxisIndex: 1)
        let dual = CartesianChartModel(series: [mA, mB], secondaryYAxis: CartesianAxisModel(kind: .value))
        assert(dual.dataBounds(yAxisIndex: 0)!.min == 10 && dual.dataBounds(yAxisIndex: 0)!.max == 40,
               "主轴组边界只含 axis0 系列")
        assert(dual.dataBounds(yAxisIndex: 1)!.min == 20 && dual.dataBounds(yAxisIndex: 1)!.max == 30,
               "次轴组边界只含 axis1 系列")
        assert(CartesianChartModel(series: [mA]).dataBounds(yAxisIndex: 1) == nil,
               "无绑定系列且无显式域 → nil")
        // 单轴堆叠回归：dataBounds(yAxisIndex: 0) 与旧 dataBounds 语义一致
        let stacked2 = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])],
            stacking: .normal)
        let sb = stacked2.dataBounds(yAxisIndex: 0)!
        assert(sb.min == 10 && sb.max == 55, "堆叠边界应为累计值 10...55，got \(sb)")

        // 3) stackedValuesByAxis：跨轴不混叠、组内链式累计、与输入同序
        let r = CartesianGeometry.stackedValuesByAxis(series: [mA, mB, mA])
        assert(r[0] == [10, 40], "系列0（axis0 首个）= 原值")
        assert(r[1] == [20, 30], "系列1（axis1 首个）= 原值，不与 axis0 混叠")
        assert(r[2] == [20, 80], "系列2（axis0 第二个）= 10+10, 40+40")
        // 全 0 轴时与 stackedValues 一致
        let allZero = CartesianGeometry.stackedValuesByAxis(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])])
        assert(allZero == CartesianGeometry.stackedValues(
            series: [CartesianSeriesElement(name: "a", data: [10, 20, 30]),
                     CartesianSeriesElement(name: "b", data: [5, 15, 25])]),
               "全主轴时应与 stackedValues 完全一致")

        // 4) point yDomain 参数：同一 y 值在不同域上映到不同高度，nil = 现状
        let vp = CartesianViewport(xMin: -0.5, xMax: 1.5, yMin: 0, yMax: 100)
        let plot = CGRect(x: 0, y: 0, width: 100, height: 100)
        let pMain = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot)
        let pNil = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot, yDomain: nil)
        assert(pMain == pNil, "yDomain nil 应等于现状")
        let pSec = CartesianGeometry.point(x: 0, y: 50, viewport: vp, plotFrame: plot,
                                           yDomain: 0...1000)
        assert(abs(pSec.y - 95) < 0.001, "次轴域 0...1000 时 y=50 应在 95%（底部起 5% 高），got \(pSec.y)")

        // 5) zeroAxisPosition valueDomain：混合域次轴零轴位置正确
        let zSec = CartesianGeometry.zeroAxisPosition(
            viewport: vp, plotArea: plot, isHorizontal: false, valueDomain: -100...100)
        assert(abs(zSec - 50) < 0.001, "次轴 -100...100 零轴应在半高，got \(zSec)")

        // 6) columnRect valueDomain：次轴系列的柱高按次轴域映射
        let secRect = CartesianGeometry.columnRect(
            dataPoint: 50, categoryIndex: 0, viewport: vp, valueDomain: 0...1000,
            plotArea: plot, theme: CartesianChartTheme(), zeroY: 100)
        assert(abs(secRect.maxY - 100) < 0.001 && abs(secRect.height - 5) < 0.001,
               "50/1000 域柱高应为 plot 高的 1/20，got \(secRect)")
    }

    /// 值轴刻度四档优先级：tickPositions > tickInterval > tickCount > 自动；labelFormatter 文本。
    static func runTickCustomizationSelfTest() {
        let dom = 0.0...100.0
        let bounds = (min: 0.0, max: 100.0)

        // 1) 显式位置最高优先（不规则刻度 0/25/60/100 原样返回，域内过滤）
        let posAxis = CartesianAxisModel(kind: .value, tickPositions: [0, 25, 60, 100])
        assert(ValueTickGenerator.ticks(axis: posAxis, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 25, 60, 100],
               "tickPositions 应原样生效")
        // 域外刻度被过滤
        let posOut = CartesianAxisModel(kind: .value, tickPositions: [-20, 0, 50, 120])
        assert(ValueTickGenerator.ticks(axis: posOut, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 50],
               "域外 tickPositions 应被过滤")

        // 2) tickInterval 须配显式 min/max（现状规则）：0...100 步长 25
        let intAxis = CartesianAxisModel(kind: .value, min: 0, max: 100, tickInterval: 25)
        assert(ValueTickGenerator.ticks(axis: intAxis, domain: dom, dataBounds: bounds,
                                        generatesFromDomain: false) == [0, 25, 50, 75, 100],
               "tickInterval 应按现状规则步进")

        // 3) tickCount 驱动 nice scale：(3,97) + count 3 → 步长 50 → [0,50,100]
        let cntAxis = CartesianAxisModel(kind: .value, tickCount: 3)
        let byCount = ValueTickGenerator.ticks(axis: cntAxis, domain: dom,
                                               dataBounds: (min: 3, max: 97),
                                               generatesFromDomain: false)
        assert(byCount == [0, 50, 100], "tickCount=3 应出 3 条刻度，got \(byCount)")

        // 4) 自动默认 6（现状）：(3,97) → 0...100 步长 20
        let autoAxis = CartesianAxisModel(kind: .value)
        let byAuto = ValueTickGenerator.ticks(axis: autoAxis, domain: dom,
                                              dataBounds: (min: 3, max: 97),
                                              generatesFromDomain: false)
        assert(byAuto == [0, 20, 40, 60, 80, 100], "自动应保持默认 6 档，got \(byAuto)")

        // 5) generatesFromDomain（水平图 X 窗口）：按窗口 50...100 生成并过滤
        let hAxis = CartesianAxisModel(kind: .value)
        let hTicks = ValueTickGenerator.ticks(axis: hAxis, domain: 50...100,
                                              dataBounds: bounds, generatesFromDomain: true)
        assert(hTicks.allSatisfy { $0 >= 50 && $0 <= 100 } && hTicks.last == 100,
               "窗口生成应落在域内且含右缘，got \(hTicks)")

        // 6) 刻度文本：formatter 优先，否则内置格式
        assert(AxisRenderer.tickText(80, formatter: nil) == "80", "默认文本应为去尾零格式")
        assert(AxisRenderer.tickText(80, formatter: { "\(Int($0))%" }) == "80%", "formatter 应生效")

        // 7) 渲染级：labelFormatter 接入左侧刻度（80 → "80%"）
        do {
            let r = ColumnChartRenderer()
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
            r.mount(into: host)
            var y = CartesianAxisModel(kind: .value)
            y.labelFormatter = { "\(Int($0))℃" }
            r.render(model: CartesianChartModel(
                series: [CartesianSeriesElement(name: "s", data: [20, 60])],
                yAxis: y),
                     theme: CartesianChartTheme(),
                     context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
            let texts = host.subviews.compactMap { ($0 as? UILabel)?.text }
            assert(texts.contains("60℃"),
                   "左侧刻度应使用 formatter 文本，got \(texts)")
        }
    }

    /// 条形图（水平图）轴系渲染契约：
    /// viewport 域交换（X=值域、Y=类目域）、底部数值刻度、左侧类目标签、
    /// 网格方向对调、X 数值轴缩放时刻度跟随窗口。
    static func runHorizontalAxisSelfTest() {
        // —— 纯函数：底部数值刻度 / 左侧类目标签 / 水平网格 ——
        let hVP = CartesianViewport(xMin: 0, xMax: 100, yMin: -0.5, yMax: 3.5)
        let hPlot = CGRect(x: 50, y: 20, width: 250, height: 160)
        let hTicks: [Double] = [0, 20, 40, 60, 80, 100]

        let bottomTicks = AxisRenderer.makeBottomValueTickLabels(
            ticks: hTicks, viewport: hVP, plotFrame: hPlot, theme: CartesianChartTheme())
        assert(bottomTicks.count == 6, "底部数值刻度应有 6 个，got \(bottomTicks.count)")
        for (i, lbl) in bottomTicks.enumerated() {
            let cx = CartesianGeometry.point(x: hTicks[i], y: 0, viewport: hVP, plotFrame: hPlot).x
            assert(abs(lbl.center.x - cx) < 0.001,
                   "底部刻度 \(hTicks[i]) 应对齐值位置 \(cx)，got \(lbl.center.x)")
            assert(lbl.center.y > hPlot.maxY, "底部刻度应在 plot 下方，got \(lbl.center.y)")
        }

        let leftCats = AxisRenderer.makeLeftCategoryLabels(
            labels: ["A", "B", "C", "D"], viewport: hVP, plotFrame: hPlot, theme: CartesianChartTheme())
        assert(leftCats.count == 4, "左侧类目标签应有 4 个，got \(leftCats.count)")
        for (i, lbl) in leftCats.enumerated() {
            // 类目 0 在顶部（自上而下映射，与 barRect 同向）
            let cy = CartesianGeometry.horizontalCategoryY(category: Double(i),
                                                           viewport: hVP, plotFrame: hPlot)
            assert(abs(lbl.center.y - cy) < 0.001,
                   "左侧类目 \(i) 应对齐类目中心 y=\(cy)，got \(lbl.center.y)")
            assert(lbl.frame.maxX <= hPlot.minX + 0.001,
                   "左侧类目标签右缘不得侵入 plot，got \(lbl.frame.maxX) vs \(hPlot.minX)")
        }
        assert(leftCats[0].center.y < leftCats[1].center.y
               && leftCats[0].center.y < hPlot.midY
               && leftCats[3].center.y > hPlot.midY,
               "类目 0 应在最顶部（首行在上半区、末行在下半区），got \(leftCats.map { $0.center.y })")

        // 显式开启两种网格线（默认主题竖线为关），验证方向映射本身
        var hGridTheme = CartesianChartTheme()
        hGridTheme.showsVerticalGridlines = true
        hGridTheme.showsHorizontalGridlines = true
        let hGrid = GridRenderer.makeGridLayer(
            valueTicks: hTicks, categoryCount: 4, viewport: hVP,
            plotFrame: hPlot, theme: hGridTheme, isHorizontalValueAxis: true)
        var hGridMoves = 0
        hGrid.path?.applyWithBlock { elem in
            if elem.pointee.type == .moveToPoint { hGridMoves += 1 }
        }
        // 竖线 6 条（值刻度）+ 横线 4 条（类目；槽高 40 > 最小间距，无抽稀）
        assert(hGridMoves == 10, "水平网格应有 6 竖(值刻度) + 4 横(类目) = 10 条线，got \(hGridMoves)")

        // —— 渲染级：BarChartRenderer 端到端 ——
        let barRenderer = BarChartRenderer()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        barRenderer.mount(into: host)
        barRenderer.render(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "s", data: [20, 40, 60, 80])]),
            theme: CartesianChartTheme(),
            context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        let plot = barRenderer.currentPlotFrame
        let vp = barRenderer.currentViewport

        // 1) viewport 域交换：X = 值域（[20...80] → nice 0...80 步长 20），Y = 类目域 -0.5...3.5
        assert(abs(vp.xMin) < 0.001 && abs(vp.xMax - 80) < 0.001,
               "水平图 X 域应为值域 0...80，got \(vp.xDomain)")
        assert(abs(vp.yMin - (-0.5)) < 0.001 && abs(vp.yMax - 3.5) < 0.001,
               "水平图 Y 域应为类目域 -0.5...3.5，got \(vp.yDomain)")

        // 2) 底部 = 数值刻度："80" 对齐 plot 右缘、位于底缘下方
        let labels = host.subviews.compactMap { $0 as? UILabel }
        guard let tickMax = labels.first(where: { $0.text == "80" && $0.center.y > plot.maxY }) else {
            assertionFailure("底部应有数值刻度 80，got \(labels.map { ($0.text ?? "") + "@(\($0.center.x), \($0.center.y))" })")
            return
        }
        assert(abs(tickMax.center.x - plot.maxX) < 1.0,
               "刻度 80 应对齐 plot 右缘 \(plot.maxX)，got \(tickMax.center.x)")

        // 3) 左侧 = 类目标签："1"（类目 0）贴左缘、垂直对齐首行类目中心（顶部）
        guard let cat1 = labels.first(where: { $0.text == "1" }) else {
            assertionFailure("左侧应有类目标签 1，got \(labels.map { $0.text ?? "" })")
            return
        }
        assert(cat1.center.x < plot.minX,
               "类目标签应在 plot 左侧，got \(cat1.center.x) vs \(plot.minX)")
        let slotHeight = plot.height / 4
        assert(abs(cat1.center.y - (plot.minY + 0.5 * slotHeight)) < 1.0,
               "类目 1 应对齐首行类目中心，got \(cat1.center.y)")

        // 3.5) 命中对齐：点击首行条形中部（类目 0、值 20 → 零轴到 plot 中点间）
        let tapY = CartesianGeometry.horizontalCategoryY(category: 0,
                                                         viewport: barRenderer.currentViewport,
                                                         plotFrame: plot)
        let tapX = plot.minX + plot.width * 0.125   // 值 20 在 0...80 域的 1/4 处，条形中段
        if let hit = barRenderer.hitTest(CGPoint(x: tapX, y: tapY)) as? BarHitTarget {
            assert(hit.categoryIndex == 0 && hit.seriesIndex == 0,
                   "点击首行条形应命中类目 0，got cat=\(hit.categoryIndex) series=\(hit.seriesIndex)")
            assert(abs(hit.value - 20) < 0.001, "命中值应为 20，got \(hit.value)")
        } else {
            assertionFailure("点击首行条形中部应命中 (\(tapX), \(tapY))")
        }

        // 4) X 数值轴缩放：窗口减半（右缘锚定 → 40...80），刻度跟随窗口、类目域恒定
        barRenderer.zoomXAxis(factor: 2, anchorScreenX: plot.maxX)
        assert(abs(barRenderer.currentViewport.xMin - 40) < 0.001
               && abs(barRenderer.currentViewport.xMax - 80) < 0.001,
               "捏合后值域窗口应为 40...80，got \(barRenderer.currentViewport.xDomain)")
        assert(abs(barRenderer.currentViewport.yMin - (-0.5)) < 0.001,
               "类目域不应随手势变化，got \(barRenderer.currentViewport.yDomain)")
        assert(barRenderer.currentValueTicks.allSatisfy { $0 >= 40 - 1e-9 && $0 <= 80 + 1e-9 },
               "缩放后数值刻度须落在生效窗口内，got \(barRenderer.currentValueTicks)")
        assert(barRenderer.currentValueTicks.contains(80),
               "右缘刻度 80 应保留，got \(barRenderer.currentValueTicks)")
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
