# Joycon2 for Mac

`Joycon2forMac` is a macOS-first utility that connects to Nintendo Switch 2 Joy-Con controllers over Bluetooth Low Energy and turns their input into Mac keyboard and mouse events.

Current focus:

- keep BLE discovery and connection working on macOS
- use the **right Joy-Con** mouse sensor for cursor control
- keep the **left Joy-Con** out of mouse movement by default
- support `mouse`, `keyboard`, and `hybrid` output modes
- make button and stick mappings configurable with a simple JSON file

## Current Data Flow

The app is intentionally small. The runtime path is:

1. `Joycon2BLEReceiver` scans for Nintendo BLE devices and auto-connects.
2. CoreBluetooth notifications arrive in `didUpdateValueForCharacteristic`.
3. The 63-byte Joy-Con packet is parsed by `parseJoycon2Data`.
4. The parsed packet is converted into an `NSDictionary` with controller metadata:
   - device type (`L` / `R` / `Unknown`)
   - peripheral identifier
   - peripheral name
5. `Joycon2VirtualHID` receives that packet through the `onDataReceived` callback.
6. `Joycon2VirtualHID` applies the selected mode and config:
   - right Joy-Con mouse sensor -> Mac cursor movement
   - configured buttons -> keyboard keys
   - configured buttons -> mouse clicks / scroll
   - left stick -> `WASD`, arrow keys, or disabled

## Features

- BLE discovery and connection for Joy-Con 2 devices
- right Joy-Con mouse sensor support for cursor movement
- configurable mouse click and scroll bindings
- keyboard bindings for Joy-Con buttons
- left stick to `WASD` or arrow keys
- hybrid mode for mouse + keyboard/mouse-button output at the same time
- JSON config file for sensitivity, deadzones, left Joy-Con participation, and bindings

## Requirements

- macOS 10.15 or later
- Xcode Command Line Tools
- Bluetooth enabled on the Mac
- Nintendo Switch 2 Joy-Con controller(s)

Install command line tools if needed:

```bash
xcode-select --install
```

## Build

Build the full macOS input app:

```bash
./build.sh FULL debug
```

Build the distributable macOS app bundle:

```bash
./build.sh APP release
```

Build the BLE parser only:

```bash
./build.sh BLE_ONLY debug
```

Build outputs:

- `build/Joycon2VirtualHID`
- `build/JoyCon2forMac.app`
- `build/Joycon2BLEReceiver`

## Run

Default run uses `joycon2_config.json` in the repo root.

Hybrid mode:

```bash
./build/Joycon2VirtualHID --hybrid
```

App bundle:

```bash
open /Users/marissameyer/Desktop/Joycon2forMac-publish/build/JoyCon2forMac.app
```

The app window starts scanning automatically, shows discovery/connection/input status, and includes a capture-based mapper:

- click `Map Joy-Con Button`
- press the Joy-Con button you want to edit
- choose whether it should act as `Press or Hold` or `Tap`
- if you choose a keyboard action, press the Mac key you want to bind
- if you choose a mouse or system action, pick it from the popup

Mouse-only mode:

```bash
./build/Joycon2VirtualHID --mouse
```

Keyboard-only mode:

```bash
./build/Joycon2VirtualHID --keyboard
```

Use a custom config path:

```bash
./build/Joycon2VirtualHID --hybrid --config /absolute/path/to/joycon2_config.json
```

BLE parser only:

```bash
./build/Joycon2BLEReceiver
```

Runtime mode shortcuts:

- `Control + Option + Command + H`: hybrid mode
- `Control + Option + Command + M`: mouse mode
- `Control + Option + Command + K`: keyboard mode

## Pairing and Permissions

### Pair the Joy-Con

1. Turn Bluetooth on in macOS.
2. Hold the Joy-Con sync button until the LEDs start flashing.
3. Start `Joycon2VirtualHID`.
4. Leave the controller in pairing mode until the app logs that it connected.

The app performs BLE discovery itself. You do not need to pair through a separate gamepad driver.

### Required macOS permissions

The app synthesizes keyboard and mouse events, so macOS may require:

- `Bluetooth`
- `Accessibility`
- `Input Monitoring` in some setups

If mode switching or injected mouse/keyboard events do not work:

1. Open `System Settings -> Privacy & Security -> Accessibility`
2. Allow the terminal or app you launched the binary from
3. If needed, also allow it in `Input Monitoring`
4. Quit and relaunch the binary

## Config File

The default config file is [`joycon2_config.json`](./joycon2_config.json).

Example:

```json
{
  "configVersion": 3,
  "mode": "hybrid",
  "enableLeftJoyCon": true,
  "mouse": {
    "sensitivity": 0.35,
    "deadzone": 2.0,
    "smoothing": 0.6,
    "maxStep": 45.0,
    "jumpThreshold": 800.0,
    "calibrationSeconds": 1.0,
    "invertX": false,
    "invertY": false,
    "scrollStep": 3
  },
  "keyboard": {
    "leftStickMode": "wasd",
    "stickDeadzone": 0.35
  },
  "bindings": {},
  "modeBindings": {
    "mouse": {
      "A": "key:space",
      "B": {
        "press": "key:left_shift",
        "tap": "key:delete"
      },
      "R": "mouse:left",
      "ZR": "mouse:right",
      "Y": "key:e",
      "X": "key:f",
      "RIGHT": "key:t",
      "LEFT": "key:left_arrow",
      "UP": "system:pov",
      "DOWN": "key:q",
      "LS": "system:double_w",
      "RS": "system:pov",
      "CHAT": "system:discord",
      "HOME": "system:launchpad"
    },
    "hybrid": {
      "A": "key:space",
      "B": {
        "press": "key:left_shift",
        "tap": "key:delete"
      },
      "R": "mouse:scroll_down",
      "L": "mouse:scroll_up",
      "ZL": "mouse:left",
      "Y": "key:e",
      "X": "key:f",
      "RIGHT": "key:t",
      "LEFT": "key:left_arrow",
      "UP": "system:pov",
      "DOWN": "key:q",
      "LS": "system:double_w",
      "RS": "system:pov"
    }
  }
}
```

### Supported config fields

- `mode`: `hybrid`, `mouse`, or `keyboard`
- `configVersion`: built-in config schema version used by the app for safe upgrades
- `enableLeftJoyCon`: `true` or `false`
- `mouse.sensitivity`: cursor scale factor
- `mouse.deadzone`: ignore tiny sensor deltas
- `mouse.smoothing`: keeps some previous motion to reduce jitter
- `mouse.maxStep`: caps large per-packet cursor jumps
- `mouse.jumpThreshold`: ignores obvious sensor blips
- `mouse.calibrationSeconds`: startup stationary calibration time
- `mouse.invertX`, `mouse.invertY`
- `mouse.scrollStep`: amount for scroll button bindings
- `keyboard.leftStickMode`: `wasd`, `arrows`, or `none`
- `keyboard.stickDeadzone`: digital threshold for stick-to-key conversion
- `bindings`: button-to-action mapping
- `modeBindings.mouse`, `modeBindings.hybrid`, `modeBindings.keyboard`: per-mode overrides
- binding values can be:
  - a string such as `key:space`, which means “hold this action while the Joy-Con button is held”
  - an object such as `{ "press": "key:left_shift", "tap": "key:delete" }`

### Supported button names

- `A`, `B`, `X`, `Y`
- `L`, `ZL`, `R`, `ZR`
- `LS`, `RS`
- `START`, `SELECT`
- `HOME`, `CAMERA`, `CHAT`
- `SL(L)`, `SR(L)`, `SL(R)`, `SR(R)`

### Supported binding actions

- `key:<name>`
- `mouse:left`
- `mouse:right`
- `mouse:middle`
- `mouse:scroll_up`
- `mouse:scroll_down`
- `mouse:scroll_left`
- `mouse:scroll_right`
- `system:launchpad`
- `system:screenshot`
- `system:discord`
- `system:pov`
- `system:double_w`

Examples:

- `key:space`
- `key:return`
- `key:escape`
- `key:tab`
- `key:q`
- `key:left_shift`
- `key:up_arrow`

## Notes About Controller Behavior

- Cursor movement comes only from packets marked as **right Joy-Con**.
- Cursor movement comes from the right Joy-Con **mouse sensor** by default.
- When you intentionally deflect the right stick, it takes over cursor movement immediately, which keeps mouse mode usable in games that hide the cursor or make the mouse-sensor path awkward.
- Default Minecraft-style layout now includes:
  - `A`: jump / `space`
  - `B`: hold `shift`, tap `delete`
  - `Y`: inventory / `e`
  - `X`: interact / `f`
  - `Right`: chat / `t`
  - `Left`: left arrow
  - `Up`: change POV / `Fn+F5`
  - `Down`: drop item / `q`
  - `LS`: double-tap `w`
  - `RS`: change POV / `Fn+F5`
  - `Plus` and `Minus`: `escape`
  - `GameChat`: open Discord in the default browser
- Left Joy-Con packets are ignored completely when `enableLeftJoyCon` is `false`.
- Button bindings still work in hybrid mode for either controller that is allowed by config.
- Left stick to keyboard is evaluated from left-controller packets, which avoids the right Joy-Con accidentally cancelling stick directions.
- The screenshot button supports two behaviors by default: tap for a full-screen screenshot in Documents, hold for about 1 second to start screen recording, then tap again to stop and save the recording to Documents.
- Captures are saved in `~/Documents/JoyCon2forMac Captures`.
- Launchpad is triggered through the macOS Launchpad keyboard event path now, rather than a direct app launch.

## Troubleshooting

### The cursor jumps or feels noisy

- lower `mouse.sensitivity`
- raise `mouse.deadzone`
- raise `mouse.smoothing`
- lower `mouse.maxStep`

### The left Joy-Con is interfering

Set:

```json
{
  "enableLeftJoyCon": false
}
```

### Buttons are not producing expected key presses

- check the button name in `bindings`
- check the key name format, for example `key:space` or `key:escape`
- make sure the app has Accessibility permission

### Screenshot or screen recording does not start

- allow the app or terminal in `System Settings -> Privacy & Security -> Screen Recording`
- screenshots and recordings are saved in `Documents`

### BLE connects but no packets arrive

- put the Joy-Con back into sync mode
- relaunch the app
- try `./build/Joycon2BLEReceiver` first to verify the BLE path independently

## Source Files

- `src/Joycon2BLEReceiver.mm`: BLE scan, connect, characteristic discovery, packet parsing
- `src/Joycon2VirtualHID.mm`: config loading, mouse injection, keyboard injection, hybrid mode logic
- `src/main_ble.mm`: CLI argument parsing and startup
- `include/Joycon2BLEReceiver.h`: BLE interfaces
- `include/Joycon2VirtualHID.h`: HID interfaces and mode definitions

## License

MIT License
