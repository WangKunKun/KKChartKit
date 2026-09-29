//
//  HMChartLegengView.m
//  hemaiInstall
//
//  Created by wangkun on 2026/4/15.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import "HMChartLegengView.h"
#import "HMAAChartModel.h"
#import "HMAASeries.h"


@interface _LegengView : UIView

@property (nonatomic, strong) UIView * dot;
@property (nonatomic, strong) UILabel * label;

@end

@implementation _LegengView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self configUI];
    }
    return self;
}

- (void)configUI {
    self.layer.cornerRadius = 12;
    [self addSubview:self.dot];
    [self addSubview:self.label];
    
    [self.dot mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.left.equalTo(self).offset(8);
        make.width.height.equalTo(@12);
    }];
    
    [self.label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.dot.mas_right).offset(4);
        make.centerY.equalTo(self);
    }];
}

- (UIView *)dot {
    if (!_dot) {
        _dot = [UIView new];
        _dot.layer.cornerRadius = 6;
    }
    return _dot;
}

- (UILabel *)label {
    if (!_label) {
        _label = [UILabel new];
        _label.font = Font_Size_weight(10, UIFontWeightMedium);
    }
    return _label;
}

@end

@interface HMChartLegengView ()

@property (nonatomic, strong) HMAAChartModel *chartModel;

@property (nonatomic, strong) NSArray <_LegengView *> * views;

@end

@implementation HMChartLegengView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
+ (instancetype)createWithModel:(HMAAChartModel *)model {
    HMChartLegengView * view = [HMChartLegengView new];
    view.chartModel = model;
    [view createLegengListView];
    return view;
}

- (void)createLegengListView {
    NSMutableArray * list = [NSMutableArray array];
    
//    for (<#type *object#> in <#collection#>) {
//        <#statements#>
//    }
    
}


//{
//    if (!_legendBgView) {
//        _legendBgView = [[UIView alloc] init];
//        [self addSubview:_legendBgView];
//    }
//    [_legendBgView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
//    
//    NSInteger row = model.seriesArray.count;
//    // 绘制按钮
//    if (model.seriesArray.count > 1) {
//        int t = 0;
//        for (int i = 0; i < model.seriesArray.count; i++) {
//            HMAASeries *series = model.seriesArray[i];
//            CGFloat lastWidth = 6;
//            for (int j = 0; j < series.element.count; j++) {
//                HMAASeriesElement *element = series.element[j];
//                UIView *vi = [[UIView alloc] init];
//                vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
//                vi.layer.cornerRadius = 12;
//                UIView *dot = [[UIView alloc] init];
//                dot.backgroundColor = [self colorWithHexString:element.color];
//                dot.layer.cornerRadius = 6;
//                dot.frame = CGRectMake(8, 6, 12, 12);
//                [vi addSubview:dot];
//                UILabel *lab = [[UILabel alloc] init];
//                lab.text = element.name;
//                lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
//                CGSize size = [lab sizeThatFits:CGSizeZero];
//                lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
//                [vi addSubview:lab];
//                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
//                if (lastWidth + viewWidth > self.bounds.size.width) {
//                    t ++;
//                    lastWidth = 6;
//                }
//                vi.frame = CGRectMake(lastWidth, (i + t) * (24 + 12), viewWidth, 24);
//                lastWidth += vi.bounds.size.width + 12;
//                vi.alpha = element.isHidden ? 0.3 : 1;
//                [_legendBgView addSubview:vi];
//                // 设置图表展示开关
//                vi.tag = i * 10 + j;
//                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
//                [vi addGestureRecognizer:tap];
//            }
//        }
//        row += t;
//    } else {
//        HMAASeries *series = model.seriesArray.firstObject;
//        if (series.element.count > 1) {
//            CGFloat lastWidth = 6;
//            int t = 0;
//            for (int j = 0; j < series.element.count; j++) {
//                HMAASeriesElement *element = series.element[j];
//                UIView *vi = [[UIView alloc] init];
//                vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
//                vi.layer.cornerRadius = 12;
//                UIView *dot = [[UIView alloc] init];
//                dot.backgroundColor = [self colorWithHexString:element.color];
//                dot.layer.cornerRadius = 6;
//                dot.frame = CGRectMake(8, 6, 12, 12);
//                [vi addSubview:dot];
//                UILabel *lab = [[UILabel alloc] init];
//                lab.text = element.name;
//                lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
//                CGSize size = [lab sizeThatFits:CGSizeZero];
//                lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
//                [vi addSubview:lab];
//                CGFloat viewWidth = 8 + 12 + 4 + size.width + 8;
//                if (lastWidth + viewWidth > self.bounds.size.width) {
//                    t ++;
//                    lastWidth = 6;
//                }
//                vi.frame = CGRectMake(lastWidth, t * (24 + 12), viewWidth, 24);
//                lastWidth += vi.bounds.size.width + 12;
//                vi.alpha = element.isHidden ? 0.3 : 1;
//                [_legendBgView addSubview:vi];
//                // 设置图表展示开关
//                vi.tag = j;
//                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
//                [vi addGestureRecognizer:tap];
//            }
//            row += t;
//        } else {
//            HMAASeriesElement *element = series.element.firstObject;
//            UIView *vi = [[UIView alloc] init];
//            vi.backgroundColor = [self colorWithHexString:element.legendBgColor alpha:element.legendBgColorAlpha];
//            vi.layer.cornerRadius = 12;
//            UIView *dot = [[UIView alloc] init];
//            dot.backgroundColor = [self colorWithHexString:element.color];
//            dot.layer.cornerRadius = 6;
//            dot.frame = CGRectMake(8, 6, 12, 12);
//            [vi addSubview:dot];
//            UILabel *lab = [[UILabel alloc] init];
//            lab.text = element.name;
//            lab.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
//            CGSize size = [lab sizeThatFits:CGSizeZero];
//            lab.frame = CGRectMake(8 + 12 + 4, 0, size.width, 24);
//            [vi addSubview:lab];
//            vi.frame = CGRectMake(0, 0, 8 + 12 + 4 + size.width + 8, 24);
//            vi.center = CGPointMake(self.bounds.size.width / 2, vi.center.y);
//            vi.alpha = element.isHidden ? 0.3 : 1;
//            [_legendBgView addSubview:vi];
//            // 设置图表展示开关
//            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(legendTapAction:)];
//            [vi addGestureRecognizer:tap];
//        }
//    }
//    
//    CGFloat legendHeight = row * (24 + 12) - 12;
//    if (model.chartHeight > 0) {
//        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, model.chartHeight);
//    } else {
//        _chartView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - legendHeight);
//    }
//    _legendBgView.frame = CGRectMake(0, _chartView.bounds.size.height, self.bounds.size.width, legendHeight);
//    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, _chartView.bounds.size.width, _chartView.bounds.size.height + legendHeight);
//}



@end
