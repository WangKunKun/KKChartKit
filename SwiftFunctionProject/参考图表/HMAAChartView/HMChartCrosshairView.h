//
//  HMChartCrosshairView.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
//原生tooltip使用的准星线
@interface HMChartCrosshairView : UIView

// 显示准星线到指定点（相对于CrosshairView的坐标）
- (void)showAtPoint:(CGPoint)point;

// 隐藏准星线
- (void)hide;

// 更新准星线位置
- (void)updatePosition:(CGPoint)point;

// 设置准星线颜色
@property (nonatomic, strong) UIColor *lineColor;

// 设置准星线宽度
@property (nonatomic, assign) CGFloat lineWidth;

// 是否显示准星线
@property (nonatomic, assign, readonly) BOOL isShowing;

@end

NS_ASSUME_NONNULL_END
