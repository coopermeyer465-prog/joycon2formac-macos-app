# JoyCon2forMac

Joy-Con 2 mouse + keyboard mapper for macOS.

It runs in the menu bar (top-right of your screen) and can keep scanning/connected in the background even when its configuration window is closed.

## Download

- Latest DMG: https://github.com/coopermeyer465-prog/joycon2formac-macos-app/releases/latest/download/JoyCon2forMac-macOS.dmg

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
2. Choose `Reconfigure / Remap...`
3. Click `Map Joy-Con Button`, press the controller button, then choose the action.

## Credits

This project is based on and heavily inspired by:

- `seitanmen/Joycon2forMac` (original repo and early implementation)
  - https://github.com/seitanmen/Joycon2forMac

## Dev Build (Optional)

Only needed if you’re building from source:

```bash
xcode-select --install
cd /Users/marissameyer/Desktop/Joycon2forMac/Joycon2forMac-publish
./build.sh APP release
```
