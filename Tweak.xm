#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 核心：安全写入日志到 App 自身的沙盒 Documents 目录
// ==========================================
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"TurritAntiEdit.log"];
        
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
    } @catch (NSException *e) {}
}

// ==========================================
// 探针：全量扫描 Turrit 真实的类名
// ==========================================
%ctor {
    @autoreleasepool {
        writeProbeLog(@"--- 开始扫描真实类名 ---");
        
        int numClasses = objc_getClassList(NULL, 0);
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        int count = 0;
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            const char *name = class_getName(cls);
            if (name) {
                NSString *clsName = [NSString stringWithUTF8String:name];
                // 只要名字里带这些关键字的，全抓出来！
                if ([clsName containsString:@"Serialization"] ||
                    [clsName containsString:@"Message"] ||
                    [clsName containsString:@"Update"] ||
                    [clsName containsString:@"Media"]) {
                    writeProbeLog(@"真实类名: %@", clsName);
                    count++;
                    if (count > 500) break; // 限制数量防崩溃
                }
            }
        }
        free(classes);
        writeProbeLog(@"--- 扫描结束，共找到 %d 个相关类 ---", count);
    }
}
