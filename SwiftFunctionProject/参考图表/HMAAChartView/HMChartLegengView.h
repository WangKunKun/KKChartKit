//
//  HMChartLegengView.h
//  hemaiInstall
//
//  Created by wangkun on 2026/4/15.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class HMAAChartModel, HMAASeriesElement;

@interface HMChartLegengView : UIView

+ (instancetype)createWithModel:(HMAAChartModel *)model;

@end

NS_ASSUME_NONNULL_END
