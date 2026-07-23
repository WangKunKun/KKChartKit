#import "OCChartDemoViewController.h"
#import "SwiftFunctionProject-Swift.h"

// 前向声明：文件级 C 工具函数（定义在文件末尾）
HYMHeatmapCellBridge *hmCell(double v);

@interface OCChartDemoViewController ()
@property (nonatomic, strong) HYMRadarChartViewBridge *radarBridge;
@property (nonatomic, strong) HYMHeatmapChartViewBridge *heatmapBridge;
@end

@implementation OCChartDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
    self.title = @"OC demo";
    [self setupRadar];
    [self setupHeatmap];
}

#pragma mark - 蛛网图（雷达图）

- (void)setupRadar {
    HYMRadarThemeBuilder *theme = [HYMRadarThemeBuilder new];
    theme.showsLabelDots = YES;
    theme.showsDecorativeRing = YES;

    // 强引用持有 bridge，否则出作用域释放 → chartView 失效、onHit 不触发
    self.radarBridge = [[HYMRadarChartViewBridge alloc] initWithTheme:theme frame:CGRectZero];
    UIView *chart = self.radarBridge.chartView;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [chart.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [chart.widthAnchor constraintEqualToConstant:300],
        [chart.heightAnchor constraintEqualToConstant:300],
    ]];

    // kind = "dataVertex" / "labelVertex"，index = 维度序号
    self.radarBridge.onHit = ^(NSString *kind, NSInteger index) {
        NSLog(@"[OC] 蛛网图命中 kind=%@ dim=%ld", kind, (long)index);
    };

    // Swift 默认参数对 OC 不可见 → 显式传全参数
    NSArray<HYMRadarDimensionBridge *> *dims = @[
        [self dimWithLabel:@"进攻" value:80],
        [self dimWithLabel:@"防守" value:60],
        [self dimWithLabel:@"速度" value:90],
        [self dimWithLabel:@"技巧" value:50],
        [self dimWithLabel:@"体力" value:70],
        [self dimWithLabel:@"意识" value:85],
    ];
    [self.radarBridge configureWithDimensions:dims showsCenterScore:YES centerScore:nil];
    [self.radarBridge playEntranceAnimation];
}

- (HYMRadarDimensionBridge *)dimWithLabel:(NSString *)label value:(double)value {
    return [[HYMRadarDimensionBridge alloc] initWithLabel:label value:value maxValue:100
                                               labelColor:nil labelFont:nil
                                             dataDotColor:nil labelDotColor:nil];
}

#pragma mark - 热力图

- (void)setupHeatmap {
    HYMHeatmapThemeBuilder *theme = [HYMHeatmapThemeBuilder new];
    theme.colorScaleType = @"alpha";                 // 单色 + 透明度按 value/max
    theme.colorScaleColors = @[UIColor.greenColor];
    theme.showsRowLabels = NO;                        // 隐藏左侧（不占空间）
    theme.showsColumnLabels = NO;                     // 隐藏顶部
    theme.rowSpacing = 0;
    theme.columnSpacing = 0;
    theme.cellCornerRadius = 0;
    theme.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1]; // value=0 透出底色

    self.heatmapBridge = [[HYMHeatmapChartViewBridge alloc] initWithTheme:theme frame:CGRectZero];
    UIView *chart = self.heatmapBridge.chartView;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.radarBridge.chartView.bottomAnchor constant:24],
        [chart.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [chart.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [chart.heightAnchor constraintEqualToConstant:180],
    ]];

    self.heatmapBridge.onHit = ^(NSInteger row, NSInteger column) {
        NSLog(@"[OC] 热力图命中 (%ld,%ld)", (long)row, (long)column);
    };

    NSArray<NSArray<HYMHeatmapCellBridge *> *> *rows = @[
        @[hmCell(12),hmCell(34),hmCell(56),hmCell(78),hmCell(90),hmCell(45),hmCell(23)],
        @[hmCell(67),hmCell(89),hmCell(12),hmCell(34),hmCell(56),hmCell(78),hmCell(90)],
        @[hmCell(45),hmCell(23),hmCell(67),hmCell(89),hmCell(12),hmCell(34),hmCell(56)],
        @[hmCell(78),hmCell(90),hmCell(45),hmCell(23),hmCell(67),hmCell(89),hmCell(12)],
        @[hmCell(34),hmCell(56),hmCell(78),hmCell(90),hmCell(45),hmCell(23),hmCell(67)],
    ];
    [self.heatmapBridge configureWithRows:rows rowLabels:nil columnLabels:nil];
    [self.heatmapBridge playEntranceAnimation];
}

@end

/// 文件级 C 函数：快速造热力图格子（值 / 满值100 / 无覆盖色）。
HYMHeatmapCellBridge *hmCell(double v) {
    return [[HYMHeatmapCellBridge alloc] initWithValue:v maxValue:100 color:nil];
}
