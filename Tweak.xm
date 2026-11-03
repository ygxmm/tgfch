#import <Foundation/Foundation.h>

// 声明类和方法，防止编译报错
@interface TGMessage : NSObject
@property (retain, nonatomic) NSArray *mediaAttachments;
@end

%hook TGMessage

// 精准拦截图片和视频的修改
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    // 1. 如果当前消息原本就有媒体（说明原来发了图/视频）
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        
        // 2. 并且对方企图塞入新的媒体（说明是修改操作）
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            
            // 3. 获取新媒体的类名，确认是图片还是视频
            id newMedia = [mediaAttachments firstObject];
            NSString *className = NSStringFromClass([newMedia class]);
            
            // 只要类名包含 Image 或 Video（涵盖 TGImageMediaAttachment 等）
            if ([className containsString:@"Image"] || [className containsString:@"Video"]) {
                NSLog(@"[TurritAntiEdit] 🛑 成功拦截媒体修改！类型: %@", className);
                return; // 直接 return，拒绝更新，保留原来的图片/视频
            }
        }
    }
    
    // 其他情况（比如正常发新图、发新视频），放行
    %orig(mediaAttachments);
}

%end
