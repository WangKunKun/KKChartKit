//
//  HMAASeries.m
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/1/22.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import "HMAASeries.h"

@interface HMAASeries ()

@property (nonatomic, readwrite, strong) NSMutableArray<NSString *> *fgdata;//根据单位计算后的数据 用于tooltip展示

@end

@implementation HMAASeries

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.gname = @"";
        self.fractionDigits = 2;
        self.icon = @"ct_lg_solar";
    }
    return self;
}


- (NSMutableArray<NSString *> *)gnames {
    if (_gnames.count != self.element.firstObject.data.count) {
        NSMutableArray *gnames = [NSMutableArray array];
        for (int i = 0; i < _element.firstObject.data.count; i ++) {
            [gnames addObject:_gname];
        }
        _gnames = gnames;
    }
    return _gnames;
}

- (void)formatGroupData {
    NSMutableArray *gdatas = [NSMutableArray array];
    for (int i = 0; i < self.element.firstObject.data.count; i ++) {
        double group = 0.0;
        for (HMAASeriesElement *element in self.element) {
            if (i < element.data.count && [HMAASeriesUtil canTranslateToNum:element.data[i]]) {
                group += [element.data[i] floatValue];
            }
        }
        double originData = [HMAASeriesUtil doubleWithOriginData:group showFabs:self.showFabs fractionDigits:self.fractionDigits];
        NSString *gdata = [HMAASeriesUtil formatDouble:originData trunc:self.trunc fractionDigits:self.fractionDigits];
        if ([HMAASeriesUtil needCarryType:self.unitType]) {
            gdata = [HMAASeriesUtil formatCarryDouble:originData trunc:self.trunc fractionDigits:self.fractionDigits];
        } else {
            gdata = [NSString stringWithFormat:@"%@ ", gdata];
        }
        if (self.unitType == HMAAElementUnitType_MONEY) {//金额格式化货币符号
            gdata = [HMAASeriesUtil formatMoney:gdata withSymbol:self.currencySymbol];
        }
        NSString *unit = [HMAASeriesUtil getUnitWithType:self.unitType];
        if (self.unitType == HMAAElementUnitType_OTHER) {//拼接其它单位
            unit = self.otherUnit?:@"";
        }
        // 拼接单位
        [gdatas addObject:[gdata stringByAppendingString:unit]];
    }
    self.fgdata = gdatas;
}

#pragma mark - NSCopying
- (nonnull id)copyWithZone:(nullable NSZone *)zone { 
    HMAASeries *series = [[HMAASeries allocWithZone:zone] init];
    series.gname = self.gname;
    series.gnames = self.gnames;
    series.element = self.element;
    series.unitType = self.unitType;
    series.currencySymbol = self.currencySymbol;
    series.showFabs = self.showFabs;
    series.trunc = self.trunc;
    
    series.icon = self.icon;
    series.color = self.color;
    series.gcname = self.gcname;
    series.showElementName = self.showElementName;
    series.stackGroupInterval = self.stackGroupInterval;
    series.fractionDigits = self.fractionDigits;
    series.onlyNameIntooltip = self.onlyNameIntooltip;

    return series;
}

@end

@interface HMAASeriesElement ()

@property (nonatomic, readwrite, strong) NSMutableArray<NSString *> *fdata;//根据单位计算后的数据 用于tooltip展示

@end

@implementation HMAASeriesElement

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.name = @"";
        self.fractionDigits = 2;
        self.color = @"#000000";
        self.fillAlpha = 0.5;
//        self.icon = @"ct_lg_solar";
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    HMAASeriesElement *copy = [[[self class] allocWithZone:zone] init];
    
    copy.name = [self.name copy];
    copy.names = [self.names mutableCopy];
    copy.color = [self.color copy];
    copy.data = [self.data copy];
    copy.unitType = self.unitType;
    copy.currencySymbol = [self.currencySymbol copy];
    copy.showFabs = self.showFabs;
    copy.trunc = self.trunc;
    copy.chartType = [self.chartType copy];
    copy.stackGroup = [self.stackGroup copy];
    copy.fillColorAlphas = [self.fillColorAlphas copy];
    copy.autoGap = self.autoGap;
    copy.yAxis = [self.yAxis copy];
    copy.fdata = [self.fdata mutableCopy];
    copy.legendBgColor = [copy.legendBgColor copy];
    copy.legendBgColorAlpha = self.legendBgColorAlpha;
    copy.isHidden = self.isHidden;
    copy.fractionDigits = self.fractionDigits;
    copy.dashStyle = self.dashStyle;

    copy.icon = self.icon;

    return copy;
}

- (NSMutableArray<NSString *> *)names {
    if (_names.count != _data.count) {
        NSMutableArray *names = [NSMutableArray array];
        for (int i = 0; i < _data.count; i ++) {
            if ([_data[i] isEqual:[NSNull null]]) {
                [names addObject:[NSNull null]];
            } else {
                [names addObject:_name];
            }
        }
        _names = names;
    }
    return _names;
}

- (void)formatData {
//    NSLog(@"===原始数据===");
//    NSLog(@"===%@===", self.data);
    
    NSMutableArray *datas = [NSMutableArray array];
    NSArray *oriDatas = self.data;
    if (self.showPrev) {//取前一个数据
        NSMutableArray *muArr = [NSMutableArray array];
        [muArr addObject:self.data.firstObject];
        for (int i = 0; i < self.data.count - 1; i ++) {
            [muArr addObject:self.data[i]];
        }
        oriDatas = muArr.copy;
    }
    for (int i = 0; i < oriDatas.count; i ++) {
        if ([HMAASeriesUtil canTranslateToNum:oriDatas[i]]) {
            double originData = [HMAASeriesUtil doubleWithOriginData:[oriDatas[i] doubleValue] showFabs:self.showFabs fractionDigits:self.fractionDigits];
            NSString *data = [HMAASeriesUtil formatDouble:originData trunc:self.trunc fractionDigits:self.fractionDigits];
            if ([HMAASeriesUtil needCarryType:self.unitType]) {
                data = [HMAASeriesUtil formatCarryDouble:originData trunc:self.trunc fractionDigits:self.fractionDigits];
            } else {
                data = [NSString stringWithFormat:@"%@ ", data];
            }
            if (self.unitType == HMAAElementUnitType_MONEY) {//金额格式化货币符号
                data = [HMAASeriesUtil formatMoney:data withSymbol:self.currencySymbol];
            }
            NSString *unit = [HMAASeriesUtil getUnitWithType:self.unitType];
            if (self.unitType == HMAAElementUnitType_OTHER) {//拼接其它单位
                unit = self.otherUnit?:@"";
            }
            // 拼接单位
            [datas addObject:[data stringByAppendingString:unit]];
        } else {
            [datas addObject:oriDatas[i]];
        }
    }
    
//    NSLog(@"===最终数据===");
//    NSLog(@"===%@===", datas);
    
    self.fdata = datas;
}

@end

@implementation HMAASeriesUtil

// 处理源数据
+ (double)doubleWithOriginData:(double)oriData showFabs:(BOOL)showFabs fractionDigits:(NSInteger)fractionDigits {
    double data = showFabs ? fabs(oriData) : oriData;

    double frac = pow(10, fractionDigits + 2);
    // 手动截断或保留原值
//    if (trunc) {
//        // 先纠正精度：四舍五入到4位小数
//        data = round(data * 10000.0) / 10000.0;
//        
////        double scaled = data * 100.0;
////        data = truncf(scaled) / 100.0;  // 向零截断
//    } else {
//        
//        // 先纠正精度：四舍五入到3位小数
//        data = round(data * 1000.0) / 1000.0;
//    }
    
    return round(data * frac) / frac;
}

// 以千位为基准格式化
+ (NSString *)formatCarryDouble:(double)orivalue trunc:(BOOL)trunc fractionDigits:(NSInteger)fractionDigits {
    double oriData = orivalue;
    
    if (fabs(oriData) >= 1000) {
        if (fabs(oriData / 1000) >= 1000) {
            oriData = oriData / 1000;
            if (fabs(oriData / 1000) >= 1000) {
                oriData = oriData / 1000;
                NSInteger endDigits = fractionDigits == 100 ? 3 : fractionDigits;
                return [NSString stringWithFormat:@"%@ G", [self formatDouble:oriData / 1000 trunc:trunc fractionDigits:endDigits]];
            }
            NSInteger endDigits = fractionDigits == 100 ? 3 : fractionDigits;
            return [NSString stringWithFormat:@"%@ M", [self formatDouble:oriData / 1000 trunc:trunc fractionDigits:endDigits]];
        }
        NSInteger endDigits = fractionDigits == 100 ? 2 : fractionDigits;
        return [NSString stringWithFormat:@"%@ k", [self formatDouble:oriData / 1000 trunc:trunc fractionDigits:endDigits]];
    }
    NSInteger endDigits = fractionDigits == 100 ? 2 : fractionDigits;
    return [NSString stringWithFormat:@"%@ ", [self formatDouble:oriData trunc:trunc fractionDigits:endDigits]];
}

// 格式化小数 showFabs展示绝对值
+ (NSString *)formatDouble:(double)orivalue trunc:(BOOL)trunc fractionDigits:(NSInteger)fractionDigits {
    double value = orivalue;

//    // 手动截断或保留原值
//    if (trunc) {
//        // Step 1: 放大 100 倍，准备截断
//        double scaled = value * 100.0;
//        
//        // Step 2: 纠正极小的浮点误差（±0.001 范围内）
//        // 例如：619.999999 → 620.0，但 99.999 不会变成 100.0
//        double tolerance = 1e-9;
//        double nearby = nearbyint(scaled);
//        if (fabs(scaled - nearby) < tolerance) {
//            scaled = nearby;
//        }
//        
//        // Step 3: 截断（向零）
//        double truncatedScaled = truncf(scaled);
//        
//        // Step 4: 缩小回原单位
//        double truncated = truncatedScaled / 100.0;
//        
//        value = truncated;
//    }

    // formatter 仅用于格式化输出，不参与舍入
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = fractionDigits;
    formatter.minimumFractionDigits = 0;
    formatter.roundingMode = trunc ? NSNumberFormatterRoundDown : NSNumberFormatterRoundHalfUp;//截断或四舍五入

//    NSString *tempStr = [formatter stringFromNumber:@(value)];

//    if (fractionDigits == 2) {// 两位小数处理
//        if ([tempStr containsString:@".00"]) {
//            // 如果是 .00，返回整数形式
//            formatter.maximumFractionDigits = 0;
//        } else if ([tempStr hasSuffix:@"0"]) {
//            // 如果是 .x0，保留一位小数
//            formatter.maximumFractionDigits = 1;
//        } else {
//            // 默认返回两位小数
//            formatter.maximumFractionDigits = 2;
//        }
//    }
    
    NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithDecimal:@(value).decimalValue];
    NSString *normalized = [num stringValue]; // 统一成当前区域格式
    NSRange dotRange = [normalized rangeOfString:@"."];
    if (dotRange.location != NSNotFound) {
        NSString *decimalPart = [normalized substringFromIndex:dotRange.location + 1];
        
        // 统计末尾连续0的个数
        NSUInteger trailingZeros = 0;
        for (NSInteger i = decimalPart.length - 1; i >= 0; i--) {
            if ([decimalPart characterAtIndex:i] == '0') {
                trailingZeros++;
            } else {
                break;
            }
        }
        
        NSUInteger actualDigits = decimalPart.length - trailingZeros;
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = fractionDigits > actualDigits ? actualDigits : fractionDigits;
    } else {
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = 0;
    }

    return [formatter stringFromNumber:@(value)];
}

// 通过单位类型获取单位
+ (NSString *)getUnitWithType:(HMAAElementUnitType)unitType {
    if (unitType == HMAAElementUnitType_W) {
        return @"W";
    }
    if (unitType == HMAAElementUnitType_Wh) {
        return @"Wh";
    }
    if (unitType == HMAAElementUnitType_A) {
        return @"A";
    }
    if (unitType == HMAAElementUnitType_V) {
        return @"V";
    }
    if (unitType == HMAAElementUnitType_HZ) {
        return @"Hz";
    }
    if (unitType == HMAAElementUnitType_T) {
        return @"℃";
    }
    if (unitType == HMAAElementUnitType_TF) {
        return @"℉";
    }
    if (unitType == HMAAElementUnitType_PAH) {
        return @"%";
    }
    if (unitType == HMAAElementUnitType_H) {
        return @"h";
    }
    if (unitType == HMAAElementUnitType_VAR) {
        return @"Var";
    }
    if (unitType == HMAAElementUnitType_MIN) {
        return @"min";
    }
    if (unitType == HMAAElementUnitType_VA) {
        return @"VA";
    }
    if (unitType == HMAAElementUnitType_OM) {
        return @"Ω";
    }
    if (unitType == HMAAElementUnitType_BAR) {
        return @"Bar";
    }
    if (unitType == HMAAElementUnitType_RH) {
        return @"RH";
    }
    return @"";
}

// 将数组转化为json字符串
+ (NSString *)jsonSerializsWithArray:(NSArray *)array {
    NSString *jsonString = @"";
    if (array.count > 0) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:array
                                                           options:0 // 你可以添加 NSJSONWritingOptions 的值来格式化输出
                                                             error:&error];
        if (!jsonData) {
            // 如果转换失败，处理错误
            NSLog(@"Error converting dictionary to JSON: %@", error);
        } else {
            // 将 NSData 转换为 NSString
            jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    return jsonString;
}

// 判断对象是否可以转数值
+ (BOOL)canTranslateToNum:(NSObject *)obj {
    return [obj isKindOfClass:[NSNumber class]] || [obj isKindOfClass:[NSString class]];
}

// 对象是否以千位进制
+ (BOOL)needCarryType:(HMAAElementUnitType)unitType {
    if (unitType == HMAAElementUnitType_W || unitType == HMAAElementUnitType_Wh || unitType == HMAAElementUnitType_VAR || unitType == HMAAElementUnitType_VA || unitType == HMAAElementUnitType_OM || unitType == HMAAElementUnitType_BAR || unitType == HMAAElementUnitType_MONEY || unitType == HMAAElementUnitType_CARRY) {
        return YES;
    }
    return NO;
}

//// 格式化二维数组中的Null用于tooltip弹窗显示
//+ (NSArray<NSArray *> *)formatNullElements:(NSArray<NSArray *> *)elements {
//    if (elements.count == 0) {
//        return @[];
//    }
//
//    // 找出最大列数（不要假设所有行长度一致）
//    NSInteger maxColumn = 0;
//    for (NSArray *row in elements) {
//        maxColumn = MAX(maxColumn, row.count);
//    }
//
//    // 每一列存放所有非Null元素
//    NSMutableArray<NSMutableArray *> *columns = [NSMutableArray arrayWithCapacity:maxColumn];
//
//    for (NSInteger col = 0; col < maxColumn; col++) {
//        [columns addObject:[NSMutableArray array]];
//    }
//
//    // 收集每一列的数据
//    for (NSArray *row in elements) {
//        for (NSInteger col = 0; col < row.count; col++) {
//            id obj = row[col];
//            if (![obj isKindOfClass:[NSNull class]]) {
//                [columns[col] addObject:obj];
//            }
//        }
//    }
//
//    // 构建结果
//    NSMutableArray *result = [NSMutableArray arrayWithCapacity:elements.count];
//    for (NSInteger row = 0; row < elements.count; row++) {
//        NSMutableArray *newRow = [NSMutableArray arrayWithCapacity:maxColumn];
//        for (NSInteger col = 0; col < maxColumn; col++) {
//            NSArray *column = columns[col];
//            if (row < column.count) {
//                [newRow addObject:column[row]];
//            } else {
//                [newRow addObject:[NSNull null]];
//            }
//        }
//        [result addObject:newRow];
//    }
//    return result.copy;
//}

+ (NSArray<NSArray *> *)formatNullElements:(NSArray<NSArray *> *)elements
{
    if (elements.count == 0) {
        return @[];
    }

    NSInteger rowCount = elements.count;

    // 最大列数（兼容每行长度不同）
    NSInteger maxColumn = 0;
    for (NSArray *row in elements) {
        maxColumn = MAX(maxColumn, row.count);
    }

    // 每一列当前扫描到哪一行
    NSMutableArray<NSNumber *> *cursors = [NSMutableArray arrayWithCapacity:maxColumn];
    for (NSInteger col = 0; col < maxColumn; col++) {
        [cursors addObject:@0];
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:rowCount];

    for (NSInteger k = 0; k < rowCount; k++) {

        NSMutableArray *newRow = [NSMutableArray arrayWithCapacity:maxColumn];

        for (NSInteger col = 0; col < maxColumn; col++) {

            NSInteger cursor = MAX(k, cursors[col].integerValue);

            id value = [NSNull null];

            while (cursor < rowCount) {

                NSArray *row = elements[cursor];

                if (col < row.count) {

                    id obj = row[col];

                    if (![obj isKindOfClass:[NSNull class]]) {
                        value = obj;

                        // 下次从下一行继续找
                        cursors[col] = @(cursor + 1);

                        break;
                    }
                }

                cursor++;
            }

            // 如果没找到，cursor也推进到当前位置，避免以后重复扫描
            if ([value isKindOfClass:[NSNull class]]) {
                cursors[col] = @(MAX(cursors[col].integerValue, cursor));
            }

            [newRow addObject:value];
        }

        [result addObject:newRow];
    }

    return result;
}

// 格式化十六进制颜色添加透明度值
+ (NSString *)rgbaStringFromHex:(NSString *)hexColor withAlpha:(CGFloat)alpha {
    // 移除 # 号
    NSString *cleanHex = [hexColor stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (cleanHex.length != 6) {
        NSLog(@"Invalid hex color: %@", hexColor);
        return nil;
    }
    
    // 解析 RGB
    NSScanner *scanner = [NSScanner scannerWithString:cleanHex];
    unsigned int rgbValue;
    [scanner scanHexInt:&rgbValue];
    
    // 分离 R, G, B
    NSUInteger r = (rgbValue >> 16) & 0xFF;
    NSUInteger g = (rgbValue >> 8) & 0xFF;
    NSUInteger b = rgbValue & 0xFF;
    
    return [NSString stringWithFormat:@"rgba(%lu, %lu, %lu, %.2f)",
            (unsigned long)r, (unsigned long)g, (unsigned long)b, alpha];
}

// 图表计算数据数组最大最小值 {min max}
+ (NSDictionary *)calculateMaxMinValueWithNumberArray:(NSArray *)numberArray {
    NSMutableArray *maxNumberArray = [NSMutableArray array];
    NSMutableArray *minNumberArray = [NSMutableArray array];
    for (NSArray *arr in numberArray) {
        if (arr.count == 0) {
            break;
        }
        // 过滤掉 NSNull 对象
        NSArray *filteredArray = [arr filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", [NSNull null]]];
        if (filteredArray.count > 0) {
            [maxNumberArray addObject:[filteredArray valueForKeyPath:@"@max.self"]];
            [minNumberArray addObject:[filteredArray valueForKeyPath:@"@min.self"]];
        } else {//全为空的话补0
            [maxNumberArray addObject:@0];
            [minNumberArray addObject:@0];
        }
    }
    NSNumber *maxNum = [maxNumberArray valueForKeyPath:@"@max.self"];
    NSNumber *minNum = [minNumberArray valueForKeyPath:@"@min.self"];

    NSNumber *yMax = maxNum;
    NSNumber *yMin = minNum;
    if (maxNum.floatValue > 0 && minNum.floatValue < 0) {
        if (maxNum.floatValue + minNum.floatValue > 0) {
            yMax = @(maxNum.floatValue * 1.1);
            yMin = @(-maxNum.floatValue * 1.1);
        } else {
            yMin = @(minNum.floatValue * 1.1);
            yMax = @(-minNum.floatValue * 1.1);
        }
    } else {
        if (maxNum.floatValue <= 0) {
            yMax = @(-minNum.floatValue * 1.1);
            yMin = @(minNum.floatValue * 1.1);
        }
        if (minNum.floatValue >= 0) {
            yMin = @(-maxNum.floatValue * 1.1);
            yMax = @(maxNum.floatValue * 1.1);
        }
    }
    
    return @{@"max": yMax, @"min": yMin};
}

// 金额格式化货币符号
+ (NSString *)formatMoney:(NSString *)money withSymbol:(NSString *)symbol {
    NSString *money_r = money;
    NSString *symbol_r = symbol;
    if (symbol_r.length > 0) {//有单位
        NSArray *arr = [money_r componentsSeparatedByString:@"-"];
        if (arr.count > 1) {//有负号
            symbol_r = [NSString stringWithFormat:@"-%@", symbol_r];
        }
        money_r = [NSString stringWithFormat:@"%@%@", symbol_r, arr.lastObject];
    }
    return money_r;
}

// 拆分数据序列返回正数据序列
+ (HMAASeriesElement *)positiveSplitFromSeriesElement:(HMAASeriesElement *)element {
    HMAASeriesElement *resultElement = element.copy;
    NSMutableArray *muArr = [NSMutableArray array];
    for (NSNumber *num in element.data) {
        if (num.doubleValue >= 0 || [num isKindOfClass:[NSNull class]]) {
            [muArr addObject:num];
        } else {
            [muArr addObject:@0];
        }
    }
    resultElement.data = muArr.copy;
    return resultElement;
}

// 拆分数据序列返回负数据序列
+ (HMAASeriesElement *)negativeSplitFromSeriesElement:(HMAASeriesElement *)element {
    HMAASeriesElement *resultElement = element.copy;
    NSMutableArray *muArr = [NSMutableArray array];
    for (NSNumber *num in element.data) {
        if (num.doubleValue <= 0 || [num isKindOfClass:[NSNull class]]) {
            [muArr addObject:num];
        } else {
            [muArr addObject:@0];
        }
    }
    resultElement.data = muArr.copy;
    return resultElement;
}

@end
