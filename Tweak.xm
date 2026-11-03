#import <Foundation/Foundation.h>

%hook TGMessage

// 拦截修改媒体附件（图片/视频）
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    // 如果当前消息原本就有媒体附件（旧图片）
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        // 并且对方企图塞入新的媒体附件（新图片）
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            NSLog(@"[TurritAntiEdit] 成功拦截图片/媒体修改！保留原图。");
            return; // 直接返回，拒绝更新
        }
    }
    %orig(mediaAttachments);
}

// 拦截修改文本
- (void)setText:(NSString *)text {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (text != nil && ![self.text isEqualToString:text]) {
            NSLog(@"[TurritAntiEdit] 成功拦截带图消息的文字修改！");
            return;
        }
    }
    if (self.text != nil && text != nil && ![self.text isEqualToString:text]) {
         NSLog(@"[TurritAntiEdit] 成功拦截纯文字修改！");
         return;
    }
    %orig(text);
}

%end
