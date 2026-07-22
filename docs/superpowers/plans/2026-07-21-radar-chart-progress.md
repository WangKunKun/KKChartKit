# 蛛网图组件 · 实现进度（断点恢复用）

> 最后更新：2026-07-22
> 执行方式：superpowers subagent-driven-development（controller 直接执行 + `xcodebuild` 权威验证 + 截图目视 + 运行时 `leaks`；机械 task 不派弱模型 reviewer）
> 当前状态：**Task 1-9 全部完成** ✅。组件功能完整、编译通过、运行时零泄漏（单次动画 / 4 次重播 / Task 9 底色层 均 leaks=0）。

---

## 本次（2026-07-22）完成 Task 7-9

### Task 7：入场展开动画 ✅
- 数据层 `transform.scale 0.01→1` + `opacity 0→1` 从中心展开；网格/轴淡入；分数 `CADisplayLink` 0→目标 easeOut 滚动。
- 触发链：`playEntranceAnimation()` → `pendingAnimation=true` + `setNeedsLayout()` → `layoutSubviews` 末尾 `performEntranceAnimation`。
- **内存**：`CADisplayLink` 三处 invalidate（重入开头 `stopDisplayLink` / `onScoreTick` t≥1 / `deinit`）。
- 验证：编译通过；`exp_a/b/end` 三帧（临时 duration=3.0 抓展开过程，已改回 0.6）确认从中心展开；运行时 `leaks`=0。

### Task 8：demo + 标签裁剪修复 + 内存抽查 ✅
- **标签裁剪修复（方案 A 轻量版）**：`self.layer.masksToBounds=false`（标签可画在卡片外），圆角裁剪下放 `gradientLayer`（内缩 `labelOuterPadding`）；`maxRadius` 改为基于卡片半边长 `half - labelOuterPadding - (vertexDotRadius+2)`；标签 center = `radius + labelOuterPadding` 落在卡片外、屏幕内。spec §10「顶点外侧」满足。
- `dotRadius=5` 硬编码迁入 `theme.vertexDotRadius`。
- demo：6 中文维度 + 双击切换「自动均值/手动 88/隐藏」+ `dispatch_after` 触发动画。
- 验证：编译通过；标签清晰在外侧无裁剪；**4 次 CADisplayLink 创建/销毁后 leaks=0**（临时 DEBUG 自动重播验证，已删除）。

### Task 9：网格每层底色 + 边框开关（spec §15）✅
- `GridRingFill` enum：`.none`（默认向后兼容）/ `.gradient(from:to:)` 外→内插值 / `.colors([...])` 每圈独立、不足回退末色。
- `gridFillContainerLayer`（CALayer 容器）每圈独立 `CAShapeLayer`，**倒序**挂载（内圈在上覆盖外圈中心）；`lerpColor` RGBA 插值。
- `showsGridLines`/`showsAxes` 与底色**正交**（`isHidden`）。
- z 序修正：背景渐变 → 网格底色 → 网格描边 → 放射轴 → 数据…（轴从网格下移到网格上）。
- 入场动画：底色容器与网格同步淡入。
- 验证 4 组合截图（改 Theme 默认值逐个编译）：`.none`(=Task8 向后兼容) / `.gradient` / `.colors` / `colors+关描边关轴`(正交)；均编译通过 + leaks=0；**默认值已恢复 `.none`+true+true**。

---

## 进度表

| Task | 内容 | 状态 | 验证 | 主要文件 |
|---|---|---|---|---|
| 1 | Swift 混编最小探针 | ✅ | 编译+log | `HYMSwiftProbe.swift`, pbxproj(+`SWIFT_VERSION=5.0`) |
| 2 | 数据模型 Dimension/Theme/Model | ✅ | 编译 | `RadarDimension.swift`, `HYMRadarChartTheme.swift`, `RadarChartModel.swift` |
| 3 | 几何纯函数 + DEBUG 自检 | ✅ | 编译+断言 | `RadarGeometry.swift`, `RadarSelfTest.swift` |
| 4 | View 骨架（渐变+网格+放射轴） | ✅ | 编译+截图 | `HYMRadarChartView.swift` |
| 5 | 数据多边形 + 顶点圆点 + 标签 | ✅ | 编译+截图 | `HYMRadarChartView.swift` |
| 6 | 中心分数双模式 | ✅ | 编译+截图（≈72.5） | `HYMRadarChartView.swift` |
| 7 | 入场展开动画 | ✅ | 编译+三帧+leaks=0 | `HYMRadarChartView.swift` |
| 8 | demo + 标签裁剪修复 + 内存抽查 | ✅ | 编译+截图+4次重播 leaks=0 | `HYMRadarChartView.swift`, `HYMRadarChartTheme.swift`, `ViewController.m` |
| 9 | 网格底色 + 边框开关（spec §15） | ✅ | 4 组合截图+leaks=0 | `HYMRadarChartView.swift`, `HYMRadarChartTheme.swift` |

---

## 已知遗留（非阻塞，按需处理）

- **长文案标签越界**（spec 风险 #5）：当前 demo 用 2 字短文案（进攻/防守…），标签略超 `HYMRadarChartView` bounds（self 不裁剪、屏幕内可见）。若接真实业务出现长文案，需加字号自适应/截断，或增大 `labelOuterPadding`。
- **OC 端无法配置 theme**：`GridRingFill` 等是 Swift enum/struct，OC 不可见，demo 用默认主题。若需 OC 配置底色/开关，需另加 `@objc` 便捷入口（如按字符串/索引映射）。

---

## 关键技术发现（踩过的坑，保留备查）

1. **文件系统同步根组**（`PBXFileSystemSynchronizedRootGroup`, objectVersion 77）：`测试111/` 下新文件自动编译，**不用改 pbxproj**。
2. **build 产物在项目内 `build/` 目录**（不是 `~/Library/Developer/Xcode/DerivedData`）。
3. **首次启用 Swift 必须设 `SWIFT_VERSION = 5.0`**（Debug+Release target-level），否则 `SWIFT_VERSION '' is unsupported`。
4. **@objc 桥接坑**：① Swift 默认参数不保留 → OC 要传全参；② `Double?` 不能 `@objc`（用 `NSNumber?` + `@nonobjc centerScoreValue`）；③ 含 struct 的成员要 `@nonobjc`；④ **Swift enum/struct（带 associated value）OC 完全不可见**（Task 9 的 GridRingFill 即如此）。
5. **SourceKit 诊断大面积假阳性**（`No such module 'UIKit'` 等）→ **以 `xcodebuild` 的 `** BUILD SUCCEEDED **` 为唯一权威**，别为假阳性改代码。
6. **`2 * .pi` 触发 `ambiguous use of 'pi'`** → 用 `2 * CGFloat.pi`。
7. 模拟器需 iOS ≥ 26.2；bundle id = `hm.--111`；本次用 iPhone 17 Pro `FB74ECC0-DDCA-4168-A93D-81B91C56432C`。
8. **运行时内存验证**：`xcrun simctl spawn <UDID> leaks <PID>` 可对模拟器进程做泄漏检测（本组件各阶段均 0 leaks）。
9. **模拟器截图抓短动画**：`simctl io screenshot` 单张约 0.8s，抓 <1s 的动画中间帧不稳；验证展开过程时临时把 `duration` 调到 3.0s 抓帧，再改回。

---

## 审查策略说明
本项目环境下 **haiku spec-reviewer 不可靠**，且 SourceKit 持续假阳性。controller 改为：**`xcodebuild`（权威）+ 读关键代码 + 截图目视 + 运行时 `leaks`** 作为审查手段，机械 task 不派弱模型 reviewer；复杂 task（动画/内存）额外用 leaks 与多次重播验证。

---

## 相关文档
- 设计 spec：`docs/superpowers/specs/2026-07-21-radar-chart-design.md`（§15 为 Task 9 依据）
- 实现 plan（8 Task 完整代码）：`docs/superpowers/plans/2026-07-21-radar-chart.md`
- 项目记忆：`test111-swift-mixed-build`（OC/Swift 混编与构建特性）
