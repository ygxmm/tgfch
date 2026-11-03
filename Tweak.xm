#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 声明我们要 Hook 的类
@interface TelegramCore_Serialization : NSObject
- (id)parseMessage:(id)a0;
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

// 因为 Objective-C 中带点号的类名，在 Theos 中通常用下划线替换
%hook TelegramCore_Serialization

- (id)parseMessage:(id)a0 {
    // 调用原方法，让 Turrit 自己解析出网络包对象
    id result = %orig;
    
    if (result) {
        // 获取解析后的类名，比如 Cons_updateEditMessage
        NSString *className = NSStringFromClass([result class]);
        
        // 如果类名包含 Edit 或者 Update，说明可能是编辑消息
        if ([className containsString:@"Edit"] || [className containsString:@"Update"]) {
            NSLog(@"[TurritAntiEdit] 抓包成功！解析结果类名: %@", className);
            
            // 为了防止刷屏，只有看到 Edit 相关的才弹窗
            if ([className containsString:@"Edit"]) {
                NSString *msg = [NSString stringWithFormat:@"拦截到网络包: %@\n\n内容: %@", className, result];
                
                if (msg.length > 1000) {
                    msg = [msg substringToIndex:1000];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"网络层探针(Edit)" message:msg preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                    [topViewController() presentViewController:alert animated:YES completion:nil];
                });
            }
        }
    }
    
    return result;
}

%end
