#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ==========================================
// 1. 数据存储引擎：记录消息历史
// ==========================================
static NSMutableDictionary *messageHistory = nil; // Key: 消息ID, Value: 历史版本数组
static NSMutableDictionary *currentMessages = nil; // Key: 消息ID, Value: 最新内容描述

// 提取核心信息的工具函数
NSString* parseMsgDesc(NSString *desc, BOOL isEdit) {
    if (!desc) return @"";
    
    // 提取消息 ID
    NSRange idRange = [desc rangeOfString:@"id: "];
    NSString *msgId = @"unknown";
    if (idRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:idRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@","];
        if (parts.count > 0) msgId = parts[0];
    }
    
    // 提取文本
    NSString *text = @"(无文本或图片)";
    NSRange textRange = [desc rangeOfString:@"message: "];
    if (textRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:textRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@", media:"];
        if (parts.count > 0) {
            text = [parts[0] stringByReplacingOccurrencesOfString:@"message: " withString:@""];
        }
    }
    
    // 提取媒体信息
    NSString *media = @"";
    NSRange mediaRange = [desc rangeOfString:@"media: MessageMedia."];
    if (mediaRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:mediaRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@","];
        if (parts.count > 0) media = parts[0];
    }
    
    // 拼装
    if (isEdit) {
        return [NSString stringWithFormat:@"[%@]\n文本: %@\n媒体: %@", msgId, text, media];
    } else {
        return [NSString stringWithFormat:@"[%@]\n文本: %@\n媒体: %@", msgId, text, media];
    }
}

// ==========================================
// 2. 网络层拦截：抓取原文与新文
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!messageHistory) messageHistory = [NSMutableDictionary dictionary];
            if (!currentMessages) currentMessages = [NSMutableDictionary dictionary];
            
            // 1. 抓取新消息（作为后续对比的“原文”）
            if ([desc containsString:@"updateNewChannelMessage"] || [desc containsString:@"updateNewMessage"]) {
                NSString *info = parseMsgDesc(desc, NO);
                NSRange idRange = [info rangeOfString:@"\\[.*?\\]" options:NSRegularExpressionSearch];
                if (idRange.location != NSNotFound) {
                    NSString *msgId = [info substringWithRange:idRange];
                    currentMessages[msgId] = info;
                }
            }
            
            // 2. 抓取撤回指令
            if ([desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateDeleteMessages"]) {
                // 这里可以增加撤回逻辑，把 currentMessages 里对应的删掉，或者保留
            }
            
            // 3. 抓取编辑指令（核心：把旧数据存入历史，更新新数据）
            if ([desc containsString:@"updateEditChannelMessage"] || [desc containsString:@"updateEditMessage"]) {
                NSString *newInfo = parseMsgDesc(desc, YES);
                NSRange idRange = [newInfo rangeOfString:@"\\[.*?\\]" options:NSRegularExpressionSearch];
                if (idRange.location != NSNotFound) {
                    NSString *msgId = [newInfo substringWithRange:idRange];
                    
                    // 取出旧信息
                    NSString *oldInfo = currentMessages[msgId] ?: @"(未知原消息，可能已被清理)";
                    
                    // 存入历史记录
                    NSMutableArray *history = messageHistory[msgId];
                    if (!history) {
                        history = [NSMutableArray array];
                        messageHistory[msgId] = history;
                    }
                    [history addObject:oldInfo];
                    
                    // 更新当前信息
                    currentMessages[msgId] = newInfo;
                    
                    NSLog(@"[HistoryEngine] 成功记录了编辑历史 ID: %@", msgId);
                }
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 3. 自定义一个仿 Lead 的界面（展示历史）
// ==========================================
@interface HistoryViewerController : UIViewController
@property (nonatomic, strong) NSString *msgId;
@end

@implementation HistoryViewerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 标题栏
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 40, self.view.bounds.size.width, 44)];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"编辑记录"];
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    navItem.leftBarButtonItem = closeBtn;
    [navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:navBar];
    
    // 滚动视图存放记录
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 90, self.view.bounds.size.width, self.view.bounds.size.height - 90)];
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];
    
    NSArray *history = messageHistory[self.msgId];
    NSString *current = currentMessages[self.msgId];
    
    CGFloat yOffset = 20;
    
    // 显示历史（原文）
    for (int i = 0; i < history.count; i++) {
        NSString *text = history[i];
        UILabel *label = [self createHistoryLabel:[NSString stringWithFormat:@"版本 %d (原文)", i+1] content:text yOffset:yOffset];
        [scrollView addSubview:label];
        yOffset += label.frame.size.height + 15;
    }
    
    // 显示当前
    if (current) {
        UILabel *label = [self createHistoryLabel:@"当前 (已修改)" content:current yOffset:yOffset];
        [scrollView addSubview:label];
        yOffset += label.frame.size.height + 15;
    }
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, yOffset);
}

- (UILabel *)createHistoryLabel:(NSString *)title content:(NSString *)content yOffset:(CGFloat)y {
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
    
    // 返回一个容器（用个空 Label 包裹以方便计算高度，这里简化处理直接返回 card 的容器）
    UILabel *wrapper = [[UILabel alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, 160)];
    [wrapper addSubview:card];
    return wrapper;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ==========================================
// 4. UI 注入：悬浮球与快捷入口
// ==========================================
static UIButton *floatBtn = nil;
static int blockCount = 0;
static NSString *lastEditedMsgId = nil;

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (floatBtn) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        
        floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.frame = CGRectMake(20, 200, 60, 60);
        floatBtn.backgroundColor = [UIColor systemGreenColor];
        floatBtn.layer.cornerRadius = 30;
        floatBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        floatBtn.layer.shadowOffset = CGSizeMake(0, 3);
        floatBtn.layer.shadowOpacity = 0.4;
        [floatBtn setTitle:@"记录" forState:UIControlStateNormal];
        floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        
        [floatBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            // 如果没有拦截到任何修改
            if (messageHistory.count == 0) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"暂无记录" message:@"请先让别人修改一条消息，然后再点这里。" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                UIViewController *topVC = window.rootViewController;
                while (topVC.presentedViewController) topVC = topVC.presentedViewController;
                [topVC presentViewController:alert animated:YES completion:nil];
                return;
            }
            
            // 弹出选择框（如果有多条被编辑的消息）
            UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"选择要查看的消息" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            for (NSString *msgId in messageHistory.allKeys) {
                [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"消息 %@", msgId] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    HistoryViewerController *vc = [[HistoryViewerController alloc] init];
                    vc.msgId = msgId;
                    vc.modalPresentationStyle = UIModalPresentationFullScreen;
                    
                    UIViewController *topVC = window.rootViewController;
                    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
                    [topVC presentViewController:vc animated:YES completion:nil];
                }]];
            }
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            
            UIViewController *topVC = window.rootViewController;
            while (topVC.presentedViewController) topVC = topVC.presentedViewController;
            
            // iPad 兼容
            actionSheet.popoverPresentationController.sourceView = topVC.view;
            actionSheet.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2, topVC.view.bounds.size.height / 2, 1.0, 1.0);
            
            [topVC presentViewController:actionSheet animated:YES completion:nil];
        }] forControlEvents:UIControlEventTouchUpInside];
        
        [window addSubview:floatBtn];
    });
}
%end
