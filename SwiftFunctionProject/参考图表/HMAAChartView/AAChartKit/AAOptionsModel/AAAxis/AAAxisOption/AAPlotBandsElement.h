//
//  AAPlotBandsElement.h
//  AAChartKitDemo
//
//  Created by AnAn on 2018/12/23.
//  Copyright © 2018 An An. All rights reserved.
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

//borderColor: null
//borderWidth: 边框宽度
//className: 类名
//color: 样式
//events: 事件
//from: 开始值
//id: 编号
//innerRadius: null
//label: {标签}
//outerRadius: 100%
//thickness: 10
//to: 结束值
//zIndex

#import <Foundation/Foundation.h>
#import "AAGlobalMacro.h"

@class AALabel;

@interface AAPlotBandsElement : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AAPlotBandsElement, NSString *, borderColor)
AAPropStatementAndPropSetFuncStatement(strong, AAPlotBandsElement, NSNumber *, borderWidth)
AAPropStatementAndPropSetFuncStatement(copy,   AAPlotBandsElement, NSString *, className)
AAPropStatementAndPropSetFuncStatement(copy,   AAPlotBandsElement, NSString *, color)
AAPropStatementAndPropSetFuncStatement(strong, AAPlotBandsElement, NSNumber *, from)
AAPropStatementAndPropSetFuncStatement(strong, AAPlotBandsElement, AALabel  *, label)
AAPropStatementAndPropSetFuncStatement(strong, AAPlotBandsElement, NSNumber *, to)
AAPropStatementAndPropSetFuncStatement(assign, AAPlotBandsElement, NSUInteger , zIndex)

@end
