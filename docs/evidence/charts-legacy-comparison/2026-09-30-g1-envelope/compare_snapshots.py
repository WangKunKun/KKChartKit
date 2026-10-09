#!/usr/bin/env python3
"""Check saved same-input arithmetic evidence; does not run either renderer."""
from pathlib import Path
import json
import tarfile

HERE = Path(__file__).resolve().parent


def read(name):
    return json.loads((HERE / name).read_text())


def compare():
    with tarfile.open(HERE / 'source-snapshot.tar.gz') as archive:
        fixture = json.load(archive.extractfile(
            'Examples/ChartComparisonFixtures/chart-area-boundaries-v1.json'))
    assert len(fixture['cases']) == 2
    for case in fixture['cases']:
        identifier = case['id']
        data = [s['values'] for s in case['series']]
        native = read('native-' + identifier + '.json')
        legacy = read('legacy-' + identifier + '.json')[0]
        assert native['id'] == identifier and native['raw'] == data
        assert case['topType'] == 'areaspline'
        assert all(s['kind'] == 'areaspline' for s in case['series'])
        assert legacy['version'] == '11.4.3' and legacy['categories'] == 3
        series = legacy['series']
        assert len(series) == 7 and sum(s['name'] == '' for s in series) == 1
        assert all(s['type'] == 'areaspline' and s['count'] == 3 for s in series)
        for i, business in enumerate(case['series']):
            positive, negative = series[i], series[i + 4]
            assert positive['name'] == negative['name'] == business['name']
            assert [s['raw'] for s in positive['samples']] == [max(0, v) for v in data[i]]
            assert [s['raw'] for s in negative['samples']] == [min(0, v) for v in data[i]]
        assert [s['raw'] for s in series[3]['samples']] == [
            -sum(min(0, row[i]) for row in data) for i in range(3)]
        expected = [[sum(row[i] for row in data[:s + 1] if (row[i] >= 0) == (v >= 0))
                     for i, v in enumerate(values)] for s, values in enumerate(data)]
        assert native['draw'] == expected
    switch = read('legacy-boundary-source-switch.json')[0]['series']
    assert [[p['stackY'] for p in s['samples']] for s in switch[:3]] == [
        [55, -5, 55], [35, -25, 35], [5, -25, 5]]
    assert read('native-boundary-source-switch.json')['draw'][2][1] == 25
    print('PASS: 2 shared inputs, legacy positive/negative copies and helper, native sign sums; +5 middle sample: legacy -25 / native +25')


if __name__ == '__main__':
    compare()
