#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 探针日志工具
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args; va_start(args, format);
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

@interface _TtC19ChatMessageItemView19ChatMessageItemView : UIView
@end

// 我们只在 UI 节点加载时，把它的所有变量掏出来看一次
%hook _TtC19ChatMessageItemView19ChatMessageItemView

- (void)didMoveToWindow {
    %orig;
    static BOOL hasDumped = NO;
    if (!hasDumped && self.window) {
        hasDumped = YES;
        
        writeProbeLog(@"====== 开始探查 ChatMessageItemView 内部结构 ======");
        
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([self class], &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            const char *type = ivar_getTypeEncoding(ivar);
            NSString *nameStr = [NSString stringWithUTF8String:name];
            NSString *typeStr = [NSString stringWithUTF8String:type];
            
            writeProbeLog(@"变量名: %@ | 类型: %@", nameStr, typeStr);
            
            // 如果变量名里带 message，尝试把它的值打印出来！
            if ([nameStr localizedCaseInsensitiveContainsString:@"message"] || 
                [nameStr localizedCaseInsensitiveContainsString:@"item"] ||
                [nameStr localizedCaseInsensitiveContainsString:@"content"]) {
                
                @try {
                    id value = [self valueForKey:nameStr];
                    if (value) {
                        writeProbeLog(@"  ==> %@ 的值: %@", nameStr, [value description]);
                    }
                } @catch (NSException *e) {}
            }
        }
        free(ivars);
        writeProbeLog(@"====== 探查结束 ======");
    }
}
%end
