#import "CartesianOCDemoViewController.h"
#import "SwiftFunctionProject-Swift.h"

@interface CartesianOCDemoViewController ()
@property(nonatomic, strong) HYMCartesianChartViewBridge *bridge;
@property(nonatomic, strong) HYMCartesianModel *model;
@property(nonatomic, strong) UIView *chartHost;
@property(nonatomic, strong) UILabel *readout;
@property(nonatomic, strong) UISegmentedControl *kindControl;
@property(nonatomic, strong) UISegmentedControl *stackControl;
@property(nonatomic, strong) UISegmentedControl *formatControl;
@property(nonatomic, strong) UISegmentedControl *boundaryControl;
@end

@implementation CartesianOCDemoViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"OC 轴系接入验证";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.kindControl = [[UISegmentedControl alloc] initWithItems:@[@"折线", @"柱状", @"条形", @"混合"]];
    self.kindControl.selectedSegmentIndex = 1;
    self.kindControl.accessibilityIdentifier = @"oc.cartesian.kind";
    self.stackControl = [[UISegmentedControl alloc] initWithItems:@[@"不堆叠", @"普通", @"百分比"]];
    self.stackControl.selectedSegmentIndex = 1;
    self.formatControl = [[UISegmentedControl alloc] initWithItems:@[@"原单位", @"k/M/G", @"仅显示绝对值"]];
    self.formatControl.selectedSegmentIndex = 0;
    self.boundaryControl = [[UISegmentedControl alloc] initWithItems:@[@"兼容边界", @"沿基线", @"正负分链"]];
    self.boundaryControl.selectedSegmentIndex = 0;
    self.boundaryControl.accessibilityIdentifier = @"oc.cartesian.boundary";
    for (UISegmentedControl *control in @[self.kindControl, self.stackControl, self.formatControl, self.boundaryControl]) {
        [control addTarget:self action:@selector(reloadChart) forControlEvents:UIControlEventValueChanged];
    }
    self.chartHost = [UIView new];
    self.readout = [UILabel new];
    self.readout.numberOfLines = 0;
    self.readout.font = [UIFont systemFontOfSize:12];
    self.readout.text = @"点击图表：OC 回调展示 raw / draw / base / percentage。";
    self.readout.accessibilityIdentifier = @"oc.cartesian.hit";
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.kindControl, self.stackControl, self.formatControl, self.boundaryControl, self.chartHost, self.readout]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.chartHost.heightAnchor constraintEqualToConstant:300],
    ]];
    [self reloadChart];
}
- (void)reloadChart {
    [self.bridge.chartView removeFromSuperview];
    self.bridge = [[HYMCartesianChartViewBridge alloc] initWithKind:(HYMCartesianChartKind)self.kindControl.selectedSegmentIndex frame:CGRectZero];
    BOOL hasLines = self.kindControl.selectedSegmentIndex == 0 || self.kindControl.selectedSegmentIndex == 3;
    BOOL boundaryEnabled = hasLines && self.stackControl.selectedSegmentIndex != 0;
    self.boundaryControl.enabled = boundaryEnabled;
    // Keep each accessibility button consistent after toggling the parent control.
    for (NSUInteger index = 0; index < self.boundaryControl.numberOfSegments; index++) {
        [self.boundaryControl setEnabled:boundaryEnabled forSegmentAtIndex:index];
    }
    self.bridge.stackedAreaFollowsBaseline = hasLines && self.boundaryControl.selectedSegmentIndex == 1;
    self.bridge.stackedAreaUsesDivergingChains = hasLines && self.boundaryControl.selectedSegmentIndex == 2;
    self.bridge.usesSharedTooltip = YES;
    self.bridge.tooltipOptions.groupsByBusinessID = YES;
    self.bridge.tooltipOptions.showsGroupSubtotals = YES;
    self.bridge.tooltipOptions.header = @"{key}";
    self.bridge.tooltipOptions.layout = HYMCartesianTooltipLayoutColumns;
    self.bridge.tooltipOptions.sampleOffset = -1;
    self.bridge.tooltipOptions.sampleBoundaryPolicy = HYMCartesianTooltipSampleBoundaryPolicyClamp;
    self.bridge.tooltipOptions.sampleOffsetsBySeriesID = @{@"target": @0};
    self.bridge.tooltipOptions.position = HYMCartesianTooltipPositionFixedTop;
    self.bridge.tooltipOptions.offset = CGPointMake(8, 0);
    self.bridge.tooltipOptions.rowStyleProvider = ^HYMCartesianTooltipRowStyle *(HYMCartesianDatum *datum) {
        HYMCartesianTooltipRowStyle *style = [HYMCartesianTooltipRowStyle new];
        style.image = [UIImage systemImageNamed:[datum.seriesID isEqualToString:@"solar"] ? @"sun.max.fill" : @"battery.100"];
        if (datum.rawValue != nil && datum.sourceRange.length == 1) {
            style.title = [NSString stringWithFormat:@"%@ · %lu", datum.name, (unsigned long)datum.sourceRange.location + 1];
        }
        return style;
    };
    HYMCartesianLegendItemStyle *solarLegend = [HYMCartesianLegendItemStyle new];
    solarLegend.image = [UIImage systemImageNamed:@"sun.max.fill"];
    solarLegend.hiddenImage = [UIImage systemImageNamed:@"sun.max"];
    solarLegend.backgroundColor = UIColor.secondarySystemBackgroundColor;
    solarLegend.cornerRadius = 6;
    self.bridge.legendItemStyles = @{@"solar": solarLegend};
    self.model = [HYMCartesianModel new];
    self.model.categories = @[@"08:00", @"08:05", @"08:10"];
    self.model.stacking = (HYMCartesianStacking)self.stackControl.selectedSegmentIndex;
    HYMCartesianGroup *group = [HYMCartesianGroup new];
    group.identifier = @"energy"; group.name = @"能源"; self.model.groups = @[group];
    NSMutableArray *series = [NSMutableArray array];
    for (NSInteger i = 0; i < 2; i++) {
        HYMCartesianSeries *row = [HYMCartesianSeries new];
        row.identifier = i == 0 ? @"solar" : @"battery";
        row.name = i == 0 ? @"光伏" : @"电池"; row.unit = @"W"; row.groupID = group.identifier;
        row.data = i == 0 ? @[@1000, @-1000, NSNull.null] : @[@500, @-500, @0];
        if (hasLines && self.boundaryControl.selectedSegmentIndex != 0) {
            row.kind = HYMCartesianSeriesKindAreaspline;
            row.data = i == 0 ? @[@1000, @-1000, NSNull.null] : @[@-500, @500, @100];
        }
        row.color = i == 0 ? UIColor.systemBlueColor : UIColor.systemOrangeColor;
        row.valueFormat = [HYMCartesianValueFormat new];
        row.valueFormat.engineeringScale = self.formatControl.selectedSegmentIndex == 1;
        row.valueFormat.showsAbsoluteValue = self.formatControl.selectedSegmentIndex == 2;
        [series addObject:row];
    }
    if (self.kindControl.selectedSegmentIndex == 3) {
        HYMCartesianSeries *line = [HYMCartesianSeries new];
        line.identifier = @"target"; line.name = @"目标曲线"; line.data = @[@800, @600, @900];
        line.kind = HYMCartesianSeriesKindSpline; line.participatesInStack = NO;
        line.color = UIColor.systemRedColor; line.style = [HYMCartesianSeriesStyle new];
        line.style.lineWidth = @3; line.style.showsPoints = @YES;
        line.marker = HYMCartesianMarkerDiamond;
        [series addObject:line];
    }
    self.model.series = series;
    __weak typeof(self) weakSelf = self;
    self.bridge.onHit = ^(NSArray<HYMCartesianDatum *> *rows) {
        NSMutableArray *lines = [NSMutableArray array];
        for (HYMCartesianDatum *row in rows) {
            [lines addObject:[NSString stringWithFormat:@"%@：%@；raw=%@ draw=%.2f base=%.2f %%=%@", row.name, row.formattedValue, row.rawValue, row.drawValue, row.stackBase, row.percentage ?: @"—"]];
        }
        weakSelf.readout.text = [lines componentsJoinedByString:@"\n"];
    };
    UIView *chart = self.bridge.chartView;
    chart.accessibilityIdentifier = @"oc.cartesian.chart";
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartHost addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.chartHost.topAnchor],
        [chart.bottomAnchor constraintEqualToAnchor:self.chartHost.bottomAnchor],
        [chart.leadingAnchor constraintEqualToAnchor:self.chartHost.leadingAnchor],
        [chart.trailingAnchor constraintEqualToAnchor:self.chartHost.trailingAnchor],
    ]];
    NSError *error = nil;
    if (![self.bridge configureWithModel:self.model error:&error]) { self.readout.text = error.localizedDescription; }
}
@end
