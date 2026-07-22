import UIKit

/// 颜色插值工具（纯函数，便于 DEBUG 自检）
public enum HYMColorInterpolation {
    /// 在 a→b 间按 t 线性插值（t=0 为 a，t=1 为 b；t 越界裁剪到 [0,1]）
    public static func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = max(0, min(1, t))
        return UIColor(red: ar + (br - ar) * k,
                       green: ag + (bg - ag) * k,
                       blue: ab + (bb - ab) * k,
                       alpha: aa + (ba - aa) * k)
    }
}
