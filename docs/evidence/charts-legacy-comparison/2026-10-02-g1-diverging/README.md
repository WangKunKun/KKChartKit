# G1 正负分链：2026-10-02 验证记录

本目录对应显式 `StackedAreaBoundaryMode.diverging` / `stackedAreaUsesDivergingChains`，不把旧 `.independent` 或 `.followBaseline` 的展示规则改成新规则。完整契约见[使用指南](../../../charts-diverging-stacks-guide.md)，关机前交接见[任务进度](../../../charts-g1-task-progress-2026-10-02.md)。

## 环境与最终结果

- 本机 macOS 26.4，Xcode 26.3；iPhone 16 Pro、iOS 18.6 Simulator、arm64。
- 模拟器 UUID：`781C9872-DAE0-4996-A623-36115772B60F`。
- 主工程在独立 DerivedData 中编译测试；独立 HYMCharts framework 使用 Release。设备产物为未签名 `iphoneos` 构建，不是真机安装/运行。
- 这是未提交工作区的验收，包含前序 G2–G5 等改动。源码、测试及工程输入散列见 [input-manifest.json](input-manifest.json)，不能用 Git HEAD 单独复现此工作区。

| 验证 | 结果 | 证据 |
|---|---|---|
| 全部主工程单元 + 两个新增 G1 UI | **366/366 通过**，即 364 个单元 + 2 个 UI；无跳过 | [main-tests-summary.json](main-tests-summary.json)、[日志](main-tests.log.gz) |
| 最终版本全部 UI 重跑 | **33/33 唯一用例通过**，即 30 个 ChartDemo + 3 个模板 UI；参数化启动共 36 次执行，无跳过 | [all-ui-summary.json](all-ui-summary.json)、[用例树](all-ui-tests.json)、[日志](all-ui.log.gz) |
| 独立 Release Swift / 纯 Objective-C 宿主 | **2/2 通过**，两端各 30 次配置/布局/释放均为 30/30，实际点击回传 `hit:power:500` | [public-import-summary.json](public-import-summary.json)、[日志](public-import.log.gz) |
| Release 模拟器 framework 和宿主 | **TEST BUILD SUCCEEDED** | [simulator-build.log.gz](simulator-build.log.gz) |
| Release iOS 设备 framework | **BUILD SUCCEEDED**（未签名） | [device-build.log.gz](device-build.log.gz) |
| 两套独立 framework 产物审计 | 通过：新 Swift/OC 入口、公开诊断、六个 SwiftUI 包装、生成头、`@rpath`、不含 AA/JS/WebKit/App 依赖或 Demo 资源 | [设备](device-product-audit.json)、[模拟器](simulator-product-audit.json) |

**最终主工程独立用例覆盖为 397 个（364 单元 + 33 UI），分上述两批执行，两个新增 G1 UI 在两批中重复；另有 2 个独立接入用例。不是同一次命令运行了 397 项，也不将重复项累加。**

计数使用 xcresult 顶层 `totalTestCount`，而非参数化启动测试的重复运行次数；不同批次有重叠的测试不能简单累加为独立用例数。

### 产物 SHA-256

- iOS 设备：`5d04d6517d6b73ced08247900c2d9e20d34e4dfb58b5f15279ec01d9ddfdc76f`
- iOS 模拟器：`579d59bd766e94ac572652649474f79239b4643cb7045630ffc2a0c0e3b0998e`

散列对应本目录审计的二进制，不代表已签名发行包。产物内仍有已有的未来 Swift 语言模式 existential 警告、可改为 `let` 的变量提示；没有声称构建零警告，也未在 G1 内扩展为 Swift 6 迁移。

## 专项覆盖

### 几何：14 个新增用例

`DivergingStackGeometryTests`：

- 真实曲线根分段，而非只把原始端点拆成两份数据。
- 普通堆叠 **125 种三层混合线型组合**，比对原贡献参考值、共享正负控制网。
- 自动百分比另 **125 种组合**，比对原始贡献有理参考曲线及正负总跨度 100%。
- 缺测、短尾、空数组统一断段；隐藏、非堆叠、不同轴/stackID/grouped 隔离。
- 非面积折线仍参与贡献和分母；普通/grouped/固定百分比的既有数值语义。
- 区间内部同时归零的单侧比例极限、原始零分母采样断段、整段恒零没有桥接描边。
- 强制预算为零时整组共享直线降级；不逐系列降级到互不相干的累计边界。
- 极小负贡献不翻正；1,500 点 × 6 系列的确定性输入保持有限、共享的轮廓。

### 渲染与数据：8 个新增用例

`DivergingStackRendererTests`：

- 统一缺口不改原始有效命中、ID、索引，不为几何根虚构 marker/业务采样。
- 五种堆叠模式下全空、全缺测、Infinity、单点、短尾安全；清空后无残留诊断。
- Line / Combined / Demo / OC 几何一致；对象池开关/重复配置一致。
- Combined 的柱族缺测不影响线族。
- 现有 Demo 场景可加载；冲突配置禁用但不清值，切回旧模式恢复。
- 显隐、320/834/480 宽度、视口、模式变更后没有旧面积残留。
- 自动双轴包含混合阶梯的采样间峰值，同时尊重显式范围与既有模式。
- 真实 renderer 诊断发布及清理，不用 UI 选择值冒充实际参与/降级结果。

扩展 `StackedAreaStrokeTests` 的原像素用例：沿基线与正负分链两模式 × 五种线型 × 两种线宽 × 1×/2×/3×，检查描边非空且不超出本层面积，容许已定义的物理像素抗锯齿边缘。

### 两个新增端到端 UI 用例

- `testDivergingStackPresetDiagnosticsAndGapControlsRecover`：折线、混合两页均实际报告 3 个参与系列、未降级；规则文本、冲突控件禁用、切回后恢复。
- `testDivergingStackObjectiveCModeAndRawCallback`：真实 OC 分段控件、普通/百分比/不堆叠切换、两种图形族和点击回调；原始 `1000/-500` 与绘制 `66.67/-33.33` 分开展示。

## 截图与人工复核

截图均来自最终通过的测试，不是生成图，也不是独立手工拼图。原附件名称、源测试、时间和 SHA-256 见 [screenshot-manifest.json](screenshot-manifest.json)。

| 图像 | 内容 |
|---|---|
| [renderer-mixed-styles.png](screenshots/renderer-mixed-styles.png) | 平滑正负基底 + 跨零直线 + 薄层阶梯；中间缺测统一留空 |
| [renderer-unified-gap.png](screenshots/renderer-unified-gap.png) | 缺测/真实根与原始命中专项快照 |
| [renderer-percent-oc.png](screenshots/renderer-percent-oc.png) | OC 入口生成的共享百分比几何 |
| [ui-swiftui-line.png](screenshots/ui-swiftui-line.png)、[ui-swiftui-combined.png](screenshots/ui-swiftui-combined.png) | 实际 Demo 页面、参与数与契约说明 |
| [ui-swiftui-line-restore.png](screenshots/ui-swiftui-line-restore.png)、[ui-swiftui-combined-restore.png](screenshots/ui-swiftui-combined-restore.png) | 切换兼容模式后的控件恢复 |
| [ui-oc-line.png](screenshots/ui-oc-line.png)、[ui-oc-combined.png](screenshots/ui-oc-combined.png) | OC 页面原始数值/绘制数值回调 |
| [public-swift-import.png](screenshots/public-swift-import.png)、[public-oc-import.png](screenshots/public-oc-import.png) | 独立宿主公开导入、30/30 释放及实际命中 |

已人工打开最终的混合线型轮廓、SwiftUI 折线页、OC 折线页，以及 Swift/OC 独立宿主页，核查统一缺口、正负切换、共享薄层、原值回调和释放结果。独立宿主截图显示的是原有基础命中场景；正负缺测百分比用于其内部 30 次创建/释放循环，不能把基础截图当作正负几何截图。

## 失败记录与修复，不隐藏先前红灯

[earlier-regression-summary.json](earlier-regression-summary.json) 保存较早完整回归：**394 个唯一测试，393 通过、1 失败**。失败为新增 G1 UI 的实际诊断未出现，不是一次全绿结果；修复图表下方诊断错误依赖 sampling 开关后，最终 366 项已通过。该早期批次包含此前 28 个 ChartDemo UI 和 3 个模板 UI。最终源码的完整 UI 重跑单独存于 `all-ui-summary.json`，33/33 通过。

本轮收尾还修复并补验：

1. 所有 series 都为空时没有已准备数值行，之前值域估计会越界；现在轮廓及值域均有空输入保护，并把渲染测试扩大至五种堆叠模式。
2. 百分比短尾预处理数组可能补齐，但原始数组未补齐；值域估计必须按原始/数值行共同可用范围工作。
3. OC `UISegmentedControl` 的容器 enabled 状态不能代表各 segment 的可访问启用状态；明确设置每个 segment，再验证“不堆叠禁用 → 普通恢复”。
4. UI 测试显式设为竖屏，按需滚动实际 Lazy Form；不把未加载的行或错误的容器状态当作功能失败。

上述中间失败的本机结果包仍位于 `/tmp/G1DivergingVerified.xcresult`、`/tmp/G1DivergingAcceptance.xcresult` 等路径。本目录最终结果不是重命名旧失败包；三个最终测试包单独生成；完整 UI 批次直接使用最终已编译产物，无源码改动。

## 可复现命令

在仓库根目录执行；本机路径固定在 2026-10-02，换机器需先替换 UUID。重复运行请给 `-resultBundlePath` 换一个不存在的路径。

```sh
# 全部单元 + 两个新 G1 UI（最终 366 个）
xcodebuild test -project SwiftFunctionProject.xcodeproj \
  -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/G1DivergingCleanDerivedData \
  -resultBundlePath /tmp/G1DivergingComplete.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testDivergingStackPresetDiagnosticsAndGapControlsRecover \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testDivergingStackObjectiveCModeAndRawCallback \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

# 最终版本的所有 UI（复用上面已编译的测试产物）
xcodebuild test-without-building -project SwiftFunctionProject.xcodeproj \
  -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/G1DivergingCleanDerivedData \
  -resultBundlePath /tmp/G1DivergingAllUIComplete.xcresult \
  -only-testing:SwiftFunctionProjectUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

# 独立 Release 框架与 Swift/纯 OC 宿主
xcodebuild build-for-testing -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/G1DivergingIntegrationDerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/G1DivergingIntegrationDerivedData \
  -resultBundlePath /tmp/G1DivergingPublicImportComplete.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

# 设备构建与两套产品审计
xcodebuild -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -target HYMCharts -configuration Release -sdk iphoneos build \
  SYMROOT=/tmp/G1DivergingDevice/products OBJROOT=/tmp/G1DivergingDevice/objects CODE_SIGNING_ALLOWED=NO
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/G1DivergingDevice/products/Release-iphoneos/HYMCharts.framework
python3 Examples/ChartsIntegration/check_product.py \
  /tmp/G1DivergingIntegrationDerivedData/Build/Products/Release-iphonesimulator/HYMCharts.framework
```

原始 xcresult 留在上述 `/tmp`，可被系统清理；本目录保存了可随仓库保留的摘要、压缩日志、产物审计、截图和源码输入散列，但不声称保存了完整 xcresult、二进制或完整源码归档。

## 验收边界

- 完成的是新模式文档所定义的正负分链、共同缺测、百分比和共享描边契约，不强迫旧模式更改外观。
- 自动百分比的正常曲线逼近目标为每累计边界 0.05 屏幕 pt；整组降级可观察，但降级后不保证原曲线外观/该误差目标。
- 真实设备抗锯齿、半透明渐变、超薄层、真实业务组合、长时间/超大数据性能仍要在业务工程验收。
- 设备构建不是设备测试；30 次释放不是长时压力/内存峰值测试；1,500 × 6 用例不是无限输入承诺。
- 不处理 G6 不等间隔 XY/新增坐标模型、正式旧业务适配、外围 UIView、签名/发布分发。此处没有宣布整个旧模块替换完成。
