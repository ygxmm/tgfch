#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 0. 声明缺失的类和方法，防止编译报错
// ==========================================
@interface TGMessage : NSObject
@property (retain, nonatomic) NSArray *mediaAttachments;
@property (copy, nonatomic) NSString *text;
@property (nonatomic) double editDate;
@property (nonatomic) BOOL isEdited;
@end

@interface TLParser : NSObject
+ (id)editHistoryForKey:(id)a0;
+ (id)editHistoryForMessageId:(id)a0;
@end

@interface LeadEditHistoryViewController : UIViewController
+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2;
@end


// ==========================================
// 1. 拦截消息本身的修改（保底防线）
// ==========================================
%hook TGMessage

- (void)setMediaAttachments:(NSArray *)mediaAttachments {
    if (self.mediaAttachments != nil && self.mediaAttachments.count > 0) {
        if (mediaAttachments != nil && mediaAttachments.count > 0) {
            NSLog(@"[TurritAntiEdit] 成功拦截图片修改！");
            return; 
        }
    }
    %orig(mediaAttachments);
}

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

- (void)setEditDate:(double)editDate {
    if (self.editDate == 0) {
        return; 
    }
    %orig(editDate);
}

- (void)setIsEdited:(BOOL)isEdited {
    if (isEdited == YES) {
        return;
    }
    %orig(isEdited);
}

%end


// ==========================================
// 2. 拦截“编辑记录”面板数据
// ==========================================
%hook TLParser

+ (id)editHistoryForKey:(id)a0 {
    NSLog(@"[TurritAntiEdit] 拦截了查看编辑历史(Key)！");
    return nil; 
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

+ (void)presentForKey:(id)a0 mediaReplaced:(BOOL)a1 from:(id)a2 {
    NSLog(@"[TurritAntiEdit] 拦截了编辑记录弹窗！");
    // 空实现，不弹出面板
}

%end
