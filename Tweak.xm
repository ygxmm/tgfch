#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSMutableDictionary *messageHistory = nil; // 记录历史 [msgId: [旧内容1, 旧内容2...]]
static NSMutableDictionary *currentMessages = nil; // 记录当前 [msgId: 最新内容]
static UIButton *floatBtn = nil;

// 提取内容（文本/图片标识）
NSString* extractContent(NSString *desc) {
    if (!desc) return @"";
    NSString *text = @"(无文本)";
    NSString *media = @"";
    
    NSRange textRange = [desc rangeOfString:@"message: "];
    if (textRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:textRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@", media:"];
        if (parts.count > 0) {
            text = [parts[0] stringByReplacingOccurrencesOfString:@"message: " withString:@""];
            if (text.length > 100) text = [text substringToIndex:100];
        }
    }
    
    NSRange mediaRange = [desc rangeOfString:@"media: MessageMedia."];
    if (mediaRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:mediaRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@","];
        if (parts.count > 0) media = [NSString stringWithFormat:@"\n[媒体] %@", parts[0]];
    }
    
    return [NSString stringWithFormat:@"内容: %@%@", text, media];
}

NSString* getMsgId(NSString *desc) {
    NSRange idRange = [desc rangeOfString:@"id: "];
    if (idRange.location != NSNotFound) {
        NSString *sub = [desc substringFromIndex:idRange.location];
        NSArray *parts = [sub componentsSeparatedByString:@","];
        if (parts.count > 0) return parts[0];
    }
    return @"unknown";
}

// ==========================================
// 1. 网络层拦截（阻断更新）
// ==========================================
%hook _TtC12TelegramCore13Serialization
- (id)parseMessage:(id)a0 {
    id result = %orig;
    if (result) {
        @try {
            NSString *desc = [result description];
            if (!messageHistory) messageHistory = [NSMutableDictionary dictionary];
            if (!currentMessages) currentMessages = [NSMutableDictionary dictionary];
            
            // 1. 捕获新消息作为“原文”
            if ([desc containsString:@"updateNewChannelMessage"] || [desc containsString:@"updateNewMessage"]) {
                NSString *msgId = getMsgId(desc);
                currentMessages[msgId] = extractContent(desc);
            }
            
            // 2. 捕获并阻断编辑
            if ([desc containsString:@"updateEditChannelMessage"] || [desc containsString:@"updateEditMessage"]) {
                NSString *msgId = getMsgId(desc);
                NSString *oldInfo = currentMessages[msgId] ?: @"(未能捕获原消息)";
                NSString *newInfo = extractContent(desc);
                
                NSMutableArray *history = messageHistory[msgId];
                if (!history) {
                    history = [NSMutableArray array];
                    messageHistory[msgId] = history;
                }
                [history addObject:oldInfo];
                currentMessages[msgId] = newInfo;
                
                // 更新悬浮球状态
                dispatch_async(dispatch_get_main_queue(), ^{
                    [floatBtn setTitle:@"已拦截" forState:UIControlStateNormal];
                    floatBtn.backgroundColor = [UIColor systemOrangeColor];
                });
                
                // 【关键】阻断更新：抛出一个空消息或返回 nil（如果导致崩溃可尝试返回空壳）
                return nil;
            }
            
            // 3. 捕获并阻断撤回
            if ([desc containsString:@"updateDeleteChannelMessages"] || [desc containsString:@"updateDeleteMessages"]) {
                // 更新悬浮球状态
                dispatch_async(dispatch_get_main_queue(), ^{
                    [floatBtn setTitle:@"防撤回" forState:UIControlStateNormal];
                    floatBtn.backgroundColor = [UIColor systemRedColor];
                });
                return nil;
            }
        } @catch (NSException *e) {}
    }
    return result;
}
%end

// ==========================================
// 2. 历史记录界面 UI
// ==========================================
@interface HistoryViewerController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSString *msgId;
@end

@implementation HistoryViewerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 40, self.view.bounds.size.width, 44)];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:[NSString stringWithFormat:@"编辑记录: %@", self.msgId]];
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    navItem.leftBarButtonItem = closeBtn;
    [navBar pushNavigationItem:navItem animated:NO];
    [self.view addSubview:navBar];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 84, self.view.bounds.size.width, self.view.bounds.size.height - 84) style:UITableViewStyleInsetGrouped];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *history = messageHistory[self.msgId];
    return history.count + 1; // +1 为当前版本
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"版本时间线";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
    
    NSArray *history = messageHistory[self.msgId];
    
    if (indexPath.row < history.count) {
        cell.textLabel.text = [NSString stringWithFormat:@"原文 %ld", (long)indexPath.row + 1];
        cell.textLabel.textColor = [UIColor systemBlueColor];
        cell.detailTextLabel.text = history[indexPath.row];
        cell.detailTextLabel.numberOfLines = 0;
    } else {
        cell.textLabel.text = @"当前 (已被修改)";
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.detailTextLabel.text = currentMessages[self.msgId];
        cell.detailTextLabel.numberOfLines = 0;
    }
    return cell;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

// ==========================================
// 3. 悬浮球与交互
// ==========================================
@interface FloatHandler : NSObject
+ (instancetype)shared;
- (void)showMenu;
@end

@implementation FloatHandler
+ (instancetype)shared {
    static FloatHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[FloatHandler alloc] init]; });
    return instance;
}
- (void)showMenu {
    if (messageHistory.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"暂无记录" message:@"请先让别人修改一条消息" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) topVC = topVC.presentedViewController;
        [topVC presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"选择要查看的消息" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *msgId in messageHistory.allKeys) {
        [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"消息 %@", msgId] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            HistoryViewerController *vc = [[HistoryViewerController alloc] init];
            vc.msgId = msgId;
            vc.modalPresentationStyle = UIModalPresentationFullScreen;
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) window = [UIApplication sharedApplication].windows.firstObject;
            UIViewController *topVC = window.rootViewController;
            while (topVC.presentedViewController) topVC = topVC.presentedViewController;
            [topVC presentViewController:vc animated:YES completion:nil];
        }]];
    }
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

// 注入悬浮球到当前 App 根视图
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (floatBtn) return;
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatBtn.frame = CGRectMake(window.bounds.size.width - 80, window.bounds.size.height - 200, 60, 60);
        floatBtn.backgroundColor = [UIColor systemGreenColor];
        floatBtn.layer.cornerRadius = 30;
        floatBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        floatBtn.layer.shadowOffset = CGSizeMake(0, 3);
        floatBtn.layer.shadowOpacity = 0.5;
        [floatBtn setTitle:@"记录" forState:UIControlStateNormal];
        floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        
        [floatBtn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            [[FloatHandler shared] showMenu];
        }] forControlEvents:UIControlEventTouchUpInside];
        
        [window.rootViewController.view addSubview:floatBtn];
    });
}
%end
