#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>

void popAlert(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

static void (*orig_updateMessage)(void *self, void *msgId, void *update, void *msg, void *completion);
static void (*orig_deleteMessages)(void *self, void *msgIds, void *forEachMedia);

static void hook_updateMessage(void *self, void *msgId, void *update, void *msg, void *completion) {
    popAlert(@"防编辑已触发", @"对方试图修改消息，已被拦截！");
    return; 
}

static void hook_deleteMessages(void *self, void *msgIds, void *forEachMedia) {
    popAlert(@"防撤回已触发", @"对方试图撤回消息，已被拦截！");
    return;
}

%ctor {
    @autoreleasepool {
        // 动态获取函数地址：先在全局符号表里找，找不到再尝试加载动态库
        void *addr_update = dlsym(RTLD_DEFAULT, "$s7Postbox11TransactionC13updateMessage_0C0yAA0D2IdV_AA0a6UpdateD0OAA0D0CXEtF");
        void *addr_delete = dlsym(RTLD_DEFAULT, "$s7Postbox11TransactionC14deleteMessages_12forEachMediaySayAA9MessageIdVG_yAA0G0_pcSgtF");

        // 如果全局没找到，用相对路径加载（iOS 默认支持）
        if (!addr_update || !addr_delete) {
            void *handle = dlopen("TurritCoreFramework.framework/TurritCoreFramework", RTLD_LAZY);
            if (handle) {
                if (!addr_update) addr_update = dlsym(handle, "$s7Postbox11TransactionC13updateMessage_0C0yAA0D2IdV_AA0a6UpdateD0OAA0D0CXEtF");
                if (!addr_delete) addr_delete = dlsym(handle, "$s7Postbox11TransactionC14deleteMessages_12forEachMediaySayAA9MessageIdVG_yAA0G0_pcSgtF");
            }
        }

        if (addr_update) {
            MSHookFunction(addr_update, (void *)hook_updateMessage, (void **)&orig_updateMessage);
        } else {
            NSLog(@"[TurritAntiEdit] 找不到 updateMessage 地址");
        }
        
        if (addr_delete) {
            MSHookFunction(addr_delete, (void *)hook_deleteMessages, (void **)&orig_deleteMessages);
        } else {
            NSLog(@"[TurritAntiEdit] 找不到 deleteMessages 地址");
        }
    }
}
