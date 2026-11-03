#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            id newMedia = [mediaAttachments firstObject];
            NSString *newClass = NSStringFromClass([newMedia class]);
            if ([newClass containsString:@"Image"] || [newClass containsString:@"Video"]) {
                if (!savedOldMediaDict) {
                    savedOldMediaDict = [NSMutableDictionary dictionary];
                }
                savedOldMediaDict[[NSString stringWithFormat:@"%d", self.mid]] = self.mediaAttachments;
                return;
            }
        }
    }
    %orig(mediaAttachments);
}

%end

%hook LeadEditHistoryViewController

+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    if (a1 == YES) {
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
                        UIImage *oldImage = nil;
                        
                        if ([url hasPrefix:@"file://"]) {
                            NSString *path = [url stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                            oldImage = [UIImage imageWithContentsOfFile:path];
                        } else if ([url hasPrefix:@"http"]) {
                            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
                            if (data) {
                                oldImage = [UIImage imageWithData:data];
                            }
                        }
                        
                        if (oldImage) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                AntiEditImageViewerController *vc = [[AntiEditImageViewerController alloc] init];
                                vc.image = oldImage;
                                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                                [topViewController() presentViewController:vc animated:YES completion:nil];
                            });
                            return;
                        }
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"防编辑提示" message:@"对方试图修改图片，已被拦截。但旧图片已不在本地缓存中。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [topViewController() presentViewController:alert animated:YES completion:nil];
        });
        
        return;
    }
    %orig(a0, a1, a2);
}

%end
