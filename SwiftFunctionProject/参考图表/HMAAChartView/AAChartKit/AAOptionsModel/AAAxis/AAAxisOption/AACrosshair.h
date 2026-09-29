//
//  AAXAxis.h
//  AAChartKit
//
//  Created by An An on 17/1/5.
//  Copyright © 2017年 An An. All rights reserved.
//*************** ...... SOURCE CODE ...... ***************
//***...................................................***
//*** https://github.com/AAChartModel/AAChartKit        ***
//*** https://github.com/AAChartModel/AAChartKit-Swift  ***
//***...................................................***
//*************** ...... SOURCE CODE ...... ***************

/*
 
 * -------------------------------------------------------------------------------
 *
 * 🌕 🌖 🌗 🌘  ❀❀❀   WARM TIPS!!!   ❀❀❀ 🌑 🌒 🌓 🌔
 *
 * Please contact me on GitHub,if there are any problems encountered in use.
 * GitHub Issues : https://github.com/AAChartModel/AAChartKit/issues
 * -------------------------------------------------------------------------------
 * And if you want to contribute for this project, please contact me as well
 * GitHub        : https://github.com/AAChartModel
 * StackOverflow : https://stackoverflow.com/users/12302132/codeforu
 * JianShu       : https://www.jianshu.com/u/f1e6753d4254
 * SegmentFault  : https://segmentfault.com/u/huanghunbieguan
 *
 * -------------------------------------------------------------------------------
 
 */

#import <Foundation/Foundation.h>
#import "AAGlobalMacro.h"

@interface AACrosshair : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AACrosshair, NSString *, dashStyle)  //准星线样式
AAPropStatementAndPropSetFuncStatement(copy,   AACrosshair, NSString *, color)  //准星线颜色
AAPropStatementAndPropSetFuncStatement(strong, AACrosshair, NSNumber *, width)  //准星线宽度
AAPropStatementAndPropSetFuncStatement(strong, AACrosshair, NSNumber *, zIndex)  //准星线的层叠值, 增大层叠值可以让准星线显示在数据里或网格线的上方。 默认是：2.

+ (AACrosshair *)crosshairWithWidth:(NSNumber *)width;

+ (AACrosshair *)crosshairWithColor:(NSString *)color;

+ (AACrosshair *)crosshairWithColor:(NSString *)color
                          dashStyle:(NSString *)dashStyle;

+ (AACrosshair *)crosshairWithColor:(NSString *)color
                          dashStyle:(NSString *)dashStyle
                              width:(NSNumber *)width;

+ (AACrosshair *)crosshairWithColor:(NSString *)color
                          dashStyle:(NSString *)dashStyle
                              width:(NSNumber *)width
                             zIndex:(NSNumber *)zIndex;

@end

