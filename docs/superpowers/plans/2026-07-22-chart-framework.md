# HYMCharts 通用图表框架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有雷达图重构为通用图表框架 `HYMCharts` 的首个实现——抽取纯 Swift 的 Protocol-First 内核（容器/渲染器/主题/数据/动画/几何/错误/交互），雷达图落地为 `RadarChartRenderer`，并提供 OC Wrapper 与 SwiftUI 封装。

**Architecture:** 方案 A（Protocol-First 组合）：`HYMChartView<Renderer>` 通用容器注入 `HYMChartRenderer`；内核纯 Swift（struct/enum/泛型/associatedtype），OC 兼容走独立 `OCBridge/`，SwiftUI 走 `UIViewRepresentable`。渲染基于 UIKit + QuartzCore（CALayer）。

**Tech Stack:** Swift 5、UIKit、QuartzCore（CALayer）、CoreGraphics、SwiftUI（Representable）。

---

## 关键工程前提（执行前必读）

1. **文件系统同步组**（`PBXFileSystemSynchronizedRootGroup`, objectVersion 77）：把新文件放到 `SwiftFunctionProject/` 下对应目录，Xcode 自动加入 target 编译，**无需改 `project.pbxproj`**。
2. **不提交 git**（项目约定）：每个 Task 末尾的「验证检查点」只做编译/运行验证，不执行 `git commit`。
3. **无 test target**（新建需改 pbxproj，高风险）：可单测的纯逻辑（几何/分数/颜色插值/命中）抽为纯函数，用 `#if DEBUG` 断言自检（`ChartSelfTest`，App 启动跑一次）；UI 靠模拟器运行目视。
4. **编译验证命令**（中文路径用引号；贯穿所有 Task）：

   ```bash
   cd "/Users/hoymiles/Desktop/移植项目/SwiftFunctionProject"
   xcodebuild -project "SwiftFunctionProject.xcodeproj" -scheme "SwiftFunctionProject" \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
     -configuration Debug build 2>&1 | tail -30
   ```

   预期结尾出现 `** BUILD SUCCEEDED **`。若 scheme 名实际不同，改用 `-scheme <实际名>` 或 `-target SwiftFunctionProject`。
5. **目录改名**：新代码全部放新建的 `SwiftFunctionProject/Charts/` 树；旧 `SwiftFunctionProject/图表/蛛网图/` 在 Task 10 最后删除。
6. **SourceKit 假阳性**（`No such module 'UIKit'` 等可能误报）：以 `xcodebuild` 的 `** BUILD SUCCEEDED **` 为唯一权威，别为假阳性改代码。

---

## File Structure

| 文件 | 职责 | 创建 Task |
|---|---|---|
| `Charts/Core/HYMChartError.swift` | 统一错误模型 | Task 1 |
| `Charts/Core/HYMColorInterpolation.swift` | 颜色插值纯函数（lerpColor 上提复用） | Task 1 |
| `Charts/Core/HYMChartModel.swift` | 数据模型 marker 协议 | Task 1 |
| `Charts/Core/HYMChartTheme.swift` | 主题 marker 协议 | Task 1 |
| `Charts/Core/HYMChartInteraction.swift` | `HYMChartGesture` / `HYMChartHitTarget` | Task 1 |
| `Charts/Core/HYMChartRenderer.swift` | 渲染器协议 + `HYMChartRenderContext` + 默认实现 | Task 2 |
| `Charts/Core/HYMChartAnimation.swift` | `HYMChartValueAnimator`（DisplayLink 数值动画器） | Task 3 |
| `Charts/Core/HYMChartView.swift` | 通用泛型容器 UIView | Task 4 |
| `Charts/Radar/RadarGeometry.swift` | 极坐标几何纯函数 | Task 5 |
| `Charts/Radar/RadarChartModel.swift` | `RadarDimension`/`RadarChartModel` struct + `resolvedCenterScore` | Task 5 |
| `Charts/Radar/RadarChartTheme.swift` | `RadarChartTheme` struct + `GridRingFill` enum | Task 5 |
| `Charts/Radar/RadarChartRenderer.swift` | 实现 `HYMChartRenderer`，承载全部 layer 重建 | Task 6 |
| `Charts/Debug/ChartSelfTest.swift` | DEBUG 框架级断言自检 | Task 7 |
| `Charts/SwiftUI/RadarChart.swift` | `RadarChart` View（Representable） | Task 8 |
| `SwiftFunctionProject/ContentView.swift`（改） | demo：嵌入 `RadarChart` + 跑自检 | Task 8 |
| `Charts/OCBridge/HYMRadarDimensionBridge.swift` | OC 维度桥接 | Task 9 |
| `Charts/OCBridge/HYMRadarThemeBuilder.swift` | OC 主题构造器（属性→struct） | Task 9 |
| `Charts/OCBridge/HYMRadarChartViewBridge.swift` | OC 视图桥接（持内部泛型实例） | Task 9 |

---

## Task 1: Core 基础协议与工具

**Why:** 内核地基——错误模型、颜色插值纯函数、Model/Theme marker 协议、交互类型。全部无 UI 依赖或最小依赖，先落地编译。

**Files:**
- Create: `SwiftFunctionProject/Charts/Core/HYMChartError.swift`
- Create: `SwiftFunctionProject/Charts/Core/HYMColorInterpolation.swift`
- Create: `SwiftFunctionProject/Charts/Core/HYMChartModel.swift`
- Create: `SwiftFunctionProject/Charts/Core/HYMChartTheme.swift`
- Create: `SwiftFunctionProject/Charts/Core/HYMChartInteraction.swift`

- [ ] **Step 1: HYMChartError.swift**

```swift
import Foundation

/// 图表框架统一错误模型
public enum HYMChartError: Error {
    /// 维度数据为空
    case emptyDimensions
    /// 数据非法（如 maxValue <= 0）
    case invalidData(String)
    /// 主题缺少必要配置
    case invalidTheme(String)
}
```

- [ ] **Step 2: HYMColorInterpolation.swift**

```swift
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
```

- [ ] **Step 3: HYMChartModel.swift**

```swift
import Foundation

/// 图表数据模型契约（marker；具体图表各自扩展字段）
public protocol HYMChartModel {}
```

- [ ] **Step 4: HYMChartTheme.swift**

```swift
import Foundation

/// 图表主题契约（marker；具体图表各自扩展字段）
public protocol HYMChartTheme {}
```

- [ ] **Step 5: HYMChartInteraction.swift**

```swift
import Foundation
import CoreGraphics

/// 交互手势类型（预留扩展）
public enum HYMChartGesture {
    case tap
    // 预留扩展：longPress 等
}

/// 图表中一个可命中的语义单元（关联数据，非绘图细节）
public protocol HYMChartHitTarget {
    /// 业务标识，如 "进攻"
    var identifier: String { get }
    /// 序号
    var index: Int { get }
}
```

- [ ] **Step 6: 编译验证**

Run the build command from「关键工程前提 #4」。
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 7: 验证检查点**

✅ Core 基础协议与工具落地，无 OC 痕迹。无需 git 提交。

---

## Task 2: HYMChartRenderer 协议

**Why:** 框架核心契约——Renderer 负责绘制，是容器与具体图表的接口。交互能力作为 requirement（保证子类 override 走 witness table 动态派发）。

**Files:**
- Create: `SwiftFunctionProject/Charts/Core/HYMChartRenderer.swift`

- [ ] **Step 1: HYMChartRenderer.swift**

```swift
import UIKit

/// 渲染上下文（容器在 layoutSubviews 时提供给 Renderer）
public struct HYMChartRenderContext {
    public let bounds: CGRect
    public let center: CGPoint
    public init(bounds: CGRect, center: CGPoint) {
        self.bounds = bounds
        self.center = center
    }
}

/// 图表渲染器契约：给定 model/theme/context，重建 layer 子树与子视图。
/// 具体图表（如 RadarChartRenderer）实现此协议；通用容器 HYMChartView 注入使用。
public protocol HYMChartRenderer: AnyObject {
    /// 无参构造（供泛型容器 `Renderer()` 实例化）
    init()

    associatedtype Model: HYMChartModel
    associatedtype Theme: HYMChartTheme

    /// 挂载渲染内容（layer 子树 + 子视图）到容器；容器 init 后调一次
    func mount(into view: UIView)
    /// 卸载渲染内容（容器销毁前调）
    func unmount(from view: UIView)
    /// 重建全部 layer 子树 + 子视图（数据/主题/布局变化时由容器调用）
    func render(model: Model, theme: Theme, context: HYMChartRenderContext)

    /// 参加入场动画的 layer（容器统一驱动 scale + opacity）
    var animatableLayers: [CALayer] { get }

    /// 入场动画每帧回调（容器驱动 DisplayLink，传归一化且已 ease 的进度 0...1）。
    /// Renderer 据此更新自身需要数值滚动的子视图（如中心分数 label）。
    func updateEntranceAnimation(progress: Double)

    // —— 交互能力（声明为 requirement，保证 override 走 witness table 可靠动态派发）——
    /// 命中测试：坐标 → 语义目标；默认 nil
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget?
    /// 选中态视觉反馈（预留）；默认空
    func applySelection(_ target: HYMChartHitTarget?)
    /// 数值动画目标（如中心分数）；默认 nil
    var centerScoreTarget: Double? { get }
}

/// 默认实现：可交互为可选；不关心的图表无需实现这些方法
public extension HYMChartRenderer {
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }
    func applySelection(_ target: HYMChartHitTarget?) {}
    var centerScoreTarget: Double? { nil }
    func updateEntranceAnimation(progress: Double) {}
}
```

- [ ] **Step 2: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 验证检查点**

✅ Renderer 协议落地，交互 requirement + 默认实现就位。无需 git 提交。

---

## Task 3: HYMChartValueAnimator 数值动画器

**Why:** 把「DisplayLink 驱动数值从 0→1 easeOut」封装成可复用动画器，供容器驱动分数滚动等数值动画；统一 invalidate 时机防泄漏。

**Files:**
- Create: `SwiftFunctionProject/Charts/Core/HYMChartAnimation.swift`

- [ ] **Step 1: HYMChartAnimation.swift**

```swift
import QuartzCore

/// 数值插值动画器（DisplayLink 驱动）。
/// 注意：CADisplayLink 强引用其 target（即本实例）；本实例持有 displayLink，
/// 形成 displayLink ↔ animator 循环，必须由调用方在 deinit / 重入时调 `stop()` 打破。
public final class HYMChartValueAnimator {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0
    private var handler: ((Double) -> Void)?
    private var completion: (() -> Void)?

    public init() {}

    /// 启动一次 0→1 的 easeOut 动画。
    /// - Parameters:
    ///   - duration: 时长（秒）
    ///   - handler: 每帧回调已 ease 的归一化进度 0...1
    ///   - completion: 结束回调（在 handler 最后一次之后）
    public func startEaseOut(duration: CFTimeInterval,
                             handler: @escaping (Double) -> Void,
                             completion: @escaping () -> Void) {
        stop()
        self.duration = max(0.0001, duration)
        self.handler = handler
        self.completion = completion
        self.startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, action: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let t = max(0, min(1, elapsed / duration))
        let eased = 1 - (1 - t) * (1 - t)   // easeOut
        handler?(eased)
        if t >= 1 {
            let cb = completion
            stop()
            cb?()
        }
    }

    /// 停止并释放 DisplayLink（打破循环引用）
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        handler = nil
        completion = nil
    }
}
```

- [ ] **Step 2: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 验证检查点**

✅ 数值动画器落地，DisplayLink 生命周期由 `stop()` 管理。无需 git 提交。

---

## Task 4: HYMChartView 通用容器

**Why:** 框架中枢——持有 Renderer，负责布局分发、入场动画（layer scale/opacity + 数值滚动）、触摸命中分发、DisplayLink 生命周期、layer 防泄漏。这是把「容器/绘制/动画」解耦的关键。

**Files:**
- Create: `SwiftFunctionProject/Charts/Core/HYMChartView.swift`

- [ ] **Step 1: HYMChartView.swift**

```swift
import UIKit

/// 通用图表容器（泛型）：持有 Renderer，负责布局分发、入场动画、触摸命中分发、
/// DisplayLink 生命周期与 layer 防泄漏。绘制细节全部在 Renderer。
///
/// Swift 用法：
/// ```
/// let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
/// chart.configure(model: m, theme: t)
/// chart.playEntranceAnimation()
/// chart.onHit = { target, gesture in ... }
/// ```
public final class HYMChartView<Renderer: HYMChartRenderer>: UIView {

    // MARK: - 状态
    private var model: Renderer.Model?
    private var theme: Renderer.Theme?
    private var pendingAnimation = false
    private let animator = HYMChartValueAnimator()

    /// 命中交互单元时回调（带手势类型，为扩展留位）
    public var onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    // MARK: - Renderer
    private let renderer: Renderer

    // MARK: - init
    public override init(frame: CGRect) {
        self.renderer = Renderer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        // 泛型 UIView 不支持从 Xib/Storyboard 初始化（本项目纯代码 + SwiftUI，不会触发）
        fatalError("HYMChartView 不支持 init?(coder:)，请用 init(frame:)")
    }

    private func commonInit() {
        backgroundColor = .clear
        // 不裁剪 self：标签需画在卡片（gradientLayer）外侧
        clipsToBounds = false
        isUserInteractionEnabled = true
        renderer.mount(into: self)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
    }

    // MARK: - 公开 API
    /// 配置并刷新（model + theme 一起传入）
    public func configure(model: Renderer.Model, theme: Renderer.Theme) {
        self.model = model
        self.theme = theme
        setNeedsLayout()
    }

    /// 播放入场动画（幂等，可重复调用）
    public func playEntranceAnimation() {
        guard model != nil, theme != nil else { return }
        pendingAnimation = true
        setNeedsLayout()   // 触发 layoutSubviews → performEntranceAnimation
    }

    // MARK: - 布局
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let model, let theme else { return }
        renderer.render(model: model, theme: theme,
                        context: HYMChartRenderContext(
                            bounds: bounds,
                            center: CGPoint(x: bounds.midX, y: bounds.midY)))
        if pendingAnimation {
            pendingAnimation = false
            performEntranceAnimation()
        }
    }

    // MARK: - 入场动画
    private func performEntranceAnimation() {
        animator.stop()
        let animatable = renderer.animatableLayers
        let duration: CFTimeInterval = 0.6

        // 第 1 步：无动画设「初始态」——scale 极小 + 透明。
        // 关键：必须在 identity transform 下，frame 由 Renderer.render 已设为 bounds（锚点居中）；
        // 非 identity 下设 frame 属未定义行为（CALayer 文档）。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let tiny = CGAffineTransform.identity.scaledBy(x: 0.01, y: 0.01)
        for l in animatable {
            l.setAffineTransform(tiny)
            l.opacity = 0
        }
        renderer.updateEntranceAnimation(progress: 0)
        CATransaction.commit()

        // 第 2 步：隐式动画过渡到「终态」——scale identity + 不透明
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        for l in animatable {
            l.setAffineTransform(.identity)
            l.opacity = 1
        }
        CATransaction.commit()

        // 第 3 步：数值滚动（如中心分数），DisplayLink 驱动
        if renderer.centerScoreTarget != nil {
            animator.startEaseOut(duration: 0.8,
                handler: { [weak self] progress in
                    self?.renderer.updateEntranceAnimation(progress: progress)
                },
                completion: { })
        }
    }

    // MARK: - 触摸命中
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        if let target = renderer.hitTest(p) {
            onHit?(target, .tap)
        }
    }

    deinit {
        animator.stop()              // 打破 displayLink ↔ animator 循环
        renderer.unmount(from: self) // 清理 layer/子视图
    }
}
```

- [ ] **Step 2: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。
（运行验证留到 Task 8 接入具体 Renderer 后；此 Task 仅保证容器编译通过。）

- [ ] **Step 3: 验证检查点**

✅ 通用容器落地，布局/动画/命中/DisplayLink 生命周期/layer 清理职责齐备。无需 git 提交。

---

## Task 5: Radar 纯 Swift 数据层（Geometry / Model / Theme）

**Why:** 先落地纯值类型数据与几何（无 UI 依赖，最易自检），供 Renderer 与 demo 使用。`RadarGeometry` 从旧文件原样搬入。

**Files:**
- Create: `SwiftFunctionProject/Charts/Radar/RadarGeometry.swift`
- Create: `SwiftFunctionProject/Charts/Radar/RadarChartModel.swift`
- Create: `SwiftFunctionProject/Charts/Radar/RadarChartTheme.swift`

- [ ] **Step 1: RadarGeometry.swift**

```swift
import CoreGraphics

/// 极坐标几何纯函数（便于 DEBUG 自检）
public enum RadarGeometry {
    /// 第 i 个顶点角度（弧度），i=0 朝正上方（-π/2）
    public static func angle(index i: Int, count n: Int) -> CGFloat {
        guard n > 0 else { return 0 }
        return -CGFloat.pi / 2 + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
    }

    /// 第 i 个数据顶点坐标（ratio 为归一化比值 0~1，越界裁剪）
    public static func point(
        index i: Int, count n: Int,
        center: CGPoint, radius: CGFloat, ratio: CGFloat
    ) -> CGPoint {
        let a = angle(index: i, count: n)
        let r = radius * max(0, min(1, ratio))
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    /// 第 k 圈（k = 0 ..< ringCount）的网格多边形顶点数组
    public static func ringPoints(
        count n: Int, center: CGPoint, radius: CGFloat,
        ringIndex k: Int, ringCount: Int
    ) -> [CGPoint] {
        guard ringCount > 0 else { return [] }
        let ratio = CGFloat(k + 1) / CGFloat(ringCount)
        return (0..<n).map { point(index: $0, count: n, center: center, radius: radius, ratio: ratio) }
    }
}
```

- [ ] **Step 2: RadarChartModel.swift**

```swift
import Foundation
import CoreGraphics

/// 单个维度（纯值类型）
public struct RadarDimension {
    /// 顶点文案，如「进攻」
    public var label: String
    /// 当前值
    public var value: Double
    /// 满分值（用于归一化），默认 100
    public var maxValue: Double

    public init(label: String, value: Double, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    /// 归一化比值 [0,1]，越界裁剪（内部使用）
    public var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }
}

/// 雷达图数据（theme 分离，由 configure(model:theme:) 单独传入）
public struct RadarChartModel: HYMChartModel {
    public var dimensions: [RadarDimension]
    public var showsCenterScore: Bool
    /// nil = 自动按各维度归一化均值算；非 nil = 用传入值
    public var centerScore: Double?

    public init(dimensions: [RadarDimension],
                showsCenterScore: Bool = true,
                centerScore: Double? = nil) {
        self.dimensions = dimensions
        self.showsCenterScore = showsCenterScore
        self.centerScore = centerScore
    }
}

/// 中心分数三态解析（纯函数，便于 DEBUG 自检）
public func resolvedCenterScore(_ model: RadarChartModel) -> Double? {
    guard model.showsCenterScore else { return nil }
    if let manual = model.centerScore { return manual }
    guard !model.dimensions.isEmpty else { return nil }
    let sum = model.dimensions.reduce(0.0) { $0 + ($1.maxValue > 0 ? $1.value / $1.maxValue : 0) }
    let avg = sum / Double(model.dimensions.count)
    let scale = model.dimensions.first?.maxValue ?? 100
    return avg * scale
}
```

- [ ] **Step 3: RadarChartTheme.swift**

```swift
import UIKit

/// 网格每圈底色模式
public enum GridRingFill {
    /// 不填充（默认）
    case none
    /// 从最外圈(from)到最内圈(to)线性插值
    case gradient(from: UIColor, to: UIColor)
    /// 每圈独立色；数组长度 < gridRingCount 时，超出圈回退为最后一色
    case colors([UIColor])
}

/// 雷达图主题（纯值类型；所有外观集中于此，改色只动这里）
public struct RadarChartTheme: HYMChartTheme {
    public var backgroundGradientStart: UIColor
    public var backgroundGradientEnd:   UIColor
    public var gridColor:   UIColor
    public var axisColor:   UIColor
    public var dataFillColor:   UIColor
    public var dataStrokeColor: UIColor
    public var vertexDotColor:     UIColor
    public var vertexDotRingColor: UIColor
    public var labelColor: UIColor
    public var labelFont:  UIFont
    public var scoreColor: UIColor
    public var scoreFont:  UIFont
    public var scoreSubtitleColor: UIColor
    public var scoreSubtitleFont:  UIFont
    public var scoreSubtitleText:  String
    public var gridRingCount: Int
    public var cardCornerRadius: CGFloat
    public var dataLineWidth: CGFloat
    public var labelOuterPadding: CGFloat
    public var vertexDotRadius: CGFloat
    public var gridRingFill: GridRingFill
    public var showsGridLines: Bool
    public var showsAxes: Bool
    public var showsData: Bool
    public var showsBackground: Bool

    public init(
        backgroundGradientStart: UIColor = UIColor(red: 0x2A/255.0, green: 0x1B/255.0, blue: 0x5C/255.0, alpha: 1),
        backgroundGradientEnd:   UIColor = UIColor(red: 0x4B/255.0, green: 0x2E/255.0, blue: 0xAA/255.0, alpha: 1),
        gridColor:   UIColor = UIColor.white.withAlphaComponent(0.15),
        axisColor:   UIColor = UIColor.white.withAlphaComponent(0.25),
        dataFillColor:   UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 0.35),
        dataStrokeColor: UIColor = UIColor(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0, alpha: 1),
        vertexDotColor:     UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 1),
        vertexDotRingColor: UIColor = .white,
        labelColor: UIColor = UIColor(red: 0xE0/255.0, green: 0xE7/255.0, blue: 0xFF/255.0, alpha: 1),
        labelFont:  UIFont = .systemFont(ofSize: 14),
        scoreColor: UIColor = .white,
        scoreFont:  UIFont = .boldSystemFont(ofSize: 36),
        scoreSubtitleColor: UIColor = UIColor(red: 0xC7/255.0, green: 0xD2/255.0, blue: 0xFE/255.0, alpha: 1),
        scoreSubtitleFont:  UIFont = .systemFont(ofSize: 13),
        scoreSubtitleText:  String = "综合评分",
        gridRingCount: Int = 5,
        cardCornerRadius: CGFloat = 16,
        dataLineWidth: CGFloat = 2,
        labelOuterPadding: CGFloat = 22,
        vertexDotRadius: CGFloat = 5,
        gridRingFill: GridRingFill = .none,
        showsGridLines: Bool = true,
        showsAxes: Bool = true,
        showsData: Bool = true,
        showsBackground: Bool = true
    ) {
        self.backgroundGradientStart = backgroundGradientStart
        self.backgroundGradientEnd = backgroundGradientEnd
        self.gridColor = gridColor
        self.axisColor = axisColor
        self.dataFillColor = dataFillColor
        self.dataStrokeColor = dataStrokeColor
        self.vertexDotColor = vertexDotColor
        self.vertexDotRingColor = vertexDotRingColor
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.scoreColor = scoreColor
        self.scoreFont = scoreFont
        self.scoreSubtitleColor = scoreSubtitleColor
        self.scoreSubtitleFont = scoreSubtitleFont
        self.scoreSubtitleText = scoreSubtitleText
        self.gridRingCount = gridRingCount
        self.cardCornerRadius = cardCornerRadius
        self.dataLineWidth = dataLineWidth
        self.labelOuterPadding = labelOuterPadding
        self.vertexDotRadius = vertexDotRadius
        self.gridRingFill = gridRingFill
        self.showsGridLines = showsGridLines
        self.showsAxes = showsAxes
        self.showsData = showsData
        self.showsBackground = showsBackground
    }
}
```

- [ ] **Step 4: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: 验证检查点**

✅ 雷达数据层纯 Swift 化落地（struct + Double?，无 NSObject/@objc），theme 已分离。无需 git 提交。

---

## Task 6: RadarChartRenderer（核心，迁移全部 layer 重建）

**Why:** 把旧 `HYMRadarChartView` 的全部 `rebuildXxx` + `applyThemeColors` 迁入 Renderer，实现 `HYMChartRenderer`。这是把雷达图变成「框架下一等公民」的核心。`hitTest` 本期用默认 nil（无交互）。

**Files:**
- Create: `SwiftFunctionProject/Charts/Radar/RadarChartRenderer.swift`

- [ ] **Step 1: RadarChartRenderer.swift**

```swift
import UIKit

/// 雷达图渲染器：实现 HYMChartRenderer，承载全部 layer 重建 / 标签 / 主题配色 / 数值动画。
/// 本期 hitTest 保持协议默认 nil（无交互命中），后续 override 增加命中目标。
public final class RadarChartRenderer: HYMChartRenderer {
    public typealias Model = RadarChartModel
    public typealias Theme = RadarChartTheme

    public init() {}

    // MARK: - 私有 layer 子树
    private let gradientLayer = CAGradientLayer()
    private let gridFillContainerLayer = CALayer()   // 网格每圈底色容器
    private let gridLayer = CAShapeLayer()
    private let axisLayer = CAShapeLayer()
    private let dataFillLayer = CAShapeLayer()
    private let dataStrokeLayer = CAShapeLayer()
    private let vertexDotsLayer = CAShapeLayer()

    // MARK: - 私有子视图
    private weak var hostView: UIView?
    private var labels: [UILabel] = []
    private let scoreLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - 当前状态（render 时存，供动画/命中读取）
    private var currentModel: RadarChartModel?
    private var currentTheme: RadarChartTheme?
    private var lastCenter = CGPoint.zero

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.masksToBounds = true
        view.layer.addSublayer(gradientLayer)
        view.layer.addSublayer(gridFillContainerLayer)

        gridLayer.fillColor = UIColor.clear.cgColor
        axisLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(gridLayer)
        view.layer.addSublayer(axisLayer)

        dataFillLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        vertexDotsLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dataFillLayer)
        view.layer.addSublayer(dataStrokeLayer)
        view.layer.addSublayer(vertexDotsLayer)

        scoreLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        subtitleLabel.numberOfLines = 1
        view.addSubview(subtitleLabel)
        view.addSubview(scoreLabel)
    }

    public func unmount(from view: UIView) {
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()
        [gradientLayer, gridFillContainerLayer, gridLayer, axisLayer,
         dataFillLayer, dataStrokeLayer, vertexDotsLayer].forEach { $0.removeFromSuperlayer() }
        scoreLabel.removeFromSuperview()
        subtitleLabel.removeFromSuperview()
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] {
        [dataFillLayer, dataStrokeLayer, vertexDotsLayer, gridLayer, axisLayer, gridFillContainerLayer]
    }

    public var centerScoreTarget: Double? {
        guard let m = currentModel else { return nil }
        return resolvedCenterScore(m)
    }

    public func updateEntranceAnimation(progress: Double) {
        guard let theme = currentTheme else { return }
        let target = centerScoreTarget ?? 0
        let value = target * progress
        scoreLabel.text = formatScore(value)
        scoreLabel.font = theme.scoreFont
        scoreLabel.textColor = theme.scoreColor
        scoreLabel.sizeToFit()
        scoreLabel.center = CGPoint(x: lastCenter.x, y: lastCenter.y + 18)
        scoreLabel.alpha = CGFloat(min(1, progress * 1.5))   // 前段淡入
    }

    // MARK: - render
    public func render(model: RadarChartModel, theme: RadarChartTheme, context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastCenter = context.center

        applyThemeColors(theme)

        let pad = theme.labelOuterPadding
        gradientLayer.frame = context.bounds.insetBy(dx: pad, dy: pad)
        gradientLayer.cornerRadius = theme.cardCornerRadius

        guard !model.dimensions.isEmpty else {
            gridLayer.path = nil
            axisLayer.path = nil
            dataFillLayer.path = nil
            dataStrokeLayer.path = nil
            vertexDotsLayer.path = nil
            scoreLabel.isHidden = true
            subtitleLabel.isHidden = true
            return
        }

        let center = context.center
        let radius = maxRadius(bounds: context.bounds)

        rebuildGridFill(model, center: center, radius: radius)
        rebuildGrid(model, center: center, radius: radius)
        rebuildAxis(model, center: center, radius: radius)
        rebuildData(model, center: center, radius: radius)
        rebuildVertexDots(model, center: center, radius: radius)
        rebuildLabels(model, center: center, radius: radius)
        rebuildScore(model, center: center)

        // animatable layer 的 frame = bounds（identity transform 下），保证容器 scale 动画锚点居中
        for l in animatableLayers { l.frame = context.bounds }
    }

    // MARK: - 主题配色
    private func applyThemeColors(_ theme: RadarChartTheme) {
        gradientLayer.colors = [theme.backgroundGradientStart.cgColor,
                                theme.backgroundGradientEnd.cgColor]
        gridLayer.strokeColor = theme.gridColor.cgColor
        gridLayer.lineWidth = 1
        axisLayer.strokeColor = theme.axisColor.cgColor
        axisLayer.lineWidth = 1

        dataFillLayer.fillColor = theme.dataFillColor.cgColor
        dataFillLayer.strokeColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.strokeColor = theme.dataStrokeColor.cgColor
        dataStrokeLayer.lineWidth = theme.dataLineWidth
        vertexDotsLayer.fillColor = theme.vertexDotColor.cgColor
        vertexDotsLayer.strokeColor = theme.vertexDotRingColor.cgColor
        vertexDotsLayer.lineWidth = 2

        // 显隐开关（彼此正交）
        gridLayer.isHidden = !theme.showsGridLines
        axisLayer.isHidden = !theme.showsAxes
        let dataHidden = !theme.showsData
        dataFillLayer.isHidden = dataHidden
        dataStrokeLayer.isHidden = dataHidden
        vertexDotsLayer.isHidden = dataHidden
        gradientLayer.isHidden = !theme.showsBackground
    }

    private func maxRadius(bounds: CGRect) -> CGFloat {
        guard let theme = currentTheme else { return 0 }
        let half = min(bounds.width, bounds.height) / 2
        let cardHalf = half - theme.labelOuterPadding
        let dotMargin = theme.vertexDotRadius + 2
        return max(0, cardHalf - dotMargin)
    }

    // MARK: - 网格描边
    private func rebuildGrid(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        guard let theme = currentTheme else { return }
        let ringCount = max(1, theme.gridRingCount)
        let path = UIBezierPath()
        for k in 0..<ringCount {
            let pts = RadarGeometry.ringPoints(count: n, center: center, radius: radius,
                                               ringIndex: k, ringCount: ringCount)
            guard let first = pts.first else { continue }
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
            path.close()
        }
        gridLayer.path = path.cgPath
    }

    // MARK: - 网格底色（每圈独立 fill）
    private func rebuildGridFill(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        gridFillContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let theme = currentTheme else { return }
        let ringCount = max(1, theme.gridRingCount)
        let fills = ringFillColors(ringCount: ringCount)
        guard !fills.isEmpty else { return }   // .none：不填充

        // 倒序：外圈(k 大)先(底)，内圈(k 小)后(顶)，内圈覆盖外圈中心
        for k in (0..<ringCount).reversed() {
            addRingFillLayer(model: model, center: center, radius: radius,
                             ringIndex: k, ringCount: ringCount, color: fills[k])
        }
    }

    private func ringFillColors(ringCount: Int) -> [UIColor] {
        guard let theme = currentTheme else { return [] }
        switch theme.gridRingFill {
        case .none:
            return []
        case .gradient(let from, let to):
            if ringCount == 1 { return [from] }
            return (0..<ringCount).map { k in
                // 外圈(k=ringCount-1)→t=0(from)；内圈(k=0)→t=1(to)
                let t = CGFloat(ringCount - 1 - k) / CGFloat(ringCount - 1)
                return HYMColorInterpolation.lerp(from, to, t)
            }
        case .colors(let cols):
            return (0..<ringCount).map { k in
                k < cols.count ? cols[k] : (cols.last ?? .clear)
            }
        }
    }

    private func addRingFillLayer(model: RadarChartModel, center: CGPoint, radius: CGFloat,
                                  ringIndex k: Int, ringCount: Int, color: UIColor) {
        let n = model.dimensions.count
        let pts = RadarGeometry.ringPoints(count: n, center: center, radius: radius,
                                           ringIndex: k, ringCount: ringCount)
        guard let first = pts.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.close()

        let ringLayer = CAShapeLayer()
        ringLayer.path = path.cgPath
        ringLayer.fillColor = color.cgColor
        ringLayer.strokeColor = UIColor.clear.cgColor
        gridFillContainerLayer.addSublayer(ringLayer)
    }

    // MARK: - 放射轴
    private func rebuildAxis(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: 1)
            path.move(to: center)
            path.addLine(to: p)
        }
        axisLayer.path = path.cgPath
    }

    // MARK: - 数据多边形
    private func rebuildData(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: ratio)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        dataFillLayer.path = path.cgPath
        dataStrokeLayer.path = path.cgPath
    }

    // MARK: - 顶点圆点
    private func rebuildVertexDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        let n = model.dimensions.count
        let dotRadius = theme.vertexDotRadius
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: ratio)
            path.append(UIBezierPath(arcCenter: p, radius: dotRadius,
                                     startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true))
        }
        vertexDotsLayer.path = path.cgPath
    }

    // MARK: - 文案标签（顶点外侧）
    private func rebuildLabels(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let view = hostView, let theme = currentTheme else { return }
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()

        let n = model.dimensions.count
        let gap = theme.labelOuterPadding
        for i in 0..<n {
            let a = RadarGeometry.angle(index: i, count: n)
            let r = radius + gap
            let labelCenter = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))

            let lbl = UILabel()
            lbl.text = model.dimensions[i].label
            lbl.textColor = theme.labelColor
            lbl.font = theme.labelFont
            lbl.textAlignment = .center
            lbl.sizeToFit()
            lbl.center = labelCenter
            view.addSubview(lbl)
            labels.append(lbl)
        }
    }

    // MARK: - 中心分数（双模式）
    private func rebuildScore(_ model: RadarChartModel, center: CGPoint) {
        guard let theme = currentTheme else { return }
        let resolved = resolvedCenterScore(model)
        if let value = resolved {
            scoreLabel.isHidden = false
            subtitleLabel.isHidden = false
            scoreLabel.text = formatScore(value)
            scoreLabel.font = theme.scoreFont
            scoreLabel.textColor = theme.scoreColor
            scoreLabel.sizeToFit()

            subtitleLabel.text = theme.scoreSubtitleText
            subtitleLabel.font = theme.scoreSubtitleFont
            subtitleLabel.textColor = theme.scoreSubtitleColor
            subtitleLabel.sizeToFit()

            subtitleLabel.center = CGPoint(x: center.x, y: center.y - 10)
            scoreLabel.center = CGPoint(x: center.x, y: center.y + 18)
        } else {
            scoreLabel.isHidden = true
            subtitleLabel.isHidden = true
        }
    }

    private func formatScore(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10   // 保留 1 位小数
        return rounded.rounded() == rounded ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
```

- [ ] **Step 2: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 验证检查点**

✅ RadarChartRenderer 完整实现协议，全部 layer 重建逻辑迁移到位，零 OC 痕迹。`hitTest` 保持默认 nil。无需 git 提交。

---

## Task 7: DEBUG 框架级自检（ChartSelfTest）

**Why:** 项目无 test target，用 `#if DEBUG` 断言自检覆盖纯逻辑（几何/分数/颜色插值/默认命中），替代旧 `RadarSelfTest`。App 启动跑一次。

**Files:**
- Create: `SwiftFunctionProject/Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: ChartSelfTest.swift**

```swift
#if DEBUG
import Foundation
import CoreGraphics
import UIKit

/// 框架级 DEBUG 断言自检（替代 RadarSelfTest）。App 启动调一次。
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
        assert(HYMColorInterpolation.lerp(black, white, 0) == black, "lerp t=0 wrong")
        let mid = HYMColorInterpolation.lerp(black, white, 0.5)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        mid.getRed(&r, green: &g, blue: &b, alpha: &a)
        assert(abs(r - 0.5) < 0.01 && abs(g - 0.5) < 0.01 && abs(b - 0.5) < 0.01, "lerp mid wrong")

        // —— 交互默认空命中 ——
        let renderer = RadarChartRenderer()
        assert(renderer.hitTest(.zero) == nil, "default hitTest should be nil")

        print("✅ ChartSelfTest passed")
    }
}
#endif
```

- [ ] **Step 2: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。
（运行时验证在 Task 8 demo 启动时由 `ChartSelfTest.runAll()` 触发。）

- [ ] **Step 3: 验证检查点**

✅ 框架级自检就位，覆盖几何/分数/插值/默认命中。无需 git 提交。

---

## Task 8: SwiftUI RadarChart 封装 + ContentView demo

**Why:** 提供声明式 SwiftUI 入口，并把当前 Xcode 默认模板的 `ContentView` 改为雷达图 demo，作为框架首个可视化验收 + 自检触发点。

**Files:**
- Create: `SwiftFunctionProject/Charts/SwiftUI/RadarChart.swift`
- Modify: `SwiftFunctionProject/ContentView.swift`

- [ ] **Step 1: RadarChart.swift**

```swift
import SwiftUI

/// SwiftUI 雷达图封装（UIViewRepresentable 包装通用容器）
public struct RadarChart: View {
    private let model: RadarChartModel
    private let theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool
    /// 命中回调（本期雷达无命中目标，预留）
    public var onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    public init(model: RadarChartModel,
                theme: RadarChartTheme = RadarChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear, onHit: onHit)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    let model: RadarChartModel
    let theme: RadarChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<RadarChartRenderer> {
        let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
        chart.onHit = onHit
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            // 延后一个 runloop，确保 layoutSubviews 已执行
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<RadarChartRenderer>, context: Context) {
        uiView.onHit = onHit
        uiView.configure(model: model, theme: theme)
    }
}
```

- [ ] **Step 2: ContentView.swift（整体替换）**

```swift
//
//  ContentView.swift
//  SwiftFunctionProject
//
//  Created by wangkun on 2026/7/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 雷达图")
                    .font(.headline)
                    .foregroundStyle(.white)
                RadarChart(model: Self.demoModel)
                    .frame(width: 320, height: 320)
            }
            .padding()
        }
        .background(Color.black)
        .onAppear {
            #if DEBUG
            ChartSelfTest.runAll()
            #endif
        }
    }

    private static var demoModel: RadarChartModel {
        let labels = ["进攻", "防守", "速度", "技巧", "体力", "意识"]
        let values: [Double] = [80, 60, 90, 50, 70, 85]
        let dims = zip(labels, values).map { RadarDimension(label: $0, value: $1) }
        // centerScore=nil：自动算归一化均值（≈72.5）
        return RadarChartModel(dimensions: dims, showsCenterScore: true, centerScore: nil)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 3: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: 运行验证（目视）**

⌘R 运行到 iOS 模拟器，逐项核对：
1. 控制台打印 `✅ ChartSelfTest passed`（若 assert 触发则说明纯逻辑有误，回到对应 Task 修正）。
2. 黑底，顶部「HYMCharts · 雷达图」标题。
3. 深紫渐变圆角卡片 + 5 圈同心六边形网格 + 6 条放射轴 + 6 个中文维度外侧标签（进攻顶点朝上、顺时针）。
4. 半透明紫色数据多边形 + 亮紫描边 + 顶点圆点。
5. 数据多边形从中心展开 + 中心分数从 0 滚动到 ≈72.5，下方「综合评分」。
6. 标签清晰在卡片外侧、无裁剪。

- [ ] **Step 5: 验证检查点**

✅ SwiftUI 封装可用、demo 正常、自检通过。无需 git 提交。

---

## Task 9: OC Wrapper（OCBridge 三件套）

**Why:** 让 OC 项目能完整使用雷达图：维度桥接、主题构造器（属性→struct、`GridRingFill` 字符串映射）、视图桥接（持内部泛型实例，OC 拿 `UIView` 嵌入）。

**Files:**
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMRadarDimensionBridge.swift`
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMRadarThemeBuilder.swift`
- Create: `SwiftFunctionProject/Charts/OCBridge/HYMRadarChartViewBridge.swift`

- [ ] **Step 1: HYMRadarDimensionBridge.swift**

```swift
import Foundation

/// OC 友好的维度桥接（NSObject）
@objcMembers
public final class HYMRadarDimensionBridge: NSObject {
    @objc public let label: String
    @objc public let value: Double
    @objc public let maxValue: Double

    @objc public init(label: String, value: Double, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        super.init()
    }

    /// 翻译为内部纯 Swift struct
    internal var dimension: RadarDimension {
        RadarDimension(label: label, value: value, maxValue: maxValue)
    }
}
```

- [ ] **Step 2: HYMRadarThemeBuilder.swift**

```swift
import UIKit

/// OC 友好的雷达主题构造器：属性赋值 → build() 成纯 Swift struct。
/// `GridRingFill` 用字符串 "none"/"gradient"/"colors" + 颜色数组映射，OC 零 Swift 特性依赖。
@objcMembers
public final class HYMRadarThemeBuilder: NSObject {
    // 显隐开关（与 RadarChartTheme 默认值一致）
    @objc public var showsData: Bool = true
    @objc public var showsGridLines: Bool = true
    @objc public var showsAxes: Bool = true
    @objc public var showsBackground: Bool = true

    /// 网格每圈底色模式："none" / "gradient" / "colors"
    @objc public var gridRingFill: String = "none"
    /// gradient: 2 个色 [from, to]；colors: 每圈一色；none: 忽略
    @objc public var gridRingColors: [UIColor] = []

    // 常用颜色（nil 用主题默认）
    @objc public var backgroundGradientStart: UIColor?
    @objc public var backgroundGradientEnd: UIColor?
    @objc public var dataFillColor: UIColor?
    @objc public var dataStrokeColor: UIColor?

    @objc public override init() { super.init() }

    /// 翻译为内部纯 Swift struct
    internal func build() -> RadarChartTheme {
        var t = RadarChartTheme()
        t.showsData = showsData
        t.showsGridLines = showsGridLines
        t.showsAxes = showsAxes
        t.showsBackground = showsBackground
        switch gridRingFill.lowercased() {
        case "gradient":
            if gridRingColors.count >= 2 {
                t.gridRingFill = .gradient(from: gridRingColors[0], to: gridRingColors[1])
            }
        case "colors":
            if !gridRingColors.isEmpty {
                t.gridRingFill = .colors(gridRingColors)
            }
        default:
            t.gridRingFill = .none
        }
        if let v = backgroundGradientStart { t.backgroundGradientStart = v }
        if let v = backgroundGradientEnd { t.backgroundGradientEnd = v }
        if let v = dataFillColor { t.dataFillColor = v }
        if let v = dataStrokeColor { t.dataStrokeColor = v }
        return t
    }
}
```

- [ ] **Step 3: HYMRadarChartViewBridge.swift**

```swift
import UIKit

/// OC 友好的雷达视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMRadarChartViewBridge: NSObject {
    private let chart: HYMChartView<RadarChartRenderer>
    private let theme: RadarChartTheme

    /// OC 端命中回调（预留；本期雷达无命中目标，不会触发）
    @objc public var onHit: ((NSString, Int) -> Void)?

    @objc public init(theme: HYMRadarThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<RadarChartRenderer>(frame: frame)
        super.init()
    }

    /// OC 嵌入用（加入父 view）
    @objc public var chartView: UIView { chart }

    /// 配置数据（NSNumber? 桥接内部 Double?）
    @objc public func configure(dimensions: [HYMRadarDimensionBridge],
                                showsCenterScore: Bool,
                                centerScore: NSNumber?) {
        let dims = dimensions.map { $0.dimension }
        let m = RadarChartModel(dimensions: dims,
                                showsCenterScore: showsCenterScore,
                                centerScore: centerScore?.doubleValue)
        chart.configure(model: m, theme: theme)
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
```

- [ ] **Step 4: 编译验证**

Run the build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: 验证检查点**

✅ OC Wrapper 三件套就位：OC 可构造维度/主题、拿 UIView 嵌入、configure + playAnimation。无需 git 提交。

---

## Task 10: 清理旧文件 + 最终验证

**Why:** 移除 OC 移植残留（探针、@objc 自检包装）与旧目录，完成纯 Swift SDK 化。最后整体编译 + 运行回归。

**Files:**
- Delete: `SwiftFunctionProject/图表/蛛网图/HYMSwiftProbe.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/RadarSelfTest.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/HYMRadarChartView.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/RadarChartModel.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/RadarGeometry.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/RadarDimension.swift`
- Delete: `SwiftFunctionProject/图表/蛛网图/HYMRadarChartTheme.swift`
- Delete: 整个 `SwiftFunctionProject/图表/` 目录（含 `.DS_Store`）

- [ ] **Step 1: 删除旧目录**

```bash
rm -rf "/Users/hoymiles/Desktop/移植项目/SwiftFunctionProject/SwiftFunctionProject/图表"
```

> 这会移除 `图表/蛛网图/` 下全部 7 个旧文件 + `.DS_Store` + 中文目录本身。文件同步组会自动从 target 移除这些引用。

- [ ] **Step 2: 最终编译验证**

Run the build command from「关键工程前提 #4」.
Expected: `** BUILD SUCCEEDED **`，无 `duplicate symbol` / `ambiguous type` 等由旧文件残留引起的错误（旧 `RadarDimension`/`RadarChartModel` 等与新 struct 重名，删旧后冲突消除）。

- [ ] **Step 3: 运行回归（目视 + 内存）**

⌘R 运行，核对与 Task 8 Step 4 完全一致的 6 项视觉/自检结果。

可选内存抽查（沿用 progress.md 经验）：
```bash
# 找到模拟器 UDID 与 App PID 后：
xcrun simctl spawn <UDID> leaks <PID>
```
Expected: 入场动画结束后 `leaks` 报告 0 leaks（displayLink 三处 invalidate 生效）。

- [ ] **Step 4: 验证检查点**

✅ 旧 OC 残留与旧目录已清理；框架纯 Swift 化完成；编译 + 运行回归通过。无需 git 提交。

---

## Self-Review（plan vs spec）

- **spec §3 决策记录（范围/架构A/渲染/OC策略/Wrapper覆盖/SwiftUI/交互/泛型/测试）** → 各 Task 覆盖：内核(Task1-4)、雷达落地(Task5-6)、Wrapper(Task9)、SwiftUI(Task8)、交互(Task1协议+Task4命中分发+Task6默认nil)、泛型容器(Task4)、测试(Task7)。
- **spec §5 目录结构** → File Structure 表逐文件对应 Task 1-9。
- **spec §6 协议族** → Task 1(Model/Theme/Interaction/Error/ColorInterpolation) + Task 2(Renderer+Context+默认实现) + Task 4(View) 覆盖；`init()` requirement 供泛型实例化。
- **spec §7 HYMChartView** → Task 4 完整实现（configure/playEntranceAnimation/onHit/deinit 防泄漏）。
- **spec §8 动画机制** → Task 3(Animator) + Task 4(performEntranceAnimation: layer scale/opacity + 数值滚动) + Task 6(updateEntranceAnimation/centerScoreTarget) 覆盖。
- **spec §9 雷达落地（去OC痕迹）** → Task 5(struct化+theme分离) + Task 6(Renderer承载rebuild) 覆盖；旧硬编码 demo 配置随旧文件删除一并移除(Task10)。
- **spec §10 OC Wrapper** → Task 9 三件套（含 GridRingFill 字符串映射、NSNumber? 桥接）覆盖。
- **spec §11 SwiftUI** → Task 8 RadarChart + ContentView demo 覆盖。
- **spec §12 迁移清理** → Task 10 覆盖（删探针/旧目录/RadarSelfTestRunner 随旧 RadarSelfTest 删除）。
- **spec §13 测试策略** → Task 7 ChartSelfTest 覆盖（几何/分数/插值/默认命中）。
- **spec §14 分期边界（第一阶段）** → Task 1-10 完整覆盖第一阶段 6 项；后续阶段（具体命中/新图表/选中态/XCTest）明确不在本 plan。
- **类型一致性**：`configure(model:theme:)`、`playEntranceAnimation()`、`animatableLayers`、`centerScoreTarget`、`updateEntranceAnimation(progress:)`、`hitTest(_:)`、`mount(into:)`/`unmount(from:)`、`HYMColorInterpolation.lerp`、`resolvedCenterScore` 跨 Task 命名一致；theme 分离贯穿 Model/Wrapper/SwiftUI。
- **Placeholder 扫描**：无 TBD/TODO；每个代码 step 均为完整可编译代码。

无缺口。

---

## 实现过程关键调整（2026-07-22 执行记录）

执行中相对 plan 代码的必要偏离（均已验证编译通过 + 运行 + 0 leaks）：

1. **Task 3 CADisplayLink · SDK 26.2 适配**：plan 原代码 `CADisplayLink(target:action:)` 与 `add(to:.main,...)` 在 iOS 26.2 SDK 下编译失败。实际采用：
   - `CADisplayLink(target: self, selector: #selector(tick))`
   - `link.add(to: RunLoop.main, forMode: .common)`
   - 增加 `import UIKit`
   - 验证方式：独立 `swiftc` 探测 + xcodebuild `** BUILD SUCCEEDED **`。

2. **Task 7 ChartSelfTest lerp 断言修复**：plan 原断言 `lerp(black,white,0) == black` 用 `UIColor ==` 比较，因 UIColor 相等性受 colorspace/精度影响不可靠而触发 assert。实际改为比较 RGBA 组件值（与中点断言风格一致）。

3. **Task 10 提前执行**：plan Task 10 的「删除旧 `图表/蛛网图/` 目录」提前到 Task 5 后执行——objectVersion 77 文件同步组把整个 `SwiftFunctionProject/` 都编译，旧目录同名 `.swift` 与新文件产生 `Multiple commands produce ...stringsdata` 冲突，阻塞后续编译验证。逻辑已 100% 迁移到新代码，删除安全。

4. **theme 与 model 分离**：`RadarChartModel` 不含 theme 字段（theme 由 `configure(model:theme:)` 单独传），符合单一职责。

5. **final review（opus）后 4 项完善**（审查结论：无 Critical，达框架地基标准）：
   - `HYMRadarChartViewBridge.onHit` 一次性接线（`chart.onHit` → OC block，`[weak self]`）。
   - `HYMChartError` 增加「防御式兜底、错误模型预留 throws API」设计说明注释。
   - `HYMRadarThemeBuilder` 增加字段覆盖范围说明注释。
   - `RadarChart.onHit` 由 `public var` 改 `private let`（构造期注入）。
   - 其余 Minor（init requirement 可演进性、formatScore 可读性、注释措辞）记录在案，非阻塞。

6. **验证结果**：
   - xcodebuild `** BUILD SUCCEEDED **`
   - 模拟器运行 UI 正确（深紫渐变卡片 + 网格 + 放射轴 + 数据多边形 + 顶点圆点 + 六维中文标签 + 中心 72.5 自动均值 + 「综合评分」）
   - 运行时 `leaks`：`0 leaks for 0 total leaked bytes`
