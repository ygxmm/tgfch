#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 核心：安全写入日志到 /var/mobile/Documents/
// ==========================================
void writeProbeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *path = @"/var/mobile/Documents/TurritAntiEdit.log";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timeStr = [formatter stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timeStr, msg];
    
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
}

// ==========================================
// 1. 探针：底层网络更新接收 (MtProtoKit)
// ==========================================
@interface _TtC12TelegramCoreP33_C08D30065300083FB7E5BAE4ADF7A07627MtProtoKitUpdateSinkService : NSObject
- (void)mtProto:(id)a0 receivedMessage:(id)a1 authInfoSelector:(long long)a2 networkType:(int)a3;
@end

%hook _TtC12TelegramCoreP33_C08D30065300083FB7E5BAE4ADF7A07627MtProtoKitUpdateSinkService
- (void)mtProto:(id)a0 receivedMessage:(id)a1 authInfoSelector:(long long)a2 networkType:(int)a3 {
    NSString *className = NSStringFromClass([a1 class]);
    if ([className containsString:@"Update"] || [className containsString:@"Edit"]) {
        writeProbeLog(@"[网络层] 收到更新包: %@", className);
    }
    %orig;
}
%end

// ==========================================
// 2. 探针：消息解析入口 (带真实 Swift 名字)
// ==========================================
@interface _TtC12TelegramCore13Serialization : NSObject
- (id)parseMessage:(id)a0;
@end
@interface TelegramCore_Serialization : NSObject
- (id)parseMessage:(id)a0;
@end

%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id res = %orig;
    NSString *className = NSStringFromClass([res class]);
    if ([className containsString:@"Edit"]) {
        writeProbeLog(@"[解析层-Swift] 解析出编辑包: %@", className);
    }
    return res;
}
%end

%hook TelegramCore_Serialization
- (id)parseMessage:(id)a0 {
    id res = %orig;
    NSString *className = NSStringFromClass([res class]);
    if ([className containsString:@"Edit"]) {
        writeProbeLog(@"[解析层-ObjC] 解析出编辑包: %@", className);
    }
    return res;
}
%end

// ==========================================
// 3. 探针：UI层媒体节点加载
// ==========================================
@interface ChatMessageInteractiveMediaNode_ChatMessageInteractiveMediaNode : NSObject
- (void)didLoad;
@end

%hook ChatMessageInteractiveMediaNode_ChatMessageInteractiveMediaNode
- (void)didLoad {
    %orig;
    @try {
        id msg = [self valueForKey:@"message"];
        if (msg) {
            writeProbeLog(@"[UI层] 节点加载，包含消息对象: %@", NSStringFromClass([msg class]));
        }
    } @catch (NSException *e) {}
}
%end

// ==========================================
// 4. 探针：全局检查 (注意这里不需要 %end)
// ==========================================
%ctor {
    writeProbeLog(@"--- Tweak 成功注入启动 ---");
    if (NSClassFromString(@"LeadAntiRevokeUpdater")) {
        writeProbeLog(@"检测到原生 Lead 插件仍存在");
    } else {
        writeProbeLog(@"未检测到 Lead 插件，纯独立模式");
    }
}
