#import <UIKit/UIKit.h>
#import <HYMCharts/HYMCharts-Swift.h>

@interface IntegrationController : UIViewController
@property(nonatomic, strong) HYMCartesianChartViewBridge *bridge;
@property(nonatomic, strong) UILabel *hit;
@end
@implementation IntegrationController
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 350, 70)];
    status.numberOfLines = 0; status.accessibilityIdentifier = @"integration-status";
    self.hit = [[UILabel alloc] initWithFrame:CGRectMake(20, 480, 350, 70)];
    self.hit.numberOfLines = 0; self.hit.accessibilityIdentifier = @"integration-hit";
    self.bridge = [[HYMCartesianChartViewBridge alloc] initWithKind:HYMCartesianChartKindLine frame:CGRectMake(10, 150, 370, 310)];
    self.bridge.stackedAreaUsesDivergingChains = YES; // Generated Objective-C header compile check.
    [self.view addSubview:self.bridge.chartView]; [self.view addSubview:status]; [self.view addSubview:self.hit];
    HYMCartesianSeries *series = [HYMCartesianSeries new]; series.identifier = @"power"; series.name = @"Stable series";
    NSMutableArray *categories = [NSMutableArray array], *values = [NSMutableArray array], *updated = [NSMutableArray array];
    for (NSInteger i = 0; i < 48; i++) { [categories addObject:@(i).stringValue]; [values addObject:@100]; [updated addObject:@500]; }
    series.data = values;
    HYMCartesianColorZone *low = [HYMCartesianColorZone new]; low.upperBound = @300; low.color = UIColor.systemRedColor;
    HYMCartesianColorZone *high = [HYMCartesianColorZone new]; high.color = UIColor.systemGreenColor;
    HYMCartesianColorZones *zones = [HYMCartesianColorZones new]; zones.zones = @[low, high];
    zones.columnValueSource = HYMCartesianColumnZoneValueSourceRawValue;
    series.colorZones = zones;
    zones.columnValueSource = HYMCartesianColumnZoneValueSourceDrawValue;
    HYMCartesianModel *model = [HYMCartesianModel new]; model.categories = categories; model.series = @[series];
    model.xAxisStyle.labelColor = UIColor.systemPurpleColor;
    model.xAxisStyle.labelFont = [UIFont systemFontOfSize:13];
    model.xAxisStyle.lineColor = UIColor.systemPurpleColor; model.xAxisStyle.lineWidth = @2;
    model.categoryLabelInterval = @2; model.yAxisStyle.showsLine = NO;
    HYMCartesianPlotLine *reference = [HYMCartesianPlotLine new]; reference.value = 500; reference.label = @"Reference";
    reference.labelStyle.color = UIColor.systemPurpleColor; reference.labelStyle.font = [UIFont boldSystemFontOfSize:13];
    reference.labelStyle.backgroundColor = UIColor.systemBackgroundColor;
    reference.labelStyle.alignment = HYMCartesianAnnotationAlignmentLeading;
    reference.labelStyle.verticalAlignment = HYMCartesianAnnotationVerticalAlignmentTop;
    reference.labelStyle.offset = CGSizeMake(2, 3); reference.labelStyle.bounds = HYMCartesianAnnotationBoundsClamp;
    HYMCartesianPlotBand *band = [HYMCartesianPlotBand new]; band.from = 300; band.to = 550; band.label = @"Range";
    model.plotLines = @[reference]; model.plotBands = @[band];
    self.bridge.dataLabelBackgroundColor = UIColor.systemBackgroundColor; self.bridge.dataLabelAvoidsOverlap = YES;
    self.bridge.selectionStyle.isEnabled = YES; self.bridge.selectionStyle.color = UIColor.systemOrangeColor;
    self.bridge.selectionStyle.lineWidth = 3; self.bridge.selectionStyle.fillOpacity = 0.15; self.bridge.selectionStyle.pointRadius = 8;
    NSError *error = nil;
    BOOL passed = [self.bridge configureWithModel:model error:&error];
    [self.bridge.chartView layoutIfNeeded];
    self.bridge.isZoomEnabled = YES; [self.bridge showCategoryRange:NSMakeRange(10, 20)];
    NSMutableArray<NSNumber *> *events = [NSMutableArray array];
    self.bridge.onSeriesVisibilityChanged = ^(NSString *identifier, BOOL visible) { if ([identifier isEqualToString:@"power"]) [events addObject:@(visible)]; };
    [self.bridge setSeriesVisible:NO forID:@"power"];
    series.name = @"Renamed series"; series.data = updated;
    passed &= [self.bridge updateWithModel:model preserveViewport:YES error:&error];
    [self.bridge.chartView layoutIfNeeded];
    [self.bridge setSeriesVisible:NO forID:@"power"]; // Preserved hidden state must not emit another callback.
    [self.bridge setSeriesVisible:YES forID:@"power"]; [self.bridge resetViewport];
    passed &= [events isEqualToArray:@[@NO, @YES]];
    // Invalid input must be rejected through the generated NSError signature and keep the valid chart.
    HYMCartesianModel *invalid = [HYMCartesianModel new]; invalid.series = @[series, series];
    passed &= ![self.bridge updateWithModel:invalid preserveViewport:YES error:&error];
    passed &= [error.domain isEqualToString:@"HYMCharts.Configuration"] && error.code == 1;
    __weak IntegrationController *weakSelf = self;
    self.bridge.onHit = ^(NSArray<HYMCartesianDatum *> *data) {
        HYMCartesianDatum *datum = data.firstObject;
        if (datum) weakSelf.hit.text = [NSString stringWithFormat:@"hit:%@:%ld", datum.seriesID, (long)datum.rawValue.integerValue];
    };
    HYMCartesianModel *stackModel = [HYMCartesianModel new]; stackModel.stacking = HYMCartesianStackingPercent;
    HYMCartesianSeries *base = [HYMCartesianSeries new]; base.identifier = @"g1-base";
    base.kind = HYMCartesianSeriesKindAreaspline; base.data = @[@20, @-20, @40, @10];
    HYMCartesianSeries *thin = [HYMCartesianSeries new]; thin.identifier = @"g1-thin";
    thin.kind = HYMCartesianSeriesKindArea; thin.data = @[@2, @2, NSNull.null, @2];
    stackModel.series = @[base, thin];
    NSInteger released = 0;
    for (NSInteger i = 0; i < 30; i++) {
        __weak HYMCartesianChartViewBridge *weakBridge;
        __weak UIView *weakChart;
        @autoreleasepool {
            HYMCartesianChartViewBridge *temporary = [[HYMCartesianChartViewBridge alloc] initWithKind:HYMCartesianChartKindCombined frame:CGRectMake(0, 0, 370, 310)];
            temporary.stackedAreaUsesDivergingChains = YES;
            passed &= [temporary configureWithModel:stackModel error:nil]; [temporary.chartView layoutIfNeeded];
            weakBridge = temporary; weakChart = temporary.chartView;
        }
        if (!weakBridge && !weakChart) released++;
    }
    passed &= released == 30;
    // Load the same engine-neutral document through the generated public Objective-C API.
    NSURL *sampleURL = [NSBundle.mainBundle URLForResource:@"energy" withExtension:@"json"];
    NSData *sampleData = sampleURL ? [NSData dataWithContentsOfURL:sampleURL] : nil;
    HYMChartSpecificationDocument *document = sampleData ? [[HYMChartSpecificationDocument alloc] initWithJSONData:sampleData error:&error] : nil;
    HYMCartesianChartViewBridge *neutralBridge = [document makeNativeBridgeWithFrame:CGRectMake(0, 0, 370, 310) error:&error];
    [neutralBridge.chartView layoutIfNeeded];
    BOOL neutralPassed = neutralBridge != nil
        && [[document sampleIdentifierForSeriesID:@"solar" categoryIndex:0] isEqualToString:@"solar-08"]
        && [neutralBridge updateWithSpecification:document preserveViewport:YES error:&error]
        && [document JSONDataWithError:&error] != nil;
    NSURL *g1URL = [NSBundle.mainBundle URLForResource:@"energy-g1-v2" withExtension:@"json"];
    NSData *g1Data = g1URL ? [NSData dataWithContentsOfURL:g1URL] : nil;
    HYMChartSpecificationDocument *g1Document = g1Data ? [[HYMChartSpecificationDocument alloc] initWithJSONData:g1Data error:&error] : nil;
    HYMCartesianChartViewBridge *g1Bridge = [g1Document makeNativeBridgeWithFrame:CGRectMake(0, 0, 370, 310) error:&error];
    [g1Bridge.chartView layoutIfNeeded];
    NSData *roundTrip = [g1Document JSONDataWithError:&error];
    NSDictionary *g1Object = roundTrip ? [NSJSONSerialization JSONObjectWithData:roundTrip options:0 error:&error] : nil;
    BOOL g1Passed = g1Bridge != nil && [g1Object[@"schemaVersion"] integerValue] == 2
        && [g1Object[@"stackedAreaBoundary"] isEqual:@"diverging"]
        && [[g1Document sampleIdentifierForSeriesID:@"battery" categoryIndex:0] isEqual:@"battery-08"]
        && [g1Bridge updateWithSpecification:g1Document preserveViewport:YES error:&error];
    NSURL *zonesURL = [NSBundle.mainBundle URLForResource:@"energy-zones-v3" withExtension:@"json"];
    NSData *zonesData = zonesURL ? [NSData dataWithContentsOfURL:zonesURL] : nil;
    HYMChartSpecificationDocument *zonesDocument = zonesData ? [[HYMChartSpecificationDocument alloc] initWithJSONData:zonesData error:&error] : nil;
    NSData *zonesRoundTrip = [zonesDocument JSONDataWithError:&error];
    NSDictionary *zonesObject = zonesRoundTrip ? [NSJSONSerialization JSONObjectWithData:zonesRoundTrip options:0 error:&error] : nil;
    NSDictionary *firstAppearance = [zonesObject[@"series"] firstObject][@"appearance"];
    NSDictionary *zoneConfig = firstAppearance[@"valueColorZones"];
    BOOL zonesPassed = zonesDocument != nil && [zonesObject[@"schemaVersion"] integerValue] == 3
        && [zonesObject[@"stackedAreaBoundary"] isEqual:@"diverging"]
        && [zoneConfig[@"valueSource"] isEqual:@"drawValue"] && [zoneConfig[@"zones"] count] == 3
        && [[zonesDocument sampleIdentifierForSeriesID:@"solar" categoryIndex:0] isEqual:@"solar-08"]
        && [g1Bridge updateWithSpecification:zonesDocument preserveViewport:YES error:&error];
    [g1Bridge.chartView layoutIfNeeded];
    NSURL *axesURL = [NSBundle.mainBundle URLForResource:@"energy-axes-v4" withExtension:@"json"];
    NSData *axesData = axesURL ? [NSData dataWithContentsOfURL:axesURL] : nil;
    HYMChartSpecificationDocument *axesDocument = axesData ? [[HYMChartSpecificationDocument alloc] initWithJSONData:axesData error:&error] : nil;
    NSData *axesRoundTrip = [axesDocument JSONDataWithError:&error];
    NSDictionary *axesObject = axesRoundTrip ? [NSJSONSerialization JSONObjectWithData:axesRoundTrip options:0 error:&error] : nil;
    NSDictionary *axis = [axesObject[@"valueAxes"] firstObject];
    BOOL axesPassed = axesDocument != nil && [axesObject[@"schemaVersion"] integerValue] == 4
        && [axesObject[@"categoryLabelInterval"] integerValue] == 2
        && [axesObject[@"domainAppearance"][@"labelFontWeight"] isEqual:@"medium"]
        && [axis[@"appearance"][@"labelFontWeight"] isEqual:@"bold"]
        && [axis[@"tickPositions"] isEqual:@[@(-100), @(-50), @0, @50, @100]]
        && [axis[@"labelFormat"][@"unit"] isEqual:@"%"]
        && [[axesDocument sampleIdentifierForSeriesID:@"solar" categoryIndex:0] isEqual:@"solar-08"]
        && [g1Bridge updateWithSpecification:axesDocument preserveViewport:YES error:&error];
    [g1Bridge.chartView layoutIfNeeded];
    neutralPassed &= g1Passed && zonesPassed && axesPassed;
    passed &= neutralPassed;
    status.text = [NSString stringWithFormat:@"%@ OC | update=500 | visibility=%lu | released=%ld/30 | invalid=rejected | neutral=%@", passed ? @"PASS" : @"FAIL", (unsigned long)events.count, (long)released, neutralPassed ? @"true" : @"false"];
}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [IntegrationController new]; [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc, char *argv[]) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); } }
