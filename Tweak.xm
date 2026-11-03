#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 强制声明我们写的 Swift 类，防止链接报错
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

// 写日志工具
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"TurritAntiEdit.log"];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

// 当前界面辅助函数
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

// ==========================================
// 埋点 1: UI 层控制器 (从 DYKiller 抓出的真实类名)
// ==========================================
%hook TelegramUI_ChatControllerImpl
- (void)viewDidLoad {
    %orig;
    writeProbeLog(@"[UI] ChatControllerImpl viewDidLoad 触发");
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    writeProbeLog(@"[UI] ChatControllerImpl viewDidAppear 触发");
}
%end

// ==========================================
// 埋点 2: 底层网络解析器 (带点号的真实类名)
// ==========================================
@interface TelegramCore_Serialization : NSObject
- (id)parseMessage:(id)a0;
@end
%hook TelegramCore_Serialization
- (id)parseMessage:(id)a0 {
    id res = %orig;
    if (res) {
        NSString *cls = NSStringFromClass([res class]);
        writeProbeLog(@"[网络] 解析出包: %@", cls);
    }
    return res;
}
%end

// ==========================================
// 埋点 3: MTProto 接收服务
// ==========================================
@interface TelegramCore_MtProtoKitUpdateSinkService : NSObject
- (void)mtProto:(id)a0 receivedMessage:(id)a1 authInfoSelector:(long long)a2 networkType:(int)a3;
@end
%hook TelegramCore_MtProtoKitUpdateSinkService
- (void)mtProto:(id)a0 receivedMessage:(id)a1 authInfoSelector:(long long)a2 networkType:(int)a3 {
    NSString *cls = NSStringFromClass([a1 class]);
    writeProbeLog(@"[底层网络] 收到消息包: %@", cls);
    %orig;
}
%end

// ==========================================
// 埋点 4: 尝试拦截可能用到的 TGMessage (带点号版本)
// ==========================================
@interface TurritUIFramework_TGMessage : NSObject
- (void)setMediaAttachments:(NSArray *)arg1;
@end
%hook TurritUIFramework_TGMessage
- (void)setMediaAttachments:(NSArray *)arg1 {
    writeProbeLog(@"[UI] TGMessage setMediaAttachments 触发，拦截！");
    return;
}
%end

// ==========================================
// 埋点 5: 全局钩住数据更新 (即使纯 Swift 也会走 setValue)
// ==========================================
%hook NSObject
- (void)setValue:(id)value forKey:(NSString *)key {
    %orig;
    if ([key isEqualToString:@"message"] || [key isEqualToString:@"media"] || [key isEqualToString:@"mediaAttachments"]) {
        writeProbeLog(@"[KVC] %@ setValue forKey: %@ 触发", NSStringFromClass([self class]), key);
    }
}
%end
