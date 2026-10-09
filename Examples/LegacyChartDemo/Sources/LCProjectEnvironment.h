#import <UIKit/UIKit.h>

// Only the old project's external environment is supplied here. Chart code is unchanged.
static inline NSString *LCLocalizedString(NSString *key) {
    NSDictionary *strings = @{
        @"k_5_1093": @"暂无数据", @"k_5_1433": @"购电", @"k_5_1432": @"馈电",
        @"k_5_209303": @"A 相购电", @"k_5_209304": @"A 相馈电",
        @"k_5_209305": @"B 相购电", @"k_5_209306": @"B 相馈电",
        @"k_5_209307": @"C 相购电", @"k_5_209308": @"C 相馈电",
        @"k_5_5417": @"充电", @"k_5_5416": @"放电"
    };
    return strings[key] ?: key;
}
#define Language(key) LCLocalizedString(key)
#define colorNamed(name) ([UIColor colorNamed:(name)] ?: UIColor.secondaryLabelColor)
#define Font_Size_weight(size, fontWeight) [UIFont systemFontOfSize:(size) weight:(fontWeight)]
#define CHECK_NULL_EXEC_BLOCK(block) do { if ((block)) { (block)(); } } while (0)
