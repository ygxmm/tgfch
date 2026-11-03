#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

// 探针 1: 监测所有视图控制器的加载 (找 UI 切入点)
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    // 只要类名带 Chat 或 Edit 或 Media，就记录下来
    if ([cls containsString:@"Chat"] || [cls containsString:@"Edit"] || [cls containsString:@"Media"] || [cls containsString:@"Turrit"]) {
        writeProbeLog(@"[UI] 发现类加载: %@", cls);
    }
}
%end

// 探针 2: 监测 TLParser (Lead 曾经利用的核心类)
@interface TLParser : NSObject
+ (id)handleResponse:(id)a0 functionID:(id)a1;
+ (id)getMessageTextFromNode:(id)a0;
+ (id)getDebugDumpFromNode:(id)a0;
@end

%hook TLParser
+ (id)handleResponse:(id)a0 functionID:(id)a1 {
    writeProbeLog(@"[TLParser] 收到网络响应! functionID: %@", a1);
    return %orig;
}
+ (id)getMessageTextFromNode:(id)a0 {
    writeProbeLog(@"[TLParser] 获取消息文本节点");
    return %orig;
}
+ (id)getDebugDumpFromNode:(id)a0 {
    writeProbeLog(@"[TLParser] 调试节点被调用");
    return %orig;
}
%end

// 探针 3: 网络接收底层 (MtProtoKit)
@interface MTProtoKit_MtProto : NSObject
- (void)setMessageService:(id)a0;
@end
%hook MTProtoKit_MtProto
- (void)setMessageService:(id)a0 {
    writeProbeLog(@"[网络] MTProto 服务注册: %@", NSStringFromClass([a0 class]));
    %orig;
}
%end

// 探针 4: 数据库写入 (SQLite)
%hook NSFileManager
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary *)attr {
    if ([path containsString:@"postbox"] || [path containsString:@"database"] || [path containsString:@"db"]) {
        writeProbeLog(@"[数据库] 试图写入文件: %@", path);
    }
    return %orig;
}
%end
