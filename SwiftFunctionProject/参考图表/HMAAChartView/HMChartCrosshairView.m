//
//  HMChartCrosshairView.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import "HMChartCrosshairView.h"

@interface HMChartCrosshairView ()

@property (nonatomic, strong) CAShapeLayer *verticalLineLayer;
@property (nonatomic, assign) BOOL isShowing;

@end

@implementation HMChartCrosshairView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    _lineColor = [UIColor redColor];
    _lineWidth = 1.0f;
    _isShowing = NO;
    
    // 设置视图为透明背景，不拦截触摸事件
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    
    // 创建垂直线图层
    self.verticalLineLayer = [CAShapeLayer layer];
    self.verticalLineLayer.strokeColor = _lineColor.CGColor;
    self.verticalLineLayer.lineWidth = _lineWidth;
    self.verticalLineLayer.lineDashPattern = @[@2, @1]; // 虚线样式
    self.verticalLineLayer.hidden = YES;
    [self.layer addSublayer:self.verticalLineLayer];
}

- (void)showAtPoint:(CGPoint)point {
    _isShowing = YES;
    
    // 显示图层
    self.verticalLineLayer.hidden = NO;
    
    // 更新位置
    [self updatePosition:point];
}

- (void)updatePosition:(CGPoint)point {
    if (!_isShowing) return;
    
    CGRect bounds = self.bounds;
    
    // 创建垂直线路径
    UIBezierPath *verticalPath = [UIBezierPath bezierPath];
    [verticalPath moveToPoint:CGPointMake(point.x, 0)];
    [verticalPath addLineToPoint:CGPointMake(point.x, point.y)];
    self.verticalLineLayer.path = verticalPath.CGPath;
}

- (void)hide {
    _isShowing = NO;
    
    // 隐藏图层
    self.verticalLineLayer.hidden = YES;
}

- (void)setLineColor:(UIColor *)lineColor {
    _lineColor = lineColor;
    
    self.verticalLineLayer.strokeColor = lineColor.CGColor;
}

- (void)setLineWidth:(CGFloat)lineWidth {
    _lineWidth = lineWidth;
    
    self.verticalLineLayer.lineWidth = lineWidth;
}

@end
