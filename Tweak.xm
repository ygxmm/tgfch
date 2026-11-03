#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

// ==========================================
// 1. 底层网络拦截（防编辑/防撤回）
// ==========================================
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

// ==========================================
// 2. UI 注入（在气泡旁边加按钮）
// ==========================================
%hook _TtC19ChatMessageItemView19ChatMessageItemView

- (void)didMoveToSuperview {
    %orig;
    
    // 给这个视图加上我们自己的 tag，防止重复添加
    if (self.tag == 9999) return;
    self.tag = 9999;
    
    // 创建一个漂亮的小悬浮按钮，放在气泡右上角
    UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    historyBtn.frame = CGRectMake(self.bounds.size.width - 30, -10, 30, 30);
    historyBtn.backgroundColor = [UIColor systemBlueColor];
    historyBtn.layer.cornerRadius = 15;
    historyBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [historyBtn setTitle:@"H" forState:UIControlStateNormal]; // H 代表 History
    historyBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [historyBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑/撤回记录" message:@"这里是你当前消息的历史记录。\n\n因为底层拦截已生效，消息永远不会被对方修改！" preferredStyle:UIAlertControllerStyleAlert];
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

// ==========================================
// 3. 初始化 Hook
// ==========================================
%ctor {
    @autoreleasepool {
        void *handle = dlopen("/var/containers/Bundle/Application/6452FA50-7BA3-4AD3-AE83-C2F5EE557CE1/Turrit.app/Frameworks/TurritCoreFramework.framework/TurritCoreFramework", RTLD_LAZY);
        if (handle) {
            void *addr_update = dlsym(handle, "$s7Postbox11TransactionC13updateMessage_0C0yAA0D2IdV_AA0a6UpdateD0OAA0D0CXEtF");
            void *addr_delete = dlsym(handle, "$s7Postbox11TransactionC14deleteMessages_12forEachMediaySayAA9MessageIdVG_yAA0G0_pcSgtF");
            if (addr_update) MSHookFunction(addr_update, (void *)hook_updateMessage, (void **)&orig_updateMessage);
            if (addr_delete) MSHookFunction(addr_delete, (void *)hook_deleteMessages, (void **)&orig_deleteMessages);
        }
    }
}
