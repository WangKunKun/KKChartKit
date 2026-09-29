//
//  HMAAPlotLinesElement.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/2.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HMAAPlotLinesElement : NSObject

@property (nonatomic, copy) NSString *color;//颜色值(16进制)
/**
 AAChartLineDashStyleType const AAChartLineDashStyleTypeSolid           = @"Solid";           //———————————————————————————————————
 AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDash       = @"ShortDash";       //— — — — — — — — — — — — — — — — — —
 AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDot        = @"ShortDot";        //ⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈ
 AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDashDot    = @"ShortDashDot";    //—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧
 AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDashDotDot = @"ShortDashDotDot"; //—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧
 AAChartLineDashStyleType const AAChartLineDashStyleTypeDot             = @"Dot";             //‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧
 AAChartLineDashStyleType const AAChartLineDashStyleTypeDash            = @"Dash";            //—— —— —— —— —— —— —— —— —— —— —— ——
 AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDash        = @"LongDash";        //——— ——— ——— ——— ——— ——— ——— ——— ———
 AAChartLineDashStyleType const AAChartLineDashStyleTypeDashDot         = @"DashDot";         //——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧
 AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDashDot     = @"LongDashDot";     //———‧———‧———‧———‧———‧———‧———‧———‧———‧
 AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDashDotDot  = @"LongDashDotDot";  //———‧‧———‧‧———‧‧———‧‧———‧‧———‧‧———‧‧
 */
@property (nonatomic, copy) NSString *dashStyle;//样式：Dash,Dot,Solid等,默认Solid
@property (nonatomic, strong) NSNumber *width;//标示线宽
@property (nonatomic, strong) NSNumber *value;//标示线位置
@property (nonatomic, strong) NSNumber *zIndex;//层叠,标示线在图表中显示的层叠级别，值越大，显示越向前
@property (nonatomic, copy) NSString *text;//标示线名称
@property (nonatomic, copy) NSString *textColor;//标示线名称颜色
@property (nonatomic, copy) NSString *textDarkColor;//标示线名称颜色深色
@property (nonatomic, copy) NSString *fontSize;//标示线名称字号

@end

NS_ASSUME_NONNULL_END
