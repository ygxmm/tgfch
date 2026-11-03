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
        
        // 1. 拦截撤回指令
        if ([desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateDeleteMessages"]) {
            logPacket([NSString stringWithFormat:@"🛑 [拦截撤回] 丢弃包: %@\n\n", [desc substringToIndex:MIN(desc.length, 200)]]);
            // 返回一个空的 BoxedMessage 或者空的 Updates 结构（如果有默认构造函数）
            // 由于是纯 Swift，直接返回 nil 可能报错，我们尝试返回原值，但通过下面的方法拦截
        }
        
        // 2. 拦截编辑指令
        if ([desc containsString:@"updateEditChannelMessage"] || [desc containsString:@"updateEditMessage"]) {
            logPacket([NSString stringWithFormat:@"🛑 [拦截编辑] 丢弃包: %@\n\n", [desc substringToIndex:MIN(desc.length, 200)]]);
        }
    }
    
    return result;
}
%end

// 核心大招：拦截底层更新分发器
@interface TelegramCore_UpdateMessageService : NSObject
@end
%hook TelegramCore_UpdateMessageService

// 如果存在这个方法，我们直接拦截（由于纯 Swift 没有暴露具体方法，我们动态查找）
- (void)process:(id)arg1 {
    NSString *desc = [arg1 description];
    if ([desc containsString:@"updateEdit"] || [desc containsString:@"updateDelete"]) {
        logPacket(@"[分发层] 拦截并阻止更新！");
        return; // 阻止执行！
    }
    %orig;
}

%end

// 注入悬浮按钮
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
