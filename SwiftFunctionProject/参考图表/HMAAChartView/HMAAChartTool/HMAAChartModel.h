//
//  HMAAChartModel.h
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/4/29.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HMAAPlotLinesElement.h"

typedef enum : NSUInteger {
    HMAAChartTypeAreaspline, //曲线填充图
    HMAAChartTypeColumn, //柱状图
    HMAAChartTypeLine, //折线图   无法填充颜色  
} HMAAChartType;

typedef enum : NSUInteger {
    HMAAChartStackingTypeFalse, //禁用堆积效果 (默认)
    HMAAChartStackingTypeNormal, //常规堆积效果
    HMAAChartStackingTypePercent, //百分比堆积效果
} HMAAChartStackingType;

typedef enum : NSUInteger {
    HMAAChartZoomTypeX, //X轴缩放
    HMAAChartZoomTypeY, //Y轴缩放
    HMAAChartZoomTypeXY, //XY轴缩放
    HMAAChartZoomTypeNone //禁用缩放
} HMAAChartZoomType;

NS_ASSUME_NONNULL_BEGIN
@class HMAASeries, HMAAYAxis, HMChartHeaderModel, HMChartSunModel;
@interface HMAAChartModel : NSObject

// ------ 基础配置 ------
@property (nonatomic, copy) NSString *name;//图表标题 不设置即不显示
@property (nonatomic, assign) HMAAChartType chartType;// 图表类型
@property (nonatomic, assign) HMAAChartStackingType stackType;// 堆积效果（默认禁用）
@property (nonatomic, copy) NSArray *xAxisArray;// 横轴
@property (nonatomic, copy) NSArray *xSeriesArray;// tooltip数据标题-横轴
@property (nonatomic, copy) NSArray<HMAASeries *> *seriesArray;// 数据

// ------版本配置------
@property (nonatomic, assign) NSInteger version;// 版本配置
@property (nonatomic, copy) NSString *unit;//版本2.0显示标题通用单位

// ------其它配置------
@property (nonatomic, assign) BOOL reverse;// 是否需要反转组中数据绘制顺序-与web端图表样式同步
@property (nonatomic, assign) HMAAChartZoomType zoomType;// 缩放类型 默认缩放X轴
@property (nonatomic, strong) NSNumber *yAxisMax;// Y 轴最大值
@property (nonatomic, strong) NSNumber *yAxisMin;// Y 轴最小值
@property (nonatomic, copy) NSArray<NSNumber *> *yAxisTickPositions;// 自定义 Y 轴坐标（如：[@(0), @(25), @(50), @(75) , (100)]）
@property (nonatomic, copy) NSString *titleColor;// 标题颜色 hex值 例:#FFFFFF
@property (nonatomic, copy) NSString *titleFont;//  标题字号 例:12
@property (nonatomic, copy) NSString *titleWeight;// 标题字重 可选的值有 bold, regular和 thin 三种,分别对应的是加粗字体,常规字体和纤细字体 默认regular
@property (nonatomic, copy) NSString *yAxisTextColor;// y轴颜色 hex值
@property (nonatomic, copy) NSString *yAxisTextFont;//  y轴字号
@property (nonatomic, copy) NSString *yAxisTextWeight;// y轴字重
@property (nonatomic, copy) NSString *xAxisTextColor;// x轴颜色 hex值
@property (nonatomic, copy) NSString *xAxisTextFont;//  x轴字号
@property (nonatomic, copy) NSString *xAxisTextWeight;// x轴字重
@property (nonatomic, copy) NSString *xAxisType;// 设置x轴类型
@property (nonatomic, strong) NSNumber *xAxisMax;// X 轴最大值
@property (nonatomic, strong) NSNumber *xAxisMin;// X 轴最小值
@property (nonatomic, strong) NSNumber *xAxisTickInterval;// X 轴刻度点间隔
@property (nonatomic, assign) BOOL yAxisHidden;// Y 轴隐藏 默认显示
@property (nonatomic, strong) NSNumber *leftMargin;// 图标内部左边距
@property (nonatomic, copy) NSString *crosshairColor;// x轴准星线颜色
@property (nonatomic, copy) NSString *dashColor;// x轴网格线颜色
@property (nonatomic, copy) NSString *toolTipBackgroundColor;// tooltip背景框颜色
@property (nonatomic, copy) NSString *toolTipTextColor;// tooltip字体颜色
@property (nonatomic, assign) BOOL closeDarkStyle;// 默认适配暗黑模式 可通过此项关闭
@property (nonatomic, assign) BOOL tooltipPinToTop;// 设置tooltip置顶
@property (nonatomic, assign) BOOL tooltipDisable;// 关闭tooltip
@property (nonatomic, copy) NSArray<HMAAPlotLinesElement *> *yAxisPlotLines;//标示线数组
@property (nonatomic, assign) BOOL nativeTooltip;//使用oc版本编写的tooltip
@property (nonatomic, copy) NSArray<NSNumber *> *defaultScope;//设置默认展示范围 @[@index1, @index2] index小于xAxisArray长度

// 头部数据
@property (nonatomic, copy, nullable) NSArray<HMChartHeaderModel *> *headerDatas;//结合原生tooltip的头部数据

// 日出日落
@property (nonatomic, copy, nullable) NSArray<HMChartSunModel *> *sunDatas;//如果需要展示日出日落

// 深浅模式配置颜色 0浅色 1深色
@property (nonatomic, copy) NSArray<NSString *> *titleColorArr;
@property (nonatomic, copy) NSArray<NSString *> *crosshairColorArr;
@property (nonatomic, copy) NSArray<NSString *> *dashColorArr;
@property (nonatomic, copy) NSArray<NSString *> *xAxisTextColorArr;
@property (nonatomic, copy) NSArray<NSString *> *yAxisTextColorArr;
@property (nonatomic, copy) NSArray<NSString *> *toolTipBackgroundColorArr;
@property (nonatomic, copy) NSArray<NSString *> *toolTipTextColorArr;

// 次y轴配置
@property (nonatomic, strong) HMAAYAxis *subYAxis;

// HMLGAAChartView使用
@property (nonatomic, assign) BOOL showLegend;// 显示图例
@property (nonatomic, assign) BOOL showNoData;// 强制显示暂无数据-不配置则内部自适应
@property (nonatomic, assign) CGFloat chartHeight;// 设置图表展示高度

// ----- 计算后的数据 -----
@property (nonatomic, copy) NSArray<HMAASeries *> *showSeriesArray;// 配合图例隐藏数据

@end

@interface HMAAYAxis : NSObject

@property (nonatomic, strong) NSNumber *yAxisMax;// Y 轴最大值
@property (nonatomic, strong) NSNumber *yAxisMin;// Y 轴最小值
@property (nonatomic, copy) NSString *yAxisTextColor;// y轴颜色 hex值
@property (nonatomic, copy) NSString *yAxisTextFont;//  y轴字号
@property (nonatomic, copy) NSString *yAxisTextWeight;// y轴字重
@property (nonatomic, copy) NSString *unit;// 单位
@property (nonatomic, copy) NSArray<NSNumber *> *yAxisTickPositions;// 自定义 Y 轴坐标（如：[@(0), @(25), @(50), @(75) , (100)]）

@end

@interface HMChartHeaderModel : NSObject

@property (nonatomic, copy) NSString *title;//标题
@property (nonatomic, copy) NSString *data;//数据
@property (nonatomic, copy) NSString *unit;//单位
@property (nonatomic, assign) CGFloat topMargin;// 上边距 默认0
@property (nonatomic, assign) CGFloat leftMargin;// 左边距 默认0
@property (nonatomic, assign) CGFloat rightMargin;// 右边距 默认0

@end

@interface HMChartSunModel : NSObject

@property (nonatomic, copy) NSString *icon;//图标
@property (nonatomic, copy) NSString *title;//日出日落
@property (nonatomic, copy) NSString *time;//时间

- (instancetype)initSunriseModel;

- (instancetype)initSunsetModel;

@end

NS_ASSUME_NONNULL_END
