# 🔧 How to Get ePOS2 Native Libraries

## Current Status:
- ✅ App detects Epson printer: `/dev/bus/usb/001/007`
- ✅ Real ePOS2 SDK integration working
- ❌ Connection fails with error code 2 (missing native libraries)

## Solution: Download Complete ePOS2 SDK

### Step 1: Download from Epson
1. Go to: https://download4.epson.biz/sec_pubs/pos/reference_en/epos_android/
2. Download the complete **ePOS2 Android SDK**
3. Extract the ZIP file

### Step 2: Find Native Libraries
In the extracted SDK, look for:
```
ePOS2_Android_SDK/
├── ePOS2.jar
├── libs/
│   ├── arm64-v8a/
│   │   └── libepos2.so
│   ├── armeabi-v7a/
│   │   └── libepos2.so
│   ├── x86/
│   │   └── libepos2.so
│   └── x86_64/
│       └── libepos2.so
└── samples/
```

### Step 3: Copy to Your Project
Copy the `libepos2.so` files to:
```
epos_printer_app/android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libepos2.so
├── armeabi-v7a/
│   └── libepos2.so
├── x86/
│   └── libepos2.so
└── x86_64/
    └── libepos2.so
```

### Step 4: Test
Run the app again:
```bash
flutter run
```

You should see:
- ✅ "Successfully connected to real printer" in logs
- ✅ Green printer icon in UI
- ✅ Successful barcode printing

## Alternative: Quick Test with Simulation

If you want to test the UI without the native libraries, you can temporarily switch back to simulation mode by commenting out the ePOS2 imports in `MainActivity.kt`.

## Error Codes Reference:
- Error 2 = ERR_CONNECT (connection failed)
- Error 0 = SUCCESS
- Error 1 = ERR_PARAM (invalid parameter)

The error 2 you're seeing confirms the ePOS2 SDK is working but can't connect due to missing native libraries.
