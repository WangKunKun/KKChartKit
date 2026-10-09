#!/usr/bin/env python3
"""Read-only verification of this batch's saved evidence, not a replacement for rerunning Xcode."""
from pathlib import Path
import hashlib, json, tarfile
HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / '2026-09-30-rerun'
def sha(data): return hashlib.sha256(data).hexdigest()
for name, count in [('native',6),('legacy',1),('debug',2),('release',2)]:
    summary = json.loads((HERE / (name+'-summary.json')).read_text())
    assert summary['totalTestCount'] == count and summary['passedTests'] == count and summary['failedTests'] == 0
attachments = 0
for manifest in HERE.glob('*-attachments-manifest.json'):
    for test in json.loads(manifest.read_text()):
        for a in test['attachments']:
            assert sha((HERE / a['savedPath']).read_bytes()) == a['sha256'], a['savedPath']
            attachments += 1
for path in (HERE / 'legacy').glob('*.json'):
    previous = list(PREVIOUS.rglob(path.name))
    assert len(previous) == 1
    assert json.loads(path.read_text()) == json.loads(previous[0].read_text()), path.name
snapshot = json.loads((HERE / 'source-snapshot.json').read_text())
archive = HERE / snapshot['archive']
assert sha(archive.read_bytes()) == snapshot['archiveSHA256']
with tarfile.open(archive) as tar:
    for name, digest in snapshot['files'].items():
        assert sha(tar.extractfile(name).read()) == digest, name
print(f'PASS: 4 summaries, {attachments} attachments, 4 unchanged legacy JSON snapshots, {len(snapshot["files"])} archived source files')
