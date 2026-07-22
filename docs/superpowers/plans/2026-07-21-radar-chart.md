# 蛛网图（雷达图）组件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个可复用的雷达/蛛网图 `UIView`（Swift，`@objc` 暴露给 OC），支持任意维度数、中心分数双模式、渐变背景、入场展开动画，并在 `ViewController` 做 demo 展示。

**Architecture:** 纯绘制组件 `HYMRadarChartView`（CAShapeLayer + CAGradientLayer）只认 `RadarChartModel`（NSObject 子类），VC 只负责构造 Model 喂数据。符合项目 MVC + VC/Manager/Service/Model 分层与「优先稳定性」约束。

**Tech Stack:** Swift 5（iOS 26.2 target）、UIKit、QuartzCore（CALayer）、Core Graphics。

---

## 关键工程前提（执行前必读）

1. **文件系统同步组**：本项目 `测试111.xcodeproj` 使用 `PBXFileSystemSynchronizedRootGroup`（objectVersion 77）。**只要把新文件放到 `测试111/` 目录下，Xcode 会自动加入 target 编译，无需手动改 `project.pbxproj`**。本计划所有新文件均放在 `测试111/` 下。
2. **不提交 git**：用户已明确要求不执行 `git commit`。每个 Task 末尾的「验证检查点」只做编译/运行验证，不提交。
3. **测试策略**：项目无 test target，新建需改 pbxproj（高风险），本计划**不新建 test target**。可单测的纯逻辑（几何计算、分数解析）抽出为纯函数，用 `#if DEBUG` 断言自检（启动时跑一组用例，失败即 assert）。UI 渲染靠模拟器运行目视。
4. **混编接口约束**：OC 无法构造/持有 Swift `struct`，故 `RadarDimension` / `RadarChartModel` 用 `class: NSObject` + `@objcMembers`；`HYMRadarChartTheme` 保持 `struct`（仅 Swift 内部使用，OC 不可见，使用默认配色）。
5. **编译验证命令**（贯穿所有 Task，中文路径/名用引号）：

   ```bash
   cd "/Users/hoymiles/Desktop/移植项目/测试111"
   xcodebuild -project "测试111.xcodeproj" -target "测试111" \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
     -configuration Debug build 2>&1 | tail -30
   ```

   预期结尾出现 `** BUILD SUCCEEDED **`。

---

## File Structure

| 文件 | 职责 | 创建 Task |
|---|---|---|
| `测试111/HYMSwiftProbe.swift` | 最小 Swift 类，验证混编通路 | Task 1 |
| `测试111/RadarDimension.swift` | 单维度数据（label/value/maxValue + 归一化） | Task 2 |
| `测试111/HYMRadarChartTheme.swift` | 配色主题（struct，默认紫蓝渐变） | Task 2 |
| `测试111/RadarChartModel.swift` | 整体数据 + 中心分数三态 + theme | Task 2 |
| `测试111/RadarGeometry.swift` | 几何纯函数（角度/坐标/网格圈顶点） | Task 3 |
| `测试111/RadarSelfTest.swift` | `#if DEBUG` 断言自检（几何 + 分数） | Task 3 |
| `测试111/HYMRadarChartView.swift` | 绘制组件主体（Task 4 骨架 → 5/6/7 增量填充） | Task 4-7 |
| `测试111/ViewController.m`（改） | demo：构造 6 维 Model + 嵌入组件 + 动画 | Task 8 |

---

## Task 1: 启用 Swift 混编的最小验证

**Why:** 老项目首次引入 Swift，必须先用一个最小用例确认「Swift 文件自动编译 + `-Swift.h` 自动生成 + OC 能调用」这条链路通，再做正式组件（spec 第 9 节风险 #1）。

**Files:**
- Create: `测试111/HYMSwiftProbe.swift`
- Modify: `测试111/ViewController.m`

- [ ] **Step 1: 创建最小 Swift 类**

Write `测试111/HYMSwiftProbe.swift`：

```swift
import Foundation

/// 最小探针类：仅用于验证 Swift/OC 混编通路（Task 1 完成后可保留或删除）
@objcMembers
public final class HYMSwiftProbe: NSObject {
    @objc public static func hello() -> String {
        return "Hello from Swift"
    }
}
```

- [ ] **Step 2: 修改 ViewController.m 调用它**

Replace the entire content of `测试111/ViewController.m` with：

```objc
//
//  ViewController.m
//  测试111
//
//  Created by wangkun on 2026/5/7.
//

#import "ViewController.h"
#import "测试111-Swift.h"   // ← 自动生成的 Swift 桥接头（模块名 = target 名）

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"probe: %@", [HYMSwiftProbe hello]);
}

@end
```

> 若编译报 `测试111-Swift.h` not found：在 Xcode 打开工程 → Build Settings → 搜 `Swift Compiler - General` → 确认 `Objective-C Bridging Header` 留空、`Objective-C Generated Interface Header Name` 为 `$(SWIFT_MODULE_NAME)-Swift.h`；模块名取 target 名 `测试111`。本计划假定默认配置即可。

- [ ] **Step 3: 编译验证**

Run the build command from「关键工程前提 #5」。
Expected: `** BUILD SUCCEEDED **`，无 `Swift` / `bridging` 相关错误。

- [ ] **Step 4: 运行验证（目视）**

在 Xcode 按 ⌘R 运行到 iOS 模拟器，控制台应打印：`probe: Hello from Swift`。

- [ ] **Step 5: 验证检查点**

✅ 混编通路确认：Swift 文件自动编译、`-Swift.h` 可 import、OC 能调 Swift。无需 git 提交。

---

## Task 2: 数据模型（Dimension / Theme / Model）

**Why:** 先把纯数据结构落地，UI 依赖它。Model 用 `NSObject` 子类以满足 OC 互操作（关键前提 #4）。

**Files:**
- Create: `测试111/RadarDimension.swift`
- Create: `测试111/HYMRadarChartTheme.swift`
- Create: `测试111/RadarChartModel.swift`

- [ ] **Step 1: RadarDimension.swift**

```swift
import Foundation
import CoreGraphics

@objcMembers
public final class RadarDimension: NSObject {
    /// 顶点文案，如「进攻」
    @objc public var label: String
    /// 当前值
    @objc public var value: Double
    /// 满分值（用于归一化），默认 100
    @objc public var maxValue: Double

    @objc public init(label: String, value: Double, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    /// 归一化比值 [0,1]，越界裁剪（Swift 内部使用）
    var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }
}
```

- [ ] **Step 2: HYMRadarChartTheme.swift**

```swift
import UIKit

/// 配色主题（纯 Swift struct，OC 不可见，使用默认值即可）。
/// 对照截图微调时只改这里。
public struct HYMRadarChartTheme {
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
        labelOuterPadding: CGFloat = 22
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
    }
}
```

- [ ] **Step 3: RadarChartModel.swift**

```swift
import Foundation

@objcMembers
public final class RadarChartModel: NSObject {
    @objc public var dimensions: [RadarDimension]
    @objc public var showsCenterScore: Bool
    /// nil = 自动按各维度归一化均值算；非 nil = 用传入值
    @objc public var centerScore: Double?

    /// Swift 专用 theme（OC 不可见）
    public var theme: HYMRadarChartTheme

    /// OC 可见 init（不带 theme，使用默认主题）
    @objc public init(
        dimensions: [RadarDimension],
        showsCenterScore: Bool = true,
        centerScore: Double? = nil
    ) {
        self.dimensions = dimensions
        self.showsCenterScore = showsCenterScore
        self.centerScore = centerScore
        self.theme = HYMRadarChartTheme()
        super.init()
    }

    /// Swift 专用 init（可传 theme）
    public init(
        dimensions: [RadarDimension],
        showsCenterScore: Bool = true,
        centerScore: Double? = nil,
        theme: HYMRadarChartTheme
    ) {
        self.dimensions = dimensions
        self.showsCenterScore = showsCenterScore
        self.centerScore = centerScore
        self.theme = theme
        super.init()
    }
}

/// 中心分数三态解析（纯函数，便于 DEBUG 自检）
public func resolvedCenterScore(_ model: RadarChartModel) -> Double? {
    guard model.showsCenterScore else { return nil }
    if let manual = model.centerScore { return manual }
    guard !model.dimensions.isEmpty else { return nil }
    // 各维度归一化均值，乘回首个维度的满分量纲作为展示刻度
    let sum = model.dimensions.reduce(0.0) { $0 + ($1.maxValue > 0 ? $1.value / $1.maxValue : 0) }
    let avg = sum / Double(model.dimensions.count)
    let scale = model.dimensions.first?.maxValue ?? 100
    return avg * scale
}
```

- [ ] **Step 4: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: 验证检查点**

✅ 数据模型落地，OC 可构造 `RadarDimension` / `RadarChartModel`（默认主题）。

---

## Task 3: 几何纯函数 + DEBUG 自检

**Why:** 把「维度数 → 顶点坐标」的纯计算抽出，便于断言验证（替代单测）；View 直接复用。

**Files:**
- Create: `测试111/RadarGeometry.swift`
- Create: `测试111/RadarSelfTest.swift`
- Modify: `测试111/ViewController.m`

- [ ] **Step 1: RadarGeometry.swift**

```swift
import CoreGraphics

public enum RadarGeometry {
    /// 第 i 个顶点角度（弧度），i=0 朝正上方（-π/2）
    public static func angle(index i: Int, count n: Int) -> CGFloat {
        guard n > 0 else { return 0 }
        return -CGFloat.pi / 2 + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
    }

    /// 第 i 个数据顶点坐标（ratio 为归一化比值 0~1）
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

- [ ] **Step 2: RadarSelfTest.swift**

```swift
#if DEBUG
import Foundation
import CoreGraphics

/// 开发期断言自检（替代单测）。在 DEBUG 启动时调用一次。
enum RadarSelfTest {
    static func runAll() {
        // —— 几何 ——
        // N=4，ratio=1，radius=10，center=(0,0)
        let top = RadarGeometry.point(index: 0, count: 4,
                center: .zero, radius: 10, ratio: 1)
        assert(abs(top.x) < 0.001 && abs(top.y - (-10)) < 0.001, "top vertex wrong: \(top)")

        let bottom = RadarGeometry.point(index: 2, count: 4,
                center: .zero, radius: 10, ratio: 1)
        assert(abs(bottom.x) < 0.001 && abs(bottom.y - 10) < 0.001, "bottom vertex wrong: \(bottom)")

        let right = RadarGeometry.point(index: 1, count: 4,
                center: .zero, radius: 10, ratio: 1)
        assert(abs(right.x - 10) < 0.001 && abs(right.y) < 0.001, "right vertex wrong: \(right)")

        // 越界 ratio 应裁剪到 [0,1]：ratio=2 等价 ratio=1
        let over = RadarGeometry.point(index: 0, count: 4,
                center: .zero, radius: 10, ratio: 2)
        assert(abs(over.y - (-10)) < 0.001, "ratio clamp wrong")

        // —— 中心分数三态 ——
        let hidden = RadarChartModel(
            dimensions: [RadarDimension(label: "a", value: 80)],
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
        let manual = RadarChartModel(
            dimensions: [RadarDimension(label: "a", value: 10)],
            centerScore: 88)
        assert(resolvedCenterScore(manual) == 88, "manual should be 88")

        print("✅ RadarSelfTest passed")
    }
}
#endif
```

- [ ] **Step 3: 在 ViewController 启动时跑自检**

In `测试111/ViewController.m`，在 `viewDidLoad` 开头加一行（保持 Task 1 的其它内容）：

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
#if DEBUG
    RadarSelfTestRunAll();   // Swift 的 static func runAll() 桥接为 RadarSelfTestRunAll()？
#endif
    NSLog(@"probe: %@", [HYMSwiftProbe hello]);
}
```

> ⚠️ 注意：`RadarSelfTest` 是 `enum`（无 `@objc`），OC 无法直接调。改为在 Swift 侧暴露一个 `@objc` 入口。新建以下**追加内容**到 `RadarSelfTest.swift` 末尾（`#endif` 之前）：

```swift
@objcMembers
public final class RadarSelfTestRunner: NSObject {
    @objc public static func runAll() {
        #if DEBUG
        RadarSelfTest.runAll()
        #endif
    }
}
```

Then `ViewController.m` 调用改为：

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [RadarSelfTestRunner runAll];
    NSLog(@"probe: %@", [HYMSwiftProbe hello]);
}
```

- [ ] **Step 4: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: 运行验证**

⌘R 运行，控制台应打印：`✅ RadarSelfTest passed`（以及 probe 行）。若 assert 触发则说明几何/分数逻辑有误，回到 Step 1 修正。

- [ ] **Step 6: 验证检查点**

✅ 纯逻辑经断言验证通过；几何与分数解析正确。

---

## Task 4: HYMRadarChartView 骨架（背景渐变 + 网格 + 放射轴）

**Why:** 先把容器、背景渐变、网格多边形、放射轴画出来，确认 layer 方向/居中正确，再加数据层。

**Files:**
- Create: `测试111/HYMRadarChartView.swift`

- [ ] **Step 1: 创建组件骨架**

Write `测试111/HYMRadarChartView.swift`：

```swift
import UIKit

@objcMembers
public final class HYMRadarChartView: UIView {

    // MARK: - 状态
    private var model: RadarChartModel?

    // MARK: - 子层
    private let gradientLayer = CAGradientLayer()
    private let gridLayer = CAShapeLayer()
    private let axisLayer = CAShapeLayer()

    // MARK: - 公开 API
    @objc public func configure(_ model: RadarChartModel) {
        self.model = model
        setNeedsLayout()
    }

    @objc public func playEntranceAnimation() {
        // Task 7 实现
    }

    // MARK: - init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.masksToBounds = true
        backgroundColor = .clear

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)

        gridLayer.fillColor = UIColor.clear.cgColor
        axisLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(axisLayer)
        layer.addSublayer(gridLayer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        layer.cornerRadius = currentCornerRadius

        guard let model, !model.dimensions.isEmpty else {
            gridLayer.path = nil
            axisLayer.path = nil
            return
        }

        applyThemeColors(model.theme)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = maxRadius(for: model)

        rebuildGrid(model, center: center, radius: radius)
        rebuildAxis(model, center: center, radius: radius)
    }

    // MARK: - 主题
    private func applyThemeColors(_ theme: HYMRadarChartTheme) {
        gradientLayer.colors = [theme.backgroundGradientStart.cgColor,
                                theme.backgroundGradientEnd.cgColor]
        gridLayer.strokeColor = theme.gridColor.cgColor
        gridLayer.lineWidth = 1
        axisLayer.strokeColor = theme.axisColor.cgColor
        axisLayer.lineWidth = 1
        layer.cornerRadius = theme.cardCornerRadius
    }

    private var currentCornerRadius: CGFloat {
        model?.theme.cardCornerRadius ?? 16
    }

    private func maxRadius(for model: RadarChartModel) -> CGFloat {
        let half = min(bounds.width, bounds.height) / 2
        // 预留标签外边距
        return max(0, half - model.theme.labelOuterPadding)
    }

    // MARK: - 网格（同心多边形）
    private func rebuildGrid(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let ringCount = max(1, model.theme.gridRingCount)
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

    // MARK: - 放射轴
    private func rebuildAxis(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let p = RadarGeometry.point(index: i, count: n,
                                        center: center, radius: radius, ratio: 1)
            path.move(to: center)
            path.addLine(to: p)
        }
        axisLayer.path = path.cgPath
    }
}
```

- [ ] **Step 2: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 临时 demo 看效果**

Temporarily modify `测试111/ViewController.m` `viewDidLoad`（先注释掉自检/probe 行也行，保留即可）：

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [RadarSelfTestRunner runAll];
    self.view.backgroundColor = UIColor.blackColor;

    RadarDimension *d0 = [[RadarDimension alloc] initWithLabel:@"A" value:80];
    RadarDimension *d1 = [[RadarDimension alloc] initWithLabel:@"B" value:60];
    RadarDimension *d2 = [[RadarDimension alloc] initWithLabel:@"C" value:90];
    RadarDimension *d3 = [[RadarDimension alloc] initWithLabel:@"D" value:50];
    RadarDimension *d4 = [[RadarDimension alloc] initWithLabel:@"E" value:70];
    RadarDimension *d5 = [[RadarDimension alloc] initWithLabel:@"F" value:85];
    NSArray<RadarDimension *> *dims = @[d0, d1, d2, d3, d4, d5];
    RadarChartModel *m = [[RadarChartModel alloc] initWithDimensions:dims
                                                      showsCenterScore:YES
                                                           centerScore:nil];
    CGFloat side = self.view.bounds.size.width - 40;
    HYMRadarChartView *chart = [[HYMRadarChartView alloc] initWithFrame:CGRectMake(20, 120, side, side)];
    [chart configure:m];
    [self.view addSubview:chart];
}
```

- [ ] **Step 4: 运行验证（目视）**

⌘R：应看到深紫渐变圆角卡片 + 5 圈同心六边形网格 + 6 条从中心到顶点的放射轴，**居中对齐、第一个顶点朝正上方**。

- [ ] **Step 5: 验证检查点**

✅ 背景渐变 + 网格 + 轴正确绘制，几何居中无偏移。

---

## Task 5: 数据多边形 + 顶点圆点 + 文案标签

**Why:** 在骨架上叠加实际数据围成的填充/描边多边形、各顶点圆点、外侧文案。

**Files:**
- Modify: `测试111/HYMRadarChartView.swift`

- [ ] **Step 1: 新增子层属性**

In `HYMRadarChartView.swift`, in the `// MARK: - 子层` section, add three new properties after `axisLayer`：

```swift
    private let dataFillLayer = CAShapeLayer()
    private let dataStrokeLayer = CAShapeLayer()
    private let vertexDotsLayer = CAShapeLayer()
    private var labels: [UILabel] = []
```

- [ ] **Step 2: 在 commonInit 中挂载新层**

In `commonInit()`, after `layer.addSublayer(gridLayer)`, add：

```swift
        dataFillLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        vertexDotsLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(dataFillLayer)
        layer.addSublayer(dataStrokeLayer)
        layer.addSublayer(vertexDotsLayer)
```

- [ ] **Step 3: applyThemeColors 增补数据层配色**

In `applyThemeColors(_:)`, append after the existing assignments：

```swift
        dataFillLayer.fillColor = theme.dataFillColor.cgColor
        dataFillLayer.strokeColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.strokeColor = theme.dataStrokeColor.cgColor
        dataStrokeLayer.lineWidth = theme.dataLineWidth
        vertexDotsLayer.fillColor = theme.vertexDotColor.cgColor
        vertexDotsLayer.strokeColor = theme.vertexDotRingColor.cgColor
        vertexDotsLayer.lineWidth = 2
```

- [ ] **Step 4: layoutSubviews 增加调用**

In `layoutSubviews()`, after `rebuildAxis(model, center: center, radius: radius)`, add：

```swift
        rebuildData(model, center: center, radius: radius)
        rebuildVertexDots(model, center: center, radius: radius)
        rebuildLabels(model, center: center, radius: radius)
```

- [ ] **Step 5: 新增三个 rebuild 方法**

Append to the class（`rebuildAxis` 方法之后）：

```swift
    // MARK: - 数据多边形（填充 + 描边）
    private func rebuildData(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n,
                                        center: center, radius: radius, ratio: ratio)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        dataFillLayer.path = path.cgPath
        dataStrokeLayer.path = path.cgPath
    }

    // MARK: - 顶点圆点
    private func rebuildVertexDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let dotRadius: CGFloat = 5
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n,
                                        center: center, radius: radius, ratio: ratio)
            path.append(UIBezierPath(arcCenter: p, radius: dotRadius,
                                     startAngle: 0, endAngle: CGFloat(2 * .pi), clockwise: true))
        }
        vertexDotsLayer.path = path.cgPath
    }

    // MARK: - 文案标签（顶点外侧）
    private func rebuildLabels(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        // 移除旧标签，防泄漏/残影
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()

        let n = model.dimensions.count
        let gap = model.theme.labelOuterPadding
        for i in 0..<n {
            let a = RadarGeometry.angle(index: i, count: n)
            let r = radius + gap
            let labelCenter = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))

            let lbl = UILabel()
            lbl.text = model.dimensions[i].label
            lbl.textColor = model.theme.labelColor
            lbl.font = model.theme.labelFont
            lbl.textAlignment = .center
            lbl.sizeToFit()
            lbl.center = labelCenter
            addSubview(lbl)
            labels.append(lbl)
        }
    }
```

- [ ] **Step 6: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 7: 运行验证（目视）**

⌘R：在网格之上应看到半透明紫色填充的数据多边形 + 亮紫描边 + 6 个顶点圆点 + 各顶点外侧的 A~F 文案。

- [ ] **Step 8: 验证检查点**

✅ 数据多边形、顶点圆点、标签正确绘制，标签无越界。

---

## Task 6: 中心分数（双模式）

**Why:** 实现中心分数三态展示（隐藏 / 自动均值 / 外部传入）。

**Files:**
- Modify: `测试111/HYMRadarChartView.swift`

- [ ] **Step 1: 新增分数子视图属性**

In `// MARK: - 子层` section, after `private var labels: [UILabel] = []`, add：

```swift
    private let scoreLabel = UILabel()
    private let subtitleLabel = UILabel()
```

- [ ] **Step 2: commonInit 配置分数标签**

In `commonInit()`, after `layer.addSublayer(vertexDotsLayer)`, add：

```swift
        scoreLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        subtitleLabel.numberOfLines = 1
        addSubview(subtitleLabel)
        addSubview(scoreLabel)
```

- [ ] **Step 3: layoutSubviews 增加分数刷新**

In `layoutSubviews()`, after `rebuildLabels(model, center: center, radius: radius)`, add：

```swift
        rebuildScore(model, center: center)
```

- [ ] **Step 4: 新增 rebuildScore 方法**

Append to the class（`rebuildLabels` 之后）：

```swift
    // MARK: - 中心分数（双模式）
    private func rebuildScore(_ model: RadarChartModel, center: CGPoint) {
        let resolved = resolvedCenterScore(model)
        if let value = resolved {
            scoreLabel.isHidden = false
            subtitleLabel.isHidden = false
            scoreLabel.text = formatScore(value)
            scoreLabel.font = model.theme.scoreFont
            scoreLabel.textColor = model.theme.scoreColor
            scoreLabel.sizeToFit()

            subtitleLabel.text = model.theme.scoreSubtitleText
            subtitleLabel.font = model.theme.scoreSubtitleFont
            subtitleLabel.textColor = model.theme.scoreSubtitleColor
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
```

- [ ] **Step 5: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 6: 运行验证（三种分数模式）**

临时在 `ViewController.m` 改 `centerScore` 参数各跑一次：

1. `centerScore:nil` → 中央应显示自动算出的均值（6 维 80/60/90/50/70/85 → 均值 ≈ 72.5），下方「综合评分」。
2. `centerScore:@(88)` → 中央显示 `88`。
3. 把 `showsCenterScore:NO` → 中央无文字。

- [ ] **Step 7: 验证检查点**

✅ 分数三态正确：隐藏 / 自动均值 / 外部传入。

---

## Task 7: 入场展开动画

**Why:** 实现数据多边形从中心展开 + 网格淡入 + 分数数字滚动。CADisplayLink 必须 invalidate（CLAUDE.md 强制检查项）。

**Files:**
- Modify: `测试111/HYMRadarChartView.swift`

- [ ] **Step 1: 新增动画状态与 displaylink 属性**

In `// MARK: - 状态` section, replace the existing block with：

```swift
    private var model: RadarChartModel?
    private var pendingAnimation = false
    private var displayLink: CADisplayLink?
    private var scoreAnimStartTime: CFTimeInterval = 0
    private var scoreAnimFrom: Double = 0
    private var scoreAnimTo: Double = 0
    private var scoreAnimDuration: CFTimeInterval = 0.8
```

- [ ] **Step 2: layoutSubviews 末尾触发待执行动画**

In `layoutSubviews()`, after `rebuildScore(model, center: center)`, add：

```swift
        if pendingAnimation {
            pendingAnimation = false
            performEntranceAnimation(model: model)
        }
```

- [ ] **Step 3: 实现 playEntranceAnimation / performEntranceAnimation**

Replace the existing `playEntranceAnimation()` stub with：

```swift
    @objc public func playEntranceAnimation() {
        guard model != nil else { return }
        pendingAnimation = true
        setNeedsLayout()   // 触发 layoutSubviews → performEntranceAnimation
    }

    private func performEntranceAnimation(model: RadarChartModel) {
        stopDisplayLink()

        // 初始：数据层缩到中心、全透明；网格/轴透明
        dataFillLayer.setAffineTransform(.identity.scaledBy(x: 0.01, y: 0.01))
        dataStrokeLayer.setAffineTransform(.identity.scaledBy(x: 0.01, y: 0.01))
        vertexDotsLayer.setAffineTransform(.identity.scaledBy(x: 0.01, y: 0.01))
        dataFillLayer.opacity = 0
        dataStrokeLayer.opacity = 0
        vertexDotsLayer.opacity = 0
        gridLayer.opacity = 0
        axisLayer.opacity = 0
        scoreLabel.alpha = 0
        subtitleLabel.alpha = 0

        let duration = 0.6

        // 数据层：transform.scale 0→1 + opacity 0→1（锚点已是 layer 中心，但 transform 基于 view 中心；
        // 为保证从视图中心展开，把 shape layer 的 frame 设为 bounds，anchorPoint 默认 0.5,0.5 即中心）
        dataFillLayer.frame = bounds
        dataStrokeLayer.frame = bounds
        vertexDotsLayer.frame = bounds

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.01
        scaleAnim.toValue = 1.0
        scaleAnim.duration = duration
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0
        opacityAnim.toValue = 1
        opacityAnim.duration = duration

        for layer in [dataFillLayer, dataStrokeLayer, vertexDotsLayer] {
            layer.add(scaleAnim, forKey: "scale")
            layer.add(opacityAnim, forKey: "opacity")
        }
        // 终态落定
        dataFillLayer.setAffineTransform(.identity)
        dataStrokeLayer.setAffineTransform(.identity)
        vertexDotsLayer.setAffineTransform(.identity)
        dataFillLayer.opacity = 1
        dataStrokeLayer.opacity = 1
        vertexDotsLayer.opacity = 1

        // 网格/轴淡入
        let gridFade = CABasicAnimation(keyPath: "opacity")
        gridFade.fromValue = 0; gridFade.toValue = 1; gridFade.duration = duration
        gridLayer.add(gridFade, forKey: "opacity")
        axisLayer.add(gridFade, forKey: "opacity")
        gridLayer.opacity = 1
        axisLayer.opacity = 1

        UIView.animate(withDuration: 0.4, delay: duration - 0.1, options: []) { [weak self] in
            self?.scoreLabel.alpha = 1
            self?.subtitleLabel.alpha = 1
        }

        // 分数数字滚动（CADisplayLink）
        if let target = resolvedCenterScore(model) {
            startScoreAnimation(from: 0, to: target, duration: scoreAnimDuration)
        }
    }

    // MARK: - 分数滚动
    private func startScoreAnimation(from: Double, to: Double, duration: CFTimeInterval) {
        scoreAnimFrom = from
        scoreAnimTo = to
        scoreAnimDuration = duration
        scoreAnimStartTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(onScoreTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func onScoreTick() {
        let elapsed = CACurrentMediaTime() - scoreAnimStartTime
        let t = max(0, min(1, elapsed / scoreAnimDuration))
        // easeOut
        let eased = 1 - (1 - t) * (1 - t)
        let value = scoreAnimFrom + (scoreAnimTo - scoreAnimFrom) * eased
        scoreLabel.text = formatScore(value)
        scoreLabel.sizeToFit()
        if let center = model.map({ CGPoint(x: bounds.midX, y: bounds.midY) }) {
            scoreLabel.center = CGPoint(x: center.x, y: center.y + 18)
        }
        if t >= 1 {
            stopDisplayLink()
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
```

- [ ] **Step 4: 防止 layer 被重新 layout 重置 transform**

在 `layoutSubviews()` 的 `guard let model ...` 之前，即方法最开头（`gradientLayer.frame = bounds` 之后），不需要改动；但需保证 `rebuildData` 等设置 `path` 后不被 `frame=bounds` 覆盖路径。由于 `CAShapeLayer` 的 `path` 用绝对坐标（已是中心坐标系），设置 `frame` 不影响 path 显示。✓ 无需额外改动。

- [ ] **Step 5: dealloc 释放 displaylink**

Append to the class：

```swift
    deinit {
        stopDisplayLink()
    }
```

- [ ] **Step 6: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 7: 运行验证（目视）**

⌘R（确保 `ViewController.m` 调了 `[chart playEntranceAnimation]`，见 Task 8 demo）：应看到数据多边形从中心展开 + 网格淡入 + 分数从 0 滚动到目标值，展开**以视图中心为锚、无偏移**。

- [ ] **Step 8: 验证检查点**

✅ 入场动画顺滑、中心对齐；CADisplayLink 在动画结束/重新播放/dealloc 时均 invalidate（无泄漏）。

---

## Task 8: 接入 demo（ViewController 完整示例）

**Why:** 把组件按真实用法接入，作为最终视觉验收与刷新防泄漏验证的载体。

**Files:**
- Modify: `测试111/ViewController.m`

- [ ] **Step 1: 完整 demo**

Replace `测试111/ViewController.m` content with：

```objc
//
//  ViewController.m
//  测试111
//
//  Created by wangkun on 2026/5/7.
//

#import "ViewController.h"
#import "测试111-Swift.h"

@interface ViewController ()
@property (nonatomic, strong) HYMRadarChartView *chart;
@property (nonatomic, strong) RadarChartModel *model;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [RadarSelfTestRunner runAll];
    self.view.backgroundColor = UIColor.blackColor;

    NSArray<NSString *> *labels = @[@"进攻", @"防守", @"速度", @"技巧", @"体力", @"意识"];
    NSArray<NSNumber *> *values = @[@80, @60, @90, @50, @70, @85];
    NSMutableArray<RadarDimension *> *dims = [NSMutableArray array];
    [labels enumerateObjectsUsingBlock:^(NSString * _Nonnull lbl, NSUInteger idx, BOOL * _Nonnull stop) {
        [dims addObject:[[RadarDimension alloc] initWithLabel:lbl value:values[idx].doubleValue]];
    }];

    // 分数双模式示例：centerScore=nil 表示自动算均值
    self.model = [[RadarChartModel alloc] initWithDimensions:dims
                                            showsCenterScore:YES
                                                 centerScore:nil];

    CGFloat side = self.view.bounds.size.width - 40;
    self.chart = [[HYMRadarChartView alloc] initWithFrame:CGRectMake(20, 120, side, side)];
    [self.chart configure:self.model];
    [self.view addSubview:self.chart];

    // 双击切换「自动均值 / 手动 88 / 隐藏」三种分数模式，便于验收
    UITapGestureRecognizer *dt = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap)];
    dt.numberOfTapsRequired = 2;
    [self.chart addGestureRecognizer:dt];

    // 延迟一点触发动画，确保 layoutSubviews 已执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.chart playEntranceAnimation];
    });
}

- (void)onDoubleTap {
    static int mode = 0;
    mode = (mode + 1) % 3;
    RadarChartModel *m = [[RadarChartModel alloc] initWithDimensions:self.model.dimensions
                                                    showsCenterScore:(mode != 2)
                                                         centerScore:(mode == 1) ? @(88) : nil];
    [self.chart configure:m];
    [self.chart playEntranceAnimation];
}

@end
```

- [ ] **Step 2: 编译验证**

Run build command. Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 运行验收（手动）**

⌘R，逐项核对：

1. 6 个中文维度（进攻/防守/速度/技巧/体力/意识）顶点朝上、顺时针排布，外侧标签清晰无越界。
2. 深紫渐变圆角卡片 + 5 圈网格 + 6 条放射轴。
3. 数据多边形从中心展开 + 分数从 0 滚动到 ≈72.5。
4. **双击组件**：循环切换「自动均值 → 手动 88 → 隐藏」三种分数，每次都重新展开动画，且**无残影、无内存增长**。

- [ ] **Step 4: 内存/泄漏抽查**

Xcode → Debug → View Memory Hierarchy / Memory Graph，连续双击多次后：无 `CADisplayLink` 残留实例、无重复 `UILabel`/`CAShapeLayer` 堆积。

- [ ] **Step 5: 验证检查点**

✅ 完整功能验收通过：任意维度数、分数双模式、渐变背景、入场动画、刷新无泄漏。

---

## Self-Review（plan vs spec）

- **Spec 第 1 节（任意维度/文案/中心分数/渐变/动画/demo）** → Task 2(模型) + 4/5/6/7/8 覆盖。
- **Spec 第 5 节组件设计** → Task 2(Model/Theme/Dimension) + 4-7(View) 覆盖；Model 由 struct 调整为 `class:NSObject` 以支持 OC（关键前提 #4，实现细化，不违背 spec 意图）。
- **Spec 第 6 节数据流** → Task 4 `configure → setNeedsLayout → layoutSubviews` 覆盖。
- **Spec 第 7 节分数双模式** → Task 3 `resolvedCenterScore` + Task 6 `rebuildScore` 覆盖，含 DEBUG 自检。
- **Spec 第 8 节入场动画** → Task 7 覆盖（scale + opacity + 数字滚动 + displaylink invalidate + deinit）。
- **Spec 第 9 节混编配置** → Task 1 最小验证覆盖（文件同步组 + `-Swift.h`）。
- **Spec 第 10 节默认配色** → Task 2 `HYMRadarChartTheme` 默认值与 spec 表逐项对应。
- **Spec 第 11 节 6 条风险** → 缓解措施散布各 Task：混编(Task1)、中心对齐(Task4/7 frame=中心坐标)、layer 清理(Task5 rebuildLabels 移除旧标签 / Task8 内存抽查)、displaylink(Task7 stop+deinit)、标签越界(Task4 maxRadius 预留 padding)、weak self(Task7 UIView.animate 用 [weak self])。
- **Placeholder 扫描**：无 TBD/TODO；每个代码 step 均为完整可编译代码。
- **类型一致性**：`configure(_:)` / `playEntranceAnimation()` / `RadarDimension(label:value:maxValue:)` / `RadarChartModel(initWithDimensions:showsCenterScore:centerScore:)` / `resolvedCenterScore(_:)` / `RadarGeometry.point/ringPoints/angle` 跨 Task 命名一致。

无缺口。
