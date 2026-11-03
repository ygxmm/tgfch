#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 核心修复：告诉编译器，这个纯 Swift 类继承自 UIView
@interface _TtC19ChatMessageItemView19ChatMessageItemView : UIView
@end

// 存储被修改或撤回的消息 ID
static NSMutableSet *editedMessageIds = nil;

// ==========================================
// 1. 网络层：精准捕获 ID
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!editedMessageIds) editedMessageIds = [NSMutableSet set];
            
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
                
                // 抓取 id: 12345 或 messages: [123, 456]
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d{3,10}\\b" options:0 error:nil];
                NSArray *matches = [regex matchesInString:desc options:0 range:NSMakeRange(0, desc.length)];
                for (NSTextCheckingResult *match in matches) {
                    NSString *msgId = [desc substringWithRange:match.range];
                    [editedMessageIds addObject:msgId];
                }
                return nil; // 丢弃包，底层数据不变
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. UI 层：在气泡上方强行贴按钮（带防复用清理）
// ==========================================
%hook _TtC19ChatMessageItemView19ChatMessageItemView

- (void)layoutSubviews {
    %orig;
    
    // 1. 防复用：每次布局前，先把可能残留的旧按钮删掉
    UIView *oldBtn = [self viewWithTag:88888];
    if (oldBtn) [oldBtn removeFromSuperview];
    
    // 2. 尝试拿到当前气泡绑定的消息对象
    id message = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"message")]) {
            message = [self valueForKey:@"message"];
        } else if ([self respondsToSelector:NSSelectorFromString(@"item")]) {
            message = [self valueForKey:@"item"];
        }
    } @catch (NSException *e) {}
    
    if (!message) return;
    
    // 3. 提取消息 ID
    NSString *msgId = nil;
    @try {
        // 往往在 message.id 或 message.mid 里
        if ([message respondsToSelector:NSSelectorFromString(@"id")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"id"]];
        } else if ([message respondsToSelector:NSSelectorFromString(@"mid")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"mid"]];
        }
    } @catch (NSException *e) {}
    
    if (!msgId) return;
    
    // 4. 判断这条消息是否被拦截过
    if ([editedMessageIds containsObject:msgId]) {
        UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        historyBtn.tag = 88888;
        [historyBtn setTitle:@"✏️" forState:UIControlStateNormal]; // 用铅笔 Emoji 更还原
        historyBtn.titleLabel.font = [UIFont systemFontOfSize:10];
        historyBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        historyBtn.layer.cornerRadius = 10;
        [historyBtn addTarget:self action:@selector(showHistoryAlert) forControlEvents:UIControlEventTouchUpInside];
        
        // 强行贴在气泡右上角
        historyBtn.frame = CGRectMake(self.bounds.size.width - 25, 5, 20, 20);
        [self addSubview:historyBtn];
        [self bringSubviewToFront:historyBtn];
    }
}

- (void)showHistoryAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"拦截记录" message:@"对方试图修改或撤回这条消息，已被拦截！原内容已保留。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%end
