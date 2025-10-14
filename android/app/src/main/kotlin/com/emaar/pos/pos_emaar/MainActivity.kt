package com.emaar.pos.pos_emaar

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.emaar.pos.usb_permissions"
    private val ACTION_USB_PERMISSION = "com.emaar.pos.USB_PERMISSION"
    private val EPSON_VENDOR_ID = 1208
    
    private lateinit var usbManager: UsbManager
    private lateinit var methodChannel: MethodChannel
    private var pendingPermissionCallback: MethodChannel.Result? = null
    
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                Log.d("USB_PERMISSION", "USB permission granted for device: ${it.deviceName}")
                                pendingPermissionCallback?.success(true)
                            }
                        } else {
                            Log.d("USB_PERMISSION", "USB permission denied for device: ${device?.deviceName}")
                            pendingPermissionCallback?.success(false)
                        }
                        pendingPermissionCallback = null
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestUSBPermissions" -> {
                    requestUSBPermissions(result)
                }
                "checkUSBPermissions" -> {
                    checkUSBPermissions(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        registerReceiver(usbReceiver, filter)
    }

    override fun onPause() {
        super.onPause()
        unregisterReceiver(usbReceiver)
    }

    private fun requestUSBPermissions(result: MethodChannel.Result) {
        try {
            Log.d("USB_PERMISSION", "Requesting USB permissions for Epson devices")
            
            val devices = usbManager.deviceList
            var foundEpsonDevice = false
            
            for (device in devices.values) {
                if (device.vendorId == EPSON_VENDOR_ID) {
                    foundEpsonDevice = true
                    Log.d("USB_PERMISSION", "Found Epson device: ${device.deviceName}, Vendor ID: ${device.vendorId}")
                    
                    if (!usbManager.hasPermission(device)) {
                        Log.d("USB_PERMISSION", "Requesting permission for device: ${device.deviceName}")
                        pendingPermissionCallback = result
                        
                        val permissionIntent = PendingIntent.getBroadcast(
                            this, 0, Intent(ACTION_USB_PERMISSION), 
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        usbManager.requestPermission(device, permissionIntent)
                        return
                    } else {
                        Log.d("USB_PERMISSION", "Permission already granted for device: ${device.deviceName}")
                    }
                }
            }
            
            if (!foundEpsonDevice) {
                Log.d("USB_PERMISSION", "No Epson devices found")
                result.success(false)
            } else {
                Log.d("USB_PERMISSION", "All Epson devices already have permission")
                result.success(true)
            }
            
        } catch (e: Exception) {
            Log.e("USB_PERMISSION", "Error requesting USB permissions", e)
            result.error("USB_PERMISSION_ERROR", e.message, null)
        }
    }

    private fun checkUSBPermissions(result: MethodChannel.Result) {
        try {
            Log.d("USB_PERMISSION", "Checking USB permissions for Epson devices")
            
            val devices = usbManager.deviceList
            var hasAllPermissions = true
            var foundEpsonDevice = false
            
            for (device in devices.values) {
                if (device.vendorId == EPSON_VENDOR_ID) {
                    foundEpsonDevice = true
                    Log.d("USB_PERMISSION", "Checking device: ${device.deviceName}, Has permission: ${usbManager.hasPermission(device)}")
                    
                    if (!usbManager.hasPermission(device)) {
                        hasAllPermissions = false
                    }
                }
            }
            
            if (!foundEpsonDevice) {
                Log.d("USB_PERMISSION", "No Epson devices found")
                result.success(false)
            } else {
                Log.d("USB_PERMISSION", "Permission check result: $hasAllPermissions")
                result.success(hasAllPermissions)
            }
            
        } catch (e: Exception) {
            Log.e("USB_PERMISSION", "Error checking USB permissions", e)
            result.error("USB_PERMISSION_ERROR", e.message, null)
        }
    }
}
