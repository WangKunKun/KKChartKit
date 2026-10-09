#import "LCChartProbe.h"
#import "AAChartView.h"
#import "HMAASeries.h"

@implementation LCChartProbe
+ (void)findCharts:(UIView *)view result:(NSMutableArray<AAChartView *> *)result {
    if ([view isKindOfClass:AAChartView.class]) [result addObject:(AAChartView *)view];
    for (UIView *child in view.subviews) [self findCharts:child result:result];
}
+ (void)readChartsInView:(UIView *)view completion:(void (^)(NSArray<NSDictionary *> *, NSString *))completion {
    NSMutableArray<AAChartView *> *views = [NSMutableArray array];
    [self findCharts:view result:views];
    if (!views.count) { completion(@[], @"未找到 AAChartView"); return; }
    NSString *script = @"(function(){ if(typeof Highcharts==='undefined') return null;"
        "var charts=Highcharts.charts.filter(function(c){return c&&c.plotHeight>0;});"
        "if(!charts.length) return null; var c=charts[charts.length-1];"
        "return {version:Highcharts.version,categories:c.xAxis[0].categories.length,"
        "min:c.xAxis[0].min,max:c.xAxis[0].max,plotHeight:c.plotHeight,plotWidth:c.plotWidth,plotLeft:c.plotLeft,plotTop:c.plotTop,"
        "stacking:c.options.plotOptions.series.stacking||null,"
        "axes:c.yAxis.map(function(a){return {min:a.min,max:a.max,opposite:!!a.opposite};}),"
        "series:c.series.map(function(s){return {name:s.name,type:s.type,visible:s.visible,stack:s.options.stack||null,stackKey:s.stackKey||null,color:s.color,"
        "count:s.options.data.length,first:s.options.data[0],nulls:s.options.data.filter(function(v){return v===null;}).length,"
        "connectNulls:!!s.options.connectNulls,zoneAxis:s.options.zoneAxis||null,"
        "zones:(s.options.zones||[]).map(function(z){return {value:z.value===undefined?null:z.value,color:z.color||null};}),"
        "samples:s.points.filter(function(p){var n=s.options.data.length;return [0,Math.floor(n/4),Math.floor(n/2),Math.floor(n/2)+1,Math.floor(n*3/4),n-1].indexOf(p.x)!==-1;})"
        ".map(function(p){return {index:p.x,raw:p.y,percentage:p.percentage===undefined?null:p.percentage,"
        "stackY:p.stackY===undefined?null:p.stackY,total:p.total===undefined?null:p.total};})};}),"
        "tooltipVisible:!!(c.tooltip&&c.tooltip.label&&c.tooltip.label.element&&c.tooltip.label.element.getAttribute('visibility')!=='hidden'),"
        "tooltipText:c.tooltip&&c.tooltip.label&&c.tooltip.label.text?c.tooltip.label.text.textStr:null};})()";
    NSMutableArray *snapshots = [NSMutableArray array];
    for (NSInteger i = 0; i < views.count; i++) [snapshots addObject:NSNull.null];
    __block NSInteger remaining = views.count;
    __block NSString *failure = @"";
    [views enumerateObjectsUsingBlock:^(AAChartView *chart, NSUInteger index, BOOL *stop) {
        [chart evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if ([result isKindOfClass:NSDictionary.class]) snapshots[index] = result;
            else failure = error.localizedDescription ?: @"等待 Highcharts 实例";
            remaining--;
            if (remaining == 0) {
                NSMutableArray *valid = [NSMutableArray array];
                for (id snapshot in snapshots) if ([snapshot isKindOfClass:NSDictionary.class]) [valid addObject:snapshot];
                completion(valid, valid.count == views.count ? @"" : failure);
            }
        }];
    }];
}
+ (void)visibleLabelsInView:(UIView *)view result:(NSMutableArray *)labels {
    if (view.hidden || view.alpha < 0.01) return;
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length) [labels addObject:@{@"text":label.text, @"frame":NSStringFromCGRect([label convertRect:label.bounds toView:nil])}];
    }
    for (UIView *child in view.subviews) [self visibleLabelsInView:child result:labels];
}
+ (NSArray<NSDictionary *> *)visibleNativeTooltipsInView:(UIView *)view {
    if (view.hidden || view.alpha < 0.01) return @[];
    NSString *name = NSStringFromClass(view.class);
    if ([name isEqualToString:@"HMTooltip"] || [name isEqualToString:@"HMIconTooltip"]) {
        NSMutableArray *labels = [NSMutableArray array];
        [self visibleLabelsInView:view result:labels];
        return @[@{@"class":name, @"frame":NSStringFromCGRect([view convertRect:view.bounds toView:nil]), @"labels":labels}];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (UIView *child in view.subviews) [result addObjectsFromArray:[self visibleNativeTooltipsInView:child]];
    return result;
}
+ (NSDictionary *)inputBoundaryDiagnostics {
    // Invoke the unmodified pure conversion helpers. Catch only at this audit boundary,
    // so a known legacy exception can be recorded without crashing the test host.
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *mode in @[@"positive", @"negative"]) {
        HMAASeriesElement *element = [HMAASeriesElement new]; element.data = @[@1, NSNull.null, @(-1)];
        @try {
            HMAASeriesElement *split = [mode isEqual:@"positive"] ? [HMAASeriesUtil positiveSplitFromSeriesElement:element] : [HMAASeriesUtil negativeSplitFromSeriesElement:element];
            result[mode] = @{@"values":split.data};
        } @catch (NSException *exception) {
            result[mode] = @{@"exception":exception.name, @"reason":exception.reason ?: @""};
        }
    }
    HMAASeriesElement *original = [HMAASeriesElement new];
    original.name = @"copy audit"; original.data = @[@1, @(-1)];
    original.hideInTooltip = YES; original.hideNameInTooltip = YES; original.showPrev = YES;
    original.markerHidden = YES; original.negativeColor = @"#FF0000";
    HMAASeriesElement *copy = [HMAASeriesUtil positiveSplitFromSeriesElement:original];
    result[@"positiveCopy"] = @{@"hideInTooltip":@(copy.hideInTooltip), @"hideNameInTooltip":@(copy.hideNameInTooltip),
        @"showPrev":@(copy.showPrev), @"markerHidden":@(copy.markerHidden), @"negativeColor":copy.negativeColor ?: NSNull.null};
    return result;
}
@end
