//
//  HMTooltipTool.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/11/18.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import "HMTooltipTool.h"
#import "HMAAChartModel.h"
#import "AAChartKit.h"
#import "HMAASeries.h"
#import "HMTooltip.h"
#import "HMIconTooltip.h"
#import "HMChartTool.h"

@interface HMTooltipTool ()

@property (nonatomic, strong) NSArray<HMAASeries *> *seriesArray;// 最终数据-去掉图例隐藏数据

@property (nonatomic, assign) BOOL hasHidePoint;//有被隐藏的点

@end

@implementation HMTooltipTool

#pragma mark - method
- (void)setChartModel:(HMAAChartModel *)chartModel {
    _chartModel = chartModel;
    _seriesArray = chartModel.showSeriesArray;
    self.hasHidePoint = NO;
}

- (AATooltip *)createAATooltip {
    NSString *formatterString = [self formatterString];
    AATooltip *cusTomToolTip = AATooltip.new
        .backgroundColorSet(_chartModel.toolTipBackgroundColor)
        .borderRadiusSet(@16)
        .borderWidthSet(@0)
        .styleSet(AAStyleColorSizeWeight(_chartModel.toolTipTextColor, 14, AAChartFontWeightTypeBold))
        .useHTMLSet(false)
        .formatterSet(formatterString);
    
    for (HMAASeries * series in self.seriesArray) {
        for (HMAASeriesElement * element in series.element) {
            if (element.hidePoints.count > 0) {
                self.hasHidePoint = YES;
                break;
            }
        }
    }
    
    if (self.seriesArray.count > 1) {//展示html分割线
        cusTomToolTip.useHTMLSet(true);
    }
    
    if (_chartModel.tooltipPinToTop) {
        // tooltip置顶
        cusTomToolTip.positionerSet(@AAJSFunc(function (labelWidth, labelHeight, point) {
            const position = {};
            const chart = this.chart;
            const plotLeft = chart.plotLeft;
            const plotWidth = chart.plotWidth;
            const chartWidth = chart.chartWidth;
            
            let x = point.plotX + plotLeft;
            
            // 边界检测
            if (x + labelWidth / 2 > chartWidth) {
                // 右侧超出，向左调整
                x = chartWidth - labelWidth - 8;
            } else if (x - labelWidth / 2 < 0) {
                // 左侧超出，贴左绘制
                x = 0;
            } else {
                // 正常情况，水平居中
                x = x - labelWidth / 2;
            }
                    
            position["x"] = x;
            position["y"] = 0;
            return position;
        }));
    } else if (self.hasHidePoint) {
        cusTomToolTip.positionerSet(@AAJSFunc(function (labelWidth, labelHeight, point) {
            
            
            var position = {};
            var target = point;

            // ✅ 替代点逻辑（保持你原来的）
            if (point && point.options && point.options.custom && point.options.custom.hide) {
                var hoverPoints = this.chart.hoverPoints || [];

                for (var i = 0; i < hoverPoints.length; i++) {
                    var p = hoverPoints[i];
                    if (p && (!p.options || !p.options.custom || !p.options.custom.hide)) {
                        target = p;
                        break;
                    }
                }
            }

            if (!target || target.plotX === undefined || target.plotY === undefined) {
                target = point;
            }

            var chart = this.chart;

            // 👉 点的绝对位置
            var pointX = target.plotX + chart.plotLeft;
            var pointY = target.plotY + chart.plotTop;

            // 🔥 关键：判断上方空间是否足够
            var margin = 10;
            var spaceAbove = pointY - chart.plotTop;
            var spaceBelow = chart.plotTop + chart.plotHeight - pointY;

            var x = pointX - labelWidth / 2;
            var y;

            if (spaceAbove >= labelHeight + margin) {
                // ✅ 放上面（优先）
                y = pointY - labelHeight - margin;
            } else if (spaceBelow >= labelHeight + margin) {
                // ✅ 放下面
                y = pointY + margin;
            } else {
                // ✅ 都不够 → 选空间更大的方向
                if (spaceAbove > spaceBelow) {
                    y = chart.plotTop;
                } else {
                    y = chart.plotTop + chart.plotHeight - labelHeight;
                }
            }

            // 🔥 左右边界限制（保持）
            var minX = chart.plotLeft;
            var maxX = chart.plotLeft + chart.plotWidth - labelWidth;

            if (x < minX) {
                x = minX;
            } else if (x > maxX) {
                x = maxX;
            }

            position["x"] = x;
            position["y"] = y;

            return position;
        }));
    }
    
    return cusTomToolTip;
}

- (NSString *)formatterString {
    // tooltip数据
    NSString *formatterString = @"";
    
//    // 组装横轴数据标题字典并转为json
//    NSMutableDictionary *xSeriesTitles = [NSMutableDictionary dictionary];
//    if (_chartModel.xAxisArray.count <= _chartModel.xSeriesArray.count) {
//        for (int i = 0; i < _chartModel.xAxisArray.count; i ++) {
//            if ([_chartModel.xAxisArray[i] isKindOfClass:[NSString class]]) {
//                [xSeriesTitles setObject:_chartModel.xSeriesArray[i] forKey:_chartModel.xAxisArray[i]];
//            }
//        }
//    }
//    NSError *error;
//    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:xSeriesTitles
//                                                       options:0 // 你可以添加 NSJSONWritingOptions 的值来格式化输出
//                                                         error:&error];
//    NSString *xSeriesTitlesJson = @"";
//    if (!jsonData) {
//        // 如果转换失败，处理错误
//        NSLog(@"Error converting dictionary to JSON: %@", error);
//    } else {
//        // 将 NSData 转换为 NSString
//        xSeriesTitlesJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//    }
//    NSString *headJS = [NSString stringWithFormat:(@AAJSFunc(var xSeriesTitles = %@;
//                        var s = '<b>' + (xSeriesTitles[this.x] || '未知标题') + '</b>' + '<br/>';)), xSeriesTitlesJson];
    
    // 横轴数据标题数组转为json
    NSString *xSeriesTitlesJson = [HMAASeriesUtil jsonSerializsWithArray:_chartModel.xSeriesArray];
    NSString *headJS = [NSString stringWithFormat:(@AAJSFunc(var xSeriesTitles = %@;
                        var s = '<b>' + (xSeriesTitles[this.point.index] || '未知标题') + '</b>' + '<br/>';)), xSeriesTitlesJson];

    
    // 数据content处理
    NSString *contentJS = @"";
    if (self.seriesArray.count > 1) {
        // 组数据大于一条
        int t = 0; // 计算每组数据之和
        for (HMAASeries *series in self.seriesArray) {
            // 组装tooltip弹窗数值并转为json
            [series formatGroupData];
            NSString *groupJson = [HMAASeriesUtil jsonSerializsWithArray:series.fgdata];
            
            NSString *gnameJson = [HMAASeriesUtil jsonSerializsWithArray:series.gnames];
            
            NSMutableArray *totalDatas = [NSMutableArray array];
            for (HMAASeriesElement *element in series.element) {
                [element formatData];
                [totalDatas addObject:element.fdata];
            }
            NSArray *fTotalDatas = [HMAASeriesUtil formatNullElements:totalDatas];
            NSString *datasJson = [HMAASeriesUtil jsonSerializsWithArray:fTotalDatas];
            
            NSMutableArray *totalNames = [NSMutableArray array];
            for (HMAASeriesElement *element in series.element) {
                [totalNames addObject:element.names];
            }
            NSArray *fTotalNames = [HMAASeriesUtil formatNullElements:totalNames];
            NSString *namesJson = [HMAASeriesUtil jsonSerializsWithArray:fTotalNames];
            
            if (t > 0) {// 分割线
                contentJS = [contentJS stringByAppendingString:@AAJSFunc(s += '<hr>';)];
            }
            NSString *newContentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                                           var start = %d;
                                                                           var end = %d;
                                                                           var i = this.point.index;
                                                                           var gdatas = %@;
                                                                           s += gnames[i] + ': ' + gdatas[i] + '<br/>';//副标题
                                                                           var names = %@;
                                                                           var datas = %@;
                                                                           this.points.slice(start, end)%@.forEach(function(point, index) {
                if (point.point.options.custom && point.point.options.custom.hide) {
                    return;
                }
                                                                               const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                                                               s += colorDot + names[index][i] + ': ' + datas[index][i] + '<br/>';
                                                                           });
                                                                           )),
                                      gnameJson, t, t + (int)series.element.count, groupJson, namesJson, datasJson, _chartModel.reverse ? @".reverse()" : @""];
            if (series.onlyNameIntooltip) {
                newContentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                                               var start = %d;
                                                                               var end = %d;
                                                                               var i = this.point.index;
                                                                               s += gnames[i] + '<br/>';//副标题
                                                                               var names = %@;
                                                                               this.points.slice(start, end)%@.forEach(function(point, index) {
                    if (point.point.options.custom && point.point.options.custom.hide) {
                        return;
                    }
                                                                                   const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                                                                   s += colorDot + names[index][i] + '<br/>';
                                                                               });
                                                                               )),
                                          gnameJson, t, t + (int)series.element.count, namesJson, _chartModel.reverse ? @".reverse()" : @""];
            }
            contentJS = [contentJS stringByAppendingString:newContentJS];
            if (_chartModel.chartType == HMAAChartTypeAreaspline && _chartModel.stackType == HMAAChartStackingTypeNormal) {//曲线填充图
                t += series.element.count + 1;//多组数据一正一负时+1越过虚拟数据组
            } else {
                t += series.element.count;
            }
        }
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.element.count > 1) {// 组装tooltip弹窗数值并转为json
            [series formatGroupData];
            NSString *groupJson = [HMAASeriesUtil jsonSerializsWithArray:series.fgdata];
            
            NSString *gnameJson = [HMAASeriesUtil jsonSerializsWithArray:series.gnames];
            
            NSMutableArray *totalDatas = [NSMutableArray array];
            for (HMAASeriesElement *element in series.element) {
                [element formatData];
                [totalDatas addObject:element.fdata];
            }
            NSArray *fTotalDatas = [HMAASeriesUtil formatNullElements:totalDatas];
            NSString *datasJson = [HMAASeriesUtil jsonSerializsWithArray:fTotalDatas];
            
            NSMutableArray *totalNames = [NSMutableArray array];
            for (HMAASeriesElement *element in series.element) {
                [totalNames addObject:element.names];
            }
            NSArray *fTotalNames = [HMAASeriesUtil formatNullElements:totalNames];
            NSString *namesJson = [HMAASeriesUtil jsonSerializsWithArray:fTotalNames];

            contentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                              var i = this.point.index;
                                                              var gdatas = %@;
                                     s += gnames[i] + ': ' + gdatas[i] + '<br/>';//副标题
                                                              var names = %@;
                                                              var datas = %@;
                                     this.points%@.forEach(function(point, index) {
                if (point.point.options.custom && point.point.options.custom.hide) {
                    return;
                }
                                     const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                     s += colorDot + names[index][i] + ': ' + datas[index][i] + '<br/>';
                                    });)), gnameJson, groupJson, namesJson, datasJson, _chartModel.reverse ? @".reverse()" : @""];
            if (series.onlyNameIntooltip) {
                contentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                                  var i = this.point.index;
                                         s += gnames[i] + '<br/>';//副标题
                                                                  var names = %@;
                                         this.points%@.forEach(function(point, index) {
                    if (point.point.options.custom && point.point.options.custom.hide) {
                        return;
                    }
                                         const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                         s += colorDot + names[index][i] + '<br/>';
                                        });)), gnameJson, namesJson, _chartModel.reverse ? @".reverse()" : @""];
            }
            if (series.gname.length == 0) {
                // 没有组名意味着不需要求和行
                contentJS = [NSString stringWithFormat:(@AAJSFunc(var i = this.point.index;
                                                                  var names = %@;
                                                                  var datas = %@;
                                         this.points%@.forEach(function(point, index) {
                    if (point.point.options.custom && point.point.options.custom.hide) {
                        return;
                    }
                                         const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                         s += colorDot + names[index][i] + ': ' + datas[index][i] + '<br/>';
                                        });)), namesJson, datasJson, _chartModel.reverse ? @".reverse()" : @""];
                if (series.onlyNameIntooltip) {
                    contentJS = [NSString stringWithFormat:(@AAJSFunc(var i = this.point.index;
                                                                      var names = %@;
                                             this.points%@.forEach(function(point, index) {
                        if (point.point.options.custom && point.point.options.custom.hide) {
                            return;
                        }
                                             const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                             s += colorDot + names[index][i] + '<br/>';
                                            });)), namesJson, _chartModel.reverse ? @".reverse()" : @""];
                }
            }
            if (_chartModel.chartType == HMAAChartTypeAreaspline && _chartModel.stackType == HMAAChartStackingTypeNormal) {//曲线填充图堆叠
                contentJS = [NSString stringWithFormat:(@AAJSFunc(var i = this.point.index;
                                                                  var names = %@;
                                                                  var datas = %@;
                                                                  var end = %ld;
                                         this.points%@.slice(0, end).forEach(function(point, index) {
                                         const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                         s += colorDot + names[index][i] + ': ' + datas[index][i] + '<br/>';
                });)), namesJson, datasJson, series.element.count, _chartModel.reverse ? @".reverse()" : @""];
                if (series.onlyNameIntooltip) {
                    contentJS = [NSString stringWithFormat:(@AAJSFunc(var i = this.point.index;
                                                                      var names = %@;
                                                                      var end = %ld;
                                             this.points%@.slice(0, end).forEach(function(point, index) {
                                             const colorDot = '<span style=\"' + 'color:' + point.series.color +'; font-size:13px\"' + '>●</span> ';
                                             s += colorDot + names[index][i] + '<br/>';
                    });)), namesJson, series.element.count, _chartModel.reverse ? @".reverse()" : @""];
                }
            }
        } else if (series.element.count == 1) {
            // 组装tooltip弹窗数值并转为json
            HMAASeriesElement *element = series.element.firstObject;
            [series formatGroupData];
            NSString *groupJson = [HMAASeriesUtil jsonSerializsWithArray:series.fgdata];
            NSString *gnameJson = [HMAASeriesUtil jsonSerializsWithArray:series.gnames];
            [element formatData];
            NSString *datasJson = [HMAASeriesUtil jsonSerializsWithArray:element.fdata];
            NSString *namesJson = [HMAASeriesUtil jsonSerializsWithArray:element.names];
            contentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                              var gdatas = %@;
                                                              var names = %@;
                                                              var datas = %@;
                                                              var i = this.point.index;
                                                              s += gnames[i] + ': ' + gdatas[i] + '<br/>';//副标题
                                                              const colorDot = '<span style=\"' + 'color:' + this.point.series.color +'; font-size:13px\"' + '>●</span> ';
                                                              s += colorDot + names[i] + ': ' + datas[i] + '<br/>';)), gnameJson, groupJson, namesJson, datasJson];
            if (series.onlyNameIntooltip) {
                contentJS = [NSString stringWithFormat:(@AAJSFunc(var gnames = %@;
                                                                  var names = %@;
                                                                  var i = this.point.index;
                                                                  s += gnames[i] + '<br/>';//副标题
                                                                  const colorDot = '<span style=\"' + 'color:' + this.point.series.color +'; font-size:13px\"' + '>●</span> ';
                                                                  s += colorDot + names[i] + '<br/>';)), gnameJson, namesJson];
            }
            if (series.gname.length == 0) {
                contentJS = [NSString stringWithFormat:(@AAJSFunc(var names = %@;
                                                                  var datas = %@;
                                                                  s += names[this.point.index] + ': ' + datas[this.point.index] + '<br/>';)), namesJson, datasJson];
                if (series.onlyNameIntooltip) {
                    contentJS = [NSString stringWithFormat:(@AAJSFunc(var names = %@;
                                                                      s += names[this.point.index] + '<br/>';)), namesJson];
                }
            }
        }
    }
        
    formatterString = [NSString stringWithFormat:(@AAJSFunc(function () {
        %@
        %@
        return s;
    })), headJS, contentJS];

    return formatterString;
}

// 创建原生版本的Tooltip
- (HMTooltip *)createNATooltip {
    HMTooltip *tooltip = [[HMTooltip alloc] init];
    tooltip.xSeriesArray = _chartModel.xSeriesArray;
    tooltip.seriesArray = self.seriesArray;
    tooltip.backgroundColor = [HMChartTool colorWithHexString:_chartModel.toolTipBackgroundColor];
    tooltip.textColor = [HMChartTool colorWithHexString:_chartModel.toolTipTextColor];
    [tooltip drawDataSubviews];
    return tooltip;
}

// 创建ver2版本的Tooltip
- (HMIconTooltip *)createIconTooltip {
    HMIconTooltip *tooltip = [[HMIconTooltip alloc] init];
    tooltip.xSeriesArray = _chartModel.xSeriesArray;
    tooltip.seriesArray = self.seriesArray;
    tooltip.backgroundColor = [HMChartTool colorWithHexString:_chartModel.toolTipBackgroundColor];
    [tooltip drawDataSubviews];
    return tooltip;
}

@end
