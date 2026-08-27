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

        print("✅ ChartSelfTest passed")
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
