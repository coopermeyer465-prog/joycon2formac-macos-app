#import <AppKit/AppKit.h>

#import "../include/Joycon2BLEReceiver.h"
#import "../include/Joycon2VirtualHID.h"

static NSInteger const kJoyConConfigVersion = 3;

static NSArray<NSString*>* ButtonOrder(void) {
    static NSArray<NSString*>* buttons = nil;
    if (!buttons) {
        buttons = [[NSArray alloc] initWithObjects:
                   @"A", @"B", @"X", @"Y", @"L", @"ZL", @"R", @"ZR",
                   @"UP", @"DOWN", @"LEFT", @"RIGHT",
                   @"SL(L)", @"SR(L)", @"SL(R)", @"SR(R)",
                   @"LS", @"RS", @"SELECT", @"START", @"HOME", @"CAMERA", @"CHAT", nil];
    }
    return buttons;
}

static NSDictionary<NSString*, NSNumber*>* ButtonMaskMapForApp(void) {
    static NSDictionary<NSString*, NSNumber*>* masks = nil;
    if (!masks) {
        masks = [[NSDictionary alloc] initWithObjectsAndKeys:
                 @(0x00000800), @"A",
                 @(0x00000400), @"B",
                 @(0x00000200), @"X",
                 @(0x00000100), @"Y",
                 @(0x40000000), @"L",
                 @(0x80000000), @"ZL",
                 @(0x00004000), @"R",
                 @(0x00008000), @"ZR",
                 @(0x02000000), @"UP",
                 @(0x01000000), @"DOWN",
                 @(0x08000000), @"LEFT",
                 @(0x04000000), @"RIGHT",
                 @(0x20000000), @"SL(L)",
                 @(0x10000000), @"SR(L)",
                 @(0x00002000), @"SL(R)",
                 @(0x00001000), @"SR(R)",
                 @(0x00080000), @"LS",
                 @(0x00040000), @"RS",
                 @(0x00010000), @"SELECT",
                 @(0x00020000), @"START",
                 @(0x00100000), @"HOME",
                 @(0x00200000), @"CAMERA",
                 @(0x00400000), @"CHAT",
                 nil];
    }
    return masks;
}

static NSDictionary<NSString*, NSString*>* ButtonDisplayNames(void) {
    static NSDictionary<NSString*, NSString*>* names = nil;
    if (!names) {
        names = [[NSDictionary alloc] initWithObjectsAndKeys:
                 @"A", @"A",
                 @"B", @"B",
                 @"X", @"X",
                 @"Y", @"Y",
                 @"L", @"L",
                 @"ZL", @"ZL",
                 @"R", @"R",
                 @"ZR", @"ZR",
                 @"D-Pad Up", @"UP",
                 @"D-Pad Down", @"DOWN",
                 @"D-Pad Left", @"LEFT",
                 @"D-Pad Right", @"RIGHT",
                 @"SL Left", @"SL(L)",
                 @"SR Left", @"SR(L)",
                 @"SL Right", @"SL(R)",
                 @"SR Right", @"SR(R)",
                 @"Left Stick Press", @"LS",
                 @"Right Stick Press", @"RS",
                 @"Minus", @"SELECT",
                 @"Plus", @"START",
                 @"Home", @"HOME",
                 @"Capture", @"CAMERA",
                 @"GameChat", @"CHAT",
                 nil];
    }
    return names;
}

static NSDictionary<NSNumber*, NSString*>* KeyNamesByCode(void) {
    static NSDictionary<NSNumber*, NSString*>* names = nil;
    if (!names) {
        names = [[NSDictionary alloc] initWithObjectsAndKeys:
                 @"a", @0, @"s", @1, @"d", @2, @"f", @3, @"h", @4, @"g", @5, @"z", @6, @"x", @7,
                 @"c", @8, @"v", @9, @"b", @11, @"q", @12, @"w", @13, @"e", @14, @"r", @15,
                 @"y", @16, @"t", @17, @"1", @18, @"2", @19, @"3", @20, @"4", @21, @"6", @22,
                 @"5", @23, @"equal", @24, @"9", @25, @"7", @26, @"minus", @27, @"8", @28,
                 @"0", @29, @"right_bracket", @30, @"o", @31, @"u", @32, @"left_bracket", @33,
                 @"i", @34, @"p", @35, @"return", @36, @"l", @37, @"j", @38, @"quote", @39,
                 @"k", @40, @"semicolon", @41, @"backslash", @42, @"comma", @43, @"slash", @44,
                 @"n", @45, @"m", @46, @"period", @47, @"tab", @48, @"space", @49, @"grave", @50,
                 @"delete", @51, @"escape", @53, @"left_command", @55, @"left_shift", @56,
                 @"caps_lock", @57, @"left_option", @58, @"left_control", @59, @"right_shift", @60,
                 @"right_option", @61, @"right_control", @62, @"left_arrow", @123,
                 @"right_arrow", @124, @"down_arrow", @125, @"up_arrow", @126,
                 @"f1", @122, @"f2", @120, @"f3", @99, @"f4", @118, @"f5", @96,
                 nil];
    }
    return names;
}

static NSString* FriendlyActionString(NSString* action) {
    if (![action isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSDictionary* friendly = @{
        @"key:space": @"Space",
        @"key:left_shift": @"Shift",
        @"key:delete": @"Delete",
        @"key:e": @"Inventory",
        @"key:f": @"Use / Interact",
        @"key:g": @"Emote",
        @"key:t": @"Chat",
        @"key:q": @"Drop Item",
        @"key:f5": @"Change POV",
        @"key:escape": @"Escape",
        @"mouse:left": @"Mouse Left Click",
        @"mouse:right": @"Mouse Right Click",
        @"mouse:middle": @"Mouse Middle Click",
        @"mouse:scroll_up": @"Scroll Up",
        @"mouse:scroll_down": @"Scroll Down",
        @"mouse:scroll_left": @"Scroll Left",
        @"mouse:scroll_right": @"Scroll Right",
        @"system:launchpad": @"Launchpad",
        @"system:screenshot": @"Screenshot / Record",
        @"system:discord": @"Open Discord"
    };
    NSString* exact = friendly[action];
    return exact ?: action;
}

static NSString* BindingSummaryFromValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"Hold: %@", FriendlyActionString(value)];
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        return @"Not set";
    }

    NSMutableArray<NSString*>* parts = [NSMutableArray array];
    NSString* press = value[@"press"] ?: value[@"hold"];
    NSString* tap = value[@"tap"] ?: value[@"click"];
    if (press.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"Hold: %@", FriendlyActionString(press)]];
    }
    if (tap.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"Tap: %@", FriendlyActionString(tap)]];
    }
    return parts.count > 0 ? [parts componentsJoinedByString:@" | "] : @"Not set";
}

@interface Joycon2AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (strong, nonatomic) NSWindow* window;
@property (strong, nonatomic) NSTextField* statusLabel;
@property (strong, nonatomic) NSPopUpButton* modePopup;
@property (strong, nonatomic) NSButton* toggleButton;
@property (strong, nonatomic) NSTextField* configPathLabel;
@property (strong, nonatomic) NSTableView* bindingsTable;
@property (strong, nonatomic) Joycon2BLEReceiver* receiver;
@property (strong, nonatomic) Joycon2VirtualHID* hid;
@property (copy, nonatomic) NSString* configPath;
@property (strong, nonatomic) NSMutableSet* activeControllers;
@property (strong, nonatomic) NSMutableDictionary* configDocument;
@property (strong, nonatomic) NSMutableDictionary* lastButtonsByController;
@property (strong, nonatomic) NSMutableDictionary* batteryStatusBySide;
@property (copy, nonatomic) NSString* pendingButtonName;
@property (assign, nonatomic) BOOL awaitingJoyConButton;
@property (assign, nonatomic) BOOL running;
@end

@implementation Joycon2AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    [self prepareConfig];
    [self loadConfigDocument];
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
    NSString* projectDir = [appSupportDir stringByAppendingPathComponent:@"JoyCon2forMac"];
    [[NSFileManager defaultManager] createDirectoryAtPath:projectDir withIntermediateDirectories:YES attributes:nil error:nil];

    self.configPath = [projectDir stringByAppendingPathComponent:@"joycon2_config.json"];
    NSString* bundledConfig = [[NSBundle mainBundle] pathForResource:@"joycon2_config" ofType:@"json"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.configPath]) {
        if (bundledConfig) {
            [[NSFileManager defaultManager] copyItemAtPath:bundledConfig toPath:self.configPath error:nil];
        }
        return;
    }

    NSData* existingData = [NSData dataWithContentsOfFile:self.configPath];
    NSDictionary* existingConfig = existingData ? [NSJSONSerialization JSONObjectWithData:existingData options:0 error:nil] : nil;
    NSInteger existingVersion = [[existingConfig objectForKey:@"configVersion"] integerValue];
    if (existingVersion >= kJoyConConfigVersion || !bundledConfig) {
        return;
    }

    NSString* backupPath = [projectDir stringByAppendingPathComponent:@"joycon2_config.backup.json"];
    [[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:self.configPath toPath:backupPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:self.configPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:bundledConfig toPath:self.configPath error:nil];
}

- (NSString*)currentModeKey {
    switch (self.modePopup.indexOfSelectedItem) {
        case 1:
            return @"mouse";
        case 2:
            return @"keyboard";
        case 0:
        default:
            return @"hybrid";
    }
}

- (void)loadConfigDocument {
    NSData* data = [NSData dataWithContentsOfFile:self.configPath];
    NSDictionary* parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        parsed = [NSMutableDictionary dictionary];
    }
    self.configDocument = [NSMutableDictionary dictionaryWithDictionary:parsed];
    self.configDocument[@"configVersion"] = @(kJoyConConfigVersion);
    if (![self.configDocument[@"modeBindings"] isKindOfClass:[NSDictionary class]]) {
        self.configDocument[@"modeBindings"] = [NSMutableDictionary dictionary];
    }
}

- (NSInteger)estimatedBatteryPercentFromVoltage:(double)voltage {
    double normalized = (voltage - 3.2) / 0.95;
    NSInteger percent = (NSInteger)llround(fmax(0.0, fmin(1.0, normalized)) * 100.0);
    return percent;
}

- (NSString*)composeLiveStatusForControllerLabel:(NSString*)controllerLabel {
    NSMutableArray<NSString*>* batteryParts = [NSMutableArray array];
    NSString* leftBattery = self.batteryStatusBySide[@"Left"];
    NSString* rightBattery = self.batteryStatusBySide[@"Right"];
    if (leftBattery.length > 0) {
        [batteryParts addObject:[NSString stringWithFormat:@"L %@", leftBattery]];
    }
    if (rightBattery.length > 0) {
        [batteryParts addObject:[NSString stringWithFormat:@"R %@", rightBattery]];
    }
    if (batteryParts.count == 0) {
        return [NSString stringWithFormat:@"Status: receiving input from %@", controllerLabel];
    }
    return [NSString stringWithFormat:@"Status: receiving input from %@ | Battery: %@", controllerLabel, [batteryParts componentsJoinedByString:@"  "]];
}

- (NSMutableDictionary*)mutableModeBindingsForCurrentMode {
    NSMutableDictionary* modeBindings = self.configDocument[@"modeBindings"];
    if (![modeBindings isKindOfClass:[NSMutableDictionary class]]) {
        modeBindings = [NSMutableDictionary dictionaryWithDictionary:modeBindings ?: @{}];
        self.configDocument[@"modeBindings"] = modeBindings;
    }

    NSString* modeKey = [self currentModeKey];
    id current = modeBindings[modeKey];
    if (![current isKindOfClass:[NSDictionary class]]) {
        current = [NSMutableDictionary dictionary];
        modeBindings[modeKey] = current;
    } else if (![current isKindOfClass:[NSMutableDictionary class]]) {
        current = [NSMutableDictionary dictionaryWithDictionary:current];
        modeBindings[modeKey] = current;
    }
    return (NSMutableDictionary*)current;
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 820, 640);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"JoyCon2 for Mac"];

    NSView* contentView = self.window.contentView;

    NSTextField* title = [self labelWithFrame:NSMakeRect(24, 592, 480, 28)
                                         text:@"Joy-Con 2 mapping + mouse for macOS"
                                         font:[NSFont boldSystemFontOfSize:20]];
    [contentView addSubview:title];

    self.statusLabel = [self labelWithFrame:NSMakeRect(24, 560, 760, 22)
                                       text:@"Status: starting"
                                       font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:self.statusLabel];

    NSTextField* modeLabel = [self labelWithFrame:NSMakeRect(24, 522, 80, 22)
                                              text:@"Mode"
                                              font:[NSFont systemFontOfSize:13]];
    [contentView addSubview:modeLabel];

    self.modePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(110, 518, 170, 28) pullsDown:NO];
    [self.modePopup addItemsWithTitles:@[@"Hybrid", @"Mouse", @"Keyboard"]];
    [self.modePopup setTarget:self];
    [self.modePopup setAction:@selector(modeChanged:)];
    [contentView addSubview:self.modePopup];

    self.toggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 516, 120, 32)];
    [self.toggleButton setBezelStyle:NSBezelStyleRounded];
    [self.toggleButton setTitle:@"Stop"];
    [self.toggleButton setTarget:self];
    [self.toggleButton setAction:@selector(toggleRunning:)];
    [contentView addSubview:self.toggleButton];

    NSButton* mapButton = [[NSButton alloc] initWithFrame:NSMakeRect(24, 476, 170, 30)];
    [mapButton setBezelStyle:NSBezelStyleRounded];
    [mapButton setTitle:@"Map Joy-Con Button"];
    [mapButton setTarget:self];
    [mapButton setAction:@selector(beginMappingFlow:)];
    [contentView addSubview:mapButton];

    NSButton* resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(208, 476, 130, 30)];
    [resetButton setBezelStyle:NSBezelStyleRounded];
    [resetButton setTitle:@"Restore Defaults"];
    [resetButton setTarget:self];
    [resetButton setAction:@selector(restoreDefaults:)];
    [contentView addSubview:resetButton];

    NSButton* openConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(352, 476, 150, 30)];
    [openConfigButton setBezelStyle:NSBezelStyleRounded];
    [openConfigButton setTitle:@"Open Config Folder"];
    [openConfigButton setTarget:self];
    [openConfigButton setAction:@selector(openConfigFolder:)];
    [contentView addSubview:openConfigButton];

    self.configPathLabel = [self labelWithFrame:NSMakeRect(24, 438, 760, 32)
                                           text:[NSString stringWithFormat:@"Config: %@", self.configPath]
                                           font:[NSFont systemFontOfSize:11]];
    [self.configPathLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.configPathLabel];

    NSScrollView* tableScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 110, 772, 312)];
    [tableScrollView setHasVerticalScroller:YES];
    [tableScrollView setBorderType:NSBezelBorder];

    self.bindingsTable = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 772, 312)];
    NSTableColumn* buttonColumn = [[NSTableColumn alloc] initWithIdentifier:@"button"];
    [buttonColumn setTitle:@"Joy-Con Button"];
    [buttonColumn setWidth:180];
    NSTableColumn* bindingColumn = [[NSTableColumn alloc] initWithIdentifier:@"binding"];
    [bindingColumn setTitle:@"Current Mapping"];
    [bindingColumn setWidth:580];
    [self.bindingsTable addTableColumn:buttonColumn];
    [self.bindingsTable addTableColumn:bindingColumn];
    [self.bindingsTable setDelegate:self];
    [self.bindingsTable setDataSource:self];
    [self.bindingsTable setHeaderView:nil];
    [self.bindingsTable setRowHeight:24.0];
    [tableScrollView setDocumentView:self.bindingsTable];
    [contentView addSubview:tableScrollView];

    NSTextField* controls = [self labelWithFrame:NSMakeRect(24, 24, 772, 68)
                                             text:@"Click “Map Joy-Con Button”, press the controller button you want to change, then choose whether it should act as a held control, a tap action, or both. Keyboard bindings are learned by pressing the Mac key you want. Mouse actions, Launchpad, Screenshot / Record, and Discord are selectable from popups."
                                             font:[NSFont systemFontOfSize:12]];
    [controls setLineBreakMode:NSLineBreakByWordWrapping];
    [controls setUsesSingleLineMode:NO];
    [contentView addSubview:controls];

    [self.window makeKeyAndOrderFront:nil];
    [self.bindingsTable reloadData];
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

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    return ButtonOrder().count;
}

- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    NSString* buttonName = ButtonOrder()[row];
    if ([tableColumn.identifier isEqualToString:@"button"]) {
        return ButtonDisplayNames()[buttonName] ?: buttonName;
    }

    NSDictionary* modeBindings = [self mutableModeBindingsForCurrentMode];
    id value = modeBindings[buttonName];
    return BindingSummaryFromValue(value);
}

- (void)refreshBindingsTable {
    [self.bindingsTable reloadData];
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
    self.activeControllers = [NSMutableSet set];
    self.lastButtonsByController = [NSMutableDictionary dictionary];
    self.batteryStatusBySide = [NSMutableDictionary dictionary];
    self.receiver = [Joycon2BLEReceiver sharedInstance];
    self.hid = [[Joycon2VirtualHID alloc] initWithMode:[self selectedMode] modeOverridden:YES configPath:self.configPath];
    void (^hidConnected)(void) = [[self.receiver.onConnected copy] autorelease];
    void (^hidFound)(NSString*, NSString*) = [[self.receiver.onDeviceFound copy] autorelease];
    void (^hidData)(NSDictionary*) = [[self.receiver.onDataReceived copy] autorelease];
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
            weakSelf.statusLabel.stringValue = @"Status: Joy-Con connected, waiting for input";
        });
    };
    self.receiver.onDataReceived = ^(NSDictionary* data) {
        if (hidData) {
            hidData(data);
        }

        NSString* controllerKey = data[@"PeripheralIdentifier"] ?: @"unknown";
        uint32_t buttons = (uint32_t)[data[@"Buttons"] unsignedLongLongValue];
        uint32_t previousButtons = (uint32_t)[weakSelf.lastButtonsByController[controllerKey] unsignedIntValue];
        weakSelf.lastButtonsByController[controllerKey] = @(buttons);

        NSString* deviceType = data[@"DeviceType"] ?: @"Unknown";
        NSNumber* batteryVoltage = data[@"BatteryVoltage"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([deviceType isEqualToString:@"L"]) {
                [weakSelf.activeControllers addObject:@"Left"];
                if ([batteryVoltage isKindOfClass:[NSNumber class]]) {
                    NSInteger percent = [weakSelf estimatedBatteryPercentFromVoltage:[batteryVoltage doubleValue]];
                    weakSelf.batteryStatusBySide[@"Left"] = [NSString stringWithFormat:@"%ld%% est", (long)percent];
                }
            } else if ([deviceType isEqualToString:@"R"]) {
                [weakSelf.activeControllers addObject:@"Right"];
                if ([batteryVoltage isKindOfClass:[NSNumber class]]) {
                    NSInteger percent = [weakSelf estimatedBatteryPercentFromVoltage:[batteryVoltage doubleValue]];
                    weakSelf.batteryStatusBySide[@"Right"] = [NSString stringWithFormat:@"%ld%% est", (long)percent];
                }
            }

            NSString* controllerLabel = @"Joy-Con";
            if (weakSelf.activeControllers.count == 2) {
                controllerLabel = @"Left + Right Joy-Con";
            } else if ([weakSelf.activeControllers containsObject:@"Right"]) {
                controllerLabel = @"Right Joy-Con";
            } else if ([weakSelf.activeControllers containsObject:@"Left"]) {
                controllerLabel = @"Left Joy-Con";
            }

            if (weakSelf.awaitingJoyConButton) {
                uint32_t newlyPressed = buttons & ~previousButtons;
                for (NSString* candidate in ButtonOrder()) {
                    uint32_t mask = (uint32_t)[ButtonMaskMapForApp()[candidate] unsignedIntValue];
                    if ((newlyPressed & mask) != 0) {
                        weakSelf.awaitingJoyConButton = NO;
                        weakSelf.pendingButtonName = candidate;
                        weakSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Status: mapping %@", ButtonDisplayNames()[candidate] ?: candidate];
                        [weakSelf runMappingFlowForButton:candidate];
                        return;
                    }
                }
            }

            weakSelf.statusLabel.stringValue = [weakSelf composeLiveStatusForControllerLabel:controllerLabel];
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
    self.activeControllers = nil;
    self.lastButtonsByController = nil;
    self.batteryStatusBySide = nil;
    self.awaitingJoyConButton = NO;
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
    [self refreshBindingsTable];
    if (wasRunning) {
        [self startController];
    }
}

- (void)openConfigFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:self.configPath]]];
}

- (void)restoreDefaults:(id)sender {
    NSString* bundledConfig = [[NSBundle mainBundle] pathForResource:@"joycon2_config" ofType:@"json"];
    if (!bundledConfig) {
        self.statusLabel.stringValue = @"Status: bundled default config not found";
        return;
    }

    [[NSFileManager defaultManager] removeItemAtPath:self.configPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:bundledConfig toPath:self.configPath error:nil];
    [self loadConfigDocument];
    [self refreshBindingsTable];
    self.statusLabel.stringValue = @"Status: restored bundled defaults";
    if (self.running) {
        [self stopController];
        [self startController];
    }
}

- (void)beginMappingFlow:(id)sender {
    self.awaitingJoyConButton = YES;
    self.pendingButtonName = nil;
    self.statusLabel.stringValue = @"Status: press the Joy-Con button you want to map";
}

- (NSString*)promptWithTitle:(NSString*)title message:(NSString*)message options:(NSArray<NSString*>*)options {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:title];
    [alert setInformativeText:message ?: @""];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];

    NSPopUpButton* popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 280, 26) pullsDown:NO];
    [popup addItemsWithTitles:options];
    [alert setAccessoryView:popup];

    NSModalResponse response = [alert runModal];
    NSString* selected = response == NSAlertFirstButtonReturn ? popup.titleOfSelectedItem : nil;
    [popup release];
    [alert release];
    return selected;
}

- (NSString*)keyboardBindingFromCapturedKey {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Press a key on your Mac"];
    [alert setInformativeText:@"The next key you press will be assigned to this Joy-Con button."];
    [alert addButtonWithTitle:@"Cancel"];

    __block NSString* capturedKey = nil;
    id monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent* (NSEvent* event) {
        capturedKey = [KeyNamesByCode() objectForKey:@(event.keyCode)];
        if (capturedKey.length > 0) {
            [NSApp stopModalWithCode:NSModalResponseOK];
            return nil;
        }
        return event;
    }];

    NSModalResponse response = [alert runModal];
    [NSEvent removeMonitor:monitor];
    [alert release];
    if (response != NSModalResponseOK || capturedKey.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"key:%@", capturedKey];
}

- (NSString*)promptForActionWithPrompt:(NSString*)prompt {
    NSString* category = [self promptWithTitle:@"Choose Output Type"
                                       message:prompt
                                       options:@[@"Keyboard Key", @"Mouse Action", @"System Action", @"Clear Binding"]];
    if (!category) {
        return nil;
    }
    if ([category isEqualToString:@"Clear Binding"]) {
        return @"";
    }
    if ([category isEqualToString:@"Keyboard Key"]) {
        return [self keyboardBindingFromCapturedKey];
    }
    if ([category isEqualToString:@"Mouse Action"]) {
        NSDictionary* actionMap = @{
            @"Left Click": @"mouse:left",
            @"Right Click": @"mouse:right",
            @"Middle Click": @"mouse:middle",
            @"Scroll Up": @"mouse:scroll_up",
            @"Scroll Down": @"mouse:scroll_down",
            @"Scroll Left": @"mouse:scroll_left",
            @"Scroll Right": @"mouse:scroll_right"
        };
        NSString* label = [self promptWithTitle:@"Choose Mouse Action"
                                        message:prompt
                                        options:actionMap.allKeys];
        return label ? actionMap[label] : nil;
    }

    NSDictionary* systemMap = @{
        @"Launchpad": @"system:launchpad",
        @"Screenshot / Screen Record": @"system:screenshot",
        @"Open Discord": @"system:discord",
        @"Change POV (Fn+F5)": @"system:pov",
        @"Double W": @"system:double_w"
    };
    NSString* label = [self promptWithTitle:@"Choose System Action"
                                    message:prompt
                                    options:systemMap.allKeys];
    return label ? systemMap[label] : nil;
}

- (void)saveConfigDocumentAndRestartIfNeeded {
    self.configDocument[@"configVersion"] = @(kJoyConConfigVersion);
    NSData* data = [NSJSONSerialization dataWithJSONObject:self.configDocument options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:self.configPath atomically:YES];
    [self loadConfigDocument];
    [self refreshBindingsTable];
    if (self.running) {
        [self stopController];
        [self startController];
    }
}

- (void)applyPressAction:(NSString*)pressAction tapAction:(NSString*)tapAction forButton:(NSString*)buttonName {
    NSMutableDictionary* modeBindings = [self mutableModeBindingsForCurrentMode];
    if (pressAction.length == 0 && tapAction.length == 0) {
        [modeBindings removeObjectForKey:buttonName];
    } else if (pressAction.length > 0 && tapAction.length == 0) {
        modeBindings[buttonName] = pressAction;
    } else {
        NSMutableDictionary* entry = [NSMutableDictionary dictionary];
        if (pressAction.length > 0) {
            entry[@"press"] = pressAction;
        }
        if (tapAction.length > 0) {
            entry[@"tap"] = tapAction;
        }
        modeBindings[buttonName] = entry;
    }
    [self saveConfigDocumentAndRestartIfNeeded];
}

- (void)runMappingFlowForButton:(NSString*)buttonName {
    NSString* triggerChoice = [self promptWithTitle:@"Choose Trigger Type"
                                            message:[NSString stringWithFormat:@"Choose how %@ should behave.", ButtonDisplayNames()[buttonName] ?: buttonName]
                                            options:@[@"Press or Hold", @"Tap"]];
    if (!triggerChoice) {
        self.statusLabel.stringValue = @"Status: mapping cancelled";
        return;
    }

    NSString* pressAction = nil;
    NSString* tapAction = nil;
    if ([triggerChoice isEqualToString:@"Tap"]) {
        tapAction = [self promptForActionWithPrompt:@"Choose what should happen when the Joy-Con button is tapped."];
    } else {
        pressAction = [self promptForActionWithPrompt:@"Choose what should happen when this button is pressed or held."];
    }

    if (pressAction == nil && tapAction == nil) {
        self.statusLabel.stringValue = @"Status: mapping cancelled";
        return;
    }

    [self applyPressAction:pressAction tapAction:tapAction forButton:buttonName];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Status: mapped %@", ButtonDisplayNames()[buttonName] ?: buttonName];
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
