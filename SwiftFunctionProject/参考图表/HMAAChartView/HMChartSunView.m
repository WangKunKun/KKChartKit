//
//  HMChartSunView.m
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/7.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import "HMChartSunView.h"
#import "HMChartTool.h"
#import "HMAAChartModel.h"

@interface HMChartSunView ()

@property (nonatomic, strong) UIView *circleView;

@end

@implementation HMChartSunView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.circleView];
        
        self.circleView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.circleView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [self.circleView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [self.circleView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.circleView.heightAnchor constraintEqualToConstant:30]
        ]];
    }
    return self;
}

- (void)reloadData {
    [self.circleView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    HMChartSunRow *leftRow = [HMChartSunRow new];
    leftRow.model = self.sunDatas.firstObject;
    [leftRow reloadData];
    [self.circleView addSubview:leftRow];
    leftRow.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [leftRow.leadingAnchor constraintEqualToAnchor:self.circleView.leadingAnchor constant:6],
        [leftRow.centerYAnchor constraintEqualToAnchor:self.circleView.centerYAnchor],
    ]];
    
    HMChartSunRow *rightRow = [HMChartSunRow new];
    rightRow.model = self.sunDatas.lastObject;
    [rightRow reloadData];
    [self.circleView addSubview:rightRow];
    rightRow.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [rightRow.trailingAnchor constraintEqualToAnchor:self.circleView.trailingAnchor constant:-6],
        [rightRow.centerYAnchor constraintEqualToAnchor:self.circleView.centerYAnchor],
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.circleView.layer.borderColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]].CGColor;
    }
}

#pragma mark - getter
- (UIView *)circleView {
    if (!_circleView) {
        _circleView = [UIView new];
        _circleView.layer.cornerRadius = 15;
        _circleView.layer.borderWidth = 1;
        _circleView.layer.borderColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]].CGColor;
    }
    return _circleView;
}

@end

@interface HMChartSunRow ()

@property (nonatomic, strong) UIImageView *iconImgView;
@property (nonatomic, strong) UILabel *contentLabel;

@end

@implementation HMChartSunRow

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.iconImgView];
        [self addSubview:self.contentLabel];
        
        self.iconImgView.translatesAutoresizingMaskIntoConstraints = NO;
        self.contentLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [NSLayoutConstraint activateConstraints:@[
            [self.iconImgView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.iconImgView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.iconImgView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [self.iconImgView.widthAnchor constraintEqualToConstant:18],
            [self.iconImgView.heightAnchor constraintEqualToConstant:18],
            [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.iconImgView.trailingAnchor constant:4],
            [self.contentLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
    }
    return self;
}

- (void)reloadData {
    self.iconImgView.image = [UIImage imageNamed:self.model.icon];
    self.contentLabel.text = [NSString stringWithFormat:@"%@ %@", self.model.title?:@"", self.model.time?:@"--:--"];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.iconImgView.tintColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.contentLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    }
}

#pragma mark - getter
- (UIImageView *)iconImgView {
    if (!_iconImgView) {
        _iconImgView = [UIImageView new];
        _iconImgView.tintColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    }
    return _iconImgView;
}

- (UILabel *)contentLabel {
    if (!_contentLabel) {
        _contentLabel = [UILabel new];
        _contentLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _contentLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    }
    return _contentLabel;
}

@end

