//
//  AASeriesElement.m
//  AAChartKit
//
//  Created by An An on 17/1/19.
//  Copyright © 2017年 An An. xAll rights reserved.
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


#import "AASeriesElement.h"

AAChartZoneAxisType const AAChartZoneAxisTypeX = @"x";
AAChartZoneAxisType const AAChartZoneAxisTypeY = @"y";

AAChartLineStepType const AAChartLineStepTypeLeft   = @"left";
AAChartLineStepType const AAChartLineStepTypeCenter = @"center";
AAChartLineStepType const AAChartLineStepTypeRight  = @"right";

@implementation AASeriesElement

- (instancetype)init {
    self = [super init];
    if (self) {
        _allowPointSelect = false;
        _showInLegend = true;
        _visible = true;
        _clip = true;
    }
    return self;
}

AAPropSetFuncImplementation(AASeriesElement, NSString *, type) 
AAPropSetFuncImplementation(AASeriesElement, BOOL      , allowPointSelect) //是否允许在点击数据点标记（markers）、柱子（柱形图）、扇区（饼图）时选中该点，选中的点可以通过 Chart.getSelectedPoints 来获取。 默认是：false.
AAPropSetFuncImplementation(AASeriesElement, NSString *, name) 
AAPropSetFuncImplementation(AASeriesElement, NSArray  *, data)
AAPropSetFuncImplementation(AASeriesElement, NSArray  *, nodes) 
AAPropSetFuncImplementation(AASeriesElement, NSString *, color)
AAPropSetFuncImplementation(AASeriesElement, NSArray  *, colors)
AAPropSetFuncImplementation(AASeriesElement, id        , colorByPoint) //When using automatic point colors pulled from the options.colors collection, this option determines whether the chart should receive one color per series or one color per point. 默认是：false.
AAPropSetFuncImplementation(AASeriesElement, AAMarker *, marker) 
AAPropSetFuncImplementation(AASeriesElement, NSString *, stacking) 
AAPropSetFuncImplementation(AASeriesElement, NSString *, dashStyle) 
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, threshold) 
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, lineWidth) //折线图、曲线图、直方折线图、折线填充图、曲线填充图、直方折线填充图的线条宽度
AAPropSetFuncImplementation(AASeriesElement, NSString *, borderColor) //The border color, It is only valid for column, bar, pie, columnrange, pyramid and funnel chart types
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderWidth) //The border width, It is only valid for column, bar, pie, columnrange, pyramid and funnel chart types
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderRadius) //The corner radius of the border surrounding each column or bar.
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderRadiusTopLeft)
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderRadiusTopRight)
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderRadiusBottomLeft)
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, borderRadiusBottomRight)
AAPropSetFuncImplementation(AASeriesElement, NSString *, fillColor) //折线填充图、曲线填充图、直方折线填充图等填充图类型的填充颜色
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, fillOpacity) //折线填充图、曲线填充图、直方折线填充图等填充图类型的填充颜色透明度
AAPropSetFuncImplementation(AASeriesElement, NSString *, negativeColor)  //The color for the parts of the graph or points that are below the threshold
AAPropSetFuncImplementation(AASeriesElement, NSString *, negativeFillColor)//A separate color for the negative part of the area.
AAPropSetFuncImplementation(AASeriesElement, NSString *, innerSize) 
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, size) 
AAPropSetFuncImplementation(AASeriesElement, NSArray  *, keys) 
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, yAxis) 
AAPropSetFuncImplementation(AASeriesElement, AADataLabels*, dataLabels) 
AAPropSetFuncImplementation(AASeriesElement, id        , step) //是否转变为直方折线图
AAPropSetFuncImplementation(AASeriesElement, AAStates *, states)
AAPropSetFuncImplementation(AASeriesElement, BOOL      , showInLegend) //Whether to display this particular series or series type in the legend. The default value is true for standalone series, false for linked series. 默认是：true.
AAPropSetFuncImplementation(AASeriesElement, BOOL      , visible) //数据列是否显示的状态,可以通过 series.show()、series.hide()、series.setVisible 来改变这个属性
AAPropSetFuncImplementation(AASeriesElement, NSArray<AAZonesElement *>*, zones)
AAPropSetFuncImplementation(AASeriesElement, AAChartZoneAxisType, zoneAxis) //Defines the Axis on which the zones are applied. 默认是：y.
AAPropSetFuncImplementation(AASeriesElement, AAShadow *, shadow) //数据列的阴影效果。从 2.3 开始阴影可以配置成包含 color、offsetX、offsetY、opacity 和 width 属性的对象形式。 默认是：false
AAPropSetFuncImplementation(AASeriesElement, NSString *, stack)
AAPropSetFuncImplementation(AASeriesElement, AATooltip*, tooltip)
AAPropSetFuncImplementation(AASeriesElement, NSNumber *, zIndex) //层叠，series element 在图表中显示的层叠级别，值越大，显示越向前
AAPropSetFuncImplementation(AASeriesElement, NSString *, pointPlacement)
AAPropSetFuncImplementation(AASeriesElement, id        , enableMouseTracking)
AAPropSetFuncImplementation(AASeriesElement, AADataSorting *, dataSorting)
AAPropSetFuncImplementation(AASeriesElement, id        , reversed) //Only useful for pyramid chart and funnel chart
AAPropSetFuncImplementation(AASeriesElement, NSString *, id)
AAPropSetFuncImplementation(AASeriesElement, id        , connectNulls)
AAPropSetFuncImplementation(AASeriesElement, id        , enabledCrosshairs)
AAPropSetFuncImplementation(AASeriesElement, BOOL      , clip)

@end


@implementation AADataElement

AAPropSetFuncImplementation(AADataElement, NSString *, color)
AAPropSetFuncImplementation(AADataElement, AADataLabels *, dataLabels)
AAPropSetFuncImplementation(AADataElement, AAMarker *, marker)
AAPropSetFuncImplementation(AADataElement, NSString *, name)
AAPropSetFuncImplementation(AADataElement, NSNumber *, x)
AAPropSetFuncImplementation(AADataElement, NSNumber *, y)
AAPropSetFuncImplementation(AADataElement, id,         selected)

@end


@implementation AAZonesElement : NSObject

AAPropSetFuncImplementation(AAZonesElement, NSNumber *, value)
AAPropSetFuncImplementation(AAZonesElement, NSString *, color)
AAPropSetFuncImplementation(AAZonesElement, NSString *, fillColor)
AAPropSetFuncImplementation(AAZonesElement, NSString *, dashStyle)

@end


@implementation AADataSorting : NSObject

AAPropSetFuncImplementation(AADataSorting, BOOL, enabled)
AAPropSetFuncImplementation(AADataSorting, BOOL, matchByName)

@end
