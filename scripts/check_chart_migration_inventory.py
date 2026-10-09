#!/usr/bin/env python3
"""Check that every declaration in the scoped legacy headers has an explicit disposition."""
from pathlib import Path
import json, re, sys
ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / 'docs/charts-legacy-field-inventory.json'
def declarations(headers, root=ROOT):
    found = {}
    for header in headers:
        current = None
        for number, line in enumerate((root / header).read_text().splitlines(), 1):
            match = re.match(r'@(interface|protocol)\s+(\w+)', line)
            if match: current = match.group(2)
            if line.startswith('@end'): current = None
            if not current: continue
            member = None
            if line.startswith('@property'):
                block = re.search(r'\(\^(\w+)\)', line)
                plain = re.search(r'(\w+)\s*;', line)
                member = (block or plain).group(1) if block or plain else None
            elif re.match(r'^[-+]\s*\(', line):
                signature = re.sub(r'^[-+]\s*\([^)]*\)\s*', '', line).split(';')[0]
                labels = re.findall(r'(\w+)\s*:', signature)
                member = ''.join(x+':' for x in labels) if labels else signature.strip()
            if member:
                key = current+'.'+member
                if key in found: raise ValueError('Duplicate declaration: '+key)
                found[key] = dict(source=header, line=number)
    return found

def main():
    inventory=json.loads(INVENTORY.read_text())
    actual=declarations(inventory['headers']); entries=inventory['entries']
    keys=[e['key'] for e in entries]
    missing=set(actual)-set(keys); stale=set(keys)-set(actual)
    assert len(keys)==len(set(keys)), 'Duplicate inventory entries'
    assert not missing and not stale, f'Missing: {sorted(missing)}; stale: {sorted(stale)}'
    statuses={'mapped','bridge','core','unsupported','confirm'}
    for e in entries:
        assert e['status'] in statuses and e['target'] and e['note'], e
        assert (e['source'],e['line']) == (actual[e['key']]['source'],actual[e['key']]['line']), e['key']
    print(f'PASS: {len(entries)} declarations in {len(inventory["headers"])} headers; every member has an explicit status')
if __name__=='__main__': main()
