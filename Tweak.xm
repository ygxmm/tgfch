#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 写日志到沙盒
void logToSandbox(NSString *text) {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Capture.txt"];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
    else { [file seekToEndOfFile]; [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
}

// ==========================================
// 1. 拦截 NSData 写入（抓取新图缓存）
// ==========================================
%hook NSData
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    // 如果写入的数据很大（超过 50KB），大概率是图片或视频
    if (self.length > 50000) {
        // 如果路径里包含 Cache 或 Media
        if ([path containsString:@"Cache"] || [path containsString:@"Media"] || [path containsString:@"Telegram"]) {
            logToSandbox([NSString stringWithFormat:@"\n[写入大文件] %@\n大小: %lu 字节\n", path, (unsigned long)self.length]);
        }
    }
    return %orig;
}
%end

// ==========================================
// 2. 拦截 UIImage 生成（抓取内存中的图片）
// ==========================================
%hook UIImage
+ (UIImage *)imageWithContentsOfFile:(NSString *)path {
    UIImage *img = %orig;
    if (img) {
        logToSandbox([NSString stringWithFormat:@"[读取本地图片] %@\n", path]);
    }
    return img;
}

+ (UIImage *)imageWithData:(NSData *)data {
    UIImage *img = %orig;
    if (img && data.length > 50000) {
        logToSandbox([NSString stringWithFormat:@"[从内存生成大图] 大小: %lu\n", (unsigned long)data.length]);
    }
    return img;
}
%end

// ==========================================
// 3. 在 UI 界面加一个看日志的按钮
// ==========================================
@interface CaptureHandler : NSObject
+ (instancetype)shared;
- (void)showLog:(UIButton *)sender;
@end

@implementation CaptureHandler
+ (instancetype)shared {
    static CaptureHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[CaptureHandler alloc] init]; });
    return instance;
}
- (void)showLog:(UIButton *)sender {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Capture.txt"];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content || content.length == 0) content = @"还没有抓到任何数据，请让对方发张图试试。";
    
    if (content.length > 1500) content = [content substringFromIndex:content.length - 1500];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"抓包结果(最新)" message:content preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        
        UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 55555) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 55555;
        btn.frame = CGRectMake(20, 250, 60, 60);
        btn.backgroundColor = [UIColor redColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"抓图" forState:UIControlStateNormal];
        [btn addTarget:[CaptureHandler shared] action:@selector(showLog:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
%end
