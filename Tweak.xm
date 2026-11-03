#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

static NSMutableDictionary *savedOldMediaDict = nil;

// ==========================================
// 核心：写日志到沙盒的辅助函数
// ==========================================
void writeDebugLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // 获取 Turrit 沙盒的 Documents 目录
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *logPath = [docPath stringByAppendingPathComponent:@"AntiEdit_Debug.log"];
    
    // 加上时间戳
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timeStr = [formatter stringFromDate:[NSDate date]];
    
    NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timeStr, message];
    
    // 追加写入文件
    FILE *file = fopen([logPath UTF8String], "a");
    if (file) {
        fprintf(file, "%s", [logLine UTF8String]);
        fclose(file);
    }
}

static UIViewController* topViewController() {
    UIWindow *keyWindow = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
#pragma clang diagnostic pop
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            id newMedia = [mediaAttachments firstObject];
            NSString *newClass = NSStringFromClass([newMedia class]);
            if ([newClass containsString:@"Image"] || [newClass containsString:@"Video"]) {
                if (!savedOldMediaDict) {
                    savedOldMediaDict = [NSMutableDictionary dictionary];
                }
                savedOldMediaDict[[NSString stringWithFormat:@"%d", self.mid]] = self.mediaAttachments;
                
                // ==========================================
                // 将调试信息写入沙盒文件
                // ==========================================
                id oldMedia = [self.mediaAttachments firstObject];
                writeDebugLog(@"=== 拦截到媒体修改 ===");
                writeDebugLog(@"旧图完整对象: %@", oldMedia);
                
                if ([oldMedia respondsToSelector:NSSelectorFromString(@"imageInfo")]) {
                    id imageInfo = [oldMedia valueForKey:@"imageInfo"];
                    writeDebugLog(@"旧图 imageInfo: %@", imageInfo);
                }
                
                return;
            }
        }
    }
    %orig(mediaAttachments);
}

%end

%hook LeadEditHistoryViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    if (a1 == YES) {
        writeDebugLog(@"=== 用户点击了编辑记录图标 ===");
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑拦截提示" message:@"图片已拦截！请去 Turrit 的 Documents 目录下查看 AntiEdit_Debug.log 获取调试信息。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [topViewController() presentViewController:alert animated:YES completion:nil];
        });
        return;
    }
    %orig(a0, a1, a2);
}
%end
