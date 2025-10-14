# USB Permissions Setup for Epson TM-T88VI Thermal Printer

## Overview
This document explains the USB permissions setup for the Epson TM-T88VI thermal printer in the Flutter POS application.

## Android Manifest Configuration

### 1. USB Permissions Added
The following permissions have been added to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- USB permissions for Epson TM-T88VI thermal printer -->
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-feature android:name="android.hardware.usb.host" android:required="false" />
```

### 2. USB Device Filter
Added intent filter and device filter for automatic USB device detection:

```xml
<!-- USB device filter for Epson TM-T88VI thermal printer -->
<intent-filter>
    <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
</intent-filter>
<meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
    android:resource="@xml/device_filter" />
```

### 3. Device Filter XML
Created `android/app/src/main/res/xml/device_filter.xml` with Epson TM-T88VI specifications:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- USB device filter for Epson TM-T88VI thermal printer -->
    <usb-device 
        vendor-id="1208" 
        product-id="1" 
        class="7" 
        subclass="1" 
        protocol="1" />
    
    <!-- Alternative filter for TM-T88VI with different product ID -->
    <usb-device 
        vendor-id="1208" 
        product-id="2" 
        class="7" 
        subclass="1" 
        protocol="1" />
    
    <!-- Generic Epson printer filter -->
    <usb-device 
        vendor-id="1208" 
        class="7" 
        subclass="1" 
        protocol="1" />
</resources>
```

## Epson TM-T88VI USB Specifications

- **Vendor ID**: 1208 (Epson)
- **Product ID**: 1 or 2 (varies by model)
- **Class**: 7 (Printer)
- **Subclass**: 1
- **Protocol**: 1

## How It Works

### 1. Automatic Detection
When the Epson TM-T88VI is connected via USB:
- Android automatically detects the device
- The app receives a USB_DEVICE_ATTACHED intent
- USB permissions are granted automatically by the system

### 2. Permission Handling
- USB permissions are handled at the system level
- No runtime permission requests needed
- Permissions are granted when the device is connected

### 3. Discovery Process
- Use "Discovery USB" button to find connected printers
- The app will automatically detect the TM-T88VI if properly connected
- USB permission status is checked before discovery

## Usage Instructions

### 1. Connect the Printer
- Connect the Epson TM-T88VI to your Android device via USB
- Ensure the printer is powered on
- Wait for the system to recognize the device

### 2. Discover Printers
- Open the app
- Tap "Discovery USB" button
- The app will scan for connected USB printers
- TM-T88VI should appear in the list if properly connected

### 3. Print Test
- Select the TM-T88VI from the discovered printers
- Tap "Print Test" to send a test print
- Use "Alt Print" if the standard method fails

## Troubleshooting

### Printer Not Detected
1. Check USB cable connection
2. Ensure printer is powered on
3. Try different USB cable
4. Check if printer appears in Android device settings

### Permission Issues
1. USB permissions are handled automatically
2. If issues persist, try disconnecting and reconnecting the printer
3. Restart the app after connecting the printer

### Connection Errors
1. Use "Reset Connection States" button
2. Try "Alt Print" method
3. Check printer status (paper, errors, etc.)

## Technical Notes

- USB permissions are granted at the system level when device is connected
- No additional runtime permissions required
- Device filter ensures only Epson printers are detected
- Multiple product IDs supported for different TM-T88VI variants

## Files Modified

1. `android/app/src/main/AndroidManifest.xml` - Added USB permissions and intent filters
2. `android/app/src/main/res/xml/device_filter.xml` - Created device filter for TM-T88VI
3. `lib/main.dart` - Added USB permission handling methods
4. `pubspec.yaml` - Added permission_handler dependency (for future use)

## Testing

To test the USB permissions setup:
1. Connect Epson TM-T88VI via USB
2. Open the app
3. Tap "Discovery USB"
4. Verify TM-T88VI appears in the list
5. Perform print test to confirm functionality
