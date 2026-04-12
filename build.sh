#!/bin/bash

# Joy-Con HID Emulator Build Script

echo "Building Joy-Con2forMac Utility..."

cd "$(dirname "$0")"

# Create build directory
mkdir -p build

# Build mode: FULL, BLE_ONLY, APP
BUILD_MODE=${1:-FULL} # デフォルトはFULL
# Build type: debug, release
BUILD_TYPE=${2:-debug} # デフォルトはdebug

# Set debug flag
if [ "$BUILD_TYPE" = "debug" ]; then
    DEBUG_FLAG="-DDEBUG"
else
    DEBUG_FLAG=""
fi

    if [ "$BUILD_MODE" = "FULL" ]; then
    echo "Building in FULL mode (Joycon2VirtualHID with BLE and HID emulation) in $BUILD_TYPE mode..."
    clang++ -std=c++17 -x objective-c++ $DEBUG_FLAG -framework Foundation -framework AppKit -framework IOKit -framework CoreBluetooth -framework ApplicationServices -Iinclude src/Joycon2VirtualHID.mm src/Joycon2BLEReceiver.mm src/main_ble.mm -o build/Joycon2VirtualHID
    elif [ "$BUILD_MODE" = "APP" ]; then
    echo "Building in APP mode (Joycon2forMac.app) in $BUILD_TYPE mode..."
    APP_DIR="build/Joycon2forMac.app"
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"
    clang++ -std=c++17 -x objective-c++ $DEBUG_FLAG -framework Foundation -framework AppKit -framework IOKit -framework CoreBluetooth -framework ApplicationServices -Iinclude src/Joycon2App.mm src/Joycon2VirtualHID.mm src/Joycon2BLEReceiver.mm -o "$APP_DIR/Contents/MacOS/Joycon2forMac"
    cp Joycon2forMac-App-Info.plist "$APP_DIR/Contents/Info.plist"
    cp joycon2_config.json "$APP_DIR/Contents/Resources/joycon2_config.json"
    elif [ "$BUILD_MODE" = "BLE_ONLY" ]; then
    echo "Building in BLE_ONLY mode (Joycon2BLEReceiver for BLE communication only) in $BUILD_TYPE mode..."
    clang++ -std=c++17 -x objective-c++ $DEBUG_FLAG -DHID_ENABLE -framework Foundation -framework CoreBluetooth -Iinclude src/Joycon2BLEReceiver.mm src/main_ble.mm -o build/Joycon2BLEReceiver
else
    echo "Invalid BUILD_MODE: $BUILD_MODE. Use FULL, APP or BLE_ONLY."
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "Build successful! Executable: $BUILD_MODE mode ($BUILD_TYPE)"
else
    echo "Build failed!"
    exit 1
fi
