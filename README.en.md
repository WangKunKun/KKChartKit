# KKChartKit / HYMCharts

[简体中文](README.md)

A native Swift chart module for iOS. Public types currently use the `HYM` and `Cartesian` prefixes. Rendering uses UIKit and Core Animation, with SwiftUI wrappers and Objective-C bridges.

This repository contains source code and a runnable demo project. It does **not** currently publish a standalone Swift package, CocoaPod, or XCFramework. The project deployment target is iOS 15; historical checks used Xcode 26.3 with an iOS 17.2 simulator, while the 2026-10-09 layout follow-up uses iOS 18.6 (see its progress record below). This is not a claim of validation on every supported OS version.


2026-10-09: [N4 fixed-top tooltip layout](docs/charts-neutral-tooltip-layout-task-progress-2026-10-09.md) adds opt-in native `fixedTopUsesPlotArea` (default `false`), enabled by N4 fixedTop adaptation. Tooltips stay inside the plot, avoiding title/legend/axis-label regions, but still overlay data. No new JSON field or reserved header area.

2026-10-09: [N4 tooltip and legend (schema v6)](docs/charts-neutral-interaction-task-progress-2026-10-09.md) adds serializable content, stable-series rules, category-slot offsets and boundary policies, plus legend layout/titles. Default v1 construction and all v1–v5 fixtures remain unchanged. Images/callbacks remain runtime concerns; dynamic group names, business subtotals and G6 are not included.

2026-10-09: [N3 value-axis annotations (schema v5)](docs/charts-neutral-annotations-task-progress-2026-10-09.md) adds stable axis bindings, visibility, line styles and label styling using the existing fixed native layering. Default v1 construction and v1–v4 JSON remain unchanged. See the [neutral model guide](docs/charts-neutral-model-guide.md) for versioning and limits; this does not enable G6 coordinates or a legacy-input mapper.

## Features

2026-10-03: [Engine-neutral chart specifications](docs/charts-neutral-model-guide.md) add Foundation-only value models, stable identities, versioned JSON, diagnostics, and a HYMCharts adapter with Swift/Objective-C entry points. Other engine adapters and automatic legacy-model migration remain future work.

| Area | Current support |
| --- | --- |
| Lines and areas | Straight, smooth, three step styles, signed values, missing-data policies, continuous color zones |
| Columns and bars | Side-by-side series, grouped stacks, percent/fixed-base stacks, fixed dimensions and automatic scrolling |
| Combined charts | Columns, lines, splines, and areas with shared axes, legend, and hit testing |
| Radar and heatmap | Separate models, themes, hit targets, popups, SwiftUI and Objective-C APIs |
| Cartesian data | Stable series IDs, dual axes except Bar, raw/stacked value separation, business groups and per-series formats |
| Dense data | Min/Max sampling for unstacked straight lines, regular-time aggregation for Column, layer/label reuse |
| Tooltips and legends | Shared hits, group subtotals, icons/name-value columns, per-point presentation, sample offsets, fixed-top placement, scrolling, custom legends and measurement |
| Interaction | Zoom, pan, crosshairs, visibility, category navigation, viewport-preserving updates and custom popups |

See the [capability status](docs/charts-capability-status.md) for detailed scope.

## Run and integrate

1. Open `SwiftFunctionProject.xcodeproj` in Xcode.
2. Select the `SwiftFunctionProject` scheme and an iOS simulator, then run.
3. Each chart has a single demo page with searchable properties, presets, and hit readouts. Demo labels currently use Chinese.

For source integration, add the required files under `SwiftFunctionProject/Charts` to your App target or a framework target you maintain, preserving dependencies. `Charts/SwiftUI` contains wrappers and demos; omit that folder when only UIKit is required. Do not compile `SwiftFunctionProject/参考图表`: it contains legacy reference sources and is excluded from the demo App target. There is no published module to import as `KKChartKit` yet.

Use the main thread for chart views, theme updates, measurement, and interactions. Series IDs must be nonempty, unique, and stable across updates.

## SwiftUI quick start

```swift
import SwiftUI

struct EnergyChart: View {
    private let model = CartesianChartModel(
        title: "Power",
        series: [
            .init(name: "Solar", data: [100, 150, .nan, 180],
                  color: .systemOrange, id: "solar", unit: "W"),
            .init(name: "Battery", data: [-40, 20, 35, 50],
                  color: .systemBlue, id: "battery", unit: "W")
        ],
        xAxis: .init(kind: .category(labels: ["08:00", "08:05", "08:10", "08:15"]))
    )

    var body: some View {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.showsTooltipOnHit = true
        return LineChart(model: model, theme: theme,
                         isZoomEnabled: true,
                         isSharedTooltipOnTapEnabled: true)
            .frame(height: 320)
    }
}
```

`ColumnChart` and `BarChart` use the same Cartesian model. Use `CombinedChart` with explicit per-series `kind` for mixed shapes. Preserve missing samples as `.nan`; removing array positions changes category/time alignment.

## UIKit updates and hit data

```swift
let chart = HYMChartView<LineChartRenderer>(frame: .zero)
// Assign a nonzero frame or Auto Layout constraints and add it to your parent view.
var model = CartesianChartModel(series: [
    .init(name: "Power", data: [100, 120, 90], id: "power", unit: "W")
])
var theme = CartesianChartTheme()
theme.legend.isEnabled = true
theme.showsTooltipOnHit = true
chart.showsTooltipOnHit = true
chart.configure(model: model, theme: theme)
chart.isZoomEnabled = true
chart.isSharedTooltipOnTapEnabled = true
chart.onHit = { target, _ in
    let rows = (target as? CartesianHitDataSource)?.chartData ?? []
    for row in rows {
        // rawValue is nil for time-aggregated data.
        // displayValue is the raw sample or aggregation result.
        // drawValue and stackBase are drawing coordinates, not the series' own value.
        _ = row.formattedValue
    }
}
model.series[0].data = [110, 130, 95]
chart.update(model: model, viewportPolicy: .preserve)
chart.showCategoryRange(0..<2)
chart.setSeriesVisible(false, for: "power")
chart.resetViewport()
```

`configure` resets the viewport and local visibility state. Use `update` for normal changes. Stable IDs maintain series identity. [Update rules](docs/charts-update-guide.md) · [Data semantics](docs/charts-data-semantics-guide.md)

## Stacks, combined charts and dual axes

```swift
var model = CartesianChartModel(series: [
    .init(name: "Solar", data: [100, 120], id: "solar", kind: .column, stackID: "supply"),
    .init(name: "Battery", data: [50, 40], id: "battery", kind: .column, stackID: "supply"),
    .init(name: "Target", data: [160, 170], yAxisIndex: 1,
          id: "target", kind: .spline, participatesInStack: false)
], secondaryYAxis: .init(kind: .value), stacking: .normal)
// SwiftUI: CombinedChart(model: model)
// UIKit: HYMChartView<CombinedChartRenderer>
```

Stacks are separated by value axis, shape family, and `stackID`. Positive and negative values accumulate separately. Percent denominators are calculated per stack. `groupID` describes business presentation and never changes stack math. Per-series `style` overrides shape defaults and the global theme. [Combined charts and stacks](docs/charts-combined-and-stacks-guide.md)

## Sampling, missing data and fixed dimensions

```swift
// Width-based sampling remains the default when sampling is enabled.
var sampling = LineChartSampling()
sampling.bucketWidth = 2
sampling.minimumVisiblePoints = 500 // Activation threshold, not a retained-point count.
theme.lineSampling = sampling
// Optional target per series and current viewport; protected endpoints/extrema may exceed it.
theme.lineSampling?.targetPointCount = 200
// Restore width-based sampling:
theme.lineSampling?.targetPointCount = nil

model.series[0].gapPolicy = .autoGap(maximumMissingPoints: 12)
// Column / Bar / Combined: fixed dimensions with automatic overflow scrolling.
theme.columnSpacing = .init(columnWidth: 12, inner: 4, group: 16)
```

Sampling reduces rendered points without changing original samples, data bounds, or hit values. Zooming selects points again from the original data. Curves, steps, and stacks currently fall back to original rendering. Column time aggregation requires `model.timeAxis`, `model.timeGrouping`, and an explicit `aggregation` for every visible series; this is separate from line sampling.

[Line sampling](docs/charts-line-sampling-guide.md) · [Gap policies](docs/charts-gap-policy-guide.md) · [Color zones](docs/charts-color-zones-guide.md) · [Time aggregation](docs/charts-time-grouping-guide.md) · [Fixed dimensions](docs/charts-fixed-column-layout-guide.md)

## Grouped tooltips and image legends

```swift
model.groups = [.init(id: "energy", name: "Energy")]
model.series[0].groupID = "energy"
chart.tooltipTextOptions.cartesian.groupsByBusinessID = true
chart.tooltipTextOptions.cartesian.showsGroupSubtotals = true
chart.tooltipTextOptions.cartesian.hidesZeroValues = true
chart.tooltipTextOptions.cartesian.ungroupedTitle = "Other"
chart.tooltipTextOptions.cartesian.subtotalTitle = "Net total"

theme.legend.itemOverrides["solar"] = .init(
    image: UIImage(systemName: "sun.max.fill"),
    hiddenImage: UIImage(systemName: "sun.max"),
    backgroundColor: .secondarySystemBackground, cornerRadius: 6)
theme.legend.startsNewRowPerGroup = true
chart.update(model: model, theme: theme)
```

Subtotals are opt-in and require at least two original samples from the same group, source range, unit, axis, and value format. They use signed original values; they do not sum stacked endpoints or time aggregates. Filtering affects tooltip presentation only. Default grouping/subtotal labels can be customized; other existing built-in text is not fully localized.

Legend symbol precedence is custom `symbolViewProvider` > image for the current visibility state > built-in shape. Providers run on the main thread and return a view exclusively owned by that item. Avoid strong captures of the chart. The symbol uses fixed `symbolSize`; the legend owns taps and sizing. Group row breaks follow adjacent group IDs after legend sorting. Public measurement uses the same layout rules as rendering.

[Grouped presentation guide](docs/charts-grouped-presentation-guide.md) · [Legend measurement](docs/charts-legend-guide.md) · [Custom popup APIs](docs/charts-popup-guide.md)

Enable icons and name/value columns inside the built-in tooltip:

```swift
var presentation = CartesianTooltipPresentation()
presentation.layout = .columns
presentation.rowStyleProvider = { datum in
    .init(image: UIImage(systemName: "bolt.fill"),
          hidesValue: datum.seriesID == "standby")
}
chart.cartesianTooltipPresentation = presentation
```

Per-point rules do not change hit data. Name-only rows are excluded from subtotals. Long names/values wrap, and tall content scrolls inside the tooltip. The same options are available in SwiftUI and Objective-C. [Rich tooltip guide](docs/charts-rich-tooltip-guide.md)

Select a previous sample and keep the tooltip at the top while hit callbacks retain the current sample:

```swift
var selection = CartesianTooltipSampleSelection()
selection.offset = -1
selection.boundaryPolicy = .clamp
selection.sourceLabelTemplate = "Value at {key}"
chart.cartesianTooltipSampleSelection = selection
chart.tooltipTheme.position = .fixedTop
chart.tooltipTheme.offset = CGPoint(x: 12, y: 0)
```

Per-series overrides use stable IDs. Missing source values are omitted without searching; actual time aggregates retain the current bucket. Source labels and displayed snapshots keep the two indices explicit. [Sample selection and placement guide](docs/charts-tooltip-selection-guide.md)

## Objective-C

Within the same App target, import Xcode's generated `YourProductModuleName-Swift.h`; this demo uses `SwiftFunctionProject-Swift.h`. Keep the bridge alive in a property and configure it on the main thread:

```objc
HYMCartesianSeries *series = [HYMCartesianSeries new];
series.identifier = @"solar";
series.name = @"Solar";
series.unit = @"W";
series.data = @[@100, @150, NSNull.null, @180];
HYMCartesianModel *model = [HYMCartesianModel new];
model.series = @[series];
HYMCartesianChartViewBridge *bridge = [[HYMCartesianChartViewBridge alloc]
    initWithKind:HYMCartesianChartKindLine frame:CGRectMake(0, 0, 350, 300)];
[self.view addSubview:bridge.chartView];
NSError *error = nil;
if (![bridge configureWithModel:model error:&error]) {
    // Pass error to your application's error handling.
}
// Retain bridge in a property for callbacks and later updates.
```

`onHit` provides an array of `HYMCartesianDatum`. Invalid configuration produces NSError. Changes to Objective-C models or presentation options require another configure/update call. The bridge does not mirror every Swift theme property. [Objective-C/data guide](docs/charts-data-semantics-guide.md)

## Documentation and tests

Detailed guides currently use Chinese, with Swift and Objective-C examples:

- [Demo navigation and searchable properties](docs/charts-demo-guide.md)
- [Lines](docs/charts-line-guide.md), [columns and bars](docs/charts-column-guide.md)
- [Rendering reuse](docs/charts-rendering-reuse-guide.md)
- [Line demo audit](docs/charts-line-demo-audit-2026-09-29.md), [stacked-area seam boundaries](docs/charts-stacked-area-seams-guide.md)
- [Legacy migration audit](docs/charts-legacy-module-migration-audit.md), [roadmap](docs/2026-09-24-charts-status-and-roadmap.md)
- Radar and heatmap usage/design records: [docs/superpowers/specs](docs/superpowers/specs).

```sh
xcodebuild test -project SwiftFunctionProject.xcodeproj \
  -scheme SwiftFunctionProject \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -derivedDataPath /tmp/KKChartKit-build \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Remaining work includes automatic time aggregation for Bar/Combined, sampling for curves/stacks, irregular XY coordinates, reusable cards, linked selection, fullscreen containers, and standalone SDK distribution. Stacked areas do not guarantee seamless transitions where signed/missing-data intervals have no shared baseline. See the individual guides for exact validation scope and historical results.


## Chart presentation controls (2026-10-02)

G2–G5 add whole-mark column/bar color zones (raw/draw), independent axis styles and category label intervals, annotation label styles and opt-in data-label collision avoidance, and opt-in mark selection overlays. UIKit/SwiftUI configuration, the Objective-C bridge and existing demos use the same renderers without changing raw data, stack semantics or hit identity.

[Color zones](docs/charts-color-zones-guide.md) · [Axis styles](docs/charts-axis-style-guide.md) · [Annotations](docs/charts-annotation-style-guide.md) · [Selection](docs/charts-selection-style-guide.md) · [Validation and boundaries](docs/charts-presentation-g2-g5-2026-10-02.md)
