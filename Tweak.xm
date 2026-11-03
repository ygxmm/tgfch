#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 写日志到沙盒
void logPacket(NSString *text) {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"Turrit_Packets.txt"];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) { [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
    else { [file seekToEndOfFile]; [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
}

// 1. 拦截底层网络序列化解析器 (这是所有消息进手机的第一站)
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        NSString *clsName = NSStringFromClass([result class]);
        // 记录所有收到的包
        logPacket([NSString stringWithFormat:@"[收到数据包] %@\n", clsName]);
        
        // 如果包名带 Edit 或 Update，特殊标记
        if ([clsName containsString:@"Edit"] || [clsName containsString:@"Update"]) {
            logPacket([NSString stringWithFormat:@"  ==> 重点可疑包: %@\n\n", result]);
        }
    }
    return result;
}
%end

// 2. 拦截另一个可能的 Swift 网络接收入口
%hook _TtC12TelegramCoreP33_C08D30065300083FB7E5BAE4ADF7A07627MtProtoKitUpdateSinkService
- (void)mtProto:(id)a0 receivedMessage:(id)a1 authInfoSelector:(long long)a2 networkType:(int)a3 {
    if (a1) {
        NSString *clsName = NSStringFromClass([a1 class]);
        logPacket([NSString stringWithFormat:@"[底层网络] 收到消息: %@\n", clsName]);
    }
    %orig;
}
%end

// 3. 拦截 Controller，确保你点击时能看到文件写在哪了
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) containsString:@"ChatController"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 44444) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 44444;
        btn.frame = CGRectMake(20, 100, 60, 60);
        btn.backgroundColor = [UIColor systemRedColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"提示" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(showPacketTip) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}

- (void)showPacketTip {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"抓包运行中" message:@"请去 Turrit 的 Documents 目录查看 Turrit_Packets.txt 文件。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}
%end
