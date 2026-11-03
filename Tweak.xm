#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

void logPacket(NSString *text) {
    @try {
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Safe.txt"];
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
        else { [file seekToEndOfFile]; [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
    } @catch (NSException *e) {}
}

%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    // 放到后台线程处理日志，绝不卡主线程
    if (result) {
        @try {
            NSString *clsName = NSStringFromClass([result class]);
            if ([clsName containsString:@"BoxedMessage"]) {
                // 安全获取 Swift 对象的内部字符串描述
                NSString *desc = [result description];
                
                // 如果描述里包含 Edit 相关的词，记录下来
                if ([desc containsString:@"Edit"] || [desc containsString:@"Delete"] || desc.length > 100) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        logPacket([NSString stringWithFormat:@"\n[抓到包] 类名: %@\n描述: %@\n", clsName, desc]);
                    });
                }
            }
        } @catch (NSException *e) {}
    }
    
    return result;
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 33333) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 33333;
        btn.frame = CGRectMake(20, 100, 60, 60);
        btn.backgroundColor = [UIColor systemGreenColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"安全抓包" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(showTip) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}
- (void)showTip {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"安全抓包运行中" message:@"请去沙盒 Documents/Turrit_Safe.txt 查看结果。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
