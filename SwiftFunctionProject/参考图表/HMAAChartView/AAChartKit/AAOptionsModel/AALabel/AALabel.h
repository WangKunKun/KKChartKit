//
//  AALabel.h
//  AAChartKitDemo
//
//  Created by AnAn on 2018/12/30.
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

#import <Foundation/Foundation.h>
#import "AAGlobalMacro.h"
@class AAStyle;

@interface AALabel : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AALabel, NSString *, align)//标签的对齐方式，可用的值有 "left"、"center" 及 "right"。默认值是根据坐标轴的位置（在图表中的位置）即标签的旋转角度进行智能判断的。 默认是：center.
AAPropStatementAndPropSetFuncStatement(strong, AALabel, NSNumber *, rotation)//标签的旋转角度 默认是：0.
AAPropStatementAndPropSetFuncStatement(copy,   AALabel, NSString *, text)//文字
AAPropStatementAndPropSetFuncStatement(copy,   AALabel, NSString *, textAlign)//文字对齐
AAPropStatementAndPropSetFuncStatement(assign, AALabel, BOOL      , useHTML)//HTML渲染
AAPropStatementAndPropSetFuncStatement(copy,   AALabel, NSString *, verticalAlign)//竖直对齐
AAPropStatementAndPropSetFuncStatement(strong, AALabel, AAStyle  *, style)//轴标签的 CSS 样式
AAPropStatementAndPropSetFuncStatement(strong, AALabel, NSNumber *, x)//水平偏移
AAPropStatementAndPropSetFuncStatement(strong, AALabel, NSNumber *, y)// 竖直偏移
AAPropStatementAndPropSetFuncStatement(copy,   AALabel, NSString *, formatter)


@end
