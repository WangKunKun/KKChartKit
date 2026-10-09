#!/usr/bin/env python3
"""Validate the reviewed legacy → neutral schema → backend matrix; render its Markdown.

Offline structural/anchor checks, not semantic proof or a renderer test runner.
No field is auto-classified. New legacy declarations require a reviewed entry.
"""
from collections import Counter
from datetime import date
import argparse
import json
from pathlib import Path
import re
import sys

from check_chart_migration_inventory import declarations

ROOT = Path(__file__).resolve().parents[1]
MATRIX = 'docs/charts-neutral-model-coverage.json'
REPORT = 'docs/charts-neutral-model-coverage.md'
DISPOSITIONS = {
    'expressed': '已表达', 'schema_gap': '需新增通用语义',
    'external': '外层 UI / 运行时 / 兼容层', 'unsupported': '应报不支持',
}
NATIVE = {'supported': '已有', 'partial': '部分/语义有差异',
          'unsupported': '缺失', 'external': '非渲染职责'}
ADAPTER = {'mapped': '已映射', 'partial': '仅部分映射', 'unmodeled': '未建模，尚无对应诊断入口',
           'rejected': '已有显式拒绝', 'external': '外部处理，不是 schema 字段'}
EVIDENCE_KINDS = {'schema', 'adapter', 'native', 'test', 'guide', 'legacy'}
NATIVE_REVIEW = {'g1-boundary', 'zones', 'value-color-zones', 'axis-basic', 'axis-weight', 'ticks', 'axis-value-format', 'annotations',
                 'annotation-order', 'data-labels', 'selection', 'continuous-domain',
                 'reversed-axis', 'backend-limits', 'secondary-grid'}


class CoverageError(ValueError):
    """Actionable audit input failure, reported without a traceback by the CLI."""


def require(condition, message):
    if not condition:
        raise CoverageError(message)


def text(value):
    return isinstance(value, str) and bool(value.strip())


def unique(values, label):
    require(len(values) == len(set(values)), f'{label}: duplicate entries')


def local_file(root, value):
    """Reject traversal, absolute paths and symlinks escaping the repository."""
    require(text(value), 'Expected a nonempty repository-relative path')
    relative = Path(value)
    require(not relative.is_absolute() and '\\' not in value
            and all(part not in {'', '.', '..'} for part in value.split('/')),
            f'Unsafe path: {value}')
    resolved = (root / relative).resolve()
    require(resolved.is_relative_to(root.resolve()), f'Path escapes repository: {value}')
    require(resolved.is_file(), f'Missing file: {value}')
    return resolved


def load_json(path):
    """Reject duplicate object keys rather than accepting the last definition."""
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f'{path}: duplicate JSON key: {key}')
            result[key] = value
        return result
    try:
        return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs)
    except json.JSONDecodeError as error:
        raise CoverageError(f'{path}: invalid JSON: {error.msg}') from error


def fields(value, names, label):
    require(isinstance(value, dict), f'{label}: expected object')
    require(set(value) == set(names.split()), f'{label}: missing/unknown fields: '
            f'{sorted(set(value) ^ set(names.split()))}')


def string_list(value, label, allow_empty=False):
    require(isinstance(value, list) and (allow_empty or bool(value))
            and all(text(item) for item in value), f'{label}: expected string list')
    unique(value, label)


def validate(matrix, root=ROOT):
    """Return the checked inventory. Raises CoverageError on the first defect."""
    fields(matrix, 'matrixVersion asOf specificationVersion inventory evidence capabilities nativeReview entries', 'matrix')
    require(type(matrix['matrixVersion']) is int and matrix['matrixVersion'] == 1, 'Unknown matrixVersion')
    require(type(matrix['specificationVersion']) is int, 'specificationVersion must be an integer')
    require(text(matrix['asOf']) and re.fullmatch(r'\d{4}-\d{2}-\d{2}', matrix['asOf']), 'Invalid asOf date')
    try:
        date.fromisoformat(matrix['asOf'])
    except ValueError as error:
        raise CoverageError('Invalid asOf date') from error
    source = local_file(root, 'SwiftFunctionProject/Charts/Specification/ChartSpecification.swift').read_text(encoding='utf-8')
    version = re.search(r'public static let latestSchemaVersion: Int = (\d+)', source)
    require(version and int(version.group(1)) == matrix['specificationVersion'],
            'Schema version changed: re-audit coverage and migration before updating the matrix')

    require(matrix['inventory'] == 'docs/charts-legacy-field-inventory.json', 'Unexpected inventory path')
    inventory = load_json(local_file(root, matrix['inventory']))
    require(isinstance(inventory, dict) and isinstance(inventory.get('entries'), list), 'Malformed inventory')
    string_list(inventory.get('headers'), 'inventory.headers')
    for header in inventory['headers']:
        local_file(root, header)
    try:
        actual = declarations(inventory['headers'], root=root)
    except ValueError as error:
        raise CoverageError(str(error)) from error
    legacy = {}
    for entry in inventory['entries']:
        require(isinstance(entry, dict) and text(entry.get('key')), 'Malformed inventory entry')
        key = entry['key']
        require(key not in legacy, f'Duplicate inventory declaration: {key}')
        require(key in actual, f'Stale inventory declaration: {key}')
        require((entry.get('source'), entry.get('line')) == (actual[key]['source'], actual[key]['line']),
                f'Inventory source location changed: {key}')
        legacy[key] = entry
    require(set(legacy) == set(actual), f'Inventory missing declarations: {sorted(set(actual) - set(legacy))}')

    references = matrix['evidence']
    require(isinstance(references, dict) and references, 'evidence: expected nonempty object')
    for key, ref in references.items():
        require(re.fullmatch(r'[a-z][a-z0-9-]*', key), f'Invalid evidence ID: {key}')
        fields(ref, 'kind path anchor', f'evidence.{key}')
        require(isinstance(ref['kind'], str) and ref['kind'] in EVIDENCE_KINDS, f'{key}: unknown evidence kind')
        require(text(ref['anchor']) and '\n' not in ref['anchor'], f'{key}: anchor must be one nonempty line')
        contents = local_file(root, ref['path']).read_text(encoding='utf-8')
        require(ref['anchor'] in contents, f'{key}: missing evidence anchor in {ref["path"]}')
        if ref['kind'] == 'test':
            require(ref['path'].startswith('SwiftFunctionProjectTests/')
                    and ref['anchor'].startswith('func test'), f'{key}: expected an XCTest method anchor')
        if ref['kind'] == 'schema':
            require(ref['path'].startswith('SwiftFunctionProject/Charts/Specification/'), f'{key}: expected schema source')
        if ref['kind'] == 'adapter':
            require(ref['path'].startswith('SwiftFunctionProject/Charts/Adapters/'), f'{key}: expected adapter source')
        if ref['kind'] == 'native':
            require(ref['path'].startswith('SwiftFunctionProject/Charts/'), f'{key}: expected native SDK source')

    require(isinstance(matrix['capabilities'], list) and matrix['capabilities'], 'capabilities: expected nonempty list')
    capabilities = {}
    for cap in matrix['capabilities']:
        fields(cap, 'id title disposition nativeSupport adapterSupport schemaPaths finding nextAction evidence', 'capability')
        require(text(cap['id']) and re.fullmatch(r'[a-z][a-z0-9-]*', cap['id']), 'Invalid capability ID')
        key = cap['id']
        require(key not in capabilities, f'Duplicate capability: {key}')
        for name in ('title', 'finding', 'nextAction'):
            require(text(cap[name]), f'{key}: empty {name}')
        for name, choices in [('disposition', DISPOSITIONS), ('nativeSupport', NATIVE), ('adapterSupport', ADAPTER)]:
            require(isinstance(cap[name], str) and cap[name] in choices, f'{key}: unknown {name}')
        string_list(cap['schemaPaths'], f'{key}.schemaPaths', allow_empty=True)
        string_list(cap['evidence'], f'{key}.evidence')
        require(set(cap['evidence']) <= set(references), f'{key}: unknown evidence reference')
        kinds = {references[ref]['kind'] for ref in cap['evidence']}
        if cap['schemaPaths']:
            require('schema' in kinds, f'{key}: schema paths need schema evidence')
        if cap['disposition'] == 'expressed':
            require(cap['schemaPaths'] and cap['adapterSupport'] == 'mapped' and cap['nativeSupport'] == 'supported',
                    f'{key}: expressed requires schema paths and fully mapped/supported semantics')
            require({'schema', 'adapter', 'test'} <= kinds, f'{key}: expressed needs schema/adapter/test anchors')
        if cap['adapterSupport'] == 'mapped':
            require(cap['disposition'] == 'expressed', f'{key}: fully mapped must be explicitly classified as expressed')
        if cap['disposition'] == 'unsupported':
            require(cap['adapterSupport'] in {'rejected', 'unmodeled', 'external'},
                    f'{key}: unsupported cannot claim mapped/partial support')
        if cap['disposition'] == 'schema_gap':
            require(cap['adapterSupport'] in {'unmodeled', 'partial'}, f'{key}: schema gap cannot claim fully mapped/rejected')
        if cap['disposition'] == 'external':
            require(cap['adapterSupport'] == 'external', f'{key}: external work must not claim adapter coverage')
        if cap['adapterSupport'] == 'rejected':
            require(cap['disposition'] == 'unsupported' and cap['schemaPaths']
                    and {'schema', 'adapter', 'test'} <= kinds,
                    f'{key}: explicit rejection requires modeled paths, adapter and test anchors')
        if cap['nativeSupport'] in {'supported', 'partial'}:
            require(bool({'native', 'adapter'} & kinds), f'{key}: native support needs implementation evidence')
        capabilities[key] = cap

    string_list(matrix['nativeReview'], 'nativeReview')
    require(NATIVE_REVIEW <= set(matrix['nativeReview']), 'nativeReview: missing G1–G6 / backend boundary review')
    require(set(matrix['nativeReview']) <= set(capabilities), 'nativeReview: unknown capability')
    require(isinstance(matrix['entries'], list), 'entries: expected list')
    keys = []
    used = set(matrix['nativeReview'])
    for entry in matrix['entries']:
        fields(entry, 'key capability rule', 'entry')
        require(text(entry['key']) and text(entry['rule']), 'Entry needs key and an explicit migration rule')
        require(text(entry['capability']) and entry['capability'] in capabilities,
                f'{entry["key"]}: unknown capability')
        keys.append(entry['key'])
        used.add(entry['capability'])
    unique(keys, 'coverage entries')
    require(set(keys) == set(legacy), f'Coverage mismatch; missing: {sorted(set(legacy)-set(keys))}; stale: {sorted(set(keys)-set(legacy))}')
    require(keys == list(legacy), 'Coverage entries must follow inventory order for stable review diffs')
    require(used == set(capabilities), f'Unreviewed/orphan capability: {sorted(set(capabilities)-used)}')
    return inventory


def counts(matrix):
    capabilities = {c['id']: c for c in matrix['capabilities']}
    return dict(Counter(capabilities[e['capability']]['disposition'] for e in matrix['entries']))


def cell(value):
    return str(value).replace('|', '\\|').replace('\n', '<br>')


def render(matrix, inventory, root=ROOT):
    """Deterministic report; called only after validation, never classifies inputs."""
    capabilities = {c['id']: c for c in matrix['capabilities']}
    legacy = {e['key']: e for e in inventory['entries']}
    total = counts(matrix)
    lines = ['# 通用图表模型覆盖矩阵', '',
        f'审计日期：{matrix["asOf"]}；`ChartSpecification` schema v{matrix["specificationVersion"]}。', '',
        '> 本文由 `scripts/check_chart_neutral_coverage.py --write` 从逐项审核的 JSON 生成；请先修改 JSON，再生成文档。工具不会自动判定新字段“已支持”。', '',
        '## 结论与阅读方式', '',
        f'- **{len(matrix["entries"])} 个旧声明逐项处置**，对应 {len(capabilities)} 个能力/职责主题；'
        f'另核对 {len(matrix["nativeReview"])} 个 G1–G6 / 后端边界主题（与旧字段覆盖有交集，不与 197 相加）。',
        '- “已表达”只指描述语义及 HYMCharts 转换已有，**不表示旧输入 mapper 已交付或旧默认/累计规则完全等价**。真实业务调用仍未提供。',
        '- “外层”细分为业务 UI、运行时命令/事件、兼容解析/格式化与派生缓存，不能都算作 renderer 缺口，也不能都算作已完成。',
        '- “未建模”没有可被适配器检查的字段，**不等于已经返回 unsupportedCapability**。当前 Codable 会忽略额外对象键；mapper 必须在丢失信息前显式诊断，metadata/扩展键不得透传引擎选项。',
        '- G1 三种边界已进入 v2 并由 HYM 显式映射；v1 保留 independent。v3 已接通值轴颜色子集（柱 raw/draw、线/面积 draw），旧 zones 的 X/分区填充仍有缺口。G3 字重/刻度、G4 标注/标签、G5 选中外观已有原生能力，但尚未全部进入通用模型。G6 连续 X/反向轴仍由后端明确拒绝。',
        '- 只审查本清单及列出的原生主题；不是整个 SDK 每个公开参数的穷举，也不是第二后端验证。v2 G1 与 v3 值轴颜色配置已同步现有 Demo 面板；未增加同类型新入口。', '',
        '| 处置 | 旧声明数 |', '| --- | ---: |']
    for status, label in DISPOSITIONS.items():
        lines.append(f'| {label} | {total.get(status, 0)} |')
    lines += ['', '## 后续实施顺序', '',
        '1. **共同能力验收**：先选一个实际要用的第二后端；按 ID、原始值、缺测、单位、轴绑定、绝对值分母和错误路径核对，不要求像素一致。未选定前不随意引入依赖。',
        '2. **按场景扩 schema**：G1 边界 v2 与值轴颜色 v3 小切片已接通；后续优先轴展示，再 annotation、tooltip/legend。缺失 schema 字段不能靠 metadata 绕过。',
        '3. **版本策略**：任何扩展先定义旧 v1 读入后的缺省含义、未来版本拒绝及降级错误；G1 v2 和颜色 v3 已落实该规则，旧构造器仍默认 v1；后续扩展继续同步校验、转换、Swift/OC、既有 Demo 与测试。',
        '4. **独立 R2 mapper**：也可在旧页面迁移优先时先做，保持旧字段识别/默认/特殊精度/符号政策在兼容层；未选 D06、D07 等业务政策时不得猜测。',
        '5. **真实工程验收**：R7/R8 需要实际页面、真机、状态恢复、分发/回退约束；本审计不标记完成。', '',
        '## G1–G6 与后端边界速查', '',
        '| 主题 | schema 处置 | HYM 原生 | v1/v2/v3 适配器 |', '| --- | --- | --- | --- |']
    for key in matrix['nativeReview']:
        cap = capabilities[key]
        lines.append(f'| [{cell(cap["title"])}](#cap-{key}) | {DISPOSITIONS[cap["disposition"]]} | '
                     f'{NATIVE[cap["nativeSupport"]]} | {ADAPTER[cap["adapterSupport"]]} |')
    lines += ['', '## 逐声明覆盖（按原头文件清单排序）', '']
    previous = None
    for entry in matrix['entries']:
        owner = entry['key'].split('.')[0]
        if owner != previous:
            lines.append('')
            lines += [f'### {owner}', '', '| 旧声明 | 处置 / 能力 | 转换规则与边界 |', '| --- | --- | --- |']
            previous = owner
        source = legacy[entry['key']]
        cap = capabilities[entry['capability']]
        lines.append(f'| [`{cell(entry["key"])}`](../{source["source"]}#L{source["line"]}) | '
                     f'{DISPOSITIONS[cap["disposition"]]} · [{cell(cap["title"])}](#cap-{cap["id"]}) | {cell(entry["rule"])} |')
    lines += ['', '## 能力判定详情', '']
    for cap in matrix['capabilities']:
        lines += [f'<a id="cap-{cap["id"]}"></a>', f'### {cap["title"]}', '',
            f'- **处置**：{DISPOSITIONS[cap["disposition"]]}。**HYM 原生**：{NATIVE[cap["nativeSupport"]]}。'
            f'**v1/v2/v3 适配器**：{ADAPTER[cap["adapterSupport"]]}。',
            '- **已有 schema 落点**：' + ('、'.join(f'`{p}`' for p in cap['schemaPaths']) if cap['schemaPaths'] else '无；不凭空假设新增字段已存在。'),
            f'- **判定**：{cap["finding"]}', f'- **后续动作**：{cap["nextAction"]}',
            '- **源码/契约入口**：' + ' · '.join(f'[{ref}](#evidence-{ref})' for ref in cap['evidence']), '']
    lines += ['## 源码与现有契约入口', '',
        '以下是审计定位依据。锚点存在不等于功能正确；“test”表示现有契约测试入口，**不表示本批已重新执行这些 XCTest**。本批实际执行范围见任务进度及独立审计证据。', '']
    for key, ref in matrix['evidence'].items():
        contents = (root / ref['path']).read_text(encoding='utf-8')
        line = contents[:contents.index(ref['anchor'])].count('\n') + 1
        lines += [f'<a id="evidence-{key}"></a>',
                  f'- **{key}** ({ref["kind"]})：[`{ref["anchor"]}`](../{ref["path"]}#L{line})']
    lines += ['', '## 离线检查与边界', '',
        '```sh', 'python3 scripts/check_chart_migration_inventory.py',
        'python3 scripts/check_chart_neutral_coverage.py',
        'python3 -m unittest discover -s scripts -p "test_check_chart_neutral_coverage.py"', '```', '',
        '检查器核对实际旧声明、重复/遗漏/失效字段、来源位置、矩阵状态组合、源码/测试锚点、schema 版本以及 Markdown 是否同步；拒绝越界路径和重复 JSON 键。',
        '检查器只验证审计材料的一致性，不自动证明语义或发现所有缺失字段；源代码行为变化需人工重新审计并运行相应契约测试。', '',
        '关联：[机器清单](charts-neutral-model-coverage.json) · [模型指南](charts-neutral-model-guide.md) · '
        '[旧字段历史清单](charts-legacy-field-inventory.md) · [后续实施计划](charts-legacy-replacement-plan.md)。', '']
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Regenerate Markdown after validation; never modifies classifications')
    args = parser.parse_args(argv)
    try:
        matrix = load_json(ROOT / MATRIX)
        inventory = validate(matrix)
        expected = render(matrix, inventory)
        if args.write:
            (ROOT / REPORT).write_text(expected, encoding='utf-8')
        require((ROOT / REPORT).is_file() and (ROOT / REPORT).read_text(encoding='utf-8') == expected,
                f'{REPORT} is stale/missing; review JSON then run with --write')
        print(json.dumps({'status': 'PASS', 'legacyDeclarations': len(matrix['entries']),
                          'capabilities': len(matrix['capabilities']), 'nativeReview': len(matrix['nativeReview']),
                          'counts': counts(matrix), 'scope': 'offline audit consistency; not renderer execution'}, ensure_ascii=False))
        return 0
    except (CoverageError, OSError, UnicodeError, ValueError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
