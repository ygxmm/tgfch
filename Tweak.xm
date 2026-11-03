#import <Foundation/Foundation.h>

// ==========================================
// 1. 拦截消息本身的修改（保底防线）
// ==========================================
%hook TGMessage

// 拦截修改图片/媒体
- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            NSLog(@"[TurritAntiEdit] 成功拦截图片修改！");
            return; 
        }
    }
    %orig(mediaAttachments);
}

// 拦截修改文本
- (void)setText:(NSString *)text {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (text != nil && ![self.text isEqualToString:text]) {
            NSLog(@"[TurritAntiEdit] 拦截带图消息文字修改！");
            return;
        }
    }
    if (self.text != nil && text != nil && ![self.text isEqualToString:text]) {
         NSLog(@"[TurritAntiEdit] 拦截纯文字修改！");
         return;
    }
    %orig(text);
}

// 拦截“已编辑”时间戳（防止出现“已编辑”小字）
- (void)setEditDate:(double)editDate {
    if (self.editDate == 0) {
        return; 
    }
    %orig(editDate);
}

// 拦截“已编辑”布尔标记
- (void)setIsEdited:(BOOL)isEdited {
    if (isEdited == YES) {
        return;
    }
    %orig(isEdited);
}

%end


// ==========================================
// 2. 拦截“编辑记录”面板（防偷窥原话）
// ==========================================
%hook TLParser

// 拦截获取编辑历史记录的方法
+ (id)editHistoryForKey:(id)a0 {
    NSLog(@"[TurritAntiEdit] 拦截了查看编辑历史(Key)！");
    return nil; // 返回 nil，面板里没数据
}

+ (id)editHistoryForMessageId:(id)a0 {
    NSLog(@"[TurritAntiEdit] 拦截了查看编辑历史(ID)！");
    return nil;
}

%end


// ==========================================
// 3. 拦截弹出的“编辑记录”视图控制器
// ==========================================
%hook LeadEditHistoryViewController

// 当试图弹出这个面板时，直接拦截
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    NSLog(@"[TurritAntiEdit] 拦截了编辑记录弹窗！");
    // 我们不调用 %orig，直接空掉它，这样就不会弹出来了
}

%end
