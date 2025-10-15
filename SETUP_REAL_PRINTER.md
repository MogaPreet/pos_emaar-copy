# Setting Up Real Epson Printer Integration

This guide explains how to convert the demo app to work with real Epson TM printers.

## Step 1: Download Complete ePOS2 SDK

1. Visit the [Epson ePOS2 SDK download page](https://download4.epson.biz/sec_pubs/pos/reference_en/epos_android/)
2. Download the complete Android SDK package
3. Extract the files - you should get:
   - `ePOS2.jar`
   - `libepos2.so` (native library files for different architectures)
   - Documentation and examples

## Step 2: Add Native Libraries

1. Create the following directory structure in your Android project:
   ```
   android/app/src/main/jniLibs/
   ├── arm64-v8a/
   │   └── libepos2.so
   ├── armeabi-v7a/
   │   └── libepos2.so
   ├── x86/
   │   └── libepos2.so
   └── x86_64/
       └── libepos2.so
   ```

2. Copy the appropriate `libepos2.so` files to each architecture folder

## Step 3: Enable JAR Dependencies

1. Uncomment the dependencies in `android/app/build.gradle.kts`:
   ```kotlin
   dependencies {
       implementation(files("libs/ePOS2.jar"))
       implementation(files("libs/ePOSEasySelect.jar"))
   }
   ```

## Step 4: Enable ePOS2 Imports

1. Uncomment the imports in `MainActivity.kt`:
   ```kotlin
   import com.epson.epos2.Epos2Exception
   import com.epson.epos2.printer.Printer
   ```

## Step 5: Replace Simulation Code

Replace the simulation methods in `MainActivity.kt` with real ePOS2 SDK calls:

### Connect to Printer:
```kotlin
private fun connectToPrinter(): Boolean {
    try {
        mPrinter = Printer(Printer.TM_T88, Printer.MODEL_ANK, this)
        mPrinter?.connect("USB:", Printer.PARAM_DEFAULT)
        Log.d("EpsonUSB", "Successfully connected to printer")
        return true
    } catch (e: Epos2Exception) {
        Log.e("EpsonUSB", "Failed to connect to printer: ${e.errorStatus}")
        mPrinter = null
        return false
    }
}
```

### Print Barcode:
```kotlin
private fun printBarcode(data: String, text: String) {
    if (mPrinter == null) {
        throw Exception("Printer not connected")
    }
    try {
        mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
        mPrinter?.addText("$text\n")
        mPrinter?.addBarcode(
            data,
            Printer.BARCODE_CODE128,
            Printer.HRI_BELOW,
            Printer.FONT_A,
            2,
            80
        )
        mPrinter?.addFeedLine(2)
        mPrinter?.addCut(Printer.CUT_FEED)
        mPrinter?.sendData(Printer.PARAM_DEFAULT)
    } catch (e: Epos2Exception) {
        e.printStackTrace()
        throw e
    }
}
```

## Step 6: Test with Real Printer

1. Connect your Epson TM printer via USB
2. Run the app: `flutter run`
3. Grant USB permission when prompted
4. Test printing functionality

## Troubleshooting

- **"library libepos2.so not found"**: Ensure native libraries are in the correct `jniLibs` folders
- **Printer not detected**: Check USB connection and vendor ID (0x04b8 for Epson)
- **Permission denied**: Grant USB permission in Android settings
- **Print fails**: Check printer paper and ensure printer is online

## Supported Printers

- Epson TM-T88 series
- Epson TM-T20 series  
- Epson TM-T82 series
- Other Epson TM series with USB connectivity

## License

Ensure you have proper licensing for the Epson ePOS2 SDK for production use.
