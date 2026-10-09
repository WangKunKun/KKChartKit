#import "LCScenarioViewController.h"
#import "LCScenario.h"
#import "LCChartProbe.h"
#import "HMAAChartUtil.h"

@interface LCScenarioViewController () <HMLGAAChartViewDelegate>
@property (nonatomic, strong) LCScenario *scenario;
@property (nonatomic, copy) NSArray<HMAAChartModel *> *models;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIStackView *configuration;
@property (nonatomic, strong) UIView *chartContainer;
@property (nonatomic, strong) UIView *legacyView;
@property (nonatomic, strong) NSLayoutConstraint *chartHeight;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UILabel *event;
@property (nonatomic, strong) UILabel *details;
@property (nonatomic, strong) UISegmentedControl *presentation;
@property (nonatomic, strong) UISegmentedControl *stacking;
@property (nonatomic, strong) UISegmentedControl *pointCounts;
@property (nonatomic, strong) UISegmentedControl *auditPreset;
@property (nonatomic, strong) UILabel *capture;
@property (nonatomic, strong) NSMutableArray *capturedTooltips;
@property (nonatomic, copy) NSString *auditIdentifier;
@property (nonatomic) NSInteger pointCount;
@property (nonatomic) NSInteger dataRevision;
@property (nonatomic) NSInteger probeGeneration;
@property (nonatomic) CGFloat renderedWidth;
@end

@implementation LCScenarioViewController
- (instancetype)initWithScenario:(LCScenario *)scenario {
    self = [super init];
    if (self) { _scenario = scenario; _pointCount = [scenario.identifier isEqualToString:@"dense"] ? 288 : 48; }
    return self;
}
- (UILabel *)label:(NSString *)text identifier:(NSString *)identifier {
    UILabel *label = [UILabel new]; label.text = text; label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:12]; label.textColor = UIColor.secondaryLabelColor;
    label.accessibilityIdentifier = identifier;
    return label;
}
- (UIButton *)button:(NSString *)title identifier:(NSString *)identifier action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    button.accessibilityIdentifier = identifier;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:32].active = YES;
    return button;
}
- (UIStackView *)row:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal; row.distribution = UIStackViewDistributionFillEqually; row.spacing = 8;
    return row;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = self.scenario.title;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"配置" style:UIBarButtonItemStylePlain target:self action:@selector(toggleConfiguration)];
    self.scrollView = [UIScrollView new]; self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    self.stack = [UIStackView new]; self.stack.axis = UILayoutConstraintAxisVertical; self.stack.spacing = 10;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO; [self.scrollView addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:12],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:12],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-12]
    ]];
    self.presentation = [[UISegmentedControl alloc] initWithItems:@[@"v1 JS", @"v1 原生", @"v2 JS", @"v2 原生"]];
    self.presentation.accessibilityIdentifier = @"presentation";
    [self.presentation addTarget:self action:@selector(changePresentation) forControlEvents:UIControlEventValueChanged];
    [self.stack addArrangedSubview:self.presentation];
    [self.stack addArrangedSubview:[self row:@[
        [self button:@"完整刷新 +125" identifier:@"reload" action:@selector(reloadData)],
        [self button:@"仅刷新数据" identifier:@"dataOnly" action:@selector(refreshDataOnly)],
        [self button:@"程序选点 12" identifier:@"selectPoint" action:@selector(selectPoint)],
        [self button:@"采样原生提示" identifier:@"captureTooltip" action:@selector(captureTooltip)]
    ]]];
    self.configuration = [UIStackView new]; self.configuration.axis = UILayoutConstraintAxisVertical; self.configuration.spacing = 8;
    self.configuration.hidden = YES;
    self.stacking = [[UISegmentedControl alloc] initWithItems:@[@"并排", @"普通堆叠", @"百分比"]];
    self.stacking.accessibilityIdentifier = @"stacking";
    [self.stacking addTarget:self action:@selector(changeStacking) forControlEvents:UIControlEventValueChanged];
    [self.configuration addArrangedSubview:self.stacking];
    self.pointCounts = [[UISegmentedControl alloc] initWithItems:@[@"48", @"288", @"1440", @"3000"]];
    self.pointCounts.accessibilityIdentifier = @"pointCounts";
    [self.pointCounts addTarget:self action:@selector(changePointCount) forControlEvents:UIControlEventValueChanged];
    [self.configuration addArrangedSubview:self.pointCounts];
    if ([self.scenario.identifier isEqualToString:@"signed"]) {
        self.auditPreset = [[UISegmentedControl alloc] initWithItems:@[@"柱", @"面积单组", @"面积多组", @"混合类型"]];
        self.auditPreset.accessibilityIdentifier = @"auditPreset"; self.auditPreset.selectedSegmentIndex = 0;
        [self.auditPreset addTarget:self action:@selector(changeAuditPreset) forControlEvents:UIControlEventValueChanged];
        [self.configuration addArrangedSubview:self.auditPreset];
        [self.configuration addArrangedSubview:[self row:@[
            [self button:@"跨零最小对照" identifier:@"auditCrossing" action:@selector(auditCrossing)],
            [self button:@"前层换链对照" identifier:@"auditSourceSwitch" action:@selector(auditSourceSwitch)]
        ]]];
    }
    [self.configuration addArrangedSubview:[self button:@"检查转换边界" identifier:@"auditInputs" action:@selector(auditInputs)]];
    [self.configuration addArrangedSubview:[self row:@[
        [self button:@"图例 开/关" identifier:@"toggleLegend" action:@selector(toggleLegend)],
        [self button:@"顺序反转" identifier:@"reverse" action:@selector(toggleReverse)],
        [self button:@"提示置顶" identifier:@"pinTooltip" action:@selector(togglePin)]
    ]]];
    [self.configuration addArrangedSubview:[self row:@[
        [self button:@"深浅色" identifier:@"theme" action:@selector(toggleTheme)],
        [self button:@"关闭提示" identifier:@"disableTooltip" action:@selector(toggleTooltip)],
        [self button:@"读取运行状态" identifier:@"inspect" action:@selector(inspect)]
    ]]];
    [self.stack addArrangedSubview:self.configuration];
    if ([self.scenario.identifier isEqualToString:@"empty"]) {
        [self.stack addArrangedSubview:[self row:@[
            [self button:@"恢复数据" identifier:@"restoreData" action:@selector(restoreData)],
            [self button:@"全零数据" identifier:@"zeroData" action:@selector(zeroData)],
            [self button:@"强制空态" identifier:@"forceEmpty" action:@selector(forceEmpty)]
        ]]];
    }
    self.status = [self label:@"等待旧图表渲染…" identifier:@"renderStatus"];
    self.event = [self label:@"最近事件：尚无" identifier:@"eventStatus"];
    [self.stack addArrangedSubview:self.status]; [self.stack addArrangedSubview:self.event];
    self.chartContainer = [UIView new]; self.chartContainer.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.chartContainer.layer.cornerRadius = 12; // Keep old tooltip/legend overflow visible for the audit.
    self.chartContainer.accessibilityIdentifier = @"chartContainer";
    self.chartHeight = [self.chartContainer.heightAnchor constraintEqualToConstant:430]; self.chartHeight.active = YES;
    [self.stack addArrangedSubview:self.chartContainer];
    [self.stack addArrangedSubview:[self label:self.scenario.instructions identifier:@"instructions"]];
    self.details = [self label:@"" identifier:@"runtimeDetails"]; self.details.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    [self.stack addArrangedSubview:self.details];
    self.capture = [self label:@"尚未采样" identifier:@"nativeTooltipCapture"];
    [self.stack addArrangedSubview:self.capture];
    [self rebuildModels];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // A nested scroll/stack layout can finish after the controller's layout callback.
    // Use the explicit horizontal budget from the host constraints for the frame-based old component.
    CGFloat width = self.view.bounds.size.width - 24;
    if (self.models.count && width > 0 && fabs(width - self.renderedWidth) > 0.5) { self.renderedWidth = width; [self renderRecreatingView:YES]; }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; self.probeGeneration++;
}
- (void)rebuildModels {
    self.models = self.auditIdentifier ? @[[self.scenario makeAuditModelWithIdentifier:self.auditIdentifier revision:self.dataRevision]] :
        [self.scenario makeModelsWithPointCount:self.pointCount revision:self.dataRevision];
    HMAAChartModel *model = self.models.firstObject;
    self.presentation.selectedSegmentIndex = (model.version == 2 ? 2 : 0) + (model.nativeTooltip ? 1 : 0);
    self.stacking.selectedSegmentIndex = model.stackType;
    self.pointCounts.selectedSegmentIndex = self.pointCount == 48 ? 0 : self.pointCount == 288 ? 1 : self.pointCount == 1440 ? 2 : 3;
    if (self.renderedWidth > 0) [self renderRecreatingView:YES];
}
- (void)renderRecreatingView:(BOOL)recreate {
    self.probeGeneration++;
    if (recreate || !self.legacyView) {
        [self.legacyView removeFromSuperview];
        if (self.scenario.multipleCharts) {
            HMMTAAChartView *multi = [HMMTAAChartView new]; multi.width = self.renderedWidth; multi.height = 280;
            multi.chartModels = self.models; multi.frame = CGRectMake(0, 0, multi.width, multi.height * self.models.count);
            self.legacyView = multi; [self.chartContainer addSubview:multi]; [multi initChartView];
        } else {
            HMLGAAChartView *chart = [HMAAChartUtil createlgaaChartView];
            chart.frame = CGRectMake(0, 0, self.renderedWidth, self.models.firstObject.chartHeight + 100);
            chart.delegate = self; chart.showEnlargeButton = YES;
            __weak typeof(self) weakSelf = self;
            chart.clickBlock = ^(NSInteger index) { weakSelf.event.text = [NSString stringWithFormat:@"最近事件：clickBlock index=%ld", (long)index]; };
            chart.legendTapBlock = ^(HMAASeriesElement *element) {
                weakSelf.event.text = [NSString stringWithFormat:@"最近事件：图例 %@ / %@", element.name, element.isHidden ? @"隐藏" : @"显示"];
                [weakSelf inspect];
            };
            self.legacyView = chart; [self.chartContainer addSubview:chart];
            [chart reloadDataWithModel:self.models.firstObject];
        }
    } else if ([self.legacyView isKindOfClass:HMLGAAChartView.class]) {
        [(HMLGAAChartView *)self.legacyView reloadDataWithModel:self.models.firstObject];
    } else { [self renderRecreatingView:YES]; return; }
    self.chartHeight.constant = MAX(CGRectGetMaxY(self.legacyView.frame), 330);
    self.status.text = @"等待旧图表渲染…";
    [self pollWithGeneration:self.probeGeneration attempts:30];
}
- (void)pollWithGeneration:(NSInteger)generation attempts:(NSInteger)attempts {
    if (generation != self.probeGeneration) return;
    __weak typeof(self) weakSelf = self;
    [LCChartProbe readChartsInView:self.legacyView completion:^(NSArray<NSDictionary *> *charts, NSString *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.probeGeneration) return;
        if (error.length && attempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf pollWithGeneration:generation attempts:attempts - 1]; });
            return;
        }
        if (error.length) { self.status.text = [@"渲染检查失败：" stringByAppendingString:error]; return; }
        NSDictionary *first = charts.firstObject;
        self.status.text = [NSString stringWithFormat:@"已渲染 · Highcharts %@ · %lu 张图 · %lu 系列 · %@ 点", first[@"version"], (unsigned long)charts.count, (unsigned long)[first[@"series"] count], first[@"categories"]];
        NSError *jsonError;
        NSMutableArray *observed = [NSMutableArray array];
        [charts enumerateObjectsUsingBlock:^(NSDictionary *chart, NSUInteger index, BOOL *stop) {
            NSMutableDictionary *entry = chart.mutableCopy;
            if (index < self.models.count) {
                entry[@"modelShowLegend"] = @(self.models[index].showLegend);
                entry[@"modelShowNoData"] = @(self.models[index].showNoData);
            }
            entry[@"nativeTooltips"] = [LCChartProbe visibleNativeTooltipsInView:self.legacyView];
            [observed addObject:entry];
        }];
        NSData *data = [NSJSONSerialization dataWithJSONObject:observed options:NSJSONWritingPrettyPrinted error:&jsonError];
        self.details.text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : jsonError.localizedDescription;
    }];
}
- (void)inspect { self.status.text = @"读取运行状态…"; self.probeGeneration++; [self pollWithGeneration:self.probeGeneration attempts:10]; }
- (void)toggleConfiguration { self.configuration.hidden = !self.configuration.hidden; }
- (void)changePresentation {
    NSInteger selected = self.presentation.selectedSegmentIndex;
    for (HMAAChartModel *model in self.models) { model.version = selected < 2 ? 1 : 2; model.nativeTooltip = selected % 2 == 1; }
    [self renderRecreatingView:YES];
}
- (void)changeStacking { for (HMAAChartModel *model in self.models) model.stackType = self.stacking.selectedSegmentIndex; [self renderRecreatingView:NO]; }
- (void)changePointCount {
    self.pointCount = [@[@48, @288, @1440, @3000][self.pointCounts.selectedSegmentIndex] integerValue];
    self.auditIdentifier = nil; self.auditPreset.selectedSegmentIndex = 0; [self rebuildModels];
}
- (void)changeAuditPreset {
    self.auditIdentifier = @[@"signed-column", @"area-single", @"area-multi", @"mixed-types"][self.auditPreset.selectedSegmentIndex];
    self.pointCount = 48; self.dataRevision = 0; [self rebuildModels];
}
- (void)auditCrossing { self.auditIdentifier = @"boundary-crossing"; self.dataRevision = 0; [self rebuildModels]; }
- (void)auditSourceSwitch { self.auditIdentifier = @"boundary-source-switch"; self.dataRevision = 0; [self rebuildModels]; }
- (void)toggleLegend { for (HMAAChartModel *model in self.models) model.showLegend = !model.showLegend; [self renderRecreatingView:NO]; }
- (void)toggleReverse { for (HMAAChartModel *model in self.models) model.reverse = !model.reverse; [self renderRecreatingView:NO]; }
- (void)togglePin { for (HMAAChartModel *model in self.models) model.tooltipPinToTop = !model.tooltipPinToTop; [self renderRecreatingView:NO]; }
- (void)toggleTooltip { for (HMAAChartModel *model in self.models) model.tooltipDisable = !model.tooltipDisable; [self renderRecreatingView:YES]; }
- (void)toggleTheme { self.navigationController.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark; [self inspect]; }
- (void)reloadData {
    self.dataRevision++;
    NSArray *updated = self.auditIdentifier ? @[[self.scenario makeAuditModelWithIdentifier:self.auditIdentifier revision:self.dataRevision]] :
        [self.scenario makeModelsWithPointCount:self.pointCount revision:self.dataRevision];
    [self copyUpdatedData:updated]; [self renderRecreatingView:NO];
    self.event.text = [NSString stringWithFormat:@"最近事件：完整刷新，数据版本 %ld", (long)self.dataRevision];
}
- (void)copyUpdatedData:(NSArray<HMAAChartModel *> *)updated {
    for (NSInteger m = 0; m < MIN(self.models.count, updated.count); m++) {
        HMAAChartModel *current = self.models[m], *next = updated[m];
        for (NSInteger g = 0; g < MIN(current.seriesArray.count, next.seriesArray.count); g++) {
            for (NSInteger e = 0; e < MIN(current.seriesArray[g].element.count, next.seriesArray[g].element.count); e++) {
                current.seriesArray[g].element[e].data = next.seriesArray[g].element[e].data;
            }
        }
    }
}
- (void)refreshDataOnly {
    self.dataRevision++;
    [self copyUpdatedData:self.auditIdentifier ? @[[self.scenario makeAuditModelWithIdentifier:self.auditIdentifier revision:self.dataRevision]] :
        [self.scenario makeModelsWithPointCount:self.pointCount revision:self.dataRevision]];
    if ([self.legacyView isKindOfClass:HMLGAAChartView.class]) [(HMLGAAChartView *)self.legacyView onlyRefreshTheChartData];
    else { self.event.text = @"HMMT 没有公开仅刷新入口"; return; }
    self.event.text = [NSString stringWithFormat:@"最近事件：仅刷新数据，输入版本 %ld（检查运行值）", (long)self.dataRevision]; [self inspect];
}
- (void)selectPoint {
    if ([self.legacyView isKindOfClass:HMLGAAChartView.class]) [(HMLGAAChartView *)self.legacyView setTouchPointXIndex:12];
    else { self.event.text = @"HMMT 使用触摸驱动内部联动"; return; }
    self.event.text = @"最近操作：setTouchPointXIndex(12)；观察原生提示是否同步"; [self inspect];
}
- (void)restoreData {
    LCScenario *power = LCScenario.catalog.firstObject;
    HMAAChartModel *model = [power makeModelsWithPointCount:self.pointCount revision:self.dataRevision].firstObject;
    model.name = @"无数据恢复"; model.headerDatas = nil; model.sunDatas = nil; model.chartHeight = 330;
    self.models = @[model]; [self renderRecreatingView:YES];
}
- (void)zeroData {
    [self restoreData];
    NSMutableArray *zero = [NSMutableArray array]; for (NSInteger i = 0; i < self.pointCount; i++) [zero addObject:@0];
    for (HMAASeries *group in self.models.firstObject.seriesArray) for (HMAASeriesElement *element in group.element) element.data = zero;
    [self renderRecreatingView:NO];
}
- (void)forceEmpty { for (HMAAChartModel *model in self.models) model.showNoData = !model.showNoData; [self renderRecreatingView:NO]; }
- (void)auditInputs {
    NSData *data = [NSJSONSerialization dataWithJSONObject:[LCChartProbe inputBoundaryDiagnostics] options:NSJSONWritingPrettyPrinted error:nil];
    self.capture.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
- (void)captureTooltip {
    self.capture.text = @"采样中"; self.capturedTooltips = [NSMutableArray array];
    [self sampleNativeTooltipWithGeneration:self.probeGeneration remaining:60];
}
- (void)sampleNativeTooltipWithGeneration:(NSInteger)generation remaining:(NSInteger)remaining {
    if (generation != self.probeGeneration) { self.capture.text = @"采样因视图变更取消"; return; }
    NSArray *current = [LCChartProbe visibleNativeTooltipsInView:self.legacyView];
    if (current.count && ![current isEqual:self.capturedTooltips.lastObject]) [self.capturedTooltips addObject:current];
    if (remaining == 0) {
        NSDictionary *result = @{@"complete":@YES, @"frames":self.capturedTooltips, @"after":current};
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
        self.capture.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf sampleNativeTooltipWithGeneration:generation remaining:remaining - 1];
    });
}
- (void)hmlgaaChartView:(HMLGAAChartView *)chartView handlePan:(UIPanGestureRecognizer *)gesture {
    // Old wrapper deliberately delegates vertical movement to its host.
    if (gesture.state != UIGestureRecognizerStateChanged) return;
    CGPoint translation = [gesture translationInView:self.scrollView];
    CGFloat maximum = MAX(-self.scrollView.adjustedContentInset.top, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.scrollView.adjustedContentInset.bottom);
    CGFloat y = MIN(maximum, MAX(-self.scrollView.adjustedContentInset.top, self.scrollView.contentOffset.y - translation.y));
    self.scrollView.contentOffset = CGPointMake(0, y); [gesture setTranslation:CGPointZero inView:self.scrollView];
}
@end
