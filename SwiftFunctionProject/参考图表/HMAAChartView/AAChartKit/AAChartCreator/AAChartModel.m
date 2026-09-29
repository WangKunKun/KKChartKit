
//
//  AAChartModel.m
//  AAChartKit
//
//  Created by An An on 17/1/20.
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

#import "AAChartModel.h"

AAChartType const AAChartTypeColumn          = @"column";          //柱形图
AAChartType const AAChartTypeBar             = @"bar";             //柱形图
AAChartType const AAChartTypeArea            = @"area";            //折线区域填充图
AAChartType const AAChartTypeAreaspline      = @"areaspline";      //曲线区域填充图
AAChartType const AAChartTypeLine            = @"line";            //折线图
AAChartType const AAChartTypeSpline          = @"spline";          //曲线图
AAChartType const AAChartTypeScatter         = @"scatter";         //散点图
AAChartType const AAChartTypePie             = @"pie";             //扇形图
AAChartType const AAChartTypeBubble          = @"bubble";          //气泡图
AAChartType const AAChartTypePyramid         = @"pyramid";         //金字塔图
AAChartType const AAChartTypeFunnel          = @"funnel";          //漏斗图
AAChartType const AAChartTypeColumnrange     = @"columnrange";     //柱形范围图
AAChartType const AAChartTypeArearange       = @"arearange";       //区域折线范围图
AAChartType const AAChartTypeAreasplinerange = @"areasplinerange"; //区域曲线范围图
AAChartType const AAChartTypeBoxplot         = @"boxplot";         //箱线图
AAChartType const AAChartTypeWaterfall       = @"waterfall";       //瀑布图
AAChartType const AAChartTypePolygon         = @"polygon";         //多边形图
AAChartType const AAChartTypeGauge           = @"gauge";           //仪表图
AAChartType const AAChartTypeErrorbar        = @"errorbar";        //误差图
AAChartType const AAChartTypeSankey          = @"sankey";        //桑基图

AAChartLayoutType const AAChartLayoutTypeHorizontal = @"horizontal"; //水平布局
AAChartLayoutType const AAChartLayoutTypeVertical   = @"vertical";   //垂直布局

AAChartAlignType const AAChartAlignTypeLeft   = @"left";   //位于左边
AAChartAlignType const AAChartAlignTypeCenter = @"center"; //位于中间
AAChartAlignType const AAChartAlignTypeRight  = @"right";  //位于右边

AAChartVerticalAlignType const AAChartVerticalAlignTypeTop    = @"top";    //垂直方向上位于顶部
AAChartVerticalAlignType const AAChartVerticalAlignTypeMiddle = @"middle"; //垂直方向上位于中间
AAChartVerticalAlignType const AAChartVerticalAlignTypeBottom = @"bottom"; //垂直方向上位于底部

AAChartZoomType const AAChartZoomTypeNone = @"none"; //禁用缩放 (默认)
AAChartZoomType const AAChartZoomTypeX    = @"x";    //仅仅支持 X 轴缩放
AAChartZoomType const AAChartZoomTypeY    = @"y";    //仅仅支持 Y 轴缩放
AAChartZoomType const AAChartZoomTypeXY   = @"xy";   //X 轴和 Y 轴均可缩放

AAChartStackingType const AAChartStackingTypeFalse   = @"";        //禁用堆积效果 (默认)
AAChartStackingType const AAChartStackingTypeNormal  = @"normal";  //常规堆积效果
AAChartStackingType const AAChartStackingTypePercent = @"percent"; //百分比堆积效果

AAChartSymbolType const AAChartSymbolTypeCircle        = @"circle";        //◉ ◉ ◉
AAChartSymbolType const AAChartSymbolTypeSquare        = @"square";        //■ ■ ■
AAChartSymbolType const AAChartSymbolTypeDiamond       = @"diamond";       //◆ ◆ ◆
AAChartSymbolType const AAChartSymbolTypeTriangle      = @"triangle";      //▲ ▲ ▲
AAChartSymbolType const AAChartSymbolTypeTriangle_down = @"triangle-down"; //▼ ▼ ▼

AAChartSymbolStyleType const AAChartSymbolStyleTypeDefault     = @"default";     //symbol 为默认样式
AAChartSymbolStyleType const AAChartSymbolStyleTypeInnerBlank  = @"innerBlank";  //symbol 为内部空白样式
AAChartSymbolStyleType const AAChartSymbolStyleTypeBorderBlank = @"borderBlank"; //symbol 为外部空白样式

AAChartFontWeightType const AAChartFontWeightTypeThin     = @"thin";    //纤细字体
AAChartFontWeightType const AAChartFontWeightTypeRegular  = @"regular"; //常规字体
AAChartFontWeightType const AAChartFontWeightTypeBold     = @"bold";    //加粗字体

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

@implementation AAChartModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _title                 = @""; //标题默认不显示
        _subtitle              = @""; //副标题默认不显示
        _chartType             = AAChartTypeColumn; //默认图表类型为柱状图
        _animationType         = AAChartAnimationLinear; //默认使用非easing.js中的'linear'线性渐变效果
        _animationDuration     = @800; //默认动画时长为800毫秒
        _stacking              = AAChartStackingTypeFalse; //默认不开启图表数据的堆积效果
        _zoomType              = AAChartZoomTypeNone; //默认禁用图表的手势缩放功能
        _colorsTheme           = @[@"#1e90ff", @"#ef476f", @"#ffd066", @"#04d69f", @"#25547c"];//默认颜色主题
        _tooltipEnabled        = YES; //默认启用浮动提示框
        _tooltipShared         = YES; //默认多组数据共享一个浮动提示框
        _xAxisLabelsEnabled    = YES; //默认显示 X 轴坐标点文字
        _xAxisVisible          = YES; //X 轴默认可见
        _yAxisTitle            = @""; //Y 轴标题默认不显示
        _yAxisVisible          = YES; //Y 轴默认可见
        _yAxisLabelsEnabled    = YES; //Y 轴文字标签默认显示
        _yAxisLineWidth        = @0.5; //Y 轴轴线的宽度
        _legendEnabled         = YES; //图例(图表下方可点击的带有文字的小圆点)默认显示
        _borderRadius          = @0; //柱状图长条图头部圆角半径(可用于设置头部的形状,仅对条形图,柱状图有效,设置为1000时,柱形图或者条形图头部为楔形)
        _markerRadius          = @5; //折线连接点的半径长度,如果值设置为0,这样就相当于不显示了
        _yAxisAllowDecimals    = YES; //Y 轴默认允许显示小数
    }
    return self;
}

AAPropSetFuncImplementation(AAChartModel, NSString *, title) //标题内容
AAPropSetFuncImplementation(AAChartModel, AAStyle  *, titleStyle) //标题文字样式

AAPropSetFuncImplementation(AAChartModel, NSString *, subtitle) //副标题内容
AAPropSetFuncImplementation(AAChartModel, AAStyle  *, subtitleStyle) //副标题文字样式
AAPropSetFuncImplementation(AAChartModel, AAChartAlignType, subtitleAlign) //图表副标题文本水平对齐方式。可选的值有 “left”，”center“和“right”。 默认是：center.

AAPropSetFuncImplementation(AAChartModel, NSString *, backgroundColor) //图表背景色(必须为十六进制的颜色色值如红色"#FF0000")
AAPropSetFuncImplementation(AAChartModel, NSArray  *, colorsTheme) //图表主题颜色数组
AAPropSetFuncImplementation(AAChartModel, NSArray     <NSString *>*, categories) //X轴坐标每个点对应的名称(注意:这个不是用来设置 X 轴的值,仅仅是用于设置 X 轴文字内容的而已)
AAPropSetFuncImplementation(AAChartModel, NSArray  *, series) //图表的数据列内容

AAPropSetFuncImplementation(AAChartModel, AAChartType,            chartType) //图表类型
AAPropSetFuncImplementation(AAChartModel, AAChartStackingType,    stacking) //堆积样式
AAPropSetFuncImplementation(AAChartModel, AAChartSymbolType,      markerSymbol) //折线曲线连接点的类型："circle ◉ ", "square ■ ", "diamond ◆ ", "triangle ▲ ","triangle-down ▼ "，AAPr是"circle  ◉ "
AAPropSetFuncImplementation(AAChartModel, AAChartSymbolStyleType, markerSymbolStyle)
AAPropSetFuncImplementation(AAChartModel, AAChartZoomType,        zoomType) //缩放类型 AAChartZoomTypeX 表示可沿着 X 轴进行手势缩放
AAPropSetFuncImplementation(AAChartModel, AAChartAnimation,       animationType) //设置图表的渲染动画类型
AAPropSetFuncImplementation(AAChartModel, NSNumber *, animationDuration) //设置图表的渲染动画时长(动画单位为毫秒)
AAPropSetFuncImplementation(AAChartModel, BOOL,       inverted) //X 轴是否垂直,默认为否
AAPropSetFuncImplementation(AAChartModel, BOOL,       polar) //是否极化图形(变为雷达图),默认为否
AAPropSetFuncImplementation(AAChartModel, NSArray  *, margin) //图表外边缘和绘图区域之间的边距。 数组中的数字分别表示顶部，右侧，底部和左侧 ([👆,👉,👇,👈])。 也可以使用 AAChart 对象的 marginTop，marginRight，marginBottom 和 marginLeft 来设置某一个方向的边距。默认值为[null]

AAPropSetFuncImplementation(AAChartModel, BOOL,       dataLabelsEnabled) //是否显示数据,默认为否
AAPropSetFuncImplementation(AAChartModel, AAStyle  *, dataLabelsStyle) //dataLabels文字样式

AAPropSetFuncImplementation(AAChartModel, BOOL,       xAxisVisible) //X 轴是否可见(默认可见)
AAPropSetFuncImplementation(AAChartModel, BOOL,       xAxisReversed) //X 轴翻转,默认为否
AAPropSetFuncImplementation(AAChartModel, BOOL,       xAxisLabelsEnabled) //X 轴是否显示文字
AAPropSetFuncImplementation(AAChartModel, AAStyle  *, xAxisLabelsStyle) //X 轴文字样式
AAPropSetFuncImplementation(AAChartModel, NSNumber *, xAxisTickInterval) //X 轴刻度点间隔数(设置每隔几个点显示一个 X轴的内容)
AAPropSetFuncImplementation(AAChartModel, AALineStyle *, xAxisGridLineStyle) //X 轴网格线的样式
AAPropSetFuncImplementation(AAChartModel, AACrosshair *, xAxisCrosshair) //X 轴准星线

AAPropSetFuncImplementation(AAChartModel, BOOL,       yAxisVisible) //Y 轴是否可见(默认可见)
AAPropSetFuncImplementation(AAChartModel, BOOL,       yAxisReversed) //Y 轴翻转,默认为否
AAPropSetFuncImplementation(AAChartModel, BOOL,       yAxisLabelsEnabled) //Y 轴是否显示文字
AAPropSetFuncImplementation(AAChartModel, AAStyle  *, yAxisLabelsStyle) //Y 轴文字样式
AAPropSetFuncImplementation(AAChartModel, NSString *, yAxisTitle) //Y 轴标题
AAPropSetFuncImplementation(AAChartModel, NSNumber *, yAxisLineWidth) //Y 轴的轴线宽度
AAPropSetFuncImplementation(AAChartModel, BOOL,       yAxisAllowDecimals) //是否允许 Y 轴显示小数
AAPropSetFuncImplementation(AAChartModel, NSArray  *, yAxisPlotLines) //Y 轴标示线🧶的配置
AAPropSetFuncImplementation(AAChartModel, NSNumber *, yAxisMax) //Y 轴最大值
AAPropSetFuncImplementation(AAChartModel, NSNumber *, yAxisMin) //Y 轴最小值（设置为0就不会有负数）
AAPropSetFuncImplementation(AAChartModel, NSNumber *, yAxisTickInterval)
AAPropSetFuncImplementation(AAChartModel, NSArray  *, yAxisTickPositions) //自定义 Y 轴坐标（如：[@(0), @(25), @(50), @(75) , (100)]）
AAPropSetFuncImplementation(AAChartModel, AALineStyle *, yAxisGridLineStyle) //Y 轴网格线的样式
AAPropSetFuncImplementation(AAChartModel, AACrosshair *, yAxisCrosshair) //Y 轴准星线

AAPropSetFuncImplementation(AAChartModel, BOOL,       tooltipEnabled) //是否显示浮动提示框(默认显示)
AAPropSetFuncImplementation(AAChartModel, BOOL,       tooltipShared) //是否多组数据共享一个浮动提示框
AAPropSetFuncImplementation(AAChartModel, NSString *, tooltipValueSuffix) //浮动提示框单位后缀

AAPropSetFuncImplementation(AAChartModel, BOOL,       connectNulls) //设置折线是否断点重连(是否连接空值点)
AAPropSetFuncImplementation(AAChartModel, BOOL,       legendEnabled) //是否显示图例 lengend(图表底部可点按的圆点和文字)
AAPropSetFuncImplementation(AAChartModel, NSNumber *, borderRadius) //柱状图长条图头部圆角半径(可用于设置头部的形状,仅对条形图,柱状图有效)
AAPropSetFuncImplementation(AAChartModel, NSNumber *, markerRadius) //折线连接点的半径长度
AAPropSetFuncImplementation(AAChartModel, AAScrollablePlotArea *, scrollablePlotArea)

@end
