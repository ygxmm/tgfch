#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

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

@interface DumpHandler : NSObject
+ (instancetype)shared;
- (void)buttonClicked:(UIButton *)sender;
@end

@implementation DumpHandler
+ (instancetype)shared {
    static DumpHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[DumpHandler alloc] init]; });
    return instance;
}
- (void)buttonClicked:(UIButton *)sender {
    NSMutableString *dumpText = [NSMutableString string];
    [dumpText appendString:@"=== 当前界面的所有变量 ===\n"];
    
    UIViewController *vc = topVC();
    [dumpText appendFormat:@"控制器: %@\n\n", NSStringFromClass([vc class])];
    
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([vc class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        NSString *nameStr = [NSString stringWithUTF8String:name];
        
        [dumpText appendFormat:@"变量: %@\n", nameStr];
        @try {
            id val = [vc valueForKey:nameStr];
            if (val) {
                NSString *desc = [val description];
                if (desc.length > 150) desc = [desc substringToIndex:150];
                [dumpText appendFormat:@"  值: %@\n\n", desc];
            }
        } @catch (NSException *e) {
            [dumpText appendFormat:@"  值: (无法读取)\n\n"];
        }
    }
    free(ivars);
    
    if (dumpText.length > 8000) {
        dumpText = (NSMutableString *)[dumpText substringToIndex:8000];
    }
    
    writeProbeLog(@"[UI] 准备弹出数据，长度: %lu", (unsigned long)dumpText.length);
    [AntiEditViewerController presentFrom:vc imageUrl:dumpText];
}
@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass([self class]);
    if ([clsName containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 44444) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 44444;
        btn.frame = CGRectMake(20, 150, 60, 60);
        btn.backgroundColor = [UIColor redColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"扒库" forState:UIControlStateNormal];
        [btn addTarget:[DumpHandler shared] action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
%end
