#!/usr/bin/env python3
"""Verify saved stroke-boundary evidence; this does not execute XCTest."""
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
for name, passed, failed in [('regression', 281, 1), ('ui', 1, 0)]:
    summary = read(name + '-summary.json')
    assert (summary['passedTests'], summary['failedTests']) == (passed, failed), name
log = gzip.decompress((HERE / 'final.log.gz').read_bytes()).decode()
assert 'Executed 281 tests, with 0 failures' in log
assert "Test Suite 'StackedAreaStrokeTests' passed" in log
assert 'editable controls=258, binding mutations=2801' in log
assert 'TEST BUILD SUCCEEDED' in gzip.decompress((HERE / 'product.log.gz').read_bytes()).decode()
attachments = read('ui-attachments.json')
assert len(attachments) == 6
for row in attachments:
    assert sha((HERE / row['file']).read_bytes()) == row['sha256']
assert (HERE / 'before.png').read_bytes() == (HERE.parent / '2026-09-30-g1-crossing/after.png').read_bytes()
snapshot = read('source-snapshot.json')
assert sha((HERE / snapshot['archive']).read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(HERE / snapshot['archive']) as archive:
    for name, digest in snapshot['files'].items():
        assert sha(archive.extractfile(name).read()) == digest, name
print(f"PASS: 281 unit tests + UI retry, 6 UI images, {len(snapshot['files'])} archived input files")
