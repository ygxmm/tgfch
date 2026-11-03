#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 写日志到沙盒
void logPacket(NSString *text) {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Unboxed.txt"];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
    else { [file seekToEndOfFile]; [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
}

// 拦截解析器
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    if (result) {
        NSString *clsName = NSStringFromClass([result class]);
        
        // 只有当结果是 BoxedMessage 时，我们才去拆包
        if ([clsName containsString:@"BoxedMessage"]) {
            // 暴力提取 BoxedMessage 里的真实数据
            @try {
                unsigned int count = 0;
                Ivar *ivars = class_copyIvarList([result class], &count);
                for (unsigned int i = 0; i < count; i++) {
                    Ivar ivar = ivars[i];
                    const char *name = ivar_getName(ivar);
                    NSString *nameStr = [NSString stringWithUTF8String:name];
                    
                    // 寻找真正的消息体
                    if ([nameStr isEqualToString:@"body"] || [nameStr containsString:@"message"] || [nameStr containsString:@"update"]) {
                        id innerValue = object_getIvar(result, ivar);
                        if (innerValue) {
                            NSString *innerCls = NSStringFromClass([innerValue class]);
                            
                            // 如果是编辑、撤回相关的类，记录下它的所有信息！
                            if ([innerCls containsString:@"Edit"] || [innerCls containsString:@"Delete"] || [innerCls containsString:@"Update"]) {
                                logPacket([NSString stringWithFormat:@"\n=======================\n[拦截到关键包!]\n外层壳子: %@\n内层真实类名: %@\n具体内容: %@\n", clsName, innerCls, innerValue]);
                            }
                        }
                    }
                }
                free(ivars);
            } @catch (NSException *e) {
                logPacket([NSString stringWithFormat:@"拆包崩溃: %@", e]);
            }
        }
    }
    
    return result;
}
%end

// 注入一个提醒按钮
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 33333) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 33333;
        btn.frame = CGRectMake(20, 100, 60, 60);
        btn.backgroundColor = [UIColor systemRedColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"拆包" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(showTip) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
- (void)showTip {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"正在拆包" message:@"请去沙盒 Documents/Turrit_Unboxed.txt 查看抓到的数据。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
