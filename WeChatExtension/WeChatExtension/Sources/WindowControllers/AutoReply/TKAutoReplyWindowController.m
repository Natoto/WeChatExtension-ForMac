//
//  TKAutoReplyWindowController.m
//  WeChatExtension
//
//  Created by WeChatExtension on 2019/4/19.
//  Copyright © 2019年 WeChatExtension. All rights reserved.
//

#import "TKAutoReplyWindowController.h"
#import "TKAutoReplyContentView.h"
#import "TKAutoReplyCell.h"
#import "YMThemeManager.h"

@interface TKAutoReplyWindowController () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) TKAutoReplyContentView *contentView;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *reduceButton;
@property (nonatomic, strong) NSButton *enableButton;
@property (nonatomic, strong) NSAlert *alert;

@property (nonatomic, strong) NSMutableArray *autoReplyModels;
@property (nonatomic, assign) NSInteger lastSelectIndex;

@end

@implementation TKAutoReplyWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self initSubviews];
    [self setup];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    [self.tableView reloadData];
    [self.contentView setHidden:YES];
    if (self.autoReplyModels && self.autoReplyModels.count == 0) {
        [self addModel];
    }
    if (self.autoReplyModels.count > 0 && self.tableView) {
         [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.autoReplyModels.count - 1] byExtendingSelection:YES];
    }
}

- (void)initSubviews
{
    NSScrollView *scrollView = ({
        NSScrollView *scrollView = [[NSScrollView alloc] init];
        scrollView.hasVerticalScroller = YES;
        scrollView.frame = NSMakeRect(30, 50, 200, 375);
        scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        scrollView;
    });
    
    self.tableView = ({
        NSTableView *tableView = [[NSTableView alloc] init];
        tableView.frame = scrollView.bounds;
        tableView.allowsTypeSelect = YES;
        tableView.delegate = self;
        tableView.dataSource = self;
        NSTableColumn *column = [[NSTableColumn alloc] init];
        column.title = YMLocalizedString(@"assistant.autoReply.list");
        column.width = 200;
        [tableView addTableColumn:column];
        if ([YMWeChatPluginConfig sharedConfig].usingDarkTheme) {
            [[YMThemeManager shareInstance] changeTheme:tableView color:[YMWeChatPluginConfig sharedConfig].mainChatCellBackgroundColor];
        }
        tableView;
    });
    
    self.contentView = ({
        TKAutoReplyContentView *contentView = [[TKAutoReplyContentView alloc] init];
        contentView.frame = NSMakeRect(250, 50, 400, 375);
        contentView.hidden = YES;
        
        contentView;
    });
    
    self.addButton = ({
        NSButton *btn = [NSButton tk_buttonWithTitle:@"＋" target:self action:@selector(addModel)];
        btn.frame = NSMakeRect(30, 10, 40, 40);
        btn.bezelStyle = NSBezelStyleTexturedRounded;
        
        btn;
    });
    
    self.reduceButton = ({
        NSButton *btn = [NSButton tk_buttonWithTitle:@"－" target:self action:@selector(reduceModel)];
        btn.frame = NSMakeRect(80, 10, 40, 40);
        btn.bezelStyle = NSBezelStyleTexturedRounded;
        btn.enabled = NO;
        
        btn;
    });
    
    self.enableButton = ({
        NSButton *btn = [NSButton tk_checkboxWithTitle:YMLocalizedString(@"assistant.autoReply.enable") target:self action:@selector(clickEnableBtn:)];
        btn.frame = NSMakeRect(130, 20, 130, 20);
        btn.state = [[YMWeChatPluginConfig sharedConfig] autoReplyEnable];
        [YMThemeManager changeButtonTheme:btn];
        btn;
    });
    
    self.alert = ({
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:YMLocalizedString(@"assistant.autoReply.alert.confirm")];
        [alert setMessageText:YMLocalizedString(@"assistant.autoReply.alert.title")];
        [alert setInformativeText:YMLocalizedString(@"assistant.autoReply.alert.content")];
        
        alert;
    });
    
    scrollView.contentView.documentView = self.tableView;
    
    [self.window.contentView addSubviews:@[scrollView,
                                           self.contentView,
                                           self.addButton,
                                           self.reduceButton,
                                           self.enableButton]];
}
//导出
- (IBAction)exportbtntap:(id)sender {
    
    [[YMWeChatPluginConfig sharedConfig] saveAutoReplyModels];
    
    NSURL * fileBaseUrl = [[NSFileManager.defaultManager URLsForDirectory: NSDownloadsDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *fileurl = [fileBaseUrl URLByAppendingPathComponent:@"AutoReplyModels-bak.plist"];
    NSString * plistfilepath = [YMWeChatPluginConfig sharedConfig].autoReplyPlistFilePath;
    if ([NSFileManager.defaultManager fileExistsAtPath:fileurl.relativePath]) {
        [NSFileManager.defaultManager  removeItemAtPath:fileurl.relativePath error:nil];
    }
    [NSFileManager.defaultManager copyItemAtPath:plistfilepath toPath:fileurl.relativePath error:nil];
    
    [self exportcsvbtntap:nil];
    NSAlert * alert = ({
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"知道了"];
        [alert setMessageText:@"已导出至Download文件夹"];
        alert;
    });
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            
        }
    }];
}

- (IBAction)exportcsvbtntap:(id)sender {
    
    [[YMWeChatPluginConfig sharedConfig] saveAutoReplyModels];
    
    NSURL * fileBaseUrl = [[NSFileManager.defaultManager URLsForDirectory: NSDownloadsDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *fileurl = [fileBaseUrl URLByAppendingPathComponent:@"AutoReplyModels-bak.csv"];
    
    __block NSMutableString * csvstring = [NSMutableString stringWithString: @"技能名称,标准问题,标准问题的相似度阈值,补充用户问法（多个用##分隔）,机器人回答(多个用##分隔）,意图优先级"];
    __block NSString * headkeyword = nil;
    __block NSMutableString * headstring = [NSMutableString stringWithString: @""];
    [[YMWeChatPluginConfig sharedConfig].autoReplyModels enumerateObjectsUsingBlock:^(YMAutoReplyModel * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.keyword containsString:@"streamKeywords"]) {
            headkeyword = [NSString stringWithFormat:@"0|%@",obj.keyword];
            return;
        }
        NSString * key = [NSString stringWithFormat:@"%d|%@",(int)idx+1,obj.keyword];
        NSString * format = [NSString stringWithFormat:@"\r\n/关键字应答,\"%@\",0.9,\"%@\",\"%@\",0.9",key,key,obj.replyContent];
        [csvstring appendString:format];
        [headstring appendFormat:@"%@\r\n",key];
    }];
    NSString * format = [NSString stringWithFormat:@"\r\n/关键字应答,\"%@\",0.9,\"%@\",\"%@\",0.9",headkeyword,headkeyword,headstring];
    [csvstring appendString:format];
    
//    NSString * plistfilepath = [YMWeChatPluginConfig sharedConfig].autoReplyPlistFilePath;
    if ([NSFileManager.defaultManager fileExistsAtPath:fileurl.relativePath]) {
        [NSFileManager.defaultManager  removeItemAtPath:fileurl.relativePath error:nil];
    }
    NSError * error = nil;
    [csvstring writeToURL:fileurl atomically:YES encoding:NSUTF8StringEncoding error:&error];
 
}
//导入
- (IBAction)inportbtntap:(id)sender {
    
    NSURL * fileBaseUrl = [[NSFileManager.defaultManager URLsForDirectory: NSDownloadsDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *fileurl = [fileBaseUrl URLByAppendingPathComponent:@"AutoReplyModels.plist"];
    NSString * filepath = fileurl.relativePath ;
    NSArray* uploadarray = [NSArray arrayWithContentsOfFile:filepath];
    NSMutableArray * willaddarray = [NSMutableArray new];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:filepath]) {
        NSAlert * alert = ({
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"知道了"];
            [alert setMessageText:@"~/Download/AutoReplyModels.plist 文件不存在，请检查"];
            alert;
        });
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            
        }];
        return;
    }
    [self.autoReplyModels removeAllObjects];
    [uploadarray enumerateObjectsUsingBlock:^(NSDictionary *  _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        YMAutoReplyModel *model = [[YMAutoReplyModel alloc] initWithDict:item];
        if ([model.replyContent containsString:@"streamKeywords"]) {
            return;
        }
        [willaddarray addObject:model];
        [self.autoReplyModels addObject:model];
    }];
   
    NSAlert * alert = ({
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"知道了"];
        [alert setMessageText:@"已导入！！"];
        alert;
    });
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self.tableView reloadData];
        }
    }];
}

- (void)setup
{
    self.window.title = YMLocalizedString(@"assistant.autoReply.title");
    self.window.contentView.layer.backgroundColor = [kBG1 CGColor];
    [self.window.contentView.layer setNeedsDisplay];
    
    self.lastSelectIndex = -1;
    self.autoReplyModels = [[YMWeChatPluginConfig sharedConfig] autoReplyModels];
    [self.tableView reloadData];
    
    __weak typeof(self) weakSelf = self;
    self.contentView.endEdit = ^(void) {
        [weakSelf.tableView reloadData];
        if (weakSelf.lastSelectIndex != -1) {
            [weakSelf.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:weakSelf.lastSelectIndex] byExtendingSelection:YES];
        }
    };
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowShouldClosed:) name:NSWindowWillCloseNotification object:nil];
}

/**
 关闭窗口事件
 
 */
- (void)windowShouldClosed:(NSNotification *)notification
{
    if (notification.object != self.window) {
        return;
    }
    [[YMWeChatPluginConfig sharedConfig] saveAutoReplyModels];

}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - addButton & reduceButton ClickAction
- (void)addModel
{
    if (self.contentView.hidden) {
        self.contentView.hidden = NO;
    }
    __block NSInteger emptyModelIndex = -1;
    [self.autoReplyModels enumerateObjectsUsingBlock:^(YMAutoReplyModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
        if (model.hasEmptyKeywordOrReplyContent) {
            emptyModelIndex = idx;
            *stop = YES;
        }
    }];
    
    if (self.autoReplyModels.count > 0 && emptyModelIndex != -1) {
        [self.alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                if (self.tableView.selectedRow != -1) {
                    [self.tableView deselectRow:self.tableView.selectedRow];
                }
                [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:emptyModelIndex] byExtendingSelection:YES];
            }
        }];
        return;
    };
    
    YMAutoReplyModel *model = [[YMAutoReplyModel alloc] init];
    [self.autoReplyModels addObject:model];
    [self.tableView reloadData];
    self.contentView.model = model;
    
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.autoReplyModels.count - 1] byExtendingSelection:YES];
}

- (void)reduceModel
{
    NSInteger index = self.tableView.selectedRow;
    if (index > -1) {
        [self.autoReplyModels removeObjectAtIndex:index];
        [self.tableView reloadData];
        if (self.autoReplyModels.count == 0) {
            self.contentView.hidden = YES;
            self.reduceButton.enabled = NO;
        } else {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.autoReplyModels.count - 1] byExtendingSelection:YES];
        }
    }
}

- (void)clickEnableBtn:(NSButton *)btn
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFY_AUTO_REPLY_CHANGE object:nil];
}

#pragma mark - NSTableViewDataSource && NSTableViewDelegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.autoReplyModels.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    TKAutoReplyCell *cell = [[TKAutoReplyCell alloc] init];
    cell.frame = NSMakeRect(0, 0, self.tableView.frame.size.width, 40);
    cell.model = self.autoReplyModels[row];
     __weak typeof(self) weakSelf = self;
    cell.updateModel = ^{
        weakSelf.contentView.model = weakSelf.autoReplyModels[row];
    };
    return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 50;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView *tableView = notification.object;
    self.contentView.hidden = tableView.selectedRow == -1;
    self.reduceButton.enabled = tableView.selectedRow != -1;
    
    if (tableView.selectedRow != -1) {
        YMAutoReplyModel *model = self.autoReplyModels[tableView.selectedRow];
        self.contentView.model = model;
        self.lastSelectIndex = tableView.selectedRow;
        __block NSInteger emptyModelIndex = -1;
        [self.autoReplyModels enumerateObjectsUsingBlock:^(YMAutoReplyModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
            if (model.hasEmptyKeywordOrReplyContent) {
                emptyModelIndex = idx;
                *stop = YES;
            }
        }];
        
        if (emptyModelIndex != -1 && tableView.selectedRow != emptyModelIndex) {
            [self.alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                if (returnCode == NSAlertFirstButtonReturn) {
                    if (self.tableView.selectedRow != -1) {
                        [self.tableView deselectRow:self.tableView.selectedRow];
                    }
                    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:emptyModelIndex] byExtendingSelection:YES];
                }
            }];
        }
    }
}

@end
