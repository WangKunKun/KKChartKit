//
//  HMAAChartFullScreenVC.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/7/2.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HMAAChartModel;
@interface HMAAChartFullScreenVC : UIViewController

@property (nonatomic, strong) HMAAChartModel *chartModel;

// ---------- 暂无数据自定义 ----------
@property (nonatomic, copy) NSString *nodImgName;// 图片
@property (nonatomic, copy) NSString *nodText;// 文案
@property (nonatomic, strong) UIColor *nodColor;// 字体颜色
@property (nonatomic, strong) UIFont *nodFont;// 字体字号

@end

NS_ASSUME_NONNULL_END
