#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 基于 dump 的头文件精准声明
@interface TLParser : NSObject
+ (id)editHistoryForKey:(id)a0;
+ (id)editHistoryForMessageId:(id)a0;
@end

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
    
    // 从 TLParser 精准获取对应的历史数据
    id history = nil;
    if ([TLParser respondsToSelector:@selector(editHistoryForKey:)]) {
        history = [TLParser editHistoryForKey:a0];
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
    
    // 绝对不执行 %orig，原生的那个“媒体已被替换”灰框将被彻底拦截！
    return; 
}

%end
