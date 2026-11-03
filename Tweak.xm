#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明我们自己的 Swift 界面
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

// 核心修复：明确告诉编译器，它继承自 UIViewController
@interface TelegramUI_ChatControllerImpl : UIViewController
- (void)viewDidLoad;
- (void)probeButtonClicked;
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

// 我们直接在聊天界面控制器里下钩子！
%hook TelegramUI_ChatControllerImpl

- (void)viewDidLoad {
    %orig;
    writeProbeLog(@"[UI] ChatControllerImpl viewDidLoad 触发！准备注入悬浮按钮");
    
    // 防止重复添加悬浮按钮
    for (UIView *v in self.view.subviews) {
        if (v.tag == 99999) return;
    }
    
    // 在屏幕右下角注入一个悬浮按钮
    UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatBtn.tag = 99999;
    floatBtn.frame = CGRectMake(self.view.bounds.size.width - 80, self.view.bounds.size.height - 200, 60, 60);
    floatBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8];
    floatBtn.layer.cornerRadius = 30;
    floatBtn.layer.masksToBounds = YES;
    [floatBtn setTitle:@"探针" forState:UIControlStateNormal];
    [floatBtn addTarget:self action:@selector(probeButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:floatBtn];
}

// 点击悬浮按钮时，把我们发现的内部属性全部通过 Swift 界面展示出来！
- (void)probeButtonClicked {
    NSMutableString *dumpText = [NSMutableString string];
    [dumpText appendString:@"=== ChatControllerImpl 属性探针 ===\n"];
    
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        NSString *nameStr = [NSString stringWithUTF8String:name];
        
        // 过滤出包含 message 或 history 或 state 的属性
        if ([nameStr containsString:@"message"] || [nameStr containsString:@"history"] || [nameStr containsString:@"state"]) {
            [dumpText appendFormat:@"变量: %@\n", nameStr];
            @try {
                id val = [self valueForKey:nameStr];
                if (val) [dumpText appendFormat:@"值: %@\n\n", val];
            } @catch (NSException *e) {}
        }
    }
    free(ivars);
    
    if (dumpText.length > 2000) {
        dumpText = (NSMutableString *)[dumpText substringToIndex:2000];
    }
    
    // 强行调用我们之前写的 Swift 界面，展示属性
    [AntiEditViewerController presentFrom:self imageUrl:dumpText];
}

%end
