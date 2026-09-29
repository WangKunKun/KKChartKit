//
//  HMIconTooltip.m
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/12.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import "HMIconTooltip.h"
#import "HMChartTool.h"
#import "HMAASeries.h"

@interface HMIconTooltip ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *leftLab;
@property (nonatomic, strong) NSArray *leftViews;
@property (nonatomic, strong) UIView *verLine;
@property (nonatomic, strong) UILabel *rightLab;
@property (nonatomic, strong) NSArray *rightViews;
@property (nonatomic, strong) HMIconTooltipItem *item;
@property (nonatomic, strong) UILabel *dataLab;

@end

@implementation HMIconTooltip

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
        ]];
        
        self.layer.cornerRadius = 4.f;
        self.layer.borderWidth = 1.f;
        self.layer.borderColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]].CGColor;
    }
    return self;
}

// 绘制当前数据需要的tooltip类型
- (void)drawDataSubviews {
    __weak typeof(self) weakSelf = self;
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj != weakSelf.titleLabel) {
            [obj removeFromSuperview];
        }
    }];
    
    if (self.seriesArray.count > 1) {//多组
        [self addSubview:self.leftLab];
        [NSLayoutConstraint activateConstraints:@[
            [self.leftLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
            [self.leftLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
        ]];
        
        UIView *vi = nil;
        NSMutableArray *leftViews = [NSMutableArray array];
        for (int i = 0; i < self.seriesArray.firstObject.element.count; i ++) {
            HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
            [self addSubview:item];
            item.translatesAutoresizingMaskIntoConstraints = NO;
            if (vi) {
                [NSLayoutConstraint activateConstraints:@[
                    [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                    [item.leadingAnchor constraintEqualToAnchor:vi.trailingAnchor constant:8],
                ]];
            } else {
                [NSLayoutConstraint activateConstraints:@[
                    [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                    [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                ]];
            }
            vi = item;
            [leftViews addObject:item];
        }
        self.leftViews = leftViews.copy;
        
        [self addSubview:self.verLine];
        NSLayoutConstraint *viTrailConstraint = [self.verLine.leadingAnchor constraintEqualToAnchor:vi.trailingAnchor constant:8];
        viTrailConstraint.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [self.verLine.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
            [self.verLine.leadingAnchor constraintEqualToAnchor:self.leftLab.trailingAnchor constant:8],
            viTrailConstraint,
            [self.verLine.widthAnchor constraintEqualToConstant:1],
            [self.verLine.bottomAnchor constraintEqualToAnchor:vi.bottomAnchor],
        ]];
        
        [self addSubview:self.rightLab];
        [NSLayoutConstraint activateConstraints:@[
            [self.rightLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
            [self.rightLab.leadingAnchor constraintEqualToAnchor:self.verLine.trailingAnchor constant:4],
        ]];
        
        UIView *vir = nil;
        NSMutableArray *rightViews = [NSMutableArray array];
        for (int i = 0; i < self.seriesArray.lastObject.element.count; i ++) {
            HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
            [self addSubview:item];
            item.translatesAutoresizingMaskIntoConstraints = NO;
            if (vir) {
                [NSLayoutConstraint activateConstraints:@[
                    [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                    [item.leadingAnchor constraintEqualToAnchor:vir.trailingAnchor constant:8],
                ]];
            } else {
                [NSLayoutConstraint activateConstraints:@[
                    [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                    [item.leadingAnchor constraintEqualToAnchor:self.verLine.trailingAnchor constant:8],
                ]];
            }
            vir = item;
            [rightViews addObject:item];
        }
        self.rightViews = rightViews.copy;
        
        NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vir.trailingAnchor constant:4];
        virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
            [self.trailingAnchor constraintEqualToAnchor:self.rightLab.trailingAnchor constant:4],
            virTrailConstraint,
            [self.bottomAnchor constraintEqualToAnchor:vir.bottomAnchor constant:4],
        ]];
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.stackGroupInterval) {// 存在分组堆叠
            if (series.stackGroupInterval.integerValue > 0) {
                [self addSubview:self.leftLab];
                [NSLayoutConstraint activateConstraints:@[
                    [self.leftLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                    [self.leftLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                ]];
                
                UIView *vi = nil;
                NSMutableArray *leftViews = [NSMutableArray array];
                for (int i = 0; i < MIN(series.stackGroupInterval.integerValue, series.element.count) ; i ++) {
                    HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                    [self addSubview:item];
                    item.translatesAutoresizingMaskIntoConstraints = NO;
                    if (vi) {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:vi.trailingAnchor constant:8],
                        ]];
                    } else {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                        ]];
                    }
                    vi = item;
                    [leftViews addObject:item];
                }
                self.leftViews = leftViews.copy;
                
                if (series.stackGroupInterval.integerValue < series.element.count) {
                    [self addSubview:self.verLine];
                    NSLayoutConstraint *viTrailConstraint = [self.verLine.leadingAnchor constraintEqualToAnchor:vi.trailingAnchor constant:8];
                    viTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                    [NSLayoutConstraint activateConstraints:@[
                        [self.verLine.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                        [self.verLine.leadingAnchor constraintEqualToAnchor:self.leftLab.trailingAnchor constant:8],
                        viTrailConstraint,
                        [self.verLine.widthAnchor constraintEqualToConstant:1],
                        [self.verLine.bottomAnchor constraintEqualToAnchor:vi.bottomAnchor],
                    ]];
                    
                    [self addSubview:self.rightLab];
                    [NSLayoutConstraint activateConstraints:@[
                        [self.rightLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                        [self.rightLab.leadingAnchor constraintEqualToAnchor:self.verLine.trailingAnchor constant:4],
                    ]];
                    
                    UIView *vir = nil;
                    NSMutableArray *rightViews = [NSMutableArray array];
                    for (int i = (int)series.stackGroupInterval.integerValue; i < series.element.count; i ++) {
                        HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                        [self addSubview:item];
                        item.translatesAutoresizingMaskIntoConstraints = NO;
                        if (vir) {
                            [NSLayoutConstraint activateConstraints:@[
                                [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                                [item.leadingAnchor constraintEqualToAnchor:vir.trailingAnchor constant:8],
                            ]];
                        } else {
                            [NSLayoutConstraint activateConstraints:@[
                                [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                                [item.leadingAnchor constraintEqualToAnchor:self.verLine.leadingAnchor constant:8],
                            ]];
                        }
                        vir = item;
                        [rightViews addObject:item];
                    }
                    self.rightViews = rightViews.copy;
                    
                    if (vir) {
                        NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vir.trailingAnchor constant:4];
                        virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                        [NSLayoutConstraint activateConstraints:@[
                            [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                            [self.trailingAnchor constraintEqualToAnchor:self.rightLab.trailingAnchor constant:4],
                            virTrailConstraint,
                            [self.bottomAnchor constraintEqualToAnchor:vir.bottomAnchor constant:4],
                        ]];
                    }
                } else {
                    NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vi.trailingAnchor constant:4];
                    virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                    [NSLayoutConstraint activateConstraints:@[
                        [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                        [self.trailingAnchor constraintEqualToAnchor:self.leftLab.trailingAnchor constant:4],
                        virTrailConstraint,
                        [self.bottomAnchor constraintEqualToAnchor:vi.bottomAnchor constant:4],
                    ]];
                }
            } else {
                [self addSubview:self.rightLab];
                [NSLayoutConstraint activateConstraints:@[
                    [self.rightLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                    [self.rightLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                ]];
                
                UIView *vir = nil;
                NSMutableArray *rightViews = [NSMutableArray array];
                for (int i = (int)series.stackGroupInterval.integerValue; i < series.element.count; i ++) {
                    HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                    [self addSubview:item];
                    item.translatesAutoresizingMaskIntoConstraints = NO;
                    if (vir) {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:vir.trailingAnchor constant:8],
                        ]];
                    } else {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
                        ]];
                    }
                    vir = item;
                    [rightViews addObject:item];
                }
                self.rightViews = rightViews.copy;
                
                if (vir) {
                    NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vir.trailingAnchor constant:4];
                    virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                    [NSLayoutConstraint activateConstraints:@[
                        [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                        [self.trailingAnchor constraintEqualToAnchor:self.rightLab.trailingAnchor constant:4],
                        virTrailConstraint,
                        [self.bottomAnchor constraintEqualToAnchor:vir.bottomAnchor constant:4],
                    ]];
                }
            }
            
        } else {
            // 存在组名
            if (series.gname.length > 0) {
                [self addSubview:self.leftLab];
                [NSLayoutConstraint activateConstraints:@[
                    [self.leftLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                    [self.leftLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                ]];
                
                NSMutableArray *leftViews = [NSMutableArray array];
                HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                [self addSubview:item];
                item.translatesAutoresizingMaskIntoConstraints = NO;
                [NSLayoutConstraint activateConstraints:@[
                    [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                    [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                ]];
                [leftViews addObject:item];
                self.leftViews = leftViews.copy;
                
                [self addSubview:self.verLine];
                NSLayoutConstraint *itemTrailConstraint = [self.verLine.leadingAnchor constraintEqualToAnchor:item.trailingAnchor constant:8];
                itemTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                [NSLayoutConstraint activateConstraints:@[
                    [self.verLine.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                    [self.verLine.leadingAnchor constraintEqualToAnchor:self.leftLab.trailingAnchor constant:8],
                    itemTrailConstraint,
                    [self.verLine.widthAnchor constraintEqualToConstant:1],
                    [self.verLine.bottomAnchor constraintEqualToAnchor:item.bottomAnchor],
                ]];
                
                [self addSubview:self.rightLab];
                [NSLayoutConstraint activateConstraints:@[
                    [self.rightLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                    [self.rightLab.leadingAnchor constraintEqualToAnchor:self.verLine.trailingAnchor constant:4],
                ]];
                
                UIView *vir = nil;
                NSMutableArray *rightViews = [NSMutableArray array];
                for (int i = 0; i < self.seriesArray.lastObject.element.count; i ++) {
                    HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                    [self addSubview:item];
                    item.translatesAutoresizingMaskIntoConstraints = NO;
                    if (vir) {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:vir.trailingAnchor constant:8],
                        ]];
                    } else {
                        [NSLayoutConstraint activateConstraints:@[
                            [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:20],
                            [item.leadingAnchor constraintEqualToAnchor:self.verLine.trailingAnchor constant:8],
                        ]];
                    }
                    vir = item;
                    [rightViews addObject:item];
                }
                self.rightViews = rightViews.copy;
                
                NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vir.trailingAnchor constant:4];
                virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                [NSLayoutConstraint activateConstraints:@[
                    [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                    [self.trailingAnchor constraintEqualToAnchor:self.rightLab.trailingAnchor constant:4],
                    virTrailConstraint,
                    [self.bottomAnchor constraintEqualToAnchor:vir.bottomAnchor constant:4],
                ]];
            } else {//无组名平铺
                if (series.element.count > 1) {//数据量大于一
                    UIView *vir = nil;
                    NSMutableArray *rightViews = [NSMutableArray array];
                    for (int i = 0; i < self.seriesArray.lastObject.element.count; i ++) {
                        HMIconTooltipItem *item = [[HMIconTooltipItem alloc] init];
                        [self addSubview:item];
                        item.translatesAutoresizingMaskIntoConstraints = NO;
                        if (vir) {
                            [NSLayoutConstraint activateConstraints:@[
                                [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                                [item.leadingAnchor constraintEqualToAnchor:vir.trailingAnchor constant:8],
                            ]];
                        } else {
                            [NSLayoutConstraint activateConstraints:@[
                                [item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                                [item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                            ]];
                        }
                        vir = item;
                        [rightViews addObject:item];
                    }
                    self.rightViews = rightViews.copy;
                    
                    NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:vir.trailingAnchor constant:4];
                    virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                    [NSLayoutConstraint activateConstraints:@[
                        [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                        virTrailConstraint,
                        [self.bottomAnchor constraintEqualToAnchor:vir.bottomAnchor constant:4],
                    ]];
                } else {//仅有一条数据
                    HMAASeriesElement *element = series.element.firstObject;
                    if (element.icon.length > 0) {
                        [self addSubview:self.item];
                        NSLayoutConstraint *virTrailConstraint = [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:self.item.trailingAnchor constant:4];
                        virTrailConstraint.priority = UILayoutPriorityDefaultHigh;
                        [NSLayoutConstraint activateConstraints:@[
                            [self.item.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                            [self.item.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                            [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                            virTrailConstraint,
                            [self.bottomAnchor constraintEqualToAnchor:self.item.bottomAnchor constant:4],
                        ]];
                    } else {
                        [self addSubview:self.dataLab];
                        [NSLayoutConstraint activateConstraints:@[
                            [self.dataLab.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
                            [self.dataLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
                            [self.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:4],
                            [self.trailingAnchor constraintGreaterThanOrEqualToAnchor:self.dataLab.trailingAnchor constant:4],
                            [self.bottomAnchor constraintEqualToAnchor:self.dataLab.bottomAnchor constant:4],
                        ]];
                    }
                }
            }
        }
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:64]//产品需求宽度至少大于64
    ]];
}

// 加载对应x轴索引的数据
- (void)loadTooltipDataIndex:(NSInteger)index {
    self.titleLabel.text = self.xSeriesArray[index];

    if (self.seriesArray.count > 1) {//多组
        HMAASeries *leftSeries = self.seriesArray.firstObject;
        self.leftLab.text = leftSeries.gname;
        for (int i = 0; i < self.leftViews.count; i ++) {
            HMIconTooltipItem *item = self.leftViews[i];
            HMAASeriesElement *element = self.seriesArray.firstObject.element[i];
            [element formatData];
            [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
            if (leftSeries.showElementName) {
                [item loadName:element.hideNameInTooltip?@"":element.names[index]];
            } else {
                [item hiddenName];
            }
        }
        HMAASeries *rightSeries = self.seriesArray.firstObject;
        self.rightLab.text = rightSeries.gname;
        for (int i = 0; i < self.rightViews.count; i ++) {
            HMIconTooltipItem *item = self.rightViews[i];
            HMAASeriesElement *element = self.seriesArray.lastObject.element[i];
            [element formatData];
            [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
            if (rightSeries.showElementName) {
                [item loadName:element.hideNameInTooltip?@"":element.names[index]];
            } else {
                [item hiddenName];
            }
        }
    } else {
        HMAASeries *series = self.seriesArray.firstObject;
        if (series.stackGroupInterval) {// 存在分组堆叠
            self.leftLab.text = series.gname;
            for (int i = 0; i < self.leftViews.count; i ++) {
                HMIconTooltipItem *item = self.leftViews[i];
                HMAASeriesElement *element = series.element[i];
                [element formatData];
                [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
                if (series.showElementName) {
                    [item loadName:element.hideNameInTooltip?@"":element.names[index]];
                } else {
                    [item hiddenName];
                }
            }
            self.rightLab.text = series.gcname;
            for (int i = 0; i < self.rightViews.count; i ++) {
                HMIconTooltipItem *item = self.rightViews[i];
                HMAASeriesElement *element = series.element[i+series.stackGroupInterval.integerValue];
                [element formatData];
                [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
                if (series.showElementName) {
                    [item loadName:element.hideNameInTooltip?@"":element.names[index]];
                } else {
                    [item hiddenName];
                }
            }
        } else {
            if (series.gname.length > 0) {//存在组名
                self.leftLab.text = series.gname;
                HMIconTooltipItem *item = self.leftViews.firstObject;
                [series formatGroupData];
                [item loadItemIcon:series.icon color:series.color data:series.fgdata[index]];
                if (series.showElementName) {
                    [item loadName:series.gname];
                } else {
                    [item hiddenName];
                }
                self.rightLab.text = series.gcname;
                for (int i = 0; i < self.rightViews.count; i ++) {
                    HMIconTooltipItem *item = self.rightViews[i];
                    HMAASeriesElement *element = self.seriesArray.lastObject.element[i];
                    [element formatData];
                    [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
                    if (series.showElementName) {
                        [item loadName:element.hideNameInTooltip?@"":element.names[index]];
                    } else {
                        [item hiddenName];
                    }
                }
            } else {
                if (series.element.count > 1) {//数据量大于一
                    for (int i = 0; i < self.rightViews.count; i ++) {
                        HMIconTooltipItem *item = self.rightViews[i];
                        HMAASeriesElement *element = self.seriesArray.lastObject.element[i];
                        [element formatData];
                        [item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
                        if (series.showElementName) {
                            [item loadName:element.hideNameInTooltip?@"":element.names[index]];
                        } else {
                            [item hiddenName];
                        }
                    }
                } else {
                    HMAASeriesElement *element = series.element.firstObject;
                    [element formatData];
                    if (element.icon.length > 0) {
                        [self.item loadItemIcon:element.icon color:element.color data:element.fdata[index]];
                        if (element.hideNameInTooltip) {
                            [self.item hiddenName];
                        } else {
                            [self.item loadName:element.names[index]];
                        }
                    } else {
                        self.dataLab.text = element.fdata[index];
                    }
                }
            }
        }
    }
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.layer.borderColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]].CGColor;
        self.titleLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.leftLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.rightLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        self.verLine.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
    }
}

#pragma mark - getter
- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _titleLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _titleLabel;
}

- (UILabel *)leftLab {
    if (!_leftLab) {
        _leftLab = [UILabel new];
        _leftLab.font = [UIFont systemFontOfSize:10];
        _leftLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        _leftLab.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _leftLab;
}

- (NSArray *)leftViews {
    if (!_leftViews) {
        _leftViews = [NSArray array];
    }
    return _leftViews;
}

- (UIView *)verLine {
    if (!_verLine) {
        _verLine = [UIView new];
        _verLine.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
        _verLine.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _verLine;
}

- (UILabel *)rightLab {
    if (!_rightLab) {
        _rightLab = [UILabel new];
        _rightLab.font = [UIFont systemFontOfSize:10];
        _rightLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        _rightLab.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _rightLab;
}

- (NSArray *)rightViews {
    if (!_rightViews) {
        _rightViews = [NSArray array];
    }
    return _rightViews;
}

- (HMIconTooltipItem *)item {
    if (!_item) {
        _item = [[HMIconTooltipItem alloc] init];
        _item.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _item;
}

- (UILabel *)dataLab {
    if (!_dataLab) {
        _dataLab = [UILabel new];
        _dataLab.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        _dataLab.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _dataLab;
}

@end

@interface HMIconTooltipItem ()

@property (nonatomic, strong) UILabel *nameLab;
@property (nonatomic, strong) NSLayoutConstraint *imgTopConstraint;
@property (nonatomic, strong) UIImageView *iconImgView;
@property (nonatomic, strong) UILabel *dataLab;

@end

@implementation HMIconTooltipItem

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.nameLab];
        [self addSubview:self.iconImgView];
        [self addSubview:self.dataLab];
        
        self.imgTopConstraint = [self.iconImgView.topAnchor constraintEqualToAnchor:self.topAnchor constant:18];

        [NSLayoutConstraint activateConstraints:@[
            [self.nameLab.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.nameLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.nameLab.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            self.imgTopConstraint,
            [self.iconImgView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.iconImgView.widthAnchor constraintEqualToConstant:16],
            [self.iconImgView.heightAnchor constraintEqualToConstant:16],
            [self.dataLab.topAnchor constraintEqualToAnchor:self.iconImgView.bottomAnchor],
            [self.dataLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.dataLab.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.dataLab.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [self.widthAnchor constraintGreaterThanOrEqualToConstant:32]//产品需求宽度至少大于32
        ]];
    }
    return self;
}

- (void)loadItemIcon:(NSString *)icon color:(NSString *)color data:(NSString *)data {
    self.iconImgView.image = [UIImage imageNamed:icon];
    self.dataLab.text = data;
    NSString * clear = [data stringByReplacingOccurrencesOfString:@"," withString:@"."];
    if (clear.doubleValue == 0) {
        self.iconImgView.tintColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    } else {
        self.iconImgView.tintColor = [HMChartTool colorWithHexString:color];
        self.dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
    }
}

- (void)loadName:(NSString *)name {
    self.nameLab.text = name;
}

- (void)hiddenName {
    self.nameLab.hidden = YES;
    self.imgTopConstraint.constant = 0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.nameLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
    }
}

#pragma mark - getter
- (UILabel *)nameLab {
    if (!_nameLab) {
        _nameLab = [UILabel new];
        _nameLab.font = [UIFont systemFontOfSize:10];
        _nameLab.textAlignment = NSTextAlignmentCenter;
        _nameLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        _nameLab.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _nameLab;
}

- (UIImageView *)iconImgView {
    if (!_iconImgView) {
        _iconImgView = [UIImageView new];
        _iconImgView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _iconImgView;
}

- (UILabel *)dataLab {
    if (!_dataLab) {
        _dataLab = [UILabel new];
        _dataLab.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _dataLab.textAlignment = NSTextAlignmentCenter;
        _dataLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        _dataLab.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _dataLab;
}

@end


