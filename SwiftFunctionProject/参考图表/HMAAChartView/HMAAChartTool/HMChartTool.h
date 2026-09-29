//
//  HMChartTool.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HMAASeries.h"

typedef enum : NSUInteger {
    HMChartColorTypePrimaryText,
    HMChartColorTypeSecondText,
    HMChartColorTypeThirdText,
    HMChartColorTypeDivider,
    HMChartColorTypeBackground2,
} HMChartColorType;

NS_ASSUME_NONNULL_BEGIN

@interface HMChartTool : NSObject

// 根据深浅模式调整颜色
+ (NSString *)colorHexWithChartColorType:(HMChartColorType)type traitCollection:(UITraitCollection *)traitCollection;

// 颜色转换
+ (UIColor *)colorWithHexString:(NSString *)hexString;

//改变UIlabel里面某些字符串的颜色 fontMode:字体样式
+ (void)messageAction:(UILabel *)theLab changeString:(NSString *)change andMarkColor:(UIColor *)markColor andMarkFondSize:(float)fontSize fontMode:(UIFontWeight)fontMode;

// 计算当前图例所需要的高度
+ (CGFloat)heightForLegendWithData:(NSArray *)seriesArray maxWidth:(CGFloat)maxWidth;

// 单位字符串映射单位枚举
+ (HMAAElementUnitType)typeWithUnit:(NSString *)unit;

@end

NS_ASSUME_NONNULL_END
