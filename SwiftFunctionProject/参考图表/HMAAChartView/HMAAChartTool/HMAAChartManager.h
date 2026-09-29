//
//  HMAAChartManager.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/1/8.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HMAAChartModel, AAOptions, AASeriesElement;
@interface HMAAChartManager : NSObject

@property (nonatomic, readonly, strong) NSArray<AASeriesElement *> *series;// 绘制AAChart最终数据

// 初始化
- (instancetype)initWithChartModel:(HMAAChartModel *)chartModel;

// 绘制chartView
- (AAOptions *)configureAAChartOptions;

@end

NS_ASSUME_NONNULL_END
