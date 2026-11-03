#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明 Swift 类
@interface AntiEditViewerController : UIViewController
+ (void)presentFrom:(UIViewController *)vc imageUrl:(NSString *)url;
@end

// 日志工具
void writeProbeLog(NSString *format, ...) { /* 省略，同上 */ }

// 拦截消息更新
@interface TGMessage : NSObject
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface TGImageInfo : NSObject
- (id)closestImageUrlWithSize:(CGSize)a0 resultingSize:(CGSize *)a1;
@end

%hook TGMessage
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments.count > 0 && mediaAttachments.count > 0) {
        id oldMedia = [self.mediaAttachments firstObject];
        @try {
            id imageInfo = [oldMedia valueForKey:@"imageInfo"];
            if (imageInfo) {
                NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(1000, 1000) resultingSize:NULL];
                if (url) {
                    // 调用 Swift UI
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIWindow *window = [UIApplication sharedApplication].keyWindow;
                        [AntiEditViewerController presentFrom:window.rootViewController imageUrl:url];
                    });
                }
            }
        } @catch (NSException *e) {}
        return; // 拒绝更新
    }
    %orig(mediaAttachments);
}
%end

// 备用大招：如果 TGMessage 不走，我们直接拦截网络包中的 TLParser 节点
@interface TLParser : NSObject
+ (id)handleResponse:(id)a0 functionID:(id)a1;
@end

%hook TLParser
+ (id)handleResponse:(id)a0 functionID:(id)a1 {
    id result = %orig;
    // 如果发现是编辑或更新包，强行触发我们的 Swift 探针
    // 这里我们暂不拦截，只打印看看
    return result;
}
%end
