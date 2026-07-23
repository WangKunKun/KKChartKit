# HYMCharts · Objective-C 使用指南

> 日期：2026-07-23
> 适用：在 OC 项目里创建「蛛网图（雷达图）」与「热力图」的 `UIView` 并嵌入界面。

HYMCharts 内核是纯 Swift，所有 OC 入口都封装成 `@objcMembers` 的 `NSObject` 桥接类（`HYMRadar*Bridge` / `HYMHeatmap*Bridge`）。OC 端不碰 Swift 特性（struct/泛型/Result），只调 NSObject + block。

## 0. 前置：导入 Swift 模块

OC 文件顶部 import Swift 生成头：

```objc
// 同一 app target 内（本仓 demo 即此情形）：
#import "SwiftFunctionProject-Swift.h"

// 若作为独立 framework 集成（模块名 = framework 名）：
// @import YourSDKName;   // 或 #import <YourSDKName/YourSDKName-Swift.h>
```

## 1. 三个通用要点（先读，避免踩坑）

1. **桥接对象必须用属性强引用**。`HYMRadarChartViewBridge` / `HYMHeatmapChartViewBridge` 持有内部容器，**出作用域被释放后 `chartView` 失效、`onHit` 不触发**。务必：
   ```objc
   @property (nonatomic, strong) HYMRadarChartViewBridge *radarBridge;
   @property (nonatomic, strong) HYMHeatmapChartViewBridge *heatmapBridge;
   ```
2. **Swift 默认参数对 OC 不可见**。OC 调 init 时要**显式传全参数**（下文代码已写全）。
3. **`onHit` block 注意循环引用**。bridge 持有 block，self 又持有 bridge → 用 `__weak`。

## 2. 蛛网图（雷达图）

### 2.1 完整可拷贝代码

```objc
#import "SwiftFunctionProject-Swift.h"

@interface MyViewController : UIViewController
@property (nonatomic, strong) HYMRadarChartViewBridge *radarBridge;
@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupRadarChart];
}

- (void)setupRadarChart {
    // 1) 主题（属性赋值；nil 字段用主题默认）
    HYMRadarThemeBuilder *theme = [HYMRadarThemeBuilder new];
    theme.showsLabelDots = YES;          // 显示标题顶点圆点（才能点 labelVertex）
    theme.showsDecorativeRing = YES;     // 装饰 ring
    // 想自定义可继续：
    // theme.dataStrokeColor = [UIColor colorWithRed:0.66 green:0.55 blue:0.98 alpha:1];
    // theme.selectionColor = [UIColor yellowColor];   // 选中变色
    // theme.selectionScale = 1.8;                      // 选中放大倍数

    // 2) 创建桥接（frame 仅占位，实际用约束）
    self.radarBridge = [[HYMRadarChartViewBridge alloc] initWithTheme:theme
                                                                 frame:self.view.bounds];

    // 3) 拿 UIView 嵌入
    UIView *chart = self.radarBridge.chartView;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:120],
        [chart.widthAnchor constraintEqualToConstant:320],
        [chart.heightAnchor constraintEqualToConstant:320],
        [chart.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    // 4) 命中回调：kind = "dataVertex" / "labelVertex"，index = 维度序号
    __weak typeof(self) ws = self;
    self.radarBridge.onHit = ^(NSString *kind, NSInteger index) {
        NSLog(@"蛛网图命中 kind=%@ 维度=%ld", kind, (long)index);
    };

    // 5) 维度数据（OC 须传全参数；nil 表示沿用主题）
    NSArray<HYMRadarDimensionBridge *> *dims = @[
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"进攻" value:80 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"防守" value:60 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"速度" value:90 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"技巧" value:50 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"体力" value:70 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
        [[HYMRadarDimensionBridge alloc] initWithLabel:@"意识" value:85 maxValue:100
                                             labelColor:nil labelFont:nil
                                           dataDotColor:nil labelDotColor:nil],
    ];
    [self.radarBridge configureWithDimensions:dims
                              showsCenterScore:YES
                                    centerScore:nil];   // nil = 自动按各维均值

    // 6) 入场动画
    [self.radarBridge playEntranceAnimation];
}

@end
```

### 2.2 要点

- `chartView` 是普通 `UIView`，frame / Auto Layout / `addSubview` 都照常。
- 点击数据顶点 → `kind="dataVertex"`；点击最外圈标题圆点 → `kind="labelVertex"`（需 `showsLabelDots=YES`）。
- 选中态（放大+描边+变色）由 `RadarChartTheme` 的 5 个 `selection*` 字段控制，默认组合，可在 ThemeBuilder 调。

## 3. 热力图

### 3.1 完整可拷贝代码

```objc
#import "SwiftFunctionProject-Swift.h"

@interface MyViewController : UIViewController
@property (nonatomic, strong) HYMHeatmapChartViewBridge *heatmapBridge;
@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupHeatmap];
}

- (void)setupHeatmap {
    // 1) 主题：.alpha 单色 + 透明度按 value/max（值越大越实色）
    HYMHeatmapThemeBuilder *theme = [HYMHeatmapThemeBuilder new];
    theme.colorScaleType = @"alpha";
    theme.colorScaleColors = @[ UIColor.greenColor ];   // colorScaleColors[0] 作单色
    theme.showsRowLabels = NO;          // 隐藏左侧（不占空间）
    theme.showsColumnLabels = NO;       // 隐藏顶部（不占空间）
    theme.rowSpacing = 0;               // 行紧贴
    theme.columnSpacing = 0;            // 列紧贴
    theme.cellCornerRadius = 0;
    theme.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1]; // value=0 透出的底色

    // 2) 桥接
    self.heatmapBridge = [[HYMHeatmapChartViewBridge alloc] initWithTheme:theme
                                                                     frame:self.view.bounds];

    // 3) 嵌入 UIView
    UIView *chart = self.heatmapBridge.chartView;
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:chart];
    [NSLayoutConstraint activateConstraints:@[
        [chart.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:120],
        [chart.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [chart.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [chart.heightAnchor constraintEqualToConstant:220],
    ]];

    // 4) 命中回调：(row, column)
    self.heatmapBridge.onHit = ^(NSInteger row, NSInteger column) {
        NSLog(@"热力图命中 (%ld, %ld)", (long)row, (long)column);
    };

    // 5) 数据：5 行 × 7 列（OC 须传全参数；maxValue 默认 100，color=nil 走色阶）
    NSArray<NSArray<HYMHeatmapCellBridge *> *> *rows = @[
        @[cell(0),cell(34),cell(56),cell(78),cell(90),cell(45),cell(23)],
        @[cell(67),cell(89),cell(12),cell(34),cell(56),cell(78),cell(90)],
        @[cell(45),cell(23),cell(67),cell(89),cell(12),cell(34),cell(56)],
        @[cell(78),cell(90),cell(45),cell(23),cell(67),cell(89),cell(12)],
        @[cell(34),cell(56),cell(78),cell(90),cell(45),cell(23),cell(67)],
    ];
    NSArray<NSString *> *rowLabels = @[@"W1",@"W2",@"W3",@"W4",@"W5"];
    NSArray<NSString *> *colLabels = @[@"一",@"二",@"三",@"四",@"五",@"六",@"日"];
    [self.heatmapBridge configureWithRows:rows rowLabels:rowLabels columnLabels:colLabels];

    // 6) 入场动画
    [self.heatmapBridge playEntranceAnimation];
}

/// 小工具：快速造格子（值 / 满值100 / 无覆盖色）
HYMHeatmapCellBridge *cell(double v) {
    return [[HYMHeatmapCellBridge alloc] initWithValue:v maxValue:100 color:nil];
}

@end
```

> C 函数 `cell()` 为示意；正式代码可写 OC 方法或宏。`color=nil` 表示走色阶（`.alpha` 下按 value/max 算透明度）。

### 3.2 色阶四种模式（`colorScaleType`）

| colorScaleType | colorScaleColors | 说明 |
|----------------|------------------|------|
| `"alpha"` | `[c0]` | 单色 c0，`alpha = value/max`（值越大越实色；value=0 全透明） |
| `"gradient"` | `[low, high]` | 两点线性插值 |
| `"stops"` | `[c0, c1, ...]` + `colorScaleValues` | 多段插值（锚点 value 升序，colors/values 等长） |
| `"none"` | — | 不映射，每格自带 `color`；无则用 `emptyColor` |

> `.alpha` 下要严格 `value/max`：保证值域下界为 0（数据含 0，或 model 端设 `valueRange = 0...max`）。

## 4. 通用属性速查

### HYMRadarThemeBuilder（节选）
`showsData` / `showsGridLines` / `showsAxes` / `showsBackground` / `showsVertexDots` / `showsLabelDots` / `showsOuterRing` / `showsDecorativeRing`；颜色 `dataFillColor` / `dataStrokeColor` / `vertexDotColor` / `labelColor` / `scoreColor`；选中 `selectionScale` / `selectionStrokeColor` / `selectionStrokeWidth` / `selectionColor` / `selectionHitPadding`。

### HYMHeatmapThemeBuilder（节选）
`colorScaleType` / `colorScaleColors` / `colorScaleValues`；`cellCornerRadius` / `rowSpacing` / `columnSpacing` / `contentInset`；`showsRowLabels` / `showsColumnLabels` / `labelGap` / `labelColor` / `labelFont`；`backgroundColor` / `showsEntranceAnimation`；选中 `selectionBorderColor` / `selectionBorderWidth` / `selectionBorderCornerRadius`。

## 5. 常见问题

- **看不到图 / onHit 不触发** → 99% 是 bridge 没强引用（出作用域释放）。加 `@property strong`。
- **OC init 报参数不全** → Swift 默认参数对 OC 不可见，按上文传全参数。
- **热力图 value=0 格子看不见** → `.alpha` 下 alpha=0 全透明；设 `theme.backgroundColor` 给底色，或换 `.gradient`。
- **编译报找不到类型** → OC 文件没 import `"<Module>-Swift.h"`。
