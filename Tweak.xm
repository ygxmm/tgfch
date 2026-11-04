#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 全局字典：缓存所有收到过的消息 { 消息ID : 消息内容 }
static NSMutableDictionary *messageCache = nil;
// 全局字典：记录被编辑/撤回的消息历史 { 消息ID : @[旧内容, 新内容] }
static NSMutableDictionary *editHistory = nil;

static UIButton *floatBtn = nil;
static int interceptedCount = 0;

// 弹窗提示
void showInterceptToast(NSString *type) {
    dispatch_async(dispatch_get_main_queue(), ^{
        interceptedCount++;
        if (floatBtn) {
            [floatBtn setTitle:[NSString stringWithFormat:@"拦截\n%d", interceptedCount] forState:UIControlStateNormal];
            floatBtn.backgroundColor = [UIColor systemRedColor];
        }
        
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:type message:@"已成功拦截，点击悬浮球查看历史记录！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

// 提取 ID 和文本的辅助函数
void processMessage(NSString *desc, BOOL isEdit) {
    if (!messageCache) messageCache = [NSMutableDictionary dictionary];
    if (!editHistory) editHistory = [NSMutableDictionary dictionary];
    
    // 简单正则提取 ID
    NSRegularExpression *idRegex = [NSRegularExpression regularExpressionWithPattern:@"\\bid:\\s*(\\d+)" options:0 error:nil];
    NSTextCheckingResult *idMatch = [idRegex firstMatchInString:desc options:0 range:NSMakeRange(0, desc.length)];
    if (!idMatch) return;
    NSString *msgId = [desc substringWithRange:[idMatch rangeAtIndex:1]];
    
    // 提取文本 (尽量兼容各种格式)
    NSString *text = @"(图片或特殊媒体)";
    NSRange textRange = [desc rangeOfString:@"message: "];
    if (textRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:textRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@", media:"];
        if (parts.count > 0) {
            text = [parts[0] stringByReplacingOccurrencesOfString:@"message: " withString:@""];
        }
    }
    
    if (isEdit) {
        // 如果发生了编辑/撤回
        NSString *oldText = messageCache[msgId] ?: @"(本地未缓存到原文)";
        NSMutableArray *history = editHistory[msgId];
        if (!history) {
            history = [NSMutableArray array];
            editHistory[msgId] = history;
        }
        [history addObject:@{@"old": oldText, @"new": text}];
        messageCache[msgId] = text; // 更新当前
    } else {
        // 如果是新消息，直接存入缓存
        messageCache[msgId] = text;
    }
}

%hook _TtC12TelegramCore13Serialization

- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    if (result) {
        @try {
            NSString *desc = [result description];
            
            // 1. 抓取新消息作为“原文”
            if ([desc containsString:@"updateNewMessage"] || [desc containsString:@"updateNewChannelMessage"]) {
                processMessage(desc, NO);
            }
            
            // 2. 拦截撤回
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateDeleteChannelMessages"]) {
                processMessage(desc, YES);
                showInterceptToast(@"防撤回成功");
                return nil; // 阻断网络包，消息不消失
            }
            
            // 3. 拦截编辑
            if ([desc containsString:@"updateEditMessage"] || [desc containsString:@"updateEditChannelMessage"]) {
                processMessage(desc, YES);
                showInterceptToast(@"防编辑成功");
                return nil; // 阻断网络包，内容不改变
            }
            
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// 注入悬浮球（用于查看历史）
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (floatBtn) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        
        floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.frame = CGRectMake(window.bounds.size.width - 75, window.bounds.size.height / 2, 60, 60);
        floatBtn.backgroundColor = [UIColor systemGreenColor];
        floatBtn.layer.cornerRadius = 30;
        floatBtn.titleLabel.numberOfLines = 2;
        floatBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
        [floatBtn setTitle:@"监控中" forState:UIControlStateNormal];
        floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        
        [floatBtn addAction:[UIAction handler:^(UIAction *action) {
            if (!editHistory || editHistory.count == 0) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"暂无记录" message:@"当前没有被拦截的消息。" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [window.rootViewController presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            // 拼接展示历史记录
            NSMutableString *log = [NSMutableString string];
            for (NSString *msgId in editHistory) {
                [log appendFormat:@"🔔 消息ID: %@\n", msgId];
                NSArray *records = editHistory[msgId];
                for (NSDictionary *record in records) {
                    [log appendFormat:@"  原文: %@\n  修改: %@\n\n", record[@"old"], record[@"new"]];
                }
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"拦截历史记录" message:log preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [editHistory removeAllObjects];
                interceptedCount = 0;
                [floatBtn setTitle:@"监控中" forState:UIControlStateNormal];
                floatBtn.backgroundColor = [UIColor systemGreenColor];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        }] forControlEvents:UIControlEventTouchUpInside];
        
        [window.rootViewController.view addSubview:floatBtn];
    });
}
%end
