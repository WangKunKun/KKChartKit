#!/usr/bin/env python3
"""Inspect a built HYMCharts.framework; emit a portable dependency/resource audit."""
from pathlib import Path
import hashlib, json, subprocess, sys
framework = Path(sys.argv[1]).resolve()
assert framework.name == 'HYMCharts.framework' and framework.is_dir()
files = sorted(p for p in framework.rglob('*') if p.is_file())
header = framework / 'Headers/HYMCharts-Swift.h'
assert 'HYMCartesianChartViewBridge' in header.read_text()
assert all(name in header.read_text() for name in ['HYMCartesianPlotLine', 'HYMCartesianPlotBand', 'HYMCartesianAnnotationLabelStyle', 'HYMCartesianSelectionStyle', 'dataLabelAvoidsOverlap'])
assert 'HYMCartesianAxisStyle' in header.read_text() and 'categoryLabelInterval' in header.read_text()
assert 'stackedAreaFollowsBaseline' in header.read_text()
assert 'stackedAreaUsesDivergingChains' in header.read_text()
assert all(name in header.read_text() for name in ['HYMChartSpecificationDocument', 'initWithJSONData', 'makeNativeBridgeWithFrame', 'updateWithSpecification'])
assert 'HYMCartesianColumnZoneValueSource' in header.read_text() and 'columnValueSource' in header.read_text()
interfaces = list((framework / 'Modules').rglob('*.swiftinterface'))
assert interfaces
for p in interfaces:
    text = p.read_text()
    for name in ['LineChart','ColumnChart','BarChart','CombinedChart','HeatmapChart','RadarChart']:
        assert f'public struct {name} :' in text, (p, name)
    assert all(name in text for name in ['CartesianAnnotationLabelStyle', 'CartesianSelectionStyle', 'dataLabelAvoidsOverlap'])
    assert 'CartesianAxisStyle' in text and 'categoryLabelInterval' in text
    assert 'CartesianColumnZoneValueSource' in text and 'columnValueSource' in text
    assert 'StackedAreaBoundaryMode' in text and 'stackedAreaBoundaryMode' in text
    assert 'case diverging' in text and 'divergingLinearFallbackSeries' in text
    assert all(name in text for name in ['ChartSpecification', 'ChartAdapter', 'ChartSample', 'HYMChartsSpecificationAdapter'])
    assert all(name in text for name in ['ChartStackedAreaBoundary', 'stackedAreaBoundary', 'latestSchemaVersion'])
    assert all(name in text for name in ['ChartValueColorZone', 'ChartValueColorZones', 'ChartZoneValueSource', 'valueColorZones'])
    assert all(name in text for name in ['ChartFontWeight', 'ChartAxisLabelFormat', 'categoryLabelInterval', 'tickPositions', 'labelFormat', 'labelFontWeight'])
    assert 'ChartSelfTest' not in text and 'CartesianChartDemo' not in text
for p in files:
    assert p.suffix not in {'.js','.html','.xcassets'}, p
    if p.suffix == '.json':
        assert p.name.endswith('.abi.json') and p.parent == framework / 'Modules/HYMCharts.swiftmodule', p
    assert not any(x in p.name.lower() for x in ['aachart','highcharts','fixture','demo']), p
binary = framework / 'HYMCharts'
links = subprocess.check_output(['xcrun','otool','-L',str(binary)],text=True)
assert '@rpath/HYMCharts.framework/HYMCharts' in links, links
assert not any(x in links for x in ['WebKit','AAChart','Highcharts','SwiftFunctionProject'])
print(json.dumps(dict(framework=str(framework),binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
    dependencies=links.splitlines(),files=[str(p.relative_to(framework)) for p in files],
    checks=['G2 column/bar color zones Swift/OC API','G3 independent axes Swift/OC API','G4 annotations and data label avoidance Swift/OC API','G5 body selection Swift/OC API','G1 diverging shared sign chains Swift/OC API and fallback diagnostics','neutral schema v4 axis presentation, v3 value zones, v2 boundary API and backward-compatible v1 construction','generated Objective-C header','six public SwiftUI wrappers','@rpath install name','no AA/JS/WebKit/App dependency or fixture/Demo resources']),ensure_ascii=False,indent=2))
