#import "LCAppDelegate.h"
#import "LCCatalogViewController.h"

@implementation LCAppDelegate
@end

@implementation LCSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[LCCatalogViewController new]];
    [self.window makeKeyAndVisible];
}
@end
