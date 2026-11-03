#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>

// 【关键修复】手动声明这个 Swift 类继承自 UIView，骗过编译器
@interface _TtC19ChatMessageItemView19ChatMessageItemView : UIView
@end

// 声明底层事务函数
static void (*orig_updateMessage)(void *self, void *msgId, void *update, void *msg, void *completion);
static void (*orig_deleteMessages)(void *self, void *msgIds, void *forEachMedia);

static void hook_updateMessage(void *self, void *msgId, void *update, void *msg, void *completion) {
    NSLog(@"[TurritAntiEdit] 拦截底层编辑");
    return;
}
static void hook_deleteMessages(void *self, void *msgIds, void *forEachMedia) {
    NSLog(@"[TurritAntiEdit] 拦截底层撤回");
    return;
}

%hook _TtC19ChatMessageItemView19ChatMessageItemView

- (void)didMoveToSuperview {
    %orig;
    
    if (self.tag == 9999) return;
    self.tag = 9999;
    
    UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    // 放在右上角
    historyBtn.frame = CGRectMake(self.bounds.size.width - 30, -10, 30, 30);
    historyBtn.backgroundColor = [UIColor systemBlueColor];
    historyBtn.layer.cornerRadius = 15;
    historyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [historyBtn setTitle:@"H" forState:UIControlStateNormal];
    historyBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [historyBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑/撤回记录" message:@"因为底层拦截已生效，消息永远不会被对方修改。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        [topVC presentViewController:alert animated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:historyBtn];
}

%end

%ctor {
    @autoreleasepool {
        // 直接通过框架名称加载，不写死 UUID 路径
        void *handle = dlopen("TurritCoreFramework", RTLD_LAZY);
        if (handle) {
            void *addr_update = dlsym(handle, "$s7Postbox11TransactionC13updateMessage_0C0yAA0D2IdV_AA0a6UpdateD0OAA0D0CXEtF");
            void *addr_delete = dlsym(handle, "$s7Postbox11TransactionC14deleteMessages_12forEachMediaySayAA9MessageIdVG_yAA0G0_pcSgtF");
            if (addr_update) MSHookFunction(addr_update, (void *)hook_updateMessage, (void **)&orig_updateMessage);
            if (addr_delete) MSHookFunction(addr_delete, (void *)hook_deleteMessages, (void **)&orig_deleteMessages);
        } else {
            NSLog(@"[TurritAntiEdit] dlopen 失败");
        }
    }
}
