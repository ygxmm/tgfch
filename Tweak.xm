#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 声明我们自己的 Swift 界面
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

@interface TGMessage : NSObject
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface TGImageInfo : NSObject
- (id)closestImageUrlWithSize:(CGSize)a0 resultingSize:(CGSize *)a1;
@end

// 辅助函数：安全获取当前最顶层的 ViewController
static UIViewController* topViewController() {
    UIWindow *keyWindow = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

%hook TGMessage
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments.count > 0 && mediaAttachments.count > 0) {
        id oldMedia = [self.mediaAttachments firstObject];
        @try {
            id imageInfo = [oldMedia valueForKey:@"imageInfo"];
            if (imageInfo) {
                NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(1000, 1000) resultingSize:NULL];
                if (url) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIViewController *vc = topViewController();
                        if (vc) {
                            // 调用纯 Swift 写的看图界面
                            [AntiEditViewerController presentFrom:vc imageUrl:url];
                        }
                    });
                }
            }
        } @catch (NSException *e) {}
        return; // 拒绝更新
    }
    %orig(mediaAttachments);
}
%end
