#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 探针日志工具
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

static NSMutableSet *editedMessageIds = nil;

// 告诉编译器 Node 其实是个 NSObject (因为我们只能通过 KVC 取值)
@interface _TtC10TelegramUI24ChatMessageBubbleItemNode : NSObject
@end

// ==========================================
// 1. 网络层拦截 (这部分你已经验证成功)
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!editedMessageIds) editedMessageIds = [NSMutableSet set];
            
            if ([desc containsString:@"updateDeleteMessages"] || [desc containsString:@"updateEditMessage"] || [desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateEditChannelMessage"]) {
                
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\bid:\\s*(\\d+)" options:0 error:nil];
                NSArray *matches = [regex matchesInString:desc options:0 range:NSMakeRange(0, desc.length)];
                for (NSTextCheckingResult *match in matches) {
                    NSString *msgId = [desc substringWithRange:[match rangeAtIndex:1]];
                    [editedMessageIds addObject:msgId];
                }
                return nil; // 阻断网络包
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. UI 层：按照 AsyncDisplayKit 规范注入
// ==========================================
%hook _TtC10TelegramUI24ChatMessageBubbleItemNode

- (void)didLoad {
    %orig;
    
    writeProbeLog(@"[UI层探针] ChatMessageBubbleItemNode 成功 didLoad！");
    
    // 1. 尝试拿到它挂载的真实 UIView
    UIView *realView = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"view")]) {
            realView = [self valueForKey:@"view"];
        }
    } @catch (NSException *e) {}
    
    if (!realView) return;
    
    // 2. 尝试拿到源码里的 item 对象，并提取 message 的 id
    id item = nil;
    NSString *msgId = nil;
    @try {
        if ([self respondsToSelector:NSSelectorFromString(@"item")]) {
            item = [self valueForKey:@"item"];
            if (item && [item respondsToSelector:NSSelectorFromString(@"content")]) {
                // content 是个数组，里面第一项的 message 是我们想要的
                NSArray *content = [item valueForKey:@"content"];
                if (content.count > 0) {
                    id firstTuple = content[0];
                    // Swift 的元组在 ObjC 里会被当作数组或字典，这里用 KVC 强行取
                    id message = nil;
                    if ([firstTuple isKindOfClass:[NSArray class]]) message = firstTuple[0];
                    
                    if (message && [message respondsToSelector:NSSelectorFromString(@"id")]) {
                        msgId = [NSString stringWithFormat:@"%@", [message valueForKey:@"id"]];
                    }
                }
            }
        }
    } @catch (NSException *e) {
        writeProbeLog(@"[UI层探针] KVC 取 item 失败: %@", e.reason);
    }
    
    if (!msgId) {
        writeProbeLog(@"[UI层探针] 无法提取 msgId，该气泡加载完成。");
        return;
    }
    
    // 3. 验证是否匹配
    if ([editedMessageIds containsObject:msgId]) {
        writeProbeLog(@"[UI层注入] 🎉 成功匹配消息 %@，正在注入 UI", msgId);
        
        // 为了不引起崩溃，我们直接把真实的 view 背景变红！而不是强行塞按钮
        dispatch_async(dispatch_get_main_queue(), ^{
            realView.layer.borderColor = [UIColor redColor].CGColor;
            realView.layer.borderWidth = 2.0;
            
            // 在右上角画个红点
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(realView.bounds.size.width - 10, 0, 10, 10)];
            dot.backgroundColor = [UIColor redColor];
            dot.layer.cornerRadius = 5;
            dot.tag = 9999;
            [realView addSubview:dot];
        });
    }
}

%end
