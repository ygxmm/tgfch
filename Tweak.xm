#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 1. 声明我们要 Hook 的核心类（包含自己创造的方法）
// ==========================================
@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (copy, nonatomic) NSString *text;
@property (retain, nonatomic) NSArray *mediaAttachments;
@property (nonatomic) BOOL isEdited;
- (void)showOurEditHistoryPanel; // 补上这个声明，解决报错
@end

@interface TGImageMediaAttachment : NSObject
@property (nonatomic) long long imageId;
@property (retain, nonatomic) id imageInfo;
@end

@interface TGImageInfo : NSObject
- (id)closestImageUrlWithSize:(CGSize)a0 resultingSize:(CGSize *)a1;
- (id)allSizes;
@end

// ==========================================
// 2. 全局变量与辅助函数
// ==========================================
static NSMutableDictionary *savedOldTextDict = nil;
static NSMutableDictionary *savedOldMediaDict = nil;

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

// 辅助函数：从 TGImageMediaAttachment 中强行挖出图片路径或URL
static NSString* extractImageUrl(id imageMedia) {
    if (!imageMedia) return nil;
    @try {
        if ([imageMedia respondsToSelector:NSSelectorFromString(@"imageInfo")]) {
            id info = [imageMedia valueForKey:@"imageInfo"];
            if (info) {
                if ([info respondsToSelector:@selector(closestImageUrlWithSize:resultingSize:)]) {
                    NSString *url = [info closestImageUrlWithSize:CGSizeMake(1000, 1000) resultingSize:NULL];
                    if (url) return url;
                }
                if ([info respondsToSelector:@selector(allSizes)]) {
                    NSArray *sizes = [info performSelector:@selector(allSizes)];
                    if (sizes.count > 0) {
                        id record = [sizes lastObject];
                        if ([record isKindOfClass:[NSString class]]) return record;
                        if ([record respondsToSelector:NSSelectorFromString(@"url")]) {
                            return [record valueForKey:@"url"];
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {}
    return nil;
}

// ==========================================
// 3. 拦截 TGMessage，保存旧数据
// ==========================================
%hook TGMessage

// 拦截文本修改
- (void)setText:(NSString *)text {
    if (self.text != nil && text != nil && ![self.text isEqualToString:text]) {
        if (!savedOldTextDict) savedOldTextDict = [NSMutableDictionary dictionary];
        savedOldTextDict[[NSString stringWithFormat:@"%d", self.mid]] = self.text;
        return; // 拦截
    }
    %orig(text);
}

// 拦截图片修改
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            id newMedia = [mediaAttachments firstObject];
            if ([NSStringFromClass([newMedia class]) containsString:@"Image"]) {
                if (!savedOldMediaDict) savedOldMediaDict = [NSMutableDictionary dictionary];
                savedOldMediaDict[[NSString stringWithFormat:@"%d", self.mid]] = self.mediaAttachments;
                
                // 拦截后，调用我们的 UI 弹窗提醒
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showOurEditHistoryPanel];
                });
                
                return; // 拦截
            }
        }
    }
    %orig(mediaAttachments);
}

// 我们自己的 UI 弹窗方法
- (void)showOurEditHistoryPanel {
    NSString *midStr = [NSString stringWithFormat:@"%d", self.mid];
    NSString *oldText = savedOldTextDict[midStr];
    NSArray *oldMedia = savedOldMediaDict[midStr];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑拦截" message:[NSString stringWithFormat:@"消息已被拦截。\n\n原文: %@\n包含旧图: %@", oldText ?: @"无", oldMedia.count > 0 ? @"是" : @"否"] preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"查看旧图片" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (oldMedia.count > 0) {
            NSString *url = extractImageUrl([oldMedia firstObject]);
            if (url) {
                UIImage *img = nil;
                if ([url hasPrefix:@"file://"]) {
                    img = [UIImage imageWithContentsOfFile:[url stringByReplacingOccurrencesOfString:@"file://" withString:@""]];
                } else if ([url hasPrefix:@"http"]) {
                    img = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:url]]];
                }
                
                if (img) {
                    UIAlertController *imgAlert = [UIAlertController alertControllerWithTitle:@"原图" message:nil preferredStyle:UIAlertControllerStyleAlert];
                    UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
                    imgView.contentMode = UIViewContentModeScaleAspectFit;
                    imgView.frame = CGRectMake(0, 0, 250, 250);
                    [imgAlert.view addSubview:imgView];
                    [imgAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
                    [topViewController() presentViewController:imgAlert animated:YES completion:nil];
                } else {
                    UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:@"提示" message:[NSString stringWithFormat:@"拿不到图片内容。\nURL: %@", url] preferredStyle:UIAlertControllerStyleAlert];
                    [failAlert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                    [topViewController() presentViewController:failAlert animated:YES completion:nil];
                }
            } else {
                UIAlertController *nilAlert = [UIAlertController alertControllerWithTitle:@"提示" message:@"无法提取旧图片的 URL 路径" preferredStyle:UIAlertControllerStyleAlert];
                [nilAlert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [topViewController() presentViewController:nilAlert animated:YES completion:nil];
            }
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    
    // iPad 兼容
    alert.popoverPresentationController.sourceView = topViewController().view;
    alert.popoverPresentationController.sourceRect = CGRectMake(topViewController().view.bounds.size.width / 2, topViewController().view.bounds.size.height / 2, 1.0, 1.0);
    
    [topViewController() presentViewController:alert animated:YES completion:nil];
}

%end
