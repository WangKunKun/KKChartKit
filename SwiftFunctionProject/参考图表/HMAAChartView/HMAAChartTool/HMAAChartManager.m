//
//  HMAAChartManager.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/1/8.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import "HMAAChartManager.h"
#import "HMAAChartModel.h"
#import "HMAASeries.h"
#import "AAChartKit.h"

@interface HMAAChartManager ()

@property (nonatomic, strong) HMAAChartModel *chartModel;
@property (nonatomic, assign) AAChartType chartType;
@property (nonatomic, assign) AAChartStackingType stackType;
@property (nonatomic, strong) NSArray<HMAASeries *> *seriesArray;// 最终数据-去掉图例隐藏数据

@property (nonatomic, readwrite, strong) NSArray<AASeriesElement *> *series;// 绘制AAChart最终数据

@property (nonatomic, assign) BOOL isAllPos; // 判断是否只有正值

@end

@implementation HMAAChartManager

- (instancetype)initWithChartModel:(HMAAChartModel *)chartModel {
    self = [super init];
    if (self) {
        self.chartModel = chartModel;
        self.seriesArray = chartModel.showSeriesArray;
    }
    return self;
}

#pragma mark - method

// 绘制chartView
- (AAOptions *)configureAAChartOptions {
    
    AAChartModel *aChartModel = [self createAAChartModel];
    
    AAOptions *aChartOptions = [AAOptionsConstructor configureChartOptionsWithAAChartModel:aChartModel];
    // 图表标题
    AAStyle *headStyle = AAStyleColorSizeWeight(@"#141414", 16, @"bold");
    if (_chartModel.titleColor) {
        headStyle.colorSet(_chartModel.titleColor);
    }
    if (_chartModel.titleFont) {
        headStyle.fontSizeSet(_chartModel.titleFont);
    }
    if (_chartModel.titleWeight) {
        headStyle.fontWeightSet(_chartModel.titleWeight);
    }
    if (_chartModel.name.length > 0 && _chartModel.version != 2) {
        aChartOptions.title = AATitle.new
            .textSet(_chartModel.name)
            .styleSet(headStyle)
            .alignSet(AAChartAlignTypeLeft);
    }
    aChartOptions.xAxis.lineColor = _chartModel.dashColor;
//    aChartOptions.plotOptions.series.states.hover.enabledSet(NO);
//    aChartOptions.plotOptions.series.states.inactive.enabledSet(NO);
    if (_chartModel.xAxisType.length > 0) {
        aChartOptions.xAxis.type = _chartModel.xAxisType;
    }
    if (_chartModel.xAxisMin) {
        aChartOptions.xAxis.min = _chartModel.xAxisMin;
    }
    if (_chartModel.xAxisMax) {
        aChartOptions.xAxis.max = _chartModel.xAxisMax;
    }
    if (_chartModel.leftMargin) {
        aChartOptions.chart.marginLeftSet(_chartModel.leftMargin);
    }
    
    // 次级y轴
    if (_chartModel.subYAxis) {
        HMAAYAxis *subYAxis = _chartModel.subYAxis;
        AAYAxis *rightYAxis = AAYAxis.new
            .oppositeSet(true);
        AAAxisTitle *axisTitle = AAAxisTitle.new
            .textSet(@"");
        rightYAxis.titleSet(axisTitle);
        
        NSArray *subTotalNumberArray = [self maxFabsNumberArrayYAxisIndex:1];//次轴
        NSDictionary *maxminSubDict = [HMAASeriesUtil calculateMaxMinValueWithNumberArray:subTotalNumberArray];
        rightYAxis.max = maxminSubDict[@"max"];
        rightYAxis.min = maxminSubDict[@"min"];

        if (self.isAllPos) {
            rightYAxis.minSet(@0);
        }
        
        //最大最小值皆为0
        if (fabs([rightYAxis.min doubleValue]) < 1e-9 && fabs([rightYAxis.max doubleValue]) < 1e-9) {
            rightYAxis.maxSet(@1);
        }
        
        if (subYAxis.yAxisMax) {
            rightYAxis.maxSet(subYAxis.yAxisMax);
        }
        
        if (subYAxis.yAxisMin) {
            rightYAxis.minSet(subYAxis.yAxisMin);
        }
        
        if (subYAxis.yAxisTextColor) {
            rightYAxis.lineColorSet(_chartModel.yAxisTextColor);
        }
        AAStyle *yAxisStyle = AAStyleColorSize(@"#64686F", 10);
        if (subYAxis.yAxisTextFont) {
            yAxisStyle.fontSizeSet(subYAxis.yAxisTextFont);
        }
        if (subYAxis.yAxisTextWeight) {
            yAxisStyle.fontWeightSet(subYAxis.yAxisTextWeight);
        }
        NSString *format = [NSString stringWithFormat:@"{value}%@", subYAxis.unit];
        AALabels *labels = AALabels.new
            .styleSet(yAxisStyle)
            .formatSet(format);
        rightYAxis.labelsSet(labels);
        if (subYAxis.yAxisTickPositions.count > 0) {
            rightYAxis.tickPositions = _chartModel.yAxisTickPositions;
        }
        
        rightYAxis.gridLineDashStyleSet(AAChartLineDashStyleTypeShortDash);
        
        AAYAxis *leftYAxis = aChartOptions.yAxis; // 原始的 yAxis 是单个对象（不是数组），需要转为数组处理
        [aChartOptions setValue:@[leftYAxis, rightYAxis] forKey:@"yAxis"];
    }
    
    if (_chartModel.subYAxis) {//次级y轴
        NSArray *yAxises = [aChartOptions valueForKey:@"yAxis"];
        for (AAYAxis *yAxis in yAxises) {
            yAxis.lineWidthSet(@0);//隐藏y轴线
        }
    } else {
        aChartOptions.yAxis.lineWidthSet(@0);//隐藏y轴线
    }
    if (_chartModel.chartType == HMAAChartTypeColumn) {//柱状图
        AASeriesElement *element = aChartModel.series.firstObject;
        aChartOptions.plotOptions.column.maxPointWidth = @(40);//最大限制40
        if (_chartModel.stackType == HMAAChartStackingTypeNormal) {//堆积图
            if (element.data.count < 30) {//数组数据低于30时设置/大于30自适应
                aChartOptions.plotOptions.column.pointWidth = @(4);//柱单元宽度
            }
        }
    }
        
    // 产品需要隐藏放大重置按钮
    aChartOptions.chart
        .resetZoomButtonSet(AAResetZoomButton.new
                            .themeSet(@{
                                @"style": @{
                                    @"display":@"none"//隐藏图表缩放后的默认显示的缩放按钮
                                }
                            }));
    
    // 默认展示区域
    if (_chartModel.defaultScope.count > 0) {
        NSNumber *min = _chartModel.defaultScope.firstObject;
        NSNumber *max = _chartModel.defaultScope.lastObject;
        if ([min compare:@(_chartModel.xAxisArray.count - 1)] == NSOrderedAscending &&
            [max compare:@0] == NSOrderedDescending &&
            [max compare:min] == NSOrderedDescending) {//数据正常
            aChartOptions.xAxis.min = [min compare:@0] == NSOrderedDescending ? min : @0;
            aChartOptions.xAxis.max = [max compare:@(_chartModel.xAxisArray.count - 1)] == NSOrderedAscending ? max : @(_chartModel.xAxisArray.count - 1);
        }
    }
    
    return aChartOptions;
}

- (AAChartModel *)createAAChartModel {
    if (_chartModel.chartType == HMAAChartTypeAreaspline) {
        self.chartType = AAChartTypeAreaspline;
    }
    if (_chartModel.chartType == HMAAChartTypeColumn) {
        self.chartType = AAChartTypeColumn;
    }
    if (_chartModel.chartType == HMAAChartTypeLine) {
        self.chartType = AAChartTypeLine;
    }
    
    if (_chartModel.stackType == HMAAChartStackingTypeFalse) {
        self.stackType = AAChartStackingTypeFalse;
    }
    if (_chartModel.stackType == HMAAChartStackingTypeNormal) {
        self.stackType = AAChartStackingTypeNormal;
    }
    if (_chartModel.stackType == HMAAChartStackingTypePercent) {
        self.stackType = AAChartStackingTypePercent;
    }
    
    self.series = [self packageAASeriesArray];//处理最终数据组
    
    // 判断是否只有正值
    self.isAllPos = YES;
    if (self.seriesArray.count > 1) {
        // 组数据大于一条
        for (HMAASeries *series in self.seriesArray) {
            for (int i = 0; i < series.element.firstObject.data.count; i ++) {
                for (HMAASeriesElement *obj in series.element) {
                    if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                        if ([obj.data[i] floatValue] < 0) {
                            self.isAllPos = NO;
                        }
                    }
                }
            }
        }
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.element.count > 1) {
            // 数据只有一组，但组内有多个数据组
            for (int i = 0; i < series.element.firstObject.data.count; i ++) {
                for (HMAASeriesElement *obj in series.element) {
                    if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                        if ([obj.data[i] floatValue] < 0) {
                            self.isAllPos = NO;
                        }
                    }
                }
            }
        } else if (series.element.count == 1) {
            for (int i = 0; i < series.element.firstObject.data.count; i ++) {
                for (HMAASeriesElement *obj in series.element) {
                    if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                        if ([obj.data[i] floatValue] < 0) {
                            self.isAllPos = NO;
                        }
                    }
                }
            }
        }
    }
    
    // 计算最大最小值
    NSArray *mainTotalNumberArray = [self maxFabsNumberArrayYAxisIndex:0];//主轴
    NSDictionary *maxminDict = [HMAASeriesUtil calculateMaxMinValueWithNumberArray:mainTotalNumberArray];
    NSNumber *mainYMax = maxminDict[@"max"];
    NSNumber *mainYMin = maxminDict[@"min"];
    
    AAChartZoomType zoomType = AAChartZoomTypeX;
    if (_chartModel.zoomType == HMAAChartZoomTypeX) {
        zoomType = AAChartZoomTypeX;
    }
    if (_chartModel.zoomType == HMAAChartZoomTypeY) {
        zoomType = AAChartZoomTypeY;
    }
    if (_chartModel.zoomType == HMAAChartZoomTypeXY) {
        zoomType = AAChartZoomTypeXY;
    }
    if (_chartModel.zoomType == HMAAChartZoomTypeNone) {
        zoomType = AAChartZoomTypeNone;
    }
        
    AAChartModel *aChartModel = AAChartModel.new
        .chartTypeSet(self.chartType)//设置图表的类型
        .stackingSet(self.stackType)//堆积样式
        .categoriesSet(_chartModel.xAxisArray)//图表横轴的内容
//        .xAxisTickIntervalSet(@(_chartModel.xAxisArray.count/6))//x 轴刻度点间隔数
//        .yAxisTickIntervalSet(@((mainYMax.doubleValue - mainYMin.doubleValue) / 5.0)) //尝试做一个间隔 发现更丑了
        .animationDurationSet(@0)//关闭渲染动画
        .legendEnabledSet(NO)//隐藏图例
        .seriesSet(self.series)
        .yAxisMaxSet(mainYMax)
        .yAxisMinSet(mainYMin)
        .zoomTypeSet(zoomType)
        .tooltipEnabledSet(NO)//为自定义原生tooltip做准备
        .yAxisGridLineStyleSet([AALineStyle styleWithColor:_chartModel.dashColor dashStyle:AAChartLineDashStyleTypeShortDash])//y轴网格线
        .xAxisCrosshairSet([AACrosshair
            crosshairWithColor:_chartModel.crosshairColor//x轴准星线
            dashStyle:AAChartLineDashStyleTypeShortDash
            width:@0.8//Zero width to disable crosshair by default
            zIndex:@3]//增大防止遮挡数据
        );

    if (_chartModel.xAxisTickInterval) {
        aChartModel.xAxisTickIntervalSet(_chartModel.xAxisTickInterval);
    }
    
    if (_chartModel.chartType == HMAAChartTypeAreaspline) {//曲线填充图
        aChartModel.markerRadiusSet(@0);//隐藏marker
    }
    
    if (_chartModel.chartType == HMAAChartTypeColumn) {//柱状堆积图
        aChartModel.borderRadiusSet(@2);//柱状图圆角
    }
    
    if (self.isAllPos) {
        aChartModel.yAxisMinSet(@0);
    }
    
    //最大最小值皆为0
    if (fabs([mainYMin doubleValue]) < 1e-9 && fabs([mainYMax doubleValue]) < 1e-9) {
        aChartModel.yAxisMaxSet(@1);
    }
    
    if (_chartModel.yAxisMax) {
        aChartModel.yAxisMaxSet(_chartModel.yAxisMax);
    }
    
    if (_chartModel.yAxisMin) {
        aChartModel.yAxisMinSet(_chartModel.yAxisMin);
    }
    
    if (_chartModel.yAxisHidden) {
        aChartModel.yAxisVisibleSet(!_chartModel.yAxisHidden);
    }
    
    if (_chartModel.yAxisTickPositions.count > 0) {
        aChartModel.yAxisTickPositionsSet(_chartModel.yAxisTickPositions);
    }
    
    AAStyle *xAxisStyle = AAStyleColorSize(@"#64686F", 10);
    if (_chartModel.xAxisTextColor) {
        xAxisStyle.colorSet(_chartModel.xAxisTextColor);
    }
    if (_chartModel.xAxisTextFont) {
        xAxisStyle.fontSizeSet(_chartModel.xAxisTextFont);
    }
    if (_chartModel.xAxisTextWeight) {
        xAxisStyle.fontWeightSet(_chartModel.xAxisTextWeight);
    }
    aChartModel.xAxisLabelsStyleSet(xAxisStyle);
    
    AAStyle *yAxisStyle = AAStyleColorSize(@"#64686F", 10);
    if (_chartModel.yAxisTextColor) {
        yAxisStyle.colorSet(_chartModel.yAxisTextColor);
    }
    if (_chartModel.yAxisTextFont) {
        yAxisStyle.fontSizeSet(_chartModel.yAxisTextFont);
    }
    if (_chartModel.yAxisTextWeight) {
        yAxisStyle.fontWeightSet(_chartModel.yAxisTextWeight);
    }
    aChartModel.yAxisLabelsStyleSet(yAxisStyle);
    
    if (_chartModel.yAxisPlotLines.count > 0) {
        NSMutableArray *yAxisPlotLines = [NSMutableArray array];
        for (HMAAPlotLinesElement *element in _chartModel.yAxisPlotLines) {
            AAPlotLinesElement *pelement = [self packagePlotElementWithObject:element];
            [yAxisPlotLines addObject:pelement];
        }
        aChartModel.yAxisPlotLinesSet(yAxisPlotLines);
    }
    
    return aChartModel;
}

- (NSArray<AASeriesElement *> *)packageAASeriesArray {
    //数据处理
    NSMutableArray *seriesElements = [NSMutableArray array];
    if (self.seriesArray.count > 1) {
        // 组数据大于一条
        for (HMAASeries *series in self.seriesArray) {
            for (HMAASeriesElement *obj in (_chartModel.reverse ? series.element.reverseObjectEnumerator : series.element)) {
                obj.chartType = obj.chartType ? obj.chartType : self.chartType;
                AASeriesElement *element = [self packageElementWithObject:obj];
                [seriesElements addObject:element];
            }
        }
        // 曲线区域堆叠图-添加虚拟序列实现绝对值堆叠
        if (_chartModel.chartType == HMAAChartTypeAreaspline && _chartModel.stackType == HMAAChartStackingTypeNormal) {
            // 计算虚拟序列实现绝对值堆叠 先绘制负曲线 计算虚拟序列填平 最后绘制正曲线
            HMAASeries *series = self.seriesArray.lastObject;
            HMAASeriesElement *obj = self.seriesArray.firstObject.element.firstObject;
            if ([HMAASeriesUtil canTranslateToNum:obj.data.firstObject]) {
                if ([obj.data.firstObject floatValue] < 0) {
                    //如果第一组为负数据 虚拟序列用第一组计算
                    series = self.seriesArray.firstObject;
                }
            }
            AASeriesElement *virtualElement = [self createVirtualElementWithArray:series.element];
            [seriesElements insertObject:virtualElement atIndex:self.seriesArray.firstObject.element.count];
        }
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.element.count > 1) {
            // 数据只有一组，但组内有多个数据组
            if (_chartModel.chartType == HMAAChartTypeAreaspline && _chartModel.stackType == HMAAChartStackingTypeNormal) {// 数据组堆叠存在正负情况/分组处理
                for (HMAASeriesElement *obj in (_chartModel.reverse ? series.element.reverseObjectEnumerator : series.element)) {
                    HMAASeriesElement *hmelement = [HMAASeriesUtil positiveSplitFromSeriesElement:obj];
                    AASeriesElement *element = [self packageElementWithObject:hmelement];
                    [seriesElements addObject:element];
                }
                NSMutableArray *negativeElements = [NSMutableArray array];
                for (HMAASeriesElement *obj in (_chartModel.reverse ? series.element.reverseObjectEnumerator : series.element)) {
                    HMAASeriesElement *hmelement = [HMAASeriesUtil negativeSplitFromSeriesElement:obj];
                    [negativeElements addObject:hmelement];
                    AASeriesElement *element = [self packageElementWithObject:hmelement];
                    [seriesElements addObject:element];
                }
                AASeriesElement *virtualElement = [self createVirtualElementWithArray:negativeElements];
                [seriesElements insertObject:virtualElement atIndex:series.element.count];
            } else {
                for (HMAASeriesElement *obj in (_chartModel.reverse ? series.element.reverseObjectEnumerator : series.element)) {
                    obj.chartType = obj.chartType ? obj.chartType : self.chartType;
                    AASeriesElement *element = [self packageElementWithObject:obj];
                    [seriesElements addObject:element];
                }
            }
        } else if (series.element.count == 1) {
            HMAASeriesElement *obj = series.element.firstObject;
            obj.chartType = obj.chartType ? obj.chartType : self.chartType;
            AASeriesElement *element = [self packageElementWithObject:obj];
            [seriesElements addObject:element];
        }
    }
    return seriesElements.copy;
}

- (AASeriesElement *)packageElementWithObject:(HMAASeriesElement *)obj {
    AAMarker *marker = AAMarker.new
        .statesSet(AAMarkerStates.new
                   .hoverSet(AAMarkerHover.new
                             .enabledSet(false)));//隐藏选择时的高亮圆圈
    if ([obj.chartType isEqualToString:@"line"] || [obj.chartType isEqualToString:@"spline"]) {
        marker.radiusSet(@2)
            .fillColorSet(@"#FFFFFF")
            .lineWidthSet(@2)
            .lineColorSet(obj.color);
    } else {
        marker.radiusSet(@0);
    }
    
    NSMutableArray *data = obj.data.mutableCopy;
    for (int i = 0; i < obj.data.count; i ++) {
        id num = obj.data[i];
        if ([num isKindOfClass:[NSString class]]) {//如果是字符串转换成number
            [data replaceObjectAtIndex:i withObject:[NSDecimalNumber decimalNumberWithString:num]];
        }
    }
    
    NSMutableArray * useData = data;
    
    //如果有需要隐藏的点，则需要重新组装
    if (obj.hidePoints.count > 0) {
        //重新组装data
        NSMutableArray *dictDataList = [NSMutableArray array];
        for (NSUInteger i = 0; i < data.count; i ++) {
            id number = data[i];
            // ✅ 关键：处理 NSNull
            if ([number isKindOfClass:[NSNull class]]) {
                [dictDataList addObject:[NSNull null]];
                continue;
            }
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            dict[@"y"] = number;
            if ([obj.hidePoints containsObject:@(i)]) {
                dict[@"custom"] = @{@"hide": @YES};
            }
            [dictDataList addObject:dict];
        }
        useData = dictDataList;
    }

    
    AASeriesElement *element = AASeriesElement.new
        .nameSet(obj.name)
        .typeSet(obj.chartType)
        .dataSet(useData)
        .colorSet(obj.color)
        .lineWidthSet(@1)
        .markerSet(marker);
        
    if (obj.hideInTooltip) {
        element.enableMouseTrackingSet(@(NO));
    }
    
    if (obj.stackGroup.length > 0) {
        element.stackSet(obj.stackGroup);
    }
  
    if (obj.dashStyle.length > 0) {
        element.dashStyleSet(obj.dashStyle);
    }
    
    if (obj.markerHidden) {
        marker.enabledSet(NO);//不显示点
    }
    
    if (obj.zones.count > 0) {//设置了需要分段显示颜色
        if (obj.zoneAxisX) {//默认按y轴分段 设置则为x
            element.zoneAxisSet(AAChartZoneAxisTypeX);
        }
        NSMutableArray *zones = [NSMutableArray array];
        for (NSDictionary *dic in obj.zones) {
            AAZonesElement *zone = AAZonesElement.new;
            if (dic[@"value"]) {
                NSNumber *value = @([NSString stringWithFormat:@"%@", dic[@"value"]].integerValue);
                zone.valueSet(value);
            }
            if (dic[@"color"]) {
                NSString *color = [NSString stringWithFormat:@"%@", dic[@"color"]];
                zone.colorSet(color);
            }
            if (dic[@"fillColor"]) {
                NSString *fillColor = [NSString stringWithFormat:@"%@", dic[@"fillColor"]];
                zone.fillColorSet(fillColor);
            }
            [zones addObject:zone];
        }
        element.zonesSet(zones);
    }

    if (obj.isStep) {
        element.stepSet(@(true));//直方图
    }
    
    if (obj.fillColorAlphas.count > 0) {//设置了渐变色透明度
        NSString * fillColor = obj.fillColor ?: obj.color;
        NSString *startColorString = [HMAASeriesUtil rgbaStringFromHex:fillColor withAlpha:[obj.fillColorAlphas.firstObject floatValue]];
        NSString *endColorString = [HMAASeriesUtil rgbaStringFromHex:fillColor withAlpha:[obj.fillColorAlphas.lastObject floatValue]];
        AAGradientColor *gradientColorDic = [AAGradientColor gradientColorWithDirection:AALinearGradientDirectionToBottom startColorString:startColorString endColorString:endColorString];
        element.fillColorSet((id)gradientColorDic);
    } else {
        if (obj.fillColor) {
            //自定义了fillcolor 则设置透明度不生效了，需要在
            //#FFFFFF 这样的类型 添加透明度上去
            if ([obj.fillColor containsString:@"#"] && obj.fillColor.length == 7) {
                NSString * color = [NSString stringWithFormat:@"%@%@",obj.fillColor,[self hexStringFromAlpha:obj.fillAlpha]];
                element.fillColorSet(color);
            } else {
                element.fillColorSet(obj.fillColor);
            }
        } else {
            element.fillOpacitySet(@(obj.fillAlpha));
        }
    }
    
    if (obj.negativeColor) {
        element.negativeColorSet(obj.negativeColor);
    }
    
    if (obj.autoGap) {//使用截断处理数据
        NSArray<NSArray<NSNumber *> *> *breaks = [self computeBreaks:obj.data maxNulls:12];//固定为超过12个点断开
        NSArray<AAZonesElement *> *zones = [self zonesFromBreaks:breaks];
        element.connectNullsSet(@YES) // 全局开启，它会负责连接所有"短"的 null 区间
                .zoneAxisSet(AAChartZoneAxisTypeX) // 指定 zones 应用于 x 轴
                .zonesSet(zones); // 应用我们精心计算出的 zones 配置
    }
    if (obj.yAxis) {
        element.yAxisSet(obj.yAxis);
    }
    // 设置未激活状态的数据不变灰/关闭tooltip时默认的行为会高亮当前滑动的点而将其他系列变灰
    if (_chartModel.nativeTooltip) {
        element.statesSet(AAStates.new.
                          inactiveSet(AAInactive.new
                                      .opacitySet(@1)));
    } else {
        element.statesSet(AAStates.new
                          .inactiveSet(AAInactive.new.enabledSet(NO))
                          .hoverSet(AAHover.new.enabledSet(NO)));
    }
    return element;
}

- (AAPlotLinesElement *)packagePlotElementWithObject:(HMAAPlotLinesElement *)obj {
    NSString *textColor = obj.textColor;
    UITraitCollection *traitCollection = [UITraitCollection currentTraitCollection];
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        textColor = obj.textDarkColor;
    }
    
    AAPlotLinesElement *element = AAPlotLinesElement.new
        .colorSet(obj.color)
        .widthSet(obj.width)
        .valueSet(obj.value)
        .zIndexSet(@3)
        .labelSet(AALabel.new
                  .textSet(obj.text)
                  .alignSet(@"right")
                  .xSet(@(-5))
                  .styleSet(AAStyle.new
                            .colorSet(textColor)
                            .fontSizeSet(obj.fontSize)));
    return element;
}

/**
 * 计算需要断开的区间。
 * @param data - 原始数据数组。
 * @param maxNulls - 允许连续 null 的最大数量。
 * @returns - 返回一个数组，每个元素代表一个断点区间。
 *   例如: @[@[@4, @9]] 表示索引 4 和索引 9 之间的连接线需要断开。
 *   其中 4 是断点前最后一个有效点的索引，9 是断点后第一个有效点的索引。
 */
- (NSArray<NSArray<NSNumber *> *> *)computeBreaks:(NSArray *)data maxNulls:(NSInteger)maxNulls {
    NSMutableArray<NSArray<NSNumber *> *> *breaks = [NSMutableArray array];
    NSInteger i = 0;
    
    while (i < data.count) {
        // 跳过有效数据点
        if (![data[i] isKindOfClass:[NSNull class]]) {
            i++;
            continue;
        }
        
        // 找到一段连续 null 的开始和结束
        NSInteger start = i;
        while (i < data.count && [data[i] isKindOfClass:[NSNull class]]) {
            i++;
        }
        NSInteger end = i - 1;
        NSInteger len = end - start + 1;
        
        // 如果连续 null 的长度超过了阈值
        if (len >= maxNulls) {
            NSInteger prevValidIndex = start - 1;
            NSInteger nextValidIndex = end + 1;
            
            // 必须确保断点两端都有有效的点，才存在一条需要被"切断"的连接线
            if (prevValidIndex >= 0 && ![data[prevValidIndex] isKindOfClass:[NSNull class]] &&
                nextValidIndex < data.count && ![data[nextValidIndex] isKindOfClass:[NSNull class]]) {
                [breaks addObject:@[@(prevValidIndex), @(nextValidIndex)]];
            }
        }
    }
    return breaks;
}

/**
 * 根据断点区间生成 Highcharts 的 zones 配置。
 * 这是整个方案最核心的逻辑，它巧妙地利用了 Highcharts 的渲染规则。
 *
 * **Highcharts 渲染黄金法则**:
 * 一条线段（从点 A 到点 B）的颜色，由其【终点 B】所在的 Zone 决定。
 *
 * @param breaks - computeBreaks 函数返回的断点数组。
 * @returns - Highcharts series.zones 的配置数组。
 */
- (NSArray<AAZonesElement *> *)zonesFromBreaks:(NSArray<NSArray<NSNumber *> *> *)breaks {
    if (breaks.count == 0) {
        return @[]; // 如果没有需要断开的地方，返回空数组
    }
    
    NSMutableArray<AAZonesElement *> *zones = [NSMutableArray array];
    
    // Highcharts 会自动处理第一个 zone 之前的部分（从 x=0 开始），所以我们无需手动定义。
    
    for (NSArray<NSNumber *> *breakPair in breaks) {
        NSInteger prevIndex = [breakPair[0] integerValue];
        NSInteger nextIndex = [breakPair[1] integerValue];
        
        // **第 1 步：定义可见区域**
        // 我们定义一个可见区域，它的终点是断点前的最后一个有效点 (prevIndex)。
        // 根据黄金法则，任何终点 x <= prevIndex 的线段都会是可见的。
        // 这就确保了断点前的所有线段都正常显示。
        AAZonesElement *visibleZone = AAZonesElement.new
            .valueSet(@(prevIndex));
        // color 属性不写，默认继承 series 的颜色
        [zones addObject:visibleZone];
        
        // **第 2 步：定义透明区域**
        // 紧接着，我们定义一个透明区域，它的终点是断点后的第一个有效点 (nextIndex)。
        // 这意味着 x > prevIndex 且 x <= nextIndex 的区域都是透明的。
        // 根据黄金法则，从 prevIndex 到 nextIndex 的这条线段，其终点是 nextIndex，
        // 恰好落在这个透明区域内，所以这条线段就会变成透明！
        AAZonesElement *transparentZone = AAZonesElement.new
            .valueSet(@(nextIndex))
            .colorSet(@"transparent");
        [zones addObject:transparentZone];
    }
    
    // Highcharts 会自动处理最后一个 zone 之后到数据末尾的部分，让它恢复成默认颜色，
    // 所以我们同样无需手动定义最后一个可见区域。
    
    return zones;
}

// 虚拟数据序列创建-曲线图堆叠使用
- (AASeriesElement *)createVirtualElementWithArray:(NSArray<HMAASeriesElement *> *)elements {
    AASeriesElement *virtualElement = AASeriesElement.new
        .nameSet(@"")
        .typeSet(AAChartTypeAreaspline)
        .colorSet(@"#FFFFFF00");
    NSMutableArray *data = [NSMutableArray array];
    for (int i = 0; i < elements.firstObject.data.count; i ++) {
        float x = 0.0;
        bool isAllNull = YES;//全为空判断
        for (HMAASeriesElement *obj in elements) {
            if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {// 需要满足可以转数值
                x += [obj.data[i] doubleValue];
                isAllNull= NO;
            }
        }
        if (isAllNull) {
            [data addObject:NSNull.null];
        } else {
            NSDecimalNumber *number = [NSDecimalNumber decimalNumberWithDecimal:@(fabs(x)).decimalValue];
            [data addObject:number];
        }
    }
    virtualElement.dataSet(data);
    return virtualElement;
}

// 图表计算数据最大绝对值数组 index 根据Y轴
- (NSArray *)maxFabsNumberArrayYAxisIndex:(NSInteger)index {
    NSMutableArray *totalNumberArray = [NSMutableArray array];
    if (self.seriesArray.count > 1) {
        // 组数据大于一条
        for (HMAASeries *series in self.seriesArray) {
            NSMutableArray *numberArray = [NSMutableArray array];
            for (int i = 0; i < series.element.firstObject.data.count; i ++) {
                float x = 0.0;
                for (HMAASeriesElement *obj in series.element) {
                    if (obj.yAxis.integerValue != index) {
                        continue;
                    }
                    if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                        if (_chartModel.stackType == HMAAChartStackingTypeNormal) {
                            float sum = x + [obj.data[i] floatValue];
                            x = fabs(x) > fabs([obj.data[i] floatValue]) ? x : [obj.data[i] floatValue];
                            x = fabs(x) > fabs(sum) ? x : sum;
                        }
                        if (_chartModel.stackType == HMAAChartStackingTypeFalse) {
                            x = fabs(x) > fabs([obj.data[i] floatValue]) ? x : [obj.data[i] floatValue];
                        }
                    }
                }
                [numberArray addObject:@(x)];
            }
            [totalNumberArray addObject:numberArray];
        }
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.element.count > 1) {
            // 数据只有一组，但组内有多个数据组
            NSMutableArray *numberArray = [NSMutableArray array];
            for (int i = 0; i < series.element.firstObject.data.count; i ++) {
                float x = 0.0;
                for (HMAASeriesElement *obj in series.element) {
                    if (obj.yAxis.integerValue != index) {
                        continue;
                    }
                    if (i < obj.data.count && [HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                        if (_chartModel.stackType == HMAAChartStackingTypeNormal) {
                            float sum = x + [obj.data[i] floatValue];
                            x = fabs(x) > fabs([obj.data[i] floatValue]) ? x : [obj.data[i] floatValue];
                            x = fabs(x) > fabs(sum) ? x : sum;
                        }
                        if (_chartModel.stackType == HMAAChartStackingTypeFalse) {
                            x = fabs(x) > fabs([obj.data[i] floatValue]) ? x : [obj.data[i] floatValue];
                        }
                    }
                }
                [numberArray addObject:@(x)];
            }
            [totalNumberArray addObject:numberArray];
        } else if (series.element.count == 1) {
            HMAASeriesElement *obj = series.element.firstObject;
            if (obj.yAxis.integerValue != index) {
                return totalNumberArray;
            }
            NSMutableArray *numberArray = [NSMutableArray array];
            for (int i = 0; i < obj.data.count; i ++) {
                if ([HMAASeriesUtil canTranslateToNum:obj.data[i]]) {
                    if ([obj.data[i] isKindOfClass:[NSNumber class]]) {
                        [numberArray addObject:obj.data[i]];
                    } else {
                        NSString *str = [NSString stringWithFormat:@"%@", obj.data[i]];
                        [numberArray addObject:[NSDecimalNumber decimalNumberWithString:str]];
                    }
                } else {//null直接插入
                    [numberArray addObject:obj.data[i]];
                }
            }
            [totalNumberArray addObject:numberArray];
        }
    }
    return totalNumberArray;
}

#pragma mark help method

- (NSString *)hexStringFromAlpha:(CGFloat)alpha {
    // 1. 修正 alpha 范围（防止传入负数/大于1的值）
    CGFloat normalizedAlpha = MAX(0.0, MIN(1.0, alpha));
    
    // 2. 映射为 0~255 的整数（四舍五入保证精度）
    NSInteger decimalValue = round(normalizedAlpha * 255.0);
    
    // 3. 转为两位十六进制（大写，不足两位补 0）
    // %02lX：02=补0到两位，l=适配NSInteger，X=大写十六进制（小写用x）
    NSString *hexStr = [NSString stringWithFormat:@"%02lX", decimalValue];
    
    return hexStr;
}

@end
