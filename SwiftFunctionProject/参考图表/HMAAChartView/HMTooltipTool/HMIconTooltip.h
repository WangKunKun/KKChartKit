//
//  HMIconTooltip.h
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/12.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HMAASeries, HMAASeriesElement;
@interface HMIconTooltip : UIView

@property (nonatomic, copy) NSArray<HMAASeries *> *seriesArray;// 配合图例隐藏数据
@property (nonatomic, copy) NSArray *xSeriesArray;// tooltip数据标题-横轴

// 绘制当前数据需要的tooltip类型
- (void)drawDataSubviews;

// 加载对应x轴索引的数据
- (void)loadTooltipDataIndex:(NSInteger)index;

@end

@interface HMIconTooltipItem : UIView

- (void)loadItemIcon:(NSString *)icon color:(NSString *)color data:(NSString *)data;

// 展示或隐藏name
- (void)loadName:(NSString *)name;

- (void)hiddenName;

@end

NS_ASSUME_NONNULL_END
