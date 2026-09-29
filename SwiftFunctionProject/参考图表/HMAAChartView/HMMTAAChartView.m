//
//  HMMTAAChartView.m
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/5/6.
//

#import "HMMTAAChartView.h"
#import "HMLGAAChartView.h"
#import "HMAAChartModel.h"

@interface HMMTAAChartView ()

@property (nonatomic, copy) NSArray<HMLGAAChartView *> *charts;

@end

@implementation HMMTAAChartView

// 初始化图表
- (void)initChartView {
    NSMutableArray *arr = [NSMutableArray array];
    for (int i = 0; i < self.chartModels.count; i ++) {
        HMAAChartModel *model = self.chartModels[i];
        HMLGAAChartView *aaChart = [[HMLGAAChartView alloc] init];
        aaChart.frame = CGRectMake(0, _height * i, _width, _height);
        [self addSubview:aaChart];
        [aaChart reloadDataWithModel:model];
        [arr addObject:aaChart];
    }
    self.charts = arr;
    
    [self connectAllCharts];
}

- (void)connectAllCharts {
    for (int i = 0; i < self.charts.count; i ++) {
        HMLGAAChartView *aaChart = self.charts[i];
        __weak typeof(self) weakSelf = self;
        aaChart.clickBlock = ^(NSInteger index) {
            for (HMLGAAChartView *chart in weakSelf.charts) {
                if (chart != aaChart) {
                    [chart setTouchPointXIndex:index];
                }
            }
        };
    }
}

@end
