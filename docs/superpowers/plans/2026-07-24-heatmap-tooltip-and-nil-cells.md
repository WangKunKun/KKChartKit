# 热力图点击弹窗 + nil 占位格 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为热力图增加「点击弹窗（tooltip）」与「nil 占位格」两项能力，并把弹窗做成 Core 通用层，供未来各图表复用。

**Architecture:** Core 新增通用 tooltip（外观主题 + 定位纯函数 + 视图 + 显示控制器）与两个带默认空实现的协议槽位（`HYMChartHitTarget.tooltipText`、`HYMChartRenderer.tooltipAnchor(for:)`）；通用容器 `HYMChartView` 命中后组合「文本 + 锚点」显示弹窗。热力图特有层填值：`HeatmapCell.isValid`（nil 占位）、`tooltipText` 取值与 value 格式化、`tooltipAnchor` 返回格子 frame、Theme 开关。

**Tech Stack:** Swift / UIKit / CoreGraphics / QuartzCore（CALayer）；objectVersion 77 同步组（新增文件自动编译，无需改 pbxproj）。

**项目验证约定（重要）：**
- 本项目**默认不主动 git commit**（用户约定）。每个 task 的完成标准 = `xcodebuild` 编译 `** BUILD SUCCEEDED **` + 相关 `ChartSelfTest` 断言；commit 仅在用户明确要求时执行。下列 task 末尾的「验证」步骤即检查点，**不含 git commit**。
- 逻辑自检写在 `Charts/Debug/ChartSelfTest.swift`（DEBUG `assert`，App 启动 `runAll()` 触发），不是 XCTest。
- SourceKit 常有假阳性（`No such module 'UIKit'` 等）—— **以 xcodebuild 为唯一权威**，别为假阳性改代码。
- 编译命令（工作目录 = 仓库根 `SwiftFunctionProject/` 的父目录）：
  ```bash
  xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
    -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
  ```
  预期末行：`** BUILD SUCCEEDED **`。

**对应 Spec：** `docs/superpowers/specs/2026-07-24-heatmap-tooltip-and-nil-cells-design.md`

---

## 文件结构

**新增（Core）：**
- `Charts/Core/HYMChartTooltipPlacement.swift` — `HYMChartTooltipPlacement` 枚举 + `HYMChartTooltipGeometry` 定位纯函数。
- `Charts/Core/HYMChartTooltipTheme.swift` — `HYMChartTooltipTheme` 外观主题（纯值类型）。
- `Charts/Core/HYMChartTooltip.swift` — `HYMChartTooltip` 视图（背景/阴影/文字/箭头）。
- `Charts/Core/HYMChartTooltipController.swift` — `HYMChartTooltipController` 显示管理。

**修改（Core）：**
- `Charts/Core/HYMChartInteraction.swift` — `HYMChartHitTarget.tooltipText` 默认实现。
- `Charts/Core/HYMChartRenderer.swift` — `HYMChartTooltipAnchor` + `tooltipAnchor(for:)` 默认实现。
- `Charts/Core/HYMChartView.swift` — `tooltipTheme`/`showsTooltipOnHit`/`tooltipController`/`updateTooltip` + 清理。

**修改（Heatmap）：**
- `Charts/Heatmap/HeatmapChartModel.swift` — `HeatmapCell.isValid`/`tooltipText`/`placeholder()`；`resolvedValueRange` 排除无效格。
- `Charts/Heatmap/HeatmapChartRenderer.swift` — 跳过无效格；`HeatmapHitTarget.tooltipText`；`tooltipAnchor(for:)`；`format(_:)`。
- `Charts/Heatmap/HeatmapChartTheme.swift` — `showsTooltipOnHit`。

**修改（OCBridge）：**
- `Charts/OCBridge/HYMHeatmapCellBridge.swift` — `valid`/`tooltipText`。
- `Charts/OCBridge/HYMHeatmapThemeBuilder.swift` — `showsTooltipOnHit`。
- `Charts/OCBridge/HYMHeatmapChartViewBridge.swift` — 透传 `showsTooltipOnHit`。

**修改（SwiftUI / Debug）：**
- `Charts/SwiftUI/HeatmapChart.swift` — 默认开 tooltip + `tooltipTheme` 参数。
- `Charts/SwiftUI/HeatmapChartDemo.swift` — placeholder + 自定义 tooltipText 样例。
- `Charts/Debug/ChartSelfTest.swift` — 定位/占位/文本断言。

---

## Task 1: Core 定位纯函数 `HYMChartTooltipGeometry`

**Files:**
- Create: `Charts/Core/HYMChartTooltipPlacement.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 先写失败的自检断言**

在 `Charts/Debug/ChartSelfTest.swift` 的 `runAll()` 末尾、`print("✅ ChartSelfTest passed")` 之前插入：

```swift
        // —— HYMChartTooltipGeometry 定位 ——
        // 锚点居中、上方充足 → .top，frame 不越界
        let ttContainer = CGRect(x: 0, y: 0, width: 200, height: 200)
        let ttAnchor = CGRect(x: 90, y: 100, width: 20, height: 20)   // midX=100, minY=100
        let ttSize = CGSize(width: 60, height: 30)
        let top = HYMChartTooltipGeometry.resolve(anchor: ttAnchor, size: ttSize,
                                                  container: ttContainer,
                                                  preferred: [.top, .bottom], gap: 6)
        assert(top?.placement == .top, "should pick .top when room above, got \(String(describing: top?.placement))")
        // .top: 底边 = anchor.minY - gap = 94；frame.minY = 94 - 30 = 64；不越界
        assert(top!.frame.maxY - 6 - abs(top!.frame.minY - 64) < 1, "top frame wrong")
        assert(abs(top!.frame.midX - 100) < 0.001, "top should center on anchor midX")
        assert(top!.arrowX >= top!.frame.minX && top!.arrowX <= top!.frame.maxX,
               "arrowX must stay inside frame")

        // 锚点贴顶（上方不够，gap+size 超出）→ 翻转 .bottom
        let topAnchor = CGRect(x: 90, y: 5, width: 20, height: 20)    // minY=5，上方只剩 5pt < gap+30
        let flip = HYMChartTooltipGeometry.resolve(anchor: topAnchor, size: ttSize,
                                                   container: ttContainer,
                                                   preferred: [.top, .bottom], gap: 6)
        assert(flip?.placement == .bottom, "should flip to .bottom when top overflows")

        // 上下都不够（锚点在容器中部，但容器太矮）→ 裁进 container 不越界
        let tiny = CGRect(x: 0, y: 0, width: 200, height: 20)
        let midAnchor = CGRect(x: 90, y: 0, width: 20, height: 20)
        let squeezed = HYMChartTooltipGeometry.resolve(anchor: midAnchor, size: ttSize,
                                                       container: tiny,
                                                       preferred: [.top, .bottom], gap: 6)
        assert(squeezed != nil, "must still produce a frame when nothing fits")
        assert(squeezed!.frame.minY >= tiny.minY - 0.001 && squeezed!.frame.maxY <= tiny.maxY + 0.001,
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
```

- [ ] **Step 2: 运行编译，确认因类型未定义而失败**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：编译失败，`cannot find 'HYMChartTooltipGeometry' in scope`。

- [ ] **Step 3: 创建定位纯函数文件**

创建 `Charts/Core/HYMChartTooltipPlacement.swift`：

```swift
import CoreGraphics

/// 通用图表弹窗（tooltip）相对锚点的放置方向。
public enum HYMChartTooltipPlacement {
    /// 弹窗在锚点上方（箭头朝下，指向锚点）。
    case top
    /// 弹窗在锚点下方（箭头朝上，指向锚点）。
    case bottom
}

/// 通用图表弹窗定位纯函数（仅依赖 CoreGraphics，便于 DEBUG 自检）。
public enum HYMChartTooltipGeometry {
    /// 定位结果。
    public struct Result {
        /// 弹窗最终 frame（容器坐标系，已裁进 container）。
        public var frame: CGRect
        /// 实际放置方向。
        public var placement: HYMChartTooltipPlacement
        /// 箭头根部 x（容器坐标系；已 clamp 到弹窗内，避免画出弹窗外）。
        public var arrowX: CGFloat
    }

    /// 根据锚点、弹窗尺寸、容器、偏好方向、间距，计算弹窗最终位置。
    ///
    /// 规则：
    /// 1. 按 `preferred` 顺序找第一个「弹窗完整落在 container 内」的方向；
    ///    `preferred` 为空按 `[.top, .bottom]`。
    /// 2. 都放不下 → 选「垂直超出量更小」的方向，并把 frame 平移裁进 container
    ///    （此即「极端情况与锚点重叠」）。
    /// 3. 水平：居中于 `anchor.midX`；左/右超出 container → 平移贴边。
    /// 4. 箭头 x：默认指向 `anchor.midX`，再 clamp 到弹窗内。
    ///
    /// - Parameters:
    ///   - anchor: 锚点 frame（容器坐标系）
    ///   - size: 弹窗自适应尺寸（由 tooltip `sizeThatFits` 给出）
    ///   - container: 可显示区域
    ///   - preferred: 偏好方向序列
    ///   - gap: 弹窗与锚点间距
    /// - Returns: 定位结果；`size` 为 0 时返回 nil。
    public static func resolve(
        anchor: CGRect, size: CGSize, container: CGRect,
        preferred: [HYMChartTooltipPlacement], gap: CGFloat
    ) -> Result? {
        guard size.width > 0, size.height > 0 else { return nil }
        let prefs = preferred.isEmpty ? [.top, .bottom] : preferred
        let halfW = size.width / 2

        func candidateFrame(_ placement: HYMChartTooltipPlacement) -> CGRect {
            switch placement {
            case .top:
                return CGRect(x: anchor.midX - halfW,
                              y: anchor.minY - gap - size.height,
                              width: size.width, height: size.height)
            case .bottom:
                return CGRect(x: anchor.midX - halfW,
                              y: anchor.maxY + gap,
                              width: size.width, height: size.height)
            }
        }

        // 选方向：优先「完整落在 container 内」(overflow==0)；否则选「垂直超出量最小」。
        var chosenPlacement: HYMChartTooltipPlacement = prefs[0]
        var chosenFrame: CGRect = candidateFrame(prefs[0])
        var bestOverflow: CGFloat = .infinity
        for p in prefs {
            let f = candidateFrame(p)
            let topOver = max(0, container.minY - f.minY)
            let bottomOver = max(0, f.maxY - container.maxY)
            let overflow = topOver + bottomOver
            if overflow == 0 {
                chosenPlacement = p
                chosenFrame = f
                break
            }
            if overflow < bestOverflow {
                bestOverflow = overflow
                chosenPlacement = p
                chosenFrame = f
            }
        }

        var frame = chosenFrame

        // 垂直裁进 container（极端情况可能与锚点重叠）
        if frame.minY < container.minY { frame.origin.y = container.minY }
        if frame.maxY > container.maxY { frame.origin.y = container.maxY - frame.height }

        // 水平：居中后贴边
        if frame.minX < container.minX { frame.origin.x = container.minX }
        if frame.maxX > container.maxX { frame.origin.x = container.maxX - frame.width }

        // 箭头 x：指向锚点中心，clamp 到弹窗内
        let arrowX = max(frame.minX, min(frame.maxX, anchor.midX))
        return Result(frame: frame, placement: chosenPlacement, arrowX: arrowX)
    }
}
```

- [ ] **Step 4: 编译验证通过**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`（运行时 assert 待 Task 12 统一验证）。

---

## Task 2: Core 弹窗外观主题 `HYMChartTooltipTheme`

**Files:**
- Create: `Charts/Core/HYMChartTooltipTheme.swift`

- [ ] **Step 1: 创建主题文件**

创建 `Charts/Core/HYMChartTooltipTheme.swift`：

```swift
import UIKit

/// 通用图表弹窗外观主题（纯值类型；所有图表的 tooltip 外观集中于此）。
///
/// tooltip 外观归通用容器（`HYMChartView.tooltipTheme`），不嵌入各图表 Theme，
/// 以保持各图表 Theme 只承载自身图表外观。
public struct HYMChartTooltipTheme {
    /// 背景色。
    public var backgroundColor: UIColor
    /// 文字色。
    public var textColor: UIColor
    /// 文字字体。
    public var font: UIFont
    /// 背景圆角。
    public var cornerRadius: CGFloat
    /// 文字内边距。
    public var contentInset: UIEdgeInsets
    /// 长文本换行上限（保证弹窗窄于典型图表宽度，配合贴边规则不溢出 container）。
    public var maxWidth: CGFloat
    /// 是否绘制指向锚点的小箭头。
    public var showsArrow: Bool
    /// 箭头尺寸（宽 × 高）。
    public var arrowSize: CGSize
    /// 阴影色；nil = 无阴影。
    public var shadowColor: UIColor?
    /// 是否启用显示/隐藏的淡入 + 轻缩放动画。
    public var showsAnimation: Bool
    /// 弹窗与锚点间距。
    public var gap: CGFloat

    public init(backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.8),
                textColor: UIColor = .white,
                font: UIFont = .systemFont(ofSize: 12),
                cornerRadius: CGFloat = 6,
                contentInset: UIEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8),
                maxWidth: CGFloat = 180,
                showsArrow: Bool = true,
                arrowSize: CGSize = CGSize(width: 10, height: 6),
                shadowColor: UIColor? = UIColor.black.withAlphaComponent(0.15),
                showsAnimation: Bool = true,
                gap: CGFloat = 6) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.contentInset = contentInset
        self.maxWidth = maxWidth
        self.showsArrow = showsArrow
        self.arrowSize = arrowSize
        self.shadowColor = shadowColor
        self.showsAnimation = showsAnimation
        self.gap = gap
    }

    /// 默认主题。
    public static let `default` = HYMChartTooltipTheme()
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 3: Core 弹窗视图 `HYMChartTooltip`

**Files:**
- Create: `Charts/Core/HYMChartTooltip.swift`

> UI 视图类，以「编译通过」为完成标准；视觉正确性在 Task 12 截图验证。

- [ ] **Step 1: 创建弹窗视图**

创建 `Charts/Core/HYMChartTooltip.swift`：

```swift
import UIKit

/// 通用图表弹窗视图：背景圆角 + 可选阴影 + 文字（支持多行）+ 可选箭头。
///
/// 尺寸由 `sizeThatFits(_:)` 按内容自适应；箭头方向与位置由
/// `applyArrow(placement:arrowX:)` 在外部定位后注入（`arrowX` 为容器坐标系 x）。
public final class HYMChartTooltip: UIView {
    private let backgroundLayer = CALayer()
    private let arrowLayer = CAShapeLayer()
    private let textLabel = UILabel()
    private var theme: HYMChartTooltipTheme = .default
    private var placement: HYMChartTooltipPlacement = .top
    private var arrowX: CGFloat = 0
    private var lastText: String = ""

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        backgroundColor = .clear
        // 不拦截触摸：弹窗下方的格子仍可点击
        isUserInteractionEnabled = false
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(arrowLayer)
        addSubview(textLabel)
    }

    /// 设置内容与外观。
    public func configure(text: String, theme: HYMChartTooltipTheme) {
        self.theme = theme
        self.lastText = text
        textLabel.text = text
        textLabel.textColor = theme.textColor
        textLabel.font = theme.font
        textLabel.preferredMaxLayoutWidth = theme.maxWidth - theme.contentInset.left - theme.contentInset.right

        backgroundLayer.backgroundColor = theme.backgroundColor.cgColor
        backgroundLayer.cornerRadius = theme.cornerRadius
        if let sc = theme.shadowColor {
            backgroundLayer.shadowColor = sc.cgColor
            backgroundLayer.shadowOpacity = 1
            backgroundLayer.shadowOffset = CGSize(width: 0, height: 1)
            backgroundLayer.shadowRadius = 3
        } else {
            backgroundLayer.shadowOpacity = 0
        }
        arrowLayer.isHidden = !theme.showsArrow
        arrowLayer.fillColor = theme.backgroundColor.cgColor
    }

    /// 注入箭头方向与位置（容器坐标系下的 `arrowX`）。在 `sizeThatFits` 后、显示前调用。
    public func applyArrow(placement: HYMChartTooltipPlacement, arrowX: CGFloat) {
        self.placement = placement
        self.arrowX = arrowX
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let inset = theme.contentInset
        backgroundLayer.frame = bounds
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        var labelFrame = bounds.inset(by: inset)
        if theme.showsArrow {
            // .top（弹窗在锚点上方，箭头在底部）→ 文字区上移让出底部箭头；
            // .bottom（弹窗在锚点下方，箭头在顶部）→ 文字区下移让出顶部箭头。
            labelFrame.size.height -= arrowH
            if placement == .bottom { labelFrame.origin.y += arrowH }
        }
        textLabel.frame = labelFrame
        rebuildArrow()
    }

    private func rebuildArrow() {
        guard theme.showsArrow else { arrowLayer.path = nil; return }
        let w = theme.arrowSize.width
        let h = theme.arrowSize.height
        let cx = max(bounds.minX + w / 2, min(bounds.maxX - w / 2, arrowX))
        let path = UIBezierPath()
        switch placement {
        case .top:
            // 箭头在底部，尖朝下（指向下方锚点）
            path.move(to: CGPoint(x: cx - w / 2, y: bounds.maxY - h))
            path.addLine(to: CGPoint(x: cx + w / 2, y: bounds.maxY - h))
            path.addLine(to: CGPoint(x: cx, y: bounds.maxY))
        case .bottom:
            // 箭头在顶部，尖朝上（指向上方锚点）
            path.move(to: CGPoint(x: cx - w / 2, y: bounds.minY + h))
            path.addLine(to: CGPoint(x: cx + w / 2, y: bounds.minY + h))
            path.addLine(to: CGPoint(x: cx, y: bounds.minY))
        }
        path.close()
        arrowLayer.path = path.cgPath
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inset = theme.contentInset
        let arrowH = theme.showsArrow ? theme.arrowSize.height : 0
        let maxTextWidth = max(0, theme.maxWidth - inset.left - inset.right)
        let textBounds = (lastText as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: theme.font],
            context: nil)
        let textH = ceil(textBounds.height)
        let w = ceil(textBounds.width + inset.left + inset.right)
        let h = textH + inset.top + inset.bottom + arrowH
        return CGSize(width: max(w, inset.left + inset.right), height: h)
    }
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 4: Core 弹窗显示控制器 `HYMChartTooltipController`

**Files:**
- Create: `Charts/Core/HYMChartTooltipController.swift`

> 依赖 Task 1–3。以「编译通过」为完成标准；行为在 Task 12 截图验证。

- [ ] **Step 1: 创建控制器**

创建 `Charts/Core/HYMChartTooltipController.swift`：

```swift
import UIKit

/// 通用图表弹窗显示管理：持有 tooltip 视图（挂在 host 上），负责定位、显示、隐藏、动画与清理。
///
/// 线程：UI 操作应在主线程。
public final class HYMChartTooltipController {
    private weak var host: UIView?
    private let tooltip: HYMChartTooltip
    public var theme: HYMChartTooltipTheme

    public init(host: UIView, theme: HYMChartTooltipTheme = .default) {
        self.host = host
        self.theme = theme
        self.tooltip = HYMChartTooltip()
        tooltip.isHidden = true
        host.addSubview(tooltip)
    }

    /// 显示弹窗。
    /// - Parameters:
    ///   - anchor: 锚点 frame（host 坐标系）
    ///   - text: 显示文本
    ///   - container: 可显示区域（host 坐标系）
    ///   - preferred: 偏好方向序列
    public func show(anchor: CGRect, text: String,
                     in container: CGRect,
                     preferred: [HYMChartTooltipPlacement]) {
        guard let host = host else { return }
        tooltip.configure(text: text, theme: theme)
        let size = tooltip.sizeThatFits(CGSize(width: theme.maxWidth, height: .greatestFiniteMagnitude))
        guard let r = HYMChartTooltipGeometry.resolve(
            anchor: anchor, size: size, container: container,
            preferred: preferred, gap: theme.gap) else {
            tooltip.isHidden = true
            return
        }
        host.bringSubviewToFront(tooltip)   // 确保在标签等子视图之上
        tooltip.frame = r.frame
        tooltip.applyArrow(placement: r.placement, arrowX: r.arrowX)
        tooltip.layoutIfNeeded()

        if theme.showsAnimation {
            tooltip.alpha = 0
            tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            tooltip.isHidden = false
            UIView.animate(withDuration: 0.18, delay: 0, options: []) {
                self.tooltip.alpha = 1
                self.tooltip.transform = .identity
            }
        } else {
            tooltip.alpha = 1
            tooltip.transform = .identity
            tooltip.isHidden = false
        }
    }

    /// 隐藏弹窗。
    public func hide() {
        guard !tooltip.isHidden else { return }
        if theme.showsAnimation {
            UIView.animate(withDuration: 0.15, delay: 0, options: [],
                           animations: {
                self.tooltip.alpha = 0
                self.tooltip.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
                self.tooltip.isHidden = true
                self.tooltip.transform = .identity
            })
        } else {
            tooltip.isHidden = true
        }
    }

    /// 从 host 移除（`HYMChartView` unmount/deinit 清理用）。
    public func removeFromSuperview() {
        tooltip.removeFromSuperview()
    }
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 5: Core 协议槽位 `tooltipText` + `tooltipAnchor`

**Files:**
- Modify: `Charts/Core/HYMChartInteraction.swift`
- Modify: `Charts/Core/HYMChartRenderer.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 先写失败的自检断言**

在 `Charts/Debug/ChartSelfTest.swift` 的 `runAll()` 末尾（Task 1 插入处之后、`print("✅...")` 之前）插入：

```swift
        // —— 通用 tooltip 槽位默认值 ——
        struct _TipTarget: HYMChartHitTarget { let identifier = "t"; let index = 0 }
        assert(_TipTarget().tooltipText == nil, "default tooltipText should be nil")
        let _tipRenderer = HeatmapChartRenderer()
        assert(_tipRenderer.tooltipAnchor(for: _TipTarget()) == nil,
               "default tooltipAnchor should be nil")
```

- [ ] **Step 2: 运行编译，确认失败**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：失败，`value of type '_TipTarget' has no member 'tooltipText'` 等。

- [ ] **Step 3: 给 `HYMChartHitTarget` 加 `tooltipText`**

在 `Charts/Core/HYMChartInteraction.swift` 末尾追加：

```swift
public extension HYMChartHitTarget {
    /// 弹窗显示文本（数据驱动）；默认 nil = 不显示弹窗。
    /// 具体图表的 `XXXHitTarget` 按需覆盖（从自身数据派生）。
    var tooltipText: String? { nil }
}
```

- [ ] **Step 4: 给 `HYMChartRenderer` 加 `HYMChartTooltipAnchor` + `tooltipAnchor(for:)`**

在 `Charts/Core/HYMChartRenderer.swift` 中，紧接 `HYMChartRenderContext` 结构体之后、`public protocol HYMChartRenderer` 之前插入：

```swift
/// 弹窗锚点（绘图驱动）：锚点 frame（view 坐标系）+ 偏好放置方向。
public struct HYMChartTooltipAnchor {
    public var frame: CGRect
    public var preferredPlacements: [HYMChartTooltipPlacement]
    public init(frame: CGRect, preferredPlacements: [HYMChartTooltipPlacement]) {
        self.frame = frame
        self.preferredPlacements = preferredPlacements
    }
}
```

并在文件末尾已有的 `public extension HYMChartRenderer { ... }`（含 `hitTest`/`applySelection`/`updateEntranceAnimation` 默认实现）内追加一行方法：

```swift
    /// 为命中目标提供弹窗锚点；默认 nil = 不显示弹窗。
    func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? { nil }
```

最终该 extension 形如：

```swift
public extension HYMChartRenderer {
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }
    func applySelection(_ target: HYMChartHitTarget?) {}
    func updateEntranceAnimation(progress: Double) {}
    func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? { nil }
}
```

- [ ] **Step 5: 编译验证通过**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。雷达图等现有图表因默认实现零改动。

---

## Task 6: Core 容器 `HYMChartView` 集成 tooltip

**Files:**
- Modify: `Charts/Core/HYMChartView.swift`

- [ ] **Step 1: 加属性**

在 `Charts/Core/HYMChartView.swift` 的 `// MARK: - 状态` 区块内（`onHit` 附近）新增：

```swift
    /// tooltip 外观主题（通用；默认 `.default`，可覆盖）。
    public var tooltipTheme: HYMChartTooltipTheme = .default {
        didSet { tooltipController?.theme = tooltipTheme }
    }
    /// 命中时是否显示默认 tooltip（通用默认 false，避免影响现有图表；
    /// 需要弹窗的图表在其封装层显式置 true）。
    public var showsTooltipOnHit: Bool = false
    /// 弹窗控制器（首次显示时懒创建）。
    private var tooltipController: HYMChartTooltipController?
```

- [ ] **Step 2: 改 `onTap` 接入 tooltip 更新**

将 `onTap(_:)` 改为（仅新增 `updateTooltip(for:)` 一行）：

```swift
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        let target = renderer.hitTest(p)
        renderer.applySelection(target)        // 命中→选中，未命中→取消（通用）
        updateTooltip(for: target)            // tooltip 跟随选中态
        if let target { onHit?(target, .tap) }
    }
```

- [ ] **Step 3: 加 `ensureTooltipController` + `updateTooltip`**

在 `onTap` 之后、`deinit` 之前新增：

```swift
    // MARK: - Tooltip
    private func ensureTooltipController() -> HYMChartTooltipController {
        if let c = tooltipController { return c }
        let c = HYMChartTooltipController(host: self, theme: tooltipTheme)
        tooltipController = c
        return c
    }

    /// 命中后更新 tooltip：开关关 / 无文本 / 无锚点 → 隐藏；否则显示。
    private func updateTooltip(for target: HYMChartHitTarget?) {
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
        guard let target,
              let text = target.tooltipText,
              let anchor = renderer.tooltipAnchor(for: target) else {
            tooltipController?.hide()
            return
        }
        ensureTooltipController().show(anchor: anchor.frame, text: text,
                                       in: bounds, preferred: anchor.preferredPlacements)
    }
```

- [ ] **Step 4: `deinit` 清理 tooltip**

将 `deinit` 改为：

```swift
    deinit {
        animator.stop()                       // 打破 displayLink ↔ animator 循环
        tooltipController?.removeFromSuperview()
        renderer.unmount(from: self)          // 清理 layer/子视图
    }
```

- [ ] **Step 5: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 7: Heatmap nil 占位（`HeatmapCell.isValid` + `tooltipText`）

**Files:**
- Modify: `Charts/Heatmap/HeatmapChartModel.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 先写失败的自检断言**

在 `ChartSelfTest.runAll()` 末尾（前述插入之后、`print("✅...")` 之前）插入：

```swift
        // —— HeatmapCell 无效占位 ——
        assert(HeatmapCell.placeholder().isValid == false, "placeholder should be invalid")
        assert(HeatmapCell(value: 50).isValid == true, "default cell should be valid")
        // 无效格不参与色阶归一化：[10, placeholder, 30] → range 10...30
        let mixed = HeatmapChartModel(rows: [
            [HeatmapCell(value: 10), HeatmapCell.placeholder(), HeatmapCell(value: 30)]
        ])
        let mixedRange = mixed.resolvedValueRange
        assert(abs(mixedRange.lowerBound - 10) < 0.001 && abs(mixedRange.upperBound - 30) < 0.001,
               "invalid cells must be excluded from range, got \(mixedRange)")
```

- [ ] **Step 2: 运行编译，确认失败**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：失败，`'placeholder()' has no member` / `isValid` 不存在。

- [ ] **Step 3: 改 `HeatmapCell` 加字段 + `placeholder()`**

将 `Charts/Heatmap/HeatmapChartModel.swift` 中 `HeatmapCell` 整体替换为：

```swift
/// 热力图单个格子（纯值类型）。
public struct HeatmapCell {
    /// 原始数值（如百分比 0~100，或任意量纲）。
    public var value: Double
    /// 满值，用于单格归一化；默认 100。<=0 时按 1 兜底。
    public var maxValue: Double
    /// 单格覆盖色；nil → 由 Theme 色阶按全局值域归一化计算。
    public var color: UIColor?
    /// 是否有效；false = 无效占位（占布局位置但不绘制、不命中、不参与色阶）。
    public var isValid: Bool
    /// 该格子弹窗文本；nil → 默认格式化 `value`。仅当 tooltip 启用时生效。
    public var tooltipText: String?

    public init(value: Double, maxValue: Double = 100, color: UIColor? = nil,
                isValid: Bool = true, tooltipText: String? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.isValid = isValid
        self.tooltipText = tooltipText
    }

    /// 单格自归一化比值 [0,1]（越界裁剪；内部使用）。
    public var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }

    /// 无效占位格：占位但不绘制、不命中、不参与色阶。
    public static func placeholder() -> HeatmapCell {
        HeatmapCell(value: 0, isValid: false)
    }
}
```

- [ ] **Step 4: `resolvedValueRange` 排除无效格**

将同文件中 `resolvedValueRange` 的实现替换为（仅把 `map` 改为 `compactMap` + `isValid` 过滤）：

```swift
    /// 实际生效的归一化值域；显式 nil/数据为空/极差为 0 时回退 0...1（纯函数，便于自检）。
    public var resolvedValueRange: ClosedRange<Double> {
        if let r = valueRange { return r }
        let vals = rows.flatMap { $0 }.compactMap { $0.isValid ? $0.value : nil }
        guard let lo = vals.min(), let hi = vals.max(), hi > lo else {
            return 0...1
        }
        return lo...hi
    }
```

- [ ] **Step 5: 编译验证通过**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 8: Heatmap tooltip 接入（跳过无效格 + `tooltipText` + `tooltipAnchor` + `format`）

**Files:**
- Modify: `Charts/Heatmap/HeatmapChartRenderer.swift`
- Test: `Charts/Debug/ChartSelfTest.swift`

- [ ] **Step 1: 先写失败的自检断言**

在 `ChartSelfTest.runAll()` 末尾（前述插入之后、`print("✅...")` 之前）插入：

```swift
        // —— Heatmap value 默认格式化 ——
        assert(HeatmapChartRenderer.format(80.0) == "80", "80.0 should format to '80'")
        assert(HeatmapChartRenderer.format(80.5) == "80.5", "80.5 should format to '80.5'")
        assert(HeatmapChartRenderer.format(0.0) == "0", "0.0 should format to '0'")

        // —— 无效格不命中、有效格命中带 tooltipText ——
        let nilModel = HeatmapChartModel(rows: [
            [HeatmapCell.placeholder(), HeatmapCell(value: 50, tooltipText: "自定义")]
        ])
        let nilRenderer = HeatmapChartRenderer()
        nilRenderer.render(model: nilModel, theme: HeatmapChartTheme(),
                           context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 300, height: 200),
                                                          center: .zero))
        // 渲染后断言：无效格无 layer（通过命中间接验证——命中无效格位置应返回 nil）
        // cellSize = min(300/2, 200/1)=100；列间距 3：(0,0)=invalid, (0,1)=valid@x≈103..203
        let hitInvalid = nilRenderer.hitTest(CGPoint(x: 5, y: 5))   // 落在 (0,0) 无效格
        assert(hitInvalid == nil, "invalid cell must not be hit, got \(String(describing: hitInvalid))")
        let hitValid = nilRenderer.hitTest(CGPoint(x: 150, y: 50))  // 落在 (0,1) 有效格
        if let h = hitValid as? HeatmapHitTarget {
            assert(h.row == 0 && h.column == 1, "should hit (0,1)")
            assert(h.tooltipText == "自定义", "custom tooltipText should win, got \(String(describing: h.tooltipText))")
        } else {
            assertionFailure("should hit valid cell (0,1)")
        }
        // 默认 value 格式化
        let defModel = HeatmapChartModel(rows: [[HeatmapCell(value: 42)]])
        let defRenderer = HeatmapChartRenderer()
        defRenderer.render(model: defModel, theme: HeatmapChartTheme(),
                          context: HYMChartRenderContext(bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                                                         center: .zero))
        let hitDef = defRenderer.hitTest(CGPoint(x: 50, y: 50)) as? HeatmapHitTarget
        assert(hitDef?.tooltipText == "42", "default tooltipText should be formatted value, got \(String(describing: hitDef?.tooltipText))")
```

- [ ] **Step 2: 运行编译，确认失败**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：失败，`format` 不存在 / `HeatmapHitTarget` 无 `tooltipText` 参数。

- [ ] **Step 3: `HeatmapHitTarget` 加 `tooltipText`**

将 `Charts/Heatmap/HeatmapChartRenderer.swift` 顶部 `HeatmapHitTarget` 替换为：

```swift
/// 热力图命中目标（点击格子时产生）。热力图不区分类别，kind 用协议默认 ""。
public struct HeatmapHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let row: Int
    public let column: Int
    /// 该格子弹窗文本（自定义优先，否则 `format(value)`）。nil 表示无文本。
    public let tooltipText: String?
    public init(row: Int, column: Int, tooltipText: String? = nil) {
        self.row = row
        self.column = column
        self.identifier = "(\(row),\(column))"
        self.index = row * 1000 + column
        self.tooltipText = tooltipText
    }
}
```

- [ ] **Step 4: render 跳过无效格**

在同文件 `render(model:theme:context:)` 的双层循环中，把：

```swift
        for (r, row) in model.rows.enumerated() {
            for (c, cell) in row.enumerated() {
                let f = HeatmapGeometry.cellFrame(row: r, col: c, layout: layout,
                                                  rowSpacing: theme.rowSpacing, columnSpacing: theme.columnSpacing)
                lastCellFrames.append((r, c, f))
                let layer = CALayer()
```

改为（仅加 `guard cell.isValid else { continue }`）：

```swift
        for (r, row) in model.rows.enumerated() {
            for (c, cell) in row.enumerated() {
                guard cell.isValid else { continue }   // 无效格：占位不绘制、不进命中缓存
                let f = HeatmapGeometry.cellFrame(row: r, col: c, layout: layout,
                                                  rowSpacing: theme.rowSpacing, columnSpacing: theme.columnSpacing)
                lastCellFrames.append((r, c, f))
                let layer = CALayer()
```

- [ ] **Step 5: `hitTest` 填充 tooltipText**

将同文件 `hitTest(_:)` 替换为：

```swift
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        for hit in lastCellFrames where hit.frame.contains(point) {
            let cell = model.rows[hit.row][hit.col]
            let text = cell.tooltipText ?? Self.format(cell.value)
            return HeatmapHitTarget(row: hit.row, column: hit.col, tooltipText: text)
        }
        return nil
    }
```

- [ ] **Step 6: 实现 `tooltipAnchor(for:)` + `format(_:)`**

在 `HeatmapChartRenderer` 内（`applySelection` 之后、类结束 `}` 之前）新增：

```swift
    // MARK: - Tooltip 锚点（覆盖协议默认 nil）
    public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let theme = currentTheme, theme.showsTooltipOnHit,
              let h = target as? HeatmapHitTarget,
              let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
        else { return nil }
        return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
    }

    /// 默认 value 文本：去尾零（80.0 → "80"；80.5 → "80.5"）。
    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
```

- [ ] **Step 7: 编译验证通过**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：失败 —— `theme.showsTooltipOnHit` 尚不存在（下一个 Task 创建）。此为预期，进入 Task 9。

> 说明：本 Task 依赖 Task 9 的 `showsTooltipOnHit` 字段；二者顺序无强约束，编译通过以 Task 9 完成为准。若希望每个 Task 独立编译通过，可先做 Task 9 再回头做本 Task 的 Step 6。

---

## Task 9: Heatmap Theme 开关 `showsTooltipOnHit`

**Files:**
- Modify: `Charts/Heatmap/HeatmapChartTheme.swift`

- [ ] **Step 1: 加字段**

在 `Charts/Heatmap/HeatmapChartTheme.swift` 的 `selectionBorderCornerRadius` 字段之后（`public init` 之前）新增：

```swift
    /// 点击有效格子是否弹出默认 tooltip（默认 true）。
    /// false 时 Renderer 不提供锚点 → 不弹窗。
    public var showsTooltipOnHit: Bool
```

- [ ] **Step 2: init 加参数 + 赋值**

在 `public init(...)` 的参数列表末尾追加（`selectionBorderCornerRadius` 之后）：

```swift
        showsTooltipOnHit: Bool = true
```

并在 init 函数体末尾（`self.selectionBorderCornerRadius = selectionBorderCornerRadius` 之后）追加：

```swift
        self.showsTooltipOnHit = showsTooltipOnHit
```

- [ ] **Step 3: 编译验证通过（含 Task 8）**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`（Task 8 的 `theme.showsTooltipOnHit` 引用至此通过）。

---

## Task 10: OC 桥接（CellBridge + ThemeBuilder + ViewBridge）

**Files:**
- Modify: `Charts/OCBridge/HYMHeatmapCellBridge.swift`
- Modify: `Charts/OCBridge/HYMHeatmapThemeBuilder.swift`
- Modify: `Charts/OCBridge/HYMHeatmapChartViewBridge.swift`

- [ ] **Step 1: `HYMHeatmapCellBridge` 加 `valid` + `tooltipText`**

将 `Charts/OCBridge/HYMHeatmapCellBridge.swift` 整体替换为：

```swift
import UIKit

/// OC 友好的热力图单格桥接：包装内部 `HeatmapCell`。
@objcMembers
public final class HYMHeatmapCellBridge: NSObject {
    @objc public var value: Double
    @objc public var maxValue: Double
    @objc public var color: UIColor?
    /// 是否有效；NO = 无效占位（占位不绘制、不命中、不参与色阶）。默认 YES。
    @objc public var valid: Bool
    /// 该格子弹窗文本；nil → 默认格式化 value。
    @objc public var tooltipText: String?

    @objc public init(value: Double, maxValue: Double = 100, color: UIColor? = nil,
                      valid: Bool = true, tooltipText: String? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.valid = valid
        self.tooltipText = tooltipText
        super.init()
    }

    internal var heatCell: HeatmapCell {
        HeatmapCell(value: value, maxValue: maxValue, color: color,
                    isValid: valid, tooltipText: tooltipText)
    }
}
```

- [ ] **Step 2: `HYMHeatmapThemeBuilder` 加 `showsTooltipOnHit`**

在 `Charts/OCBridge/HYMHeatmapThemeBuilder.swift`：
（a）在 `selectionBorderCornerRadius` 属性之后新增：

```swift
    /// 点击格子是否弹默认 tooltip（默认 YES）。
    @objc public var showsTooltipOnHit: Bool = true
```

（b）在 `build()` 函数体末尾（`if let v = selectionBorderCornerRadius {...}` 之后、`return t` 之前）新增：

```swift
        t.showsTooltipOnHit = showsTooltipOnHit
```

- [ ] **Step 3: `HYMHeatmapChartViewBridge` 开启通用 tooltip 机制**

在 `Charts/OCBridge/HYMHeatmapChartViewBridge.swift` 的 `init(theme:frame:)` 内，`super.init()` 之后、设置 `chart.onHit` 之前新增一行：

```swift
        chart.showsTooltipOnHit = true   // 开启通用 tooltip 机制；开关细节由 theme.showsTooltipOnHit 控制
```

- [ ] **Step 4: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 11: SwiftUI 封装 + Demo

**Files:**
- Modify: `Charts/SwiftUI/HeatmapChart.swift`
- Modify: `Charts/SwiftUI/HeatmapChartDemo.swift`

- [ ] **Step 1: `HeatmapChart` 加 `tooltipTheme` 参数 + 默认开启**

将 `Charts/SwiftUI/HeatmapChart.swift` 整体替换为：

```swift
import SwiftUI

/// SwiftUI 热力图封装（UIViewRepresentable 包装通用容器）。
public struct HeatmapChart: View {
    private let model: HeatmapChartModel
    private var theme: HeatmapChartTheme
    private let playsAnimationOnAppear: Bool
    private let tooltipTheme: HYMChartTooltipTheme
    /// 命中回调：点中格子时触发，携带 HeatmapHitTarget（row + column）
    private let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?

    public init(model: HeatmapChartModel,
                theme: HeatmapChartTheme = HeatmapChartTheme(),
                playsAnimationOnAppear: Bool = true,
                tooltipTheme: HYMChartTooltipTheme = .default,
                onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.theme.colorScale = .alpha(UIColor(named: "Green")!)
        self.theme.showsRowLabels = false
        self.theme.showsColumnLabels = false
        self.theme.rowSpacing = 0
        self.theme.columnSpacing = 0
        self.theme.cellCornerRadius = 0
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.tooltipTheme = tooltipTheme
        self.onHit = onHit
    }

    public var body: some View {
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear,
                                  tooltipTheme: tooltipTheme, onHit: onHit)
    }
}

struct HeatmapChartRepresentable: UIViewRepresentable {
    let model: HeatmapChartModel
    let theme: HeatmapChartTheme
    let playsAnimationOnAppear: Bool
    let tooltipTheme: HYMChartTooltipTheme
    let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<HeatmapChartRenderer> {
        let chart = HYMChartView<HeatmapChartRenderer>(frame: .zero)
        chart.tooltipTheme = tooltipTheme
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<HeatmapChartRenderer>, context: Context) {
        uiView.tooltipTheme = tooltipTheme
        uiView.showsTooltipOnHit = true
        uiView.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        uiView.configure(model: model, theme: theme)
    }
}
```

- [ ] **Step 2: Demo 加 placeholder + 自定义 tooltipText 样例**

将 `Charts/SwiftUI/HeatmapChartDemo.swift` 整体替换为：

```swift
import SwiftUI

/// 热力图 demo：5 行百分比，含 nil 占位格 + 部分自定义 tooltip 文本。
/// 点击有效格子：上方/下方自动避让弹窗；无效格不绘制、不可点。
struct HeatmapChartDemo: View {
    private static let model: HeatmapChartModel = {
        let values: [[Double?]] = [
            [0, 34, 56, nil, 90, 45, 23, 29, 12, 8],
            [67, 89, 12, 34, 56, 78, 90, 34, 56, 78],
            [45, 23, 67, nil, 12, 34, 56, 45, 23, 67],
            [78, 90, 45, 23, 67, 89, 12, nil, nil, nil],
            [90],
        ]
        let rows = values.map { row in
            row.map { v -> HeatmapCell in
                guard let v else { return HeatmapCell.placeholder() }
                // 个别格子演示自定义 tooltip 文本
                if v == 90 { return HeatmapCell(value: v, tooltipText: "满分 \(Int(v))") }
                return HeatmapCell(value: v)
            }
        }
        return HeatmapChartModel(
            rows: rows,
            rowLabels: ["W1", "W2", "W3", "W4", "W5"],
            columnLabels: ["一", "二", "三", "四", "五", "六", "日"])
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("HYMCharts · 热力图（默认绿色 + 点击弹窗）")
                    .font(.headline)
                Text("点击有效格子弹窗（上下避让）；nil 格子占位不绘制")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HeatmapChart(model: Self.model) { target, _ in
                    print("🔥 heatmap hit: (\(target.row),\(target.column)) tip=\(target.tooltipText ?? "nil")")
                }
                .frame(height: 220)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("热力图 demo")
    }
}
```

- [ ] **Step 3: 编译验证**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

---

## Task 12: 全量验证（自检运行 + 模拟器截图 + leaks）

**Files:**
- Run only.

- [ ] **Step 1: 全量编译**

```bash
xcodebuild -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=FB74ECC0-DDCA-4168-A93D-81B91C56432C' build 2>&1 | tail -5
```
预期：`** BUILD SUCCEEDED **`。

- [ ] **Step 2: 安装并启动 App（触发 `ChartSelfTest.runAll()`）**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "SwiftFunctionProject.app" -path "*/Debug-iphonesimulator/*" | head -1)
xcrun simctl install FB74ECC0-DDCA-4168-A93D-81B91C56432C "$APP_PATH"
xcrun simctl launch --console-pty FB74ECC0-DDCA-4168-A93D-81B91C56432C hm-test-widget.SwiftFunctionProject 2>&1 | grep -E "ChartSelfTest|Assertion" | head -20
```
预期：日志含 `✅ ChartSelfTest passed`，无 `Assertion failed`。

> 若 demo 入口需要手动导航到「热力图 demo」页：用 `xcrun simctl launch` 启动后，在 UI 中进入热力图页再截图。

- [ ] **Step 3: 截图验证弹窗视觉**

```bash
xcrun simctl io FB74ECC0-DDCA-4168-A93D-81B91C56432C screenshot /tmp/heatmap-tooltip.png
```
打开 `/tmp/heatmap-tooltip.png` 检查：格子色阶正常、nil 格子留空、（若点到格子）弹窗在格子上方或下方且不溢出、箭头指向格子、自定义文本「满分 90」生效。

- [ ] **Step 4: 泄漏检查**

```bash
PID=$(xcrun simctl launch FB74ECC0-DDCA-4168-A93D-81B91C56432C hm-test-widget.SwiftFunctionProject | grep -oE '[0-9]+$' | head -1)
xcrun simctl spawn FB74ECC0-DDCA-4168-A93D-81B91C56432C leaks $PID 2>&1 | tail -15
```
预期：`leaks` 报告无 `HYMChartTooltip*` / `HYMChartTooltipController` / `CADisplayLink` 相关泄漏（重点确认反复点击切换弹窗、进出页面后无泄漏）。

- [ ] **Step 5: 完成确认**

所有 12 个 Task 编译通过、自检全绿、截图与 leaks 正常即视为完成。按项目约定**不主动 commit**；如用户要求提交，再执行 git add/commit。

---

## Self-Review（计划自检）

**1. Spec 覆盖：**
- 弹窗位置局限可显示区域 + 上/下避让 + 极端重叠 → Task 1（`resolve` 裁进 container + 翻转 + squeeze）。
- 内容默认 value、每点可指定 → Task 8（`format` + `cell.tooltipText` 优先）。
- nil 占位不绘制不点击不参与色阶 → Task 7（`isValid`/`placeholder`）+ Task 8（render `guard`）。
- 通用层 + 协议槽位 → Task 1–6。
- 外观主题化（不嵌入图表 Theme） → Task 2 + Task 6（`HYMChartView.tooltipTheme`）。
- OC 兼容 → Task 10。
- SwiftUI → Task 11。
- 自检 → Task 1/5/7/8 + Task 12 运行。
- 兼容性（默认实现、默认字段值、雷达图零改动） → Task 5/6/7/9。

**2. 占位符扫描：** 无 TBD/TODO；每个代码步骤含完整代码。

**3. 类型一致性：**
- `HYMChartTooltipAnchor(frame:preferredPlacements:)` —— Task 5 定义，Task 8 使用，签名一致。
- `tooltipAnchor(for:)` —— Task 5 协议默认、Task 8 热力图实现，签名一致。
- `tooltipText` —— Task 5 协议默认、Task 8 `HeatmapHitTarget` 存储属性，一致。
- `format(_:)` —— Task 8 定义为 `static`、自检以 `HeatmapChartRenderer.format(...)` 调用，一致。
- `showsTooltipOnHit` —— Task 9 Theme 字段、Task 8 Renderer 引用、Task 10 ThemeBuilder/ViewBridge、Task 11 未直接用（走通用 `chart.showsTooltipOnHit`），一致。
- `HYMChartTooltipController.show(anchor:text:in:preferred:)` —— Task 4 定义、Task 6 调用，签名一致。
- `HeatmapCell.init(value:maxValue:color:isValid:tooltipText:)` —— Task 7 定义、Task 8/10/11 使用，一致。

**4. 已知顺序依赖：** Task 8 Step 6 引用 Task 9 的 `showsTooltipOnHit`，故 Task 8 Step 7 单独编译会失败（已在 Task 8 Step 7 注明，Task 9 完成后通过）。其余 Task 可独立编译。
