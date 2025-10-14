# Print Troubleshooting Guide

## Overview
This guide helps diagnose and fix print issues in the POS Emaar application. The app now includes comprehensive diagnostic logging to identify print problems.

## Diagnostic Features Added

### 1. Enhanced Logging
- **Print Diagnostics**: Comprehensive system check before printing
- **Safe Print Logging**: Detailed logging of print attempts and failures
- **Error Tracking**: Full error messages and stack traces
- **Connection State Monitoring**: Real-time connection status tracking

### 2. Diagnostic Information
The app now logs the following information:
- Selected printer details (model, IP, series)
- Connection state and retry counts
- EpsonEPOS plugin availability
- USB permission status
- Print command details
- Error types and stack traces

## Common Print Issues and Solutions

### 1. No Printer Selected
**Symptoms**: White printer icon, no green state
**Diagnosis**: Check logs for "No printer selected"
**Solutions**:
- Tap the white printer icon to start auto-detection
- Ensure printer is connected (USB or network)
- Check USB permissions are granted
- Verify printer is powered on

### 2. USB Permission Issues
**Symptoms**: Permission denied errors, discovery fails
**Diagnosis**: Check logs for "USB permission check failed"
**Solutions**:
- Grant USB permissions when prompted
- Check Android device settings for USB permissions
- Try disconnecting and reconnecting the printer
- Restart the app after granting permissions

### 3. Plugin/Connection Issues
**Symptoms**: Epos2Exception errors, connection failures
**Diagnosis**: Check logs for "Epos2Exception" or "disconnect"
**Solutions**:
- Check printer connection (cable, power)
- Verify printer is compatible (TM-T88VI, TM-T20, etc.)
- Try alternative print methods
- Reset connection states using the app
- Restart the printer

### 4. Print Command Issues
**Symptoms**: Commands created but print fails
**Diagnosis**: Check logs for command details and error messages
**Solutions**:
- Verify print commands are properly formatted
- Check if printer supports the command types
- Try simpler print commands
- Check printer paper and status

### 5. Network Printer Issues
**Symptoms**: TCP discovery fails, network errors
**Diagnosis**: Check logs for TCP discovery failures
**Solutions**:
- Verify network connectivity
- Check printer IP address and network settings
- Ensure printer and device are on same network
- Check firewall settings

## Step-by-Step Troubleshooting

### Step 1: Check Basic Setup
1. **Printer Connection**: Ensure printer is connected and powered on
2. **App State**: Check if printer icon is white (needs detection) or green (ready)
3. **Permissions**: Verify USB permissions are granted

### Step 2: Run Diagnostics
1. **Tap Printer Icon**: This will run automatic diagnostics
2. **Check Logs**: Look for diagnostic information in the console
3. **Review Errors**: Note any error messages or failed checks

### Step 3: Test Print
1. **Green Icon**: Tap green icon to test print
2. **Monitor Logs**: Watch for detailed print attempt logs
3. **Check Results**: Note success/failure and any error messages

### Step 4: Analyze Results
Based on the logs, identify the specific issue:
- **Connection Issues**: Check physical connections
- **Permission Issues**: Grant required permissions
- **Plugin Issues**: Try alternative methods or restart
- **Command Issues**: Verify print command format

## Log Analysis

### Key Log Messages to Look For

#### Successful Flow
```
=== PRINT DIAGNOSTICS START ===
Selected printer: TM-T88VI
Printer IP: 192.168.1.100
Connection state: true
USB permission status: true
=== PRINT DIAGNOSTICS END ===
=== SAFE PRINT START ===
Calling EpsonEPOS.onPrint with 6 commands
Print completed successfully
=== SAFE PRINT SUCCESS ===
```

#### Common Error Patterns
```
ERROR: No printer selected
ERROR: EpsonEPOS discovery test failed
ERROR: USB permission check failed
Print attempt 1 failed: Epos2Exception
Detected Epos2Exception, marking printer as disconnected
```

### Log Locations
- **Android**: Use `adb logcat` or Android Studio logcat
- **Flutter**: Check console output in your IDE
- **App**: Look for SnackBar messages in the UI

## Advanced Troubleshooting

### 1. Plugin Issues
If the EpsonEPOS plugin is causing issues:
- Check plugin version compatibility
- Verify Android SDK integration
- Try alternative print methods
- Consider plugin updates

### 2. Hardware Issues
If printer hardware is suspected:
- Test printer with other applications
- Check printer status and error lights
- Verify paper and ribbon (if applicable)
- Test with different USB cables

### 3. Network Issues
For network printers:
- Ping printer IP address
- Check network configuration
- Verify firewall settings
- Test with direct connection

### 4. Android-Specific Issues
- Check Android version compatibility
- Verify USB host mode support
- Check device-specific USB drivers
- Test on different Android devices

## Prevention Tips

### 1. Regular Maintenance
- Keep printer firmware updated
- Clean printer regularly
- Check connections periodically
- Monitor printer status

### 2. Best Practices
- Always check printer status before printing
- Use proper print commands
- Handle errors gracefully
- Keep logs for debugging

### 3. Environment Setup
- Use stable network connections
- Ensure proper power supply
- Keep printer in good condition
- Use compatible hardware

## Getting Help

### 1. Collect Information
Before seeking help, collect:
- Complete error logs
- Printer model and configuration
- Android device information
- Network setup details

### 2. Test Scenarios
Try these test scenarios:
- Simple text print
- Different printer models
- Various connection types
- Different Android devices

### 3. Documentation
Keep track of:
- What works and what doesn't
- Error patterns and frequencies
- Successful configurations
- Failed attempts and solutions

## Quick Fixes

### Immediate Actions
1. **Restart App**: Close and reopen the application
2. **Reset States**: Use the reset connection states feature
3. **Reconnect Printer**: Disconnect and reconnect the printer
4. **Check Permissions**: Verify all required permissions are granted

### Emergency Workarounds
1. **Alternative Print**: Try the alternative print method
2. **Manual Discovery**: Use manual discovery buttons
3. **Different Printer**: Try with a different printer if available
4. **Network vs USB**: Switch between network and USB connections

The enhanced diagnostic system should help identify the root cause of print issues quickly and accurately. Always check the logs first before trying other solutions.
