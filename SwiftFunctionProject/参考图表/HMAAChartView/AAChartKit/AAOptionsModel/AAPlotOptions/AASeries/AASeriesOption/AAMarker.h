//
//  AAMarker.h
//  AAChartKit
//
//  Created by An An on 17/1/20.
//  Copyright © 2017年 An An. All rights reserved.
//
//*************** ...... SOURCE CODE ...... ***************
//***...................................................***
//*** https://github.com/AAChartModel/AAChartKit        ***
//*** https://github.com/AAChartModel/AAChartKit-Swift  ***
//***...................................................***
//*************** ...... SOURCE CODE ...... ***************
//

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

@class AAMarkerStates, AAMarkerHover, AAMarkerSelect;

@interface AAMarker : NSObject

AAPropStatementAndPropSetFuncStatement(assign, AAMarker, BOOL,       enabled)
AAPropStatementAndPropSetFuncStatement(strong, AAMarker, NSNumber *, radius) 
AAPropStatementAndPropSetFuncStatement(copy,   AAMarker, NSString *, symbol) 
AAPropStatementAndPropSetFuncStatement(copy,   AAMarker, NSString *, fillColor) //点的填充色(用来设置折线连接点的填充色)
AAPropStatementAndPropSetFuncStatement(strong, AAMarker, NSNumber *, lineWidth) //外沿线的宽度(用来设置折线连接点的轮廓描边的宽度)
AAPropStatementAndPropSetFuncStatement(copy,   AAMarker, NSString *, lineColor) //外沿线的颜色(用来设置折线连接点的轮廓描边颜色，当值为空字符串时，默认取数据点或数据列的颜色。)
AAPropStatementAndPropSetFuncStatement(strong, AAMarker, AAMarkerStates *,  states)
AAPropStatementAndPropSetFuncStatement(strong, AAMarker, NSNumber *,  width)
AAPropStatementAndPropSetFuncStatement(strong, AAMarker, NSNumber *,  height)

@end


@interface AAMarkerStates : NSObject

AAPropStatementAndPropSetFuncStatement(strong, AAMarkerStates, AAMarkerHover  *, hover)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerStates, AAMarkerSelect *, select)

@end


@interface AAMarkerHover : NSObject

AAPropStatementAndPropSetFuncStatement(assign, AAMarkerHover, BOOL,       enabled)
AAPropStatementAndPropSetFuncStatement(copy,   AAMarkerHover, NSString *, fillColor)
AAPropStatementAndPropSetFuncStatement(copy,   AAMarkerHover, NSString *, lineColor)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerHover, NSNumber *, lineWidth)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerHover, NSNumber *, lineWidthPlus)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerHover, NSNumber *, radius)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerHover, NSNumber *, radiusPlus)

@end


@interface AAMarkerSelect : NSObject

AAPropStatementAndPropSetFuncStatement(assign, AAMarkerSelect, BOOL,       enabled)
AAPropStatementAndPropSetFuncStatement(copy,   AAMarkerSelect, NSString *, fillColor)
AAPropStatementAndPropSetFuncStatement(copy,   AAMarkerSelect, NSString *, lineColor)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerSelect, NSNumber *, lineWidth)
AAPropStatementAndPropSetFuncStatement(strong, AAMarkerSelect, NSNumber *, radius)

@end



