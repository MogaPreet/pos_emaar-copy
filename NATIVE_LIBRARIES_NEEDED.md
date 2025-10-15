# ⚠️ NATIVE LIBRARIES REQUIRED

The ePOS2.jar requires native library files (`libepos2.so`) to function properly. These are NOT included in the JAR file.

## Required Files:

You need to download the complete ePOS2 SDK from Epson and extract these files:

```
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libepos2.so
├── armeabi-v7a/
│   └── libepos2.so
├── x86/
│   └── libepos2.so
└── x86_64/
│   └── libepos2.so
```

## How to Get the Native Libraries:

1. **Download ePOS2 SDK**: Visit [Epson ePOS2 SDK](https://download4.epson.biz/sec_pubs/pos/reference_en/epos_android/)
2. **Extract the SDK**: The native libraries are in the SDK package
3. **Copy to Project**: Place the `libepos2.so` files in the appropriate architecture folders

## Current Status:

- ✅ JAR files are included and configured
- ✅ Android code is ready for real printer communication
- ❌ Native libraries are missing (will cause runtime error)

## Error You'll See Without Native Libraries:

```
dlopen failed: library "libepos2.so" not found
```

## Quick Test:

To test if you have the native libraries:
1. Run the app: `flutter run`
2. If it crashes with "libepos2.so not found", you need to add the native libraries
3. If it runs without crashing, the native libraries are present

## Alternative Solution:

If you cannot get the native libraries, you can temporarily use the simulation version by:
1. Commenting out the ePOS2 imports in MainActivity.kt
2. Commenting out the JAR dependencies in build.gradle.kts
3. Using the simulation code instead
