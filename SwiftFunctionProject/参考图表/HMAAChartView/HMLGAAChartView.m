//
//  HMLGAAChartView.m
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/4/30.
//

#import "HMLGAAChartView.h"
#import "HMAAChartView.h"
#import "HMAAChartModel.h"
#import "HMAASeries.h"
#import "HMAAChartFullScreenVC.h"
#import "HMChartTool.h"

@interface HMLGAAChartView () <HMAAChartViewDelegate>

@property (nonatomic, strong) HMAAChartView *chartView;
@property (nonatomic, strong) HMAAChartModel *chartModel;
@property (nonatomic, strong) UIView *legendBgView;
@property (nonatomic, strong) UIButton *enlargeButton;

@property (nonatomic, strong) UIImage * snapShotImage;

@end

@implementation HMLGAAChartView

- (instancetype)init {
    self = [super init];
    if (self) {
        _chartView = [[HMAAChartView alloc] init];
//        _chartView.translatesAutoresizingMaskIntoConstraints = NO;
        _chartView.delegate = self;
        __weak typeof(self) weakSelf = self;
        _chartView.clickBlock = ^(NSInteger index) {
            if (weakSelf.clickBlock) {
                weakSelf.clickBlock(index);
            }
        };
        _chartView.finishLoad = ^{
            if (weakSelf.triggerSnap) {
            }
        };
        [self addSubview:_chartView];
        [self addSubview:self.enlargeButton];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _chartView = [[HMAAChartView alloc] init];
//        _chartView.translatesAutoresizingMaskIntoConstraints = NO;
        _chartView.delegate = self;
        __weak typeof(self) weakSelf = self;
        _chartView.clickBlock = ^(NSInteger index) {
            if (weakSelf.clickBlock) {
                weakSelf.clickBlock(index);
            }
        };
        [self addSubview:_chartView];
        [self addSubview:self.enlargeButton];
    }
    return self;
}

#pragma mark - method

- (void)reloadDataWithModel:(HMAAChartModel *)model {
    _chartModel = model;
    [self setNeedsLayout];
    [self layoutIfNeeded];// 兼容外界使用约束
            
    if (model.showNoData) {
        model.showLegend = NO;
    }
    
    if (!model.showLegend) {
        _chartView.frame = self.bounds;
        if (_legendBgView) {
            [_legendBgView removeFromSuperview];
            _legendBgView = nil;
        }
    } else {
        if (!_legendBgView) {
            _legendBgView = [[UIView alloc] init];
//            _legendBgView.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:_legendBgView];
        }
        [_legendBgView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        
        // 绘制图例按钮
        if (model.version == 2) {//新版本
            [self drawLegendView2:model];
        } else {
            [self drawLegendView:model];
        }
        
    }
    
    // ---暂无数据配置项---
    if (self.nodImgName) {
        _chartView.nodImgName = self.nodImgName;
    }
    if (self.nodText) {
        _chartView.nodText = self.nodText;
    }
    if (self.nodColor) {
        _chartView.nodColor = self.nodColor;
    }
    if (self.nodFont) {
        _chartView.nodFont = self.nodFont;
    }
    [_chartView reloadDataWithModel:_chartModel];
    
    if (model.showNoData) {
        [_chartView showNoData:model.showNoData];
    }
    
    if (self.showEnlargeButton) {
        self.enlargeButton.hidden = NO;
        self.enlargeButton.frame = CGRectMake(self.frame.origin.x + self.frame.size.width - 80 - 12, 0, 80, 40);
    }
}

// 只刷新数据
- (void)onlyRefreshTheChartData {
    [_chartView onlyRefreshTheChartData];
}

// 设置选中某一个点
- (void)setTouchPointXIndex:(NSInteger)xIndex {
    [_chartView setTouchPointXIndex:xIndex];
}

// 绘制图例按钮
- (void)drawLegendView:(HMAAChartModel *)model {
    NSInteger row = model.seriesArray.count;
    if (model.seriesArray.count > 1) {
        int t = 0;
        for (int i = 0; i < model.seriesArray.count; i++) {
            HMAASeries *series = model.seriesArray[i];
            CGFloat lastWidth = 6;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                UIView *vi = [[UIView alloc] init];
                vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
                vi.layer.cornerRadius = 12;
                UIView *dot = [[UIView alloc] init];
                dot.backgroundColor = [self colorWithHexString:element.color];
                dot.layer.cornerRadius = 6;
                dot.frame = CGRectMake(8, 6, 12, 12);
                if (element.dashStyle.length > 0) {//配置虚线
                    dot.backgroundColor = [self colorWithHexString:element.color alpha:0.2];
                    CAShapeLayer *shapeLayer = [self createShapeLayerFrame:dot.bounds color:[self colorWithHexString:element.color]];
                    [dot.layer addSublayer:shapeLayer];
                }
                [vi addSubview:dot];
                UILabel *lab = [[UILabel alloc] init];
                lab.text = element.name;
                lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
                CGSize size = [lab sizeThatFits:CGSizeZero];
                lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
                [vi addSubview:lab];
                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
                if (lastWidth + viewWidth > self.bounds.size.width) {
                    t ++;
                    lastWidth = 6;
                }
                vi.frame = CGRectMake(lastWidth, (i + t) * (24 + 12), viewWidth, 24);
                lastWidth += vi.bounds.size.width + 12;
                vi.alpha = element.isHidden ? 0.3 : 1;
                [_legendBgView addSubview:vi];
                // 设置图表展示开关
                vi.tag = i * 10 + j;
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
                [vi addGestureRecognizer:tap];
            }
        }
        row += t;
    } else {
        HMAASeries *series = model.seriesArray.firstObject;
        if (series.element.count > 1) {
            CGFloat lastWidth = 6;
            int t = 0;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                UIView *vi = [[UIView alloc] init];
                vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
                vi.layer.cornerRadius = 12;
                UIView *dot = [[UIView alloc] init];
                dot.backgroundColor = [self colorWithHexString:element.color];
                dot.layer.cornerRadius = 6;
                dot.frame = CGRectMake(8, 6, 12, 12);
                if (element.dashStyle.length > 0) {//配置虚线
                    dot.backgroundColor = [self colorWithHexString:element.color alpha:0.2];
                    CAShapeLayer *shapeLayer = [self createShapeLayerFrame:dot.bounds color:[self colorWithHexString:element.color]];
                    [dot.layer addSublayer:shapeLayer];
                }
                [vi addSubview:dot];
                UILabel *lab = [[UILabel alloc] init];
                lab.text = element.name;
                lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
                CGSize size = [lab sizeThatFits:CGSizeZero];
                lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
                [vi addSubview:lab];
                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
                if (lastWidth + viewWidth > self.bounds.size.width) {
                    t ++;
                    lastWidth = 6;
                }
                vi.frame = CGRectMake(lastWidth, t * (24 + 12), viewWidth, 24);
                lastWidth += vi.bounds.size.width + 12;
                vi.alpha = element.isHidden ? 0.3 : 1;
                [_legendBgView addSubview:vi];
                // 设置图表展示开关
                vi.tag = j;
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
                [vi addGestureRecognizer:tap];
            }
            row += t;
        } else if (series.element.count == 1) {
            HMAASeriesElement *element = series.element.firstObject;
            UIView *vi = [[UIView alloc] init];
            vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
            vi.layer.cornerRadius = 12;
            UIView *dot = [[UIView alloc] init];
            dot.backgroundColor = [self colorWithHexString:element.color];
            dot.layer.cornerRadius = 6;
            dot.frame = CGRectMake(8, 6, 12, 12);
            if (element.dashStyle.length > 0) {//配置虚线
                dot.backgroundColor = [self colorWithHexString:element.color alpha:0.2];
                CAShapeLayer *shapeLayer = [self createShapeLayerFrame:dot.bounds color:[self colorWithHexString:element.color]];
                [dot.layer addSublayer:shapeLayer];
            }
            [vi addSubview:dot];
            UILabel *lab = [[UILabel alloc] init];
            lab.text = element.name;
            lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
            CGSize size = [lab sizeThatFits:CGSizeZero];
            lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
            [vi addSubview:lab];
            vi.frame = CGRectMake(0, 0, 8 + 12 + 4 + size.width + 8, 24);
            vi.center = CGPointMake(self.bounds.size.width / 2, vi.center.y);
            vi.alpha = element.isHidden ? 0.3 : 1;
            [_legendBgView addSubview:vi];
            // 设置图表展示开关
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
            [vi addGestureRecognizer:tap];
        }
    }
    
    CGFloat legendHeight = row * (24 + 12) - 12;
    if (model.chartHeight > 0) {
        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, model.chartHeight);
    } else {
        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - legendHeight);
    }
    _legendBgView.frame = CGRectMake(0, _chartView.bounds.size.height, self.bounds.size.width, legendHeight);
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, _chartView.bounds.size.width, _chartView.bounds.size.height + legendHeight);
}

// 绘制图例按钮ver2
- (void)drawLegendView2:(HMAAChartModel *)model {
    NSInteger row = model.seriesArray.count;
    if (model.seriesArray.count > 1) {
        int t = 0;
        for (int i = 0; i < model.seriesArray.count; i++) {
            HMAASeries *series = model.seriesArray[i];
            CGFloat lastWidth = 8;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                HMChartLGSwitch *st = [[HMChartLGSwitch alloc] init];
                st.on = !element.isHidden;
                __weak typeof(self) weakSelf = self;
                st.tapSwitchBlock = ^{
                    [weakSelf legendTap:element];
                };
                st.element = series.element[j];
                CGSize size = [element.name boundingRectWithSize:CGSizeZero options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium]} context:nil].size;
                CGFloat viewWidth = MIN(self.bounds.size.width - 16, 36 + 4 + ceil(size.width));
                if (lastWidth + viewWidth > self.bounds.size.width) {
                    t ++;
                    lastWidth = 8;
                }
                [_legendBgView addSubview:st];
//                [NSLayoutConstraint activateConstraints:@[
//                    [st.leadingAnchor constraintEqualToAnchor:_legendBgView.leadingAnchor constant:lastWidth],
//                    [st.topAnchor constraintEqualToAnchor:_legendBgView.topAnchor constant:(i + t) * (18 + 8)],
//                    [st.widthAnchor constraintEqualToConstant:viewWidth],
//                    [st.heightAnchor constraintEqualToConstant:18]
//                ]];
                st.frame = CGRectMake(lastWidth, (i + t) * (18 + 8), viewWidth, 18);
                lastWidth += viewWidth + 8;
            }
        }
        row += t;
    } else {
        HMAASeries *series = model.seriesArray.firstObject;
        if (series.element.count > 1) {
            CGFloat lastWidth = 8;
            int t = 0;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                HMChartLGSwitch *st = [[HMChartLGSwitch alloc] init];
                st.on = !element.isHidden;
                __weak typeof(self) weakSelf = self;
                st.tapSwitchBlock = ^{
                    [weakSelf legendTap:element];
                };
                st.element = series.element[j];
                CGSize size = [element.name boundingRectWithSize:CGSizeZero options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium]} context:nil].size;
                CGFloat viewWidth = MIN(self.bounds.size.width - 16, 36 + 4 + ceil(size.width));
                if (lastWidth + viewWidth > self.bounds.size.width) {
                    t ++;
                    lastWidth = 8;
                }
                [_legendBgView addSubview:st];
//                [NSLayoutConstraint activateConstraints:@[
//                    [st.leadingAnchor constraintEqualToAnchor:_legendBgView.leadingAnchor constant:lastWidth],
//                    [st.topAnchor constraintEqualToAnchor:_legendBgView.topAnchor constant:t * (18 + 8)],
//                    [st.widthAnchor constraintEqualToConstant:viewWidth],
//                    [st.heightAnchor constraintEqualToConstant:18]
//                ]];
                st.frame = CGRectMake(lastWidth, t * (18 + 8), viewWidth, 18);
                lastWidth += viewWidth + 8;
            }
            row += t;
        } else if (series.element.count == 1) {
            HMAASeriesElement *element = series.element.firstObject;
            HMChartLGSwitch *st = [[HMChartLGSwitch alloc] init];
            st.on = !element.isHidden;
            __weak typeof(self) weakSelf = self;
            st.tapSwitchBlock = ^{
                [weakSelf legendTap:element];
            };
            st.element = element;
            [_legendBgView addSubview:st];
            CGSize size = [element.name boundingRectWithSize:CGSizeZero options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium]} context:nil].size;
//            [NSLayoutConstraint activateConstraints:@[
//                [st.centerXAnchor constraintEqualToAnchor:_legendBgView.centerXAnchor],
//                [st.centerYAnchor constraintEqualToAnchor:_legendBgView.centerYAnchor],
//                [st.widthAnchor constraintEqualToConstant:MIN(self.bounds.size.width - 16, 36 + 4 + ceil(size.width))],
//                [st.heightAnchor constraintEqualToConstant:18]
//            ]];
            st.frame = CGRectMake(0, 0, MIN(self.bounds.size.width - 16, 36 + 4 + ceil(size.width)), 18);
            st.center = CGPointMake(self.bounds.size.width / 2, st.center.y);
        }
    }
    
    CGFloat legendHeight = row * (18 + 8) - 8;
    if (model.chartHeight > 0) {
        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, model.chartHeight);
    } else {
        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - legendHeight);
    }
    _legendBgView.frame = CGRectMake(0, _chartView.bounds.size.height, self.bounds.size.width, legendHeight);
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, _chartView.bounds.size.width, _chartView.bounds.size.height + legendHeight);
    
//    CGFloat legendHeight = row * (18 + 8) - 8;
//    if (model.chartHeight > 0) {
//        [NSLayoutConstraint activateConstraints:@[
//            [_chartView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
//            [_chartView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
//            [_chartView.topAnchor constraintEqualToAnchor:self.topAnchor],
//            [_chartView.heightAnchor constraintEqualToConstant:model.chartHeight]
//        ]];
//    } else {
//        [NSLayoutConstraint activateConstraints:@[
//            [_chartView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
//            [_chartView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
//            [_chartView.topAnchor constraintEqualToAnchor:self.topAnchor],
//            [_chartView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-legendHeight]
//        ]];
//    }
//    [NSLayoutConstraint activateConstraints:@[
//        [_legendBgView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
//        [_legendBgView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
//        [_legendBgView.topAnchor constraintEqualToAnchor:_chartView.bottomAnchor],
//        [_legendBgView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
//    ]];
}

#pragma mark - private
// 绘制虚线dot
- (CAShapeLayer *)createShapeLayerFrame:(CGRect)frame color:(UIColor *)color {
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.strokeColor = color.CGColor;
    shapeLayer.lineDashPattern = @[@2, @2]; // 2pt实线，2pt空白
    shapeLayer.lineWidth = 1;
    shapeLayer.fillColor = [UIColor clearColor].CGColor;
    CGRect borderRect = CGRectInset(frame, 1 / 2.0, 1 / 2.0);
    shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:borderRect cornerRadius:frame.size.width/2].CGPath;
    return shapeLayer;
}

// 图注点击事件
- (void)legendTapAction:(UITapGestureRecognizer *)tap {
    UIView *vi = tap.view;
    int i = (int)vi.tag / 10;
    int j = vi.tag % 10;
    HMAASeriesElement *element = _chartModel.seriesArray[i].element[j];
    element.isHidden = !element.isHidden;
    vi.alpha = element.isHidden ? 0.3 : 1;
    [_chartView reloadDataWithModel:_chartModel];
    if (self.legendTapBlock) {
        self.legendTapBlock(element);
    }
}

// 图注点击事件ver
- (void)legendTap:(HMAASeriesElement *)element {
    element.isHidden = !element.isHidden;
    [_chartView reloadDataWithModel:_chartModel];
    if (self.legendTapBlock) {
        self.legendTapBlock(element);
    }
}

// 放大事件
- (void)enlargeAction {
    HMAAChartFullScreenVC *vc = [[HMAAChartFullScreenVC alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    vc.chartModel = _chartModel;
    vc.nodImgName = self.nodImgName;
    vc.nodText = self.nodText;
    vc.nodColor = self.nodColor;
    vc.nodFont = self.nodFont;
    UIViewController *con = [self parentViewController];
    [con presentViewController:vc animated:NO completion:nil];
}

#pragma mark - HMAAChartViewDelegate
- (void)hmaaChartView:(HMAAChartView *)chartView handlePan:(UIPanGestureRecognizer *)gesture {
    if ([self.delegate respondsToSelector:@selector(hmlgaaChartView:handlePan:)]) {
        [self.delegate hmlgaaChartView:self handlePan:gesture];
    }
}

#pragma mark - Others
- (UIColor *)colorWithHexString:(NSString *)color {
    return [self colorWithHexString:color alpha:1.0f];
}

- (UIColor *)colorWithHexString:(NSString *)color alpha:(CGFloat)alphaValue {
    
    NSString *cString = [[color stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6 or 8 characters
    if ([cString length] < 6) {
        return [UIColor clearColor];
    }
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"])
        cString = [cString substringFromIndex:2];
    if ([cString hasPrefix:@"#"])
        cString = [cString substringFromIndex:1];
    if ([cString length] != 6)
        return [UIColor clearColor];
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    
    //r
    NSString *rString = [cString substringWithRange:range];
    
    //g
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    //b
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:alphaValue];
}

- (UIViewController *)parentViewController {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

#pragma mark - getter
- (UIButton *)enlargeButton {
    if (!_enlargeButton) {
        _enlargeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_enlargeButton setTitle:@"Enlarge" forState:UIControlStateNormal];
        _enlargeButton.bounds = CGRectMake(0, 0, 80, 40);
        _enlargeButton.layer.borderColor = [UIColor blueColor].CGColor;
        _enlargeButton.layer.borderWidth = 1;
        _enlargeButton.hidden = YES;
        [_enlargeButton addTarget:self action:@selector(enlargeAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _enlargeButton;
}

@end

@interface HMChartLGSwitch ()

@property (nonatomic, strong) UIImageView *imgView;
@property (nonatomic, strong) UIView *rail;
@property (nonatomic, strong) UILabel *nameLab;

@property (strong, nonatomic) NSLayoutConstraint *leadingConstraint;

@end

@implementation HMChartLGSwitch

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.rail];
        [self addSubview:self.imgView];
        [self addSubview:self.nameLab];
        
//        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.rail.translatesAutoresizingMaskIntoConstraints = NO;
        self.imgView.translatesAutoresizingMaskIntoConstraints = NO;
        self.nameLab.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.leadingConstraint = [self.imgView.leadingAnchor constraintEqualToAnchor:self.rail.leadingAnchor constant:18];

        [NSLayoutConstraint activateConstraints:@[
            [self.rail.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.rail.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.rail.widthAnchor constraintEqualToConstant:36],
            [self.rail.heightAnchor constraintEqualToConstant:8],
            self.leadingConstraint,
            [self.imgView.centerYAnchor constraintEqualToAnchor:self.rail.centerYAnchor],
            [self.imgView.widthAnchor constraintEqualToConstant:18],
            [self.imgView.heightAnchor constraintEqualToConstant:18],
            [self.nameLab.leadingAnchor constraintEqualToAnchor:self.rail.trailingAnchor constant:4],
            [self.nameLab.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.nameLab.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchTapAction)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)setElement:(HMAASeriesElement *)element {
    _element = element;
    self.imgView.image = [UIImage imageNamed:element.icon];
    [self colorWithSwitch];
    self.nameLab.text = element.name;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        _rail.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
        [self colorWithSwitch];
    }
}

- (void)colorWithSwitch {
    self.imgView.tintColor =  [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeBackground2 traitCollection:self.traitCollection]];
    if (self.on) {
        self.imgView.backgroundColor = [HMChartTool colorWithHexString:self.element.color];
        self.nameLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
    } else {
        self.imgView.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
        self.nameLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    }
}

#pragma mark - action
- (void)switchTapAction {
    self.on = !self.on;
    [self colorWithSwitch];
    if (self.on) {
        self.leadingConstraint.constant = 18;
    } else {
        self.leadingConstraint.constant = 0;
    }
    
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self layoutIfNeeded];
    } completion:nil];
    
    if (self.tapSwitchBlock) {
        self.tapSwitchBlock();
    }
}

#pragma mark - getter
- (UIView *)rail {
    if (!_rail) {
        _rail = [UIView new];
        _rail.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
        _rail.layer.cornerRadius = 4.f;
    }
    return _rail;
}

- (UIImageView *)imgView {
    if (!_imgView) {
        _imgView = [UIImageView new];
        _imgView.contentMode = UIViewContentModeCenter;
        _imgView.layer.cornerRadius = 9.f;
    }
    return _imgView;
}

- (UILabel *)nameLab {
    if (!_nameLab) {
        _nameLab = [UILabel new];
        _nameLab.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _nameLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
    }
    return _nameLab;
}

@end
