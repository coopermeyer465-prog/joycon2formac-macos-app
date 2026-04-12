#import <AppKit/AppKit.h>

#import "../include/Joycon2BLEReceiver.h"
#import "../include/Joycon2VirtualHID.h"

@interface Joycon2AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSWindow* window;
@property (strong, nonatomic) NSTextField* statusLabel;
@property (strong, nonatomic) NSPopUpButton* modePopup;
@property (strong, nonatomic) NSButton* toggleButton;
@property (strong, nonatomic) NSTextField* configPathLabel;
@property (strong, nonatomic) NSTextView* configEditor;
@property (strong, nonatomic) Joycon2BLEReceiver* receiver;
@property (strong, nonatomic) Joycon2VirtualHID* hid;
@property (copy, nonatomic) NSString* configPath;
@property (assign, nonatomic) BOOL running;
@end

@implementation Joycon2AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    [self prepareConfig];
    [self buildWindow];
    [self startController];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    [self.hid stopEmulation];
}

- (void)prepareConfig {
    NSString* appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString* projectDir = [appSupportDir stringByAppendingPathComponent:@"Joycon2forMac"];
    [[NSFileManager defaultManager] createDirectoryAtPath:projectDir withIntermediateDirectories:YES attributes:nil error:nil];

    self.configPath = [projectDir stringByAppendingPathComponent:@"joycon2_config.json"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.configPath]) {
        NSString* bundledConfig = [[NSBundle mainBundle] pathForResource:@"joycon2_config" ofType:@"json"];
        if (bundledConfig) {
            [[NSFileManager defaultManager] copyItemAtPath:bundledConfig toPath:self.configPath error:nil];
        }
    }
}

- (void)loadConfigIntoEditor {
    NSString* configContents = [NSString stringWithContentsOfFile:self.configPath encoding:NSUTF8StringEncoding error:nil];
    [self.configEditor setString:configContents ?: @"{}"];
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 760, 620);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"Joycon2 for Mac"];

    NSView* contentView = self.window.contentView;

    NSTextField* title = [self labelWithFrame:NSMakeRect(24, 566, 420, 28)
                                         text:@"Joy-Con 2 mouse + keyboard for macOS"
                                         font:[NSFont boldSystemFontOfSize:20]];
    [contentView addSubview:title];

    self.statusLabel = [self labelWithFrame:NSMakeRect(24, 532, 600, 22)
                                       text:@"Status: starting"
                                       font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:self.statusLabel];

    NSTextField* modeLabel = [self labelWithFrame:NSMakeRect(24, 492, 80, 22)
                                              text:@"Mode"
                                              font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:modeLabel];

    self.modePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(110, 488, 160, 28) pullsDown:NO];
    [self.modePopup addItemsWithTitles:@[@"Hybrid", @"Mouse", @"Keyboard"]];
    [self.modePopup setTarget:self];
    [self.modePopup setAction:@selector(modeChanged:)];
    [contentView addSubview:self.modePopup];

    self.toggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(290, 486, 120, 32)];
    [self.toggleButton setBezelStyle:NSBezelStyleRounded];
    [self.toggleButton setTitle:@"Stop"];
    [self.toggleButton setTarget:self];
    [self.toggleButton setAction:@selector(toggleRunning:)];
    [contentView addSubview:self.toggleButton];

    NSButton* openConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(24, 446, 150, 30)];
    [openConfigButton setBezelStyle:NSBezelStyleRounded];
    [openConfigButton setTitle:@"Open Config Folder"];
    [openConfigButton setTarget:self];
    [openConfigButton setAction:@selector(openConfigFolder:)];
    [contentView addSubview:openConfigButton];

    NSButton* saveConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(188, 446, 110, 30)];
    [saveConfigButton setBezelStyle:NSBezelStyleRounded];
    [saveConfigButton setTitle:@"Save Config"];
    [saveConfigButton setTarget:self];
    [saveConfigButton setAction:@selector(saveConfig:)];
    [contentView addSubview:saveConfigButton];

    NSButton* reloadConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(312, 446, 120, 30)];
    [reloadConfigButton setBezelStyle:NSBezelStyleRounded];
    [reloadConfigButton setTitle:@"Reload Config"];
    [reloadConfigButton setTarget:self];
    [reloadConfigButton setAction:@selector(reloadConfig:)];
    [contentView addSubview:reloadConfigButton];

    self.configPathLabel = [self labelWithFrame:NSMakeRect(24, 410, 700, 32)
                                           text:[NSString stringWithFormat:@"Config: %@", self.configPath]
                                           font:[NSFont systemFontOfSize:11]];
    [self.configPathLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.configPathLabel];

    NSScrollView* editorScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 118, 712, 280)];
    [editorScrollView setHasVerticalScroller:YES];
    [editorScrollView setBorderType:NSBezelBorder];
    self.configEditor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 712, 280)];
    [self.configEditor setFont:[NSFont userFixedPitchFontOfSize:12]];
    [editorScrollView setDocumentView:self.configEditor];
    [contentView addSubview:editorScrollView];

    NSTextField* controls = [self labelWithFrame:NSMakeRect(24, 20, 700, 86)
                                             text:@"Edit the JSON config here to map any Joy-Con button to any keyboard key, mouse action, Launchpad, or screenshot/record action. Defaults: A = jump/space, B = shift, ZL = left click, ZR = right click, L/R = hotbar scroll, Down = drop item, Home = Launchpad, Camera = screenshot or hold for recording."
                                             font:[NSFont systemFontOfSize:12]];
    [controls setLineBreakMode:NSLineBreakByWordWrapping];
    [controls setUsesSingleLineMode:NO];
    [contentView addSubview:controls];

    [self loadConfigIntoEditor];
    [self.window makeKeyAndOrderFront:nil];
}

- (NSTextField*)labelWithFrame:(NSRect)frame text:(NSString*)text font:(NSFont*)font {
    NSTextField* label = [[NSTextField alloc] initWithFrame:frame];
    [label setEditable:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setStringValue:text ?: @""];
    [label setFont:font];
    return label;
}

- (EmulationMode)selectedMode {
    switch (self.modePopup.indexOfSelectedItem) {
        case 1:
            return MODE_MOUSE;
        case 2:
            return MODE_KEYBOARD;
        case 0:
        default:
            return MODE_HYBRID;
    }
}

- (void)startController {
    self.receiver = [[Joycon2BLEReceiver alloc] init];
    self.hid = [[Joycon2VirtualHID alloc] initWithMode:[self selectedMode] modeOverridden:YES configPath:self.configPath];
    void (^hidConnected)(void) = [[self.receiver.onConnected copy] autorelease];
    void (^hidFound)(NSString*, NSString*) = [[self.receiver.onDeviceFound copy] autorelease];
    void (^hidError)(NSString*) = [[self.receiver.onError copy] autorelease];

    __block Joycon2AppDelegate* weakSelf = self;
    self.receiver.onDeviceFound = ^(NSString* name, NSString* address) {
        if (hidFound) {
            hidFound(name, address);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Status: found %@, connecting", name ?: @"Joy-Con 2"];
        });
    };
    self.receiver.onConnected = ^{
        if (hidConnected) {
            hidConnected();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.stringValue = @"Status: Joy-Con connected";
        });
    };
    self.receiver.onError = ^(NSString* error) {
        if (hidError) {
            hidError(error);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Status: error - %@", error ?: @"unknown"];
        });
    };

    [self.hid startEmulation];
    self.running = YES;
    [self.statusLabel setStringValue:@"Status: scanning for Joy-Con 2 controllers"];
    [self.toggleButton setTitle:@"Stop"];
}

- (void)stopController {
    [self.hid stopEmulation];
    self.hid = nil;
    self.receiver = nil;
    self.running = NO;
    [self.statusLabel setStringValue:@"Status: stopped"];
    [self.toggleButton setTitle:@"Start"];
}

- (void)toggleRunning:(id)sender {
    if (self.running) {
        [self stopController];
    } else {
        [self startController];
    }
}

- (void)modeChanged:(id)sender {
    BOOL wasRunning = self.running;
    if (wasRunning) {
        [self stopController];
    }
    if (wasRunning) {
        [self startController];
    }
}

- (void)openConfigFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:self.configPath]]];
}

- (void)saveConfig:(id)sender {
    NSString* configContents = self.configEditor.string ?: @"{}";
    NSData* data = [configContents dataUsingEncoding:NSUTF8StringEncoding];
    NSError* parseError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (![json isKindOfClass:[NSDictionary class]]) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Status: invalid config JSON - %@", parseError.localizedDescription ?: @"parse error"];
        return;
    }

    NSError* writeError = nil;
    BOOL success = [configContents writeToFile:self.configPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (!success) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Status: failed to save config - %@", writeError.localizedDescription ?: @"write error"];
        return;
    }

    self.statusLabel.stringValue = @"Status: config saved, restarting controller";
    BOOL wasRunning = self.running;
    if (wasRunning) {
        [self stopController];
        [self startController];
    }
}

- (void)reloadConfig:(id)sender {
    [self loadConfigIntoEditor];
    self.statusLabel.stringValue = @"Status: config reloaded into editor";
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        Joycon2AppDelegate* delegate = [[Joycon2AppDelegate alloc] init];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app setDelegate:delegate];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
