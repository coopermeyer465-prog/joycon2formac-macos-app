# JoyCon2forMac

Joy-Con 2 support for macOS: mouse + keyboard mapping, with an optional (experimental) virtual gamepad mode.

It runs in the menu bar (top-right of your screen) and keeps scanning/connected in the background even when its configuration window is closed.

## Download

- Latest DMG: [JoyCon2forMac-macOS.dmg](https://github.com/coopermeyer465-prog/joycon2formac-macos-app/releases/latest/download/JoyCon2forMac-macOS.dmg)

## Install

1. Open the DMG.
2. Drag `JoyCon2forMac.app` into `Applications`.
3. Open `JoyCon2forMac` from `Applications`.

## Permissions (Required)

Open `System Settings -> Privacy & Security` and allow `JoyCon2forMac`:

- `Accessibility` (System Control)
- `Screen Recording` (required for screenshots / screen recording)
- `Bluetooth`
- `Input Monitoring` (if buttons/keys/clicks still do nothing)

After changing permissions, quit and relaunch the app.

## Pair Joy-Cons

1. Turn Bluetooth on in macOS.
2. Hold the Joy-Con sync button until the LEDs start flashing.
3. Open `JoyCon2forMac.app` and leave the Joy-Con in pairing mode until it connects.

## Remap

The app runs in the menu bar.

1. Click `JoyCon2forMac` in the menu bar.
2. Choose one of:
   - `Reconfigure / Remap...` (Hybrid mouse + keyboard mapping)
   - `Keyboard Controls...`
   - `Gamepad Controls...`
3. Click `Map Joy-Con Button`, press the controller button, then choose the action.

Notes:
- Default mode is `Gamepad Controls...`.
- Gamepad mode is “gamepad + hybrid mouse” so scrolling/clicking can still work even if macOS blocks virtual gamepads on your machine.

## Virtual Gamepad Notes

The app attempts to create a system-visible virtual HID gamepad so games can see controller input.

On some macOS versions, Apple may block virtual HID gamepad creation unless you have Apple-granted entitlements (Developer Program). If the virtual gamepad can’t be created, gamepad button mappings won’t register in games, but mouse/keyboard bindings still work.

## Credits

This project is based on and heavily inspired by:

- `seitanmen/Joycon2forMac` (original repo and early implementation)
  - https://github.com/seitanmen/Joycon2forMac

## Dev Build (Optional)

Only needed if you’re building from source:

```bash
xcode-select --install
git clone https://github.com/coopermeyer465-prog/joycon2formac-macos-app.git
cd joycon2formac-macos-app
./build.sh APP release
```
