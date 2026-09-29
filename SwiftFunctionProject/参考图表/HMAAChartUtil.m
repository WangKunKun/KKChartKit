//
//  HMAAChartUtil.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/5/9.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import "HMAAChartUtil.h"

@implementation HMAAChartUtil

+ (HMLGAAChartView *)createlgaaChartView {
    HMLGAAChartView *lgaaChartView = [[HMLGAAChartView alloc] init];
    lgaaChartView.backgroundColor = [UIColor clearColor];
    lgaaChartView.nodImgName = @"img_chart_nodata";
    lgaaChartView.nodText = Language(@"k_5_1093");
    lgaaChartView.nodColor = colorNamed(@"次要文字");
    lgaaChartView.nodFont = Font_Size_weight(14, UIFontWeightMedium);
//    lgaaChartView.showEnlargeButton = YES;
    return lgaaChartView;
}

+ (HMLGAAChartView *)createlgaaChartViewWithFrame:(CGRect)frame {
    HMLGAAChartView *lgaaChartView = [[HMLGAAChartView alloc] initWithFrame:frame];
    lgaaChartView.backgroundColor = [UIColor clearColor];
    lgaaChartView.nodImgName = @"img_chart_nodata";
    lgaaChartView.nodText = Language(@"k_5_1093");
    lgaaChartView.nodColor = colorNamed(@"次要文字");
    lgaaChartView.nodFont = Font_Size_weight(14, UIFontWeightMedium);
    return lgaaChartView;
}

+ (HMAAChartView *)createaaChartView {
    HMAAChartView *aaChartView = [[HMAAChartView alloc] init];
    aaChartView.backgroundColor = [UIColor clearColor];
    aaChartView.nodImgName = @"img_chart_nodata";
    aaChartView.nodText = Language(@"k_5_1093");
    aaChartView.nodColor = colorNamed(@"次要文字");
    aaChartView.nodFont = Font_Size_weight(14, UIFontWeightMedium);
    return aaChartView;
}

+ (HMAAChartView *)createaaChartViewWithFrame:(CGRect)frame {
    HMAAChartView *aaChartView = [[HMAAChartView alloc] initWithFrame:frame];
    aaChartView.backgroundColor = [UIColor clearColor];
    aaChartView.nodImgName = @"img_chart_nodata";
    aaChartView.nodText = Language(@"k_5_1093");
    aaChartView.nodColor = colorNamed(@"次要文字");
    aaChartView.nodFont = Font_Size_weight(14, UIFontWeightMedium);
    return aaChartView;
}

// 判断key是否需要区分正负并返回数据名称 @[positive, negative];
+ (NSArray *)namesWithKey:(NSString *)key {
    NSDictionary *names = @{@"grid_p_power":@[Language(@"k_5_1433"), Language(@"k_5_1432")],
                            @"grid_p_power_a":@[Language(@"k_5_209303"), Language(@"k_5_209304")],
                            @"grid_p_power_b":@[Language(@"k_5_209305"), Language(@"k_5_209306")],
                            @"grid_p_power_c":@[Language(@"k_5_209307"), Language(@"k_5_209308")],
                            @"bms_power":@[Language(@"k_5_5417"), Language(@"k_5_5416")]};
    return names[key]?:@[];
}

// 根据正负数据区分数据名称
+ (NSMutableArray *)formatNamesWithData:(NSArray *)data positive:(NSString *)positive negative:(NSString *)negative {
    NSMutableArray *muArr = [NSMutableArray array];
    for (int i = 0; i < data.count; i ++) {
        if ([data[i] isEqual:[NSNull null]]) {
            [muArr addObject:[NSNull null]];
        } else {
            float num = [data[i] floatValue];
            [muArr addObject:num < 0 ? negative:positive];
        }
    }
    return muArr;
}

// 需要取相反数的key
+ (NSArray *)keyNeedOpposite {
    return @[@"fpp", @"fbp", @"fgp", @"fpe", @"fbe", @"fge", @"consumption_power", @"grid_p_power", @"gfp", @"gfb", @"bfp", @"bfg", @"fpp", @"grid_p_power_a", @"grid_p_power_b", @"grid_p_power_c", @"lcm_grid_p_power", @"lcm_grid_p_eq", @"lcm_consumption_eq", @"gp", @"bp", @"cpt"];
}

// 需要取绝对值后相反数的key
+ (NSArray *)keyNeedFabsAndOpposite {
    return @[@"fgp", @"consumption_power", @"lcm_consumption_power"];
}

+ (NSArray *)fixAIChatData:(NSArray *)data type:(NSString *)type {
    NSArray * list = [self keyNeedOpposite];
    NSArray * fabsOpp = [self keyNeedFabsAndOpposite];
    if ([list containsObject:type]) {
        NSMutableArray * array = [NSMutableArray array];
        for (NSString * value in data) {
            [array addObject:@(-[value doubleValue])];
        }
        return array;
    } else if ([fabsOpp containsObject:type]) {
        NSMutableArray * array = [NSMutableArray array];
        for (NSString * value in data) {
            [array addObject:@(- fabs([value doubleValue]))];
        }
        return array;
    }
    return data;
}

@end
