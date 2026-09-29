//
//  HMChartSunView.h
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/7.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HMChartSunModel;
@interface HMChartSunView : UIView

@property (nonatomic, copy) NSArray<HMChartSunModel *> *sunDatas;//如果需要展示日出日落

- (void)reloadData;

@end

@interface HMChartSunRow : UIView

@property (nonatomic, strong) HMChartSunModel *model;

- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
