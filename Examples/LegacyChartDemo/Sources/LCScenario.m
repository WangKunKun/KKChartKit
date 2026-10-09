#import "LCScenario.h"

@interface LCScenario ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *summary;
@property (nonatomic, copy, readwrite) NSString *instructions;
@end

@implementation LCScenario
+ (NSArray<LCScenario *> *)catalog {
    NSArray *definitions = @[
        @[@"power", @"功率曲线与业务卡片", @"v2 · 原生图标提示 / 统计表头 / 日出日落 / 三组图例", @"在曲线上按住并横移，观察提示与统计表头的切换。点击图例开关；留意中间业务组是否完整出现在提示中。"],
        @[@"line", @"折线、阶梯与前值", @"v1 · JS 提示 / 虚线 / marker / showPrev", @"切换 v1/v2 与 JS/原生提示，比较阶梯前值、单位和抬手后的行为。程序选点通过旧 setTouchPointXIndex 调用。"],
        @[@"column", @"电量柱状与分组堆叠", @"并排 / 普通堆叠 / 百分比 · 两个 stackGroup", @"切换堆叠模式并关闭一个系列，观察柱组、百分比和提示值。通过旧图例直接修改系列显隐。"],
        @[@"signed", @"正负堆叠与百分比", @"跨零柱状 · 正负成员 · 绝对值展示", @"切换普通和百分比堆叠，检查正负分链、坐标与提示原值。绝对值仅用于格式化展示，不预先改写绘图数据。"],
        @[@"legendGroups", @"组内分栏与长图例", @"12 系列 · gcname / stackGroupInterval · 换行", @"一组包含十二条系列，分成左右两栏并带分标题。检查提示是否完整、长名称图例是否换行，以及 v1/v2 的高度差异。"],
        @[@"mixed", @"混合图与双 Y 轴", @"column + areaspline + spline · 功率 / 温度", @"比较左右轴单位、范围和提示。缩放后执行完整刷新与仅刷新数据，检查窗口和数据是否变化。"],
        @[@"gaps", @"缺测、分区和正负颜色", @"5 / 12 个 NSNull · autoGap · X zones / negativeColor", @"短缺测和 12 点缺测使用确定性输入。观察是否连线、面积闭合、跨零颜色及默认窗口。"],
        @[@"format", @"提示分组与数值格式", @"逐点行/组名 · k/M · 金额 · 隐藏 / 仅名称", @"数据包含分级精度、独立提示表头、三组、前值和过滤规则。切换两版提示，记录每条路径实际显示的内容。"],
        @[@"dense", @"长序列与默认窗口", @"288 / 1440 / 3000 点 · defaultScope · X 缩放", @"使用双指缩放和横向拖动。选择点数后重建场景；刷新两种入口使用同一可预测的数据增量。"],
        @[@"empty", @"无数据与恢复", @"空数组 / 强制空态 / 全零 / 全系列隐藏", @"默认空数组。用恢复数据、全零、强制空态按钮分别检查；全零应可绘制。恢复时重新提交完整模型。"],
        @[@"multi", @"旧组件多图联动", @"HMMTAAChartView · 三张图 / 同采样域", @"直接使用原 HMMTAAChartView 的索引广播。拖动任意图，比较 JS 与原生提示的同步效果；不假定窗口也会同步。"]
    ];
    NSMutableArray *scenarios = [NSMutableArray array];
    for (NSArray *definition in definitions) {
        LCScenario *scenario = [LCScenario new];
        scenario.identifier = definition[0]; scenario.title = definition[1];
        scenario.summary = definition[2]; scenario.instructions = definition[3];
        [scenarios addObject:scenario];
    }
    return scenarios;
}
- (BOOL)multipleCharts { return [self.identifier isEqualToString:@"multi"]; }

- (HMAASeriesElement *)element:(NSString *)name color:(NSString *)color count:(NSInteger)count phase:(double)phase revision:(NSInteger)revision {
    HMAASeriesElement *element = [HMAASeriesElement new];
    element.name = name; element.color = color; element.icon = @"ct_lg_solar";
    element.unitType = HMAAElementUnitType_W; element.markerHidden = YES;
    element.legendBgColor = color; element.legendBgColorAlpha = 0.10;
    element.fillColorAlphas = @[@"0.40", @"0.04"];
    NSMutableArray *values = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        double x = (double)i / MAX(count - 1, 1);
        double value = 400 + 2400 * MAX(0, sin(x * M_PI)) + 260 * sin(x * 6 * M_PI + phase) + phase * 180;
        [values addObject:@(round(value + revision * 125))];
    }
    element.data = values;
    return element;
}
- (HMAASeries *)group:(NSString *)name elements:(NSArray<HMAASeriesElement *> *)elements icon:(NSString *)icon {
    HMAASeries *group = [HMAASeries new];
    group.gname = name; group.element = elements; group.unitType = elements.firstObject.unitType;
    group.icon = icon; group.color = elements.firstObject.color; group.showElementName = YES;
    for (HMAASeriesElement *element in elements) element.icon = icon;
    return group;
}
- (HMAAChartModel *)baseModel:(NSInteger)count {
    HMAAChartModel *model = [HMAAChartModel new];
    model.name = self.title; model.version = 2; model.unit = @"W";
    model.chartType = HMAAChartTypeAreaspline; model.showLegend = YES;
    model.nativeTooltip = YES; model.zoomType = HMAAChartZoomTypeX;
    model.chartHeight = 330; model.xAxisTickInterval = @(MAX(1, count / 6));
    NSMutableArray *categories = [NSMutableArray array], *headers = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        NSInteger minute = i * 1440 / count;
        NSString *time = [NSString stringWithFormat:@"%02ld:%02ld", (long)(minute / 60), (long)(minute % 60)];
        [categories addObject:time]; [headers addObject:[@"2026-09-30 " stringByAppendingString:time]];
    }
    model.xAxisArray = categories; model.xSeriesArray = headers;
    return model;
}
- (NSArray<HMAAChartModel *> *)makeModelsWithPointCount:(NSInteger)count revision:(NSInteger)revision {
    count = MAX(count, 48);
    if (count == 48 && ([@"gaps" isEqual:self.identifier] || [@"format" isEqual:self.identifier])) {
        return @[[self makeDetailAuditModelWithRevision:revision]];
    }
    if ([self.identifier isEqualToString:@"signed"] && count == 48) {
        return @[[self makeAuditModelWithIdentifier:@"signed-column" revision:revision]];
    }
    HMAAChartModel *model = [self baseModel:count];
    HMAASeriesElement *solar = [self element:@"屋顶光伏" color:@"#F2A93B" count:count phase:0 revision:revision];
    HMAASeriesElement *load = [self element:@"家庭负载" color:@"#43A8EF" count:count phase:1 revision:revision];
    HMAASeriesElement *grid = [self element:@"电网功率" color:@"#53BC82" count:count phase:2 revision:revision];
    model.seriesArray = @[[self group:@"发电" elements:@[solar] icon:@"ct_lg_solar"],
                          [self group:@"用电" elements:@[load] icon:@"ct_lg_load"],
                          [self group:@"电网" elements:@[grid] icon:@"ct_lg_grid"]];
    if ([self.identifier isEqualToString:@"power"]) {
        HMChartHeaderModel *energy = [HMChartHeaderModel new];
        energy.title = @"今日发电"; energy.data = @"18.62"; energy.unit = @"kWh";
        HMChartHeaderModel *peak = [HMChartHeaderModel new];
        peak.title = @"峰值功率"; peak.data = @"3.24"; peak.unit = @"kW";
        model.headerDatas = @[energy, peak];
        HMChartSunModel *rise = [[HMChartSunModel alloc] initSunriseModel]; rise.title = @"日出"; rise.time = @"06:12";
        HMChartSunModel *set = [[HMChartSunModel alloc] initSunsetModel]; set.title = @"日落"; set.time = @"18:08";
        model.sunDatas = @[rise, set]; model.chartHeight = 390;
    } else if ([self.identifier isEqualToString:@"line"]) {
        model.version = 1; model.nativeTooltip = NO; model.chartType = HMAAChartTypeLine;
        solar.markerHidden = NO; load.isStep = YES; load.showPrev = YES; load.dashStyle = @"ShortDash";
        model.seriesArray = @[[self group:@"功率" elements:@[solar, load] icon:@"ct_lg_solar"]];
    } else if ([self.identifier isEqualToString:@"column"]) {
        model.chartType = HMAAChartTypeColumn; model.unit = @"Wh"; model.stackType = HMAAChartStackingTypeNormal;
        HMAASeriesElement *second = [self element:@"车库光伏" color:@"#FFD069" count:count phase:0.5 revision:revision];
        solar.stackGroup = @"generation"; second.stackGroup = @"generation";
        load.stackGroup = @"consumption"; grid.stackGroup = @"consumption";
        for (HMAASeriesElement *element in @[solar, second, load, grid]) element.unitType = HMAAElementUnitType_Wh;
        model.seriesArray = @[[self group:@"发电量" elements:@[solar, second] icon:@"ct_lg_solar"],
                              [self group:@"消耗量" elements:@[load, grid] icon:@"ct_lg_load"]];
    } else if ([self.identifier isEqualToString:@"signed"]) {
        model.chartType = HMAAChartTypeColumn; model.stackType = HMAAChartStackingTypeNormal;
        NSMutableArray *a = [NSMutableArray array], *b = [NSMutableArray array];
        for (NSInteger i = 0; i < count; i++) {
            double value = 1800 * sin((double)i / count * 2 * M_PI);
            [a addObject:@(round(value + revision * 125))];
            [b addObject:@(round(value * 0.5 + 220))];
        }
        solar.name = @"电池充放电"; solar.data = a; solar.stackGroup = @"battery"; solar.showFabs = YES;
        load.name = @"辅助功率"; load.data = b; load.stackGroup = @"battery";
        model.seriesArray = @[[self group:@"电池" elements:@[solar, load] icon:@"ct_lg_battery"]];
    } else if ([self.identifier isEqualToString:@"legendGroups"]) {
        NSMutableArray *elements = [NSMutableArray array];
        NSArray *colors = @[@"#F2A93B", @"#43A8EF", @"#53BC82", @"#9769E8", @"#E46F86", @"#58C9C4"];
        for (NSInteger i = 0; i < 12; i++) {
            HMAASeriesElement *element = [self element:[NSString stringWithFormat:@"逆变器 %02ld 功率", (long)(i + 1)] color:colors[i % colors.count] count:count phase:i * 0.15 revision:revision];
            [elements addObject:element];
        }
        HMAASeries *group = [self group:@"屋顶阵列" elements:elements icon:@"ct_lg_solar"];
        group.gcname = @"车库阵列"; group.stackGroupInterval = @6;
        model.seriesArray = @[group];
    } else if ([self.identifier isEqualToString:@"mixed"]) {
        model.chartType = HMAAChartTypeColumn; solar.chartType = @"column"; load.chartType = @"areaspline";
        grid.chartType = @"spline"; grid.name = @"组件温度"; grid.unitType = HMAAElementUnitType_T; grid.yAxis = @1;
        NSMutableArray *temperatures = [NSMutableArray array];
        for (NSInteger i = 0; i < count; i++) [temperatures addObject:@(22 + 18 * sin((double)i / count * M_PI) + revision)];
        grid.data = temperatures;
        HMAAYAxis *axis = [HMAAYAxis new]; axis.unit = @"℃"; axis.yAxisMin = @0; axis.yAxisMax = @60;
        model.subYAxis = axis;
        HMAAPlotLinesElement *limit = [HMAAPlotLinesElement new];
        limit.value = @2500; limit.color = @"#E45E5E"; limit.width = @1; limit.dashStyle = @"Dash";
        limit.text = @"功率参考线"; limit.textColor = @"#E45E5E"; limit.fontSize = @"10";
        model.yAxisPlotLines = @[limit];
    } else if ([self.identifier isEqualToString:@"gaps"]) {
        NSMutableArray *values = [solar.data mutableCopy];
        for (NSInteger i = 8; i < 13; i++) values[i] = NSNull.null;
        for (NSInteger i = 25; i < 37; i++) values[i] = NSNull.null;
        solar.data = values; solar.autoGap = YES;
        solar.zones = @[@{@"value": @20, @"color": @"#F2A93B", @"fillColor": @"#F2A93B44"},
                        @{@"color": @"#9769E8", @"fillColor": @"#9769E844"}]; solar.zoneAxisX = YES;
        NSMutableArray *signedValues = [NSMutableArray array];
        for (NSInteger i = 0; i < count; i++) [signedValues addObject:@(1800 * sin((double)i / count * 2 * M_PI) + revision * 125)];
        load.data = signedValues; load.negativeColor = @"#E46F86";
        model.seriesArray = @[[self group:@"缺测与跨零" elements:@[solar, load] icon:@"ct_lg_grid"]];
    } else if ([self.identifier isEqualToString:@"format"]) {
        NSMutableArray *values = [NSMutableArray array], *names = [NSMutableArray array], *groupNames = [NSMutableArray array];
        for (NSInteger i = 0; i < count; i++) {
            [values addObject:@(i % 2 ? 1234567.89 : 1234.567)];
            [names addObject:[NSString stringWithFormat:@"逆变器 %ld", (long)(i % 3 + 1)]];
            [groupNames addObject:[NSString stringWithFormat:@"发电分组 %ld", (long)(i % 2 + 1)]];
        }
        solar.data = values; solar.names = names; solar.fractionDigits = 100;
        HMAASeries *generation = model.seriesArray[0]; generation.gnames = groupNames; generation.fractionDigits = 100;
        load.name = @"收益"; load.unitType = HMAAElementUnitType_MONEY; load.currencySymbol = @"¥"; load.trunc = YES;
        HMAASeries *money = model.seriesArray[1]; money.unitType = HMAAElementUnitType_MONEY; money.currencySymbol = @"¥";
        grid.isStep = YES; grid.showPrev = YES; grid.hidePoints = @[@10, @11];
        HMAASeriesElement *nameOnly = [self element:@"设备正常" color:@"#9769E8" count:count phase:0 revision:revision];
        nameOnly.hideInTooltip = YES; generation.element = @[solar, nameOnly];
        money.onlyNameIntooltip = YES;
    } else if ([self.identifier isEqualToString:@"dense"]) {
        model.defaultScope = @[@0, @(MIN(96, count - 1))];
    } else if ([self.identifier isEqualToString:@"empty"]) {
        model.seriesArray = @[]; model.showLegend = NO;
    } else if (self.multipleCharts) {
        NSMutableArray *models = [NSMutableArray array];
        for (NSInteger i = 0; i < 3; i++) {
            HMAAChartModel *linked = [self baseModel:count]; linked.chartHeight = 240;
            linked.name = @[@"光伏功率", @"家庭负载", @"电网功率"][i]; linked.nativeTooltip = NO;
            linked.seriesArray = @[[self group:linked.name elements:@[@[solar, load, grid][i]] icon:@"ct_lg_solar"]];
            [models addObject:linked];
        }
        return models;
    }
    return @[model];
}
// Demo-only fixture reader; this is deliberately not the production migration adapter.
- (HMAAChartModel *)makeDetailAuditModelWithRevision:(NSInteger)revision {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"chart-migration-audit-v2" withExtension:@"json"];
    NSAssert(url, @"Missing shared detail fixture");
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:nil];
    NSDictionary *sample = nil;
    for (NSDictionary *candidate in fixture[@"detailCases"]) if ([candidate[@"id"] isEqual:self.identifier]) sample = candidate;
    NSAssert(sample, @"Unknown detail fixture");
    HMAAChartModel *model = [self baseModel:[fixture[@"categories"] count]];
    model.xAxisArray = fixture[@"categories"]; model.xSeriesArray = fixture[@"xSeries"];
    NSMutableDictionary *elements = [NSMutableDictionary dictionary];
    for (NSDictionary *input in sample[@"series"]) {
        HMAASeriesElement *element = [self element:input[@"name"] color:input[@"color"] count:model.xAxisArray.count phase:0 revision:0];
        NSMutableArray *values = [NSMutableArray array];
        for (id value in input[@"values"]) {
            [values addObject:value == NSNull.null ? value : @([value doubleValue] + revision * [input[@"revisionDelta"] doubleValue])];
        }
        element.data = values; element.names = [input[@"names"] mutableCopy];
        if (input[@"fractionDigits"]) element.fractionDigits = [input[@"fractionDigits"] integerValue];
        element.autoGap = [input[@"autoGap"] boolValue]; element.zoneAxisX = [input[@"zoneAxisX"] boolValue];
        element.zones = input[@"zones"]; element.negativeColor = input[@"negativeColor"];
        element.hideInTooltip = [input[@"hideInTooltip"] boolValue]; element.showPrev = [input[@"showPrev"] boolValue];
        element.isStep = [input[@"isStep"] boolValue]; element.hidePoints = input[@"hidePoints"];
        element.trunc = [input[@"trunc"] boolValue]; element.currencySymbol = input[@"currencySymbol"];
        if ([input[@"unit"] isEqual:@"MONEY"]) element.unitType = HMAAElementUnitType_MONEY;
        elements[input[@"id"]] = element;
    }
    NSMutableArray *groups = [NSMutableArray array];
    for (NSDictionary *input in sample[@"groups"]) {
        NSMutableArray *members = [NSMutableArray array];
        for (NSString *identifier in input[@"members"]) [members addObject:elements[identifier]];
        NSString *icon = [self.identifier isEqual:@"gaps"] || [input[@"id"] isEqual:@"grid"] ? @"ct_lg_grid" :
            ([input[@"id"] isEqual:@"consumption"] ? @"ct_lg_load" : @"ct_lg_solar");
        HMAASeries *group = [self group:input[@"name"] elements:members icon:icon];
        group.gnames = [input[@"names"] mutableCopy]; group.onlyNameIntooltip = [input[@"onlyNameIntooltip"] boolValue];
        group.currencySymbol = input[@"currencySymbol"];
        if (input[@"fractionDigits"]) group.fractionDigits = [input[@"fractionDigits"] integerValue];
        [groups addObject:group];
    }
    model.seriesArray = groups;
    return model;
}
- (HMAAChartModel *)makeAuditModelWithIdentifier:(NSString *)identifier revision:(NSInteger)revision {
    BOOL boundary = [identifier hasPrefix:@"boundary-"];
    NSURL *url = [NSBundle.mainBundle URLForResource:boundary ? @"chart-area-boundaries-v1" : @"chart-migration-audit-v1" withExtension:@"json"];
    NSAssert(url, @"Missing shared audit fixture");
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:nil];
    NSDictionary *sample = nil;
    for (NSDictionary *candidate in fixture[@"cases"]) if ([candidate[@"id"] isEqual:identifier]) sample = candidate;
    NSAssert(sample, @"Unknown audit fixture: %@", identifier);
    HMAAChartModel *model = [self baseModel:[fixture[@"categories"] count]];
    model.xAxisArray = fixture[@"categories"];
    model.chartType = [sample[@"topType"] isEqual:@"areaspline"] ? HMAAChartTypeAreaspline :
        ([sample[@"topType"] isEqual:@"line"] ? HMAAChartTypeLine : HMAAChartTypeColumn);
    model.stackType = HMAAChartStackingTypeNormal;
    NSMutableDictionary *elements = [NSMutableDictionary dictionary];
    for (NSDictionary *input in sample[@"series"]) {
        HMAASeriesElement *element = [self element:input[@"name"] color:input[@"color"] count:model.xAxisArray.count phase:0 revision:0];
        element.chartType = input[@"kind"]; element.stackGroup = input[@"stackID"];
        NSMutableArray *values = [input[@"values"] mutableCopy];
        if ([input[@"id"] isEqual:@"battery"]) {
            for (NSInteger i = 0; i < values.count; i++) values[i] = @([values[i] doubleValue] + revision * 125);
            element.showFabs = YES;
        }
        element.data = values; elements[input[@"id"]] = element;
    }
    NSMutableArray *groups = [NSMutableArray array];
    for (NSArray *ids in sample[@"groups"]) {
        NSMutableArray *members = [NSMutableArray array];
        for (NSString *key in ids) [members addObject:elements[key]];
        [groups addObject:[self group:@"电池" elements:members icon:@"ct_lg_battery"]];
    }
    model.seriesArray = groups;
    if (boundary) {
        model.name = [identifier isEqual:@"boundary-crossing"] ? @"跨零最小对照" : @"前层换链最小对照";
        model.xSeriesArray = fixture[@"categories"];
        // Keep the real legacy converter (including its areaspline top-level split branch).
        // Series and top-level type are both areaspline, as in the old module's area use case.
        for (HMAASeriesElement *element in elements.allValues) element.fillColorAlphas = @[@"0.60", @"0.60"];
    }
    return model;
}
@end
