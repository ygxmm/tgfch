#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 探针日志工具：直接写入沙盒 Documents 目录
// ==========================================
void writeProbeLog(NSString *format, ...) {
    @try {
        va_list args; va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"TurritAntiEdit.log"];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *timeStr = [formatter stringFromDate:[NSDate date]];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timeStr, msg];
        
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

// 存储被修改或撤回的消息 ID
static NSMutableSet *editedMessageIds = nil;

// 告诉编译器它是 UIView
@interface _TtC19ChatMessageItemView19ChatMessageItemView : UIView
@end

// ==========================================
// 1. 网络层拦截（对应官方 UpdateGroup.swift 逻辑）
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!editedMessageIds) editedMessageIds = [NSMutableSet set];
            
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
                
                writeProbeLog(@"[网络层拦截] 捕获到编辑/撤回指令。");
                
                // 抓取可能的消息 ID
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\bid:\\s*(\\d+)" options:0 error:nil];
                NSArray *matches = [regex matchesInString:desc options:0 range:NSMakeRange(0, desc.length)];
                for (NSTextCheckingResult *match in matches) {
                    NSString *msgId = [desc substringWithRange:[match rangeAtIndex:1]];
                    [editedMessageIds addObject:msgId];
                    writeProbeLog(@"[网络层拦截] 记录了消息 ID: %@", msgId);
                }
                
                return nil; // 丢弃数据包
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. UI 层探针（对应官方 ChatMessageItemView）
// ==========================================
%hook _TtC19ChatMessageItemView19ChatMessageItemView

- (void)layoutSubviews {
    %orig;
    
    // 防复用：先删掉旧按钮
    UIView *oldBtn = [self viewWithTag:88888];
    if (oldBtn) [oldBtn removeFromSuperview];
    
    // 尝试获取底层的 message 对象
    id message = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"message")]) {
            message = [self valueForKey:@"message"];
        }
    } @catch (NSException *e) {}
    
    if (!message) return;
    
    // 提取消息 ID
    NSString *msgId = nil;
    @try {
        if ([message respondsToSelector:NSSelectorFromString(@"id")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"id"]];
        } else if ([message respondsToSelector:NSSelectorFromString(@"mid")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"mid"]];
        }
    } @catch (NSException *e) {}
    
    if (!msgId) return;
    
    // 只要触发了布局，就写一次日志（防止刷屏，可以加个判断）
    // writeProbeLog(@"[UI层探针] 布局消息 ID: %@", msgId);
    
    // 如果消息被拦截过，显示按钮
    if ([editedMessageIds containsObject:msgId]) {
        writeProbeLog(@"[UI层注入] 找到目标消息 %@，尝试注入按钮", msgId);
        
        UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        historyBtn.tag = 88888;
        [historyBtn setTitle:@"✏️" forState:UIControlStateNormal];
        historyBtn.titleLabel.font = [UIFont systemFontOfSize:10];
        historyBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        historyBtn.layer.cornerRadius = 10;
        [historyBtn addTarget:self action:@selector(showHistoryAlert) forControlEvents:UIControlEventTouchUpInside];
        
        historyBtn.frame = CGRectMake(self.bounds.size.width - 25, 5, 20, 20);
        [self addSubview:historyBtn];
        [self bringSubviewToFront:historyBtn];
    }
}

- (void)showHistoryAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"拦截记录" message:@"对方试图修改或撤回这条消息，已被拦截！" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%end
