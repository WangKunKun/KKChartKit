#!/usr/bin/env python3
"""Check saved crossing evidence and immutable source hashes; does not run XCTest."""
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

for name, passed, failed in [('before', 0, 1), ('core', 19, 0), ('final', 279, 0),
                             ('contract', 6, 0), ('endpoints', 25, 0), ('integration', 2, 0)]:
    summary = read(name + '-summary.json')
    assert (summary['passedTests'], summary['failedTests']) == (passed, failed), name

log = gzip.decompress((HERE / 'final.log.gz').read_bytes()).decode()
assert 'Executed 276 tests, with 0 failures' in log
assert 'editable controls=258, binding mutations=2801' in log
attachments = read('ui-attachments.json')
assert len(attachments) == 10
for row in attachments:
    assert sha((HERE / row['file']).read_bytes()) == row['sha256']

snapshot = read('source-snapshot.json')
assert sha((HERE / snapshot['archive']).read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(HERE / snapshot['archive']) as archive:
    for name, digest in snapshot['files'].items():
        assert sha(archive.extractfile(name).read()) == digest, name

print(f"PASS: crossing summaries, 10 UI screenshots, {len(snapshot['files'])} archived input files")
