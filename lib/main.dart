import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epson_epos/epson_epos.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'printer_utils.dart';

void main() {
  // Enable Android WebView debugging
  if (Platform.isAndroid) {
    AndroidWebViewController.enableDebugging(true);
  }
  
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
  String _currentState = 'permission'; // permission, got_permission, list_printer, selected_first_printer
  EpsonPrinterModel? _selectedPrinter;
  List<EpsonPrinterModel> _printers = [];
  
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
          },
        ),
      )
      ..loadRequest(Uri.parse('https://dbaccess.thinkry.tech/'));
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
          _currentState = 'got_permission';
        });
        log("Permission granted, discovering printers...");
       
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

  Future<void> _discoverPrinters() async {
    try {
      log("Discovering printers...");
      List<EpsonPrinterModel> allPrinters = await PrinterUtils.discoverAllPrinters();
      
      if (allPrinters.isNotEmpty) {
        setState(() {
          _printers = allPrinters;
          _currentState = 'list_printer';
        });
        log("Found ${allPrinters.length} printers total");
        await _selectFirstPrinter();
      } else {
        log("No printers found, starting continuous discovery...");
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
      if (_currentState == 'selected_first_printer') {
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

      if (_currentState == 'got_permission') {
        // timer.cancel();
        if (!_isDiscoveringPrinters) {
          _isDiscoveringPrinters = true;
          await _discoverPrinters();
          _isDiscoveringPrinters = false;
        }
        // await _discoverPrinters();
        return;
      }
      
      try {
        log("Continuous discovery: Scanning for printers...");
        List<EpsonPrinterModel> allPrinters = await PrinterUtils.discoverAllPrinters();
        
        if (allPrinters.isNotEmpty) {
          setState(() {
            _printers = allPrinters;
            _currentState = 'list_printer';
          });
          log("Continuous discovery: Found ${allPrinters.length} printers!");
          await _selectFirstPrinter();
          timer.cancel();
        } else {
          log("Continuous discovery: No printers found, will retry in 5 seconds...");
        }
      } catch (e) {
        log("Continuous discovery error: $e");
      }
    });
  }

  Future<void> _selectFirstPrinter() async {
    if (_printers.isNotEmpty) {
      setState(() {
        _selectedPrinter = _printers.first;
        _currentState = 'selected_first_printer';
      });
      
      // Stop blinking animation when printer is found
      _blinkController.stop();
      
      log("Selected first printer: ${_selectedPrinter!.model}");
      final connectionType = _isNetworkPrinter() ? 'WiFi' : 'USB';
      _showMessage('✓ Printer connected via $connectionType');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
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

  Future<void> _performTestPrint() async {
    if (_selectedPrinter == null) {
      _showMessage('No printer available. Please check connection.', isError: true);
      return;
    }

    try {
      log("Performing test print on ${_selectedPrinter!.model}");
      _showMessage('Sending receipt to printer...');
      
      // Create test print commands using PrinterUtils
      List<Map<String, dynamic>> commands = PrinterUtils.buildEpsonCommandsForReceipt();
      
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

  void _handlePrintFromWeb(String jsonMessage) {
    try {
      log("Received print request from web: $jsonMessage");
      
      // Parse the JSON from web
      final Map<String, dynamic> receiptData = jsonDecode(jsonMessage);
      
      // Build Epson commands from the received JSON
      final commands = PrinterUtils.buildEpsonCommandsFromJson(receiptData);
      
      // Print the receipt
      if (_selectedPrinter != null) {
        _printReceipt(commands);
      } else {
        _showMessage('No printer connected. Please check connection.', isError: true);
      }
    } catch (e) {
      log("Error handling print from web: $e");
      _showMessage('Failed to process print request.', isError: true);
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
          if (_showStatusOverlay) _buildStatusOverlay(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _currentState == 'selected_first_printer' ? 1.0 : _blinkAnimation.value,
            child: FloatingActionButton.extended(
              onPressed: _handlePrinterIconTap,
              backgroundColor: _getButtonColor(),
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                  ),
                  if (_isNetworkPrinter()) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.wifi,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ],
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
      case 'got_permission':
        return _buildStatusCard(
          icon: Icons.search,
          iconColor: Colors.blue,
          title: 'Searching for Printer',
          message: 'Please wait while we locate your printer...',
          showProgress: true,
        );
      case 'list_printer':
        return _buildStatusCard(
          icon: Icons.print,
          iconColor: Colors.purple,
          title: 'Printer Found',
          message: 'Connecting to ${_printers.length} printer${_printers.length > 1 ? 's' : ''}...',
          showProgress: true,
        );
      case 'selected_first_printer':
        return _buildStatusCard(
          icon: Icons.check_circle,
          iconColor: Colors.green,
          title: 'Printer Ready',
          message: 'Connected to ${_selectedPrinter?.model ?? "printer"}',
          subtitle: _isNetworkPrinter() 
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

  Color _getButtonColor() {
    switch (_currentState) {
      case 'permission':
        return Colors.orange;
      case 'got_permission':
        return Colors.blue;
      case 'list_printer':
        return Colors.purple;
      case 'selected_first_printer':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentState) {
      case 'permission':
        return Icons.usb;
      case 'got_permission':
        return Icons.search;
      case 'list_printer':
        return Icons.print;
      case 'selected_first_printer':
        return Icons.check_circle;
      default:
        return Icons.print;
    }
  }

  String _getStatusMessage() {
    switch (_currentState) {
      case 'permission':
        return 'Permission Needed';
      case 'got_permission':
        return 'Searching...';
      case 'list_printer':
        return 'Found ${_printers.length}';
      case 'selected_first_printer':
        return 'Ready to Print';
      default:
        return 'Checking...';
    }
  }

  bool _isNetworkPrinter() {
    if (_selectedPrinter == null) return false;
    return _selectedPrinter!.ipAddress != null && 
           _selectedPrinter!.ipAddress!.isNotEmpty &&
           _selectedPrinter!.ipAddress != 'USB';
  }

  void _handlePrinterIconTap() {
    log("Printer icon tapped - Current state: $_currentState");
    
    setState(() => _showStatusOverlay = true);
    
    if (_currentState == 'permission') {
      // User will tap the button in the overlay
    } else if (_currentState == 'selected_first_printer') {
      // Close overlay and perform test print
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() => _showStatusOverlay = false);
        _performTestPrint();
      });
    }
  }
}