#!/usr/bin/env python3
"""Small offline regressions for the portable evidence validator."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import check_chart_evidence as evidence


class EvidenceTests(unittest.TestCase):
    def test_links_skip_remote_fragments_and_fences_keep_unicode_spaces_and_file_lines(self):
        text = '''[remote](https://example.com/a) [anchor](#heading)
![image](图表%20一.png) [source](/tmp/source.swift:12:3)
[title](guide.md "A guide") [space](<my guide.md>)
```md
[example](not-an-actual-file.md)
```
~~~
[example](also-not-actual.md)
~~~
[mail](mailto:chart@example.com)
'''
        self.assertEqual(list(evidence.local_link_targets(text)),
                         ["图表 一.png", "/tmp/source.swift", "guide.md", "my guide.md"])

    def fixture(self, root):
        data = evidence.PNG_SIGNATURE + b"fixture payload"
        (root / "capture.png").write_bytes(data)
        return {"file": "capture.png", "sha256": hashlib.sha256(data).hexdigest(),
                "test": "ChartTests/testScene()", "resultBundle": "/tmp/removed.xcresult",
                "attachment": {"isAssociatedWithFailure": False, "deviceId": "simulator",
                               "exportedFileName": "UUID.png", "suggestedHumanReadableName": "capture_0_UUID.png"}}

    def test_manifest_is_portable_and_rejects_modified_missing_or_unlisted_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            entry = self.fixture(root)
            (root / "screenshots.json").write_text(json.dumps([entry]))
            self.assertEqual(evidence.check_screenshots(root), (1, []))
            (root / "capture.png").write_bytes(evidence.PNG_SIGNATURE + b"changed")
            self.assertTrue(any("SHA-256 mismatch" in e for e in evidence.check_screenshots(root)[1]))
            (root / "capture.png").rename(root / "unlisted.png")
            errors = evidence.check_screenshots(root)[1]
            self.assertTrue(any("Missing screenshot" in e for e in errors))
            self.assertTrue(any("Unlisted screenshot" in e for e in errors))

    def test_manifest_rejects_duplicate_failure_provenance_and_path_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            entry = self.fixture(root)
            entry["attachment"]["isAssociatedWithFailure"] = True
            invalid = dict(entry, file="../outside.png")
            (root / "screenshots.json").write_text(json.dumps([entry, entry, invalid]))
            errors = evidence.check_screenshots(root)[1]
            for message in ["duplicate", "successful attachment", "invalid screenshot"]:
                self.assertTrue(any(message in e for e in errors), message)

    def test_malformed_manifest_is_a_diagnostic_not_a_crash(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for contents in ["invalid json", "{}", "[]", '[null, {"file":42}]']:
                (root / "screenshots.json").write_text(contents)
                self.assertTrue(evidence.check_screenshots(root)[1])


if __name__ == "__main__":
    unittest.main()
