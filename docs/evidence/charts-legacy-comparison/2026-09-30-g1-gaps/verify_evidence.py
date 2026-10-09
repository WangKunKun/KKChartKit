#!/usr/bin/env python3
"""Verify archived gap-boundary evidence; does not execute XCTest."""
from pathlib import Path
import gzip
import hashlib
import json
import tarfile

HERE = Path(__file__).resolve().parent


def read(name):
    return json.loads((HERE / name).read_text())


def sha(data):
    return hashlib.sha256(data).hexdigest()


for name, digest in read('evidence-files.json').items():
    assert sha((HERE / name).read_bytes()) == digest, name
for name, count in [('final', 299), ('integration', 2)]:
    summary = read(name + '-summary.json')
    assert (summary['passedTests'], summary['failedTests'], summary['skippedTests']) == (count, 0, 0), name
log = gzip.decompress((HERE / 'final.log.gz').read_bytes()).decode()
assert 'Executed 296 tests, with 0 failures' in log
assert "Test Suite 'StackedAreaGapBoundaryTests' passed" in log
assert 'editable controls=258, binding mutations=2801' in log
assert 'rendered configuration matrix=750' in log
assert 'TEST BUILD SUCCEEDED' in gzip.decompress((HERE / 'product.log.gz').read_bytes()).decode()
for name in ['before', 'final']:
    for row in read(name + '-attachments.json'):
        assert sha((HERE / row['file']).read_bytes()) == row['sha256'], row['file']
ui = [r for r in read('final-attachments.json') if r['test'].startswith('ChartDemoUITests/')]
assert len(ui) == 14
snapshot = read('source-snapshot.json')
assert sha((HERE / snapshot['archive']).read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(HERE / snapshot['archive']) as archive:
    for name, digest in snapshot['files'].items():
        assert sha(archive.extractfile(name).read()) == digest, name
print(f"PASS: 296 unit + 3 Demo UI + 2 integration UI; 14 Demo images; {len(snapshot['files'])} source files")
