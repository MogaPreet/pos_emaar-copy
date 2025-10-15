package com.example.epos_printer_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.PendingIntent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.epson.epos2.Epos2Exception
import com.epson.epos2.printer.Printer
import org.json.JSONObject

class MainActivity: FlutterActivity() {
  private val CHANNEL = "epson_usb_printer"
  private var mPrinter: Printer? = null
  private var mUsbManager: UsbManager? = null
  private var mUsbDevice: UsbDevice? = null
  private var isPrinterConnected = false
  private val ACTION_USB_PERMISSION = "com.example.epos_printer_app.USB_PERMISSION"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    mUsbManager = getSystemService(Context.USB_SERVICE) as UsbManager?

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "autoConnectUsbPrinter" -> {
            val success = autoConnectUsbPrinter()
            result.success(success)
          }
          "printBarcode" -> {
            val data = call.argument<String>("data") ?: ""
            val text = call.argument<String>("text") ?: ""
            try {
              printBarcode(data, text)
              result.success(true)
            } catch (e: Exception) {
              result.error("PRINT_ERR", e.message, null)
            }
          }
          "printTestReceipt" -> {
            val orderId = call.argument<String>("orderId") ?: "01209457"
            try {
              printTestReceipt(orderId)
              result.success(true)
            } catch (e: Exception) {
              result.error("PRINT_ERR", e.message, e)
            }
          }
          "printTickets" -> {
            val ticketData = call.argument<String>("ticketData") ?: ""
            try {
              printTickets(ticketData)
              result.success(true)
            } catch (e: Exception) {
              result.error("PRINT_ERR", e.message, e)
            }
          }
          "printReceipt" -> {
            val ticketData = call.argument<String>("ticketData") ?: ""
            try {
              printRecipt(ticketData)
              result.success(true)
            } catch (e: Exception) {
              result.error("PRINT_ERR", e.message, e)
            }
          }
          "printVoidTransaction" -> {
            val ticketData = call.argument<String>("ticketData") ?: ""
            try {
              printVoidTransaction(ticketData)
              result.success(true)
            } catch (e: Exception) {
              result.error("PRINT_ERR", e.message, e)
            }
          }
          "isPrinterConnected" -> {
            // Always verify the actual connection status
            val actualStatus = verifyPrinterConnection()
            isPrinterConnected = actualStatus
            result.success(actualStatus)
          }
          else -> result.notImplemented()
        }
      }

    // Register USB permission receiver
    val filter = IntentFilter(ACTION_USB_PERMISSION)
    registerReceiver(usbReceiver, filter)
  }

  /** BroadcastReceiver to handle USB permission result */
  private val usbReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      if (intent.action == ACTION_USB_PERMISSION) {
        synchronized(this) {
          val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
          val granted: Boolean = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
          if (granted && device != null) {
            Log.d("EpsonUSB", "USB permission granted for device ${device.deviceName}")
            mUsbDevice = device
          } else {
            Log.d("EpsonUSB", "USB permission denied for device ${device?.deviceName}")
          }
        }
      }
    }
  }

  private fun autoConnectUsbPrinter(): Boolean {
    try {
      // Iterate connected USB devices and find Epson printer (vendorId = 0x04b8)
      val deviceList = mUsbManager?.deviceList
      if (deviceList == null || deviceList.isEmpty()) {
        Log.d("EpsonUSB", "No USB devices found")
        return false
      }
      
      Log.d("EpsonUSB", "Found ${deviceList.size} USB devices")
      
      deviceList.values.forEach { device ->
        Log.d("EpsonUSB", "USB Device: ${device.deviceName}, Vendor ID: ${device.vendorId}, Product ID: ${device.productId}")
        
        // Epson vendor ID is 0x04b8 (1208 in decimal)
        if (device.vendorId == 0x04b8) {
          Log.d("EpsonUSB", "Found Epson device: ${device.deviceName}")
          
          // Check if we already have permission
          if (mUsbManager?.hasPermission(device) == true) {
            Log.d("EpsonUSB", "Already have permission for Epson device")
            mUsbDevice = device
            return connectToPrinter()
          } else {
            Log.d("EpsonUSB", "Requesting permission for Epson device")
            // Request permission
            val pi = PendingIntent.getBroadcast(
              this, 0,
              Intent(ACTION_USB_PERMISSION), PendingIntent.FLAG_IMMUTABLE
            )
            mUsbManager?.requestPermission(device, pi)
            mUsbDevice = device
            // Don't return immediately, wait for permission callback
            return false
          }
        }
      }
      Log.d("EpsonUSB", "No Epson printer found among ${deviceList.size} devices")
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Error in autoConnectUsbPrinter: ${e.message}")
    }
    return false
  }

  private fun connectToPrinter(): Boolean {
    try {
      // Create printer instance for TM series
      mPrinter = Printer(Printer.TM_T88, Printer.MODEL_ANK, this)
      
      // Connect to USB printer
      mPrinter?.connect("USB:", Printer.PARAM_DEFAULT)
      
      // Verify connection by checking printer status
      val isConnected = verifyPrinterConnection()
      isPrinterConnected = isConnected
      
      if (isConnected) {
        Log.d("EpsonUSB", "Successfully connected to real printer")
      } else {
        Log.e("EpsonUSB", "Failed to verify printer connection")
        mPrinter = null
      }
      
      return isConnected
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Failed to connect to printer: ${e.errorStatus}")
      mPrinter = null
      isPrinterConnected = false
      return false
    }
  }

  private fun verifyPrinterConnection(): Boolean {
    return try {
      if (mPrinter == null) {
        Log.d("EpsonUSB", "Printer instance is null")
        false
      } else {
        // Try to get printer status to verify connection
        val status = mPrinter?.getStatus()
        val isConnected = status != null && status.connection == Printer.TRUE
        Log.d("EpsonUSB", "Printer connection status: $isConnected")
        isConnected
      }
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Error verifying printer connection: ${e.errorStatus}")
      false
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Error verifying printer connection: ${e.message}")
      false
    }
  }

  private fun printBarcode(data: String, text: String) {
    if (mPrinter == null || !isPrinterConnected) {
      throw Exception("Printer not connected")
    }
    try {
      // Center align
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)

      // Print the text above barcode
      mPrinter?.addText("$text\n")

      // Add barcode with Epson SDK
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
      Log.d("EpsonUSB", "Real print job sent to printer successfully")
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Print failed: ${e.errorStatus}")
      throw e
    }
  }

  private fun printTestReceipt(orderId: String) {
    if (mPrinter == null || !isPrinterConnected) {
      throw Exception("Printer not connected")
    }
    try {
      // Clear any existing commands
      mPrinter?.clearCommandBuffer()
      Log.d("EpsonUSB", "Starting test receipt print")

      // Center align text
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)

      // Add feed lines
      mPrinter?.addFeedLine(2)

      // Print header text
      mPrinter?.addText("AUTO-PRINT TEST\n")
      mPrinter?.addText("Barcode Test:\n")

      // Add barcode
      mPrinter?.addBarcode(
        orderId,
        Printer.BARCODE_CODE39,
        Printer.HRI_BELOW,
        Printer.FONT_A,
        2,
        80
      )


      mPrinter?.addFeedLine(1)
      mPrinter?.addText("Barcode should appear above\n")

      // Print printer model info
      mPrinter?.addText("Printer: TM-T88\n")

      // Print current time
      val currentTime = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
        .format(java.util.Date())
      mPrinter?.addText("Time: $currentTime\n")

      // Add more feed lines
      mPrinter?.addFeedLine(2)

      // Cut the paper
      mPrinter?.addCut(Printer.CUT_FEED)

      // Send the print job
      Log.d("EpsonUSB", "Sending print job to printer")
      mPrinter?.sendData(Printer.PARAM_DEFAULT)
      Log.d("EpsonUSB", "Test receipt printed successfully")
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Print test receipt failed: ${e.errorStatus}")
      throw e
    }
  }

  private fun printTickets(ticketData: String) {
    if (mPrinter == null || !isPrinterConnected) {
      throw Exception("Printer not connected")
    }

    try {
      val jsonData = JSONObject(ticketData)
      Log.d("EpsonUSB", "Received ticket data: $jsonData")

      // Expecting: { "ticketData": [ ... ] }
      val ticketsArray = jsonData.optJSONArray("ticketData")
      if (ticketsArray == null) {
        Log.e("EpsonUSB", "ticketData is not an array or missing")
        throw Exception("ticketData is malformed")
      }

      mPrinter?.clearCommandBuffer()

      for (i in 0 until ticketsArray.length()) {
        val ticket = ticketsArray.getJSONObject(i)

        // ===== HEADER =====
        mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
        mPrinter?.addText("EMAAR ENTERTAINMENT LLC\n")
        mPrinter?.addText(ticket.optString("eventName", "") + "\n")
        mPrinter?.addText("TRNNO 100067521300003\n")
        mPrinter?.addText("PO BOX NO 9440\n")
        mPrinter?.addText("DUBAI U.A.E\n")
        mPrinter?.addFeedLine(1)
        mPrinter?.addText("--------------------------------\n")

        // ===== TICKET INFO =====
        mPrinter?.addTextAlign(Printer.ALIGN_LEFT)
        mPrinter?.addText("Event Name: ${ticket.optString("eventName", "")}\n")
        mPrinter?.addText("Event Date: ${ticket.optString("eventDate", "")}\n")
        mPrinter?.addText("Event Time: ${ticket.optString("eventTime", "")}\n")
        mPrinter?.addText("Items: ${ticket.optString("itemName", "")}\n")
        mPrinter?.addFeedLine(1)

        // Handle barcodeValue as an array
        val barcodeArray = ticket.optJSONArray("barcodeValue")
        if (barcodeArray != null) {
          for (j in 0 until barcodeArray.length()) {
            val barcodeValue = barcodeArray.getString(j)
            // val asciiOrderId = barcodeValue.toByteArray(Charsets.US_ASCII)
            mPrinter?.addTextAlign(Printer.ALIGN_CENTER)

            
              mPrinter?.addBarcode(
                barcodeValue,
                Printer.BARCODE_CODE39,
                Printer.HRI_BELOW,
                Printer.FONT_A,
                2,
                80
              )
              Log.d("EpsonUSB", "BARCODE_CODE39 barcode added successfully")
           

            mPrinter?.addFeedLine(2)
            mPrinter?.addText("Order ID: $barcodeValue\n")
          }
        }
        mPrinter?.addText("--------------------------------\n")

        // ===== FOOTER =====
        mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
        mPrinter?.addText("*** THIS IS YOUR TICKET ***\n")
        mPrinter?.addFeedLine(1)
        mPrinter?.addText("Please go to the counter to get the ticket.\n")
        mPrinter?.addFeedLine(2)

        // ===== CUT PAPER =====
        mPrinter?.addCut(Printer.CUT_FEED)
      }

      // Send all tickets as a single print job
      mPrinter?.sendData(Printer.PARAM_DEFAULT)
      Log.d("EpsonUSB", "Ticket(s) printed successfully")

    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Printing failed: ${e.errorStatus}")
      throw e
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Unexpected error: ${e.message}")
      throw e
    }
  }




  // private fun printTickets(ticketData: String) {
  //   if (mPrinter == null || !isPrinterConnected) {
  //     throw Exception("Printer not connected")
  //   }
    
  //   try {
  //     val jsonData = JSONObject(ticketData)
  //     Log.d("EpsonUSB", "Received ticket data: $jsonData")
      
  //     // Clear any existing commands
  //     mPrinter?.clearCommandBuffer()
  //     Log.d("EpsonUSB", "Starting print tickets")
      
  //     // Center align text
  //     mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Print header
  //     mPrinter?.addText("TICKET RECEIPT\n")
  //     mPrinter?.addText("================\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(1)
      
  //     // Print ticket data (you can customize this based on your JSON structure)
  //     mPrinter?.addText("Ticket Data:\n")
  //     mPrinter?.addText("$ticketData\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Cut the paper
  //     mPrinter?.addCut(Printer.CUT_FEED)
      
  //     // Send the print job
  //     Log.d("EpsonUSB", "Sending print job to printer")
  //     mPrinter?.sendData(Printer.PARAM_DEFAULT)
  //     Log.d("EpsonUSB", "Tickets printed successfully")
  //   } catch (e: Epos2Exception) {
  //     Log.e("EpsonUSB", "Print tickets failed: ${e.errorStatus}")
  //     throw e
  //   } catch (e: Exception) {
  //     Log.e("EpsonUSB", "Print tickets error: ${e.message}")
  //     throw e
  //   }
  // }

  // private fun printRecipt(ticketData: String) {
  //   if (mPrinter == null || !isPrinterConnected) {
  //     throw Exception("Printer not connected")
  //   }
    
  //   try {
  //     val jsonData = JSONObject(ticketData)
  //     Log.d("EpsonUSB", "Received ticket data: $jsonData")
      
  //     // Clear any existing commands
  //     mPrinter?.clearCommandBuffer()
  //     Log.d("EpsonUSB", "Starting print tickets")
      
  //     // Center align text
  //     mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Print header
  //     mPrinter?.addText("TICKET RECEIPT\n")
  //     mPrinter?.addText("================\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(1)
      
  //     // Print ticket data (you can customize this based on your JSON structure)
  //     mPrinter?.addText("Ticket Data:\n")
  //     mPrinter?.addText("$ticketData\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Cut the paper
  //     mPrinter?.addCut(Printer.CUT_FEED)
      
  //     // Send the print job
  //     Log.d("EpsonUSB", "Sending print job to printer")
  //     mPrinter?.sendData(Printer.PARAM_DEFAULT)
  //     Log.d("EpsonUSB", "Tickets printed successfully")
  //   } catch (e: Epos2Exception) {
  //     Log.e("EpsonUSB", "Print tickets failed: ${e.errorStatus}")
  //     throw e
  //   } catch (e: Exception) {
  //     Log.e("EpsonUSB", "Print tickets error: ${e.message}")
  //     throw e
  //   }
  // }

  private fun printRecipt(ticketData: String) {
    if (mPrinter == null || !isPrinterConnected) {
      throw Exception("Printer not connected")
    }

    try {
      val jsonData = JSONObject(ticketData)
      Log.d("EpsonUSB", "Received ticket data: $jsonData")

      // Expecting: { "ticketData": { ... } }
      val ticketsData = jsonData.optJSONObject("ticketData")
      if (ticketsData == null) {
        Log.e("EpsonUSB", "ticketData is not an object or missing")
        throw Exception("ticketData is malformed")
      }

      // Fetch & handle all supported fields safely, converting as needed
      val headerName = ticketsData.optString("name", "")
      val taxRegNo = ticketsData.optString("taxRegistrationNo", "")
      val saleNumber = ticketsData.optString("saleNumber", "")
      val date = ticketsData.optString("date", "")
      val time = ticketsData.optString("time", "")
      val posNumber = ticketsData.optString("posNumber", "")
      val userId = ticketsData.optString("userId", "")
      val tnc = ticketsData.optString("tnc", "")
      val address = ticketsData.optString("address", "")
      val instruction = ticketsData.optString("instruction", "")
      val website = ticketsData.optString("website", "")

      val discountName = ticketsData.optString("discountName", "")
      val discountTotal = ticketsData.opt("discountTotal")?.toString() ?: ""
      val totalExclVat = ticketsData.opt("totalExclVat")?.toString() ?: ""
      val vatAmount = ticketsData.opt("vatAmount")?.toString() ?: ""
      val totalInclVat = ticketsData.opt("totalInclVat")?.toString() ?: ""
      val cash = ticketsData.opt("cash")?.toString() ?: ""
      val change = ticketsData.opt("change")?.toString() ?: ""
      val balance = ticketsData.opt("balance")?.toString() ?: ""
      val barcodeValue = ticketsData.optString("barcodeValue", "")

      // Clear previous commands
      mPrinter?.clearCommandBuffer()

      // ===== HEADER =====
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      mPrinter?.addText("EMAAR ENTERTAINMENT LLC\n")
      if (headerName.isNotEmpty()) mPrinter?.addText("$headerName\n")
      if (address.isNotEmpty()) mPrinter?.addText("$address\n")
      mPrinter?.addText("TRNNO $taxRegNo\n")
      mPrinter?.addText("PO BOX NO 9440\n")
      mPrinter?.addText("DUBAI U.A.E\n")
      mPrinter?.addFeedLine(1)
      if (instruction.isNotEmpty()) mPrinter?.addText("$instruction\n")

      // Sale info
      mPrinter?.addTextAlign(Printer.ALIGN_LEFT)
      mPrinter?.addText("Sale No: $saleNumber\n")
      mPrinter?.addText("Date: $date    Time: $time\n")
      mPrinter?.addText("POS No: $posNumber\n")
      mPrinter?.addText("User ID: $userId\n")
      mPrinter?.addText("----------------------------------------\n")

      // ===== ITEMS TABLE =====
      // items is loaded from ticketsData["items"]: JSONArray
      val itemArray = ticketsData.optJSONArray("items")
      val items = mutableListOf<Triple<String, String, String>>()
      if (itemArray != null) {
        for (i in 0 until itemArray.length()) {
          val itemObj = itemArray.optJSONObject(i)
          if (itemObj != null) {
            val qty = itemObj.opt("qty")?.toString() ?: ""
            val description = itemObj.optString("description", "")
            val amount = itemObj.opt("amount")?.toString() ?: ""
            items.add(Triple(qty, description, amount))
          }
        }
      }

      mPrinter?.addText("QTY  ITEM DESCRIPTION            AMOUNT\n")
      mPrinter?.addText("----------------------------------------\n")

      // Wrap description if it is too long for one line; print qty and amount only on the first line
      val maxDescLenPerLine = 27 // Area for description
      for (item in items) {
        val qty = item.first.padEnd(4).take(4)
        val desc = item.second
        val amt = item.third.padStart(9)

        // Split description into multiple lines if needed
        val descLines = mutableListOf<String>()
        var start = 0
        while (start < desc.length) {
          val end = (start + maxDescLenPerLine).coerceAtMost(desc.length)
          descLines.add(desc.substring(start, end))
          start = end
        }

        if (descLines.isNotEmpty()) {
          // First line with qty, description, amount
          val descFirst = descLines[0].padEnd(maxDescLenPerLine)
          mPrinter?.addText("$qty$descFirst$amt\n")
          // Next lines: only description (indented to match)
          for (i in 1 until descLines.size) {
            val descExtra = descLines[i].padEnd(maxDescLenPerLine)
            // Indent to align description under desc column
            mPrinter?.addText("    $descExtra\n")
          }
        } else {
          // If description is empty, just print qty and amt
          mPrinter?.addText("$qty${"".padEnd(maxDescLenPerLine)}$amt\n")
        }
      }

      mPrinter?.addText("----------------------------------------\n")

      // ===== TOTALS & DISCOUNTS =====
      if (discountName.isNotEmpty() && discountTotal != "0" && discountTotal != "0.0" && discountTotal != "0.00") {
        val label = discountName.padEnd(20)
        val value = discountTotal.padStart(10)
        mPrinter?.addText("$label$value\n")
      }
      val totals = listOf(
        "TOTAL EXCL VAT" to totalExclVat,
        "VAT 5%" to vatAmount,
        "TOTAL INCL VAT" to totalInclVat,
        "CASH" to cash,
        "CHANGE" to change,
        "BALANCE" to balance,
        "TOTAL" to totalInclVat
      )
      for ((label, value) in totals) {
        if (value.isNotEmpty() && value != "0" && value != "0.0" && value != "0.00") {
          val labelText = label.padEnd(20)
          val valueText = value.padStart(10)
          mPrinter?.addText("$labelText$valueText\n")
        }
      }
      mPrinter?.addText("----------------------------------------\n")

      // ===== BARCODE if any =====
      if (barcodeValue.isNotEmpty()) {
        try {
          mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
          mPrinter?.addBarcode(
            barcodeValue,
            Printer.BARCODE_CODE128,
            Printer.HRI_BELOW,
            Printer.FONT_A,
            60, // height
            2   // width
          )
        } catch (e: Exception) {
          Log.e("EpsonUSB", "Barcode print failed: ${e.message}")
        }
        mPrinter?.addFeedLine(1)
      }

      // ===== FOOTER =====
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      mPrinter?.addText("THANK YOU FOR VISITING US\n")
      mPrinter?.addText("*** TERMS AND CONDITIONS ***\n")

      // Remove any HTML tags for T&C (optional, simple replacement)
      val tncPlain = android.text.Html.fromHtml(tnc, android.text.Html.FROM_HTML_MODE_LEGACY).toString()
      mPrinter?.addText("$tncPlain\n")
      if (website.isNotEmpty()) mPrinter?.addText("$website\n")
      if (address.isEmpty()) mPrinter?.addText("At The Dubai Mall\n")
      mPrinter?.addText("800 382246255\n")
      mPrinter?.addFeedLine(2)

      // ===== CUT PAPER =====
      mPrinter?.addCut(Printer.CUT_FEED)

      // Send to printer
      mPrinter?.sendData(Printer.PARAM_DEFAULT)
      Log.d("EpsonUSB", "Receipt printed successfully")

    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Printing failed: ${e.errorStatus}")
      throw e
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Unexpected error: ${e.message}")
      throw e
    }
  }


  // private fun printVoidTransaction(ticketData: String) {
  //   if (mPrinter == null || !isPrinterConnected) {
  //     throw Exception("Printer not connected")
  //   }
    
  //   try {
  //     val jsonData = JSONObject(ticketData)
  //     Log.d("EpsonUSB", "Received ticket data: $jsonData")
      
  //     // Clear any existing commands
  //     mPrinter?.clearCommandBuffer()
  //     Log.d("EpsonUSB", "Starting print tickets")
      
  //     // Center align text
  //     mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Print header
  //     mPrinter?.addText("TICKET RECEIPT\n")
  //     mPrinter?.addText("================\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(1)
      
  //     // Print ticket data (you can customize this based on your JSON structure)
  //     mPrinter?.addText("Ticket Data:\n")
  //     mPrinter?.addText("$ticketData\n")
      
  //     // Add feed lines
  //     mPrinter?.addFeedLine(2)
      
  //     // Cut the paper
  //     mPrinter?.addCut(Printer.CUT_FEED)
      
  //     // Send the print job
  //     Log.d("EpsonUSB", "Sending print job to printer")
  //     mPrinter?.sendData(Printer.PARAM_DEFAULT)
  //     Log.d("EpsonUSB", "Tickets printed successfully")
  //   } catch (e: Epos2Exception) {
  //     Log.e("EpsonUSB", "Print tickets failed: ${e.errorStatus}")
  //     throw e
  //   } catch (e: Exception) {
  //     Log.e("EpsonUSB", "Print tickets error: ${e.message}")
  //     throw e
  //   }
  // }

  private fun printVoidTransaction(ticketData: String) {
    if (mPrinter == null || !isPrinterConnected) {
      throw Exception("Printer not connected")
    }

    try {
      val jsonData = org.json.JSONObject(ticketData)
      Log.d("EpsonUSB", "Received ticket data for void: $jsonData")

      val ticketsData = jsonData.optJSONObject("ticketData")
      if (ticketsData == null) {
        Log.e("EpsonUSB", "ticketData is not an object or missing")
        throw Exception("ticketData is malformed")
      }

      val name = ticketsData.optString("name", "")
      val address = ticketsData.optString("address", "")
      val taxRegistrationNo = ticketsData.optString("taxRegistrationNo", "")
      val website = ticketsData.optString("website", "")
      val saleNumber = ticketsData.optString("saleNumber", "")
      val date = ticketsData.optString("date", "")
      val time = ticketsData.optString("time", "")
      val posNumber = ticketsData.optString("posNumber", "")
      val userId = ticketsData.optString("userId", "")
      val discountName = ticketsData.optString("discountName", "")
      val discountTotal = ticketsData.opt("discountTotal")?.toString() ?: ""
      val totalExclVat = ticketsData.opt("totalExclVat")?.toString() ?: ""
      val vatAmount = ticketsData.opt("vatAmount")?.toString() ?: ""
      val totalInclVat = ticketsData.opt("totalInclVat")?.toString() ?: ""
      val cash = ticketsData.opt("cash")?.toString() ?: ""
      val change = ticketsData.opt("change")?.toString() ?: ""
      val balance = ticketsData.opt("balance")?.toString() ?: ""
      val barcodeValue = ticketsData.optString("barcodeValue", "")
      val tnc = ticketsData.optString("tnc", "")

      // Clear previous commands
      mPrinter?.clearCommandBuffer()

      // ===== HEADER =====
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      mPrinter?.addText("***** VOID RECEIPT *****\n")
      mPrinter?.addFeedLine(1)
      mPrinter?.addText("TAX INVOICE\n")
      mPrinter?.addFeedLine(1)
      if (name.isNotEmpty()) mPrinter?.addText("$name\n")
      if (address.isNotEmpty()) mPrinter?.addText("$address\n")
      if (taxRegistrationNo.isNotEmpty()) mPrinter?.addText("TRNNO $taxRegistrationNo\n")
      mPrinter?.addText("PO BOX NO 9440\n")
      mPrinter?.addText("DUBAI U.A.E\n")
      mPrinter?.addFeedLine(1)

      // ===== SALE DETAILS =====
      mPrinter?.addTextAlign(Printer.ALIGN_LEFT)
      if (saleNumber.isNotEmpty()) mPrinter?.addText("Sale No: $saleNumber\n")
      if (date.isNotEmpty() || time.isNotEmpty()) mPrinter?.addText("Date: $date   Time: $time\n")
      if (posNumber.isNotEmpty()) mPrinter?.addText("POS No: $posNumber\n")
      if (userId.isNotEmpty()) mPrinter?.addText("User ID: $userId\n")
      mPrinter?.addFeedLine(1)
      mPrinter?.addText("----------------------------------------\n")
      mPrinter?.addText("QTY    ITEM DESCRIPTION           AMOUNT\n")
      mPrinter?.addText("----------------------------------------\n")

      // ===== ITEMS TABLE =====
      val itemsArray = ticketsData.optJSONArray("items")
      if (itemsArray != null && itemsArray.length() > 0) {
        for (i in 0 until itemsArray.length()) {
          val item = itemsArray.optJSONObject(i) ?: continue
          val qty = item.opt("qty")?.toString() ?: ""
          val desc = item.optString("description", "")
          val amt = item.opt("amount")?.toString() ?: ""
          val qtyFormatted = qty.padEnd(5, ' ')
          // Print with alignment
          mPrinter?.addText(String.format("%-6s%-25s%10s\n", qtyFormatted, desc, amt))
        }
      }
      mPrinter?.addText("----------------------------------------\n")

      // ===== TOTALS =====
      if (discountName.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", discountName, discountTotal))
      } else if (discountTotal.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "DISCOUNT", discountTotal))
      }
      if (totalExclVat.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL EXCL VAT", totalExclVat))
      }
      if (vatAmount.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "VAT", vatAmount))
      }
      if (totalInclVat.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL INCL VAT", totalInclVat))
      }
      if (change.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "CHANGE", change))
      }
      mPrinter?.addText("----------------------------------------\n")
      if (totalInclVat.isNotEmpty()) {
        mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL", totalInclVat))
      }
      mPrinter?.addText("----------------------------------------\n")

      // ===== FOOTER =====
      mPrinter?.addFeedLine(1)
      mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      mPrinter?.addText("THANK YOU FOR VISITING US\n")
      mPrinter?.addFeedLine(1)
      mPrinter?.addText("*** TERMS AND CONDITIONS ***\n")
      mPrinter?.addFeedLine(1)
      // Clean TNC from HTML tags (optional, simple replacement)
      if (tnc.isNotEmpty()) {
        val tncPlain = android.text.Html.fromHtml(tnc, android.text.Html.FROM_HTML_MODE_LEGACY).toString()
        mPrinter?.addText("$tncPlain\n")
      }
      if (website.isNotEmpty()) mPrinter?.addText("$website\n")
      if (address.isEmpty()) mPrinter?.addText("At The Dubai Mall\n")
      mPrinter?.addText("800 382246255\n")

      // ===== BARCODE if any =====
      // if (barcodeValue.isNotEmpty()) {
      //   try {
      //     mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
      //     mPrinter?.addBarcode(
      //       barcodeValue,
      //       Printer.BARCODE_CODE128,
      //       Printer.HRI_BELOW,
      //       Printer.FONT_A,
      //       60, // height
      //       2   // width
      //     )
      //   } catch (e: Exception) {
      //     Log.e("EpsonUSB", "Barcode print failed: ${e.message}")
      //   }
      //   mPrinter?.addFeedLine(1)
      // }

      // ===== FINALIZE =====
      mPrinter?.addCut(Printer.CUT_FEED)
      mPrinter?.sendData(Printer.PARAM_DEFAULT)
      Log.d("EpsonUSB", "Void receipt printed successfully")

    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Failed to print receipt: ${e.errorStatus}")
      throw e
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Failed to print receipt: ${e.message}")
      throw e
    }
  }

// private fun printVoidTransaction(ticketData: String) {
//   try {
//       mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
//       mPrinter?.addText("***** VOID RECEIPT *****\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("TAX INVOICE\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("TRNNO\n")
//       mPrinter?.addText("PO BOX NO 9440\n")
//       mPrinter?.addText("DUBAI U.A.E\n")
//       mPrinter?.addFeedLine(1)

//       mPrinter?.addTextAlign(Printer.ALIGN_LEFT)
//       mPrinter?.addText("Sale No: 714358449\n")
//       mPrinter?.addText("Date: 28-08-2023   Time: 16:08\n")
//       mPrinter?.addText("POS No: 714\n")
//       mPrinter?.addText("User ID: Fahad Jan Khan4\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("----------------------------------------\n")
//       mPrinter?.addText("QTY    ITEM DESCRIPTION           AMOUNT\n")
//       mPrinter?.addText("----------------------------------------\n")

//       // Items Table
//       mPrinter?.addTextAlign(Printer.ALIGN_LEFT)
//       mPrinter?.addText("1      VIP PASS Pack               380.00\n")
//       mPrinter?.addText("----------------------------------------\n")

//       // Totals
//       mPrinter?.addText(String.format("%-25s %10s\n", "DISCOUNT", "0.00"))
//       mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL EXCL VAT", "380.00"))
//       mPrinter?.addText(String.format("%-25s %10s\n", "VAT 5%", "19.00"))
//       mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL INCL VAT", "399.00"))
//       mPrinter?.addText(String.format("%-25s %10s\n", "CHANGE", "0.00"))
//       mPrinter?.addText("----------------------------------------\n")
//       mPrinter?.addText(String.format("%-25s %10s\n", "TOTAL", "399.00"))
//       mPrinter?.addText("----------------------------------------\n")

//       // Footer
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addTextAlign(Printer.ALIGN_CENTER)
//       mPrinter?.addText("THANK YOU FOR VISITING US\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("*** TERMS AND CONDITIONS ***\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("1. Tickets can be used once only and may not be replaced, refunded or exchanged.\n")
//       mPrinter?.addText("2. Please find the complete terms on our website.\n")
//       mPrinter?.addFeedLine(1)
//       mPrinter?.addText("At The Dubai Mall\n")
//       mPrinter?.addText("800 382246255\n")

//       // Finalize
//       mPrinter?.addCut(Printer.CUT_FEED)
//       mPrinter?.sendData(Printer.PARAM_DEFAULT)
//       Log.d("EpsonUSB", "Void receipt printed successfully")

//   } catch (e: Epos2Exception) {
//       Log.e("EpsonUSB", "Failed to print receipt: ${e.errorStatus}")
//   }
// }




  override fun onPause() {
    super.onPause()
    try {
      mPrinter?.disconnect()
      isPrinterConnected = false
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Error disconnecting printer: ${e.errorStatus}")
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    try {
      mPrinter?.disconnect()
      isPrinterConnected = false
    } catch (e: Epos2Exception) {
      Log.e("EpsonUSB", "Error disconnecting printer: ${e.errorStatus}")
    }
    try {
      unregisterReceiver(usbReceiver)
    } catch (e: Exception) {
      Log.e("EpsonUSB", "Error unregistering receiver: ${e.message}")
    }
  }
}
