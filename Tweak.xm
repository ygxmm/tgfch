#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSMutableDictionary *messageHistory = nil;
static NSMutableDictionary *currentMessages = nil;

NSString* parseMsgDesc(NSString *desc, BOOL isEdit) {
    if (!desc) return @"";
    NSRange idRange = [desc rangeOfString:@"id: "];
    NSString *msgId = @"unknown";
    if (idRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:idRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@","];
        if (parts.count > 0) msgId = parts[0];
    }
    
    NSString *text = @"(无文本或图片)";
    NSRange textRange = [desc rangeOfString:@"message: "];
    if (textRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:textRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@", media:"];
        if (parts.count > 0) text = [parts[0] stringByReplacingOccurrencesOfString:@"message: " withString:@""];
    }
    
    return [NSString stringWithFormat:@"[%@]\n文本: %@", msgId, text];
}

%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!messageHistory) messageHistory = [NSMutableDictionary dictionary];
            if (!currentMessages) currentMessages = [NSMutableDictionary dictionary];
            
            if ([desc containsString:@"updateNewChannelMessage"] || [desc containsString:@"updateNewMessage"]) {
                NSString *info = parseMsgDesc(desc, NO);
                NSRange idRange = [info rangeOfString:@"\\[.*?\\]" options:NSRegularExpressionSearch];
                if (idRange.location != NSNotFound) {
                    currentMessages[[info substringWithRange:idRange]] = info;
                }
            }
            
            if ([desc containsString:@"updateEditChannelMessage"] || [desc containsString:@"updateEditMessage"]) {
                NSString *newInfo = parseMsgDesc(desc, YES);
                NSRange idRange = [newInfo rangeOfString:@"\\[.*?\\]" options:NSRegularExpressionSearch];
                if (idRange.location != NSNotFound) {
                    NSString *msgId = [newInfo substringWithRange:idRange];
                    NSString *oldInfo = currentMessages[msgId] ?: @"(未知原消息)";
                    
                    NSMutableArray *history = messageHistory[msgId];
                    if (!history) {
                        history = [NSMutableArray array];
                        messageHistory[msgId] = history;
                    }
                    [history addObject:oldInfo];
                    currentMessages[msgId] = newInfo;
                }
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// 面板界面
@interface HistoryViewerController : UIViewController
@property (nonatomic, strong) NSString *msgId;
@end

@implementation HistoryViewerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 40, self.view.bounds.size.width, 44)];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"编辑记录"];
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    navItem.leftBarButtonItem = closeBtn;
    [navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:navBar];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 90, self.view.bounds.size.width, self.view.bounds.size.height - 90)];
    [self.view addSubview:scrollView];
    
    NSArray *history = messageHistory[self.msgId];
    NSString *current = currentMessages[self.msgId];
    CGFloat yOffset = 20;
    
    for (int i = 0; i < history.count; i++) {
        UILabel *label = [self createLabel:[NSString stringWithFormat:@"原文 %d", i+1] content:history[i] yOffset:yOffset];
        [scrollView addSubview:label];
        yOffset += label.frame.size.height + 15;
    }
    if (current) {
        UILabel *label = [self createLabel:@"当前 (已修改)" content:current yOffset:yOffset];
        [scrollView addSubview:label];
        yOffset += label.frame.size.height + 15;
    }
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, yOffset);
}

- (UILabel *)createLabel:(NSString *)title content:(NSString *)content yOffset:(CGFloat)y {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, y, self.view.bounds.size.width - 40, 150)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, card.frame.size.width - 30, 20)];
    titleLbl.text = title;
    titleLbl.font = [UIFont boldSystemFontOfSize:14];
    titleLbl.textColor = [UIColor systemBlueColor];
    [card addSubview:titleLbl];
    
    UILabel *contentLbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, card.frame.size.width - 30, 100)];
    contentLbl.text = content;
    contentLbl.numberOfLines = 0;
    contentLbl.font = [UIFont systemFontOfSize:13];
    [card addSubview:contentLbl];
    
    UILabel *wrapper = [[UILabel alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, 160)];
    [wrapper addSubview:card];
    return wrapper;
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

// 长按拦截
@interface LongPressHandler : NSObject
+ (instancetype)shared;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation LongPressHandler
+ (instancetype)shared {
    static LongPressHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[LongPressHandler alloc] init]; });
    return instance;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (messageHistory.count == 0) return; // 如果没有编辑记录，不干扰原生长按
    
    // 弹窗让用户选择
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"查看编辑记录" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 默认展示第一条被修改的记录（实际应用中可以动态匹配长按的消息ID）
        NSString *firstMsgId = messageHistory.allKeys.firstObject;
        HistoryViewerController *vc = [[HistoryViewerController alloc] init];
        vc.msgId = firstMsgId;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        [topVC presentViewController:vc animated:YES completion:nil];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    
    actionSheet.popoverPresentationController.sourceView = topVC.view;
    actionSheet.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2, topVC.view.bounds.size.height / 2, 1.0, 1.0);
    [topVC presentViewController:actionSheet animated:YES completion:nil];
}
@end

// 注入长按手势
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[LongPressHandler shared] action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.8;
    [self addGestureRecognizer:longPress];
}
%end
