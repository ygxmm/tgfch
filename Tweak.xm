#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void logPacket(NSString *text) {
    @try {
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Blocked.txt"];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    if (result) {
        NSString *desc = [result description];
        
        // 1. 拦截撤回指令 (updateDeleteChannelMessages / updateDeleteMessages)
        if ([desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateDeleteMessages"]) {
            logPacket([NSString stringWithFormat:@"🛑 [防撤回] 拦截并丢弃数据包: %@\n\n", desc]);
            return nil; // 丢弃这个数据包，界面不会消失！
        }
        
        // 2. 拦截编辑指令 (updateEditMessage / updateEditChannelMessage)
        if ([desc containsString:@"updateEditMessage"] || [desc containsString:@"updateEditChannelMessage"]) {
            logPacket([NSString stringWithFormat:@"🛑 [防编辑] 拦截并丢弃数据包: %@\n\n", desc]);
            return nil; // 丢弃这个数据包，内容不会改变！
        }
    }
    
    return result;
}
%end

// 注入一个悬浮按钮方便看日志
@interface BlockHandler : NSObject
+ (instancetype)shared;
- (void)showLog:(UIButton *)sender;
@end
@implementation BlockHandler
+ (instancetype)shared {
    static BlockHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[BlockHandler alloc] init]; });
    return instance;
}
- (void)showLog:(UIButton *)sender {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Blocked.txt"];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content || content.length == 0) content = @"没有拦截到任何数据。";
    if (content.length > 1000) content = [content substringFromIndex:content.length - 1000];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"拦截日志" message:content preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 11111) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 11111;
        btn.frame = CGRectMake(20, 200, 60, 60);
        btn.backgroundColor = [UIColor systemGreenColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"日志" forState:UIControlStateNormal];
        [btn addTarget:[BlockHandler shared] action:@selector(showLog:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
%end
