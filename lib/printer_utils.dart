import 'dart:async';
import 'dart:developer';
import 'dart:io';
// Removed: ui, typed_data (not needed here)
import 'package:epson_epos/epson_epos.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:barcode/barcode.dart' as barcode_lib;
import 'package:image/image.dart' as img;
// Removed: flutter_html and screenshot (HTML rendering handled in main.dart)

class PrinterUtils {
  // Method channel for USB permissions
  static const platform = MethodChannel('com.emaar.pos.usb_permissions');
   

  /// Request USB permissions for Epson TM-T88VI thermal printer
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestUSBPermissions() async {
    if (!Platform.isAndroid) return true;
    
    try {
      log("Requesting USB permissions for Epson TM-T88VI...");
      
      // Use native Android USB permission handling
      final bool hasPermission = await platform.invokeMethod('requestUSBPermissions');
      
      if (hasPermission) {
        log("USB permission granted");
      } else {
        log("USB permission denied or no Epson devices found");
      }
      
      return hasPermission;
      
    } catch (e) {
      log("Error requesting USB permissions: ${e.toString()}");
      return false;
    }
  }

  /// Check USB permission status
  /// Returns true if permission is granted, false otherwise
  static Future<bool> checkUSBPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      log("Checking USB permissions for Epson devices");
      
      // Use native Android USB permission checking
      final bool hasPermission = await platform.invokeMethod('checkUSBPermissions');
      
      log("USB permission check result: $hasPermission");
      return hasPermission;
      
    } catch (e) {
      log("Error checking USB permission: ${e.toString()}");
      return false;
    }
  }

  /// Discover USB printers
  /// Returns list of discovered USB printers or empty list if none found
  static Future<List<EpsonPrinterModel>> discoverUSBPrinters() async {
    try {
      log("Starting USB discovery...");
      
      // Check USB permission first
      bool hasUSBPermission = await checkUSBPermission();
      if (!hasUSBPermission) {
        log("USB permission not granted, requesting permission...");
        hasUSBPermission = await requestUSBPermissions();
        
        if (!hasUSBPermission) {
          log("USB permission required for USB printer discovery");
          return [];
        }
      }
      
      List<EpsonPrinterModel>? data = await EpsonEPOS.onDiscovery(type: EpsonEPOSPortType.USB);
      if (data != null && data.isNotEmpty) {
        log("Found ${data.length} USB printers");
        for (var element in data) {
          log("USB Printer: ${element.toJson()}");
        }
        return data;
      } else {
        log("No USB printers found");
        return [];
      }
    } catch (e) {
      log("USB Discovery Error: ${e.toString()}");
      return [];
    }
  }

  /// Discover TCP printers
  /// Returns list of discovered TCP printers or empty list if none found
  static Future<List<EpsonPrinterModel>> discoverTCPPrinters() async {
    try {
      log("Starting TCP discovery...");
      
      List<EpsonPrinterModel>? data = await EpsonEPOS.onDiscovery(type: EpsonEPOSPortType.TCP);
      if (data != null && data.isNotEmpty) {
        log("Found ${data.length} TCP printers");
        for (var element in data) {
          log("TCP Printer: ${element.toJson()}");
        }
        return data;
      } else {
        log("No TCP printers found");
        return [];
      }
    } catch (e) {
      log("TCP Discovery Error: ${e.toString()}");
      return [];
    }
  }

  /// Discover all printers (USB + TCP)
  /// Returns combined list of all discovered printers
  static Future<List<EpsonPrinterModel>> discoverAllPrinters() async {
    List<EpsonPrinterModel> allPrinters = [];
    
    // Discover USB printers
    List<EpsonPrinterModel> usbPrinters = await discoverUSBPrinters();
    allPrinters.addAll(usbPrinters);
    
    // Discover TCP printers
    List<EpsonPrinterModel> tcpPrinters = await discoverTCPPrinters();
    allPrinters.addAll(tcpPrinters);
    
    log("Total printers discovered: ${allPrinters.length}");
    return allPrinters;
  }

  /// Print to selected printer with retry logic
  /// Returns true if print is successful, false otherwise
  static Future<bool> printToPrinter(
    EpsonPrinterModel printer, 
    List<Map<String, dynamic>> commands, {
    int maxRetries = 3,
    Map<String, bool?>? connectionStates,
    Map<String, int>? retryCounts,
  }) async {
    String printerKey = "${printer.model}_${printer.ipAddress}";
    
    log("=== PRINT TO PRINTER START ===");
    log("Printer: ${printer.model} at ${printer.ipAddress}");
    log("Commands count: ${commands.length}");
    log("Max retries: $maxRetries");
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        log("Attempting to print to ${printer.model} (attempt $attempt/$maxRetries)");
        
        // Check if we know the printer is disconnected
        if (connectionStates != null && connectionStates[printerKey] == false && attempt == 1) {
          log("Printer is known to be disconnected, waiting longer before retry");
          await Future.delayed(Duration(seconds: 5));
        }
        
        // Add delay between attempts to avoid plugin conflicts
        if (attempt > 1) {
          log("Waiting ${5 * attempt} seconds before retry attempt $attempt");
          await Future.delayed(Duration(seconds: 5 * attempt));
        }
        
        // Try to print directly without pre-validation to avoid plugin disconnect issues
        log("Calling EpsonEPOS.onPrint with ${commands.length} commands");
        await EpsonEPOS.onPrint(printer, commands);
        log("Print completed successfully");
        
        // Update connection state on success
        if (connectionStates != null) {
          connectionStates[printerKey] = true;
        }
        if (retryCounts != null) {
          retryCounts[printerKey] = 0;
        }
        log("=== PRINT TO PRINTER SUCCESS ===");
        return true;
        
      } catch (e) {
        log("Print attempt $attempt failed: ${e.toString()}");
        log("Error type: ${e.runtimeType}");
        log("Stack trace: ${StackTrace.current}");
        
        if (connectionStates != null) {
          connectionStates[printerKey] = false;
        }
        if (retryCounts != null) {
          retryCounts[printerKey] = attempt;
        }
        
        // Check if this is an Epos2Exception (connection issue)
        if (e.toString().contains('Epos2Exception') || e.toString().contains('disconnect')) {
          log("Detected Epos2Exception, marking printer as disconnected");
          
          // For Epos2Exception, wait longer and try alternative approach
          if (attempt < maxRetries) {
            log("Waiting ${8 * attempt} seconds before retry due to Epos2Exception");
            await Future.delayed(Duration(seconds: 8 * attempt));
          }
        } else {
          // For other errors, wait shorter time
          if (attempt < maxRetries) {
            log("Waiting 2 seconds before retry for other error");
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }
    }
    
    log("Print failed after $maxRetries attempts");
    log("=== PRINT TO PRINTER FAILED ===");
    return false;
  }

  /// Alternative print method that tries to work around plugin issues
  /// Returns true if print is successful, false otherwise
  static Future<bool> alternativePrintToPrinter(
    EpsonPrinterModel printer, 
    List<Map<String, dynamic>> commands,
    Map<String, bool?>? connectionStates,
    Map<String, int>? retryCounts,
  ) async {
    String printerKey = "${printer.model}_${printer.ipAddress}";
    
    try {
      log("Attempting alternative print method for ${printer.model}");
      
      // Wait a bit to ensure any previous connection attempts are cleared
      await Future.delayed(Duration(seconds: 3));
      
      // Try to print without any pre-validation
      await EpsonEPOS.onPrint(printer, commands);
      log("Alternative print completed successfully");
      
      if (connectionStates != null) {
        connectionStates[printerKey] = true;
      }
      if (retryCounts != null) {
        retryCounts[printerKey] = 0;
      }
      return true;
      
    } catch (e) {
      log("Alternative print failed: ${e.toString()}");
      if (connectionStates != null) {
        connectionStates[printerKey] = false;
      }
      return false;
    }
  }

  /// Set printer settings
  /// Returns true if settings are applied successfully, false otherwise
  static Future<bool> setPrinterSettings(EpsonPrinterModel printer, {int paperWidth = 80}) async {
    try {
      log("Setting printer settings for: ${printer.model}");
      await EpsonEPOS.setPrinterSetting(printer, paperWidth: paperWidth);
      log("Printer settings updated successfully");
      return true;
    } catch (e) {
      log("Printer settings error: ${e.toString()}");
      return false;
    }
  }

  /// Create test print commands
  /// Returns list of print commands for testing
  static List<Map<String, dynamic>> createTestPrintCommands(EpsonPrinterModel printer) {
    EpsonEPOSCommand command = EpsonEPOSCommand();
    List<Map<String, dynamic>> commands = [];
    
    commands.add(command.addTextAlign(EpsonEPOSTextAlign.CENTER));
    commands.add(command.addFeedLine(2));
    commands.add(command.append('AUTO-PRINT TEST\n'));
    commands.add(command.append('Printer: ${printer.model}\n'));
    commands.add(command.append('Time: ${DateTime.now().toString()}\n'));
    commands.add(command.addFeedLine(2));
    commands.add(command.addCut(EpsonEPOSCut.CUT_FEED));
    
    return commands;
  }

  /// Builds Epson commands from JSON data received from web
  /// Returns a List<Map<String, dynamic>> ready to pass to Epson print APIs.
  static Future<Uint8List?> generateBarcodePngBytes(String data,
      {int width = 300, int height = 80}) async {
    try {
      final bc = barcode_lib.Barcode.code128();
      final svg = bc.toSvg(data, width: width.toDouble(), height: height.toDouble());

      // For now, create a simple barcode pattern as PNG bytes
      final pngBytes = await _createSimpleBarcodePng(data, width, height);
      return pngBytes;
    } catch (e) {
      print('Error generating barcode: $e');
      return null;
    }
  }

  static Future<List<int>> _customEscPos(String barcode) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];
      final List<String> barData = barcode.split('');
      // bytes += generator.barcode(Barcode.upcA(barData));
      // bytes += generator.feed(2);

      Uint8List barcodeBytes = Uint8List.fromList(barcode.codeUnits);

      bytes += generator.barcode(
        Barcode.code128(barcodeBytes)
      );

    bytes += generator.feed(2);

      return bytes;
    } catch (e) {
      print('Error in _customEscPos: $e');
      return [];
    }
  }


   static Future<List<Map<String, dynamic>>> buildPrintRecipt(Map<String, dynamic> receiptData) async {

    
    final EpsonEPOSCommand cmd = EpsonEPOSCommand();
    final List<Map<String, dynamic>> commands = [];

    // Extract data from JSON
    final header = receiptData['header'] as Map<String, dynamic>? ?? {};
    final items = receiptData['items'] as List<dynamic>? ?? [];
    final totals = receiptData['totals'] as Map<String, dynamic>? ?? {};
    final footer = receiptData['footer'] as Map<String, dynamic>? ?? {};

  
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (header['company'] != null) commands.add(cmd.append('${header['company']}\n'));
    if (header['location'] != null) commands.add(cmd.append('${header['location']}\n'));
    if (header['trnNo'] != null) commands.add(cmd.append('TRNNO ${header['trnNo']}\n'));
    if (header['orderNo'] != null) commands.add(cmd.append('Order No: ${header['orderNo']}\n'));
    if (header['venue'] != null) commands.add(cmd.append('${header['venue']}\n'));
    commands.add(cmd.addFeedLine(1));

    // TAX INVOICE
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (header['taxInvoiceText'] != null) commands.add(cmd.append('${header['taxInvoiceText']}\n'));
    commands.add(cmd.addFeedLine(1));

    // ========== SALE DETAILS ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (header['saleNo'] != null) commands.add(cmd.append('Sale No: ${header['saleNo']}\n'));
    if (header['date'] != null && header['time'] != null) {
      commands.add(cmd.append('Date: ${header['date']}     Time: ${header['time']}\n'));
    }
    if (header['posNo'] != null) commands.add(cmd.append('POS No: ${header['posNo']}\n'));
    if (header['userId'] != null) commands.add(cmd.append('User ID: ${header['userId']}\n'));
    commands.add(cmd.append('------------------------------------------\n'));

    // ========== TABLE HEADER ==========
    commands.add(cmd.append('QTY   ITEM DESCRIPTION               AMOUNT\n'));
    commands.add(cmd.append('-----------------------------------------------\n'));

    // ========== ITEMS ==========
    for (var item in items) {
      final description = (item['description'] ?? '').toString();
      final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
      final String qty = (item['qty'] ?? '1').toString();

      // Word wrap the description
      int lineWidth = 39;
      int descColStart = 6;
      int priceColWidth = 12;
      int descMaxWidth = lineWidth - descColStart - priceColWidth;

      List<String> descLines = [];
      String descRemainder = description;
      while (descRemainder.isNotEmpty) {
        if (descRemainder.length <= descMaxWidth) {
          descLines.add(descRemainder);
          break;
        }
        int breakIndex = descRemainder.lastIndexOf(' ', descMaxWidth);
        if (breakIndex == -1) breakIndex = descMaxWidth;
        descLines.add(descRemainder.substring(0, breakIndex).trimRight());
        descRemainder = descRemainder.substring(breakIndex).trimLeft();
      }

      for (int i = 0; i < descLines.length; i++) {
        if (i == 0) {
          String desc = descLines[0];
          String qtyCol = qty.padRight(5);
          String amtCol = price.toStringAsFixed(2).padLeft(priceColWidth);
          commands.add(cmd.append('$qtyCol$desc'.padRight(lineWidth - priceColWidth) + amtCol + '\n'));
        } else {
          String desc = descLines[i];
          commands.add(cmd.append('      $desc\n'));
        }
      }
    }
    commands.add(cmd.append('-----------------------------------------------\n'));

    // ========== TOTALS ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (totals['discount'] != null) {
      final discount = (totals['discount'] is num) ? (totals['discount'] as num).toDouble() : 0.0;
      commands.add(cmd.append("DISCOUNT".padRight(36) + discount.toStringAsFixed(2) + '\n'));
    }
    if (totals['totalExclVat'] != null) {
      final totalExclVat = (totals['totalExclVat'] is num) ? (totals['totalExclVat'] as num).toDouble() : 0.0;
      commands.add(cmd.append("TOTAL EXCL VAT".padRight(36) + totalExclVat.toStringAsFixed(2) + '\n'));
    }
    if (totals['vatPercent'] != null && totals['vatAmount'] != null) {
      final vatAmount = (totals['vatAmount'] is num) ? (totals['vatAmount'] as num).toDouble() : 0.0;
      commands.add(cmd.append("VAT ${totals['vatPercent']}%".padRight(36) + vatAmount.toStringAsFixed(2) + '\n'));
    }
    if (totals['totalInclVat'] != null) {
      final totalInclVat = (totals['totalInclVat'] is num) ? (totals['totalInclVat'] as num).toDouble() : 0.0;
      commands.add(cmd.append("TOTAL INCL VAT".padRight(36) + totalInclVat.toStringAsFixed(2) + '\n'));
    }
    if (totals['change'] != null) {
      final change = (totals['change'] is num) ? (totals['change'] as num).toDouble() : 0.0;
      commands.add(cmd.append("CHANGE".padRight(36) + change.toStringAsFixed(2) + '\n'));
    }
    commands.add(cmd.append('------------------------------------------\n'));

    // TOTAL
    if (totals['grandTotal'] != null) {
      final grandTotal = (totals['grandTotal'] is num) ? (totals['grandTotal'] as num).toDouble() : 0.0;
      commands.add(cmd.append('TOTAL: ${grandTotal.toStringAsFixed(2)}\n'));
    }
    commands.add(cmd.addFeedLine(1));

    // ========== FOOTER ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (footer['thankYou'] != null) commands.add(cmd.append('${footer['thankYou']}\n'));
    commands.add(cmd.addFeedLine(1));
    if (footer['termsTitle'] != null) commands.add(cmd.append('${footer['termsTitle']}\n'));
    commands.add(cmd.addFeedLine(1));
    
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (footer['termsLines'] != null) {
      for (var line in footer['termsLines'] as List<dynamic>) {
        commands.add(cmd.append('$line\n'));
      }
    }

      commands.add(cmd.rawData(Uint8List.fromList(await _customEscPos("123456789012"))));


    // ========== CUT PAPER ==========
    commands.add(cmd.addFeedLine(2));
    commands.add(cmd.addCut(EpsonEPOSCut.CUT_FEED));

    return commands;
  }


  static Future<List<Map<String, dynamic>>> buildPrintVoid(Map<String, dynamic> receiptData) async {

    
    final EpsonEPOSCommand cmd = EpsonEPOSCommand();
    final List<Map<String, dynamic>> commands = [];

    // Extract data from JSON
    final header = receiptData['header'] as Map<String, dynamic>? ?? {};
    final items = receiptData['items'] as List<dynamic>? ?? [];
    final totals = receiptData['totals'] as Map<String, dynamic>? ?? {};
    final footer = receiptData['footer'] as Map<String, dynamic>? ?? {};

  
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (header['company'] != null) commands.add(cmd.append('${header['company']}\n'));
    if (header['location'] != null) commands.add(cmd.append('${header['location']}\n'));
    if (header['trnNo'] != null) commands.add(cmd.append('TRNNO ${header['trnNo']}\n'));
    if (header['orderNo'] != null) commands.add(cmd.append('Order No: ${header['orderNo']}\n'));
    if (header['venue'] != null) commands.add(cmd.append('${header['venue']}\n'));
    commands.add(cmd.addFeedLine(1));

    // TAX INVOICE
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (header['taxInvoiceText'] != null) commands.add(cmd.append('${header['taxInvoiceText']}\n'));
    commands.add(cmd.addFeedLine(1));

    // ========== SALE DETAILS ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (header['saleNo'] != null) commands.add(cmd.append('Sale No: ${header['saleNo']}\n'));
    if (header['date'] != null && header['time'] != null) {
      commands.add(cmd.append('Date: ${header['date']}     Time: ${header['time']}\n'));
    }
    if (header['posNo'] != null) commands.add(cmd.append('POS No: ${header['posNo']}\n'));
    if (header['userId'] != null) commands.add(cmd.append('User ID: ${header['userId']}\n'));
    commands.add(cmd.append('------------------------------------------\n'));

    // ========== TABLE HEADER ==========
    commands.add(cmd.append('QTY   ITEM DESCRIPTION               AMOUNT\n'));
    commands.add(cmd.append('-----------------------------------------------\n'));

    // ========== ITEMS ==========
    for (var item in items) {
      final description = (item['description'] ?? '').toString();
      final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
      final String qty = (item['qty'] ?? '1').toString();

      // Word wrap the description
      int lineWidth = 39;
      int descColStart = 6;
      int priceColWidth = 12;
      int descMaxWidth = lineWidth - descColStart - priceColWidth;

      List<String> descLines = [];
      String descRemainder = description;
      while (descRemainder.isNotEmpty) {
        if (descRemainder.length <= descMaxWidth) {
          descLines.add(descRemainder);
          break;
        }
        int breakIndex = descRemainder.lastIndexOf(' ', descMaxWidth);
        if (breakIndex == -1) breakIndex = descMaxWidth;
        descLines.add(descRemainder.substring(0, breakIndex).trimRight());
        descRemainder = descRemainder.substring(breakIndex).trimLeft();
      }

      for (int i = 0; i < descLines.length; i++) {
        if (i == 0) {
          String desc = descLines[0];
          String qtyCol = qty.padRight(5);
          String amtCol = price.toStringAsFixed(2).padLeft(priceColWidth);
          commands.add(cmd.append('$qtyCol$desc'.padRight(lineWidth - priceColWidth) + amtCol + '\n'));
        } else {
          String desc = descLines[i];
          commands.add(cmd.append('      $desc\n'));
        }
      }
    }
    commands.add(cmd.append('-----------------------------------------------\n'));

    // ========== TOTALS ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (totals['discount'] != null) {
      final discount = (totals['discount'] is num) ? (totals['discount'] as num).toDouble() : 0.0;
      commands.add(cmd.append("DISCOUNT".padRight(36) + discount.toStringAsFixed(2) + '\n'));
    }
    if (totals['totalExclVat'] != null) {
      final totalExclVat = (totals['totalExclVat'] is num) ? (totals['totalExclVat'] as num).toDouble() : 0.0;
      commands.add(cmd.append("TOTAL EXCL VAT".padRight(36) + totalExclVat.toStringAsFixed(2) + '\n'));
    }
    if (totals['vatPercent'] != null && totals['vatAmount'] != null) {
      final vatAmount = (totals['vatAmount'] is num) ? (totals['vatAmount'] as num).toDouble() : 0.0;
      commands.add(cmd.append("VAT ${totals['vatPercent']}%".padRight(36) + vatAmount.toStringAsFixed(2) + '\n'));
    }
    if (totals['totalInclVat'] != null) {
      final totalInclVat = (totals['totalInclVat'] is num) ? (totals['totalInclVat'] as num).toDouble() : 0.0;
      commands.add(cmd.append("TOTAL INCL VAT".padRight(36) + totalInclVat.toStringAsFixed(2) + '\n'));
    }
    if (totals['change'] != null) {
      final change = (totals['change'] is num) ? (totals['change'] as num).toDouble() : 0.0;
      commands.add(cmd.append("CHANGE".padRight(36) + change.toStringAsFixed(2) + '\n'));
    }
    commands.add(cmd.append('------------------------------------------\n'));

    // TOTAL
    if (totals['grandTotal'] != null) {
      final grandTotal = (totals['grandTotal'] is num) ? (totals['grandTotal'] as num).toDouble() : 0.0;
      commands.add(cmd.append('TOTAL: ${grandTotal.toStringAsFixed(2)}\n'));
    }
    commands.add(cmd.addFeedLine(1));

    // ========== FOOTER ==========
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    if (footer['thankYou'] != null) commands.add(cmd.append('${footer['thankYou']}\n'));
    commands.add(cmd.addFeedLine(1));
    if (footer['termsTitle'] != null) commands.add(cmd.append('${footer['termsTitle']}\n'));
    commands.add(cmd.addFeedLine(1));
    
    commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    if (footer['termsLines'] != null) {
      for (var line in footer['termsLines'] as List<dynamic>) {
        commands.add(cmd.append('$line\n'));
      }
    }

      commands.add(cmd.rawData(Uint8List.fromList(await _customEscPos("123456789012"))));


    // ========== CUT PAPER ==========
    commands.add(cmd.addFeedLine(2));
    commands.add(cmd.addCut(EpsonEPOSCut.CUT_FEED));

    return commands;
  }

  static Future<List<Map<String, dynamic>>> buildPrintticket(Map<String, dynamic> receiptData) async {

    print("buildPrintticket: $receiptData");
    final EpsonEPOSCommand cmd = EpsonEPOSCommand();
    final List<Map<String, dynamic>> commands = [];

    // for (var item in receiptData['ticketData']) {
    //     // Header (centered)
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    //     commands.add(cmd.append('EMAAR ENTERTAINMENT LLC\n'));
    //     commands.add(cmd.append('At The Top\n'));
    //     commands.add(cmd.append('TRNNO 100067521300003\n'));
    //     commands.add(cmd.append('PO BOX NO 9440\n'));
    //     commands.add(cmd.append('DUBAI U.A.E\n'));
    //     commands.add(cmd.addFeedLine(1));

    //     // Spacer
    //     commands.add(cmd.addFeedLine(1));

    //     // Dashed HR (simulate dashed by dashes)
    //     commands.add(cmd.append('------------------------------------------\n'));
    //     // Centered instruction text
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    //     commands.add(cmd.append('Please go to the counter get the ticket.\n'));
    //     // Dashed HR
    //     commands.add(cmd.append('------------------------------------------\n'));

    //     // Spacer and bold centered ticket notice
    //     commands.add(cmd.addFeedLine(1));
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    //     commands.add(cmd.append('*** THIS IS YOUR  TICKET ***\n'));
    //     commands.add(cmd.addFeedLine(1));

    //     // Event Info (left-aligned)
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    //     commands.add(cmd.append('Event Name: At The Top\n'));
    //     commands.add(cmd.append('Event Date: 2025-10-05\n'));
    //     commands.add(cmd.append('Event Time: 8:30 AM\n'));
    //     commands.add(cmd.append('Item Name: ATT + RT  WEB CHILD (1), ATT + RT  WEB ADULT (1), WEB CHILD (1), WEB ADULT (1)\n'));

    //     // Spacer for the barcode
    //     commands.add(cmd.addFeedLine(1));
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
    //     // Render barcode using custom ESC/POS routine (simulate unique ticket ID, here fixed)
    //     for(var bitem in item['barcodeValue']) {
    //     final ticketBarcode = bitem.toString();
    //      commands.add(cmd.rawData(Uint8List.fromList(await _customEscPos(ticketBarcode))));
    //       // Show code under barcode
    //       commands.add(cmd.append('$ticketBarcode\n'));
    //       commands.add(cmd.addFeedLine(1));    
    //     }

    //     // Solid horizontal rule
    //     commands.add(cmd.append('==========================================\n'));
    //     // Trans Date/Time and Transaction/Node/User details (left-aligned)
    //     commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.LEFT));
    //     commands.add(cmd.append('Trans Date/Time: 2025-10-05 17:26:40.926Z\n'));
    //     commands.add(cmd.append('Trans: 153   Node: 189   User ID: 2\n'));

    //     // Feed/cut at end
    //     commands.add(cmd.addFeedLine(2));
    //     commands.add(cmd.addCut(EpsonEPOSCut.CUT_FEED));
    // }
      commands.add(cmd.rawData(Uint8List.fromList(await _customEscPos("3921893"))));
    commands.add(cmd.addFeedLine(2));
        commands.add(cmd.addCut(EpsonEPOSCut.CUT_FEED));

    return commands;
  }


  /// Create a simple barcode pattern as PNG bytes optimized for thermal printers
  static Future<Uint8List?> _createSimpleBarcodePng(String value, int width, int height) async {
    try {
      // Create a simple barcode pattern using the image package
      final img.Image image = img.Image(width, height);
      
      // Fill with white background
      img.fill(image, img.getColor(255, 255, 255));
      
      // Create barcode pattern - make it more visible and printer-friendly
      final int barWidth = 3; // Slightly thicker bars
      final int startX = 20;
      int currentX = startX;
      
      // Generate bars based on value hash - create a more realistic barcode pattern
      final int hash = value.hashCode.abs();
      
      // Start with guard bars (thick bars at beginning and end)
      for (int y = 10; y < height - 10; y++) {
        for (int x = currentX; x < currentX + barWidth * 2 && x < width; x++) {
          image.setPixel(x, y, img.getColor(0, 0, 0));
        }
      }
      currentX += barWidth * 2 + 2;
      
      // Add data bars
      for (int i = 0; i < 15 && currentX < width - 30; i++) {
        final bool isBar = (hash >> i) & 1 == 1;
        if (isBar) {
          // Draw black bar
          for (int y = 10; y < height - 10; y++) {
            for (int x = currentX; x < currentX + barWidth && x < width; x++) {
              image.setPixel(x, y, img.getColor(0, 0, 0));
            }
          }
        }
        currentX += barWidth + 1; // Add spacing between bars
      }
      
      // End with guard bars
      for (int y = 10; y < height - 10; y++) {
        for (int x = currentX; x < currentX + barWidth * 2 && x < width; x++) {
          image.setPixel(x, y, img.getColor(0, 0, 0));
        }
      }
      
      // Add value text area (white space for text)
      final int textY = height - 15;
      for (int x = startX; x < currentX + barWidth * 2 && x < width; x++) {
        for (int y = textY; y < height - 5; y++) {
          image.setPixel(x, y, img.getColor(255, 255, 255));
        }
      }
      
      print('Created barcode image: ${width}x${height}, bars: ${currentX - startX}px wide');
      
      // Convert to PNG bytes
      final List<int> pngBytes = img.encodePng(image);
      print('PNG bytes length: ${pngBytes.length}');
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      print('Simple barcode PNG creation error: $e');
      return null;
    }
  }

  /// Complete auto-start sequence
  /// Returns map with results: {'permission': bool, 'printers': List, 'selected': EpsonPrinterModel?}
  static Future<Map<String, dynamic>> autoStartSequence() async {
    log("=== AUTO START SEQUENCE BEGIN ===");
    
    Map<String, dynamic> results = {
      'permission': false,
      'printers': <EpsonPrinterModel>[],
      'selected': null,
    };
    
    try {
      // Step 1: Request USB permissions
      log("Step 1: Requesting USB permissions...");
      bool hasPermission = await requestUSBPermissions();
      results['permission'] = hasPermission;
      
      if (!hasPermission) {
        log("USB permission not granted, continuing with limited functionality");
      }
      
      // Step 2: Discover printers
      log("Step 2: Discovering printers...");
      List<EpsonPrinterModel> printers = await discoverAllPrinters();
      results['printers'] = printers;
      
      // Step 3: Auto-select printer if found
      if (printers.isNotEmpty) {
        EpsonPrinterModel selectedPrinter = printers.first;
        results['selected'] = selectedPrinter;
        log("Auto-selected printer: ${selectedPrinter.model} at ${selectedPrinter.ipAddress}");
      } else {
        log("No printers found during auto-start sequence");
      }
      
    } catch (e) {
      log("Auto-start sequence error: ${e.toString()}");
    }
    
    log("=== AUTO START SEQUENCE END ===");
    return results;
  }
}
