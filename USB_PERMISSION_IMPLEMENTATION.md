# USB Permission Implementation for Epson TM-T88VI

## Overview
This document explains the implementation of native Android USB permission handling for Epson TM-T88VI thermal printer in the Flutter POS application.

## Implementation Details

### Native Android Code (MainActivity.kt)

#### Key Components:
1. **UsbManager**: Manages USB device access
2. **BroadcastReceiver**: Handles USB permission responses
3. **MethodChannel**: Communicates with Flutter
4. **PendingIntent**: Requests USB permissions

#### Core Functionality:
```kotlin
// USB Manager setup
val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
val devices = usbManager.deviceList

// Check for Epson devices (Vendor ID: 1208)
for (device in devices.values) {
    if (device.vendorId == 1208) { // Epson vendor ID
        if (!usbManager.hasPermission(device)) {
            val permissionIntent = PendingIntent.getBroadcast(
                context, 0, Intent(ACTION_USB_PERMISSION), 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            usbManager.requestPermission(device, permissionIntent)
            return
        }
    }
}
```

### Flutter Integration

#### Method Channel:
- **Channel Name**: `com.emaar.pos.usb_permissions`
- **Methods**: 
  - `requestUSBPermissions`: Request USB permissions
  - `checkUSBPermissions`: Check current permission status

#### Usage in Flutter:
```dart
// Request USB permissions
final bool hasPermission = await platform.invokeMethod('requestUSBPermissions');

// Check USB permissions
final bool hasPermission = await platform.invokeMethod('checkUSBPermissions');
```

## Android Manifest Configuration

### Permissions:
```xml
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-feature android:name="android.hardware.usb.host" android:required="false" />
```

### Intent Filters:
```xml
<!-- USB device attachment -->
<intent-filter>
    <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
</intent-filter>

<!-- USB permission response -->
<intent-filter>
    <action android:name="com.emaar.pos.USB_PERMISSION" />
</intent-filter>
```

### Device Filter:
```xml
<meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
    android:resource="@xml/device_filter" />
```

## How It Works

### 1. Device Detection
- Android automatically detects USB devices
- App receives `USB_DEVICE_ATTACHED` intent
- Device filter ensures only Epson devices trigger the app

### 2. Permission Request Flow
1. **Check Device List**: Scan for connected USB devices
2. **Filter Epson Devices**: Look for devices with Vendor ID 1208
3. **Check Permissions**: Verify if permission is already granted
4. **Request Permission**: Show system permission dialog if needed
5. **Handle Response**: Process user's permission decision

### 3. Permission Response Handling
- **BroadcastReceiver** listens for permission responses
- **MethodChannel** communicates result back to Flutter
- **User Feedback** shows appropriate success/error messages

## Epson Device Specifications

### TM-T88VI Details:
- **Vendor ID**: 1208 (Epson)
- **Product ID**: 1 or 2 (varies by model)
- **USB Class**: 7 (Printer)
- **Connection**: USB 2.0

### Supported Devices:
- TM-T88VI (primary target)
- TM-T20
- Other TM series printers
- Any Epson device with Vendor ID 1208

## User Experience

### Permission Request Process:
1. **User Action**: Taps "Request USB Permission" button
2. **System Dialog**: Android shows USB permission dialog
3. **User Decision**: User grants or denies permission
4. **Feedback**: App shows success/error message
5. **Discovery**: User can now discover and use printer

### Error Handling:
- **No Device**: "No Epson devices found"
- **Permission Denied**: "USB permission denied"
- **Already Granted**: "Permission already granted"
- **System Error**: Detailed error message with troubleshooting

## Code Structure

### MainActivity.kt:
```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.emaar.pos.usb_permissions"
    private val ACTION_USB_PERMISSION = "com.emaar.pos.USB_PERMISSION"
    private val EPSON_VENDOR_ID = 1208
    
    // USB Manager and Method Channel setup
    // BroadcastReceiver for permission responses
    // Permission request and check methods
}
```

### Flutter Integration:
```dart
class _MyAppState1 extends State<MyApp1> {
  static const platform = MethodChannel('com.emaar.pos.usb_permissions');
  
  // USB permission request method
  // USB permission check method
  // Integration with discovery and printing
}
```

## Testing

### Test Scenarios:
1. **Connect Printer**: Plug in TM-T88VI via USB
2. **Request Permission**: Tap "Request USB Permission" button
3. **Grant Permission**: Allow permission in system dialog
4. **Discover Printer**: Use "Discovery USB" button
5. **Print Test**: Send test print to verify functionality

### Debug Information:
- Check Android logs for "USB_PERMISSION" tags
- Monitor Flutter logs for permission status
- Verify device detection in system settings

## Troubleshooting

### Common Issues:

#### 1. "No Epson devices found"
- **Cause**: Printer not connected or not recognized
- **Solution**: Check USB cable, power, and connection

#### 2. "USB permission denied"
- **Cause**: User denied permission in system dialog
- **Solution**: Reconnect printer and grant permission

#### 3. "Permission already granted"
- **Cause**: Permission was previously granted
- **Solution**: Proceed with printer discovery

#### 4. Method channel errors
- **Cause**: Communication issue between Flutter and Android
- **Solution**: Check channel name and method signatures

### Debug Steps:
1. Check Android device logs
2. Verify USB device detection
3. Test permission request flow
4. Monitor method channel communication

## Benefits

### Enhanced User Experience:
- **Automatic Detection**: Recognizes Epson devices automatically
- **Clear Feedback**: Shows permission status and results
- **Error Handling**: Provides helpful error messages
- **Integration**: Seamlessly works with printer discovery

### Technical Advantages:
- **Native Implementation**: Uses Android's built-in USB handling
- **Proper Permissions**: Follows Android security model
- **Device Filtering**: Only requests permissions for Epson devices
- **Async Handling**: Non-blocking permission requests

## Files Modified

1. **`MainActivity.kt`** - Added native USB permission handling
2. **`AndroidManifest.xml`** - Added USB permissions and intent filters
3. **`device_filter.xml`** - Epson device specifications
4. **`main.dart`** - Flutter integration with method channel
5. **`config.xml`** - Epson API key configuration

## Next Steps

1. **Test Implementation**: Connect TM-T88VI and test permission flow
2. **Verify Discovery**: Ensure printer appears in discovery list
3. **Test Printing**: Send test prints to verify full functionality
4. **Error Handling**: Test various error scenarios
5. **User Feedback**: Gather feedback on permission request flow

The USB permission implementation is now complete and ready for testing with your Epson TM-T88VI thermal printer.
