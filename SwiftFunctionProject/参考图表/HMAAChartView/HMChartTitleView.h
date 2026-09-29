//
//  HMChartTitleView.h
//  Aurora
//
//  Created by HoymilesMac2024xjc on 2026/5/7.
//  Copyright © 2026 Aurora. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HMChartTitleView : UIView

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *unit;

- (void)showLine:(BOOL)show;

@end

NS_ASSUME_NONNULL_END
