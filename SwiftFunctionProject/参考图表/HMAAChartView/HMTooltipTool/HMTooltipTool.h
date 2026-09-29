//
//  HMTooltipTool.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/11/18.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HMTooltip.h"
#import "HMIconTooltip.h"

NS_ASSUME_NONNULL_BEGIN

@class HMAAChartModel, AATooltip;
@interface HMTooltipTool : NSObject

@property (nonatomic, strong) HMAAChartModel *chartModel;

// 创建js版本AATooltip
- (AATooltip *)createAATooltip;

// 创建原生版本的Tooltip
- (HMTooltip *)createNATooltip;

// 创建ver2版本的Tooltip
- (HMIconTooltip *)createIconTooltip;

@end

NS_ASSUME_NONNULL_END
