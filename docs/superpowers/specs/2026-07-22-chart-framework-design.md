# 通用图表框架（HYMCharts）设计

> 日期：2026-07-22
> 状态：待审阅
> 负责人：wangkun
> 前序文档：
> - `specs/2026-07-21-radar-chart-design.md`（雷达图原始设计）
> - `plans/2026-07-21-radar-chart-progress.md`（雷达图 Task 1-9 已完成）

## 1. 概述与目标

把现有的「蛛网图（雷达图）」从一次性的 OC 移植产物，重构为**一套通用图表框架 `HYMCharts`** 的首个落地实现，为后续持续接入的新图表类型（柱状/折线/饼等）打好可扩展地基。

本次目标：

- 抽取一套 **Protocol-First、纯 Swift** 的通用图表内核（容器 / 渲染器 / 主题 / 数据 / 动画 / 几何 / 错误 / 交互）。
- 把雷达图迁移到框架下，**去除全部 OC 痕迹**（`NSObject` / `@objcMembers` / `NSNumber?` / `@nonobjc` / 双 `init` / 硬编码 demo 配置）。
- 提供一层 **OC Wrapper（OCBridge）**，让 OC 项目能完整使用雷达图。
- 提供 **SwiftUI `RadarChart` 封装**，让当前 SwiftUI App 开箱即用。
- 在框架层规划 **交互（命中/点击）能力**，蛛网图具体命中目标留待后续。

## 2. 背景与现状问题

| # | 现状 | 问题 |
|---|---|---|
| 1 | `RadarDimension` / `RadarChartModel` 为 `NSObject` + `@objcMembers` | 与「纯 Swift SDK」定位冲突，类型笨重 |
| 2 | `RadarChartModel.centerScore` 为 `NSNumber?`（因 `Double?` 不能 `@objc`），`theme` 标 `@nonobjc`，存在 OC/Swift 双 `init` | OC 适配逻辑污染了数据层 |
| 3 | `RadarChartModel` 的 OC `init` 内硬编码 `UIColor(named:"Green")!` / `gridRingFill` / `showsAxes=false` 等 demo 配置 | 违反「Model 不带业务默认值」「最小暴露」；`UIColor(named:)!` 强解包无对应资源会**崩溃** |
| 4 | `HYMRadarChartView` 427 行，容器布局 + 全部绘制 + 动画混在一起 | 无法复用、不可测试、违背单一职责 |
| 5 | `HYMSwiftProbe.swift`、`RadarSelfTestRunner`（`@objc` 包装） | OC 混编探针/桥接残留，纯 Swift SDK 无用 |
| 6 | `ContentView.swift` 仍是 Xcode 默认模板 | 组件从未在 App 中实际接入展示 |
| 7 | 无框架抽象 | 后续新图表只能复制粘贴，无法沉淀通用能力 |

## 3. 决策记录

| 决策点 | 结论 | 理由 |
|---|---|---|
| 框架范围 | **通用图表库（重型）** | 后续会有多种新图需求，需完整可扩展地基 |
| 内核架构 | **方案 A：Protocol-First 组合**（Theme/Model/Renderer 协议 + 通用容器注入 Renderer） | 最可扩展/可测，贴合「开闭原则」「单一职责」，符合 CLAUDE.md |
| 渲染技术 | **UIKit + QuartzCore（UIView/CALayer）** | 保留现有 CALayer 动画优势；Core 不依赖 SwiftUI |
| OC 兼容策略 | **内核纯 Swift，OC 兼容走独立 `OCBridge/` Wrapper** | 内核干净现代；OC 端仍有完整可用入口 |
| OC Wrapper 覆盖 | **框架级 + 雷达图完整 Wrapper**（ThemeBuilder / DimensionBridge / ViewBridge） | 贴合「方便 OC 使用」诉求 |
| SwiftUI 支持 | **`UIViewRepresentable` 封装**（`RadarChart` View） | SwiftUI App 开箱即用；Core 不依赖 SwiftUI |
| 交互范围 | **tap 命中 + 预留扩展位**（手势 enum、选中态协议位） | 先搭框架，蛛网图具体命中目标后填 |
| 命中测试归属 | **Renderer 负责 `hitTest(point)`，默认返回 nil** | Renderer 最清楚几何；可交互可选，蛛网图零侵入接入 |
| 容器泛型化 | **`HYMChartView<Renderer: HYMChartRenderer>` 泛型** | Swift 端类型安全；OC 经 Wrapper 使用；项目不用 Xib |
| 测试基线 | **DEBUG 断言自检 + 纯函数可测设计**（XCTest target 列为可选） | 零 pbxproj 风险，立即可落地 |

## 4. 分层架构与依赖方向

遵循 CLAUDE.md「Core → Foundation → UIKit/SwiftUI，绝不反向」：

```
SwiftUI/（Representable 封装：RadarChart）         ← 只做 View 包装，不含逻辑
        ↑ 依赖
OCBridge/（OC Wrapper：NSObject 子类）             ← 翻译 Swift 类型给 OC，不含绘制
        ↑ 依赖
Charts/Radar/（具体图表：Model / Theme / Renderer / Geometry）
        ↑ 依赖
Core/（通用框架内核：协议 + 通用容器 + 动画 + 几何 + 错误 + 交互 + 颜色工具）
        ↑
UIKit + QuartzCore + Foundation
```

**关键去耦**：现 `HYMRadarChartView`（容器+绘制+动画混合）拆为——
- `HYMChartView`（Core）：只做「容器 + 布局分发 + 动画驱动 + 触摸命中分发 + DisplayLink 生命周期 + layer 清理防泄漏」。
- `RadarChartRenderer`（Radar）：承载全部 layer 重建 / 标签 / 主题配色 / 命中测试。

## 5. 目录结构

顶层目录由中文 `图表/` 改名为英文 `Charts/`（更符合 SDK 规范）。

```
SwiftFunctionProject/Charts/
├── Core/                          # 通用框架内核（纯 Swift，零 OC 痕迹）
│   ├── HYMChartModel.swift            # 数据模型协议（marker）
│   ├── HYMChartTheme.swift            # 主题协议（marker）
│   ├── HYMChartRenderer.swift         # 渲染器协议 + HYMChartRenderContext
│   ├── HYMChartView.swift             # 通用容器 UIView（泛型）
│   ├── HYMChartAnimation.swift        # 动画协议 + 数值动画器（DisplayLink）
│   ├── HYMChartInteraction.swift      # HYMChartGesture / HYMChartHitTarget / hitTest 默认实现
│   ├── HYMChartError.swift            # HYMChartError
│   └── HYMColorInterpolation.swift    # 颜色插值工具（现有 lerpColor 上提复用）
├── Radar/                         # 雷达图：框架首个实现
│   ├── RadarChartModel.swift          # 纯 struct + Double?
│   ├── RadarChartTheme.swift          # 纯 struct + GridRingFill enum
│   ├── RadarChartRenderer.swift       # 实现 HYMChartRenderer，承载全部 layer 重建
│   └── RadarGeometry.swift            # 极坐标几何纯函数
├── OCBridge/                       # OC Wrapper
│   ├── HYMRadarChartViewBridge.swift      # OC 友好雷达视图（持内部泛型实例）
│   ├── HYMRadarThemeBuilder.swift         # 字典/builder 造 Theme、enum 字符串映射
│   └── HYMRadarDimensionBridge.swift      # OC 造维度
├── SwiftUI/
│   └── RadarChart.swift                   # RadarChart(model:theme:) View
└── Debug/
    └── ChartSelfTest.swift                # DEBUG 断言自检（替代 RadarSelfTest）
```

迁移完成后删除旧 `图表/蛛网图/` 整个目录。

## 6. Core 协议族设计

### 6.1 `HYMChartModel` / `HYMChartTheme`（marker 协议）

通用图表的 Model/Theme 字段各异，协议只做类型约束标记，具体类型自带字段。

```swift
public protocol HYMChartModel {}
public protocol HYMChartTheme {}
```

### 6.2 `HYMChartRenderer`（核心协议）

```swift
/// 渲染上下文（容器在 layoutSubviews 时提供）
public struct HYMChartRenderContext {
    public let bounds: CGRect
    public let center: CGPoint
}

public protocol HYMChartRenderer: AnyObject {
    associatedtype Model: HYMChartModel
    associatedtype Theme: HYMChartTheme

    /// 挂载渲染内容（layer 子树 + label 子视图）到容器；容器 init 后调一次
    func mount(into view: UIView)
    /// 卸载渲染内容
    func unmount(from view: UIView)
    /// 重建全部 layer 子树 + label（数据 / 主题 / 布局变化时由容器调用）
    func render(model: Model, theme: Theme, context: HYMChartRenderContext)

    /// 参加入场动画的 layer（容器统一驱动 opacity/scale）
    var animatableLayers: [CALayer] { get }

    /// 入场动画每帧回调（容器驱动 DisplayLink，传归一化进度 0...1）
    /// Renderer 据此更新自身需要数值滚动的子视图（如中心分数 label）
    func updateEntranceAnimation(progress: Double)

    // —— 交互能力（见 §6.3；声明为 requirement 以保证 override 可靠动态派发）——
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget?
    func applySelection(_ target: HYMChartHitTarget?)
    var centerScoreTarget: Double? { get }
}
```

> Renderer 是 `class`（`AnyObject`），内部持有当前 `model`（`render` 时存下），供 `centerScoreTarget` / `hitTest` 读取。

### 6.3 交互能力（requirement + 默认实现，可交互可选）

下列三者已在 §6.2 声明为协议 **requirement**（保证 override 走 witness table 可靠动态派发，避免「protocol-extension 默认实现被静态调用、override 不生效」的 Swift 陷阱），这里只给默认空实现；具体图表按需 override。

```swift
public enum HYMChartGesture {
    case tap
    // 预留扩展：longPress ...
}

/// 一个可命中的语义单元（关联数据，不是绘图细节）
public protocol HYMChartHitTarget {
    var identifier: String { get }   // 业务标识，如 "进攻"
    var index: Int { get }
}

public extension HYMChartRenderer {
    /// 默认无可命中目标；具体图表按需 override
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }
    /// 选中态视觉反馈（预留，默认空实现）
    func applySelection(_ target: HYMChartHitTarget?) {}
    /// 数值动画目标（如中心分数），默认 nil；雷达 override 返回 resolvedCenterScore
    var centerScoreTarget: Double? { nil }
}
```

## 7. 通用容器 `HYMChartView`

```swift
public final class HYMChartView<Renderer: HYMChartRenderer>: UIView {
    private let renderer: Renderer
    private var model: Renderer.Model?
    private var theme: Renderer.Theme?

    /// 命中交互单元时回调（带手势类型，为扩展留位）
    public var onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    public override init(frame: CGRect) {
        self.renderer = Renderer()
        super.init(frame: frame)
        renderer.mount(into: self)
        addTapGesture()          // UITapGestureRecognizer → renderer.hitTest → onHit
    }

    /// 配置并刷新（model + theme 一起传入）
    public func configure(model: Renderer.Model, theme: Renderer.Theme) {
        self.model = model
        self.theme = theme
        setNeedsLayout()
    }

    /// 播放入场动画（幂等，可重复调用）
    public func playEntranceAnimation()

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let model, let theme else { return }
        renderer.render(model: model, theme: theme,
            context: .init(bounds: bounds, center: .init(x: bounds.midX, y: bounds.midY)))
    }

    deinit { stopDisplayLink() }   // 兜底切断 DisplayLink
}
```

**职责边界**：容器只管「持有 renderer、布局分发、动画驱动、触摸命中分发、DisplayLink 生命周期、layer 防泄漏」。所有绘制细节在 Renderer。

## 8. 动画机制（容器与 Renderer 协作）

容器驱动节奏，Renderer 持有数值：

- **layer 动画**：容器对 `renderer.animatableLayers` 统一施加 `opacity 0→1` + `transform.scale`（沿用现有 `CATransaction` 方案，已验证可靠）。
- **数值滚动**（如中心分数）：容器启动 `CADisplayLink`，每帧算归一化进度 `t`（easeOut），调 `renderer.updateEntranceAnimation(progress: t)`；Renderer 据 `t` 在 `[0, centerScoreTarget]` 间插值并更新自身 label。
- **DisplayLink 释放三处**：重入开头 / `t>=1` / `deinit`（沿用现有防泄漏方案）。

## 9. 雷达图落地（去 OC 痕迹）

### 9.1 类型纯 Swift 化

| 类型 | 现状 | 重构后 |
|---|---|---|
| `RadarDimension` | `NSObject` + `@objcMembers` | `struct`（`label`/`value`/`maxValue`/`normalized`） |
| `RadarChartModel` | `NSObject` + `NSNumber?` + `@nonobjc theme` + 双 init + 硬编码 demo | `struct: HYMChartModel`（`dimensions`/`showsCenterScore`/`centerScore: Double?`；**theme 分离，由 `configure(model:theme:)` 单独传入**，符合单一职责） |
| `GridRingFill` | 纯 swift enum | 不变 |
| `RadarChartTheme` | `struct` | `struct: HYMChartTheme`（字段不变） |
| `resolvedCenterScore` | 全局函数（`NSNumber` 适配） | 纯函数（`Double`） |

### 9.2 `RadarChartRenderer` 职责

把现 `HYMRadarChartView` 的全部 `rebuildXxx` + `applyThemeColors` 迁入：

- 私有 layer 子树：`gradientLayer` / `gridFillContainerLayer` / `gridLayer` / `axisLayer` / `dataFillLayer` / `dataStrokeLayer` / `vertexDotsLayer`
- 私有子视图：`labels: [UILabel]` / `scoreLabel` / `subtitleLabel`
- `render(model:theme:context:)` 依次：`applyThemeColors` → `rebuildGridFill` → `rebuildGrid` → `rebuildAxis` → `rebuildData` → `rebuildVertexDots` → `rebuildLabels` → `rebuildScore`
- `animatableLayers` = `[dataFillLayer, dataStrokeLayer, vertexDotsLayer, gridLayer, axisLayer, gridFillContainerLayer]`
- `centerScoreTarget` = `resolvedCenterScore(model)`
- `updateEntranceAnimation(progress:)` 按 progress 插值更新 `scoreLabel.text`
- `hitTest(_:)` **本期返回 nil**（默认），后续 override 实现具体命中

### 9.3 Swift 使用形态

```swift
let chart = HYMChartView<RadarChartRenderer>()
chart.configure(model: m, theme: t)
chart.playEntranceAnimation()
chart.onHit = { target, gesture in /* 后续 */ }

// 便捷别名（可选）
// public typealias RadarChartView = HYMChartView<RadarChartRenderer>
```

## 10. OC Wrapper（OCBridge/）

OC 用不到泛型 / struct / enum(associated value) / `Double?`，由 Wrapper 翻译。

### 10.1 `HYMRadarDimensionBridge`（NSObject）

```swift
@objcMembers
public final class HYMRadarDimensionBridge: NSObject {
    @objc public init(label: String, value: Double, maxValue: Double = 100)
    internal var dimension: RadarDimension { /* 构造 struct */ }
}
```

### 10.2 `HYMRadarThemeBuilder`（NSObject）

OC 用属性造主题；`GridRingFill` 用字符串常量 + 颜色数组映射：

```swift
@objcMembers
public final class HYMRadarThemeBuilder: NSObject {
    @objc public var showsData: Bool = true
    @objc public var showsGridLines: Bool = true
    @objc public var showsAxes: Bool = true
    @objc public var showsBackground: Bool = true
    /// "none" / "gradient" / "colors"
    @objc public var gridRingFill: String = "none"
    /// gradient 的起止色 / colors 的每圈色
    @objc public var gridRingColors: [UIColor] = []
    // ... 其余颜色/字号属性，默认值与 RadarChartTheme 一致
    internal func build() -> RadarChartTheme { /* 翻译成 struct */ }
}
```

### 10.3 `HYMRadarChartViewBridge`（NSObject）

持有内部泛型实例，OC 拿 `UIView` 嵌入：

```swift
@objcMembers
public final class HYMRadarChartViewBridge: NSObject {
    private let chart: HYMChartView<RadarChartRenderer>

    @objc public init(theme: HYMRadarThemeBuilder)   // 内部 build 成 struct
    @objc public var chartView: UIView { chart }      // OC 嵌入用
    @objc public func configure(dimensions: [HYMRadarDimensionBridge],
                                showsCenterScore: Bool,
                                centerScore: NSNumber?)  // NSNumber? 桥接 Double?
    @objc public func playEntranceAnimation()
    /// 预留（蛛网图有点击时启用）
    @objc public var onHit: ((NSString, Int) -> Void)?
}
```

> Wrapper 只翻译、不含绘制；内核改动对 OC 透明。

## 11. SwiftUI 封装

```swift
public struct RadarChart: View {
    private let model: RadarChartModel
    private let theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool

    public init(model: RadarChartModel, theme: RadarChartTheme = .init(),
                playsAnimationOnAppear: Bool = true)

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    func makeUIView(context:) -> HYMChartView<RadarChartRenderer>   // configure + onAppear 动画
    func updateUIView(_ uiView:, context:)                          // configure 刷新
}
```

`ContentView.swift` 改为嵌入 `RadarChart(model:theme:)`，作为框架首个可视化 demo（6 维中文数据 + 默认主题 + 入场动画）。

## 12. 既有代码迁移与清理

| 动作 | 对象 | 说明 |
|---|---|---|
| 删除 | `HYMSwiftProbe.swift` | OC 混编探针残留 |
| 删除 | `RadarSelfTest.swift` 的 `RadarSelfTestRunner`（@objc 包装） | Swift App 直接调自检 |
| 删除 | 旧 `图表/蛛网图/` 整目录 | 迁移完成后删 |
| 重构 | `RadarDimension`/`RadarChartModel`/Theme → 纯 struct | 去 OC 痕迹、删硬编码 demo |
| 拆分 | `HYMRadarChartView` → `HYMChartView` + `RadarChartRenderer` | 容器/绘制解耦 |
| 迁移 | `RadarGeometry` 原样搬入 `Radar/`；自检逻辑 → `Debug/ChartSelfTest.swift` | |
| 新建 | Core 8 文件 + OCBridge 3 文件 + SwiftUI 1 文件 | 见 §5 |
| 接入 | `ContentView.swift` → `RadarChart` demo | 框架首个可视化验证 |

**迁移顺序**（每步 `xcodebuild` 验证）：新建 `Charts/` 树 → Core 内核（编译通过）→ 雷达图落地（编译通过）→ `ContentView` demo（运行目视）→ OCBridge → SwiftUI → 删旧目录（最终编译通过）。

## 13. 测试策略

项目无 test target（新建需改 pbxproj，高风险；以 `xcodebuild` 为权威，见 progress.md）。

- **主：DEBUG 断言自检**（`Debug/ChartSelfTest.swift`，App 启动调一次），覆盖纯逻辑：
  - `RadarGeometry`：`angle`/`point`/`ringPoints`（N=4/6/8、越界 ratio 裁剪）。
  - `resolvedCenterScore`：三态（隐藏 / 自动均值 / 外部传入）。
  - `HYMColorInterpolation`：`lerpColor` 端点与中点。
  - 交互：框架级 `hitTest` 默认返回 nil。
- **设计保障**：几何 / 分数 / 插值 / 命中均为无 UI 依赖的纯函数或纯输入输出方法。
- **可选增强（不阻塞）**：后续若建 XCTest target，纯函数部分直接补单测（可测边界已留好）。

## 14. 分期交付边界

**✅ 第一阶段（本次实现）**
1. Core 框架内核（协议族 + `HYMChartView` + 动画器 + 几何 + 错误 + 颜色插值 + 交互层）。
2. 雷达图迁移到框架下（纯 Swift 化、去 OC 痕迹、删硬编码 demo）。
3. OC Wrapper（雷达图 + 框架级）。
4. SwiftUI `RadarChart` 封装 + `ContentView` demo。
5. DEBUG 框架级自检。
6. 清理旧文件（探针 / 旧目录 / `RadarSelfTestRunner`）。

**🔜 后续阶段（不在本次）**
- 蛛网图具体交互命中目标（哪部分可点）实现：`RadarChartRenderer.hitTest` override + `onHit` 业务接入。
- 新图表类型（柱状 / 折线 / 饼）Renderer 实现。
- 选中态视觉反馈、长按等扩展交互（`applySelection` / `HYMChartGesture` 扩展）。
- 正式 XCTest target（可选）。

## 15. 风险与缓解

| # | 风险 | 缓解 |
|---|---|---|
| 1 | 目录改名 `图表/`→`Charts/` 导致 Xcode 引用断裂 | objectVersion 77 文件同步组：目录改动自动反映；每步 `xcodebuild` 验证；旧目录最后才删 |
| 2 | 泛型 `HYMChartView<Renderer>` 在某些场景（Storyboard/Xib）不便 | 本项目纯代码 + SwiftUI，不用 Xib；OC 经 Wrapper |
| 3 | 重构期功能回归（动画/底色/分数） | Renderer 逻辑从现 `HYMRadarChartView` 原样迁移；`ContentView` demo 逐项目视比对；保留 `CATransaction` 动画方案 |
| 4 | DisplayLink / layer 泄漏回归 | 容器统一管理 DisplayLink（三处 invalidate）；`mount/unmount` 明确 layer 生命周期；迁移后运行时 `leaks` 抽查 |
| 5 | `RadarChartModel.centerScore` 从 `NSNumber?` 改 `Double?` 影响 OC Wrapper | Wrapper 用 `NSNumber?` 桥接，OC 端无感 |
| 6 | 交互协议引入后 OC 端回调桥接 | `onHit` 暂为预留（蛛网图无命中），Wrapper block 同步预留，不增加本期复杂度 |
| 7 | 长 label 越界（spec 风险沿用） | 沿用现有 `maxRadius` 预留 padding 方案；demo 用 2 字短文案 |

## 16. 开放问题（后续处理）

- [ ] 蛛网图具体哪些部分可点击（维度扇区 / 顶点圆点 / 整个区域）——后续确认后实现 `RadarChartRenderer.hitTest`。
- [ ] 是否需要正式 XCTest target——视后续纯函数体量决定。
- [ ] 主题是否需要深色/亮色预设套件——后续按需新增，不改结构。
