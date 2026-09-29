//
//  HMTooltip.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/11/18.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import "HMTooltip.h"
#import "HMAASeries.h"
#import "HMChartTool.h"

@interface HMTooltip ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSArray *viewsArr;

@property (nonatomic, assign) CGFloat commonFont;
@property (nonatomic, assign) CGFloat commonLineHeight;
@property (nonatomic, assign) CGFloat commonInterval;

@property (nonatomic, assign) BOOL hiddenDot;//只有一条数据使用

@end

@implementation HMTooltip

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minWidth = 156;
        _maxWidth = [[UIScreen mainScreen] bounds].size.width - 24;
        
        _commonFont = 10.f;
        _commonLineHeight = 15.f;
        _commonInterval = 4.f;
        
        self.layer.cornerRadius = 8.f;
    }
    return self;
}

#pragma mark - method
// 绘制当前数据需要的tooltip类型
- (void)drawDataSubviews {
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    _commonFont = 12.f;
    if (self.seriesArray.count > 1) {//多组数据
        _commonFont = 10.f;
    }

    self.titleLabel.textColor = self.textColor;
    self.titleLabel.font = [UIFont systemFontOfSize:_commonFont + 2];
    [self addSubview:self.titleLabel];
    NSMutableArray *viewsArr = [NSMutableArray array];
    for (HMAASeries *series in self.seriesArray) {
        [series formatGroupData];
        NSMutableDictionary *viewsDic = [NSMutableDictionary dictionary];
        if (series.gnames.firstObject.length > 0) {//有组名
            UILabel *lab = [UILabel new];
            lab.font = [UIFont systemFontOfSize:_commonFont + 2];
            lab.textColor = self.textColor;
            [viewsDic setObject:lab forKey:@"group"];
            [self addSubview:lab];
        }
        NSMutableArray *labsArr = [NSMutableArray array];
        for (HMAASeriesElement *element in series.element) {
            [element formatData];
            HMDotLabel *lab = [[HMDotLabel alloc] init];
            lab.dotColor = [HMChartTool colorWithHexString:element.color];
            lab.font = [UIFont systemFontOfSize:_commonFont];
            lab.textColor = self.textColor;
            [labsArr addObject:lab];
            [self addSubview:lab];
        }
        [viewsDic setObject:labsArr forKey:@"element"];
        UIView *line = [UIView new];
        line.backgroundColor = self.textColor;
        line.hidden = YES;
        [viewsDic setObject:line forKey:@"line"];
        [self addSubview:line];
        
        [viewsArr addObject:viewsDic];
    }
    self.viewsArr = viewsArr.copy;
}

- (void)loadTooltipDataIndex:(NSInteger)index {
    CGFloat topMar = 8;
    CGFloat minWidth = _minWidth;
    
    _hiddenDot = NO;
    if (self.seriesArray.count == 1) {
        HMAASeries *series = self.seriesArray.lastObject;
        if (series.element.count == 1) {
            _hiddenDot = YES;
        }
    }
    
    _commonInterval = 7.f;
    _commonLineHeight = 18.f;
    if (self.seriesArray.count > 1) {//多组数据
        _commonInterval = 4.f;
        _commonLineHeight = 15.f;
    }
    
    self.titleLabel.text = self.xSeriesArray[index];
    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeZero];
    self.titleLabel.frame = CGRectMake(8, topMar, titleSize.width, MAX(titleSize.height, _commonLineHeight+3));
    
    topMar += self.titleLabel.frame.size.height;
    minWidth = MAX(minWidth, self.titleLabel.frame.size.width);
    
    for (int i = 0; i < self.viewsArr.count; i ++) {
        HMAASeries *series = self.seriesArray[i];
        NSDictionary *viewsDic = self.viewsArr[i];
        if ([viewsDic objectForKey:@"group"]) {
            topMar += _commonInterval + 2;

            UILabel *lab = viewsDic[@"group"];
            lab.text = [NSString stringWithFormat:@"%@:%@", series.gnames[index], series.fgdata[index]];
            CGSize labSize = [lab sizeThatFits:CGSizeZero];
            lab.frame = CGRectMake(8, topMar, labSize.width, MAX(labSize.height, _commonLineHeight));
            
            topMar += lab.frame.size.height;
            minWidth = MAX(minWidth, lab.frame.size.width);
        }
        NSArray *labsArr = viewsDic[@"element"]? : @[];
        for (int i = 0; i < labsArr.count; i ++) {
            HMAASeriesElement *element = series.element[i];
            if ([element.data[index] isKindOfClass:[NSNull class]]) {
                continue;
            }
            
            topMar += _commonInterval;
            HMDotLabel *lab = labsArr[i];
            lab.hiddenDot = _hiddenDot;
            lab.minHeight = _commonLineHeight;
            lab.text = [NSString stringWithFormat:@"%@:%@", element.names[index], element.fdata[index]];
            CGRect rect = [lab calculateFrame];
            lab.frame = CGRectMake(8, topMar, rect.size.width, rect.size.height);
            
            topMar += lab.frame.size.height;
            minWidth = MAX(minWidth, lab.frame.size.width);
        }
        if (i != self.viewsArr.count - 1) {//需要划线
            topMar += _commonInterval + 4;
            UIView *line = viewsDic[@"line"];
            line.frame = CGRectMake(8, topMar, minWidth, 1);
            line.hidden = NO;
            
            topMar += 1;
        } else {
            topMar += 8;
        }
    }
    // 根据绘制完的text调整文本框和横线宽高
    for (NSDictionary *viewsDic in self.viewsArr) {
        UIView *line = viewsDic[@"line"];
        CGRect rect = line.frame;
        rect.size.width = minWidth;
        line.frame = rect;
    }
    
    self.frame = CGRectMake(0, 0, minWidth + 16, topMar);
}

#pragma mark - getter
- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.numberOfLines = 0;
    }
    return _titleLabel;
}

- (NSArray *)viewsArr {
    if (!_viewsArr) {
        _viewsArr = [NSArray array];
    }
    return _viewsArr;
}

@end

@interface HMDotLabel ()

@property (nonatomic, strong) UIView *dotView;
@property (nonatomic, strong) UILabel *label;

@end

@implementation HMDotLabel
    
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addSubview:self.dotView];
        [self addSubview:self.label];
        
        _minHeight = 15;

        self.hiddenDot = YES;
        self.dotView.frame = CGRectMake(0, 3, (_minHeight-6), (_minHeight-6));
        self.label.frame = CGRectMake((_minHeight-6)+8, 0, 0, _minHeight);
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.dotView.frame = CGRectMake(0, 3, (_minHeight-6), (_minHeight-6));
    
    CGFloat leftMargin = 0.f;
    if (!self.hiddenDot) {
        leftMargin = (_minHeight - 6) + 8;
    }

    CGSize needSize = _maxWidth > 0 ? CGSizeMake(_maxWidth, MAXFLOAT) : CGSizeZero;
    CGSize labSize = [_label sizeThatFits:needSize];
    self.label.frame = CGRectMake(leftMargin, 0, labSize.width, MAX(labSize.height, _minHeight));
}

#pragma mark - method
- (CGRect)calculateFrame {
    CGFloat leftMargin = 0.f;
    if (!self.hiddenDot) {
        leftMargin = (_minHeight - 6) + 8;
    }
    
    CGSize needSize = _maxWidth > 0 ? CGSizeMake(_maxWidth, MAXFLOAT) : CGSizeZero;
    CGSize labSize = [_label sizeThatFits:needSize];
    self.label.frame = CGRectMake(leftMargin, 0, labSize.width, MAX(labSize.height, _minHeight));
    
    CGRect rect = self.frame;
    rect.size.width = leftMargin + labSize.width;
    rect.size.height = MAX(labSize.height, _minHeight);
    return rect;
}

- (void)setDotColor:(UIColor *)dotColor {
    _dotView.backgroundColor = dotColor;
}

- (void)setText:(NSString *)text {
    _label.text = text;
}

- (void)setFont:(UIFont *)font {
    _label.font = font;
}

- (void)setTextColor:(UIColor *)textColor {
    _label.textColor = textColor;
}

- (void)setHiddenDot:(BOOL)hiddenDot {
    _hiddenDot = hiddenDot;
    self.dotView.hidden = hiddenDot;
}

#pragma mark - getter
- (UIView *)dotView {
    if (!_dotView) {
        _dotView = [UIView new];
        _dotView.layer.cornerRadius = 6;
        _dotView.layer.masksToBounds = YES;
    }
    return _dotView;
}

- (UILabel *)label {
    if (!_label) {
        _label = [UILabel new];
        _label.numberOfLines = 0;
    }
    return _label;
}

@end
