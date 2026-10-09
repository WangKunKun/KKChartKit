# 通用图表模型验收记录

日期：2026-10-03（Asia/Shanghai）。设计与使用入口：[通用模型指南](../../charts-neutral-model-guide.md)。本批只交付通用描述、HYMCharts 适配、OC 文档入口和 Demo，没有实现 Highcharts/ECharts/DGCharts 适配器或旧 HMAA 自动迁移。

环境：Xcode 26.3、iPhone 16 Pro / iOS 18.6 / arm64 模拟器。主工程 Debug，独立 framework 与 Swift/纯 OC 宿主 Release。没有真机运行、签名发行或第三方引擎实际运行结论。

## 最终结果

| 验证 | 结果 | 证据 |
|---|---|---|
| 全部主工程单元 + 两项相关 UI | **386/386 通过、0 失败、0 跳过**；384 单元含本次新增 20 项，另有 2 项 UI | [机器摘要](main-summary.json)、[完整日志](main-tests.log.gz)；`/tmp/HYMChartSpecificationVerified.xcresult` |
| Release 公开 Swift / 纯 OC 宿主 | **2/2 通过、0 失败、0 跳过**；双方均包含 neutral=true、既有真实命中及 30/30 释放断言 | [机器摘要](public-import-summary.json)、[日志](public-import-tests.log.gz)；`/tmp/HYMChartSpecificationPublicImport.xcresult` |
| 独立 Release framework / 宿主构建 | TEST BUILD SUCCEEDED；95 份 SDK Swift 源文件，6 个 SwiftUI 包装 | [构建日志](HYMChartSpecificationIntegration-build-verified.log.gz)、[产物审计](framework-audit.json) |
| Foundation-only 核心 | Swift 6 严格并发独立编译/示例生成通过 | [校验记录](core-validation.json) |
| 真实 UI 截图 | 两张最终通用模型预览已打开复核；主轴网格关闭生效、缺测留空、原始正负方向正确 | [原附件清单](screenshots/manifest.json)、[散列](screenshot-hashes.json) |

本轮没有执行全部 34 个主工程 UI 用例，不能将“全部单元 + 2 项相关 UI”写成全 UI 回归。早期成功轮和专项轮不累加到上述最终计数。新核心独立通过 Swift 6，不代表整个既有 SDK 已完成 Swift 6 迁移；Release 仍有原有 existential/变量警告。

## 验收内容

- Foundation-only 核心通过 Swift 6 + strict-concurrency=complete 独立编译，并生成 [energy.json](../../../Examples/ChartSpecifications/energy.json)；不是把 UIKit 一起编译后声称解耦。
- 新测试覆盖稳定身份、同名类目、稀疏/乱序对齐、显式缺测与隐式空位、0/负数/非法数值、引用完整性、单位分组、百分比分母、外观/缺测规则、JSON 格式和版本、不可变快照、实际网格方向、四种原生图形的原值命中、OC 失败保留与错误恢复。
- UI 验证同页“通用模型”切换、真实数值 X 的不支持诊断、恢复有效配置和返回原面板；另跑原有六种图表入口与实时属性操作。
- 两个独立宿主只使用公开导入，共用同一份 JSON，新增 neutral=true 断言，同时保留既有真实命中与 30/30 释放检查。
- [framework-audit.json](framework-audit.json) 记录最终 Release 模拟器产物审计：生成头含新 OC 入口，Swift interface 含中立模型和适配协议，framework 不含 AA/JS/WebKit/App/Demo 依赖或样本资源。JSON 仅进入两个宿主。

## 发现与处理

1. 初次构建发现 Swift throwing 方法不能把 OC 枚举作为 NSError 约定的返回值。`nativeChartKind()` 保留为 Swift 入口，OC 使用返回对象的 `makeNativeBridgeWithFrame:error:`。首轮失败日志保留为 [HYMChartSpecificationFocused.log.gz](HYMChartSpecificationFocused.log.gz)，不能当成通过记录。
2. 视觉复核发现只转换 axis.showsGridlines 不会控制原生主轴网格。适配器补上映射到屏幕横/竖主题开关，并用真实网格路径覆盖四种开关组合及横向/纵向图；原生“只开次轴、关闭主轴”目前不支持，返回诊断。
3. JSON 使用显式 kind/mode 字段，不依赖 Swift 合成的 `_0` 枚举编码；最终验证包含所有有关联值的枚举往返和错误判别字段测试。

## 复现

在项目根目录运行；结果路径须不存在，可替换为本机可用模拟器 UUID。

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartSpecificationDerivedData \
  -resultBundlePath /tmp/HYMChartSpecificationRerun.xcresult \
  -only-testing:SwiftFunctionProjectTests \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery \
  -only-testing:SwiftFunctionProjectUITests/ChartDemoUITests/testSingleEntryPagesAndLiveThemeControls \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

python3 Examples/ChartsIntegration/generate_project.py
xcodebuild test -project Examples/ChartsIntegration/ChartsIntegration.xcodeproj \
  -scheme ChartsIntegration -configuration Release \
  -destination 'platform=iOS Simulator,id=781C9872-DAE0-4996-A623-36115772B60F' \
  -derivedDataPath /tmp/HYMChartSpecificationIntegration \
  -resultBundlePath /tmp/HYMChartSpecificationIntegrationRerun.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
```

本批 [source-inputs.json](source-inputs.json) 只记录新增/直接改动输入的散列，不是工作区完整源码快照。构建还包含前序未提交改动；不使用 Git HEAD 冒充完整测试输入。完整 xcresult 位于 `/tmp`，随系统清理可能丢失；此目录的摘要/日志/截图用于持久记录。
