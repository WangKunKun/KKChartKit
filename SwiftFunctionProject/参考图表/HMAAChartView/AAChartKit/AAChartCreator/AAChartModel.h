//
//  AAChartModel.h
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

#import <Foundation/Foundation.h>
#import "AASeriesElement.h"
#import "AAPlotLinesElement.h"
@class AAStyle, AALineStyle, AACrosshair, AAScrollablePlotArea;

typedef NS_ENUM(NSInteger,AAChartAnimation) {
    AAChartAnimationLinear = 0,
    AAChartAnimationEaseInQuad,
    AAChartAnimationEaseOutQuad,
    AAChartAnimationEaseInOutQuad,
    AAChartAnimationEaseInCubic,
    AAChartAnimationEaseOutCubic,
    AAChartAnimationEaseInOutCubic,
    AAChartAnimationEaseInQuart,
    AAChartAnimationEaseOutQuart,
    AAChartAnimationEaseInOutQuart,
    AAChartAnimationEaseInQuint,
    AAChartAnimationEaseOutQuint,
    AAChartAnimationEaseInOutQuint,
    AAChartAnimationEaseInSine,
    AAChartAnimationEaseOutSine,
    AAChartAnimationEaseInOutSine,
    AAChartAnimationEaseInExpo,
    AAChartAnimationEaseOutExpo,
    AAChartAnimationEaseInOutExpo,
    AAChartAnimationEaseInCirc,
    AAChartAnimationEaseOutCirc,
    AAChartAnimationEaseInOutCirc,
    AAChartAnimationEaseOutBounce,
    AAChartAnimationEaseInBack,
    AAChartAnimationEaseOutBack,
    AAChartAnimationEaseInOutBack,
    AAChartAnimationElastic,
    AAChartAnimationSwingFromTo,
    AAChartAnimationSwingFrom,
    AAChartAnimationSwingTo,
    AAChartAnimationBounce,
    AAChartAnimationBouncePast,
    AAChartAnimationEaseFromTo,
    AAChartAnimationEaseFrom,
    AAChartAnimationEaseTo,
};

typedef NSString * AAChartType;
typedef NSString * AAChartLayoutType;
typedef NSString * AAChartAlignType;
typedef NSString * AAChartVerticalAlignType;
typedef NSString * AAChartZoomType;
typedef NSString * AAChartStackingType;
typedef NSString * AAChartSymbolType;
typedef NSString * AAChartSymbolStyleType;
typedef NSString * AAChartFontWeightType;
typedef NSString * AAChartLineDashStyleType;

AACHARTKIT_EXTERN AAChartType const AAChartTypeColumn;          //柱形图
AACHARTKIT_EXTERN AAChartType const AAChartTypeBar;             //条形图
AACHARTKIT_EXTERN AAChartType const AAChartTypeArea;            //折线区域填充图
AACHARTKIT_EXTERN AAChartType const AAChartTypeAreaspline;      //曲线区域填充图
AACHARTKIT_EXTERN AAChartType const AAChartTypeLine;            //折线图
AACHARTKIT_EXTERN AAChartType const AAChartTypeSpline;          //曲线图
AACHARTKIT_EXTERN AAChartType const AAChartTypeScatter;         //散点图
AACHARTKIT_EXTERN AAChartType const AAChartTypePie;             //扇形图
AACHARTKIT_EXTERN AAChartType const AAChartTypeBubble;          //气泡图
AACHARTKIT_EXTERN AAChartType const AAChartTypePyramid;         //金字塔图
AACHARTKIT_EXTERN AAChartType const AAChartTypeFunnel;          //漏斗图
AACHARTKIT_EXTERN AAChartType const AAChartTypeColumnrange;     //柱形范围图
AACHARTKIT_EXTERN AAChartType const AAChartTypeArearange;       //区域折线范围图
AACHARTKIT_EXTERN AAChartType const AAChartTypeAreasplinerange; //区域曲线范围图
AACHARTKIT_EXTERN AAChartType const AAChartTypeBoxplot;         //箱线图
AACHARTKIT_EXTERN AAChartType const AAChartTypeWaterfall;       //瀑布图
AACHARTKIT_EXTERN AAChartType const AAChartTypePolygon;         //多边形图
AACHARTKIT_EXTERN AAChartType const AAChartTypeGauge;           //仪表图
AACHARTKIT_EXTERN AAChartType const AAChartTypeErrorbar;        //误差图
AACHARTKIT_EXTERN AAChartType const AAChartTypeSankey;          //桑基图= @"sankey";

AACHARTKIT_EXTERN AAChartLayoutType const AAChartLayoutTypeHorizontal; //水平布局
AACHARTKIT_EXTERN AAChartLayoutType const AAChartLayoutTypeVertical;   //垂直布局

AACHARTKIT_EXTERN AAChartAlignType const AAChartAlignTypeLeft;   //位于左边
AACHARTKIT_EXTERN AAChartAlignType const AAChartAlignTypeCenter; //位于中间
AACHARTKIT_EXTERN AAChartAlignType const AAChartAlignTypeRight;  //位于右边

AACHARTKIT_EXTERN AAChartVerticalAlignType const AAChartVerticalAlignTypeTop;    //垂直方向上位于顶部
AACHARTKIT_EXTERN AAChartVerticalAlignType const AAChartVerticalAlignTypeMiddle; //垂直方向上位于中间
AACHARTKIT_EXTERN AAChartVerticalAlignType const AAChartVerticalAlignTypeBottom; //垂直方向上位于底部

AACHARTKIT_EXTERN AAChartZoomType const AAChartZoomTypeNone; //禁用缩放 (默认)
AACHARTKIT_EXTERN AAChartZoomType const AAChartZoomTypeX;    //仅仅支持 X 轴缩放
AACHARTKIT_EXTERN AAChartZoomType const AAChartZoomTypeY;    //仅仅支持 Y 轴缩放
AACHARTKIT_EXTERN AAChartZoomType const AAChartZoomTypeXY;   //X 轴和 Y 轴均可缩放

AACHARTKIT_EXTERN AAChartStackingType const AAChartStackingTypeFalse;   //禁用堆积效果 (默认)
AACHARTKIT_EXTERN AAChartStackingType const AAChartStackingTypeNormal;  //常规堆积效果
AACHARTKIT_EXTERN AAChartStackingType const AAChartStackingTypePercent; //百分比堆积效果

AACHARTKIT_EXTERN AAChartSymbolType const AAChartSymbolTypeCircle;        //◉ ◉ ◉
AACHARTKIT_EXTERN AAChartSymbolType const AAChartSymbolTypeSquare;        //■ ■ ■
AACHARTKIT_EXTERN AAChartSymbolType const AAChartSymbolTypeDiamond;       //◆ ◆ ◆
AACHARTKIT_EXTERN AAChartSymbolType const AAChartSymbolTypeTriangle;      //▲ ▲ ▲
AACHARTKIT_EXTERN AAChartSymbolType const AAChartSymbolTypeTriangle_down; //▼ ▼ ▼

AACHARTKIT_EXTERN AAChartSymbolStyleType const AAChartSymbolStyleTypeDefault;     //symbol 为默认样式
AACHARTKIT_EXTERN AAChartSymbolStyleType const AAChartSymbolStyleTypeInnerBlank;  //symbol 为内部空白样式
AACHARTKIT_EXTERN AAChartSymbolStyleType const AAChartSymbolStyleTypeBorderBlank; //symbol 为外部空白样式

AACHARTKIT_EXTERN AAChartFontWeightType const AAChartFontWeightTypeThin;    //纤细字体
AACHARTKIT_EXTERN AAChartFontWeightType const AAChartFontWeightTypeRegular; //常规字体
AACHARTKIT_EXTERN AAChartFontWeightType const AAChartFontWeightTypeBold;    //加粗字体

AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeSolid;           //———————————————————————————————————
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDash;       //— — — — — — — — — — — — — — — — — —
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDot;        //ⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈⵈ
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDashDot;    //—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧—‧
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeShortDashDotDot; //—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧—‧‧
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeDot;             //‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧‧
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeDash;            //—— —— —— —— —— —— —— —— —— —— —— ——
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDash;        //——— ——— ——— ——— ——— ——— ——— ——— ———
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeDashDot;         //——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧——‧
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDashDot;     //———‧———‧———‧———‧———‧———‧———‧———‧———‧
AACHARTKIT_EXTERN AAChartLineDashStyleType const AAChartLineDashStyleTypeLongDashDotDot;  //———‧‧———‧‧———‧‧———‧‧———‧‧———‧‧———‧‧

@interface AAChartModel : NSObject

AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, NSString *, title) //标题内容
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAStyle  *, titleStyle) //标题文字样式

AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, NSString *, subtitle) //副标题内容
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAStyle  *, subtitleStyle) //副标题文字样式
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, AAChartAlignType, subtitleAlign) //图表副标题文本水平对齐方式。可选的值有 “left”，”center“和“right”。 默认是：center.

AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, NSString *, backgroundColor) //图表背景色(必须为十六进制的颜色色值如红色"#FF0000")
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray  *, colorsTheme) //图表主题颜色数组
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray     <NSString *>*, categories) //X轴坐标每个点对应的名称(注意:这个不是用来设置 X 轴的值,仅仅是用于设置 X 轴文字内容的而已)
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray  *, series) //图表的数据列内容

AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, AAChartType,            chartType) //图表类型
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, AAChartStackingType,    stacking) //堆积样式
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, AAChartSymbolType,      markerSymbol) //折线曲线连接点的类型："circle ◉ ", "square ■ ", "diamond ◆ ", "triangle ▲ ","triangle-down ▼ "，默认是"circle  ◉ "
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, AAChartSymbolStyleType, markerSymbolStyle)
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, AAChartZoomType,        zoomType) //缩放类型 AAChartZoomTypeX 表示可沿着 X 轴进行手势缩放
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, AAChartAnimation,       animationType) //设置图表的渲染动画类型
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, animationDuration) //设置图表的渲染动画时长(动画单位为毫秒)
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       inverted) //X 轴是否垂直,默认为否
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       polar) //是否极化图形(变为雷达图),默认为否
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray  *, margin) //图表外边缘和绘图区域之间的边距。 数组中的数字分别表示顶部，右侧，底部和左侧 ([👆,👉,👇,👈])。 也可以使用 AAChart 对象的 marginTop，marginRight，marginBottom 和 marginLeft 来设置某一个方向的边距。默认值为[null]

AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       dataLabelsEnabled) //是否显示数据,默认为否
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAStyle  *, dataLabelsStyle) //dataLabels文字样式

AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       xAxisVisible) //X 轴是否可见(默认可见)
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       xAxisReversed) //X 轴翻转,默认为否
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       xAxisLabelsEnabled) //X 轴是否显示文字
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAStyle  *, xAxisLabelsStyle) //X 轴文字样式
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, xAxisTickInterval) //X 轴刻度点间隔数(设置每隔几个点显示一个 X轴的内容)
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AALineStyle *, xAxisGridLineStyle) //X 轴网格线的样式
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AACrosshair *, xAxisCrosshair) //X 轴准星线

AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       yAxisVisible) //Y 轴是否可见(默认可见)
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       yAxisReversed) //Y 轴翻转,默认为否
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       yAxisLabelsEnabled) //Y 轴是否显示文字
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAStyle  *, yAxisLabelsStyle) //Y 轴文字样式
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, NSString *, yAxisTitle) //Y 轴标题
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, yAxisLineWidth) //Y 轴的轴线宽度
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       yAxisAllowDecimals) //是否允许 Y 轴显示小数
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray  *, yAxisPlotLines) //Y 轴标示线🧶的配置
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, yAxisMax) //Y 轴最大值
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, yAxisMin) //Y 轴最小值（设置为0就不会有负数）
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, yAxisTickInterval)
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSArray  *, yAxisTickPositions) //自定义 Y 轴坐标（如：[@(0), @(25), @(50), @(75) , (100)]）
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AALineStyle *, yAxisGridLineStyle) //Y 轴网格线的样式
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AACrosshair *, yAxisCrosshair) //Y 轴准星线

AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       tooltipEnabled) //是否显示浮动提示框(默认显示)
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       tooltipShared) //是否多组数据共享一个浮动提示框
AAPropStatementAndPropSetFuncStatement(copy,   AAChartModel, NSString *, tooltipValueSuffix) //浮动提示框单位后缀

AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       connectNulls) //设置折线是否断点重连(是否连接空值点)
AAPropStatementAndPropSetFuncStatement(assign, AAChartModel, BOOL,       legendEnabled) //是否显示图例 lengend(图表底部可点按的圆点和文字)
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, borderRadius) //柱状图长条图头部圆角半径(可用于设置头部的形状,仅对条形图,柱状图有效)
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, NSNumber *, markerRadius) //折线连接点的半径长度
AAPropStatementAndPropSetFuncStatement(strong, AAChartModel, AAScrollablePlotArea *, scrollablePlotArea)

@end


@interface AAChartModel(Unavailable)

@property (nonatomic, strong) NSNumber * titleFontSize AAChartKitUnavailable("`titleFontSize` was removed, please use titleStyle instead of it");
- (AAChartModel * (^) (NSNumber * titleFontSize))titleFontSizeSet AAChartKitUnavailable("`titleFontSizeSet` was removed, please use titleStyleSet instead of it");

@property (nonatomic, strong) NSString * titleFontColor AAChartKitUnavailable("`titleFontColor` was removed, please use titleStyle instead of it");
- (AAChartModel * (^) (NSString * titleFontColor))titleFontColorSet AAChartKitUnavailable("`titleFontColorSet` was removed, please use titleStyleSet instead of it");

@property (nonatomic, strong) NSString * titleFontWeight AAChartKitUnavailable("`titleFontWeight` was removed, please use titleStyle instead of it");
- (AAChartModel * (^) (NSString * titleFontWeight))titleFontWeightSet AAChartKitUnavailable("`titleFontWeightSet` was removed, please use titleStyleSet instead of it");



@property (nonatomic, strong) NSNumber * subtitleFontSize AAChartKitUnavailable("`subtitleFontSize` was removed, please use subtitleStyle instead of it");
- (AAChartModel * (^) (NSNumber * subtitleFontSize))subtitleFontSizeSet AAChartKitUnavailable("`subtitleFontSizeSet` was removed, please use subtitleStyleSet instead of it");

@property (nonatomic, strong) NSString * subtitleFontColor AAChartKitUnavailable("`subtitleFontColor` was removed, please use subtitleStyle instead of it");
- (AAChartModel * (^) (NSString * subtitleFontColor))subtitleFontColorSet AAChartKitUnavailable("`subtitleFontColorSet` was removed, please use subtitleStyleSet instead of it");

@property (nonatomic, strong) NSString * subtitleFontWeight AAChartKitUnavailable("`subtitleFontWeight` was removed, please use subtitleStyle instead of it");
- (AAChartModel * (^) (NSString * subtitleFontWeight))subtitleFontWeightSet AAChartKitUnavailable("`subtitleFontWeightSet` was removed, please use subtitleStyleSet instead of it");



@property (nonatomic, strong) NSNumber * dataLabelsFontSize AAChartKitUnavailable("`dataLabelsFontSize` was removed, please use dataLabelsStyle instead of it");
- (AAChartModel * (^) (NSNumber * dataLabelsFontSize))dataLabelsFontSizeSet AAChartKitUnavailable("`dataLabelsFontSizeSet` was removed, please use dataLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * dataLabelsFontColor AAChartKitUnavailable("`dataLabelsFontColor` was removed, please use dataLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * dataLabelsFontColor))dataLabelsFontColorSet AAChartKitUnavailable("`dataLabelsFontColorSet` was removed, please use dataLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * dataLabelsFontWeight AAChartKitUnavailable("`dataLabelsFontWeight` was removed, please use dataLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * dataLabelsFontWeight))dataLabelsFontWeightSet AAChartKitUnavailable("`dataLabelsFontWeightSet` was removed, please use dataLabelsStyleSet instead of it");



@property (nonatomic, strong) NSNumber * xAxisLabelsFontSize AAChartKitUnavailable("`xAxisLabelsFontSize` was removed, please use xAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSNumber * xAxisLabelsFontSize))xAxisLabelsFontSizeSet AAChartKitUnavailable("`xAxisLabelsFontSizeSet` was removed, please use xAxisLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * xAxisLabelsFontColor AAChartKitUnavailable("`xAxisLabelsFontColor` was removed, please use xAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * xAxisLabelsFontColor))xAxisLabelsFontColorSet AAChartKitUnavailable("`xAxisLabelsFontColorSet` was removed, please use xAxisLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * xAxisLabelsFontWeight AAChartKitUnavailable("`xAxisLabelsFontWeight` was removed, please use xAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * xAxisLabelsFontWeight))xAxisLabelsFontWeightSet AAChartKitUnavailable("`xAxisLabelsFontWeightSet` was removed, please use xAxisLabelsStyleSet instead of it");



@property (nonatomic, strong) NSNumber * yAxisLabelsFontSize AAChartKitUnavailable("`yAxisLabelsFontSize` was removed, please use yAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSNumber * yAxisLabelsFontSize))yAxisLabelsFontSizeSet AAChartKitUnavailable("`yAxisLabelsFontSizeSet` was removed, please use yAxisLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * yAxisLabelsFontColor AAChartKitUnavailable("`yAxisLabelsFontColor` was removed, please use yAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * yAxisLabelsFontColor))yAxisLabelsFontColorSet AAChartKitUnavailable("`yAxisLabelsFontColorSet` was removed, please use yAxisLabelsStyleSet instead of it");

@property (nonatomic, strong) NSString * yAxisLabelsFontWeight AAChartKitUnavailable("`yAxisLabelsFontWeight` was removed, please use yAxisLabelsStyle instead of it");
- (AAChartModel * (^) (NSString * yAxisLabelsFontWeight))yAxisLabelsFontWeightSet AAChartKitUnavailable("`yAxisLabelsFontWeightSet` was removed, please use yAxisLabelsStyleSet instead of it");

@end
