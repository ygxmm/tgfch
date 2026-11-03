#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 只需要声明我们要 Hook 的类
@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

static UIViewController* topViewController() {
    UIWindow *keyWindow = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;
    return rootVC;
}

%hook LeadEditHistoryViewController

+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    
    id history = nil;
    
    // 使用运行时动态获取 TLParser 类，避免链接错误
    Class TLParserClass = NSClassFromString(@"TLParser");
    if (TLParserClass && [TLParserClass respondsToSelector:NSSelectorFromString(@"editHistoryForKey:")]) {
        // 动态调用 editHistoryForKey:
        history = [TLParserClass performSelector:NSSelectorFromString(@"editHistoryForKey:") withObject:a0];
    }
    
    // 拼装探针数据
    NSString *probeStr = [NSString stringWithFormat:@"Key: %@\n\nmediaReplaced: %d\n\n[TLParser获取的历史数据]:\n%@", a0, a1, history];
    
    // 限制一下字数，免得太大崩溃
    if (probeStr.length > 1500) {
        probeStr = [probeStr substringToIndex:1500];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"探针：历史数据" message:probeStr preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
        [topViewController() presentViewController:alert animated:YES completion:nil];
    });
    
    // 彻底拦截原来的灰框
    return; 
}

%end
