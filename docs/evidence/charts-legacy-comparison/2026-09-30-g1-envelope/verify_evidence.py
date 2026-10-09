#!/usr/bin/env python3
"""Verify archived evidence only; this does not execute XCTest."""
from pathlib import Path
import gzip
import hashlib
import json
import runpy
import tarfile

HERE = Path(__file__).resolve().parent


def read(name):
    return json.loads((HERE / name).read_text())


def sha(data):
    return hashlib.sha256(data).hexdigest()


for name, digest in read('evidence-files.json').items():
    assert sha((HERE / name).read_bytes()) == digest, name
for name, count in [('final', 290), ('legacy-final', 1), ('integration', 2)]:
    summary = read(name + '-summary.json')
    assert (summary['passedTests'], summary['failedTests'], summary['skippedTests']) == (count, 0, 0), name
log = gzip.decompress((HERE / 'final.log.gz').read_bytes()).decode()
assert 'Executed 288 tests, with 0 failures' in log
assert "Test Suite 'StackedAreaEnvelopeTests' passed" in log
assert 'editable controls=258, binding mutations=2801' in log
assert 'TEST BUILD SUCCEEDED' in gzip.decompress((HERE / 'product.log.gz').read_bytes()).decode()
for name in ['before', 'legacy-final', 'final']:
    for row in read(name + '-attachments.json'):
        assert sha((HERE / row['file']).read_bytes()) == row['sha256'], row['file']
ui = [row for row in read('final-attachments.json') if row['test'].startswith('ChartDemoUITests/')]
assert len(ui) == 10
snapshot = read('source-snapshot.json')
assert sha((HERE / snapshot['archive']).read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(HERE / snapshot['archive']) as archive:
    for name, digest in snapshot['files'].items():
        assert sha(archive.extractfile(name).read()) == digest, name
runpy.run_path(str(HERE / 'compare_snapshots.py'), run_name='__main__')
print(f"PASS: 288 unit + 2 Demo UI + 1 legacy UI + 2 integration UI; 10 Demo images; {len(snapshot['files'])} source files")
