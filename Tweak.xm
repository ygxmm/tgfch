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
- (id)closestImageUrlWithSize:(struct CGSize { double x0; double x1; })a0 resultingSize:(struct CGSize { double x0; double x1; } *)a1;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

// 全局字典：存放被拦截的旧图 (Key: 消息ID字符串, Value: 媒体数组)
static NSMutableDictionary *savedOldMediaDict = nil;

// ==========================================
// 自定义一个简单的全屏看图控制器
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
    
    // 点击任意位置关闭
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    [self.view addGestureRecognizer:tap];
}
- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ==========================================
// 1. 拦截消息本身，保存旧图
// ==========================================
%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            
            id oldMedia = [self.mediaAttachments firstObject];
            id newMedia = [mediaAttachments firstObject];
            NSString *newClass = NSStringFromClass([newMedia class]);
            
            if ([newClass containsString:@"Image"] || [newClass containsString:@"Video"]) {
                NSLog(@"[TurritAntiEdit] 🛑 拦截媒体修改！保存旧图用于查看。");
                
                if (!savedOldMediaDict) {
                    savedOldMediaDict = [NSMutableDictionary dictionary];
                }
                // 用消息的 mid 作为 Key 存入旧媒体
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
        
        // 由于 a0 可能是复合字符串，我们尝试取最近一次保存的旧图
        // 如果你想严谨匹配，可以从 a0 里正则提取 mid，这里为了兼容性取最后一次拦截的图
        NSArray *oldMediaArray = nil;
        if (savedOldMediaDict && savedOldMediaDict.count > 0) {
            // 这里简单处理：取字典里最后一个保存的图（或者根据当前界面去匹配）
            oldMediaArray = [[savedOldMediaDict allValues] lastObject]; 
        }
        
        if (oldMediaArray && oldMediaArray.count > 0) {
            id media = [oldMediaArray firstObject];
            NSString *className = NSStringFromClass([media class]);
            
            if ([className containsString:@"Image"]) {
                // 提取 URL
                id imageInfo = [media valueForKey:@"imageInfo"];
                if (imageInfo) {
                    NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(1000, 1000) resultingSize:NULL];
                    if (url) {
                        NSLog(@"[TurritAntiEdit] 找到旧图路径: %@", url);
                        // 兼容处理 file:// 路径
                        NSString *path = [url stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                        UIImage *oldImage = [UIImage imageWithContentsOfFile:path];
                        
                        if (oldImage) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                AntiEditImageViewerController *vc = [[AntiEditImageViewerController alloc] init];
                                vc.image = oldImage;
                                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
                            });
                            return; // 成功弹出图片，结束执行
                        }
                    }
                }
            }
        }
        
        // 如果上面提取图片失败（比如图片不在本地缓存），就降级弹个提示框
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑提示" message:@"旧图片已成功保留在聊天界面。\n(未找到本地缓存原图文件)" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        });
        
        return;
    }
    %orig(a0, a1, a2);
}

%end
