#import <AppKit/AppKit.h>

#import "../include/Joycon2BLEReceiver.h"
#import "../include/Joycon2VirtualHID.h"

@interface Joycon2AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSWindow* window;
@property (strong, nonatomic) NSTextField* statusLabel;
@property (strong, nonatomic) NSPopUpButton* modePopup;
@property (strong, nonatomic) NSButton* toggleButton;
@property (strong, nonatomic) NSTextField* configPathLabel;
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

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 520, 320);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"Joycon2 for Mac"];

    NSView* contentView = self.window.contentView;

    NSTextField* title = [self labelWithFrame:NSMakeRect(24, 260, 360, 28)
                                         text:@"Joy-Con 2 mouse + keyboard for macOS"
                                         font:[NSFont boldSystemFontOfSize:20]];
    [contentView addSubview:title];

    self.statusLabel = [self labelWithFrame:NSMakeRect(24, 225, 420, 22)
                                       text:@"Status: starting"
                                       font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:self.statusLabel];

    NSTextField* modeLabel = [self labelWithFrame:NSMakeRect(24, 186, 80, 22)
                                              text:@"Mode"
                                              font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:modeLabel];

    self.modePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(110, 182, 160, 28) pullsDown:NO];
    [self.modePopup addItemsWithTitles:@[@"Hybrid", @"Mouse", @"Keyboard"]];
    [self.modePopup setTarget:self];
    [self.modePopup setAction:@selector(modeChanged:)];
    [contentView addSubview:self.modePopup];

    self.toggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(290, 180, 120, 32)];
    [self.toggleButton setBezelStyle:NSBezelStyleRounded];
    [self.toggleButton setTitle:@"Stop"];
    [self.toggleButton setTarget:self];
    [self.toggleButton setAction:@selector(toggleRunning:)];
    [contentView addSubview:self.toggleButton];

    NSButton* openConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(24, 142, 180, 30)];
    [openConfigButton setBezelStyle:NSBezelStyleRounded];
    [openConfigButton setTitle:@"Open Config Folder"];
    [openConfigButton setTarget:self];
    [openConfigButton setAction:@selector(openConfigFolder:)];
    [contentView addSubview:openConfigButton];

    self.configPathLabel = [self labelWithFrame:NSMakeRect(24, 108, 470, 32)
                                           text:[NSString stringWithFormat:@"Config: %@", self.configPath]
                                           font:[NSFont systemFontOfSize:11]];
    [self.configPathLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.configPathLabel];

    NSTextField* controls = [self labelWithFrame:NSMakeRect(24, 20, 470, 78)
                                             text:@"Defaults: A = jump/space, B = shift, R = left click in mouse mode, ZR = right click, L = scroll up, R = scroll down in hybrid, Home = Launchpad. Right stick moves the cursor when the cursor is hidden."
                                             font:[NSFont systemFontOfSize:12]];
    [controls setLineBreakMode:NSLineBreakByWordWrapping];
    [controls setUsesSingleLineMode:NO];
    [contentView addSubview:controls];

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
