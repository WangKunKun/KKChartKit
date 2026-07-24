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
