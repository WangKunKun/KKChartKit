# 折线图三方功能对比与缺口清单（KKChartKit vs AAChartKit vs ChartsOrg/Charts）

> 基准日期：2026-08-31（提交 `0e3a710`）。
> 对比范围：折线图（直线/平滑曲线/阶梯）及其配套（数据点、面积、轴系、标签、交互）。
> 用途：记录当前对齐状态与剩余缺口，后续有需求时按档位补齐并更新本表。
> 说明：AAChartKit 为 WebView+JS（Highcharts 封装）架构；Charts(DGCharts) 与我们均为原生渲染（我们是 CALayer）。

## 一、当前对齐状态总览

图例：✅ 已对齐 · 🟡 部分对齐（有已知限制） · ❌ 缺失 · ⭐ 我们独有/领先

### 1. 线形态

| 能力 | 我们 | AAChartKit | Charts(DGCharts) |
|---|---|---|---|
| 直线 | ✅ | ✅ | ✅ Linear |
| 平滑曲线（F-C 单调插值，无过冲） | ⭐✅ | ✅（Catmull-Rom 类，会过冲） | ✅ CubicBezier |
| 阶梯（居中/后置/前置 3 变体） | ✅ | ✅ | ✅（单一形态） |
| 水平贝塞尔 HorizontalBezier | ❌ | ❌ | ✅ |
| 曲线张力参数 | ❌（有意不做，F-C 下无意义） | ❌ | ✅ cubicIntensity |

### 2. 线样式与数据点

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 线宽/颜色/圆角连接 | ✅ | ✅ | ✅ |
| 虚线 11 种（主题级 + 系列级） | ✅ | ✅ | ✅（另有 lineDashPhase） |
| 负值换色 negativeColor | ✅ 直线（跨零插值切分）/🟡 阶梯（数据点切分）/🟡 曲线（不切，用系列色） | ✅ | ❌ |
| 分段变色 zones（按值区间） | ❌ | ✅ | ❌（可用逐点色半实现） |
| 系列阴影 shadow | ❌ | ✅ | ✅ |
| 点形状（圆/方/菱/正三角/倒三角） | ✅ 系列级覆盖 | ✅ 类似集合 | 仅圆 |
| 空心圆点（holeRadius/holeColor） | ✅ 2026-08-31 | ❌ | ✅ |
| 逐点颜色数组 / 点上放图标 | ❌ | 部分（icon） | ✅ |
| 点 hover/selected 态（选中放大） | ❌（applySelection 空实现） | ✅ states | ✅ highlight |
| 标线（阈值线，plotLines/LimitLine） | ✅ 2026-08-31（含标签/虚线/轴绑定） | ✅（另有 plotBands 色带） | ✅ |
| 色带 plotBands（区间背景色块） | ❌ | ✅ | ❌（LimitLine 无色带） |

### 3. 面积填充

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 面积渐变（顶部浓→底淡，浓度可调） | ✅ | ✅ | ✅（渐变角度可调） |
| 填充到自定义边界（fillFormatter，两线之间） | ❌ | 部分（threshold） | ✅ |
| 空值下面积分段闭合 | ✅ | ✅ | ✅ |

### 4. 数据与轴系

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 空值断线 + connectNulls（系列级） | ✅ | ✅ | ✅ NaN gap |
| 线堆叠（普通/正负分链/百分比/统一基准 max） | ⭐✅ | ✅ | ❌（无原生线堆叠） |
| 双值轴（次轴独立刻度/域） | ✅ | ✅（多 Y 轴 >2） | ✅ axisDependency |
| 刻度四档自定义（positions/interval/count/auto）+ formatter | ✅ | ✅ | ✅ granularity/forceLabels |
| Y 轴反向 reversed | ❌ | ✅ | ✅ inverted |
| 对数轴 logarithmic | ❌ | ✅ | ❌ |
| 轴标签旋转 | ❌ | ✅ | ✅ |
| 轴百分比留白（spaceTop/spaceBottom） | ❌（nice padding 固定） | ✅ | ✅ |
| 类目轴居中标签（centerAxisLabels） | ❌ | ✅ | ✅ |

### 5. 数据标签

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 开关/3 档位置（两两不同）/系列级覆盖/formatter | ✅ | ✅（align/x/y 全自由） | ✅ 上/下 |
| 标签边框/底色/圆角/旋转 | ❌ | ✅ | ❌ |
| 大数据量保护（>200 自动跳过、缩放后恢复） | ⭐✅ | ❌ | ❌ |

### 6. 交互（弹窗/准线/手势）

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 弹窗内容自定义（popupContentProvider） | ✅（等价 ChartMarker） | ✅ | ✅ |
| 整列 shared / 逐点+吸附 双模式 + 自动档 | ✅ | ✅ shared | 部分 |
| 十字准线（逐点/整列统一） | ✅ 样式可配（颜色/线宽/虚线，2026-08-31） | ✅ | ✅ 竖/横指示线 |
| 准线横+竖双向指示 | ❌（当前单向：垂直图竖线/水平图横线） | ✅ | ✅ |
| 捏合缩放轴向 x/y/xy | ✅ | ✅ zoomType | ✅（可锁拖拽方向） |
| 锚点跟手/平移/惯性减速/橡皮筋回弹 | ✅ | 部分（WebView 手势） | ✅ |
| 双击重置（两轴） | ✅ | ✅ + reset 按钮回调 | ⚠️ 双击是放大（语义不同） |
| 滑动选中（全量视图拖拽=划过高亮） | ✅ | ❌ | ✅ |
| 多图联动 sync | ❌ | ❌ | 第三方 SyncChartGesture |
| 弹窗文本模板（header/valueSuffix/decimals） | ❌（tooltipText 固定格式） | ✅ | ✅ |

### 7. 周边能力

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 图例 legend（点击隐藏系列） | ❌ | ✅ | ✅（可滚动/自定义） |
| 动画 easing 可选 | ❌（单一 ease） | ✅ 多种 | ❌ |
| 极坐标 polar | ❌ | ✅ | ❌ |
| 描述文本 / 无数据占位文案 | ❌ | ✅ | ✅ noDataText |

## 二、剩余缺口（按建议优先级）

### 第 2 档（中成本，下一个建议批次）
| 缺口 | 价值 | 预估成本 | 备注 |
|---|---|---|---|
| 图例 legend（点击隐藏系列） | 高：系列多时必须能关；demo 也需要 | 中 | 需系列显隐状态进 model 渲染层过滤；点击交互区（顶部条） |
| zones 分段变色（按值区间换色） | 高：超标变色与标线同源 | 中 | 数据结构与 plotLines 同构（value 区间 → 颜色）；曲线形态切分同 negativeColor 限制 |
| 弹窗文本模板（header/valueSuffix/valueDecimals） | 中：外接弹窗/固定格式不够灵活 | 低-中 | tooltipText 组装层加模板参数 |

### 第 3 档（高成本，按需）
| 缺口 | 价值 | 预估成本 | 备注 |
|---|---|---|---|
| Y 轴 reversed | 中 | 高 | 几何符号翻转，波及刻度/网格/零轴/命中/堆叠 |
| 面积填充到自定义线（fillFormatter） | 中 | 高 | 面积下边界泛化 |
| HorizontalBezier 形态 | 低（锦上添花） | 低 | 每段 addCurve 控制点水平；共享全部下游逻辑 |
| 逐点颜色数组 / 点上图标 | 中 | 中 | 点层循环按索引取色/贴图 |
| 点 hover/selected 态（选中放大） | 中 | 中 | applySelection 目前空实现；需命中几何→视觉反馈 |
| 系列阴影 shadow | 低 | 低 | CALayer.shadowXxx 直配 |
| 色带 plotBands | 中 | 低-中 | 与标线同源（区间矩形层） |
| 准线横+竖双向 | 低 | 低 | crosshairRect 已有几何，加垂直分量 |
| 轴标签旋转 | 低 | 低-中 | tick label transform |
| 轴百分比留白 / 类目标签居中 | 低 | 中 | makeValueDomain/布局微调 |
| 对数轴 logarithmic | 低（受众窄） | 高 | 值映射整条链路换算 |
| 多 Y 轴（>2） | 低 | 高 | 有效轴索引泛化 |
| 双击改放大语义 | — | — | 不建议（我们是重置，语义更好） |
| tension 曲线张力 | — | — | 不做（F-C 结论，见记忆 smoothing-algorithm-comparison） |
| polar 极坐标 | 低 | 很高 | 整套坐标系 |
| 多图联动 sync | 低 | 中 | 可后续以手势广播组件提供 |

## 三、我们独有/领先项

1. **F-C 单调平滑**：无过冲，优于两库的 Catmull-Rom/CubicBezier。
2. **线堆叠四形态**：普通、正负分开链、百分比、统一基准 max（Charts 无原生线堆叠）。
3. **手势体验**：锚点跟手缩放（x/y/xy）、惯性减速、橡皮筋回弹、滑动选中、双击重置两轴。
4. **整列/逐点双命中模式 + 自动档**，弹窗跟手不闪动。
5. **数据标签大数据量保护**（>200 跳过、缩放恢复）。
6. **空值语义完整**：NaN 断线 + 系列级 connectNulls，面积分段闭合。
7. **原生 CALayer 渲染**（AAChartKit 是 WebView+JS）。

## 四、语义差异备忘（同功能不同行为）

- **双击**：我们/AAChartKit = 重置视口；Charts = 放大。
- **Bar 的 y 缩放**：我们 `.y` = 纵向类目轴放大；Charts 的 scaleY = 值轴缩放（方向语义相反）。
- **阶梯默认锚点**：Highcharts step 默认 center？实际 Highcharts 默认为 `false`（直线）；我们的 demo 默认直线、阶梯三变体显式可选。
- **负值换色切分**：我们在 y=0 插值切分（Highcharts threshold 同款）；阶梯/曲线形态有已知限制（见 2 节表格注释）。

## 五、更新日志

- 2026-08-31（`0e3a710`）：补齐第 1 档四项——标线 plotLines、折线 negativeColor、空心圆点、准线样式可配；本文档建立。
- 2026-08-31（`7318807`）：数据标签、捏合缩放轴向 x/y/xy 对齐。
- 更新约定：每补齐一项，把对应行 ❌/🟡 改 ✅（标注日期/提交），并从「剩余缺口」表移除。
