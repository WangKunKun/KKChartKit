//
//  HMAAChartFullScreenVC.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/7/2.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import "HMAAChartFullScreenVC.h"
#import "HMLGAAChartView.h"

@interface HMAAChartFullScreenVC ()
 
@property (nonatomic, strong) HMLGAAChartView *lgaaChartView;
@property (nonatomic, strong) UIButton *restoreButton;

@end

@implementation HMAAChartFullScreenVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    _lgaaChartView = [[HMLGAAChartView alloc] init];
    _lgaaChartView.backgroundColor = [UIColor clearColor];
    _lgaaChartView.nodImgName = self.nodImgName;
    _lgaaChartView.nodText = self.nodText;
    _lgaaChartView.nodColor = self.nodColor;
    _lgaaChartView.nodFont = self.nodFont;
    [self.view addSubview:_lgaaChartView];
    
    UIWindowScene *windowScene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIWindow *window = windowScene ? windowScene.windows.firstObject : nil;
    CGFloat width = window.bounds.size.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom;
    CGFloat height = window.bounds.size.width;
    _lgaaChartView.frame = CGRectMake(0, 0, width, height);
    _lgaaChartView.center = self.view.center;
    [_lgaaChartView reloadDataWithModel:self.chartModel];
    
    _lgaaChartView.transform = CGAffineTransformMakeRotation(M_PI_2);
    
    _restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_restoreButton setTitle:@"Restore" forState:UIControlStateNormal];
    [self.lgaaChartView addSubview:_restoreButton];
    _restoreButton.frame = CGRectMake(width - 80, 0, 80, 40);
    _restoreButton.layer.borderColor = [UIColor blueColor].CGColor;
    _restoreButton.layer.borderWidth = 1;
    [_restoreButton addTarget:self action:@selector(restoreAction) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - action
- (void)restoreAction {
    [self dismissViewControllerAnimated:NO completion:nil];
}

@end
