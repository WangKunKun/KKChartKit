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
        // 注意：不用 `==` 比较 UIColor（受 colorspace/精度影响不可靠），一律比组件值
        let black = UIColor.black, white = UIColor.white
        let at0 = HYMColorInterpolation.lerp(black, white, 0)
        var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
        at0.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
        assert(abs(r0) < 0.001 && abs(g0) < 0.001 && abs(b0) < 0.001 && abs(a0 - 1) < 0.001, "lerp t=0 wrong")
        let mid = HYMColorInterpolation.lerp(black, white, 0.5)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        mid.getRed(&r, green: &g, blue: &b, alpha: &a)
        assert(abs(r - 0.5) < 0.01 && abs(g - 0.5) < 0.01 && abs(b - 0.5) < 0.01, "lerp mid wrong")

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

        // —— hitTest / applySelection 基本行为（render 后）——
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

        print("✅ ChartSelfTest passed")
    }
}
#endif
