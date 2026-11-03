#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 存储被编辑或撤回的消息 ID
static NSMutableSet *editedMessageIds = nil;

// ==========================================
// 1. 网络层：拦截并记录 ID
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!editedMessageIds) editedMessageIds = [NSMutableSet set];
            
            // 如果是撤回或编辑指令
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
                
                // 简单提取 ID 记录到集合中
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"id:\\s*(\\d+)" options:0 error:nil];
                NSArray *matches = [regex matchesInString:desc options:0 range:NSMakeRange(0, desc.length)];
                for (NSTextCheckingResult *match in matches) {
                    NSString *msgId = [desc substringWithRange:[match rangeAtIndex:1]];
                    [editedMessageIds addObject:msgId];
                }
                
                return nil; // 阻断网络包，消息内容不变
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. UI层：在气泡旁边强行贴按钮
// ==========================================
// 注意：类名是你在 dump 里找出来的真实 Swift 类名
%hook _TtC19ChatMessageItemView19ChatMessageItemView

// 拦截视图布局阶段，这是注入 UI 最安全的时机
- (void)layoutSubviews {
    %orig;
    
    // 1. 尝试通过 KVC 获取这个气泡对应的消息对象
    // Turrit 通常会有 message 或 item 属性
    id message = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"message")]) {
            message = [self valueForKey:@"message"];
        } else if ([self respondsToSelector:NSSelectorFromString(@"item")]) {
            message = [self valueForKey:@"item"];
        }
    } @catch (NSException *e) {}
    
    if (!message) return;
    
    // 2. 提取消息 ID (通常是 mid 或 id)
    NSString *msgId = nil;
    @try {
        if ([message respondsToSelector:NSSelectorFromString(@"id")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"id"]];
        }
    } @catch (NSException *e) {}
    
    if (!msgId) return;
    
    // 3. 判断这条消息是不是被修改过
    if ([editedMessageIds containsObject:msgId]) {
        // 找找有没有加过按钮，没有就加
        UIView *btn = [self viewWithTag:88888];
        if (!btn) {
            UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            historyBtn.tag = 88888;
            [historyBtn setTitle:@"笔" forState:UIControlStateNormal];
            historyBtn.titleLabel.font = [UIFont systemFontOfSize:10];
            historyBtn.backgroundColor = [UIColor systemOrangeColor];
            historyBtn.layer.cornerRadius = 8;
            [historyBtn addTarget:self action:@selector(showHistoryAlert) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:historyBtn];
            btn = historyBtn;
        }
        
        // 强行把它放在右上角 (根据气泡边界计算)
        btn.frame = CGRectMake(self.bounds.size.width - 20, -5, 20, 20);
        [self bringSubviewToFront:btn];
        
    } else {
        // 如果未被修改，确保按钮不显示
        UIView *btn = [self viewWithTag:88888];
        if (btn) [btn removeFromSuperview];
    }
}

- (void)showHistoryAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑记录" message:@"对方修改了这条消息，但已被拦截，保留了原文。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%end
