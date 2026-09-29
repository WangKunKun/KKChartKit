//
//  HMChartHeaderView.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
//原生tooltip使用的表头
@class HMChartHeaderModel;
@interface HMChartHeaderView : UIView

@property (nonatomic, copy) NSArray<HMChartHeaderModel *> *headerDatas;

- (void)reloadData;

- (void)hiddenContent:(BOOL)hide;//隐藏内部数据

@end

@interface HMChartHeaderRow : UIView

@property (nonatomic, strong) HMChartHeaderModel *model;

- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
