#import "../include/Joycon2VirtualHID.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

#include <algorithm>
#include <cmath>
#include <cctype>
#include <map>
#include <set>
#include <string>
#include <unistd.h>

typedef NS_ENUM(NSInteger, BindingActionKind) {
    BindingActionKindNone = 0,
    BindingActionKindKey,
    BindingActionKindMouseButton,
    BindingActionKindScroll,
    BindingActionKindLaunchpad,
    BindingActionKindScreenshot,
    BindingActionKindOpenURL,
    BindingActionKindMacro
};

typedef NS_ENUM(NSInteger, BindingMacroKind) {
    BindingMacroKindNone = 0,
    BindingMacroKindPOV,
    BindingMacroKindDoubleW,
    BindingMacroKindSpaceClick,
    BindingMacroKindShiftDelete
};

struct MouseConfig {
    double sensitivity = 0.35;
    double deadzone = 2.0;
    double smoothing = 0.6;
    double maxStep = 45.0;
    double jumpThreshold = 800.0;
    double calibrationSeconds = 1.0;
    BOOL invertX = NO;
    BOOL invertY = NO;
    int scrollStep = 3;
};

struct KeyboardConfig {
    double stickDeadzone = 0.35;
    std::string leftStickMode = "wasd";
};

struct BindingAction {
    BindingActionKind kind = BindingActionKindNone;
    BindingMacroKind macroKind = BindingMacroKindNone;
    CGKeyCode keyCode = 0;
    CGMouseButton mouseButton = kCGMouseButtonLeft;
    int scrollX = 0;
    int scrollY = 0;
    std::string url;
    std::string description;
};

struct ButtonBinding {
    BindingAction pressAction;
    BindingAction tapAction;
};

struct RuntimeConfig {
    EmulationMode defaultMode = MODE_HYBRID;
    bool enableLeftJoyCon = true;
    MouseConfig mouse;
    KeyboardConfig keyboard;
    std::map<uint32_t, ButtonBinding> bindings;
    std::map<uint32_t, ButtonBinding> mouseBindings;
    std::map<uint32_t, ButtonBinding> keyboardBindings;
    std::map<uint32_t, ButtonBinding> hybridBindings;
    std::string loadedFrom;
};

struct DeviceState {
    uint32_t lastButtons = 0;
    bool hasMouseSample = false;
    int16_t lastMouseX = 0;
    int16_t lastMouseY = 0;
    double smoothedDeltaX = 0.0;
    double smoothedDeltaY = 0.0;
    double driftBiasX = 0.0;
    double driftBiasY = 0.0;
    CFAbsoluteTime calibrationEndsAt = 0.0;
    CFAbsoluteTime screenshotPressedAt = 0.0;
    bool screenshotHoldTriggered = false;
    std::map<uint32_t, CFAbsoluteTime> buttonPressedAt;
    bool stickUp = false;
    bool stickDown = false;
    bool stickLeft = false;
    bool stickRight = false;
};

static std::string ToLower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

static std::string UpperNoSpaces(std::string value) {
    std::string normalized;
    normalized.reserve(value.size());
    for (unsigned char ch : value) {
        if (std::isspace(ch)) {
            continue;
        }
        normalized.push_back(static_cast<char>(std::toupper(ch)));
    }
    return normalized;
}

static std::string NormalizeKeyName(std::string value) {
    value = ToLower(value);
    std::replace(value.begin(), value.end(), '-', '_');
    std::replace(value.begin(), value.end(), ' ', '_');
    return value;
}

static double ClampDouble(double value, double minimum, double maximum) {
    if (value < minimum) {
        return minimum;
    }
    if (value > maximum) {
        return maximum;
    }
    return value;
}

static std::map<std::string, uint32_t> ButtonMaskMap() {
    return {
        {"ZL", 0x80000000}, {"L", 0x40000000}, {"SELECT", 0x00010000},
        {"LS", 0x00080000}, {"↓", 0x01000000}, {"UP", 0x02000000},
        {"RIGHT", 0x04000000}, {"LEFT", 0x08000000}, {"CAMERA", 0x00200000},
        {"SR(L)", 0x10000000}, {"SL(L)", 0x20000000}, {"HOME", 0x00100000},
        {"CHAT", 0x00400000}, {"START", 0x00020000}, {"SR(R)", 0x00001000},
        {"SL(R)", 0x00002000}, {"R", 0x00004000}, {"ZR", 0x00008000},
        {"RS", 0x00040000}, {"Y", 0x00000100}, {"X", 0x00000200},
        {"B", 0x00000400}, {"A", 0x00000800},
        {"DOWN", 0x01000000}, {"^", 0x02000000}, {"→", 0x04000000}, {"←", 0x08000000}
    };
}

static std::map<std::string, CGKeyCode> KeyCodeMap() {
    return {
        {"a", 0}, {"s", 1}, {"d", 2}, {"f", 3}, {"h", 4}, {"g", 5}, {"z", 6}, {"x", 7},
        {"c", 8}, {"v", 9}, {"b", 11}, {"q", 12}, {"w", 13}, {"e", 14}, {"r", 15},
        {"y", 16}, {"t", 17}, {"1", 18}, {"2", 19}, {"3", 20}, {"4", 21}, {"6", 22},
        {"5", 23}, {"equal", 24}, {"9", 25}, {"7", 26}, {"minus", 27}, {"8", 28},
        {"0", 29}, {"right_bracket", 30}, {"o", 31}, {"u", 32}, {"left_bracket", 33},
        {"i", 34}, {"p", 35}, {"return", 36}, {"enter", 36}, {"l", 37}, {"j", 38},
        {"quote", 39}, {"k", 40}, {"semicolon", 41}, {"backslash", 42}, {"comma", 43},
        {"slash", 44}, {"n", 45}, {"m", 46}, {"period", 47}, {"tab", 48}, {"space", 49},
        {"grave", 50}, {"delete", 51}, {"escape", 53}, {"esc", 53}, {"command", 55},
        {"left_command", 55}, {"shift", 56}, {"left_shift", 56}, {"caps_lock", 57},
        {"option", 58}, {"left_option", 58}, {"alt", 58}, {"control", 59},
        {"left_control", 59}, {"right_shift", 60}, {"right_option", 61},
        {"right_alt", 61}, {"right_control", 62}, {"left_arrow", 123},
        {"right_arrow", 124}, {"down_arrow", 125}, {"up_arrow", 126},
        {"f1", 122}, {"f2", 120}, {"f3", 99}, {"f4", 118}, {"f5", 96}
    };
}

static EmulationMode ModeFromString(NSString* value) {
    NSString* lower = [[value lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([lower isEqualToString:@"mouse"]) {
        return MODE_MOUSE;
    }
    if ([lower isEqualToString:@"keyboard"]) {
        return MODE_KEYBOARD;
    }
    return MODE_HYBRID;
}

static NSString* ModeName(EmulationMode mode) {
    switch (mode) {
        case MODE_MOUSE:
            return @"mouse";
        case MODE_KEYBOARD:
            return @"keyboard";
        case MODE_HYBRID:
        default:
            return @"hybrid";
    }
}

static BindingAction ParseActionString(NSString* actionString, const RuntimeConfig& config) {
    BindingAction action;
    if (![actionString isKindOfClass:[NSString class]]) {
        return action;
    }

    NSString* trimmed = [actionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return action;
    }

    NSArray<NSString*>* parts = [trimmed componentsSeparatedByString:@":"];
    if (parts.count != 2) {
        return action;
    }

    NSString* category = [parts[0] lowercaseString];
    std::string target = NormalizeKeyName([parts[1] UTF8String]);
    action.description = [trimmed UTF8String];

    if ([category isEqualToString:@"key"]) {
        auto keyCodes = KeyCodeMap();
        auto it = keyCodes.find(target);
        if (it != keyCodes.end()) {
            action.kind = BindingActionKindKey;
            action.keyCode = it->second;
        }
        return action;
    }

    if ([category isEqualToString:@"mouse"]) {
        if (target == "left") {
            action.kind = BindingActionKindMouseButton;
            action.mouseButton = kCGMouseButtonLeft;
        } else if (target == "right") {
            action.kind = BindingActionKindMouseButton;
            action.mouseButton = kCGMouseButtonRight;
        } else if (target == "middle" || target == "center") {
            action.kind = BindingActionKindMouseButton;
            action.mouseButton = kCGMouseButtonCenter;
        } else if (target == "scroll_up") {
            action.kind = BindingActionKindScroll;
            action.scrollY = config.mouse.scrollStep;
        } else if (target == "scroll_down") {
            action.kind = BindingActionKindScroll;
            action.scrollY = -config.mouse.scrollStep;
        } else if (target == "scroll_left") {
            action.kind = BindingActionKindScroll;
            action.scrollX = -config.mouse.scrollStep;
        } else if (target == "scroll_right") {
            action.kind = BindingActionKindScroll;
            action.scrollX = config.mouse.scrollStep;
        }
    }

    if ([category isEqualToString:@"system"]) {
        if (target == "launchpad") {
            action.kind = BindingActionKindLaunchpad;
        } else if (target == "screenshot") {
            action.kind = BindingActionKindScreenshot;
        } else if (target == "discord") {
            action.kind = BindingActionKindOpenURL;
            action.url = "https://discord.com/app";
        } else if (target == "pov") {
            action.kind = BindingActionKindMacro;
            action.macroKind = BindingMacroKindPOV;
        } else if (target == "double_w") {
            action.kind = BindingActionKindMacro;
            action.macroKind = BindingMacroKindDoubleW;
        } else if (target == "space_click") {
            action.kind = BindingActionKindMacro;
            action.macroKind = BindingMacroKindSpaceClick;
        } else if (target == "shift_delete") {
            action.kind = BindingActionKindMacro;
            action.macroKind = BindingMacroKindShiftDelete;
        }
    }

    return action;
}

static ButtonBinding ParseBindingValue(id value, const RuntimeConfig& config) {
    ButtonBinding binding;
    if ([value isKindOfClass:[NSString class]]) {
        binding.pressAction = ParseActionString(value, config);
        return binding;
    }

    if (![value isKindOfClass:[NSDictionary class]]) {
        return binding;
    }

    NSDictionary* dictionary = (NSDictionary*)value;
    id pressValue = dictionary[@"press"] ?: dictionary[@"hold"];
    id tapValue = dictionary[@"tap"] ?: dictionary[@"click"];
    if ([pressValue isKindOfClass:[NSString class]]) {
        binding.pressAction = ParseActionString(pressValue, config);
    }
    if ([tapValue isKindOfClass:[NSString class]]) {
        binding.tapAction = ParseActionString(tapValue, config);
    }
    return binding;
}

static void LoadBindingsFromDictionary(NSDictionary* dictionary,
                                       std::map<uint32_t, ButtonBinding>& target,
                                       const RuntimeConfig& config,
                                       NSString* label) {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return;
    }

    target.clear();
    auto masks = ButtonMaskMap();
    for (NSString* rawButtonName in dictionary) {
        id actionValue = dictionary[rawButtonName];
        std::string buttonName = UpperNoSpaces([rawButtonName UTF8String]);
        auto maskIt = masks.find(buttonName);
        if (maskIt == masks.end()) {
            NSLog(@"Ignoring unknown button binding '%@' in %@", rawButtonName, label);
            continue;
        }

        ButtonBinding binding = ParseBindingValue(actionValue, config);
        if (binding.pressAction.kind == BindingActionKindNone && binding.tapAction.kind == BindingActionKindNone) {
            NSLog(@"Ignoring unsupported action '%@' for button '%@' in %@", actionValue, rawButtonName, label);
            continue;
        }

        target[maskIt->second] = binding;
    }
}

@interface Joycon2VirtualHID () {
@private
    RuntimeConfig _config;
    std::map<std::string, DeviceState> _deviceStates;
    NSTask *_screenRecordingTask;
    NSString *_screenRecordingPath;
}
- (void)setupKeyboardEventTap;
- (void)ensureAccessibilityPermission;
- (void)loadConfig;
- (void)installDefaultBindings;
- (const ButtonBinding*)bindingForMask:(uint32_t)mask mode:(EmulationMode)mode;
- (void)switchToMode:(EmulationMode)mode;
- (void)releaseAllPressedInputs;
- (void)postKeyboardEventForKeyCode:(CGKeyCode)keyCode down:(BOOL)down;
- (void)postKeyboardTapForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags;
- (void)postMouseButton:(CGMouseButton)button down:(BOOL)down;
- (void)postScrollX:(int32_t)scrollX scrollY:(int32_t)scrollY;
- (void)postEventToAllTaps:(CGEventRef)event;
- (void)moveCursorByDeltaX:(double)deltaX deltaY:(double)deltaY;
- (void)openLaunchpad;
- (void)openURLString:(const std::string&)urlString;
- (void)runMacro:(BindingMacroKind)macroKind;
- (void)performComboMacro:(BindingMacroKind)macroKind down:(BOOL)down keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled;
- (NSString*)documentsCapturePathWithPrefix:(NSString*)prefix extension:(NSString*)extension;
- (void)takeScreenshot;
- (void)startScreenRecording;
- (void)stopScreenRecording;
- (BOOL)isScreenRecordingActive;
- (BOOL)processRightStickMouseFromData:(NSDictionary*)joyconData;
- (void)processMouseSensorFromData:(NSDictionary*)joyconData state:(DeviceState&)state;
- (void)performPressAction:(const BindingAction&)action down:(BOOL)down keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled;
- (void)performTapAction:(const BindingAction&)action keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled;
- (void)processButtonBindings:(uint32_t)buttons state:(DeviceState&)state keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled;
- (void)processLeftStickFromData:(NSDictionary*)joyconData state:(DeviceState&)state;
@end

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

@implementation Joycon2VirtualHID

@synthesize initialized = _initialized;
@synthesize emulationMode = _emulationMode;

- (instancetype)initWithMode:(EmulationMode)mode {
    return [self initWithMode:mode modeOverridden:YES configPath:nil];
}

- (instancetype)initWithMode:(EmulationMode)mode modeOverridden:(BOOL)modeOverridden configPath:(NSString*)configPath {
    self = [super init];
    if (!self) {
        return nil;
    }

    _modeOverridden = modeOverridden;
    _configPath = [configPath copy];
    self.emulationMode = mode;
    self.initialized = NO;

#ifndef HID_ENABLE
    joyconClient = [Joycon2BLEReceiver sharedInstance];
    if (!joyconClient) {
        NSLog(@"Failed to get Joy-Con BLE receiver instance");
        return nil;
    }

    [self loadConfig];
    if (!_modeOverridden) {
        self.emulationMode = _config.defaultMode;
    }

    __block Joycon2VirtualHID *blockSelf = self;
    joyconClient.onDataReceived = ^(NSDictionary* data) {
        [blockSelf sendHIDReportFromJoyconData:data];
    };
    joyconClient.onConnected = ^{
        blockSelf.initialized = NO;
    };
    joyconClient.onError = ^(NSString* error) {
        NSLog(@"Joy-Con error: %@", error);
    };
#endif

    NSLog(@"HID event injection ready in mode: %@", ModeName(self.emulationMode));
    return self;
}

- (void)dealloc {
    if ([self isScreenRecordingActive]) {
        [self stopScreenRecording];
    }
    [_screenRecordingPath release];
    [self stopEmulation];
    [_configPath release];
    [super dealloc];
}

- (void)loadConfig {
    _config = RuntimeConfig();
    [self installDefaultBindings];

    NSString* resolvedPath = _configPath;
    if (!resolvedPath || resolvedPath.length == 0) {
        NSString* appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        NSString* appSupportConfig = appSupportDir ? [[appSupportDir stringByAppendingPathComponent:@"JoyCon2forMac"] stringByAppendingPathComponent:@"joycon2_config.json"] : nil;
        NSString* currentDirConfig = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"joycon2_config.json"];
        NSString* bundledConfig = [[NSBundle mainBundle] pathForResource:@"joycon2_config" ofType:@"json"];

        if (appSupportConfig && [[NSFileManager defaultManager] fileExistsAtPath:appSupportConfig]) {
            resolvedPath = appSupportConfig;
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:currentDirConfig]) {
            resolvedPath = currentDirConfig;
        } else {
            resolvedPath = bundledConfig ?: currentDirConfig;
        }
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedPath]) {
        _config.loadedFrom = [resolvedPath UTF8String];
        NSLog(@"Config file not found at %@, using defaults", resolvedPath);
        return;
    }

    NSData* data = [NSData dataWithContentsOfFile:resolvedPath];
    if (!data) {
        NSLog(@"Failed to read config at %@, using defaults", resolvedPath);
        return;
    }

    NSError* error = nil;
    id rootObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![rootObject isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Invalid config JSON at %@: %@", resolvedPath, error.localizedDescription);
        return;
    }

    NSDictionary* root = (NSDictionary*)rootObject;
    _config.loadedFrom = [resolvedPath UTF8String];

    NSString* modeValue = root[@"mode"];
    if ([modeValue isKindOfClass:[NSString class]]) {
        _config.defaultMode = ModeFromString(modeValue);
    }

    NSNumber* enableLeft = root[@"enableLeftJoyCon"];
    if ([enableLeft isKindOfClass:[NSNumber class]]) {
        _config.enableLeftJoyCon = [enableLeft boolValue];
    }

    NSDictionary* mouse = root[@"mouse"];
    if ([mouse isKindOfClass:[NSDictionary class]]) {
        NSNumber* sensitivity = mouse[@"sensitivity"];
        NSNumber* deadzone = mouse[@"deadzone"];
        NSNumber* smoothing = mouse[@"smoothing"];
        NSNumber* maxStep = mouse[@"maxStep"];
        NSNumber* jumpThreshold = mouse[@"jumpThreshold"];
        NSNumber* calibrationSeconds = mouse[@"calibrationSeconds"];
        NSNumber* invertX = mouse[@"invertX"];
        NSNumber* invertY = mouse[@"invertY"];
        NSNumber* scrollStep = mouse[@"scrollStep"];
        if ([sensitivity isKindOfClass:[NSNumber class]]) _config.mouse.sensitivity = [sensitivity doubleValue];
        if ([deadzone isKindOfClass:[NSNumber class]]) _config.mouse.deadzone = [deadzone doubleValue];
        if ([smoothing isKindOfClass:[NSNumber class]]) _config.mouse.smoothing = [smoothing doubleValue];
        if ([maxStep isKindOfClass:[NSNumber class]]) _config.mouse.maxStep = [maxStep doubleValue];
        if ([jumpThreshold isKindOfClass:[NSNumber class]]) _config.mouse.jumpThreshold = [jumpThreshold doubleValue];
        if ([calibrationSeconds isKindOfClass:[NSNumber class]]) _config.mouse.calibrationSeconds = std::max(0.0, [calibrationSeconds doubleValue]);
        if ([invertX isKindOfClass:[NSNumber class]]) _config.mouse.invertX = [invertX boolValue];
        if ([invertY isKindOfClass:[NSNumber class]]) _config.mouse.invertY = [invertY boolValue];
        if ([scrollStep isKindOfClass:[NSNumber class]]) _config.mouse.scrollStep = std::max(1, [scrollStep intValue]);
    }

    NSDictionary* keyboard = root[@"keyboard"];
    if ([keyboard isKindOfClass:[NSDictionary class]]) {
        NSNumber* stickDeadzone = keyboard[@"stickDeadzone"];
        NSString* leftStickMode = keyboard[@"leftStickMode"];
        if ([stickDeadzone isKindOfClass:[NSNumber class]]) _config.keyboard.stickDeadzone = [stickDeadzone doubleValue];
        if ([leftStickMode isKindOfClass:[NSString class]]) _config.keyboard.leftStickMode = ToLower([leftStickMode UTF8String]);
    }

    NSDictionary* bindings = root[@"bindings"];
    if ([bindings isKindOfClass:[NSDictionary class]]) {
        LoadBindingsFromDictionary(bindings, _config.bindings, _config, @"bindings");
    }

    NSDictionary* modeBindings = root[@"modeBindings"];
    if ([modeBindings isKindOfClass:[NSDictionary class]]) {
        LoadBindingsFromDictionary(modeBindings[@"mouse"], _config.mouseBindings, _config, @"modeBindings.mouse");
        LoadBindingsFromDictionary(modeBindings[@"keyboard"], _config.keyboardBindings, _config, @"modeBindings.keyboard");
        LoadBindingsFromDictionary(modeBindings[@"hybrid"], _config.hybridBindings, _config, @"modeBindings.hybrid");
    }

    NSLog(@"Loaded config from %@ (mode=%@, leftJoyCon=%@)", resolvedPath, ModeName(_config.defaultMode), _config.enableLeftJoyCon ? @"enabled" : @"disabled");
}

- (void)installDefaultBindings {
    auto masks = ButtonMaskMap();
    auto bindPress = [&](std::map<uint32_t, ButtonBinding>& target, const std::string& button, NSString* actionString) {
        auto it = masks.find(button);
        if (it == masks.end()) {
            return;
        }
        BindingAction action = ParseActionString(actionString, _config);
        if (action.kind != BindingActionKindNone) {
            target[it->second].pressAction = action;
        }
    };
    auto bindTap = [&](std::map<uint32_t, ButtonBinding>& target, const std::string& button, NSString* actionString) {
        auto it = masks.find(button);
        if (it == masks.end()) {
            return;
        }
        BindingAction action = ParseActionString(actionString, _config);
        if (action.kind != BindingActionKindNone) {
            target[it->second].tapAction = action;
        }
    };

    _config.bindings.clear();
    _config.mouseBindings.clear();
    _config.keyboardBindings.clear();
    _config.hybridBindings.clear();

    bindPress(_config.mouseBindings, "A", @"system:space_click");
    bindPress(_config.mouseBindings, "R", @"mouse:left");
    bindTap(_config.mouseBindings, "B", @"system:shift_delete");
    bindPress(_config.mouseBindings, "ZR", @"mouse:right");
    bindPress(_config.mouseBindings, "X", @"key:f");
    bindPress(_config.mouseBindings, "Y", @"key:e");
    bindPress(_config.mouseBindings, "L", @"mouse:scroll_up");
    bindPress(_config.mouseBindings, "ZL", @"mouse:scroll_down");
    bindPress(_config.mouseBindings, "UP", @"system:pov");
    bindPress(_config.mouseBindings, "DOWN", @"key:q");
    bindPress(_config.mouseBindings, "LEFT", @"key:left_arrow");
    bindPress(_config.mouseBindings, "RIGHT", @"key:t");
    bindPress(_config.mouseBindings, "SL(L)", @"mouse:scroll_up");
    bindPress(_config.mouseBindings, "SR(L)", @"mouse:scroll_down");
    bindPress(_config.mouseBindings, "SL(R)", @"mouse:scroll_up");
    bindPress(_config.mouseBindings, "SR(R)", @"mouse:scroll_down");
    bindPress(_config.mouseBindings, "LS", @"system:double_w");
    bindPress(_config.mouseBindings, "RS", @"system:pov");
    bindPress(_config.mouseBindings, "SELECT", @"key:escape");
    bindPress(_config.mouseBindings, "START", @"key:escape");
    bindPress(_config.mouseBindings, "HOME", @"system:launchpad");
    bindPress(_config.mouseBindings, "CAMERA", @"system:screenshot");
    bindPress(_config.mouseBindings, "CHAT", @"system:discord");

    bindPress(_config.hybridBindings, "A", @"system:space_click");
    bindTap(_config.hybridBindings, "B", @"system:shift_delete");
    bindPress(_config.hybridBindings, "X", @"key:f");
    bindPress(_config.hybridBindings, "Y", @"key:e");
    bindPress(_config.hybridBindings, "R", @"mouse:scroll_down");
    bindPress(_config.hybridBindings, "ZR", @"mouse:right");
    bindPress(_config.hybridBindings, "L", @"mouse:scroll_up");
    bindPress(_config.hybridBindings, "ZL", @"mouse:left");
    bindPress(_config.hybridBindings, "UP", @"system:pov");
    bindPress(_config.hybridBindings, "DOWN", @"key:q");
    bindPress(_config.hybridBindings, "LEFT", @"key:left_arrow");
    bindPress(_config.hybridBindings, "RIGHT", @"key:t");
    bindPress(_config.hybridBindings, "SL(L)", @"mouse:scroll_up");
    bindPress(_config.hybridBindings, "SR(L)", @"mouse:scroll_down");
    bindPress(_config.hybridBindings, "SL(R)", @"mouse:scroll_up");
    bindPress(_config.hybridBindings, "SR(R)", @"mouse:scroll_down");
    bindPress(_config.hybridBindings, "LS", @"system:double_w");
    bindPress(_config.hybridBindings, "RS", @"system:pov");
    bindPress(_config.hybridBindings, "SELECT", @"key:escape");
    bindPress(_config.hybridBindings, "START", @"key:escape");
    bindPress(_config.hybridBindings, "HOME", @"system:launchpad");
    bindPress(_config.hybridBindings, "CAMERA", @"system:screenshot");
    bindPress(_config.hybridBindings, "CHAT", @"system:discord");

    bindPress(_config.keyboardBindings, "A", @"system:space_click");
    bindTap(_config.keyboardBindings, "B", @"system:shift_delete");
    bindPress(_config.keyboardBindings, "X", @"key:f");
    bindPress(_config.keyboardBindings, "Y", @"key:e");
    bindPress(_config.keyboardBindings, "R", @"key:return");
    bindPress(_config.keyboardBindings, "ZR", @"key:left_control");
    bindPress(_config.keyboardBindings, "L", @"mouse:scroll_up");
    bindPress(_config.keyboardBindings, "ZL", @"mouse:scroll_down");
    bindPress(_config.keyboardBindings, "UP", @"system:pov");
    bindPress(_config.keyboardBindings, "DOWN", @"key:q");
    bindPress(_config.keyboardBindings, "LEFT", @"key:left_arrow");
    bindPress(_config.keyboardBindings, "RIGHT", @"key:t");
    bindPress(_config.keyboardBindings, "SL(L)", @"mouse:scroll_up");
    bindPress(_config.keyboardBindings, "SR(L)", @"mouse:scroll_down");
    bindPress(_config.keyboardBindings, "SL(R)", @"mouse:scroll_up");
    bindPress(_config.keyboardBindings, "SR(R)", @"mouse:scroll_down");
    bindPress(_config.keyboardBindings, "LS", @"system:double_w");
    bindPress(_config.keyboardBindings, "RS", @"system:pov");
    bindPress(_config.keyboardBindings, "SELECT", @"key:escape");
    bindPress(_config.keyboardBindings, "START", @"key:escape");
    bindPress(_config.keyboardBindings, "HOME", @"system:launchpad");
    bindPress(_config.keyboardBindings, "CAMERA", @"system:screenshot");
    bindPress(_config.keyboardBindings, "CHAT", @"system:discord");
}

- (void)startEmulation {
#ifndef HID_ENABLE
    [joyconClient startScan];
#endif
    [self ensureAccessibilityPermission];
    [self setupKeyboardEventTap];
    NSLog(@"Started Joy-Con emulation in %@ mode", ModeName(self.emulationMode));
}

- (void)stopEmulation {
    [self releaseAllPressedInputs];
#ifndef HID_ENABLE
    [joyconClient disconnect];
#endif
    if (_eventTap) {
        CFMachPortInvalidate(_eventTap);
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
}

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    Joycon2VirtualHID *self = (__bridge Joycon2VirtualHID *)refcon;
    if (type != kCGEventKeyDown) {
        return event;
    }

    CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags requiredFlags = kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate;
    if ((flags & requiredFlags) != requiredFlags) {
        return event;
    }

    if (keyCode == 46) { // M
        [self switchToMode:MODE_MOUSE];
        return NULL;
    }
    if (keyCode == 40) { // K
        [self switchToMode:MODE_KEYBOARD];
        return NULL;
    }
    if (keyCode == 4) { // H
        [self switchToMode:MODE_HYBRID];
        return NULL;
    }

    return event;
}

- (void)ensureAccessibilityPermission {
    NSDictionary* options = @{(__bridge NSString*)kAXTrustedCheckOptionPrompt: @YES};
    if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options)) {
        NSLog(@"Accessibility access is not granted yet. Input injection may not work until JoyCon2forMac is allowed in System Settings > Privacy & Security > Accessibility.");
    }
}

- (void)setupKeyboardEventTap {
    if (_eventTap) {
        return;
    }

    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown);
    _eventTap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 eventMask,
                                 eventTapCallback,
                                 (__bridge void *)self);
    if (!_eventTap) {
        NSLog(@"Failed to create event tap. Grant Accessibility access in System Settings.");
        return;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    CGEventTapEnable(_eventTap, true);
}

- (void)moveCursorByDeltaX:(double)deltaX deltaY:(double)deltaY {
    CGEventRef tempEvent = CGEventCreate(NULL);
    CGPoint currentPos = CGEventGetLocation(tempEvent);
    CFRelease(tempEvent);
    const bool cursorVisible = CGCursorIsVisible();

    CGPoint nextPos = currentPos;
    nextPos.x += deltaX;
    nextPos.y += deltaY;

    CGRect screenBounds = CGDisplayBounds(CGMainDisplayID());
    nextPos.x = fmax(screenBounds.origin.x, fmin(nextPos.x, screenBounds.origin.x + screenBounds.size.width));
    nextPos.y = fmax(screenBounds.origin.y, fmin(nextPos.y, screenBounds.origin.y + screenBounds.size.height));

    CGPoint eventPos = cursorVisible ? nextPos : currentPos;
    CGMouseButton eventButton = kCGMouseButtonLeft;
    CGEventType eventType = kCGEventMouseMoved;
    if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft)) {
        eventType = kCGEventLeftMouseDragged;
        eventButton = kCGMouseButtonLeft;
    } else if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight)) {
        eventType = kCGEventRightMouseDragged;
        eventButton = kCGMouseButtonRight;
    } else if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonCenter)) {
        eventType = kCGEventOtherMouseDragged;
        eventButton = kCGMouseButtonCenter;
    }
    CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, eventType, eventPos, eventButton);
    if (moveEvent) {
        CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaX, (int64_t)llround(deltaX));
        CGEventSetIntegerValueField(moveEvent, kCGMouseEventDeltaY, (int64_t)llround(deltaY));
        [self postEventToAllTaps:moveEvent];
        CFRelease(moveEvent);
    }
    if (cursorVisible) {
        CGWarpMouseCursorPosition(nextPos);
    }
}

- (void)openLaunchpad {
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/osascript";
    task.arguments = @[@"-e", @"tell application \"System Events\" to key code 160"];
    [task launch];
    [task waitUntilExit];
    int status = task.terminationStatus;
    [task release];
    if (status != 0) {
        [self postKeyboardEventForKeyCode:118 down:YES];
        [self postKeyboardEventForKeyCode:118 down:NO];
    }
}

- (void)postEventToAllTaps:(CGEventRef)event {
    if (!event) {
        return;
    }
    CGEventPost(kCGHIDEventTap, event);
    CGEventRef copy = CGEventCreateCopy(event);
    if (copy) {
        CGEventPost(kCGSessionEventTap, copy);
        CFRelease(copy);
    }
}

- (void)openURLString:(const std::string&)urlString {
    if (urlString.empty()) {
        return;
    }
    NSString* url = [NSString stringWithUTF8String:urlString.c_str()];
    NSURL* targetURL = [NSURL URLWithString:url];
    if (targetURL) {
        [[NSWorkspace sharedWorkspace] openURL:targetURL];
    }
}

- (void)runMacro:(BindingMacroKind)macroKind {
    switch (macroKind) {
        case BindingMacroKindPOV:
            [self postKeyboardTapForKeyCode:96 flags:kCGEventFlagMaskSecondaryFn];
            break;
        case BindingMacroKindDoubleW:
            [self postKeyboardEventForKeyCode:13 down:YES];
            [self postKeyboardEventForKeyCode:13 down:NO];
            usleep(25000);
            [self postKeyboardEventForKeyCode:13 down:YES];
            [self postKeyboardEventForKeyCode:13 down:NO];
            break;
        case BindingMacroKindSpaceClick:
        case BindingMacroKindShiftDelete:
        case BindingMacroKindNone:
        default:
            break;
    }
}

- (void)performComboMacro:(BindingMacroKind)macroKind down:(BOOL)down keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled {
    switch (macroKind) {
        case BindingMacroKindSpaceClick:
            if (keyboardEnabled) {
                [self postKeyboardEventForKeyCode:49 down:down];
            }
            if (mouseEnabled) {
                [self postMouseButton:kCGMouseButtonLeft down:down];
            }
            break;
        case BindingMacroKindShiftDelete:
            if (keyboardEnabled) {
                [self postKeyboardEventForKeyCode:56 down:down];
                [self postKeyboardEventForKeyCode:51 down:down];
            }
            break;
        case BindingMacroKindPOV:
        case BindingMacroKindDoubleW:
        case BindingMacroKindNone:
        default:
            break;
    }
}

- (NSString*)documentsCapturePathWithPrefix:(NSString*)prefix extension:(NSString*)extension {
    NSString* documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString* timestamp = [formatter stringFromDate:[NSDate date]];
    [formatter release];
    NSString* fileName = [NSString stringWithFormat:@"%@_%@.%@", prefix, timestamp, extension];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

- (void)takeScreenshot {
    NSString* outputPath = [self documentsCapturePathWithPrefix:@"joycon2_screenshot" extension:@"png"];
    NSTask* task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/screencapture";
    task.arguments = @[@"-x", outputPath];
    [task launch];
    [task waitUntilExit];
    NSLog(@"Saved JoyCon2 screenshot to %@", outputPath);
    [task release];
}

- (BOOL)isScreenRecordingActive {
    return _screenRecordingTask != nil && _screenRecordingTask.isRunning;
}

- (void)startScreenRecording {
    if ([self isScreenRecordingActive]) {
        return;
    }

    [_screenRecordingPath release];
    _screenRecordingPath = [[self documentsCapturePathWithPrefix:@"joycon2_recording" extension:@"mov"] copy];

    _screenRecordingTask = [[NSTask alloc] init];
    _screenRecordingTask.launchPath = @"/usr/sbin/screencapture";
    _screenRecordingTask.arguments = @[@"-v", @"-D1", _screenRecordingPath];
    [_screenRecordingTask launch];
    NSLog(@"Started JoyCon2 screen recording: %@", _screenRecordingPath);
}

- (void)stopScreenRecording {
    if (![self isScreenRecordingActive]) {
        return;
    }

    [_screenRecordingTask terminate];
    [_screenRecordingTask waitUntilExit];
    [_screenRecordingTask release];
    _screenRecordingTask = nil;
    if (_screenRecordingPath) {
        NSLog(@"Saved JoyCon2 screen recording to %@", _screenRecordingPath);
    }
}

- (const ButtonBinding*)bindingForMask:(uint32_t)mask mode:(EmulationMode)mode {
    const std::map<uint32_t, ButtonBinding>* selectedBindings = nullptr;
    switch (mode) {
        case MODE_MOUSE:
            selectedBindings = &_config.mouseBindings;
            break;
        case MODE_KEYBOARD:
            selectedBindings = &_config.keyboardBindings;
            break;
        case MODE_HYBRID:
        default:
            selectedBindings = &_config.hybridBindings;
            break;
    }

    if (selectedBindings) {
        auto it = selectedBindings->find(mask);
        if (it != selectedBindings->end()) {
            return &it->second;
        }
    }

    auto fallback = _config.bindings.find(mask);
    if (fallback != _config.bindings.end()) {
        return &fallback->second;
    }

    return nullptr;
}

- (void)switchToMode:(EmulationMode)mode {
    if (self.emulationMode == mode) {
        return;
    }
    [self releaseAllPressedInputs];
    self.emulationMode = mode;
    NSLog(@"Switched to %@ mode", ModeName(mode));
}

- (void)releaseAllPressedInputs {
    BOOL keyboardEnabled = YES;
    BOOL mouseEnabled = YES;
    std::set<uint32_t> relevantMasks;
    for (const auto& entry : _config.bindings) relevantMasks.insert(entry.first);
    for (const auto& entry : _config.mouseBindings) relevantMasks.insert(entry.first);
    for (const auto& entry : _config.keyboardBindings) relevantMasks.insert(entry.first);
    for (const auto& entry : _config.hybridBindings) relevantMasks.insert(entry.first);

    for (auto& entry : _deviceStates) {
        DeviceState& state = entry.second;
        for (uint32_t mask : relevantMasks) {
            const ButtonBinding* binding = [self bindingForMask:mask mode:self.emulationMode];
            bool isPressed = (state.lastButtons & mask) != 0;
            if (!isPressed || !binding) {
                continue;
            }

            const BindingAction& action = binding->pressAction;
            if (action.kind == BindingActionKindKey && keyboardEnabled) {
                [self postKeyboardEventForKeyCode:action.keyCode down:NO];
            } else if (action.kind == BindingActionKindMouseButton && mouseEnabled) {
                [self postMouseButton:action.mouseButton down:NO];
            }
        }

        if (state.stickUp) [self postKeyboardEventForKeyCode:(_config.keyboard.leftStickMode == "arrows" ? 126 : 13) down:NO];
        if (state.stickDown) [self postKeyboardEventForKeyCode:(_config.keyboard.leftStickMode == "arrows" ? 125 : 1) down:NO];
        if (state.stickLeft) [self postKeyboardEventForKeyCode:(_config.keyboard.leftStickMode == "arrows" ? 123 : 0) down:NO];
        if (state.stickRight) [self postKeyboardEventForKeyCode:(_config.keyboard.leftStickMode == "arrows" ? 124 : 2) down:NO];

        state.lastButtons = 0;
        state.buttonPressedAt.clear();
        state.stickUp = false;
        state.stickDown = false;
        state.stickLeft = false;
        state.stickRight = false;
    }
}

- (void)sendHIDReportFromJoyconData:(NSDictionary *)joyconData {
#ifndef HID_ENABLE
    NSString* deviceTypeString = joyconData[@"DeviceType"] ?: @"Unknown";
    NSString* identifier = joyconData[@"PeripheralIdentifier"] ?: @"unknown";
    std::string deviceType = [deviceTypeString UTF8String];

    if (deviceType == "L" && !_config.enableLeftJoyCon) {
        return;
    }

    BOOL mouseMotionEnabled = (self.emulationMode == MODE_MOUSE || self.emulationMode == MODE_HYBRID);
    BOOL leftStickEnabled = (self.emulationMode == MODE_KEYBOARD || self.emulationMode == MODE_HYBRID);
    BOOL mouseEnabled = YES;
    BOOL keyboardEnabled = YES;

    DeviceState& state = _deviceStates[[identifier UTF8String]];

    if (mouseMotionEnabled && (deviceType == "R" || deviceType == "Unknown")) {
        [self processMouseSensorFromData:joyconData state:state];
    }

    NSNumber* buttonsNumber = joyconData[@"Buttons"];
    uint32_t buttons = buttonsNumber ? (uint32_t)[buttonsNumber unsignedLongLongValue] : 0;
    [self processButtonBindings:buttons state:state keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];

    if (leftStickEnabled && (deviceType == "L" || deviceType == "Unknown")) {
        [self processLeftStickFromData:joyconData state:state];
    }
#endif
}

- (void)processMouseSensorFromData:(NSDictionary*)joyconData state:(DeviceState&)state {
    NSNumber* mouseXNumber = joyconData[@"MouseX"];
    NSNumber* mouseYNumber = joyconData[@"MouseY"];
    BOOL rightStickMoved = [self processRightStickMouseFromData:joyconData];
    if (!mouseXNumber || !mouseYNumber) {
        return;
    }

    int16_t mouseX = (int16_t)[mouseXNumber intValue];
    int16_t mouseY = (int16_t)[mouseYNumber intValue];

    if (rightStickMoved) {
        state.lastMouseX = mouseX;
        state.lastMouseY = mouseY;
        state.hasMouseSample = true;
        state.smoothedDeltaX *= 0.5;
        state.smoothedDeltaY *= 0.5;
        if (state.calibrationEndsAt == 0.0) {
            state.calibrationEndsAt = CFAbsoluteTimeGetCurrent() + _config.mouse.calibrationSeconds;
        }
        return;
    }

    if (!state.hasMouseSample) {
        state.lastMouseX = mouseX;
        state.lastMouseY = mouseY;
        state.calibrationEndsAt = CFAbsoluteTimeGetCurrent() + _config.mouse.calibrationSeconds;
        state.hasMouseSample = true;
        return;
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    double rawDeltaX = (double)(mouseX - state.lastMouseX);
    double rawDeltaY = (double)(mouseY - state.lastMouseY);
    state.lastMouseX = mouseX;
    state.lastMouseY = mouseY;

    if (std::fabs(rawDeltaX) > _config.mouse.jumpThreshold || std::fabs(rawDeltaY) > _config.mouse.jumpThreshold) {
        state.smoothedDeltaX = 0.0;
        state.smoothedDeltaY = 0.0;
        return;
    }

    if (now < state.calibrationEndsAt) {
        state.driftBiasX = (state.driftBiasX * 0.8) + (rawDeltaX * 0.2);
        state.driftBiasY = (state.driftBiasY * 0.8) + (rawDeltaY * 0.2);
        state.smoothedDeltaX = 0.0;
        state.smoothedDeltaY = 0.0;
        return;
    }

    const double driftWindow = std::max(_config.mouse.deadzone * 3.0, 6.0);
    if (std::fabs(rawDeltaX) < driftWindow) {
        state.driftBiasX = (state.driftBiasX * 0.95) + (rawDeltaX * 0.05);
    }
    if (std::fabs(rawDeltaY) < driftWindow) {
        state.driftBiasY = (state.driftBiasY * 0.95) + (rawDeltaY * 0.05);
    }

    rawDeltaX -= state.driftBiasX;
    rawDeltaY -= state.driftBiasY;

    if (std::fabs(rawDeltaX) < _config.mouse.deadzone) rawDeltaX = 0.0;
    if (std::fabs(rawDeltaY) < _config.mouse.deadzone) rawDeltaY = 0.0;

    const double carry = ClampDouble(_config.mouse.smoothing, 0.0, 0.95);
    state.smoothedDeltaX = (state.smoothedDeltaX * carry) + (rawDeltaX * (1.0 - carry));
    state.smoothedDeltaY = (state.smoothedDeltaY * carry) + (rawDeltaY * (1.0 - carry));

    if (rawDeltaX == 0.0) {
        state.smoothedDeltaX *= carry;
    }
    if (rawDeltaY == 0.0) {
        state.smoothedDeltaY *= carry;
    }

    double deltaX = state.smoothedDeltaX * _config.mouse.sensitivity;
    double deltaY = state.smoothedDeltaY * _config.mouse.sensitivity;
    if (_config.mouse.invertX) deltaX = -deltaX;
    if (_config.mouse.invertY) deltaY = -deltaY;

    if (std::fabs(deltaX) < 0.01 && std::fabs(deltaY) < 0.01) {
        return;
    }

    deltaX = ClampDouble(deltaX, -_config.mouse.maxStep, _config.mouse.maxStep);
    deltaY = ClampDouble(deltaY, -_config.mouse.maxStep, _config.mouse.maxStep);

    [self moveCursorByDeltaX:deltaX deltaY:deltaY];
}

- (BOOL)processRightStickMouseFromData:(NSDictionary*)joyconData {
    NSNumber* rightStickX = joyconData[@"RightStickX"];
    NSNumber* rightStickY = joyconData[@"RightStickY"];
    if (!rightStickX || !rightStickY) {
        return NO;
    }

    double normalizedX = ([rightStickX doubleValue] - 2047.0) / 2047.0;
    double normalizedY = (2047.0 - [rightStickY doubleValue]) / 2047.0;
    double deadzone = ClampDouble(_config.keyboard.stickDeadzone, 0.0, 0.95);

    if (std::fabs(normalizedX) < deadzone) normalizedX = 0.0;
    if (std::fabs(normalizedY) < deadzone) normalizedY = 0.0;
    if (normalizedX == 0.0 && normalizedY == 0.0) {
        return NO;
    }

    double scale = std::max(10.0, _config.mouse.maxStep * 0.85);
    double deltaX = normalizedX * scale;
    double deltaY = normalizedY * scale;

    [self moveCursorByDeltaX:deltaX deltaY:deltaY];
    return YES;
}

- (void)performPressAction:(const BindingAction&)action down:(BOOL)down keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled {
    switch (action.kind) {
        case BindingActionKindKey:
            if (keyboardEnabled) {
                [self postKeyboardEventForKeyCode:action.keyCode down:down];
            }
            break;
        case BindingActionKindMouseButton:
            if (mouseEnabled) {
                [self postMouseButton:action.mouseButton down:down];
            }
            break;
        case BindingActionKindScroll:
            if (mouseEnabled && down) {
                [self postScrollX:action.scrollX scrollY:action.scrollY];
            }
            break;
        case BindingActionKindLaunchpad:
            if (down) {
                [self openLaunchpad];
            }
            break;
        case BindingActionKindOpenURL:
            if (down) {
                [self openURLString:action.url];
            }
            break;
        case BindingActionKindMacro:
            if (action.macroKind == BindingMacroKindSpaceClick || action.macroKind == BindingMacroKindShiftDelete) {
                [self performComboMacro:action.macroKind down:down keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
            } else if (down) {
                [self runMacro:action.macroKind];
            }
            break;
        case BindingActionKindScreenshot:
        case BindingActionKindNone:
        default:
            break;
    }
}

- (void)performTapAction:(const BindingAction&)action keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled {
    switch (action.kind) {
        case BindingActionKindKey:
            if (keyboardEnabled) {
                [self postKeyboardEventForKeyCode:action.keyCode down:YES];
                [self postKeyboardEventForKeyCode:action.keyCode down:NO];
            }
            break;
        case BindingActionKindMouseButton:
            if (mouseEnabled) {
                [self postMouseButton:action.mouseButton down:YES];
                [self postMouseButton:action.mouseButton down:NO];
            }
            break;
        case BindingActionKindScroll:
            if (mouseEnabled) {
                [self postScrollX:action.scrollX scrollY:action.scrollY];
            }
            break;
        case BindingActionKindLaunchpad:
            [self openLaunchpad];
            break;
        case BindingActionKindScreenshot:
            [self takeScreenshot];
            break;
        case BindingActionKindOpenURL:
            [self openURLString:action.url];
            break;
        case BindingActionKindMacro:
            if (action.macroKind == BindingMacroKindSpaceClick || action.macroKind == BindingMacroKindShiftDelete) {
                [self performComboMacro:action.macroKind down:YES keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
                [self performComboMacro:action.macroKind down:NO keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
            } else {
                [self runMacro:action.macroKind];
            }
            break;
        case BindingActionKindNone:
        default:
            break;
    }
}

- (void)processButtonBindings:(uint32_t)buttons state:(DeviceState&)state keyboardEnabled:(BOOL)keyboardEnabled mouseEnabled:(BOOL)mouseEnabled {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    const double tapThreshold = 0.30;
    std::set<uint32_t> relevantMasks;
    for (const auto& entry : _config.bindings) relevantMasks.insert(entry.first);
    switch (self.emulationMode) {
        case MODE_MOUSE:
            for (const auto& entry : _config.mouseBindings) relevantMasks.insert(entry.first);
            break;
        case MODE_KEYBOARD:
            for (const auto& entry : _config.keyboardBindings) relevantMasks.insert(entry.first);
            break;
        case MODE_HYBRID:
        default:
            for (const auto& entry : _config.hybridBindings) relevantMasks.insert(entry.first);
            break;
    }

    for (uint32_t mask : relevantMasks) {
        const ButtonBinding* binding = [self bindingForMask:mask mode:self.emulationMode];
        if (!binding) {
            continue;
        }
        bool wasPressed = (state.lastButtons & mask) != 0;
        bool isPressed = (buttons & mask) != 0;

        if (binding->pressAction.kind == BindingActionKindScreenshot) {
            if ([self isScreenRecordingActive]) {
                if (isPressed && !wasPressed) {
                    [self stopScreenRecording];
                    state.screenshotHoldTriggered = true;
                } else if (!isPressed && wasPressed) {
                    state.screenshotPressedAt = 0.0;
                    state.screenshotHoldTriggered = false;
                }
                continue;
            }

            if (isPressed && !wasPressed) {
                state.screenshotPressedAt = now;
                state.screenshotHoldTriggered = false;
            } else if (isPressed && wasPressed) {
                if (!state.screenshotHoldTriggered && (now - state.screenshotPressedAt) >= 1.0) {
                    [self startScreenRecording];
                    state.screenshotHoldTriggered = true;
                }
            } else if (!isPressed && wasPressed) {
                if (!state.screenshotHoldTriggered) {
                    [self takeScreenshot];
                }
                state.screenshotPressedAt = 0.0;
                state.screenshotHoldTriggered = false;
            }
            continue;
        }

        if (wasPressed == isPressed) {
            continue;
        }

        if (isPressed) {
            state.buttonPressedAt[mask] = now;
            if (binding->pressAction.kind != BindingActionKindNone) {
                [self performPressAction:binding->pressAction down:YES keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
            }
        } else {
            if (binding->pressAction.kind != BindingActionKindNone) {
                [self performPressAction:binding->pressAction down:NO keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
            }

            auto it = state.buttonPressedAt.find(mask);
            double duration = (it != state.buttonPressedAt.end()) ? (now - it->second) : 0.0;
            bool shouldTap = (binding->tapAction.kind != BindingActionKindNone) &&
                             (binding->pressAction.kind == BindingActionKindNone || duration <= tapThreshold);
            if (shouldTap) {
                [self performTapAction:binding->tapAction keyboardEnabled:keyboardEnabled mouseEnabled:mouseEnabled];
            }
            state.buttonPressedAt.erase(mask);
        }
    }

    state.lastButtons = buttons;
}

- (void)processLeftStickFromData:(NSDictionary*)joyconData state:(DeviceState&)state {
    if (_config.keyboard.leftStickMode == "none") {
        return;
    }

    NSNumber* leftStickX = joyconData[@"LeftStickX"];
    NSNumber* leftStickY = joyconData[@"LeftStickY"];
    if (!leftStickX || !leftStickY) {
        return;
    }

    double normalizedX = ([leftStickX doubleValue] - 2047.0) / 2047.0;
    double normalizedY = ([leftStickY doubleValue] - 2047.0) / 2047.0;
    double deadzone = ClampDouble(_config.keyboard.stickDeadzone, 0.0, 0.95);

    bool up = normalizedY < -deadzone;
    bool down = normalizedY > deadzone;
    bool left = normalizedX < -deadzone;
    bool right = normalizedX > deadzone;

    CGKeyCode upCode = _config.keyboard.leftStickMode == "arrows" ? 126 : 13;
    CGKeyCode downCode = _config.keyboard.leftStickMode == "arrows" ? 125 : 1;
    CGKeyCode leftCode = _config.keyboard.leftStickMode == "arrows" ? 123 : 0;
    CGKeyCode rightCode = _config.keyboard.leftStickMode == "arrows" ? 124 : 2;

    if (state.stickUp != up) [self postKeyboardEventForKeyCode:upCode down:up];
    if (state.stickDown != down) [self postKeyboardEventForKeyCode:downCode down:down];
    if (state.stickLeft != left) [self postKeyboardEventForKeyCode:leftCode down:left];
    if (state.stickRight != right) [self postKeyboardEventForKeyCode:rightCode down:right];

    state.stickUp = up;
    state.stickDown = down;
    state.stickLeft = left;
    state.stickRight = right;
}

- (void)postKeyboardEventForKeyCode:(CGKeyCode)keyCode down:(BOOL)down {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, down);
    if (!event) {
        return;
    }
    [self postEventToAllTaps:event];
    CFRelease(event);
}

- (void)postKeyboardTapForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags {
    CGEventRef downEvent = CGEventCreateKeyboardEvent(NULL, keyCode, YES);
    CGEventRef upEvent = CGEventCreateKeyboardEvent(NULL, keyCode, NO);
    if (!downEvent || !upEvent) {
        if (downEvent) CFRelease(downEvent);
        if (upEvent) CFRelease(upEvent);
        return;
    }
    CGEventSetFlags(downEvent, flags);
    CGEventSetFlags(upEvent, flags);
    [self postEventToAllTaps:downEvent];
    [self postEventToAllTaps:upEvent];
    CFRelease(downEvent);
    CFRelease(upEvent);
}

- (void)postMouseButton:(CGMouseButton)button down:(BOOL)down {
    CGEventRef tempEvent = CGEventCreate(NULL);
    CGPoint currentPos = CGEventGetLocation(tempEvent);
    CFRelease(tempEvent);

    CGEventType eventType = kCGEventLeftMouseDown;
    if (button == kCGMouseButtonLeft) {
        eventType = down ? kCGEventLeftMouseDown : kCGEventLeftMouseUp;
    } else if (button == kCGMouseButtonRight) {
        eventType = down ? kCGEventRightMouseDown : kCGEventRightMouseUp;
    } else {
        eventType = down ? kCGEventOtherMouseDown : kCGEventOtherMouseUp;
    }

    CGEventRef clickEvent = CGEventCreateMouseEvent(NULL, eventType, currentPos, button);
    if (!clickEvent) {
        return;
    }
    [self postEventToAllTaps:clickEvent];
    CFRelease(clickEvent);
}

- (void)postScrollX:(int32_t)scrollX scrollY:(int32_t)scrollY {
    if (scrollX == 0 && scrollY == 0) {
        return;
    }

    CGEventRef wheelEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 2, scrollY, scrollX);
    if (!wheelEvent) {
        return;
    }
    [self postEventToAllTaps:wheelEvent];
    CFRelease(wheelEvent);
}

@end
