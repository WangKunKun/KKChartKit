//
//  HMMTAAChartView.h
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/5/6.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// 竖列多个封装图表HMMTAAChartView
@class HMAAChartModel;
@interface HMMTAAChartView : UIView

@property (nonatomic, copy) NSArray<HMAAChartModel *> *chartModels;//图表模型

// 每个图表的宽高属性
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;

// ---------- 暂无数据自定义 ----------
@property (nonatomic, copy) NSString *nodImgName;// 图片
@property (nonatomic, copy) NSString *nodText;// 文案
@property (nonatomic, strong) UIColor *nodColor;// 字体颜色
@property (nonatomic, strong) UIFont *nodFont;// 字体字号

// 初始化图表
- (void)initChartView;

@end

NS_ASSUME_NONNULL_END
