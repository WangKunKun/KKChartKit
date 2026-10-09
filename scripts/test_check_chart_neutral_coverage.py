#!/usr/bin/env python3
"""Offline regressions for coverage data, fail-closed validation and report generation."""
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import check_chart_neutral_coverage as coverage


class NeutralCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = coverage.load_json(coverage.ROOT / coverage.MATRIX)
        cls.inventory = coverage.validate(cls.baseline)

    def setUp(self):
        self.matrix = deepcopy(self.baseline)

    def cap(self, key):
        return next(cap for cap in self.matrix['capabilities'] if cap['id'] == key)

    @contextmanager
    def copied_root(self):
        """Only copy reviewed inputs, never touch project sources or simulator state."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = {coverage.MATRIX, coverage.REPORT, self.matrix['inventory'],
                     'SwiftFunctionProject/Charts/Specification/ChartSpecification.swift'}
            paths.update(self.inventory['headers'])
            paths.update(ref['path'] for ref in self.matrix['evidence'].values())
            for path in paths:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(coverage.ROOT / path, root / path)
            yield root

    def invalid(self, pattern, root=coverage.ROOT):
        with self.assertRaisesRegex(coverage.CoverageError, pattern):
            coverage.validate(self.matrix, root)

    def test_repository_matrix_covers_every_declaration_once(self):
        self.assertEqual(len(self.inventory['entries']), 197)
        self.assertEqual(coverage.validate(self.matrix), self.inventory)
        self.assertEqual(coverage.counts(self.matrix),
                         {'expressed': 47, 'schema_gap': 39, 'external': 104, 'unsupported': 7})
        self.assertEqual(sum(coverage.counts(self.matrix).values()), len(self.matrix['entries']))

    def test_value_color_slice_does_not_claim_complete_legacy_zones(self):
        self.assertEqual(self.cap('value-color-zones')['disposition'], 'expressed')
        self.assertEqual(self.cap('zones')['disposition'], 'schema_gap')
        self.assertEqual(self.cap('zones')['adapterSupport'], 'partial')
        legacy_zones = {entry['key']: entry['capability'] for entry in self.matrix['entries']
                        if entry['key'] in {'HMAASeriesElement.zones', 'HMAASeriesElement.zoneAxisX'}}
        self.assertEqual(legacy_zones, {'HMAASeriesElement.zones': 'zones',
                                        'HMAASeriesElement.zoneAxisX': 'zones'})
        self.assertIn('value-color-zones', self.matrix['nativeReview'])

    def test_axis_slice_does_not_claim_business_formats_or_coordinate_support(self):
        for capability in ['axis-weight', 'ticks', 'axis-value-format']:
            self.assertEqual(self.cap(capability)['disposition'], 'expressed')
            self.assertEqual(self.cap(capability)['adapterSupport'], 'mapped')
            self.assertIn(capability, self.matrix['nativeReview'])
        self.assertEqual(self.cap('compat-format')['disposition'], 'external')
        self.assertEqual(self.cap('reversed-axis')['nativeSupport'], 'unsupported')
        self.assertIn('不包含值轴 tickInterval/tickCount', self.cap('ticks')['finding'])
        self.assertIn('自定义字体资源/任意名称不在此契约', self.cap('axis-weight')['finding'])
        self.assertEqual(sum(e['capability'] in {'axis-weight', 'ticks', 'axis-value-format'}
                             for e in self.matrix['entries']), 7)

    def test_generated_markdown_is_deterministic_and_checked_in_sync(self):
        report = coverage.render(self.matrix, self.inventory)
        self.assertEqual(report, coverage.render(deepcopy(self.matrix), self.inventory))
        self.assertEqual(report, (coverage.ROOT / coverage.REPORT).read_text(encoding='utf-8'))
        self.assertIn('不表示旧输入 mapper 已交付', report)
        self.assertIn('不等于已经返回 unsupportedCapability', report)
        for entry in self.matrix['entries']:
            self.assertEqual(report.count(f'[`{entry["key"]}`]'), 1)
        self.assertEqual(coverage.cell('a|b\nc'), 'a\\|b<br>c')

    def test_new_unknown_and_duplicate_fields_never_default_to_supported(self):
        self.matrix['entries'].pop()
        self.invalid('Coverage mismatch; missing:')
        self.matrix = deepcopy(self.baseline)
        self.matrix['entries'][0]['key'] = 'Unknown.newField'
        self.invalid('Coverage mismatch; missing:')
        self.matrix = deepcopy(self.baseline)
        self.matrix['entries'].append(deepcopy(self.matrix['entries'][0]))
        self.invalid('coverage entries: duplicate')

    def test_entry_requires_explicit_nonblank_rule_and_known_capability(self):
        self.matrix['entries'][0]['rule'] = '   '
        self.invalid('explicit migration rule')
        self.matrix = deepcopy(self.baseline)
        self.matrix['entries'][0]['capability'] = 'unknown'
        self.invalid('unknown capability')
        self.matrix = deepcopy(self.baseline)
        self.matrix['entries'][0]['supportedByDefault'] = True
        self.invalid('missing/unknown fields')

    def test_unknown_top_level_fields_and_types_are_diagnostics(self):
        for bad in (None, [], {'matrixVersion': 1}):
            with self.subTest(bad=bad), self.assertRaises(coverage.CoverageError):
                coverage.validate(bad)
        for field, value in [('matrixVersion', True), ('specificationVersion', True),
                             ('asOf', '2026-02-30'), ('asOf', '20261003')]:
            with self.subTest(field=field):
                bad = deepcopy(self.baseline)
                bad[field] = value
                with self.assertRaises(coverage.CoverageError):
                    coverage.validate(bad)

    def test_capability_status_and_backend_dimension_cannot_be_conflated(self):
        for field, value in [('disposition', 'mapped'), ('nativeSupport', 'yes'),
                             ('adapterSupport', 'default'), ('adapterSupport', [])]:
            with self.subTest(field=field):
                self.matrix = deepcopy(self.baseline)
                self.cap('title')[field] = value
                self.invalid('unknown')
        self.matrix = deepcopy(self.baseline)
        self.cap('zones')['adapterSupport'] = 'mapped'
        self.invalid('fully mapped must be explicitly')
        self.matrix = deepcopy(self.baseline)
        self.cap('zones')['disposition'] = 'expressed'
        self.invalid('expressed requires')

    def test_expressed_requires_schema_adapter_and_test_evidence(self):
        for kind in ('schema', 'adapter', 'test'):
            with self.subTest(kind=kind):
                self.matrix = deepcopy(self.baseline)
                cap = self.cap('title')
                cap['evidence'] = [key for key in cap['evidence']
                                   if self.matrix['evidence'][key]['kind'] != kind]
                self.invalid('schema evidence|needs schema/adapter/test')
        self.matrix = deepcopy(self.baseline)
        self.cap('title')['schemaPaths'] = []
        self.invalid('expressed requires')

    def test_native_supported_needs_implementation_not_just_prose(self):
        self.cap('zones')['evidence'] = ['schema', 'data', 'g1-test']
        self.invalid('native support needs implementation evidence')

    def test_unmodeled_is_not_an_existing_rejection_diagnostic(self):
        self.cap('annotations')['adapterSupport'] = 'rejected'
        self.invalid('schema gap cannot claim')
        self.matrix = deepcopy(self.baseline)
        cap = self.cap('continuous-domain')
        cap['evidence'] = [key for key in cap['evidence'] if key != 'reject-test']
        self.invalid('explicit rejection requires')
        self.matrix = deepcopy(self.baseline)
        self.cap('runtime-create')['adapterSupport'] = 'partial'
        self.invalid('external work must not claim adapter coverage')

    def test_g1_and_g6_limits_are_explicit_and_not_fake_completed(self):
        self.assertEqual((self.cap('g1-boundary')['nativeSupport'], self.cap('g1-boundary')['adapterSupport']),
                         ('supported', 'mapped'))
        for key in ('continuous-domain', 'reversed-axis'):
            self.assertEqual((self.cap(key)['nativeSupport'], self.cap(key)['adapterSupport']),
                             ('unsupported', 'rejected'))
        entries = {entry['key']: entry for entry in self.matrix['entries']}
        self.assertEqual(entries['HMAAChartModel.version']['capability'], 'host-card')
        self.assertEqual(entries['HMAAChartModel.reverse']['capability'], 'compat-order')
        self.assertEqual(entries['HMAASeriesElement.fractionDigits']['capability'], 'precision-compatibility')
        self.assertEqual(entries['HMAAYAxis.unit']['capability'], 'axis-value-format')
        self.assertIn('刻度', self.cap('axis-value-format')['finding'])

    def test_native_review_and_capabilities_are_complete_unique_and_linked(self):
        self.matrix['nativeReview'].remove('g1-boundary')
        self.invalid('missing G1–G6')
        self.matrix = deepcopy(self.baseline)
        self.matrix['nativeReview'].append('g1-boundary')
        self.invalid('nativeReview: duplicate')
        self.matrix = deepcopy(self.baseline)
        orphan = deepcopy(self.cap('title'))
        orphan['id'] = 'orphan'
        self.matrix['capabilities'].append(orphan)
        self.invalid('orphan capability')
        self.matrix = deepcopy(self.baseline)
        self.matrix['capabilities'].append(deepcopy(self.cap('title')))
        self.invalid('Duplicate capability')

    def test_evidence_type_missing_anchor_and_unknown_reference_are_diagnostics(self):
        self.matrix['evidence']['schema']['anchor'] = 'no-such-source-declaration'
        self.invalid('missing evidence anchor')
        self.matrix = deepcopy(self.baseline)
        self.matrix['evidence']['schema']['kind'] = []
        self.invalid('unknown evidence kind')
        self.matrix = deepcopy(self.baseline)
        self.matrix['evidence']['schema']['kind'] = 'test'
        self.invalid('expected an XCTest method')
        self.matrix = deepcopy(self.baseline)
        self.cap('title')['evidence'].append('unknown-ref')
        self.invalid('unknown evidence reference')

    def test_paths_reject_missing_absolute_traversal_and_symlink_escape(self):
        for path in ('/tmp/source.swift', '../source.swift', 'a/../b.swift', 'a//b.swift',
                     'a\\b.swift', 'nonexistent.swift'):
            with self.subTest(path=path):
                self.matrix = deepcopy(self.baseline)
                self.matrix['evidence']['schema']['path'] = path
                self.invalid('Unsafe path|Missing file')
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / 'repo'
            root.mkdir()
            outside = parent / 'outside.txt'
            outside.write_text('secret', encoding='utf-8')
            (root / 'link').symlink_to(outside)
            with self.assertRaisesRegex(coverage.CoverageError, 'escapes repository'):
                coverage.local_file(root, 'link')

    def test_duplicate_json_keys_and_invalid_json_never_last_win(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'matrix.json'
            for source, expected in [('not json', 'invalid JSON'), ('{"x":1,"x":2}', 'duplicate JSON key'),
                                     ('{"data":{"x":1,"x":2}}', 'duplicate JSON key')]:
                with self.subTest(source=source):
                    path.write_text(source, encoding='utf-8')
                    with self.assertRaisesRegex(coverage.CoverageError, expected):
                        coverage.load_json(path)

    def test_changed_header_requires_inventory_and_matrix_review(self):
        with self.copied_root() as root:
            header = root / self.inventory['headers'][0]
            header.write_text(header.read_text(encoding='utf-8') +
                              '\n@interface NewLegacyModel : NSObject\n@property NSString *newField;\n@end\n', encoding='utf-8')
            self.invalid('Inventory missing declarations', root)
        with self.copied_root() as root:
            header = root / self.inventory['headers'][0]
            header.write_text('\n' + header.read_text(encoding='utf-8'), encoding='utf-8')
            self.invalid('Inventory source location changed', root)

    def test_duplicate_or_stale_inventory_is_not_accepted(self):
        with self.copied_root() as root:
            path = root / self.matrix['inventory']
            inventory = deepcopy(self.inventory)
            inventory['entries'].append(deepcopy(inventory['entries'][0]))
            path.write_text(json.dumps(inventory), encoding='utf-8')
            self.invalid('Duplicate inventory declaration', root)
        with self.copied_root() as root:
            path = root / self.matrix['inventory']
            inventory = deepcopy(self.inventory)
            inventory['entries'][0]['key'] = 'NoSuchOwner.field'
            path.write_text(json.dumps(inventory), encoding='utf-8')
            self.invalid('Stale inventory declaration', root)

    def test_source_version_drift_and_removed_evidence_are_detected(self):
        with self.copied_root() as root:
            path = root / 'SwiftFunctionProject/Charts/Specification/ChartSpecification.swift'
            path.write_text(path.read_text(encoding='utf-8').replace(f'latestSchemaVersion: Int = {self.baseline["specificationVersion"]}', f'latestSchemaVersion: Int = {self.baseline["specificationVersion"] + 1}'), encoding='utf-8')
            self.invalid('Schema version changed', root)
        with self.copied_root() as root:
            (root / self.matrix['evidence']['g1-test']['path']).unlink()
            self.invalid('Missing file', root)

    def test_entry_order_is_stable(self):
        self.matrix['entries'][0], self.matrix['entries'][1] = self.matrix['entries'][1], self.matrix['entries'][0]
        self.invalid('must follow inventory order')

    def test_cli_fails_on_stale_report_and_write_repairs_only_markdown(self):
        with self.copied_root() as root:
            before = (root / coverage.MATRIX).read_bytes()
            report = root / coverage.REPORT
            report.write_text('stale', encoding='utf-8')
            original_validate = coverage.validate
            original_render = coverage.render
            # Bind explicit roots too: function default arguments retain their original root.
            with patch.object(coverage, 'ROOT', root), \
                 patch.object(coverage, 'validate', side_effect=lambda m: original_validate(m, root)), \
                 patch.object(coverage, 'render', side_effect=lambda m, i: original_render(m, i, root)), \
                 redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(coverage.main([]), 1)
                self.assertIn('stale/missing', errors.getvalue())
                self.assertEqual(coverage.main(['--write']), 0)
                self.assertEqual(coverage.main([]), 0)
            self.assertEqual((root / coverage.MATRIX).read_bytes(), before)
            self.assertEqual(report.read_text(encoding='utf-8'), original_render(self.matrix, self.inventory, root))

    def test_cli_reports_malformed_json_without_traceback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / coverage.MATRIX).parent.mkdir(parents=True)
            (root / coverage.MATRIX).write_text('{ broken', encoding='utf-8')
            with patch.object(coverage, 'ROOT', root), redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(coverage.main([]), 1)
                self.assertIn('invalid JSON', errors.getvalue())
                self.assertNotIn('Traceback', errors.getvalue())


if __name__ == '__main__':
    unittest.main()
