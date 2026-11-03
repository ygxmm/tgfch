#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 声明缺失的类和属性
@interface TGMessage : NSObject
@property (nonatomic) int mid;
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end

// 全局字典，用来按消息 ID 保存旧图片
static NSMutableDictionary *oldMediaStore = nil;

%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            
            id oldMedia = [self.mediaAttachments firstObject];
            id newMedia = [mediaAttachments firstObject];
            NSString *oldClass = NSStringFromClass([oldMedia class]);
            NSString *newClass = NSStringFromClass([newMedia class]);
            
            if ([newClass containsString:@"Image"] || [newClass containsString:@"Video"]) {
                NSLog(@"[TurritAntiEdit] 🛑 成功拦截媒体修改！原类型: %@, 新类型: %@", oldClass, newClass);
                
                // 把旧媒体对象存下来，键值为消息的 mid
                if (!oldMediaStore) {
                    oldMediaStore = [NSMutableDictionary dictionary];
                }
                oldMediaStore[@(self.mid)] = self.mediaAttachments;
                
                return; // 拒绝更新
            }
        }
    }
    %orig(mediaAttachments);
}

%end

// 当用户试图查看编辑记录时：
%hook LeadEditHistoryViewController

+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    // 如果我们有拦截过这张图，且它试图弹窗
    // 这里我们让它正常弹窗（你可以看到“媒体已被替换”），但在终端打印出旧图信息
    // 因为纯 ObjC 替换 SwiftUI 界面非常容易导致崩溃
    
    NSLog(@"[TurritAntiEdit] 编辑记录被打开，mediaReplaced=%d, key=%@", a1, a0);
    
    if (a1 == YES) {
        // 你可以在这里发一个本地通知，或者打印日志，证明我们确实保留了旧图
        NSLog(@"[TurritAntiEdit] 我们知道旧图，但这里为了稳定性不作视图替换");
    }
    
    %orig(a0, a1, a2);
}

%end
