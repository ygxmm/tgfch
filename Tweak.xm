#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明我们的 Swift 探针类
@interface SwiftProbe : NSObject
+ (void)probeViewController:(UIViewController *)vc;
@end

// 注入 UI 按钮
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass([self class]);
    if ([clsName containsString:@"ChatController"] || [clsName containsString:@"ChatList"]) {
        for (UIView *v in self.view.subviews) { if (v.tag == 12321) return; }
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 12321;
        btn.frame = CGRectMake(20, 150, 60, 60);
        btn.backgroundColor = [UIColor systemGreenColor];
        btn.layer.cornerRadius = 30;
        [btn setTitle:@"Swift" forState:UIControlStateNormal];
        
        // 调用 Swift 探针
        [btn addTarget:self action:@selector(runSwiftProbe) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
    }
}

- (void)runSwiftProbe {
    [SwiftProbe probeViewController:self];
}
%end
