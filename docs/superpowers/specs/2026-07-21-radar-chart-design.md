# 蛛网图（雷达图）组件设计

> 日期：2026-07-21
> 状态：待审阅
> 负责人：wangkun

## 1. 概述

实现一个可复用的雷达 / 蛛网图 `UIView` 组件，用于多维评分展示：

- 支持任意数量的维度顶点（参考截图为 6 个，但组件不写死）。
- 每个顶点带文案标签。
- 中心展示整体分数（可通过开关隐藏；分数来源支持「自动算均值」和「外部传入」两种模式）。
- 卡片背景与数据多边形带渐变效果。
- 入场带展开动画。
- 作为全新功能，先在 `ViewController` 中做 demo 展示，不耦合现有业务。

## 2. 项目现状（影响选型的关键事实）

| 项 | 现状 | 影响 |
|---|---|---|
| 语言 | 纯 Objective-C，无 Swift、无 Bridging Header | 选 Swift 需新建 Bridging Header，混编配置是首要风险点 |
| 依赖 | 无 Podfile、无任何三方库 | 引 Charts 等大库违反「优先稳定性」，倾向原生 |
| 部署目标 | iOS 26.2 | UIKit/CALayer 新特性全部可用 |
| ViewController | 空模板（仅空 `viewDidLoad`） | 全新功能，无历史包袱 |
| 架构约束 | MVC + VC/Manager/Service/Model 分层 | 组件须是独立 `UIView` 子类，VC 只持有并喂数据 |

## 3. 决策记录

| 决策点 | 结论 | 理由 |
|---|---|---|
| 实现语言 | **Swift**（`@objc` 暴露给 OC） | 用户指定；语法现代。代价：需配置 Bridging Header |
| 维度数量 | **可配置任意数量**（model 驱动） | 6 个只是其中一种 case，组件应通用可复用 |
| 中心分数 | **双模式**：开关控制是否显示；自动均值 / 外部传入都支持 | 覆盖不同业务场景 |
| 入场动画 | **需要**（展开 + 淡入 + 数字滚动） | 用户指定，提升体验 |
| 实现方案 | **A：CAShapeLayer + CAGradientLayer** | 动画原生最顺滑、零依赖、layer 化便于未来交互 |
| 视觉细节 | **先用默认配色（紫蓝渐变系）**，后对照截图微调 | 图片分析工具暂限流，不阻塞推进 |

## 4. 分层架构

符合项目 MVC + VC/Manager/Service/Model 约束：

```
ViewController            demo 阶段直接构造 Model 喂数据（不引入 Manager，避免过度设计）
      ↓
HYMRadarChartView        纯绘制组件（Swift, @objc 暴露），只认 Model，不碰业务
      ↓
RadarChartModel          数据结构（维度数组 + 分数配置 + 主题）
```

> 原则：View 只负责「给定 Model 画出图」，不发起网络请求、不做业务判断。后续接入真实业务时，由 Manager/Service 层组装 Model 再喂给 View，View 无需改动。

## 5. 组件设计

### 5.1 `RadarDimension`（单个维度）

```swift
struct RadarDimension {
    let label: String      // 顶点文案，如「进攻」
    var value: Double      // 当前值
    var maxValue: Double   // 满分值（用于归一化），默认 100
}
```

### 5.2 `RadarChartModel`（整体数据）

```swift
struct RadarChartModel {
    let dimensions: [RadarDimension]   // 任意数量，建议 3~12
    var showsCenterScore: Bool         // 是否显示中央分数
    var centerScore: Double?           // nil = 自动算归一化均值；非 nil = 用传入值
    var theme: HYMRadarChartTheme      // 配色主题
}
```

分数语义：
- `showsCenterScore == false` → 不画中央分数。
- `showsCenterScore == true && centerScore == nil` → 组件自动算 `Σ(value/maxValue) / N * maxValue`（按 maxValue 同量纲）。
- `showsCenterScore == true && centerScore != nil` → 用传入值。

### 5.3 `HYMRadarChartTheme`（配色集中管理）

把所有颜色集中在此 struct，改色只动一处。默认提供一套紫蓝渐变（深色卡片）主题，后续可对照截图微调或新增亮色主题。

### 5.4 `HYMRadarChartView`（对外入口）

```swift
@objcMembers public final class HYMRadarChartView: UIView {
    /// 配置并刷新整张图
    @objc public func configure(_ model: RadarChartModel)
    /// 播放入场展开动画（幂等，可重复调用）
    @objc public func playEntranceAnimation()
}
```

内部私有子层（每次 `configure` 重建）：

| 子层 / 子视图 | 类型 | 作用 |
|---|---|---|
| 背景层 | `CAGradientLayer` | 卡片渐变底色 |
| 网格层 | 多个 `CAShapeLayer` | 同心多边形（默认 5 圈） |
| 放射轴 | `CAShapeLayer` | 从中心到各顶点的连线 |
| 数据多边形 | `CAShapeLayer`（填充）+ `CAShapeLayer`（描边） | 实际数值围成的区域 |
| 顶点圆点 | `CAShapeLayer`（每个顶点一个，或合并路径） | 数据顶点标记 |
| 标签 | `[UILabel]` | 各顶点文案 |
| 中心分数 | `UILabel`（分数 + 副标题，如「综合评分」） | 中央展示 |

## 6. 数据流

```
ViewController 构造 RadarChartModel
    → chartView.configure(model)
        → invalidate 旧动画 / 移除旧 sublayer（防泄漏）
        → setNeedsLayout
        → layoutSubviews()：按 bounds 与维度数计算几何，重建各 layer 与 label
    → (可选) chartView.playEntranceAnimation()
```

几何计算（纯函数，便于单测）：
- 中心 = bounds 中心；最大半径 = `min(width, height)/2 - labelPadding`。
- 第 i 个顶点角度 = `-π/2 + i * 2π/N`（第一个顶点朝正上方）。
- 第 i 个顶点坐标 = 中心 + `(value/maxValue * maxRadius) * (cos, sin)`。

## 7. 中心分数双模式

见 5.2 的三态语义。组件内部统一封装一个 `resolvedCenterScore(model) -> Double?`，调用方无需关心来源，消除「总分与维度对不上」的 bug 风险。

## 8. 入场动画

- 数据多边形：`transform.scale 0→1` + `opacity 0→1`，`anchorPoint` 锁 view 中心，防展开偏移。
- 描边：可选 `strokeStart/strokeEnd` 描线。
- 网格 / 轴：`opacity 0→1` 淡入。
- 中心分数：数字 `0→target` 滚动（`CADisplayLink`，结束 **必须 invalidate**）。
- 完成回调：`[weak self]`，避免循环引用。

## 9. Swift 混编配置（⚠️ 关键风险，单独列出）

老项目首次引入 Swift，配置错误会直接编译失败：

1. 新建 `HYMRadarChartView.swift` 等 `.swift` 文件时，Xcode 弹窗提示创建 **Bridging Header** → 生成 `测试111/测试111-Bridging-Header.h`（本次可留空）。
2. Build Settings 写入 `SWIFT_OBJC_BRIDGING_HEADER = 测试111/测试111-Bridging-Header.h`。
3. OC 端调用 Swift：`#import "测试111-Swift.h"`；Swift 类与要对 OC 暴露的成员加 `@objc` / `@objcMembers`。
4. Swift 调 OC：把 OC 头写进 Bridging Header（本次 View 不反向调 OC，可不动）。
5. 模块名（`ProductName-Swift.h` 中的 `ProductName`）需与 target 名一致，注意中文 target 名的转义。

> 这一步会作为独立的「最小验证」步骤：先只建一个空的 Swift 类 + Bridging Header，确认编译通过，再加正式组件代码（小步验证，避免一次性大改）。

## 10. 视觉规范（默认 Theme，待对照截图微调）

| 部位 | 默认值 | 说明 |
|---|---|---|
| 卡片背景渐变 | `#2A1B5C → #4B2EAA`（深紫，竖向） | 可改亮色或改方向 |
| 网格线 | `#FFFFFF` alpha 0.15 | |
| 放射轴 | `#FFFFFF` alpha 0.25 | |
| 数据多边形填充 | `#8B5CF6` alpha 0.35（半透明紫） | 可叠渐变 |
| 数据多边形描边 | `#A78BFA`，宽 2pt | 可加 shadow 发光 |
| 顶点圆点 | 实心 `#8B5CF6`，外圈 `#FFFFFF` | |
| 标签文字 | `#E0E7FF`，14pt | 顶点外侧 |
| 中心分数 | `#FFFFFF` bold 36pt | |
| 中心副标题 | `#C7D2FE` 13pt（如「综合评分」） | |
| 卡片圆角 | 16pt | |

> 以上为通用好看的默认值。截图恢复可见后，按实际色值 / 文案 / 分数微调 `HYMRadarChartTheme` 即可，不影响结构。

## 11. 风险与缓解

| # | 风险 | 缓解 |
|---|---|---|
| 1 | Swift 混编 Bridging Header 配置错误导致编译失败 | 先建空 Swift 类 + Header 做最小编译验证，再加正式代码 |
| 2 | 动画中心未对齐，展开时整体偏移 | 所有 shape layer 统一以 view 中心为锚，`frame` = bounds，路径用中心坐标 |
| 3 | layer 刷新时未清理旧 sublayer → 内存涨 + 残影 | `configure` 开头统一移除重建的私有 sublayer，保留背景层引用 |
| 4 | `CADisplayLink` 未 invalidate → 泄漏 | 动画结束 / 组件 dealloc / 重新 configure 时 invalidate |
| 5 | 维度多或文案长 → 标签越界 | 预留 `maxRadius` 内边距，标签支持字号自适应 / 截断 |
| 6 | block / 回调循环引用 | 完成回调用 `[weak self]` |

## 12. 可扩展性

- 维度数任意（model 驱动）。
- 配色全集中在 `HYMRadarChartTheme`，可换肤 / 支持深色模式。
- 预留「点击某维度回调」（`onSelectDimension: ((Int) -> Void)?`），layer 天然支持 hit-testing，未来按需开启。
- 多组数据对比（叠两个多边形）可作为后续增强，当前不做（YAGNI）。

## 13. 测试方案

- 单元（纯函数，易测）：
  - 顶点坐标计算（N=3/6/8，边界值正确）。
  - `resolvedCenterScore` 三态（隐藏 / 自动均值 / 传入值）。
- 手动（demo 中验证）：
  - 维度数 3 / 6 / 8 各画一次，布局与标签无越界。
  - 分数开关：隐藏 / 自动 / 传入三种。
  - 入场动画顺滑、无偏移。
  - 连续 `configure` 刷新不泄漏、无残影（Instruments / Memory Graph 抽查）。

## 14. 开放问题（待确认）

- [x] 截图实际配色 / 文案 / 分数值 —— 工具恢复或用户提供后，按第 10 节微调 Theme。
- [x] 是否需要深色 / 亮色双主题（当前默认深紫，可后续加）。
- [x] 点击维度回调是否本期实现（默认预留接口、不启用）。

---

## 15. 网格每层底色与边框开关（增强，后续实现）

> 本节为 Task 1-8 之后的增强需求（2026-07-21 追加），**暂不实现**，待新增 Task 9。
> 它对 5.3（Theme）和 10（视觉规范）做补充；Theme 结构以此节为准。

### 15.1 需求
1. 网格每一圈同心多边形可填充**底色**（目前仅描边、无填充）。
2. 底色支持两种配置模式（可切换）：**起止 2 色自动插值** / **每圈独立颜色数组**；并保留「不填充」选项。
3. **网格边框描边**与**放射轴**可各自独立开关显示。

### 15.2 Theme 新增字段（HYMRadarChartTheme）

```swift
/// 网格每圈底色模式
public enum GridRingFill {
    case none                                  // 不填充（默认，向后兼容现状）
    case gradient(from: UIColor, to: UIColor)  // 从最外圈到最内圈自动线性插值
    case colors([UIColor])                      // 每圈独立指定颜色（数组长度建议 ≥ gridRingCount）
}

// HYMRadarChartTheme 新增：
public var gridRingFill: GridRingFill = .none   // 默认不填充，保持现状
public var showsGridLines: Bool = true           // 网格描边显示开关
public var showsAxes: Bool = true                // 放射轴显示开关
```

- `gridRingFill = .none` 时与现状完全一致（向后兼容，已交付代码视觉不变）。
- `.gradient(from:to:)`：组件按 `gridRingCount` 在 from→to 间线性插值出每圈色（外圈=from，内圈=to）。
- `.colors([...])`：每圈取数组对应元素；若数组长度 < `gridRingCount`，超出部分回退为最后一色（实现时定，届时补充）。

### 15.3 View 行为（实现指引）
- **底色绘制**：每圈底色需独立填充。建议把当前单 `gridLayer` 拆为「底色层（每圈独立 fill）」+「描边层」。底色层位于背景渐变之上、描边/轴/数据之下。
  - 画序建议外圈→内圈（内圈覆盖外圈中心），或半透明叠加；实现时选视觉效果佳者。
- **边框开关**：`showsGridLines=false` → 网格描边不绘制/隐藏；`showsAxes=false` → 放射轴不绘制/隐藏。底色与边框开关**正交**（互不影响）。
- z 序（底→顶）：背景渐变 → 网格底色 → 网格描边 → 放射轴 → 数据多边形 → 顶点圆点 → 标签 → 分数。

### 15.4 默认视觉（补充第 10 节）

| 部位 | 默认值 |
|---|---|
| 网格每圈底色 | `gridRingFill = .none`（不填充，与现状一致） |
| 网格描边 | 显示（`showsGridLines = true`），`#FFFFFF` alpha 0.15 |
| 放射轴 | 显示（`showsAxes = true`），`#FFFFFF` alpha 0.25 |

开启底色的示例：`gridRingFill = .gradient(from: UIColor.white.withAlphaComponent(0.10), to: UIColor.white.withAlphaComponent(0.02))`。

### 15.5 实现计划（新增 Task 9，在 Task 8 之后）
1. Theme 加 `GridRingFill` enum + `gridRingFill` / `showsGridLines` / `showsAxes` 三字段（默认向后兼容）。
2. View 拆分网格层为「底色 + 描边」，按 mode 填充每圈（gradient 插值 / colors 取值 / none 跳过）。
3. `showsGridLines` / `showsAxes` 控制描边 / 轴 layer 显隐。
4. 截图验证组合：none（现状）/ gradient / colors 三种底色 × 边框开关。
