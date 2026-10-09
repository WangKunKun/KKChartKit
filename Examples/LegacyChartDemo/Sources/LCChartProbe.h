#import <UIKit/UIKit.h>

/// Demo-only, read-only runtime inspection. Does not replace the old chart's delegate or formatter.
@interface LCChartProbe : NSObject
+ (void)readChartsInView:(UIView *)view completion:(void (^)(NSArray<NSDictionary *> *charts, NSString *error))completion;
+ (NSArray<NSDictionary *> *)visibleNativeTooltipsInView:(UIView *)view;
+ (NSDictionary *)inputBoundaryDiagnostics;
@end
