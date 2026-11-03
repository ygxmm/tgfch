#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 获取 Turrit 沙盒的 Documents 目录并写入
void writeToSandbox(NSString *text) {
    @try {
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Dump.txt"];
        
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) {
            [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [file seekToEndOfFile];
            [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
            [file closeFile];
        }
    } @catch (NSException *e) {}
}

// 扫雷函数：遍历所有加载的类
void dumpClassesAndMethods() {
    writeToSandbox(@"\n\n====== 开始扫描 Runtime 中的类 ======\n");
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    
    int foundCount = 0;
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        const char *name = class_getName(cls);
        NSString *clsName = [NSString stringWithUTF8String:name];
        
        // 过滤核心关键词
        if ([clsName localizedCaseInsensitiveContainsString:@"Message"] ||
            [clsName localizedCaseInsensitiveContainsString:@"Edit"] ||
            [clsName localizedCaseInsensitiveContainsString:@"Media"] ||
            [clsName localizedCaseInsensitiveContainsString:@"Postbox"] ||
            [clsName localizedCaseInsensitiveContainsString:@"Update"]) {
            
            NSMutableString *classInfo = [NSMutableString string];
            [classInfo appendFormat:@"\n[类] %@\n", clsName];
            
            // 扫方法
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(cls, &methodCount);
            for (unsigned int j = 0; j < methodCount; j++) {
                SEL selector = method_getName(methods[j]);
                NSString *methodName = NSStringFromSelector(selector);
                
                // 过滤关键字方法
                if ([methodName localizedCaseInsensitiveContainsString:@"set"] ||
                    [methodName localizedCaseInsensitiveContainsString:@"update"] ||
                    [methodName localizedCaseInsensitiveContainsString:@"edit"] ||
                    [methodName localizedCaseInsensitiveContainsString:@"media"] ||
                    [methodName localizedCaseInsensitiveContainsString:@"text"] ||
                    [methodName localizedCaseInsensitiveContainsString:@"init"]) {
                    [classInfo appendFormat:@"  - %@\n", methodName];
                }
            }
            free(methods);
            
            if (classInfo.length > 50) {
                writeToSandbox(classInfo);
                foundCount++;
            }
        }
    }
    free(classes);
    writeToSandbox([NSString stringWithFormat:@"\n====== 扫描结束，共找到 %d 个相关类 ======\n", foundCount]);
}

@interface DumpHandler : NSObject
+ (instancetype)shared;
- (void)doDump:(UIButton *)sender;
@end

@implementation DumpHandler
+ (instancetype)shared {
    static DumpHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[DumpHandler alloc] init]; });
    return instance;
}
- (void)doDump:(UIButton *)sender {
    // 重置沙盒里的文件
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Dump.txt"];
    [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dumpClassesAndMethods();
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取成功" message:@"数据已写入 Turrit 沙盒的 Documents 目录，请用 Filza 查看：\nTurrit_Dump.txt" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
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
        for (UIView *v in self.view.subviews) { if (v.tag == 88888) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 88888;
        btn.frame = CGRectMake(20, 100, 70, 70);
        btn.backgroundColor = [UIColor systemBlueColor];
        btn.layer.cornerRadius = 35;
        [btn setTitle:@"提取" forState:UIControlStateNormal];
        [btn addTarget:[DumpHandler shared] action:@selector(doDump:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
%end
