//
//  HMChartTitleView.m
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/7.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import "HMChartTitleView.h"
#import "HMChartTool.h"

@interface HMChartTitleView ()

@property (nonatomic, strong) UILabel *titleLab;
@property (nonatomic, strong) UILabel *unitLab;
@property (nonatomic, strong) UIView *line;

@end

@implementation HMChartTitleView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.titleLab];
        [self addSubview:self.unitLab];
        [self addSubview:self.line];
        
        self.titleLab.translatesAutoresizingMaskIntoConstraints = NO;
        self.unitLab.translatesAutoresizingMaskIntoConstraints = NO;
        self.line.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLab.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [self.titleLab.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.unitLab.leadingAnchor constraintEqualToAnchor:self.titleLab.trailingAnchor constant:4],
            [self.unitLab.bottomAnchor constraintEqualToAnchor:self.titleLab.bottomAnchor],
            [self.line.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [self.line.leftAnchor constraintEqualToAnchor:self.leftAnchor],
            [self.line.rightAnchor constraintEqualToAnchor:self.rightAnchor],
            [self.line.heightAnchor constraintEqualToConstant:1]
        ]];
    }
    return self;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.titleLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        self.unitLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
        self.line.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
    }
}

#pragma mark - method
- (void)showLine:(BOOL)show {
    _line.hidden = !show;
}

#pragma mark - setter
- (void)setName:(NSString *)name {
    _titleLab.text = name;
}

- (void)setUnit:(NSString *)unit {
    _unitLab.text = unit;
}

#pragma mark - getter
- (UILabel *)titleLab {
    if (!_titleLab) {
        _titleLab = [UILabel new];
        _titleLab.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
    }
    return _titleLab;
}

- (UILabel *)unitLab {
    if (!_unitLab) {
        _unitLab = [UILabel new];
        _unitLab.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _unitLab.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeThirdText traitCollection:self.traitCollection]];
    }
    return _unitLab;
}

- (UIView *)line {
    if (!_line) {
        _line = [UIView new];
        _line.backgroundColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeDivider traitCollection:self.traitCollection]];
        _line.hidden = YES;
    }
    return _line;
}

@end
