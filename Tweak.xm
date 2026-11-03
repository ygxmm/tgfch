#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 补齐头文件声明，让编译器闭嘴
// ==========================================
@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface TGImageMediaAttachment : NSObject
@property (nonatomic) long long imageId;
@property (retain, nonatomic) id imageInfo;
@end

@interface TGImageInfo : NSObject
- (id)allSizes;
@end

static UIViewController* topViewController() {
    UIWindow *keyWindow = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;
    return rootVC;
}

%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            id newMedia = [mediaAttachments firstObject];
            if ([NSStringFromClass([newMedia class]) containsString:@"Image"]) {
                
                id oldMedia = [self.mediaAttachments firstObject];
                
                // 强行提取内部信息
                NSString *mediaDesc = [oldMedia description];
                TGImageInfo *imageInfo = nil;
                NSArray *sizes = nil;
                long long imgId = 0;
                
                @try {
                    if ([oldMedia respondsToSelector:NSSelectorFromString(@"imageId")]) {
                        imgId = [[oldMedia valueForKey:@"imageId"] longLongValue];
                    }
                    if ([oldMedia respondsToSelector:NSSelectorFromString(@"imageInfo")]) {
                        imageInfo = [oldMedia valueForKey:@"imageInfo"];
                    }
                    if ([imageInfo respondsToSelector:@selector(allSizes)]) {
                        sizes = [imageInfo allSizes];
                    }
                } @catch (NSException *e) {}

                NSString *probeMsg = [NSString stringWithFormat:@"imageId: %lld\n\nallSizes: %@\n\nimageInfo: %@\n\n旧对象: %@", 
                                      imgId, sizes, imageInfo, mediaDesc];
                
                // 字数太多只取前1000个字符，防止弹窗崩溃
                if (probeMsg.length > 1000) {
                    probeMsg = [probeMsg substringToIndex:1000];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"旧图探针数据" message:probeMsg preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                    [topViewController() presentViewController:alert animated:YES completion:nil];
                });
                
                return; // 拒绝更新
            }
        }
    }
    %orig(mediaAttachments);
}

%end
