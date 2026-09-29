//
//  HMLGAAChartView.h
//  HMAAChartViewDemo
//
//  Created by HoymilesMac2024xjc on 2025/4/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// 带图例的封装图表HMLGAAChartView
@class HMLGAAChartView, HMAAChartModel, HMAASeriesElement;
@protocol HMLGAAChartViewDelegate <NSObject>

- (void)hmlgaaChartView:(HMLGAAChartView *)chartView handlePan:(UIPanGestureRecognizer *)gesture;

@end

@interface HMLGAAChartView : UIView

@property (nonatomic, weak) id<HMLGAAChartViewDelegate> delegate;

@property (nonatomic, copy) void(^clickBlock)(NSInteger index); // 图表点击回调
@property (nonatomic, copy) void(^legendTapBlock)(HMAASeriesElement *element); // 图表标签点击回调
@property (nonatomic, copy) void(^snapClosure)(UIImage *img); //截图完成回调

@property (nonatomic, assign) BOOL triggerSnap;//触发截图 优化AI使用

@property (nonatomic, assign) BOOL showEnlargeButton;// 显示放大按钮 默认隐藏

// ---------- 暂无数据自定义 ----------
@property (nonatomic, copy) NSString *nodImgName;// 图片
@property (nonatomic, copy) NSString *nodText;// 文案
@property (nonatomic, strong) UIColor *nodColor;// 字体颜色
@property (nonatomic, strong) UIFont *nodFont;// 字体字号

// 刷新图表
- (void)reloadDataWithModel:(HMAAChartModel *)model;

// 只刷新数据
- (void)onlyRefreshTheChartData;

// 设置选中某一个点
- (void)setTouchPointXIndex:(NSInteger)xIndex;

@end

@interface HMChartLGSwitch : UIView

@property (nonatomic, strong) HMAASeriesElement *element;

@property (nonatomic, assign) BOOL on;

@property (nonatomic, copy) void(^tapSwitchBlock)(void);

@end

NS_ASSUME_NONNULL_END
