#import <Foundation/Foundation.h>
#import "HMAAChartKit.h"

@interface LCScenario : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *summary;
@property (nonatomic, copy, readonly) NSString *instructions;
@property (nonatomic, readonly) BOOL multipleCharts;
+ (NSArray<LCScenario *> *)catalog;
- (NSArray<HMAAChartModel *> *)makeModelsWithPointCount:(NSInteger)count revision:(NSInteger)revision;
// Demo audit presets share immutable JSON inputs with the native renderer tests.
- (HMAAChartModel *)makeAuditModelWithIdentifier:(NSString *)identifier revision:(NSInteger)revision;
@end
