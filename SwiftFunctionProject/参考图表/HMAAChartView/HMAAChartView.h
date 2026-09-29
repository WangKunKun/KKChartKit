//
//  HMAAChartView.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2024/12/11.
//  Copyright © 2024 hemaiInstall. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HMAAChartView, HMAAChartModel;
@protocol HMAAChartViewDelegate <NSObject>

- (void)hmaaChartView:(HMAAChartView *)chartView handlePan:(UIPanGestureRecognizer *)gesture;

@end

// 基础封装图表HMAAChartView
@interface HMAAChartView : UIView

@property (nonatomic, weak) id<HMAAChartViewDelegate> delegate;

@property (nonatomic, copy) void(^clickBlock)(NSInteger index); // 图表点击回调
@property (nonatomic, copy) void(^finishLoad)(void); // 渲染完成？

// ---------- 暂无数据自定义 ----------
@property (nonatomic, copy) NSString *nodImgName;// 图片
@property (nonatomic, copy) NSString *nodText;// 文案
@property (nonatomic, strong) UIColor *nodColor;// 字体颜色
@property (nonatomic, strong) UIFont *nodFont;// 字体字号

// 初始化图表数据 配置完model后调用
- (void)initChartViewWithModel:(HMAAChartModel *)model;

// 刷新界面
- (void)reloadDataWithModel:(HMAAChartModel *)model;

// 只刷新数据
- (void)onlyRefreshTheChartData;

// 设置选中某一个点
- (void)setTouchPointXIndex:(NSInteger)xIndex;

// 显示暂无数据
- (void)showNoData:(BOOL)show;

@end


NS_ASSUME_NONNULL_END
