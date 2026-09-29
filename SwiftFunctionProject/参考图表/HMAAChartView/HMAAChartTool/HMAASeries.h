//
//  HMAASeries.h
//  hemaiInstall
//
//  Created by HoymilesMac2024xjc on 2025/1/22.
//  Copyright © 2025 hemaiInstall. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    HMAAElementUnitType_NONE, //无
    HMAAElementUnitType_W, //功率 W
    HMAAElementUnitType_Wh, //发电量 Wh
    HMAAElementUnitType_A, //电流 A
    HMAAElementUnitType_V, //电压 V
    HMAAElementUnitType_HZ, //频率 Hz
    HMAAElementUnitType_T, //℃
    HMAAElementUnitType_TF, //℉
    HMAAElementUnitType_PAH, //%
    HMAAElementUnitType_MONEY, //金额
    HMAAElementUnitType_H, //小时
    HMAAElementUnitType_VAR, //无功功率
    HMAAElementUnitType_MIN, //分钟
    HMAAElementUnitType_VA, //视载功率
    HMAAElementUnitType_OM, //Ω
    HMAAElementUnitType_BAR, //bar压强
    HMAAElementUnitType_RH, //湿度
    HMAAElementUnitType_OTHER, //其它
    HMAAElementUnitType_CARRY, //带进位
} HMAAElementUnitType;



NS_ASSUME_NONNULL_BEGIN

@class HMAASeriesElement;
@interface HMAASeries : NSObject <NSCopying>

@property (nonatomic, copy) NSString *gname;//组标题
@property (nonatomic, strong) NSMutableArray<NSString *> *gnames;//名称组 和数据组长度对应 优先使用 用于弹窗显示
@property (nonatomic, copy) NSArray<HMAASeriesElement *> *element;//数据源组
@property (nonatomic, assign) HMAAElementUnitType unitType;//数据单位类型
@property (nonatomic, copy) NSString *otherUnit;//数据单位 other使用
@property (nonatomic, copy) NSString *currencySymbol;//货币符号 money使用
@property (nonatomic, assign) BOOL showFabs;//计算后的数据显示绝对值
@property (nonatomic, assign) BOOL trunc;//计算后的数据直接截断
//保留小数（默认保留两位小数）
//兼容措施 当fractionDigits=100时 会在M以上保留3位小数 普通情况保留两位小数
@property (nonatomic, assign) NSInteger fractionDigits;

//------计算后的数据------
@property (nonatomic, readonly, strong) NSMutableArray<NSString *> *fgdata;//根据单位计算后的数据 用于tooltip展示

- (void)formatGroupData;//格式化单位数据

@property (nonatomic, assign) BOOL onlyNameIntooltip; //tooltip上只显示名称

//------图例配置属性ver2使用-----
@property (nonatomic, copy) NSString *icon;//组图片名称
@property (nonatomic, copy) NSString *color;//组颜色
@property (nonatomic, copy) NSString *gcname;//组分标题
@property (nonatomic, assign) BOOL showElementName;//是否展示内部数据名称 默认隐藏
@property (nonatomic, copy) NSNumber *stackGroupInterval;//默认为空 存在stackGroup分隔时使用

@end

@interface HMAASeriesElement : NSObject <NSCopying>

@property (nonatomic, copy) NSString *name;//名称
@property (nonatomic, strong) NSMutableArray<NSString *> *names;//名称组 和数据组长度对应 优先使用 用于弹窗显示
@property (nonatomic, copy) NSString *color;//图例颜色
@property (nonatomic, copy) NSArray *data;//数据 图表坐标展示
@property (nonatomic, assign) HMAAElementUnitType unitType;//数据单位类型
@property (nonatomic, copy) NSString *otherUnit;//数据单位 other使用
@property (nonatomic, copy) NSString *currencySymbol;//货币符号 money使用
@property (nonatomic, assign) BOOL showFabs;//计算后的数据显示绝对值
@property (nonatomic, assign) BOOL trunc;//计算后的数据直接截断
//保留小数（默认保留两位小数）
//兼容措施 当fractionDigits=100时 会在M以上保留3位小数 普通情况保留两位小数
@property (nonatomic, assign) NSInteger fractionDigits;
// 混合图表单独设置类型/默认跟随model中chartType
// 支持 柱形图@"column" 折线图@"line" 曲线图@"spline" 曲线填充图@"areaspline" 等
@property (nonatomic, copy) NSString *chartType;
// 分组堆叠柱状图单独设置类型/需要model中stackType为堆叠
// 自定义堆叠组名 组名相同的会自动堆叠
@property (nonatomic, copy) NSString *stackGroup;
// 设置曲线填充区域透明度渐变 ep:[@"1", @"0.3"] 指从上到下从1到0.3渐变
@property (nonatomic, copy) NSArray *fillColorAlphas;
// 判断data中存在的NSNull连续值不超过12个(1h)时 数据不截断
@property (nonatomic, assign) BOOL autoGap;
// 左右双y轴使用 0左 1右
@property (nonatomic, strong) NSNumber *yAxis;
// 设置线图虚线样式
@property (nonatomic, copy) NSString *dashStyle;

// 分段展示颜色
@property (nonatomic, copy) NSArray<NSDictionary *> *zones;//范围值 ep:[@{value, fillColor}]
@property (nonatomic, assign) BOOL zoneAxisX;//默认Y轴

//新增五个参数
@property (nonatomic, assign) BOOL hideInTooltip; //数据是否隐藏于tooltips 默认否
@property (nonatomic, assign) CGFloat fillAlpha;//单独设置填充色的透明度
@property (nonatomic, copy) NSString *fillColor;//单独设置填充色
@property (nonatomic, copy) NSString *negativeColor;//单独设置负轴颜色
@property (nonatomic, assign) BOOL isStep; //是否设置为直方  （线图可使用）
@property (nonatomic, assign) BOOL markerHidden; //隐藏坐标节点圆圈
@property (nonatomic, assign) BOOL showPrev;// 直方图 特殊情况 需要tooltip展示前一位数据

//------计算后的数据------
- (void)formatData;//格式化单位数据
@property (nonatomic, readonly, strong) NSMutableArray<NSString *> *fdata;//根据单位计算后的数据 用于tooltip展示
@property (nonatomic, strong) NSArray <NSNumber *> * hidePoints;//在tooltip中不需要显示的点 是data的索引index
//考虑添加某一个点不显示的逻辑

//------带图例的属性配置------
@property (nonatomic, copy) NSString *legendBgColor;//图例背景颜色
@property (nonatomic, assign) CGFloat legendBgColorAlpha;//图例背景透明度
@property (nonatomic, assign) BOOL isHidden;//是否隐藏数据（默认开启）

//------图例配置属性ver2使用-----
@property (nonatomic, copy) NSString *icon;//图例图片名称
@property (nonatomic, assign) BOOL hideNameInTooltip;//tooltip中是否隐藏 默认展示

@end

@interface HMAASeriesUtil : NSObject

// 处理源数据
+ (double)doubleWithOriginData:(double)oriData showFabs:(BOOL)showFabs fractionDigits:(NSInteger)fractionDigits;

// 以千位为基准格式化 showFabs绝对值 trunc截断
+ (NSString *)formatCarryDouble:(double)orivalue trunc:(BOOL)trunc fractionDigits:(NSInteger)fractionDigits;

// 格式化小数 showFabs绝对值 trunc截断
+ (NSString *)formatDouble:(double)orivalue trunc:(BOOL)trunc fractionDigits:(NSInteger)fractionDigits;

// 通过单位类型获取单位
+ (NSString *)getUnitWithType:(HMAAElementUnitType)unitType;

// 将数组转化为json字符串
+ (NSString *)jsonSerializsWithArray:(NSArray *)array;

// 判断对象是否可以转数值
+ (BOOL)canTranslateToNum:(NSObject *)obj;

// 对象是否以千位进制
+ (BOOL)needCarryType:(HMAAElementUnitType)unitType;

// 格式化二维数组中的Null用于tooltip弹窗显示
+ (NSArray *)formatNullElements:(NSMutableArray *)elements;

// 格式化十六进制颜色添加透明度值
+ (NSString *)rgbaStringFromHex:(NSString *)hexColor withAlpha:(CGFloat)alpha;

// 图表计算数据数组最大最小值 {min max}
+ (NSDictionary *)calculateMaxMinValueWithNumberArray:(NSArray *)numberArray;

// 金额格式化货币符号
+ (NSString *)formatMoney:(NSString *)money withSymbol:(NSString *)symbol;

// 拆分数据序列返回正数据序列
+ (HMAASeriesElement *)positiveSplitFromSeriesElement:(HMAASeriesElement *)element;

// 拆分数据序列返回负数据序列
+ (HMAASeriesElement *)negativeSplitFromSeriesElement:(HMAASeriesElement *)element;

@end


NS_ASSUME_NONNULL_END
