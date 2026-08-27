# 轴系自定义 · 双值轴 · 折线堆叠 设计文档

> 日期：2026-08-27 · 状态：已评审（brainstorming 四问确认）
> 范围：Cartesian 轴系（Line / Column 先行；Bar 仅享受刻度自定义，双轴后续单独提）

## 1. 背景与需求

三个子需求（均已与用户确认语义）：

| # | 需求 | 已确认的决定 |
|---|------|--------------|
| 1 | 轴刻度数量与每个刻度显示的文本由外部数据设置 | 全套：`tickCount`（数量）+ `labelFormatter`（文本）+ `tickPositions`（完全显式位置），对齐 AAChartKit 能力 |
| 2 | 双值轴：左轴之外可设右轴（AAChartKit 同款） | **系列绑定轴**：每个系列声明用主轴（左）或次轴（右），两轴各自独立值域与刻度 |
| 3 | 折线图支持堆叠，每系列自己的颜色 | 折线与面积**都堆叠**：面积从上一系列累计线填到自己累计线，分层不遮挡 |

## 2. 方案选型

**方案 A（采用）**：`secondaryYAxis` 可选字段 + 系列 `yAxisIndex` 绑定。
向后兼容 100%——不设 `secondaryYAxis` 时所有现有图表行为逐字节不变，现有 demo/自检零迁移。
`yAxisIndex` 为 Int，未来若需三轴可将 `secondaryYAxis` 平滑升级为数组。

否决的备选：B（`yAxes` 数组化，Highcharts 式）破坏现有公开 API 且本轮双轴够用；
C（叠两个 chart view 的伪双轴）网格/命中/手势互相打架，不可行。

## 3. 模型层 API

```swift
public struct CartesianAxisModel {
    public var kind: CartesianAxisKind
    public var min: Double?                          // 现有
    public var max: Double?                          // 现有
    public var tickInterval: Double?                 // 现有（须配显式 min/max）
    // —— 新增 ——
    public var tickCount: Int?                       // 目标刻度数量（nice scale 依据；nil = 默认 6）
    public var tickPositions: [Double]?              // 完全显式刻度值（最高优先级）
    public var labelFormatter: ((Double) -> String)? // 刻度文本（nil = 内置去尾零格式）
    public var showsGridlines: Bool?                 // 该轴网格开关（nil = 主轴开、次轴关）
}

public struct CartesianSeriesElement {
    // name / data / color / negativeColor 现有不动
    public var yAxisIndex: Int = 0                   // 0 = 主轴（左），1 = 次轴（右）；越界回落 0（DEBUG 断言）
}

public struct CartesianChartModel {
    public var xAxis: CartesianAxisModel             // 类目轴（垂直图在底部）
    public var yAxis: CartesianAxisModel             // 主值轴（左）——现有字段，语义不变
    public var secondaryYAxis: CartesianAxisModel?   // 次值轴（右）；nil = 单轴（现状）
}
```

### 刻度生成优先级（值轴统一）

```
tickPositions（显式值，过滤到生效值域内）
  > tickInterval（须显式 min/max，现状规则不变）
    > tickCount（传给 NiceScaleGenerator.generate(maxTickCount:)，实际数量 ±1~2）
      > 自动（默认 maxTickCount = 6）
```

- `labelFormatter` 只改文本，不影响位置；`tickPositions` 决定"画哪些刻度"，
  值域仍由 min/max/数据驱动（域外刻度过滤，与现有 tickInterval 行为一致）
- 类目轴（xAxis）的 `tickCount`/`tickPositions` 无意义（类目位置由数据决定），
  `labelFormatter` 同样无意义（标签本来就是字符串）；忽略即可，不额外校验
- 三个新字段对 Bar（水平图）的 X 数值轴同样生效；`secondaryYAxis` 对 Bar 不生效
  （DEBUG 断言提示，水平多值轴=顶部轴，后续单独做）

## 4. 渲染架构（双值轴）

### 值域与刻度（per 轴独立）

- `viewport.yDomain` 继续表示**主轴**值域——现有几何映射、缩放手势、
  Column/Line/Bar 全部现有路径零改动
- `CartesianRendererBase` 新增渲染期状态：
  - `currentSecondaryYDomain: ClosedRange<Double>?`（nil = 无次轴）
  - `currentSecondaryValueTicks: [Double]`
- 值域计算按系列分组：`yAxisIndex == 0` 的系列（堆叠时用累计值，沿用 `dataBounds`
  既有逻辑）→ 主轴域；`== 1` → 次轴域。两轴各自套用各自的 min/max / tick 三件套。
  某轴无绑定系列时：显式 min/max 仍生效；否则该轴域兜底为 `0...1`
  （与现有 `dataBounds == nil` 的兜底一致）。

### 布局与轴组件

- `CartesianGeometry.layout` 加参数 `rightAxisLabelWidth: CGFloat = 0`；
  有次轴时右侧让宽
- `AxisRenderer` 新增右侧刻度方法（右对齐、贴 plot 右缘外侧）；
  `makeAxisLinesLayer` 在有次轴时补画右缘竖线
- 网格线默认只由主轴刻度驱动；次轴 `showsGridlines == true` 时才画第二套

### 系列映射与命中

- 基类加 `screenPoint(x:y:yAxisIndex:)`（0 → viewport.yDomain，1 → 次轴域）
- `columnRect` 与折线取点加 `yDomain: ClosedRange<Double>? = nil` 参数
  （nil = 主轴域），现有调用点签名不变
- `zeroAxisPosition` 按系列所属值域计算（双轴 + 负值时各自正确）
- `LineHitTarget` / 柱状命中 target 增加 `yAxisIndex`（默认 0），弹窗可按轴显示单位
- 缩放/平移手势不动（只作用 X 轴，与值轴无关）

## 5. 折线/面积堆叠

- 复用柱状堆叠机制：`StackConfig.normal` + `CartesianGeometry.stackedValues`
  （累计值链）；折线画累计后的值，每系列自己的 `color`；
  平滑曲线（Fritsch-Carlson）/阶梯等连接形态在累计值上照常生效
- **堆叠面积分层**（关键语义）：
  - 系列 i 的面积 path = 正向沿「系列 i 累计线」+ 反向沿「系列 i-1 累计线」闭合
  - 第一个系列从 y=0 基线填起（现状行为）
  - 渐变色 per-series（现有机制直接用），层层叠高、颜色不互相覆盖
- **双轴 × 堆叠**：堆叠链按轴分组——同 `yAxisIndex` 的系列才互相累计，跨轴不混叠
- 不开 `stacking` 时折线/面积行为与现状逐字节一致

## 6. 兼容性

- 不设 `secondaryYAxis`、不开 `stacking`、不设新刻度字段 → 行为与现状完全一致
- 现有 demo / ChartSelfTest / 文档调用点**零迁移**
- OC 桥接不受影响（Cartesian 未做桥接，仅 Radar/Heatmap 有）
- `CartesianAxisModel` 新字段全部 Optional 且有默认值，现有构造调用不变

## 7. demo 与文档

- `LineChartDemo`：加"双轴演示"（温度℃ 左轴 + 湿度% 右轴，各自独立刻度）、
  "堆叠"开关（折线 + 面积分层）、刻度自定义面板项
  （tickCount 滑条、tickPositions 示例、labelFormatter 示例）
- `ColumnChartDemo`：加双轴开关（与现有堆叠开关组合可用）
- `charts-line-guide.md` / `charts-column-guide.md`：补新能力章节

## 8. 验收标准

1. 刻度四档优先级与 labelFormatter：ChartSelfTest 断言（positions > interval > tickCount > 自动）
2. 双轴：两轴值域独立计算、右侧让宽、右侧刻度对齐右缘、网格默认仅主轴
3. 双轴数据展示：系列按 `yAxisIndex` 映射到对应轴的值域（截图目检 + 断言）
4. 折线堆叠：累计线正确、每系列独立颜色；面积分层（系列 2 面积起点 = 系列 1 累计线，断言 path 几何）
5. 负值 + 双轴：零轴位置按所属值域正确
6. 回归：全部现有断言不改动地通过；Bar/Column/Line 无堆叠无双轴时渲染与当前一致
7. 全量 XCTest 通过

## 9. 实施顺序（每步 TDD：RED → GREEN）

1. **轴刻度自定义**：`CartesianAxisModel` 三新字段 + 刻度生成四档优先级 + labelFormatter
   （最小独立，Bar/Column/Line 同时受益）
2. **双值轴**：模型 `secondaryYAxis`/`yAxisIndex` + renderer 次轴域/刻度 + 右侧布局/
   轴线/网格开关 + 系列按轴映射 + 命中带轴索引
3. **折线堆叠**：stackedValues 按轴分组 + 累计线 + 分层面积
4. **demo 与文档**收尾
