//
//  HMChartTool.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import "HMChartTool.h"
#import "HMAASeries.h"

@implementation HMChartTool

+ (NSString *)colorHexWithChartColorType:(HMChartColorType)type traitCollection:(UITraitCollection *)traitCollection {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        switch (type) {
            case HMChartColorTypePrimaryText:
                return @"FFFFFF";
            case HMChartColorTypeSecondText:
                return @"B3B3B3";
            case HMChartColorTypeThirdText:
                return @"808080";
            case HMChartColorTypeDivider:
                return @"494F59";
            case HMChartColorTypeBackground2:
                return @"262B32";
            default:
                break;
        }
    } else {
        switch (type) {
            case HMChartColorTypePrimaryText:
                return @"141414";
            case HMChartColorTypeSecondText:
                return @"64686F";
            case HMChartColorTypeThirdText:
                return @"A1A7B2";
            case HMChartColorTypeDivider:
                return @"D8DDE4";
            case HMChartColorTypeBackground2:
                return @"FFFFFF";
            default:
                break;
        }
    }
    return @"";
}

// 颜色转换
+ (UIColor *)colorWithHexString:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    
    if (cleanString.length == 6) {
        cleanString = [cleanString stringByAppendingString:@"FF"]; // 添加默认Alpha值
    }
    
    if (cleanString.length != 8) return [UIColor blackColor];
    
    unsigned int rgba;
    [[NSScanner scannerWithString:cleanString] scanHexInt:&rgba];
    
    return [UIColor colorWithRed:((rgba >> 24) & 0xFF) / 255.0f
                           green:((rgba >> 16) & 0xFF) / 255.0f
                            blue:((rgba >> 8) & 0xFF) / 255.0f
                           alpha:((rgba) & 0xFF) / 255.0f];
}

//改变UIlabel里面某些字符串的颜色 fontMode:字体样式
+ (void)messageAction:(UILabel *)theLab changeString:(NSString *)change andMarkColor:(UIColor *)markColor andMarkFondSize:(float)fontSize fontMode:(UIFontWeight)fontMode {
    NSString *tempStr = theLab.text;
    NSMutableAttributedString *strAtt = [[NSMutableAttributedString alloc] initWithString:tempStr];
    [strAtt addAttribute:NSForegroundColorAttributeName value:theLab.textColor range:NSMakeRange(0, [strAtt length])];
    NSRange markRange = [tempStr rangeOfString:change];
    if (markColor == nil) {
        [strAtt addAttribute:NSForegroundColorAttributeName value:theLab.textColor range:markRange];
    }else {
        [strAtt addAttribute:NSForegroundColorAttributeName value:markColor range:markRange];
    }
    [strAtt addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:fontSize weight:fontMode] range:markRange];
    theLab.attributedText = strAtt;
}

// 计算当前图例所需要的高度
+ (CGFloat)heightForLegendWithData:(NSArray *)seriesArray maxWidth:(CGFloat)maxWidth {
    CGFloat legendHeight = 0;
    NSInteger row = seriesArray.count;
    // 绘制按钮
    if (seriesArray.count > 1) {
        int t = 0;
        for (int i = 0; i < seriesArray.count; i++) {
            HMAASeries *series = seriesArray[i];
            CGFloat lastWidth = 6;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                CGSize size = [element.name boundingRectWithSize:CGSizeZero options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium]} context:nil].size;
                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
                if (lastWidth + viewWidth > maxWidth) {
                    t ++;
                    lastWidth = 6;
                }
                lastWidth += viewWidth + 12;
            }
        }
        row += t;
    } else {
        HMAASeries *series = seriesArray.firstObject;
        if (series.element.count > 1) {
            CGFloat lastWidth = 6;
            int t = 0;
            for (int j = 0; j < series.element.count; j++) {
                HMAASeriesElement *element = series.element[j];
                CGSize size = [element.name boundingRectWithSize:CGSizeZero options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium]} context:nil].size;
                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
                if (lastWidth + viewWidth > maxWidth) {
                    t ++;
                    lastWidth = 6;
                }
                lastWidth += viewWidth + 12;
            }
            row += t;
        }
    }
    legendHeight = row * (24 + 12) - 12;
    return legendHeight;
}


static NSDictionary * UnitKeyValues = @{
    @"":@(HMAAElementUnitType_NONE),
    @"W":@(HMAAElementUnitType_W),
    @"A":@(HMAAElementUnitType_A),
    @"V":@(HMAAElementUnitType_V),
    @"Hz":@(HMAAElementUnitType_HZ),
    @"%":@(HMAAElementUnitType_PAH),
    @"Wh":@(HMAAElementUnitType_Wh),
    @"h":@(HMAAElementUnitType_H),
    @"Var":@(HMAAElementUnitType_VAR),
    @"min":@(HMAAElementUnitType_MIN),
    @"℃":@(HMAAElementUnitType_T),
    @"VA":@(HMAAElementUnitType_VA),
    @"Ω":@(HMAAElementUnitType_OM),
    @"Bar":@(HMAAElementUnitType_BAR),
    @"RH":@(HMAAElementUnitType_RH),
};

// 单位字符串映射单位枚举
+ (HMAAElementUnitType)typeWithUnit:(NSString *)unit {
    NSNumber * number = UnitKeyValues[unit];
    return number ? [number intValue] : HMAAElementUnitType_OTHER;
}

@end
