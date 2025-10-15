import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epson_epos/epson_epos.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'printer_utils.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

void main() {
  // Enable Android WebView debugging
  if (Platform.isAndroid) {
    AndroidWebViewController.enableDebugging(true);
  }
  // Hide status/navigation bars for immersive full-screen UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(MaterialApp(
    title: 'POS Emaar',
    debugShowCheckedModeBanner: false,
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  // State management
  String _currentState = 'permission'; // permission, searching, connected, error
  EpsonPrinterModel? _selectedPrinter;
  List<EpsonPrinterModel> _printers = [];
  String _connectionType = 'none'; // none, usb, wifi, both
  
  // WebView controller
  late final WebViewController _webViewController;
  
  // Continuous discovery timer
  Timer? _discoveryTimer;
  
  // Blinking animation controller
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  
  // Permission request flag to avoid multiple calls
  bool _isRequestingPermission = false;
  bool _isDiscoveringPrinters = false;
  bool _showStatusOverlay = false;

  // Toast message settings
  bool _showToastMessages = false;
  int _buttonTapCount = 0;

  // Offstage HTML render key + buffer
  final GlobalKey _htmlRepaintKey = GlobalKey();
  String _pendingHtmlForPrint = '';

  @override
  void initState() {
    super.initState();
    log("App started - Simple UI with printer icon");
    _initializeWebView();
    _initializeBlinkAnimation();
    _startInitialization();
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  void _initializeBlinkAnimation() {
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
    
    // Start blinking animation
    _blinkController.repeat(reverse: true);
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterPrint',
        onMessageReceived: (JavaScriptMessage message) {
          _handlePrintFromWeb(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            log("Page loaded: $url");
            // Inject bridge so pages using inappwebview/react-native APIs relay to FlutterPrint
            _injectWebBridge();
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.100.77:3001/'));
  }

  void _injectWebBridge() {
    const js = r"""
      (function() {
        try {
          // Ensure FlutterPrint channel shim exists check
          var sendToFlutter = function(payload) {
            try {
              if (window.FlutterPrint && typeof window.FlutterPrint.postMessage === 'function') {
                window.FlutterPrint.postMessage(payload);
              } else {
                console.warn('FlutterPrint channel not available');
              }
            } catch (e) { console.error('Error posting to FlutterPrint', e); }
          };

          // Shim for flutter_inappwebview.callHandler(name, jsonString)
          if (!window.flutter_inappwebview) {
            window.flutter_inappwebview = {
              callHandler: function(name, data) {
                try {
                  var message = data;
                  if (typeof data !== 'string') { message = JSON.stringify(data); }
                  // Forward only known handlers; others still forward raw
                  sendToFlutter(message);
                } catch (e) { console.error('callHandler error', e); }
              }
            };
          }

          // Shim for ReactNativeWebView.postMessage
          if (!window.ReactNativeWebView) {
            window.ReactNativeWebView = {
              postMessage: function(data) {
                try {
                  var message = data;
                  if (typeof data !== 'string') { message = JSON.stringify(data); }
                  sendToFlutter(message);
                } catch (e) { console.error('postMessage error', e); }
              }
            };
          }

          // Provide convenience global functions if a page calls them
          if (!window.printReceipt) {
            window.printReceipt = function(data) {
              try { sendToFlutter(typeof data === 'string' ? data : JSON.stringify(data)); } catch (e) {}
            };
          }
          if (!window.voidTransaction) {
            window.voidTransaction = function(data) {
              try { sendToFlutter(typeof data === 'string' ? data : JSON.stringify({action:'voidTransaction', data:data})); } catch (e) {}
            };
          }
          if (!window.printTicket) {
            window.printTicket = function(data) {
              try { sendToFlutter(typeof data === 'string' ? data : JSON.stringify({action:'printTicket', data:data})); } catch (e) {}
            };
          }
          if (!window.printHtml) {
            window.printHtml = function(htmlContent) {
              try { 
                // Send HTML content directly to Flutter for rendering and printing
                sendToFlutter(htmlContent); 
              } catch (e) { console.error('printHtml error', e); }
            };
          }
          console.log('Flutter webview bridge injected');
        } catch (e) {
          console.error('Failed to inject Flutter bridge', e);
        }
      })();
    """;
    _webViewController.runJavaScript(js);
  }

  Future<void> _startInitialization() async {
    await _requestPermission();
     await _discoverPrinters();
  }

  // State management methods using PrinterUtils
  Future<void> _requestPermission() async {
    if (_isRequestingPermission) {
      log("Permission request already in progress, skipping...");
      return;
    }
    
    // _isRequestingPermission = true;
    try {
      log("Requesting USB permissions...");
      bool hasPermission = await PrinterUtils.requestUSBPermissions();
      
      if (hasPermission) {
        setState(() {
          _currentState = 'searching';
        });
        log("Permission granted, starting automatic printer search...");
        _discoverAllPrinters();
      } else {
        log("Permission denied");
        _showMessage('Printer access not granted. Please allow access to continue.', isError: true);
      }

      // _isRequestingPermission = false;
    } catch (e) {
      log("Error requesting permission: $e");
      _showMessage('Unable to request printer access. Please try again.', isError: true);
    } finally {
      // _isRequestingPermission = false;
    }
  }

  Future<void> _discoverAllPrinters() async {
    try {
      log("Starting simultaneous USB and network printer discovery...");
      // Search for both USB and network printers at the same time
      final usbFuture = PrinterUtils.discoverUSBPrinters();
      final networkFuture = PrinterUtils.discoverTCPPrinters();

      final usbPrinters = await usbFuture;
      final networkPrinters = await networkFuture;

      final allPrinters = [...usbPrinters, ...networkPrinters];

      if (allPrinters.isNotEmpty) {
        log("Found ${allPrinters.length} printers total (${usbPrinters.length} USB, ${networkPrinters.length} network)");
        await _autoSelectBestPrinter(allPrinters);
      } else {
        log("No printers found, will retry in 3 seconds...");
        // Wait a bit and try again
        await Future.delayed(const Duration(seconds: 3));
        _discoverAllPrinters();
      }
    } catch (e) {
      log("Error discovering printers: $e");
      // Try again after error
      await Future.delayed(const Duration(seconds: 3));
      _discoverAllPrinters();
    }
  }

  Future<void> _discoverPrinters() async {
    try {
      log("Discovering printers...");
      List<EpsonPrinterModel> allPrinters = await PrinterUtils.discoverAllPrinters();
      
      if (allPrinters.isNotEmpty) {
        setState(() {
          _printers = allPrinters;
          _currentState = 'connected';
        });
       
        await _autoSelectBestPrinter(allPrinters);
      } else {
     
        _startContinuousDiscovery();
      }
    } catch (e) {
      log("Error discovering printers: $e");
      _startContinuousDiscovery();
    }
  }

  void _startContinuousDiscovery() {
    log("Starting continuous printer discovery...");
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_currentState == 'connected') {
        timer.cancel();
        return;
      }

      if (_currentState == 'permission') {
        // Only request permission if not already requesting
        if (!_isRequestingPermission) {
          _isRequestingPermission = true; 
          log("Continuous discovery: Requesting permission...");
          await _requestPermission();
          _isRequestingPermission = false;
        } else {
          log("Continuous discovery: Permission request already in progress, skipping... isDiscoveringPrinters: $_isRequestingPermission");
        }
        return;
      }

      if (_currentState == 'searching') {
        // Continue searching if no printer found yet
        if (!_isDiscoveringPrinters) {
          _isDiscoveringPrinters = true;
          await _discoverAllPrinters();
          _isDiscoveringPrinters = false;
        }
        return;
      }
      
      try {
        log("Continuous discovery: Scanning for printers...");
        List<EpsonPrinterModel> allPrinters = await PrinterUtils.discoverAllPrinters();
        
        if (allPrinters.isNotEmpty) {
          setState(() {
            _printers = allPrinters;
            _currentState = 'connected';
          });
          await _autoSelectBestPrinter(allPrinters);
          timer.cancel();
        } else {
        }
      } catch (e) {
      }
    });
  }

  Future<void> _autoSelectBestPrinter(List<EpsonPrinterModel> allPrinters) async {
    if (allPrinters.isNotEmpty) {
      // Prioritize network printers first, then USB
      EpsonPrinterModel? bestPrinter;
      String detectedConnectionType = 'none';

      // Look for network printers first
      for (var printer in allPrinters) {
        if (printer.ipAddress != null && printer.ipAddress!.isNotEmpty && printer.ipAddress != 'USB') {
          bestPrinter = printer;
          detectedConnectionType = 'wifi';
          break;
        }
      }

      // If no network printer found, use first USB printer
      if (bestPrinter == null) {
        bestPrinter = allPrinters.first;
        detectedConnectionType = 'usb';
      }

      setState(() {
        _selectedPrinter = bestPrinter;
        _printers = allPrinters;
        _connectionType = detectedConnectionType;
        _currentState = 'connected';
      });

      // Stop blinking animation when printer is found
      _blinkController.stop();

      log("Auto-selected best printer: ${bestPrinter!.model} via $detectedConnectionType");
      _showMessage('✓ Printer connected via ${_connectionType.toUpperCase()}');
    }
  }

  Future<void> _selectFirstPrinter() async {
    if (_printers.isNotEmpty) {
      setState(() {
        _selectedPrinter = _printers.first;
        _currentState = 'selected_first_printer';
      });

      // Stop blinking animation when printer is found
      _blinkController.stop();

      _showMessage('✓ Printer connected via ${_connectionType.toUpperCase()}');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    // Only show toast messages if the setting is enabled
    if (!_showToastMessages) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _handleConnectionButtonTap() {
    _buttonTapCount++;

    if (_buttonTapCount >= 5) {
      _buttonTapCount = 0; // Reset counter
      _showToastSettingsDialog();
    }
  }

  void _resetTapCounter() {
    _buttonTapCount = 0;
  }

  void _showToastSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Toast Message Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Show toast messages when printing and connecting?'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Toast Messages:'),
                  const Spacer(),
                  Switch(
                    value: _showToastMessages,
                    onChanged: (bool value) {
                      setState(() {
                        _showToastMessages = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _showToastMessages
                      ? '✅ Toast messages are ENABLED\nMessages will appear when printing and connecting.'
                      : '❌ Toast messages are DISABLED\nNo messages will appear during operations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _showToastMessages ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Reset Tap Counter'),
              onPressed: () {
                _resetTapCounter();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performTestPrint() async {
    if (_selectedPrinter == null) {
      _showMessage('No printer available. Please check connection.', isError: true);
      return;
    }

    try {
      log("Performing test print on ${_selectedPrinter!.model}");
      _showMessage('Sending receipt to printer...');
      
      // Create test print commands using PrinterUtils
      List<Map<String, dynamic>> commands = await PrinterUtils.buildPrintRecipt({});
      
      // Print using PrinterUtils
      bool success = await PrinterUtils.printToPrinter(_selectedPrinter!, commands);
      
      if (success) {
        _showMessage('✓ Receipt printed successfully!');
      } else {
        _showMessage('Unable to print. Please check printer.', isError: true);
      }
    } catch (e) {
      log("Test print failed: $e");
      _showMessage('Print failed. Please check printer connection.', isError: true);
    }
  }

  void _handlePrintFromWeb(String jsonMessage) async {
    try {
      log("Received print request from web: $jsonMessage");

      // Parse the JSON from web
      final Map<String, dynamic> receiptData = jsonDecode(jsonMessage);

      print("jsonMessage111: $jsonMessage");
      print("action: ${receiptData['action']}");

      if (_selectedPrinter == null) {
        _showMessage('No printer connected. Please check connection.', isError: true);
        return;
      }

      if (receiptData['action'] == 'voidTransaction') {
        final commands = await PrinterUtils.buildPrintVoid(receiptData);
        _printReceipt(commands);
      } else if (receiptData['action'] == 'printTicket') {
        print("printTicket: $receiptData");
        final commands = await PrinterUtils.buildPrintticket(receiptData);
        _printReceipt(commands);
      } else {
        // Default to normal receipt print
        final commands = await PrinterUtils.buildPrintRecipt(receiptData);
        _printReceipt(commands);
      }
    } catch (e) {
      log("Error handling print from web: $e");
      _showMessage('Failed to process print request.', isError: true);
    }
  }

  void _handleHtmlPrint(String htmlContent) {
    try {
      log("Received HTML print request");
      
      if (_selectedPrinter == null) {
        _showMessage('No printer connected. Please check connection.', isError: true);
        return;
      }
      
      _showMessage('Rendering HTML content for printing...');
      
      _renderHtmlAndPrint(htmlContent);
      
    } catch (e) {
      log("Error handling HTML print: $e");
      _showMessage('Failed to process HTML print request.', isError: true);
    }
  }

  Future<void> _renderHtmlAndPrint(String htmlContent) async {
    try {
      setState(() { _pendingHtmlForPrint = htmlContent; });
      // allow offstage tree to layout/paint
      await Future.delayed(const Duration(milliseconds: 20));
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = _htmlRepaintKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        _showMessage('Failed to prepare HTML for printing.', isError: true);
        return;
      }
      final RenderRepaintBoundary boundary = renderObject as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showMessage('Failed to capture HTML image.', isError: true);
        return;
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final EpsonEPOSCommand cmd = EpsonEPOSCommand();
      final List<Map<String, dynamic>> commands = [];
      commands.add(cmd.addTextAlign(EpsonEPOSTextAlign.CENTER));
      commands.add(cmd.appendBitmap(
        pngBytes,
        image.width,
        image.height,
        0,
        0,
      ));
      commands.add(cmd.addFeedLine(2));
      commands.add(cmd.addCut(EpsonEPOSCut.CUT_FEED));

      final success = await PrinterUtils.printToPrinter(_selectedPrinter!, commands);
      if (success) {
        _showMessage('✓ HTML content printed successfully!');
      } else {
        _showMessage('Failed to print HTML content. Please check printer.', isError: true);
      }
    } catch (e) {
      log('Render/print HTML error: $e');
      _showMessage('Error printing HTML content.', isError: true);
    } finally {
      if (mounted) setState(() { _pendingHtmlForPrint = ''; });
    }
  }

  Future<void> _printReceipt(List<Map<String, dynamic>> commands) async {
    if (_selectedPrinter == null) {
      _showMessage('No printer available. Please check connection.', isError: true);
      return;
    }

    try {
      log("Printing receipt from web data on ${_selectedPrinter!.model}");
      _showMessage('Sending receipt to printer...');
      
      // Print using PrinterUtils
      bool success = await PrinterUtils.printToPrinter(_selectedPrinter!, commands);
      
      if (success) {
        _showMessage('✓ Receipt printed successfully!');
      } else {
        _showMessage('Unable to print. Please check printer.', isError: true);
      }
    } catch (e) {
      log("Print receipt failed: $e");
      _showMessage('Print failed. Please check printer connection.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          // Offstage HTML renderer for printing
          Offstage(
            offstage: true,
            child: Center(
              child: RepaintBoundary(
                key: _htmlRepaintKey,
                child: Container(
                  width: 384,
                  color: Colors.white,
                  child: Html(
                    data: _pendingHtmlForPrint,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(12),
                        color: Colors.black,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_showStatusOverlay) _buildStatusOverlay(),
          if (_currentState == 'connected') _buildConnectionButtons(),
        ],
      ),
      floatingActionButton: _currentState == 'connected' ? null : AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _currentState == 'connected' ? 1.0 : _blinkAnimation.value,
            child: FloatingActionButton.extended(
              onPressed: _handlePrinterIconTap,
              backgroundColor: _getButtonColor(),
              icon: Icon(
                _getStatusIcon(),
                color: Colors.white,
              ),
              label: Text(
                _getStatusMessage(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusContent(),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () {
                setState(() => _showStatusOverlay = false);
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    switch (_currentState) {
      case 'permission':
        return _buildStatusCard(
          icon: Icons.usb,
          iconColor: Colors.orange,
          title: 'Printer Access Required',
          message: 'We need permission to connect to your printer.\nPlease tap below to grant access.',
          showAction: true,
          actionLabel: 'Grant Permission',
          onAction: () {
            setState(() => _showStatusOverlay = false);
            _requestPermission();
          },
        );
      case 'searching':
        return _buildStatusCard(
          icon: Icons.search,
          iconColor: Colors.blue,
          title: 'Auto-Searching for Printers',
          message: 'Scanning for USB and WiFi printers automatically...',
          showProgress: true,
        );
      case 'connected':
        return _buildStatusCard(
          icon: _connectionType == 'wifi' ? Icons.wifi : Icons.usb,
          iconColor: Colors.green,
          title: 'Printer Connected',
          message: 'Connected to ${_selectedPrinter?.model ?? "printer"}',
          subtitle: _connectionType == 'wifi'
              ? 'Connected via WiFi (${_selectedPrinter?.ipAddress ?? ""})'
              : 'Connected via USB',
        );
      default:
        return _buildStatusCard(
          icon: Icons.info,
          iconColor: Colors.grey,
          title: 'Printer Status',
          message: 'Checking printer connection...',
        );
    }
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String? subtitle,
    bool showProgress = false,
    bool showAction = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isNetworkPrinter())
                  const Icon(
                    Icons.wifi,
                    color: Colors.white70,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 24),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 3,
              ),
            ),
          ],
          if (showAction && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel ?? 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionButtons() {
    return Positioned(
      top: 50,
      right: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Printer Button (left)
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: _connectionType == 'usb' ? Colors.green : Colors.grey.shade700,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.5),
                  onTap: () {
                    _handleConnectionButtonTap();
                    if (_connectionType == 'usb') {
                      _performTestPrint();
                    }
                  },
                  child: Icon(
                    Icons.print,
                    color: _connectionType == 'usb' ? Colors.white : Colors.grey.shade400,
                    size: 11,
                  ),
                ),
              ),
            ),
          ),
          // WiFi Button (right)
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: _connectionType == 'wifi' ? Colors.green : Colors.grey.shade700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.5),
                onTap: () {
                  _handleConnectionButtonTap();
                  if (_connectionType == 'wifi') {
                    _performTestPrint();
                  }
                },
                child: Icon(
                  Icons.wifi,
                  color: _connectionType == 'wifi' ? Colors.white : Colors.grey.shade400,
                  size: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor() {
    switch (_currentState) {
      case 'permission':
        return Colors.orange;
      case 'searching':
        return Colors.blue;
      case 'connected':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentState) {
      case 'permission':
        return Icons.usb;
      case 'searching':
        return Icons.search;
      case 'connected':
        return _connectionType == 'wifi' ? Icons.wifi : Icons.usb;
      case 'error':
        return Icons.error;
      default:
        return Icons.print;
    }
  }

  String _getStatusMessage() {
    switch (_currentState) {
      case 'permission':
        return 'Permission Needed';
      case 'searching':
        return 'Searching...';
      case 'connected':
        return 'Connected via ${_connectionType.toUpperCase()}';
      case 'error':
        return 'Connection Error';
      default:
        return 'Checking...';
    }
  }

  bool _isNetworkPrinter() {
    return _connectionType == 'wifi';
  }

  void _handlePrinterIconTap() {
    log("Printer icon tapped - Current state: $_currentState");
    
    setState(() => _showStatusOverlay = true);
    
    if (_currentState == 'permission') {
      // User will tap the button in the overlay
    } else if (_currentState == 'connected') {
      // Close overlay and perform test print
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() => _showStatusOverlay = false);
        _performTestPrint();
      });
    }
  }
}