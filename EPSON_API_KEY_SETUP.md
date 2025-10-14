# Epson ePOS2 API Key Setup

## Overview
This document explains how to obtain and configure the Epson ePOS2 API key for your Flutter POS application.

## Current Configuration

### Android Manifest
The following permissions and API key configuration have been added to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- USB permissions for Epson TM-T88VI thermal printer -->
<uses-permission android:name="android.permission.USB_PERMISSION" />
<uses-feature android:name="android.hardware.usb.host" android:required="false" />

<application>
    <!-- Epson ePOS2 API Key -->
    <meta-data
        android:name="com.epson.epos2.apikey"
        android:value="YOUR_API_KEY_HERE" />
</application>
```

## How to Get Your Epson API Key

### Step 1: Register with Epson
1. Visit the [Epson ePOS2 Developer Portal](https://www.epson-biz.com/modules/pos/index.php?page=epos2_developer)
2. Create an account or log in
3. Navigate to the API Key section

### Step 2: Request API Key
1. Fill out the API key request form
2. Provide your application details:
   - Application name: "POS Emaar"
   - Package name: "com.emaar.pos.pos_emaar"
   - Description: "Flutter POS application for Epson TM-T88VI thermal printer"
3. Submit the request

### Step 3: Receive API Key
- Epson will review your request
- You'll receive an email with your API key
- The API key is typically a long string of characters

## Configuring the API Key

### Replace Placeholder
Once you receive your API key, replace `YOUR_API_KEY_HERE` in the AndroidManifest.xml:

```xml
<meta-data
    android:name="com.epson.epos2.apikey"
    android:value="your-actual-api-key-here" />
```

### Example
```xml
<meta-data
    android:name="com.epson.epos2.apikey"
    android:value="ABCD1234EFGH5678IJKL9012MNOP3456QRST7890UVWX1234YZAB5678CDEF9012" />
```

## API Key Requirements

### Development vs Production
- **Development**: You can use a development API key for testing
- **Production**: You need a production API key for release builds

### Key Characteristics
- API keys are typically 64+ characters long
- They contain alphanumeric characters
- Each key is unique to your application
- Keys are tied to your package name

## Security Considerations

### Do Not Commit API Keys
1. **Never commit API keys to version control**
2. Use environment variables or build configurations
3. Consider using a separate config file

### Alternative Configuration (Recommended)
Create a separate configuration file:

#### 1. Create `android/app/src/main/res/values/config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="epson_api_key">YOUR_API_KEY_HERE</string>
</resources>
```

#### 2. Update AndroidManifest.xml:
```xml
<meta-data
    android:name="com.epson.epos2.apikey"
    android:value="@string/epson_api_key" />
```

#### 3. Add to `.gitignore`:
```
android/app/src/main/res/values/config.xml
```

## Testing Without API Key

### Development Mode
- Some ePOS2 features work without an API key in development
- Basic printing functionality may work
- Advanced features require a valid API key

### Error Handling
The app includes error handling for API key issues:
- Invalid API key errors
- Missing API key warnings
- Graceful fallback behavior

## Troubleshooting

### Common Issues

#### 1. "Invalid API Key" Error
- Verify the API key is correct
- Check for extra spaces or characters
- Ensure the key is properly formatted

#### 2. "API Key Not Found" Error
- Verify the meta-data is in the correct location
- Check the AndroidManifest.xml syntax
- Ensure the application tag is properly closed

#### 3. Permission Denied
- Verify USB permissions are granted
- Check device filter configuration
- Ensure printer is properly connected

### Debug Steps
1. Check Android logs for ePOS2 errors
2. Verify API key format and placement
3. Test with a known working API key
4. Check Epson developer portal for key status

## Production Deployment

### Before Release
1. Obtain production API key from Epson
2. Update configuration with production key
3. Test thoroughly with production key
4. Verify all printer functions work correctly

### App Store Requirements
- Some app stores may require API key documentation
- Provide Epson API key information if requested
- Ensure compliance with Epson's terms of service

## Support

### Epson Support
- [Epson ePOS2 Developer Portal](https://www.epson-biz.com/modules/pos/index.php?page=epos2_developer)
- [Epson Technical Support](https://www.epson-biz.com/modules/pos/index.php?page=support)
- [ePOS2 Documentation](https://www.epson-biz.com/modules/pos/index.php?page=epos2_doc)

### Application Support
- Check the app's error handling and logging
- Use the built-in troubleshooting features
- Monitor connection states and retry logic

## Next Steps

1. **Get API Key**: Register with Epson and request an API key
2. **Configure**: Replace `YOUR_API_KEY_HERE` with your actual key
3. **Test**: Verify the API key works with your printer
4. **Deploy**: Use production API key for release builds

The API key configuration is now ready in your AndroidManifest.xml. Once you obtain your API key from Epson, simply replace the placeholder value and your app will be ready to use the full ePOS2 SDK functionality.
