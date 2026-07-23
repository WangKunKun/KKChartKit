#import "OCChartDemoViewController.h"
#import "SwiftFunctionProject-Swift.h"

// 前向声明：文件级 C 工具函数（定义在文件末尾）
HYMHeatmapCellBridge *hmCell(double v);

@interface OCChartDemoViewController ()
@property (nonatomic, strong) HYMRadarChartViewBridge *radarBridge;
@property (nonatomic, strong) HYMHeatmapChartViewBridge *heatmapBridge;
@property (nonatomic, assign) BOOL themeToggleOn;
@end

@implementation OCChartDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"OC demo";
    [self setupRadar];
    [self setupHeatmap];
    [self setupThemeToggle];
}

#pragma mark - 蛛网图（雷达图）

- (void)setupRadar {
    HYMRadarThemeBuilder *theme = [HYMRadarThemeBuilder new];
    theme.showsLabelDots = YES;
    theme.showsDecorativeRing = YES;
    theme.showsVertexDots = NO;
    theme.showsBackground = NO;
    theme.showsGridLines = NO;
    theme.gridRingFill = @"gradient";
    UIColor * color = [[UIColor colorNamed:@"Green"] colorWithAlphaComponent:0.06];
    theme.gridRingColors = @[color,color,color,color,color,color];
    theme.decorativeRingFillColor = [[UIColor colorNamed:@"Green"] colorWithAlphaComponent:0.08];
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

    // Swift 默认参数对 OC 不可见 → 显式传全参数。
    // 维度标签用 4 字，便于 toggleRadarTheme 开启换行时观察左右标签换行。
    // per-dim 演示：防守能力(右)显式隐藏标题点 @NO，其余 nil=沿用全局 showsLabelDots
    NSArray<HYMRadarDimensionBridge *> *dims = @[
        [self dimWithLabel:@"进攻能力" value:80],
        [self dimWithLabel:@"防守能力" value:60 showsLabelDot:@NO],
        [self dimWithLabel:@"速度能力" value:90],
        [self dimWithLabel:@"技巧能力" value:50],
        [self dimWithLabel:@"体力能力" value:70],
        [self dimWithLabel:@"意识能力" value:85],
    ];
    [self.radarBridge configureWithDimensions:dims showsCenterScore:YES centerScore:nil];
    [self.radarBridge playEntranceAnimation];
}

- (HYMRadarDimensionBridge *)dimWithLabel:(NSString *)label value:(double)value {
    return [self dimWithLabel:label value:value showsLabelDot:nil];
}

- (HYMRadarDimensionBridge *)dimWithLabel:(NSString *)label value:(double)value showsLabelDot:(NSNumber *)showsLabelDot {
    return [[HYMRadarDimensionBridge alloc] initWithLabel:label value:value maxValue:100
                                               labelColor:nil labelFont:nil
                                             dataDotColor:nil labelDotColor:nil
                                             showsLabelDot:showsLabelDot];
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

#pragma mark - 主题切换（验证 applyTheme 重新渲染）

- (void)setupThemeToggle {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"切换雷达图主题（applyTheme）" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(toggleRadarTheme) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    [NSLayoutConstraint activateConstraints:@[
        [btn.topAnchor constraintEqualToAnchor:self.heatmapBridge.chartView.bottomAnchor constant:24],
        [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
}

/// 切换雷达图主题：主题 A（默认紫色、不换行）↔ 主题 B（红色、左右标签换行）。
/// 验证 OC 改 theme 后调 applyTheme 触发重新渲染。
- (void)toggleRadarTheme {
    self.themeToggleOn = !self.themeToggleOn;
    HYMRadarThemeBuilder *t = [HYMRadarThemeBuilder new];
    t.showsLabelDots = YES;
    t.showsDecorativeRing = YES;
    if (self.themeToggleOn) {
        // 主题 B：红色 + 左右标签换行（labelMaxLineLength=60）
        t.dataStrokeColor = UIColor.redColor;
        t.dataFillColor = [UIColor colorWithRed:1 green:0.8 blue:0.8 alpha:0.4];
        t.vertexDotColor = UIColor.redColor;
        t.labelMaxLineLength = 60;
    }
    // else 主题 A：默认紫色，不换行
    [self.radarBridge applyTheme:t];
    NSLog(@"[OC] applyTheme 切换 → themeToggleOn=%d", self.themeToggleOn);
}

@end

/// 文件级 C 函数：快速造热力图格子（值 / 满值100 / 无覆盖色）。
HYMHeatmapCellBridge *hmCell(double v) {
    return [[HYMHeatmapCellBridge alloc] initWithValue:v maxValue:100 color:nil];
}
