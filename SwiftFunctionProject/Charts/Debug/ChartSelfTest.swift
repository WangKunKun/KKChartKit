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
        assert(abs(hmRange.lowerBound - 10) < 0.001 && abs(hmRange.upperBound - 50) < 0.001,
               "resolved range 10...50, got \(hmRange)")

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
