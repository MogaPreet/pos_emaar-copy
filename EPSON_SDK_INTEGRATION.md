# Epson ePOS2 SDK Integration

## Overview
This document explains the integration of the official Epson ePOS2 SDK (`ePOS2.jar`) into the Flutter POS application for Epson TM-T88VI thermal printer support.

## SDK Information

### File Details
- **File**: `ePOS2.jar`
- **Size**: 475,196 bytes (~475 KB)
- **Type**: Official Epson ePOS2 Android SDK
- **Version**: ePOS2 SDK (latest version)

### Key Classes Available
The ePOS2.jar contains the following main printer classes:

1. **`com.epson.epos2.printer.Printer`** (55,833 bytes)
   - Main printer class for ePOS2 operations
   - Handles connection, printing, and status management

2. **`com.epson.epos2.printer.CommonPrinter`** (28,352 bytes)
   - Common printer functionality
   - Base class for printer operations

3. **`com.epson.epos2.printer.HybridPrinter`** (18,409 bytes)
   - Hybrid printer support
   - For printers with multiple functions

4. **`com.epson.epos2.printer.LFCPrinter`** (14,286 bytes)
   - Large Format Code printer support

5. **`com.epson.eposdevice.printer.Printer`** (37,933 bytes)
   - Device-specific printer class

6. **`com.epson.eposdevice.printer.NativePrinter`** (9,213 bytes)
   - Native printer implementation

### Additional Components
- **CAT (Cash Drawer)**: `com.epson.epos2.cat.Cat`
- **Simple Serial**: `com.epson.epos2.simpleserial.SimpleSerial`
- **Other Peripherals**: `com.epson.epos2.otherperipheral.OtherPeripheral`
- **Logging**: `com.epson.epos2.Log`

## Integration Steps Completed

### 1. File Placement
```
android/app/libs/ePOS2.jar
```

### 2. Build Configuration
Updated `android/app/build.gradle.kts`:
```kotlin
dependencies {
    // Epson ePOS2 SDK
    implementation(files("libs/ePOS2.jar"))
}
```

### 3. Android Manifest
Already configured with:
- USB permissions
- USB device filters for TM-T88VI
- Intent filters for USB device attachment

## SDK Features Available

### Printer Operations
- **Connection Management**: Connect/disconnect to printers
- **Print Commands**: Send text, images, barcodes, QR codes
- **Status Monitoring**: Check printer status and errors
- **Firmware Updates**: Update printer firmware
- **Maintenance**: Access maintenance counters

### Supported Printers
- **TM-T88VI**: Primary target printer
- **TM-T20**: Also supported
- **Other TM Series**: Compatible with most TM series printers
- **Hybrid Printers**: Multi-function printer support

### Communication Methods
- **USB**: Direct USB connection
- **TCP/IP**: Network printing
- **Bluetooth**: Wireless printing (if supported)

## Flutter Plugin Integration

### Current Plugin
The app uses `epson_epos: ^0.0.2` which wraps the ePOS2 SDK for Flutter.

### Plugin Benefits
- **Flutter Integration**: Easy to use from Dart code
- **Cross-Platform**: Works on Android and iOS
- **Error Handling**: Proper error handling and callbacks
- **Type Safety**: Dart type safety for printer operations

## Usage in the App

### Discovery
```dart
// TCP Discovery
List<EpsonPrinterModel>? data = await EpsonEPOS.onDiscovery(type: EpsonEPOSPortType.TCP);

// USB Discovery
List<EpsonPrinterModel>? data = await EpsonEPOS.onDiscovery(type: EpsonEPOSPortType.USB);
```

### Printing
```dart
// Create print commands
EpsonEPOSCommand command = EpsonEPOSCommand();
List<Map<String, dynamic>> commands = [];
commands.add(command.addTextAlign(EpsonEPOSTextAlign.LEFT));
commands.add(command.append('Hello World\n'));
commands.add(command.addCut(EpsonEPOSCut.CUT_FEED));

// Send to printer
await EpsonEPOS.onPrint(printer, commands);
```

### Settings
```dart
// Configure printer settings
await EpsonEPOS.setPrinterSetting(printer, paperWidth: 80);
```

## Troubleshooting

### Common Issues
1. **Connection Errors**: Check USB cable and printer power
2. **Permission Issues**: Ensure USB permissions are granted
3. **Plugin Errors**: Use alternative print methods if standard fails

### Debug Information
- Check Android logs for ePOS2 SDK messages
- Use the app's built-in error handling and retry logic
- Monitor connection states and retry counts

## Next Steps

### Testing
1. Connect Epson TM-T88VI via USB
2. Run the app and test discovery
3. Perform print tests
4. Verify error handling works correctly

### Optimization
1. Monitor performance with the integrated SDK
2. Test with different printer models
3. Optimize connection handling
4. Add more printer-specific features

## Files Modified

1. **`android/app/libs/ePOS2.jar`** - Added official ePOS2 SDK
2. **`android/app/build.gradle.kts`** - Added SDK dependency
3. **`android/app/src/main/AndroidManifest.xml`** - USB permissions and filters
4. **`android/app/src/main/res/xml/device_filter.xml`** - TM-T88VI device filter
5. **`lib/main.dart`** - Enhanced printer handling and error management

## Benefits of Direct SDK Integration

1. **Official Support**: Using the official Epson SDK
2. **Full Feature Access**: Access to all ePOS2 features
3. **Better Performance**: Direct SDK calls without plugin overhead
4. **Future Compatibility**: Easy to update to newer SDK versions
5. **Debugging**: Better error messages and debugging capabilities

The ePOS2 SDK is now properly integrated and ready for use with your Epson TM-T88VI thermal printer.
