//
//  AAColumnrange.h
//  AAChartKitDemo
//
//  Created by An An on 2021/7/20.
//  Copyright © 2021 An An. All rights reserved.
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

@class AADataLabels;

@interface AAColumnrange : NSObject

AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, NSNumber *,     borderRadius)
AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, NSNumber *,     borderWidth)
AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, AADataLabels *, dataLabels)
AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, NSNumber *,     groupPadding) //Padding between each value groups, in x axis units. default：0.2.
AAPropStatementAndPropSetFuncStatement(assign, AAColumnrange, BOOL,           grouping) //Whether to group non-stacked columns or to let them render independent of each other. Non-grouped columns will be laid out individually and overlap each other. default：true.
AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, NSNumber *,     pointPadding) //Padding between each column or bar, in x axis units. default：0.1.
AAPropStatementAndPropSetFuncStatement(strong, AAColumnrange, NSNumber *,     pointPlacement) //Padding between each column or bar, in x axis units. default：0.1.


@end

