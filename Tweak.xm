#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 探针日志工具：写入 App 沙盒 Documents 目录
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

// 存储被拦截的消息 ID
static NSMutableSet *editedMessageIds = nil;

// 官方源码证实，气泡真正的渲染容器为 ChatMessageBubbleItemNode
@interface _TtC10TelegramUI24ChatMessageBubbleItemNode : UIView
@end

// ==========================================
// 1. 网络层：提取并记录编辑/撤回的 ID
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!editedMessageIds) editedMessageIds = [NSMutableSet set];
            
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
                
                // 通过特征字符串定位真实的消息 id (MessageId)
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\bid:\\s*(\\d+)" options:0 error:nil];
                NSArray *matches = [regex matchesInString:desc options:0 range:NSMakeRange(0, desc.length)];
                for (NSTextCheckingResult *match in matches) {
                    NSString *msgId = [desc substringWithRange:[match rangeAtIndex:1]];
                    [editedMessageIds addObject:msgId];
                    writeProbeLog(@"[网络层拦截] 记录了目标消息 ID: %@", msgId);
                }
                return nil; // 直接阻断网络包，不写入底层数据库
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. UI 层：在真实气泡节点布局时注入标志
// ==========================================
%hook _TtC10TelegramUI24ChatMessageBubbleItemNode

- (void)layoutSubviews {
    %orig;
    
    // 防复用：每次布局前先移除旧状态
    UIView *oldBtn = [self viewWithTag:88888];
    if (oldBtn) [oldBtn removeFromSuperview];
    
    // 按照官方架构提取绑定的 message 模型
    id message = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"message")]) {
            message = [self valueForKey:@"message"];
        }
    } @catch (NSException *e) {}
    
    if (!message) return;
    
    // 从 Message 模型中取出 id 字段
    NSString *msgId = nil;
    @try {
        if ([message respondsToSelector:NSSelectorFromString(@"id")]) {
            msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"id"]];
        }
    } @catch (NSException *e) {}
    
    if (!msgId) return;
    
    // 写一次日志，验证当前气泡的 ID 是否与网络层拦截到的 ID 对应
    writeProbeLog(@"[UI层探针] 正在渲染气泡 ID: %@", msgId);
    
    if ([editedMessageIds containsObject:msgId]) {
        writeProbeLog(@"[UI层注入] 匹配成功！为消息 %@ 注入防修改图标", msgId);
        
        UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        historyBtn.tag = 88888;
        [historyBtn setTitle:@"✏️" forState:UIControlStateNormal];
        historyBtn.titleLabel.font = [UIFont systemFontOfSize:10];
        historyBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        historyBtn.layer.cornerRadius = 10;
        [historyBtn addTarget:self action:@selector(showHistoryAlert) forControlEvents:UIControlEventTouchUpInside];
        
        historyBtn.frame = CGRectMake(self.bounds.size.width - 25, 5, 20, 20);
        [self addSubview:historyBtn];
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
