#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 弹窗工具
void popAlert(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

// ==========================================
// 探针 A：网络解析层（确认能不能抓到包）
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        NSString *desc = [result description];
        if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
            // 只要抓到了包，立刻弹窗！
            popAlert(@"探针A触发：网络层", @"成功拦截到撤回/编辑包！");
        }
    }
    return result;
}
%end

// ==========================================
// 探针 B：UI 节点层（确认这个类到底有没有被使用）
// ==========================================
@interface _TtC19ChatMessageItemView19ChatMessageItemView : UIView
@end

%hook _TtC19ChatMessageItemView19ChatMessageItemView
- (void)didMoveToWindow {
    %orig;
    // 只要这个视图出现，就弹窗
    static BOOL hasAlerted = NO;
    if (!hasAlerted && self.window) {
        hasAlerted = YES;
        popAlert(@"探针B触发：UI层", @"ChatMessageItemView 加载成功，可以尝试注入按钮！");
    }
}
%end
