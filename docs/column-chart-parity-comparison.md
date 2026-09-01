# 柱状图/条形图三方功能对比与缺口清单（KKChartKit vs AAChartKit vs ChartsOrg/Charts）

> 基准日期：2026-09-01（提交 `7380fa5`）。
> 对比范围：柱状图（ColumnChart）与条形图（BarChart，水平镜像）及其配套（柱体、堆叠、轴系、标签、交互）。
> 用途：记录当前对齐状态与剩余缺口，后续有需求时按档位补齐并更新本表。
> 说明：AAChartKit 为 WebView+JS（Highcharts 封装）架构；Charts(DGCharts) 与我们均为原生渲染（我们是 CALayer）。
> 约定：Bar（条形图）与 Column 共享模型/几何/交互层，除特殊标注外两图能力一致。

## 一、当前对齐状态总览

图例：✅ 已对齐 · 🟡 部分对齐（有已知限制） · ❌ 缺失 · ⭐ 我们独有/领先

### 1. 柱体形态与几何

| 能力 | 我们 | AAChartKit | Charts(DGCharts) |
|---|---|---|---|
| 垂直柱 / 水平条（同一模型两渲染器） | ✅ | ✅ bar/column | ✅ |
| 柱宽/组内间距/组间距独立可调（柱宽优先 clamp、组放不下等比收窄） | ⭐✅ | 🟡 pointPadding/groupPadding 换算 | 🟡 barSpace 自动 |
| 柱体圆角（堆叠仅链末段圆角） | ✅ | ✅ borderRadius | ✅ |
| 最小柱高/条长 minPointLength（小值柱仍可见） | ✅ 2026-09-01 | ✅（Highcharts 同名） | ❌ |
| 柱体描边 borderColor/borderWidth | ✅ | ✅ | ✅ barBorder |
| 悬浮柱形态（borderRadius 全圆 + pointPadding 拉缝） | ❌ | ✅（组合实现） | ❌ |
| Y 轴/值轴反向 reversed | ❌ | ✅ | ✅ inverted |

### 2. 柱体颜色与标线

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 逐柱颜色 colorByPoint（barColors 按类目循环，传调色板即可） | ✅ 2026-09-01 | ✅ | ❌（需自建 formatter 分色） |
| 负值换色 negativeColor | ✅ | ✅ | ❌ |
| 分段变色 zones（按值区间） | ❌ | ✅ | ❌ |
| 系列阴影 shadow | ❌ | ✅ | ✅ |
| 标线 plotLines（阈值线/标签/虚线/轴绑定，模型级） | ✅ | ✅ | ✅ LimitLine |
| 色带 plotBands（区间背景色块） | ❌ | ✅ | ❌ |

### 3. 堆叠

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 普通堆叠 | ✅ | ✅ | ✅ |
| 正负分开链（同列正负各起各的基线） | ⭐✅ | ❌（Highcharts 行为混乱） | ✅ |
| 百分比堆叠 percent（每列必满 100%）+ 统一基准 percentFixed(max:) | ⭐✅（percentFixed 是扩展，Highcharts 没有） | 🟡 仅 percent | ❌ |
| 堆叠段分隔线（独立颜色参数，非 borderWidth 模拟） | ⭐✅ | 🟡（borderWidth 0.x 模拟） | ❌ |
| 堆叠总量标签 stackLabels（列顶合计） | ❌ | ✅ | ❌ |
| 双值轴（次轴独立刻度/域，Column 支持；Bar 不支持=设计决定） | ✅ | ✅（多 Y 轴 >2） | ✅ axisDependency |

### 4. 数据与轴系

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 空值跳过（`.nan` 该类目无柱，堆叠链不被破坏） | ✅ | ✅ | ✅ |
| 刻度四档自定义（positions/interval/count/auto）+ formatter | ✅ | ✅ | ✅ granularity/forceLabels |
| 类目轴贴边（首柱贴轴起点，-0.5 起坐标） | ✅（须显式 min/max，默认点居中） | ✅ | ✅ |
| 轴标签旋转 | ❌ | ✅ | ✅ |
| 轴百分比留白（spaceTop/spaceBottom） | ❌（nice padding 固定） | ✅ | ✅ |
| 对数轴 logarithmic | ❌ | ✅ | ❌ |
| X 轴（类目轴）reversed | ❌ | ✅ | ✅ |

### 5. 数据标签

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 开关/位置/系列级覆盖/formatter（堆叠标各段值） | ✅ | ✅（align/x/y 全自由） | ✅ |
| 标签边框/底色/圆角/旋转 | ❌ | ✅ | ❌ |
| 大数据量保护（>200 自动跳过、缩放后恢复） | ⭐✅ | ❌ | ❌ |

### 6. 交互（弹窗/准线/手势，与折线图共享层）

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 整列 shared 弹窗 + 十字准线（样式可配） | ✅ | ✅ | ✅ |
| 弹窗内容自定义/文本模板（header/valueSuffix/decimals） | ✅ | ✅ | ✅ |
| 捏合缩放轴向 x/y/xy（Bar 的 `.y` = 类目轴放大，见第四节） | ✅ | ✅ zoomType | ✅ |
| 锚点跟手/平移/惯性减速/橡皮筋回弹 | ✅ | 部分（WebView 手势） | ✅ |
| 双击重置（两轴） | ✅ | ✅ | ⚠️ 双击是放大（语义不同） |
| 点击选中柱高亮（states/hover 视觉） | ❌ | ✅ states | ✅ highlight |
| 图例 legend（点击隐藏系列） | ❌ | ✅ | ✅（可滚动/自定义） |

### 7. 周边能力

| 能力 | 我们 | AAChartKit | Charts |
|---|---|---|---|
| 动画 easing 可选 | ❌（单一 ease） | ✅ 多种 | ❌ |
| 无数据占位文案 | ❌ | ✅ | ✅ noDataText |
| 极坐标 polar（极区柱图） | ❌ | ✅ | ❌ |
| 瀑布图 waterfall（组合实现：堆叠+透明桥系列） | ❌ | ✅（组合） | ❌ |

## 二、剩余缺口（按建议优先级）

### 第 1 档（高价值低成本，下一个建议批次）
| 缺口 | 价值 | 预估成本 | 备注 |
|---|---|---|---|
| 色带 plotBands（区间背景色块） | 中：达标区/超标区一目了然 | 低-中 | 与 plotLines 同源（区间矩形层，挂轴网格之上系列之下） |
| 系列阴影 shadow | 低-中：立体感 | 低 | CALayer.shadowXxx 直配 |

### 第 2 档（中成本）
| 缺口 | 价值 | 预估成本 | 备注 |
|---|---|---|---|
| 图例 legend（点击隐藏系列） | 高：系列多时必须能关；demo 也需要 | 中 | 与折线图同一缺口，实现后两图共享 |
| 堆叠总量标签 stackLabels | 中：合计场景常用 | 低-中 | 堆叠链顶数值，复用数据标签层 |
| zones 分段变色（按值区间） | 中：超标变色与标线同源 | 中 | 与 plotLines 同构（value 区间 → 颜色）；负值换色已是单区间特例 |

### 第 3 档（高成本/按需）
| 缺口 | 价值 | 预估成本 | 备注 |
|---|---|---|---|
| 点击选中柱高亮 | 中 | 中 | 需命中几何→视觉反馈；shared tooltip 已有命中可复用 |
| Y 轴 reversed / X 轴 reversed | 中 | 高 | 几何符号翻转，波及刻度/网格/零轴/命中/堆叠 |
| 瀑布图 waterfall | 中 | 中（组合） | 堆叠+透明桥系列+逐柱颜色已具备原材料，缺封装形态 |
| 悬浮柱形态 | 低 | 低-中 | 全圆角 + pointPadding 组合 |
| 轴标签旋转 / 轴百分比留白 | 低 | 低-中 | tick label transform / makeValueDomain 微调 |
| 对数轴 logarithmic | 低（受众窄） | 高 | 值映射整条链路换算 |
| 标签边框/底色/旋转 | 低 | 中 | 数据标签绘制层扩展 |
| 多 Y 轴（>2） | 低 | 高 | 有效轴索引泛化 |
| 极坐标 polar | 低 | 很高 | 整套坐标系 |

## 三、我们独有/领先项

1. **百分比堆叠双形态**：percent（每列必满 100%）+ percentFixed(max:) 统一基准（可不满），后者是 Highcharts 没有的扩展。
2. **正负分开链堆叠**：同列正负各起各的基线，语义清晰（Highcharts 同配置行为混乱）。
3. **堆叠段分隔线**独立参数，不必用 borderWidth 0.x 模拟。
4. **双间距参数体系**：组内间距/组间距独立可调，柱宽优先 clamp、组放不下等比收窄、组宽内容驱动居中。
5. **最小柱高**在负值方向同样生效（向下 clamp），且与堆叠正确互斥（堆叠语义优先）。
6. **大数据量**：复合 path 同色合一层，1440 柱层级数与单色渲染一致；数据标签 >200 保护。
7. **手势体验**：锚点跟手缩放（x/y/xy）、惯性减速、橡皮筋回弹、双击重置两轴、整列弹窗跟手不闪。
8. **原生 CALayer 渲染**（AAChartKit 是 WebView+JS）。

## 四、语义差异备忘（同功能不同行为）

- **双击**：我们/AAChartKit = 重置视口；Charts = 放大。
- **Bar 的缩放轴向**：我们 `.y` = 纵向类目轴放大（与 Column 的 `.y`=值轴相反方向语义）；Charts 的 scaleY = 值轴缩放。使用时以「屏幕方向」理解即可。
- **Bar 不支持双值轴/类目贴边**：设计决定（水平图值轴在 X，次轴/贴边场景罕见），非缺口。
- **类目轴默认点居中**：首柱不贴原点是标准（坐标域 -0.5…n-0.5，AAChartKit/Highcharts 同）；要贴边须显式 min/max。
- **minPointLength 仅非堆叠生效**：堆叠时抬小值会破坏累计基线语义（Highcharts 同款限制，柱长以真值为准）。
- **逐柱颜色优先级**：负值换色 negativeColor > barColors > 系列色（负值语义优先于装饰性配色）。

## 五、更新日志

- 2026-09-01（`7380fa5`）：补齐最小柱高/条长（`columnMinPointLength`）+ 逐柱颜色（系列 `barColors` 按类目循环 = colorByPoint）；本文档建立。
- 更新约定：每补齐一项，把对应行 ❌/🟡 改 ✅（标注日期/提交），并从「剩余缺口」表移除。
