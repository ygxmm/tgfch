#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 精准声明头文件
@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface TGImageMediaAttachment : NSObject <NSCoding>
@property (nonatomic) long long imageId;
@property (retain, nonatomic) id imageInfo;
@end

@interface TGImageInfo : NSObject
- (id)closestImageUrlWithSize:(CGSize)a0 resultingSize:(CGSize *)a1;
- (id)allSizes;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

// 自定义全屏看图
@interface AntiEditImageViewerController : UIViewController
@property (nonatomic, strong) UIImage *image;
@end

@implementation AntiEditImageViewerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.frame = self.view.bounds;
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:imageView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [self.view addGestureRecognizer:tap];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
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

// 帮助函数：把旧图序列化保存到沙盒文件（防原生缓存清理）
static void saveOldMediaToDisk(id oldMedia) {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"AntiEdit_SavedMedia.data"];
    @try {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:oldMedia requiringSecureCoding:NO error:nil];
        [data writeToFile:path atomically:YES];
    } @catch (NSException *e) {
        NSLog(@"[TurritAntiEdit] 归档失败: %@", e);
    }
}

// 帮助函数：从沙盒文件读回旧图对象
static id loadOldMediaFromDisk() {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [docPath stringByAppendingPathComponent:@"AntiEdit_SavedMedia.data"];
    @try {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            return [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"TGImageMediaAttachment") fromData:data error:nil];
        }
    } @catch (NSException *e) {}
    return nil;
}

%hook TGMessage
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            id newMedia = [mediaAttachments firstObject];
            if ([NSStringFromClass([newMedia class]) containsString:@"Image"]) {
                // 保存旧图对象到本地磁盘
                id oldMedia = [self.mediaAttachments firstObject];
                saveOldMediaToDisk(oldMedia);
                return; // 拦截修改
            }
        }
    }
    %orig(mediaAttachments);
}
%end

%hook LeadEditHistoryViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    if (a1 == YES) {
        // 从沙盒读取我们刚才存的旧图
        id oldMedia = loadOldMediaFromDisk();
        if (oldMedia) {
            id imageInfo = [oldMedia valueForKey:@"imageInfo"];
            if (imageInfo) {
                NSString *urlStr = nil;
                
                // 方法1：通过头文件里的 closestImageUrlWithSize 提取
                if ([imageInfo respondsToSelector:@selector(closestImageUrlWithSize:resultingSize:)]) {
                    urlStr = [imageInfo closestImageUrlWithSize:CGSizeMake(800, 800) resultingSize:NULL];
                }
                
                // 方法2：如果方法1返回 nil，暴力遍历 allSizes
                if (!urlStr && [imageInfo respondsToSelector:@selector(allSizes)]) {
                    NSArray *sizes = [imageInfo allSizes];
                    if (sizes.count > 0) {
                        // 由于不确定 allSizes 里面具体是对象还是字典，我们先拿到最后一个（通常最大的图）
                        id record = [sizes lastObject];
                        if ([record isKindOfClass:[NSString class]]) {
                            urlStr = (NSString *)record;
                        } else {
                            // 可能是包含 url 的字典或对象
                            if ([record respondsToSelector:NSSelectorFromString(@"url")]) {
                                urlStr = [record valueForKey:@"url"];
                            }
                        }
                    }
                }
                
                if (urlStr) {
                    UIImage *image = nil;
                    if ([urlStr hasPrefix:@"file://"]) {
                        image = [UIImage imageWithContentsOfFile:[urlStr stringByReplacingOccurrencesOfString:@"file://" withString:@""]];
                    } else if ([urlStr hasPrefix:@"http"]) {
                        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]];
                        if (data) image = [UIImage imageWithData:data];
                    }
                    
                    if (image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            AntiEditImageViewerController *vc = [[AntiEditImageViewerController alloc] init];
                            vc.image = image;
                            vc.modalPresentationStyle = UIModalPresentationFullScreen;
                            [topViewController() presentViewController:vc animated:YES completion:nil];
                        });
                        return;
                    }
                }
            }
        }
        
        // 如果还是失败，我们打印详细说明
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑提示" message:@"图片已拦截。但无法从底层 mediaInfo 提取 URL，可能此图片未保存在本地服务器。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [topViewController() presentViewController:alert animated:YES completion:nil];
        });
        return;
    }
    %orig(a0, a1, a2);
}
%end
