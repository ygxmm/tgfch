#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 记录拦截次数
static int blockCount = 0;

// 弹窗提示
void showInterceptAlert(NSString *type) {
    dispatch_async(dispatch_get_main_queue(), ^{
        blockCount++;
        
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:type message:[NSString stringWithFormat:@"成功拦截底层指令！(累计 %d 次)", blockCount] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

%hook _TtC12TelegramCore13Serialization

- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    if (result) {
        @try {
            NSString *desc = [result description];
            
            // 拦截撤回
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateDeleteChannelMessages"]) {
                showInterceptAlert(@"防撤回成功");
                return nil; // 阻断数据包进入数据库，但网络层已经收到包了，所以不会断网
            }
            
            // 拦截编辑
            if ([desc containsString:@"updateEditMessage"] || [desc containsString:@"updateEditChannelMessage"]) {
                showInterceptAlert(@"防编辑成功");
                return nil; // 阻断数据包
            }
        } @catch (NSException *e) {}
    }
    return result;
}

%end
