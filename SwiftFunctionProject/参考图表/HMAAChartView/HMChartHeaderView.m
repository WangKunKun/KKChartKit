//
//  HMChartHeaderView.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2026/2/3.
//  Copyright © 2026 hemaiInstall. All rights reserved.
//

#import "HMChartHeaderView.h"
#import "HMAAChartModel.h"
#import "HMChartTool.h"

@interface HMChartHeaderView ()

@property (nonatomic, assign) BOOL allHide;
@property (nonatomic, strong) UIStackView *stackView;

@end

@implementation HMChartHeaderView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.stackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)reloadData {
    [self.stackView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    for (int i = 0; i < self.headerDatas.count; i ++) {
        HMChartHeaderRow *row = [[HMChartHeaderRow alloc] init];
        [self.stackView addArrangedSubview:row];
        row.model = self.headerDatas[i];
        [row reloadData];
    }
}

- (void)hiddenContent:(BOOL)hide {
    if (self.allHide == hide) {
        return;
    }
    self.allHide = hide;
    
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.hidden = hide;
    }];
}

#pragma mark - getter
- (UIStackView *)stackView {
    if (!_stackView) {
        _stackView = [[UIStackView alloc] init];
        _stackView.distribution = UIStackViewDistributionFillEqually;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _stackView;
}

@end

@interface HMChartHeaderRow ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *contentLabel;

@end

@implementation HMChartHeaderRow

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.titleLabel];
        [self addSubview:self.contentLabel];
    }
    return self;
}

- (void)reloadData {
    self.titleLabel.text = self.model.title;
    self.titleLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeSecondText traitCollection:self.traitCollection]];
    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeZero];
    
    if (self.model.data.length == 0) {
        self.contentLabel.hidden = YES;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:self.model.topMargin],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:self.model.leftMargin],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-self.model.rightMargin],
            [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    } else {
        self.contentLabel.hidden = NO;
        
        self.contentLabel.text = [NSString stringWithFormat:@"%@ %@", self.model.data, self.model.unit];
        self.contentLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeSecondText traitCollection:self.traitCollection]];
        UIColor *dataColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        [HMChartTool messageAction:self.contentLabel changeString:self.model.data andMarkColor:dataColor andMarkFondSize:14 fontMode:UIFontWeightBold];
        CGSize contentSize = [self.contentLabel sizeThatFits:CGSizeZero];
        
//        CGFloat width = MAX(titleSize.width, contentSize.width);
        
        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:self.model.topMargin],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:self.model.leftMargin],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-self.model.rightMargin],
            [self.titleLabel.heightAnchor constraintEqualToConstant:titleSize.height],
            [self.contentLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:self.model.topMargin + titleSize.height + 4],
            [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:self.model.leftMargin],
            [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-self.model.rightMargin],
            [self.contentLabel.heightAnchor constraintEqualToConstant:contentSize.height],
        ]];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.titleLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeSecondText traitCollection:self.traitCollection]];
        self.contentLabel.textColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypeSecondText traitCollection:self.traitCollection]];
        UIColor *dataColor = [HMChartTool colorWithHexString:[HMChartTool colorHexWithChartColorType:HMChartColorTypePrimaryText traitCollection:self.traitCollection]];
        if (self.contentLabel.text) {
            [HMChartTool messageAction:self.contentLabel changeString:self.model.data andMarkColor:dataColor andMarkFondSize:14 fontMode:UIFontWeightBold];
        }
    }
}

#pragma mark - getter
- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
//        _titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLabel;
}

- (UILabel *)contentLabel {
    if (!_contentLabel) {
        _contentLabel = [UILabel new];
        _contentLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
//        _contentLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _contentLabel;
}

@end

