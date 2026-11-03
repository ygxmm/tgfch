#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明 Swift UI
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

// 日志工具
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args; va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
        NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"TurritAntiEdit.log"];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

static UIViewController* topVC() {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (!kw) kw = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *vc = kw.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

// 创建一个全局的事件处理类，确保点击绝对生效
@interface DumpHandler : NSObject
+ (instancetype)shared;
- (void)buttonClicked:(UIButton *)sender;
@end

@implementation DumpHandler
+ (instancetype)shared {
    static DumpHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DumpHandler alloc] init];
    });
    return instance;
}
- (void)buttonClicked:(UIButton *)sender {
    writeProbeLog(@"[UI] 按钮被点击了！");
    
    NSMutableString *dumpText = [NSMutableString string];
    [dumpText appendString:@"=== 正在扫描当前界面的消息状态 ===\n"];
    
    UIViewController *vc = topVC();
    [dumpText appendFormat:@"当前控制器: %@\n", NSStringFromClass([vc class])];
    
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([vc class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        NSString *nameStr = [NSString stringWithUTF8String:name];
        
        if ([nameStr localizedCaseInsensitiveContainsString:@"message"] ||
            [nameStr localizedCaseInsensitiveContainsString:@"state"] ||
            [nameStr localizedCaseInsensitiveContainsString:@"data"] ||
            [nameStr localizedCaseInsensitiveContainsString:@"media"]) {
            [dumpText appendFormat:@"变量: %@\n", nameStr];
            @try {
                id val = [vc valueForKey:nameStr];
                if (val) [dumpText appendFormat:@"值: %@\n\n", [val description]];
            } @catch (NSException *e) {}
        }
    }
    free(ivars);
    
    if (dumpText.length > 3000) {
        dumpText = (NSMutableString *)[dumpText substringToIndex:3000];
    }
    
    [AntiEditViewerController presentFrom:vc imageUrl:dumpText];
}
@end

// ==========================================
// 直接 Hook 所有的 ViewController 加载
// ==========================================
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass([self class]);
    
    // 只要类名是聊天界面，就加按钮
    if ([clsName containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) {
            if (v.tag == 44444) return;
        }
        
        writeProbeLog(@"[UI] 发现聊天界面 %@，注入按钮", clsName);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 44444;
        btn.frame = CGRectMake(20, 150, 60, 60);
        btn.backgroundColor = [UIColor redColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"扒库" forState:UIControlStateNormal];
        
        // 绑定到全局的 DumpHandler
        [btn addTarget:[DumpHandler shared] action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.view addSubview:btn];
    }
}
%end
