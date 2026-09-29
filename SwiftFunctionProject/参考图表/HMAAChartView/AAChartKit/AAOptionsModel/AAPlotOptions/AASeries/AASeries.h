//
//  AASeries.h
//  AAChartKit
//
//  Created by An An on 17/1/5.
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

@class AAMarker, AAAnimation, AAShadow, AADataLabels, AASeriesEvents, AAStates, AAPoint;

@interface AASeries : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AASeries, NSString     *, borderColor) //The border color, It is only valid for column, bar, pie, columnrange, pyramid and funnel chart types
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderWidth) //The border width, It is only valid for column, bar, pie, columnrange, pyramid and funnel chart types
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderRadius) //The corner radius of the border surrounding each column or bar.
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderRadiusTopLeft)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderRadiusTopRight)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderRadiusBottomLeft)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber     *, borderRadiusBottomRight)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AAMarker     *, marker) 
AAPropStatementAndPropSetFuncStatement(copy,   AASeries, NSString     *, stacking) 
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AAAnimation  *, animation) 
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSArray      *, keys) 
//colorByPoint 决定了图表是否给每个数据列或每个点分配一个颜色，默认值是 false， 即默认是给每个数据类分配颜色，
//AAPropStatementAndPropSetFuncStatement(assign, AASeries, BOOL , colorByPoint) //设置为 true 则是给每个点分配颜色。
//plotOptions.series.connectNulls
//https://www.zhihu.com/question/24173311
AAPropStatementAndPropSetFuncStatement(assign, AASeries, BOOL ,          connectNulls) //设置折线是否断点重连
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AASeriesEvents *, events)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AAShadow *, shadow)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AADataLabels *, dataLabels)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AAStates *, states)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, id        , allowPointSelect) //折线图的曲线宽度，默认是：0
AAPropStatementAndPropSetFuncStatement(strong, AASeries, AAPoint  *, point)
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber *, pointWidth) //柱状图, 条形图, 柱形范围图, 瀑布图, 箱线图(盒须图)直接设置单个图形元素的宽度
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber *, maxPointWidth) //柱状图, 条形图, 柱形范围图, 瀑布图, 箱线图(盒须图)直接设置单个图形元素的最大宽度
AAPropStatementAndPropSetFuncStatement(strong, AASeries, NSNumber *, minPointLength) //柱状图, 条形图, 柱形范围图, 瀑布图, 箱线图(盒须图)直接设置单个图形元素的最小高度

@end


@interface AASeriesEvents : NSObject

AAPropStatementAndPropSetFuncStatement(copy, AASeriesEvents, NSString *, click)
AAPropStatementAndPropSetFuncStatement(copy, AASeriesEvents, NSString *, mouseOver)
AAPropStatementAndPropSetFuncStatement(copy, AASeriesEvents, NSString *, mouseOut)
AAPropStatementAndPropSetFuncStatement(copy, AASeriesEvents, NSString *, legendItemClick)

@end


@class AAPointEvents;

@interface AAPoint : NSObject

AAPropStatementAndPropSetFuncStatement(strong, AAPoint, AAPointEvents *, events)

@end


@interface AAPointEvents : NSObject

AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, click) //点击事件
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, mouseOut) //鼠标划出
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, mouseOver) //鼠标划过
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, remove) //删除
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, select) //选中
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, unselect) //取消选中
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, update) //更新
AAPropStatementAndPropSetFuncStatement(copy, AAPointEvents, NSString *, legendItemClick) //图例点击事件

@end

