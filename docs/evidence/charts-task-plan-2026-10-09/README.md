# 2026-10-09 任务文档核对记录

日期按 Asia/Shanghai。本批仅做任务文档/源码入口核对、离线检查和排期，**未执行 Xcode 构建、XCTest、模拟器 UI、真机或新的视觉验收**。

## 文档编辑前实际执行

- [检查命令、退出码及旧清单比对](review-before.json)：2026-10-03 G1 v2 的限定范围输入 **179/179** 与静态证据 **23/23** 哈希一致。
- [旧声明检查](inventory-check.log)：197 项声明完整性通过。
- [覆盖矩阵检查](coverage-check.log)：40 / 46 / 104 / 7，58 主题、13 原生边界；矩阵和生成 Markdown 一致。
- [Python 测试](python-tests.log)：**24/24**。
- [原有文档/截图检查](evidence-check-before.log)：57 文档、1150 本地链接、45 张当前批次截图完整性通过；只检查内容/来源/哈希，不等价于运行或目视验证。

最近运行结果仍引用 [2026-10-03 的 G1 v2 验收](../charts-neutral-g1-2026-10-03/README.md)：395 单元 + 2 相关 UI，以及独立 Release 双宿主 2 项。本批不将历史结果记成重新通过。

## 本批更改及收尾

1. 新增[下一步任务计划](../../charts-next-task-plan-2026-10-09.md)。
2. 更新[总替换计划](../../charts-legacy-replacement-plan.md)的规划入口、“最新交付”小节和日期；保留旧批次记录，不覆写旧证据清单。
3. 重新生成[覆盖矩阵 Markdown](../../charts-neutral-model-coverage.md)，仅同步总计划引文的行号（135 → 139），JSON 分类/数量未改。
4. 新增本目录离线核对记录。

文档编辑后重跑[链接/截图检查](evidence-check-after.log)、覆盖/声明检查及 Python 回归；结果与相对旧输入清单的最终变化见[收尾核对](review-after.json)。旧源清单中的总计划与生成矩阵 Markdown 因此出现**两项预期文档差异**，不代表 SDK 源码变化；旧 evidence 内容仍保持不变。

没有修改功能源码、测试、样例 JSON、项目配置或审计脚本；没有 Git commit/push/reset、依赖安装、后台自动任务或关机。工作区其他变更为原有工作，本批不据此重新归因。

### 首次收尾检查发现并修复的文档漂移

总计划插入更新说明后，矩阵引文行号改变，首次[覆盖检查](coverage-check-stale-first.log)及 [Python 回归](python-tests-stale-first.log)捕获 Markdown 未同步（23/24，1 项同步测试失败）。通过既有 `check_chart_neutral_coverage.py --write` 重新生成，仅改变引文行号，再运行全部离线检查。首次失败记录保留，不将其写成通过；最终结果以 `review-after.json` 为准。
