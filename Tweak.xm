#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明 Swift UI
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

// 日志工具
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args; va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
        NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"TurritAntiEdit.log"];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

static UIViewController* topVC() {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (!kw) kw = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *vc = kw.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

// ==========================================
// 1. 暴力 Hook 系统级 NSData 写入
// ==========================================
%hook NSData
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    // 只要路径里包含这几样，大概率就是缓存或者数据库
    if ([path containsString:@"Telegram"] || [path containsString:@"Turrit"] || [path containsString:@"Media"] || [path containsString:@"Cache"]) {
        // 如果包含图片后缀，说明正在存图！
        if ([path containsString:@".jpg"] || [path containsString:@".png"] || [path containsString:@"media"]) {
            writeProbeLog(@"[文件写入] 发现图片/媒体数据写入: %@", path);
        }
    }
    return %orig;
}
%end

// ==========================================
// 2. 暴力 Hook 窗口，把按钮贴在最上层
// ==========================================
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    
    // 延迟 2 秒注入，等 UI 加载完
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 防止重复添加
        for (UIView *v in self.subviews) {
            if (v.tag == 55555) return;
        }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 55555;
        btn.frame = CGRectMake(20, 150, 60, 60);
        btn.backgroundColor = [UIColor purpleColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"扒库" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dumpAllData) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:btn];
        writeProbeLog(@"[UI] 悬浮按钮成功注入到 UIWindow！");
    });
}

- (void)dumpAllData {
    NSMutableString *dumpText = [NSMutableString string];
    [dumpText appendString:@"=== 正在扫描当前界面的消息状态 ===\n"];
    
    UIViewController *vc = topVC();
    [dumpText appendFormat:@"当前控制器: %@\n", NSStringFromClass([vc class])];
    
    // 如果是 TelegramUI_ChatControllerImpl
    if ([NSStringFromClass([vc class]) containsString:@"ChatController"]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([vc class], &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            NSString *nameStr = [NSString stringWithUTF8String:name];
            
            if ([nameStr localizedCaseInsensitiveContainsString:@"message"] ||
                [nameStr localizedCaseInsensitiveContainsString:@"state"] ||
                [nameStr localizedCaseInsensitiveContainsString:@"data"]) {
                [dumpText appendFormat:@"变量: %@\n", nameStr];
                @try {
                    id val = [vc valueForKey:nameStr];
                    if (val) [dumpText appendFormat:@"值: %@\n\n", [val description]];
                } @catch (NSException *e) {}
            }
        }
        free(ivars);
    } else {
        [dumpText appendString:@"当前没在聊天界面，或者类名不对。"];
    }
    
    if (dumpText.length > 3000) {
        dumpText = (NSMutableString *)[dumpText substringToIndex:3000];
    }
    
    [AntiEditViewerController presentFrom:vc imageUrl:dumpText];
}

%end
