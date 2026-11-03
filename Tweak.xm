#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SwiftNodeProbe : NSObject
+ (void)probeCurrentView:(UIView *)view;
@end

static UIButton *floatBtn = nil;

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (floatBtn) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        
        floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.frame = CGRectMake(window.bounds.size.width - 75, window.bounds.size.height / 2 + 100, 60, 60);
        floatBtn.backgroundColor = [UIColor systemPurpleColor];
        floatBtn.layer.cornerRadius = 30;
        [floatBtn setTitle:@"抓Swift" forState:UIControlStateNormal];
        floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        
        [floatBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            [SwiftNodeProbe probeCurrentView:window.rootViewController.view];
        }] forControlEvents:UIControlEventTouchUpInside];
        
        [window.rootViewController.view addSubview:floatBtn];
    });
}
%end
