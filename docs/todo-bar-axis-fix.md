# 待办任务：条形图（Bar）轴系渲染修复

> 创建：2026-08-27 · 状态：**待修复** · 优先级：中（功能可用性缺陷，Bar 图当前轴信息错误）

## 问题描述

条形图（水平图）的轴/网格渲染没有按图表方向分支，复用了垂直图（Column/Line）的绘制逻辑，
导致轴系信息错乱。截图诊断已确认以下三个现象：

| # | 现象 | 期望行为 |
|---|------|----------|
| 1 | 底部（X 轴位置）画的是**类目标签**（"1"、"2"…），且全部挤在最左侧 | 底部应画**数值刻度**（0、20、40…，nice scale） |
| 2 | 左侧（Y 轴位置）画的是**数值刻度**（从类目域 -0.5...n-0.5 生成的无意义数字） | 左侧应画**类目标签** |
| 3 | 竖网格线位置无意义（类目索引被当 X 数值映射；1440 点时会画 1440 条错位线） | 竖线按数值刻度、横线按类目 |

柱状图/折线图不受影响（垂直方向恰好匹配现有逻辑）。

## 根因

`CartesianRendererBase.render()` 编排轴组件（`AxisRenderer`）与网格（`GridRenderer`）时
**不区分图表方向**。条形图的 viewport 语义与柱状图互换：

| | 柱状图（垂直） | 条形图（水平） |
|---|---|---|
| 数值轴 | Y（左侧） | **X（底部）** |
| 类目轴 | X（底部） | **Y（左侧）** |

而当前渲染无条件地：数值刻度画左侧、类目标签画底部、竖网格按类目——只对垂直图正确。

## 修复方案（已评审）

1. `CartesianRendererBase` 加方向开关：

   ```swift
   /// 值轴是否水平（条形图为 true；决定轴标签/网格的方向分支）
   open var isHorizontalValueAxis: Bool { false }
   ```

   `BarChartRenderer` override 返回 `true`。

2. `render()` 按方向分支轴系编排：

   - **水平图**：
     - 数值刻度（nice scale，从 `viewport.xDomain` 生成）→ 画**底部**，x 按值映射
     - 类目标签 → 画**左侧**，y 按类目映射，右对齐
     - 网格：竖线按数值刻度，横线按类目
   - **垂直图**：维持现状

3. `AxisRenderer` 增加水平方向的方法（如 `makeValueTickLabels(atBottom:)`、
   `makeCategoryLabels(atLeft:)`），或给现有方法加方向参数。

4. 布局计算同步对调：水平图时 `yAxisTickLabelWidth` 量**类目标签**宽度（左侧），
   `xAxisTickLabelHeight` 量数值刻度高度（底部）。

5. 涉及文件：`CartesianRendererBase.swift`、`AxisRenderer.swift`、`GridRenderer.swift`

## 验收标准

- BarChartDemo（默认 4 类目）：左侧显示类目标签、底部显示 0/20/40… 数值刻度
- 网格线方向与刻度对齐
- 负值数据：零轴在数值轴上的位置正确
- ColumnChartDemo / LineChartDemo 回归无变化
- X 轴缩放（数值轴）平移时刻度跟随、类目恒定
- ChartSelfTest 补充水平轴刻度生成断言

## 关联

- 依赖本次缩放重构（viewport 驱动，已完成）：水平图缩放 X 数值轴的语义已就绪
- BarChartDemo 的数据点数滑块范围（当前 2...12）可顺带扩到 2...1440 对齐柱状图
