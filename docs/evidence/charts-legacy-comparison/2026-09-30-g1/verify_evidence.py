#!/usr/bin/env python3
"""Verify the saved G1 evidence, without comparing historical inputs to today's tree."""
from pathlib import Path
import gzip
import hashlib
import json
import tarfile

HERE = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(name):
    return json.loads((HERE / name).read_text())


for name, digest in read('evidence-files.json').items():
    assert sha((HERE / name).read_bytes()) == digest, name

for name, passed, failed in [('before', 0, 1), ('matrix', 33, 0),
                             ('final', 270, 1), ('ui-initial', 17, 1),
                             ('ui', 1, 0), ('integration', 2, 0)]:
    summary = read(name + '-summary.json')
    assert (summary['passedTests'], summary['failedTests']) == (passed, failed), name

log = gzip.decompress((HERE / 'final.log.gz').read_bytes()).decode()
assert 'Executed 269 tests, with 0 failures' in log
for row in read('ui-attachments.json'):
    assert sha((HERE / row['file']).read_bytes()) == row['sha256']
assert len(read('ui-attachments.json')) == 4

snapshot = read('source-snapshot.json')
assert sha((HERE / snapshot['archive']).read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(HERE / snapshot['archive']) as archive:
    for name, digest in snapshot['files'].items():
        assert sha(archive.extractfile(name).read()) == digest, name

print(f"PASS: G1 summaries, four final Demo screenshots, and {len(snapshot['files'])} archived input files")
