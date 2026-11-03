#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 声明缺失的类和方法
// ==========================================
@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface TGImageMediaAttachment : NSObject
@property (retain, nonatomic) id imageInfo;
@end

@interface TGImageInfo : NSObject
- (id)closestImageUrlWithSize:(CGSize)a0 resultingSize:(CGSize *)a1;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

static NSMutableDictionary *savedOldMediaDict = nil;

// ==========================================
// 自定义全屏看图控制器
// ==========================================
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
- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ==========================================
// 辅助函数：获取当前最顶层的 ViewController
// ==========================================
static UIViewController* topViewController() {
    UIWindow *keyWindow = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
#pragma clang diagnostic pop

    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

// ==========================================
// 1. 拦截消息本身，保存旧图
// ==========================================
%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            
            id newMedia = [mediaAttachments firstObject];
            NSString *newClass = NSStringFromClass([newMedia class]);
            
            if ([newClass containsString:@"Image"] || [newClass containsString:@"Video"]) {
                NSLog(@"[TurritAntiEdit] 🛑 拦截媒体修改！保存旧图用于查看。");
                
                if (!savedOldMediaDict) {
                    savedOldMediaDict = [NSMutableDictionary dictionary];
                }
                savedOldMediaDict[[NSString stringWithFormat:@"%d", self.mid]] = self.mediaAttachments;
                
                return; // 拒绝更新
            }
        }
    }
    %orig(mediaAttachments);
}

%end

// ==========================================
// 2. 拦截弹窗，自己弹旧图
// ==========================================
%hook LeadEditHistoryViewController

+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    if (a1 == YES) {
        NSLog(@"[TurritAntiEdit] 触发图片查看拦截！Key: %@", a0);
        
        NSArray *oldMediaArray = nil;
        if (savedOldMediaDict && savedOldMediaDict.count > 0) {
            oldMediaArray = [[savedOldMediaDict allValues] lastObject]; 
        }
        
        if (oldMediaArray && oldMediaArray.count > 0) {
            id media = [oldMediaArray firstObject];
            NSString *className = NSStringFromClass([media class]);
            
            if ([className containsString:@"Image"]) {
                id imageInfo = [media valueForKey:@"imageInfo"];
                if (imageInfo) {
                    NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(1000, 1000) resultingSize:NULL];
                    if (url) {
                        NSLog(@"[TurritAntiEdit] 找到旧图路径: %@", url);
                        NSString *path = [url stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                        UIImage *oldImage = [UIImage imageWithContentsOfFile:path];
                        
                        if (oldImage) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                AntiEditImageViewerController *vc = [[AntiEditImageViewerController alloc] init];
                                vc.image = oldImage;
                                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                                [topViewController() presentViewController:vc animated:YES completion:nil];
                            });
                            return; // 成功弹出图片
                        }
                    }
                }
            }
        }
        
        // 降级方案
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑提示" message:@"旧图片已成功保留在聊天界面。\n(未找到本地缓存原图文件，可能已被系统清理)" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [topViewController() presentViewController:alert animated:YES completion:nil];
        });
        
        return;
    }
    %orig(a0, a1, a2);
}

%end
