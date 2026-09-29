//
//  HMAAChartModel.m
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/4/29.
//

#import "HMAAChartModel.h"
#import "HMAASeries.h"

@implementation HMAAChartModel

// 初始化图表默认颜色配置
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configColor];
    }
    return self;
}

- (void)configColor {
    _titleColorArr = @[@"#141414", @"#FFFFFF"];
    _crosshairColorArr = @[@"#141414", @"#FFFFFF"];
    _dashColorArr = @[@"#D8DDE4", @"#494F59"];
    _xAxisTextColorArr = @[@"#64686F", @"#B3B3B3"];
    _yAxisTextColorArr = @[@"#64686F", @"#B3B3B3"];
    _toolTipBackgroundColorArr = @[@"#FFFFFFB3", @"#64686FB3"];
    _toolTipTextColorArr = @[@"#141414", @"#EFF0F1"];
}

- (NSArray<HMAASeries *> *)showSeriesArray {
    // 重构数据序列-去除图例隐藏序列
    NSMutableArray *showSeriesArray = [NSMutableArray array];
    for (HMAASeries *series in self.seriesArray) {
        NSMutableArray *elementsArray = [NSMutableArray array];
        NSMutableArray *hiddenIndexs = [NSMutableArray array];//针对2.0版本分组分割线
        for (int i = 0; i < series.element.count; i ++) {
            HMAASeriesElement *element = series.element[i];
            if (!element.isHidden) {
                [elementsArray addObject:element];
            } else {
                [hiddenIndexs addObject:@(i)];
            }
        }
        if (elementsArray.count > 0) {
            HMAASeries *newSeries = series.copy;
            newSeries.element = elementsArray;
            [showSeriesArray addObject:newSeries];
            
            if (self.version == 2 && series.stackGroupInterval) {// 2.0版本针对分割线处理
                NSInteger endInterval = series.stackGroupInterval.integerValue;
                for (NSNumber *index in hiddenIndexs) {
                    if (index.integerValue < series.stackGroupInterval.integerValue) {
                        endInterval --;
                    }
                }
                newSeries.stackGroupInterval = @(endInterval);
            }
        }
    }
    return showSeriesArray.copy;
}
    
@end

@implementation HMAAYAxis

- (instancetype)init
{
    self = [super init];
    if (self) {
        _yAxisTextColor = @"#64686F";
    }
    return self;
}

@end

@implementation HMChartHeaderModel

@end

@implementation HMChartSunModel

- (instancetype)initSunriseModel
{
    self = [super init];
    if (self) {
        self.icon = @"ct_ic_sunrise";
    }
    return self;
}

- (instancetype)initSunsetModel
{
    self = [super init];
    if (self) {
        self.icon = @"ct_ic_sunset";
    }
    return self;
}

@end
