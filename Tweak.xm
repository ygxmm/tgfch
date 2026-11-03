#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

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

@interface TurritUIFramework_TGMessage : NSObject
- (void)setMediaAttachments:(NSArray *)arg1;
@end
%hook TurritUIFramework_TGMessage
- (void)setMediaAttachments:(NSArray *)arg1 {
    writeProbeLog(@"[UI] TGMessage setMediaAttachments 触发，拦截！");
    return;
}
%end

%hook NSObject
- (void)setValue:(id)value forKey:(NSString *)key {
    %orig;
    if ([key isEqualToString:@"message"] || [key isEqualToString:@"media"] || [key isEqualToString:@"mediaAttachments"]) {
        writeProbeLog(@"[KVC] %@ setValue forKey: %@ 触发", NSStringFromClass([self class]), key);
    }
}
%end

%ctor {
    writeProbeLog(@"--- Tweak 成功注入启动 ---");
}
