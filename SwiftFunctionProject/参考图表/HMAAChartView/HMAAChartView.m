//
//  HMAAChartView.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2024/12/11.
//  Copyright © 2024 hemaiInstall. All rights reserved.
//

#import "HMAAChartView.h"
#import "HMAASeries.h"
#import "HMAAChartModel.h"
#import "AAChartKit.h"
#import "HMTooltipTool.h"
#import "HMAAChartManager.h"
#import "HMChartTitleView.h"
#import "HMChartHeaderView.h"
#import "HMChartSunView.h"
#import "HMChartCrosshairView.h"
#import "HMChartTool.h"

@interface HMAAChartView () <AAChartViewEventDelegate>

@property (nonatomic, strong) UIStackView *stackView;//背景stack

@property (nonatomic, strong) AAChartView *chartView;
@property (nonatomic, strong) AAOptions *options;
@property (nonatomic, assign) NSInteger index;

@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
//@property (nonatomic, assign) NSTimeInterval idleThreshold;// 定义手指被认为停止滑动的时间阈值
//@property (nonatomic, strong) NSTimer *idleTimer;// 用于检测手指是否停止移动的计时器

@property (nonatomic, strong) HMAAChartManager *chartManager;//处理图表数据相关

@property (nonatomic, strong) HMAAChartModel *chartModel;
@property (nonatomic, strong) UIStackView *noDataStack;
@property (nonatomic, strong) UIImageView *noDataImgView;
@property (nonatomic, strong) UILabel *noDataLabel;
@property (nonatomic, strong) NSArray<HMAASeries *> *seriesArray;// 最终数据-去掉图例隐藏数据

@property (nonatomic, assign) BOOL isAllPos; // 判断是否只有正值

@property (nonatomic, strong) HMChartTitleView *titleView;//标题
@property (nonatomic, strong) HMChartHeaderView *headerView;//表头
@property (nonatomic, strong) HMChartSunView *sunView;//附加行

@property (nonatomic, strong) HMTooltipTool *tooltipTool;//弹窗工具
@property (nonatomic, strong) HMTooltip *natooltip;//原生弹窗
@property (nonatomic, strong) HMIconTooltip *ictooltip;//ver2弹窗
@property (nonatomic, strong) NSLayoutConstraint *centerXConstraint;
// 配合原生弹窗使用
@property (nonatomic, strong) HMChartCrosshairView *crosshairView;//准星线
@property (nonatomic, strong) UILongPressGestureRecognizer *lPressGesture;//长按手势
@property (nonatomic, assign) BOOL touched;//存在选中的坐标信息
@property (nonatomic, copy, nullable) dispatch_block_t timerBlock;

@end

@implementation HMAAChartView

- (void)dealloc {
    if (self.natooltip) {
        [self.natooltip removeFromSuperview];
        self.natooltip = nil;
    }
    if (self.ictooltip) {
        [self.ictooltip removeFromSuperview];
        self.ictooltip = nil;
    }
    if (self.timerBlock) {
        dispatch_block_cancel(self.timerBlock);
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configChartView];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configChartView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self configChartView];
    }
    return self;
}

- (void)configChartView {
    [self addSubview:self.stackView];//用stackview布局
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    [self.stackView addArrangedSubview:self.chartView];

    [self initializeNoData];
    
    // 设置手指被认为停止滑动的时间阈值，例如0.5秒
//    _idleThreshold = 0.1;
    
    // 创建并添加平移手势识别器
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:_panGesture];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    if (fabs(translation.y) > fabs(translation.x)) {
        // 上下滑动，传递事件给外部
        if ([self.delegate respondsToSelector:@selector(hmaaChartView:handlePan:)]) {
            [self.delegate hmaaChartView:self handlePan:gesture];
        }
    }
    
    if (self.clickBlock) {
        self.clickBlock(_index);
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // 滑动结束 抬起手指
//        if (self.clickBlock) {
//            self.clickBlock(_index);
//        }
    }
    
    CGPoint velocity = [gesture velocityInView:self];
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        // 当手势状态为改变中，检查速度
        CGFloat speed = hypotf(velocity.x, velocity.y);
        
        if (speed < 30.0) { // 10.0 是一个示例阈值，可以根据需求调整
            // 如果速度足够低，启动或重置计时器
//            if (_idleTimer) {
//                [_idleTimer invalidate];
//            }
//            _idleTimer = [NSTimer scheduledTimerWithTimeInterval:_idleThreshold
//                                                          target:self
//                                                        selector:@selector(fingerStoppedSliding)
//                                                        userInfo:nil
//                                                         repeats:NO];
        } else {
            // 手指还在快速移动，取消计时器
//            if (_idleTimer) {
//                [_idleTimer invalidate];
//                _idleTimer = nil;
//            }
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        // 手势结束或被取消，取消计时器
//        if (_idleTimer) {
//            [_idleTimer invalidate];
//            _idleTimer = nil;
//        }
    }
}

//- (void)fingerStoppedSliding {
//    // 计时器触发，表示手指停止滑动但未离开屏幕
//    if (self.clickBlock) {
//        self.clickBlock(_index);
//    }
//    
//    // 记得在操作完成后重置计时器
//    _idleTimer = nil;
//}

- (void)initializeNoData {
    self.nodColor = [UIColor grayColor];
    self.nodFont = [UIFont systemFontOfSize:14];
    
    [self addSubview:self.noDataStack];
    [self.noDataStack addArrangedSubview:self.noDataImgView];
    [self.noDataStack addArrangedSubview:self.noDataLabel];
    
    // 栈视图关闭自动约束（必须！否则手动约束无效）
    self.noDataStack.translatesAutoresizingMaskIntoConstraints = NO;
    // 图片视图关闭自动约束（设置高度约束前必须关闭）
    self.noDataImgView.translatesAutoresizingMaskIntoConstraints = NO;
    // 标签视图也建议关闭（避免后续布局冲突）
    self.noDataLabel.translatesAutoresizingMaskIntoConstraints = NO;
    // 设置图片高度约束
    NSLayoutConstraint *imageHeight = [NSLayoutConstraint constraintWithItem:self.noDataImgView
                                                                   attribute:NSLayoutAttributeHeight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:nil
                                                                   attribute:NSLayoutAttributeNotAnAttribute
                                                                  multiplier:1.0
                                                                    constant:80];
    [self.noDataImgView addConstraint:imageHeight];
    // 栈视图基于父视图居中（水平+垂直）
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.noDataStack
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1.0
                                                                constant:0];
    // 栈视图左右距离父视图12
    NSLayoutConstraint *leading = [NSLayoutConstraint constraintWithItem:self.noDataStack
                                                                attribute:NSLayoutAttributeLeading
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self
                                                                attribute:NSLayoutAttributeLeading
                                                               multiplier:1.0
                                                                 constant:12];

    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:self.noDataStack
                                                                 attribute:NSLayoutAttributeTrailing
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self
                                                                 attribute:NSLayoutAttributeTrailing
                                                                multiplier:1.0
                                                                  constant:-12];
    // 激活所有约束
    [NSLayoutConstraint activateConstraints:@[centerY, leading, trailing]];
//    [self addSubview:self.noDataImgView];
//    [self addSubview:self.noDataLabel];
    
//    self.nodImgName = @"list.bullet.clipboard";
//    self.nodText = @"暂无数据";
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        if (!_chartModel.closeDarkStyle) {
            [self userInterfaceStyleChange];
            [self reloadDataWithModel:_chartModel];
        }
    }
}

// 判断暗黑模式修改图表配置
- (void)userInterfaceStyleChange {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        _chartModel.titleColor = _chartModel.titleColorArr.lastObject;
        _chartModel.crosshairColor = _chartModel.crosshairColorArr.lastObject;
        _chartModel.dashColor = _chartModel.dashColorArr.lastObject;
        _chartModel.xAxisTextColor = _chartModel.xAxisTextColorArr.lastObject;
        _chartModel.yAxisTextColor = _chartModel.yAxisTextColorArr.lastObject;
        _chartModel.toolTipBackgroundColor = _chartModel.toolTipBackgroundColorArr.lastObject;
        _chartModel.toolTipTextColor = _chartModel.toolTipTextColorArr.lastObject;
    } else {
        _chartModel.titleColor = _chartModel.titleColorArr.firstObject;
        _chartModel.crosshairColor = _chartModel.crosshairColorArr.firstObject;
        _chartModel.dashColor = _chartModel.dashColorArr.firstObject;
        _chartModel.xAxisTextColor = _chartModel.xAxisTextColorArr.firstObject;
        _chartModel.yAxisTextColor = _chartModel.yAxisTextColorArr.firstObject;
        _chartModel.toolTipBackgroundColor = _chartModel.toolTipBackgroundColorArr.firstObject;
        _chartModel.toolTipTextColor = _chartModel.toolTipTextColorArr.firstObject;
    }
}

#pragma mark - custom
- (void)showNoData:(BOOL)show {
    _chartView.hidden = show;
    self.noDataStack.hidden = !show;
    self.headerView.hidden = !show;
    if (self.nodImgName.length == 0) {
        self.noDataImgView.hidden = YES;
    }
    if (self.nodText.length == 0) {
        self.noDataLabel.hidden = YES;
    }
    if (_chartModel.version == 2 && _chartModel.name.length > 0) {
        self.titleView.hidden = show;
    }
    if (_chartModel.headerDatas.count > 0) {
        self.headerView.hidden = show;
    }
    if (_chartModel.sunDatas.count > 0) {
        self.sunView.hidden = show;
    }
//    self.noDataImgView.hidden = !show;
//    self.noDataLabel.hidden = !show;
    
//    CGSize lbSize = [self.noDataLabel sizeThatFits:CGSizeMake(self.frame.size.width, MAXFLOAT)];
//    CGFloat topH = (self.frame.size.height - 80 - 16 - lbSize.height) / 2;
//
//    self.noDataImgView.frame = CGRectMake(self.frame.size.width/2 - 34, topH, 68, 80);
//    self.noDataLabel.frame = CGRectMake((self.frame.size.width - lbSize.width)/2, topH + 80 + 16, lbSize.width, lbSize.height);
}

- (void)initChartViewWithModel:(HMAAChartModel *)model {
    [self dealWithModel:model];
    [_chartView aa_drawChartWithOptions:_options];
}

- (void)reloadDataWithModel:(HMAAChartModel *)model {
    [self dealWithModel:model];
    [_chartView aa_drawChartWithOptions:_options];
    [_chartView aa_refreshChartWithOptions:_options];
}

- (void)onlyRefreshTheChartData {
    [_chartView aa_onlyRefreshTheChartDataWithOptionsSeries:self.chartManager.series animation:NO];
}

- (void)dealWithModel:(HMAAChartModel *)model {
    _chartModel = model;
    if (self.nodImgName) {
        _noDataImgView.image = [UIImage imageNamed:self.nodImgName];
    }
    if (self.nodText) {
        _noDataLabel.font = self.nodFont;
        _noDataLabel.textColor = self.nodColor;
        _noDataLabel.text = self.nodText;
    }
    [self userInterfaceStyleChange];
    
    // 判断外部是否传递数据
    [self showNoData:model.seriesArray.count == 0];

    // 重构数据序列-去除图例隐藏序列
    self.seriesArray = model.showSeriesArray;
    
    // 赋值弹窗
    self.tooltipTool.chartModel = model;
    
    self.chartManager = [[HMAAChartManager alloc] initWithChartModel:model];
    
    _options = [self.chartManager configureAAChartOptions];
    
    NSInteger index = 0;
    
    // 存在标题
    if (_chartModel.version == 2 && _chartModel.name.length > 0) {
        self.titleView.name = _chartModel.name;
        self.titleView.unit = _chartModel.unit;
        [self.stackView insertArrangedSubview:self.titleView atIndex:index];
        [NSLayoutConstraint activateConstraints:@[
            [self.titleView.heightAnchor constraintEqualToConstant:44]
        ]];
        
        index += 1;
    } else {
        [self.titleView removeFromSuperview];
    }
    
    // 存在表头数据
    if (_chartModel.headerDatas.count > 0) {
        self.headerView.headerDatas = _chartModel.headerDatas;
        [self.stackView insertArrangedSubview:self.headerView atIndex:index];
        [NSLayoutConstraint activateConstraints:@[
            [self.headerView.heightAnchor constraintEqualToConstant:62]
        ]];
        
        [self.headerView reloadData];
        
        if (index == 1) {
            [self.titleView showLine:YES];
        }
    } else {
        [self.headerView removeFromSuperview];
    }
    
    //存在附加数据
    if (_chartModel.sunDatas.count > 0) {
        self.sunView.sunDatas = _chartModel.sunDatas;
        [self.stackView addArrangedSubview:self.sunView];
        [NSLayoutConstraint activateConstraints:@[
            [self.sunView.heightAnchor constraintEqualToConstant:30 + 8]
        ]];
        
        [self.sunView reloadData];
    } else {
        [self.sunView removeFromSuperview];
    }
    
    if (_chartModel.tooltipDisable) {
        _options.tooltip = AATooltip.new
            .enabledSet(NO);
        _options.xAxis.crosshair = [AACrosshair crosshairWithColor:@"00FFFFFF"];//准星线透明
        return;
    }
    
    if (_chartModel.nativeTooltip) {//是否使用原生tooltip
        _options.tooltip = AATooltip.new
            .backgroundColorSet(@"rgba(0,0,0,0)")
            .borderColorSet(@"rgba(0,0,0,0)")
            .borderWidthSet(@0)
            .formatterSet(@AAJSFunc(function() {
                return "";
            }));
        _options.xAxis.crosshair = [AACrosshair crosshairWithColor:@"00FFFFFF"];//准星线透明
        
        _touched = NO;
        
        self.crosshairView.frame = self.chartView.bounds;
        self.crosshairView.lineColor = [HMChartTool colorWithHexString:_chartModel.crosshairColor];
        self.crosshairView.hidden = YES;
        [self.chartView addSubview:self.crosshairView];
        
        if (_chartModel.version == 2) {
            [self.ictooltip removeFromSuperview];
            self.ictooltip = nil;

            HMIconTooltip *ictooltip = [_tooltipTool createIconTooltip];
            ictooltip.hidden = YES;
            [self addSubview:ictooltip];
            self.ictooltip = ictooltip;
            
            [self setupConstraints];
        } else {
            [self.natooltip removeFromSuperview];
            self.natooltip = nil;

            HMTooltip *natooltip = [_tooltipTool createNATooltip];
            natooltip.hidden = YES;
            [self addSubview:natooltip];
            self.natooltip = natooltip;
        }
        
        _lPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        _lPressGesture.minimumPressDuration = 0.01;
        [self.chartView addGestureRecognizer:_lPressGesture];
    } else {
        _options.tooltip = [_tooltipTool createAATooltip];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            
            NSLog(@"UIGestureRecognizerStateBegan");
        
            if (_touched) {
                [self tooltipEventShow:YES];
            }
            
            break;
            
        case UIGestureRecognizerStateChanged:
            NSLog(@"UIGestureRecognizerStateChanged");
            
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self tooltipEventShow:NO];
            
            NSLog(@"UIGestureRecognizerStateEnded & UIGestureRecognizerStateCancelled");
            
            break;
            
        default:
            break;
    }
}

// 设置选中某一个点
- (void)setTouchPointXIndex:(NSInteger)xIndex {
//    NSLog(@"xIndex : %ld", xIndex);
    
    if (_options == nil) {
        return;
    }
//    NSString *jsString = [NSString stringWithFormat:@AAJSFunc(function() {
//        const points = [];
//        const chart = this;
//        const series = chart.series;
//        const length = series.length;
//                   
//        for (let i = 0; i < length; i++) {
//            const pointElement = series[i].data[%ld];
//            pointElement.onMouseOver();
//            points.push(pointElement);
//        }
//        chart.xAxis[0].drawCrosshair(null, points[0]);
//        chart.tooltip.refresh(points);
//    }), xIndex];
//    _options.chart
//            .eventsSet(AAChartEvents.new
//                .loadSet(jsString));
//    [_chartView aa_refreshChartWithOptions:_options];
    
//    NSString *jsString = [NSString stringWithFormat:
//        @"(function() {"
//            // 1. 安全获取已渲染完成的 chart 实例
//            @"var charts = Highcharts.charts || [];"
//            @"var chart = null;"
//            @"for (var i = charts.length - 1; i >= 0; i--) {"
//            @"    var c = charts[i];"
//            @"    if (c && c.plotLeft !== undefined && c.plotHeight > 0) {"
//            @"        chart = c;"
//            @"        break;"
//            @"    }"
//            @"}"
//            
//            // 如果没找到 chart，直接退出
//            @"if (!chart) return '未找到有效的chart实例';"
//            
//            // 2. 延迟 50ms 执行，给 Tooltip 组件留出准备时间
//            @"setTimeout(function() {"
//            @"    var points = [];"
//            @"    var length = chart.series.length;"
//            
//            @"    for (var i = 0; i < length; i++) {"
//            @"        var pointElement = chart.series[i].data[%ld];"
//            @"        if (pointElement) {"
////            @"            pointElement.onMouseOver();"
//            @"            points.push(pointElement);"
//            @"        }"
//            @"    }"
//            
//            @"    if (points.length > 0) {"
//            @"        chart.xAxis[0].drawCrosshair(null, points[0]);"
//            @"        chart.tooltip.refresh(points);"
//            @"    }"
//            @"}, 50);"
//            
//            @"return 'JS注入成功，等待Tooltip渲染...';"
//        @"})()",
//        (long)xIndex
//    ];
    
    NSString *jsString = [NSString stringWithFormat:
        @"(function() {"
            @"var charts = Highcharts.charts || [];"
            @"var chart = null;"
            @"for (var i = charts.length - 1; i >= 0; i--) {"
            @"    var c = charts[i];"
            @"    if (c && c.plotLeft !== undefined && c.plotHeight > 0) {"
            @"        chart = c;"
            @"        break;"
            @"    }"
            @"}"
            @"if (!chart) return '未找到有效的chart实例';"
            
            @"var points = [];"
            @"var length = chart.series.length;"
            @"for (var i = 0; i < length; i++) {"
            @"    var pointElement = chart.series[i].data[%ld];"
            @"    if (pointElement) {"
            @"        points.push(pointElement);"
            @"    }"
            @"}"
            @"if (points.length > 0) {"
            @"    chart.xAxis[0].drawCrosshair(null, points[0]);"
            @"    chart.tooltip.refresh(points);"
            @"}"
            @"return '同步更新完成';"
        @"})()",
        (long)xIndex
    ];
    [_chartView evaluateJavaScript:jsString completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JS执行错误: %@", error);
            return;
        }
    }];
}

#pragma mark - AAChartViewEventDelegate
- (void)aaChartView:(AAChartView *)aaChartView clickEventWithMessage:(AAClickEventMessageModel *)message {
//    NSLog(@"click offset:%@, index:%ld, size:%@", message.offset, _index, NSStringFromCGSize(self.bounds.size));
    if (self.clickBlock) {
        self.clickBlock(message.index);
    }
}

- (void)aaChartView:(AAChartView *)aaChartView moveOverEventWithMessage:(AAMoveOverEventMessageModel *)message {
    _index = message.index;
//    NSLog(@"move offset:%@, index:%ld, size:%@", message.offset, _index, NSStringFromCGSize(self.bounds.size));
//    if (self.clickBlock) {
//        self.clickBlock(message.index);
//    }
    
    if (_chartModel.nativeTooltip) {
        _touched = YES;
//        [_headerView hiddenContent:YES];
        
        CGFloat plotX = [message.offset[@"plotX"] floatValue];
        // 通过图表比例计算准星线位置
//        CGFloat crossX = 47 * (self.bounds.size.width/345.0);
//        CGFloat crossY = 96 * (self.bounds.size.height/330.0);
//        [self.crosshairView showAtPoint:CGPointMake(plotX + crossX, self.bounds.size.height - crossY)];
        
        if (_chartModel.version == 2) {
            // 赋值数据
            [_ictooltip loadTooltipDataIndex:_index];
            
//            CGRect frame = _ictooltip.frame;
//            CGFloat x = MAX(plotX - 40, 0);
//            if (x + frame.size.width > self.frame.size.width) {
//                x = self.frame.size.width - frame.size.width;
//            }
//            frame.origin.x = x;
//            frame.origin.y = 0;
//            _ictooltip.frame = frame;
        } else {
            _natooltip.hidden = NO;

            // 赋值数据
            [_natooltip loadTooltipDataIndex:_index];
            
            CGRect frame = _natooltip.frame;
            CGFloat x = MAX(plotX - 40, 0);
            if (x + frame.size.width > self.frame.size.width) {
                x = self.frame.size.width - frame.size.width;
            }
            frame.origin.x = x;
            frame.origin.y = 0;
            _natooltip.frame = frame;
        }
                
        NSString *js = @"(function() {"
                "var charts = Highcharts.charts || [];"
                "for (var i = charts.length - 1; i >= 0; i--) {"
                    "var chart = charts[i];"
                    "if (chart && chart.plotLeft !== undefined && chart.plotHeight > 0) {"
                        "return ["
                            "chart.plotLeft || 0,"
                            "chart.plotTop || 0,"
                            "chart.plotHeight || 0,"
                            "chart.chartHeight || 0"
                        "];"
                    "}"
                "}"
                "return null;"
            "})();";
            
        [aaChartView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"JS执行错误: %@", error);
                return;
            }
            if ([result isKindOfClass:[NSArray class]] && [result count] == 4) {
                CGFloat plotLeft = [result[0] floatValue];
                CGFloat plotTop = [result[1] floatValue];
                CGFloat plotHeight = [result[2] floatValue];
                CGFloat chartHeight = [result[3] floatValue];
                
                CGFloat distanceLeft = plotLeft;                          // 固定左边距
                CGFloat distanceBottom = chartHeight - (plotTop + plotHeight); // 固定底部边距
                
//                NSLog(@"固定左边距: %.2f, 固定底部边距: %.2f", distanceLeft, distanceBottom);
                
                [self.crosshairView showAtPoint:CGPointMake(plotX + distanceLeft, self.chartView.bounds.size.height - distanceBottom)];
                _crosshairView.hidden = NO;
                
                if (_chartModel.version == 2) {
                    self.centerXConstraint.constant = plotX + distanceLeft;
                    self.ictooltip.hidden = NO;
                    
                    [self layoutIfNeeded];
                }
                
                [_headerView hiddenContent:YES];
            }
        }];
        
        // 计时让原生tooltip消失
        if (self.timerBlock) {
            dispatch_block_cancel(self.timerBlock);
            self.timerBlock = nil;
        }
            
        __weak typeof(self) weakSelf = self;
        dispatch_block_t newBlock = dispatch_block_create(0, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
                
            // 倒计时归零，执行你的业务逻辑（例如隐藏加载框、发送请求等）
            [strongSelf tooltipEventShow:NO];
            
            // 清空引用，表示计时器已销毁
            strongSelf.timerBlock = nil;
        });
            
        // 保存新任务并调度到主队列，5秒后执行
        self.timerBlock = newBlock;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), newBlock);
    }
}

- (void)aaChartViewDidFinishLoad:(AAChartView *)aaChartView {
    CHECK_NULL_EXEC_BLOCK(self.finishLoad);
}

// 调试图表信息代码
- (void)debugChartInstances {
    NSString *js = @"(function() {"
        "var charts = Highcharts.charts || [];"
        "var result = { count: charts.length, details: [] };"
        "for (var i = 0; i < charts.length; i++) {"
            "var chart = charts[i];"
            "if (chart) {"
                "result.details.push({"
                    "index: i,"
                    "hasContainer: !!chart.container,"
                    "containerInDom: chart.container ? document.body.contains(chart.container) : false,"
                    "plotLeft: chart.plotLeft,"
                    "plotTop: chart.plotTop,"
                    "plotHeight: chart.plotHeight,"
                    "chartHeight: chart.chartHeight"
                "});"
            "} else {"
                "result.details.push({ index: i, chart: null });"
            "}"
        "}"
        "return JSON.stringify(result);"
    "})();";
    
    [_chartView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JS执行错误: %@", error);
            return;
        }
        NSLog(@"图表调试信息: %@", result);
        // 将 result 字符串转为字典打印更清晰
        if ([result isKindOfClass:[NSString class]]) {
            NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSLog(@"解析后: %@", dict);
        }
    }];
}

#pragma mark - private
//- (UIViewController *)currentViewController {
//    UIResponder *responder = self;
//    while ((responder = [responder nextResponder])) {
//        if ([responder isKindOfClass: [UIViewController class]]) {
//            return (UIViewController *)responder;
//        }
//    }
//    return nil;
//}
//
//- (UIScrollView *)findParentScrollView {
//    UIView *superview = self.superview;
//    while (superview) {
//        if ([superview isKindOfClass:[UIScrollView class]]) {
//            return (UIScrollView *)superview;
//        }
//        superview = superview.superview;
//    }
//    return nil;
//}

- (void)tooltipEventShow:(BOOL)show {
    _natooltip.hidden = !show;
    _ictooltip.hidden = !show;
    _crosshairView.hidden = !show;
    [_headerView hiddenContent:show];
}

- (void)setupConstraints {
    NSLayoutConstraint *leftBound = [self.ictooltip.leftAnchor constraintGreaterThanOrEqualToAnchor:self.leftAnchor constant:8];
    leftBound.priority = UILayoutPriorityRequired; // 1000
    NSLayoutConstraint *rightBound = [self.ictooltip.rightAnchor constraintLessThanOrEqualToAnchor:self.rightAnchor constant:-8];
    rightBound.priority = UILayoutPriorityRequired;

    
    self.centerXConstraint = [self.ictooltip.centerXAnchor constraintEqualToAnchor:self.leftAnchor];
    self.centerXConstraint.priority = UILayoutPriorityDefaultHigh; // 750
    
    NSMutableArray *constraints = @[leftBound, rightBound, self.centerXConstraint].mutableCopy;
    if (_chartModel.headerDatas.count > 0) {
        NSLayoutConstraint *bottom = [self.ictooltip.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:0];
        [constraints addObject:bottom];
    } else {
        NSLayoutConstraint *top = [self.ictooltip.topAnchor constraintEqualToAnchor:self.topAnchor constant:0];
        [constraints addObject:top];
    }

    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - getter
- (UIStackView *)stackView {
    if (!_stackView) {
        _stackView = [[UIStackView alloc] init];
        _stackView.axis = UILayoutConstraintAxisVertical;
        _stackView.distribution = UIStackViewDistributionFill;
        _stackView.alignment = UIStackViewAlignmentFill;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _stackView;
}

- (AAChartView *)chartView {
    if (!_chartView) {
        _chartView = [[AAChartView alloc] init];
        _chartView.scrollEnabled = NO;
        _chartView.isClearBackgroundColor = YES;
        _chartView.delegate = self;
        _chartView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _chartView;
}

- (HMTooltipTool *)tooltipTool {
    if (!_tooltipTool) {
        _tooltipTool = [[HMTooltipTool alloc] init];
    }
    return _tooltipTool;
}

- (UIStackView *)noDataStack {
    if (!_noDataStack) {
        _noDataStack = [[UIStackView alloc] init];
        _noDataStack.axis = UILayoutConstraintAxisVertical;
        _noDataStack.spacing = 4;
    }
    return _noDataStack;
}

- (UIImageView *)noDataImgView {
    if (!_noDataImgView) {
        _noDataImgView = [[UIImageView alloc] init];
        _noDataImgView.contentMode = UIViewContentModeScaleAspectFit;
//        _noDataImgView.image = [UIImage imageNamed:self.nodImgName];
    }
    return _noDataImgView;
}

- (UILabel *)noDataLabel {
    if (!_noDataLabel) {
        _noDataLabel = [[UILabel alloc] init];
        _noDataLabel.font = self.nodFont;
        _noDataLabel.textColor = self.nodColor;
        _noDataLabel.numberOfLines = 1;
        _noDataLabel.text = self.nodText;
        _noDataLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _noDataLabel;
}

- (HMChartTitleView *)titleView {
    if (!_titleView) {
        _titleView = [[HMChartTitleView alloc] init];
    }
    return _titleView;
}

- (HMChartHeaderView *)headerView {
    if (!_headerView) {
        _headerView = [[HMChartHeaderView alloc] init];
        _headerView.hidden = YES;
    }
    return _headerView;
}

- (HMChartSunView *)sunView {
    if (!_sunView) {
        _sunView = [[HMChartSunView alloc] init];
        _sunView.hidden = YES;
    }
    return _sunView;
}

- (HMChartCrosshairView *)crosshairView {
    if (!_crosshairView) {
        _crosshairView = [[HMChartCrosshairView alloc] init];
        _crosshairView.bounds = CGRectMake(0, 0, 1, self.bounds.size.height);
    }
    return _crosshairView;
}

#pragma mark help method

- (NSString *)hexStringFromAlpha:(CGFloat)alpha {
    // 1. 修正 alpha 范围（防止传入负数/大于1的值）
    CGFloat normalizedAlpha = MAX(0.0, MIN(1.0, alpha));
    
    // 2. 映射为 0~255 的整数（四舍五入保证精度）
    NSInteger decimalValue = round(normalizedAlpha * 255.0);
    
    // 3. 转为两位十六进制（大写，不足两位补 0）
    // %02lX：02=补0到两位，l=适配NSInteger，X=大写十六进制（小写用x）
    NSString *hexStr = [NSString stringWithFormat:@"%02lX", decimalValue];
    
    return hexStr;
}

@end
