//
//  HMTooltip.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/11/18.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HMAASeries;
@interface HMTooltip : UIView

@property (nonatomic, copy) NSArray<HMAASeries *> *seriesArray;// 配合图例隐藏数据
@property (nonatomic, copy) NSArray *xSeriesArray;// tooltip数据标题-横轴

@property (nonatomic, assign) CGFloat minWidth;//最小宽度 默认196
@property (nonatomic, assign) CGFloat maxWidth;//最大宽度 默认屏宽-24

@property (nonatomic, strong) UIColor *textColor;

// 绘制当前数据需要的tooltip类型
- (void)drawDataSubviews;

// 加载对应x轴索引的数据
- (void)loadTooltipDataIndex:(NSInteger)index;

@end

@interface HMDotLabel : UIView

@property (nonatomic, strong) UIColor *dotColor;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;

@property (nonatomic, assign) BOOL hiddenDot;

@property (nonatomic, assign) CGFloat minHeight;//最小行高
@property (nonatomic, assign) CGFloat maxWidth;//用于限制最大宽度 默认不做限制

// 计算当前需要的大小 设置完属性使用
- (CGRect)calculateFrame;

@end

NS_ASSUME_NONNULL_END
