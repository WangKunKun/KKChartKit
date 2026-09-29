//
//  HMAAChartUtil.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/5/9.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HMAAChartView/HMAAChartKit.h"

NS_ASSUME_NONNULL_BEGIN
// 针对项目配置HMAAChartView
@interface HMAAChartUtil : NSObject

// 创建带图例的AAChartView
+ (HMLGAAChartView *)createlgaaChartView;
+ (HMLGAAChartView *)createlgaaChartViewWithFrame:(CGRect)frame;

// 创建基础AAChartView
+ (HMAAChartView *)createaaChartView;
+ (HMAAChartView *)createaaChartViewWithFrame:(CGRect)frame;

// 判断key是否需要区分正负并返回数据名称 @[positive, negative];
+ (NSArray *)namesWithKey:(NSString *)key;

// 根据正负数据区分数据名称
+ (NSMutableArray *)formatNamesWithData:(NSArray *)data positive:(NSString *)positive negative:(NSString *)negative;

// 需要取相反数的key
+ (NSArray *)keyNeedOpposite;

// 需要取绝对值后相反数的key
+ (NSArray *)keyNeedFabsAndOpposite;

//AI图表使用
+ (NSArray *)fixAIChatData:(NSArray *)data type:(NSString *)type;
@end

NS_ASSUME_NONNULL_END
