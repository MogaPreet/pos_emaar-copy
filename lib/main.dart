import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(EpsonApp());
}

class EpsonApp extends StatefulWidget {
  @override
  _EpsonAppState createState() => _EpsonAppState();
}

class _EpsonAppState extends State<EpsonApp> {
  static const MethodChannel _channel = MethodChannel('epson_usb_printer');
  bool _isPrinterConnected = false;
  bool _isInternetConnected = false;
  bool _isCheckingPrinter = false;
  late WebViewController _webViewController;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    
    // Hide system status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Initialize WebView controller
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
              print("Page loaded: $url");
              // Check internet connectivity when page loads successfully
              _checkInternetConnection();
              // Inject bridge so pages using inappwebview/react-native APIs relay to FlutterPrint
              _injectWebBridge();
            },
            onWebResourceError: (WebResourceError error) {
              print("WebView error: ${error.description}");
              // If there's a network error, mark as offline
              setState(() {
                _isInternetConnected = false;
              });
            },
          ),
        )
      ..loadRequest(Uri.parse('http://192.168.100.77:3001/')); // Default URL
    
    // Delay auto-connect to ensure widget tree is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectPrinter();
      _checkInternetConnection();
      
      // Start periodic connectivity checks
      _connectivityTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        _checkInternetConnection();
        _checkPrinterConnection();
      });
    });
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  void _handlePrintFromWeb(String jsonMessage) async {
    try {
      final Map<String, dynamic> receiptData = jsonDecode(jsonMessage);

      if (receiptData['action'] == 'printTicket') {
        try {
          await _channel.invokeMethod('printTickets', {'ticketData': jsonMessage});
        } catch (e) {
          print("Print ticket failed: $e");
          await _checkPrinterConnection();
        }
      }

      if (receiptData['action'] == 'printReceipt') {
        try {
          await _channel.invokeMethod('printReceipt', {'ticketData': jsonMessage});
        } catch (e) {
          print("Print receipt failed: $e");
          await _checkPrinterConnection();
        }
      }

      if (receiptData['action'] == 'printVoidTransaction') {
        try {
          await _channel.invokeMethod('printVoidTransaction', {'ticketData': jsonMessage});
        } catch (e) {
          print("Print void transaction failed: $e");
          await _checkPrinterConnection();
        }
      }

      print("Received message from web (as obj): $receiptData");
    } catch (e) {
      print("Error parsing JSON from web: $e");
      print("Raw message: $jsonMessage");
    }
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

  Future<void> _checkInternetConnection() async {
    try {
      // Try to connect to a reliable server to check internet connectivity
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _isInternetConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isInternetConnected = false;
      });
    }
  }

  Future<void> _checkPrinterConnection() async {
    try {
      final bool connected = await _channel.invokeMethod('isPrinterConnected');
      setState(() {
        _isPrinterConnected = connected;
      });
    } catch (e) {
      print('Check printer connection error: $e');
      setState(() {
        _isPrinterConnected = false;
      });
    }
  }

  Future<void> _autoConnectPrinter() async {
    try {
      await _channel.invokeMethod('autoConnectUsbPrinter');
      // Check the actual connection status after attempting to connect
      await _checkPrinterConnection();
    } catch (e) {
      print('Auto connect error: $e');
      setState(() {
        _isPrinterConnected = false;
      });
    }
  }

  Future<void> _checkAndConnectPrinter() async {
    if (_isCheckingPrinter) return; // Prevent multiple simultaneous checks
    
    setState(() {
      _isCheckingPrinter = true;
    });
    
    try {
      print("Checking current printer status...");
      
      // First check current status
      await _checkPrinterConnection();
      
      if (!_isPrinterConnected) {
        print("Printer not connected, attempting to connect...");
        
        // Attempt to connect
        await _channel.invokeMethod('autoConnectUsbPrinter');
        
        // Check status again after connection attempt
        await _checkPrinterConnection();
        
        if (_isPrinterConnected) {
          print("✅ Printer connected successfully!");
        } else {
          print("❌ Failed to connect to printer");
        }
      } else {
        print("✅ Printer is already connected");
      }
    } catch (e) {
      print('Check and connect printer error: $e');
      setState(() {
        _isPrinterConnected = false;
      });
    } finally {
      setState(() {
        _isCheckingPrinter = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove debug ribbon
      home: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Full screen WebView
              WebViewWidget(controller: _webViewController),
              
              // Floating status icons in top right corner
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Printer status icon (clickable)
                      GestureDetector(
                        onTap: () async {
                          print("Printer icon clicked - checking connection...");
                          await _checkAndConnectPrinter();
                        },
                        child: Container(
                          width: 40,
                          height: 30,
                          child: _isCheckingPrinter 
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              )
                            : Icon(
                                Icons.print,
                                color: _isPrinterConnected ? Colors.green : Colors.red,
                                size: 20,
                              ),
                        ),
                      ),
                      SizedBox(width: 4),
                      // WiFi status icon
                      Container(
                        width: 40,
                        height: 30,
                        child: Icon(
                          _isInternetConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isInternetConnected ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
