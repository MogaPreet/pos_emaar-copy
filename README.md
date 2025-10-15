# Epson USB Printer Flutter App

A Flutter Android application that connects to Epson TM series printers via USB and prints barcodes with text.

## ⚠️ Current Status: Ready for Real Printer

The app is now configured to connect to **real Epson TM printers** using the ePOS2 SDK. However, it requires the native library files (`libepos2.so`) to function.

**Current Status:**
- ✅ Real ePOS2 SDK integration implemented
- ✅ USB printer detection and connection
- ✅ Actual barcode printing functionality
- ❌ Missing native libraries (see `NATIVE_LIBRARIES_NEEDED.md`)

**To complete the setup:**
1. Download the complete ePOS2 SDK from Epson
2. Extract the `libepos2.so` files to the `jniLibs` folders
3. Run the app - it will connect to your real Epson printer!

## Features

- **Auto USB Connection**: Automatically detects and connects to Epson TM printers via USB
- **Visual Status Indicator**: Shows printer connection status with a printer icon
- **Barcode Printing**: Prints barcodes with accompanying text
- **User-friendly UI**: Clean interface with connection status and print controls

## Requirements

- Android device with USB Host support
- Epson TM series printer (TM-T88, TM-T20, etc.)
- USB cable to connect printer to Android device

## Setup Instructions

1. **Connect Hardware**:
   - Connect your Epson TM printer to the Android device via USB cable
   - Ensure the printer is powered on

2. **Install the App**:
   ```bash
   cd epos_printer_app
   flutter run
   ```

3. **Grant Permissions**:
   - When prompted, grant USB permission for the Epson printer
   - The app will automatically detect the printer

## Usage

1. **Launch the App**: The app will automatically attempt to connect to the printer
2. **Check Status**: The printer icon will turn green when connected
3. **Print Test**: Click "Print Test" to print a sample barcode with text
4. **Reconnect**: Use the "Reconnect" button if the connection is lost

## Technical Details

### Android Integration
- Uses `ePOS2.jar` and `ePOSEasySelect.jar` for printer communication
- Implements USB permission handling for Epson devices (Vendor ID: 0x04b8)
- Supports TM series printers with ESC/POS commands

### Flutter Implementation
- Method channel communication between Flutter and native Android code
- Real-time connection status updates
- Error handling with user feedback

## File Structure

```
epos_printer_app/
├── android/
│   └── app/
│       ├── libs/
│       │   ├── ePOS2.jar
│       │   └── ePOSEasySelect.jar
│       └── src/main/kotlin/com/example/epos_printer_app/
│           └── MainActivity.kt
├── lib/
│   └── main.dart
└── README.md
```

## Troubleshooting

- **Printer not detected**: Ensure USB cable is properly connected and printer is powered on
- **Permission denied**: Grant USB permission when prompted by Android
- **Print fails**: Check printer paper and ensure printer is online
- **Connection lost**: Use the "Reconnect" button to re-establish connection

## Supported Printers

- Epson TM-T88 series
- Epson TM-T20 series
- Other Epson TM series printers with USB connectivity

## Development

To modify the app:

1. **Change barcode data**: Edit the `data` parameter in `_printBarcode()` method
2. **Modify text**: Edit the `text` parameter in `_printBarcode()` method
3. **Add new features**: Extend the `MainActivity.kt` with additional printer commands

## License

This project is for demonstration purposes. Please ensure you have proper licensing for the Epson ePOS2 SDK in production use.