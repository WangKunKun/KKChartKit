//
//  AATitle.h
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

@class AAStyle;

@interface AATitle : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AATitle, NSString *, text) 
AAPropStatementAndPropSetFuncStatement(strong, AATitle, AAStyle  *, style) 
AAPropStatementAndPropSetFuncStatement(copy,   AATitle, NSString *, align)
AAPropStatementAndPropSetFuncStatement(copy,   AATitle, NSString *, verticalAlign)
AAPropStatementAndPropSetFuncStatement(strong, AATitle, NSNumber *, x)//标题相对于水平对齐的偏移量，取值范围为：图表左边距到图表右边距，可以是负值，单位px。 默认是：0.
AAPropStatementAndPropSetFuncStatement(strong, AATitle, NSNumber *, y) //标题相对于垂直对齐的偏移量，取值范围：图表的上边距（chart.spacingTop ）到图表的下边距（chart.spacingBottom），可以是负值，单位是px。默认值和字体大小有关。
AAPropStatementAndPropSetFuncStatement(assign, AATitle, BOOL      , useHTML) //是否 使用HTML渲染标题。 默认是：false.

@end


@class AAStyle;

@interface AASubtitle : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AASubtitle, NSString *, text)
AAPropStatementAndPropSetFuncStatement(copy,   AASubtitle, NSString *, align)
AAPropStatementAndPropSetFuncStatement(strong, AASubtitle, AAStyle  *, style)

@end
