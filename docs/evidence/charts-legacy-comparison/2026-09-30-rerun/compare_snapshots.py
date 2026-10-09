"""Recompute numerical evidence from exported runtime JSON; does not run either engine."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TOLERANCE = 1e-8
sources = {}


def read(name):
    path = ROOT / (name + ".json")
    sources[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    value = json.loads(path.read_text())
    return value[0] if isinstance(value, list) else value


def compare(old_name, new_name, *, require_draw_match):
    old, new = read(old_name), read(new_name)
    old_by_name = {series["name"]: series for series in old["series"]}
    differences, raw_error, draw_error = [], 0, 0
    count = 0
    for series in new["series"]:
        original = old_by_name[series["name"]]
        points = {point["index"]: point for point in original["samples"]}
        for point in series["samples"]:
            reference = points[point["index"]]
            raw_error = max(raw_error, abs(point["raw"] - reference["raw"]))
            delta = point["stackY"] - reference["stackY"]
            draw_error = max(draw_error, abs(delta))
            count += 1
            if abs(delta) > TOLERANCE:
                differences.append({"seriesID": series["id"], "index": point["index"],
                                    "legacyDraw": reference["stackY"], "nativeDraw": point["stackY"]})
            if new_name == "hym-signed-percent-mapped":
                assert abs(point["percentage"] - reference["percentage"]) <= TOLERANCE
    assert raw_error <= TOLERANCE
    if require_draw_match:
        assert draw_error <= TOLERANCE
    return {"old": old_name, "new": new_name, "comparedPoints": count,
            "maxRawError": raw_error, "maxDrawDifference": draw_error, "drawDifferences": differences}


def compare_area(case):
    old, new = read("audit-" + case), read("hym-" + case + "-business-series")
    is_single = case == "area-single"
    assert len(old["series"]) == (5 if is_single else 3)
    assert len(new["series"]) == 2
    assert sum(series["name"] == "" for series in old["series"]) == 1
    differences, clipped, count = [], [], 0
    for series in new["series"]:
        ordinal = {"battery": 0, "aux": 1}[series["id"]]
        for point in series["samples"]:
            # This mapping is specific to the captured default (reverse=false) audit fixtures.
            # Use the active sign copy; do not mistake the other copy's synthetic zero for raw data.
            index = (ordinal + (3 if point["raw"] < 0 else 0)) if is_single else ordinal * 2
            original = old["series"][index]
            assert original["name"] == series["name"]
            reference = next(p for p in original["samples"] if p["index"] == point["index"])
            assert abs(reference["raw"] - point["raw"]) <= TOLERANCE
            count += 1
            if abs(reference["stackY"] - point["stackY"]) > TOLERANCE:
                differences.append({"seriesID": series["id"], "index": point["index"], "raw": point["raw"],
                                    "legacyDraw": reference["stackY"], "nativeDraw": point["stackY"]})
            if not old["axes"][0]["min"] <= reference["stackY"] <= old["axes"][0]["max"]:
                clipped.append({"seriesID": series["id"], "index": point["index"], "draw": reference["stackY"]})
    return {"case": case, "businessPointsCompared": count, "rawMatches": True,
            "legacySeriesCount": len(old["series"]), "nativeSeriesCount": len(new["series"]),
            "drawDifferences": differences, "legacyAxis": old["axes"][0], "legacyClippedSamples": clipped}


def main():
    result = {"schemaVersion": 1, "tolerance": TOLERANCE,
              "scope": "Six representative indices per series; no pixel or complete-page parity claim.",
              "comparisons": [
                  compare("comparison-signed-normal", "hym-signed-normal-mapped", require_draw_match=True),
                  compare("comparison-signed-percent", "hym-signed-percent-mapped", require_draw_match=True),
                  compare("audit-mixed-types", "hym-mixed-types-unmapped", require_draw_match=False),
                  compare("audit-mixed-types", "hym-mixed-types-partitioned", require_draw_match=True)],
              "areas": [compare_area("area-single"), compare_area("area-multi")],
              "sourcesSHA256": sources}
    (ROOT / "numeric-audit-summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"comparisons": [(x["new"], x["maxDrawDifference"]) for x in result["comparisons"]],
                      "areas": [(x["case"], x["drawDifferences"]) for x in result["areas"]]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
