import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// استيراد WebView لـ Android
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // تهيئة WebView لـ Android بشكل آمن
    _initializeWebViewPlatform();
    _requestPermission();
  }

  void _initializeWebViewPlatform() {
    // تحقق مما إذا كانت المنصة هي Android قبل التهيئة
    if (Platform.isAndroid) {
      try {
        WebViewPlatform.instance = AndroidWebViewPlatform();
      } catch (e) {
        print("خطأ في تهيئة WebView لـ Android: $e");
      }
    }
  }

  Future<void> _requestPermission() async {
    if (await Permission.storage.request().isGranted) {
      print("تم منح إذن التخزين");
    } else {
      print("تم رفض إذن التخزين");
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      Dio dio = Dio();
      final cookies = await _controller.runJavaScriptReturningResult('document.cookie');
      String cookieString = cookies.toString().replaceAll('"', '');
      if (cookieString.isNotEmpty && cookieString != 'null') {
        dio.options.headers['Cookie'] = cookieString;
      }
      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/$fileName";
      await dio.download(url, filePath, onReceiveProgress: (rec, total) {
        print("تم تحميل: ${(rec / total * 100).toStringAsFixed(0)}%");
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تحميل الملف إلى: $filePath")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل التحميل: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تطبيق موقعي"),
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller = WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setUserAgent(
                  "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36")
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageStarted: (String url) {
                    print("بدأ تحميل الصفحة: $url");
                    setState(() {
                      _isLoading = true;
                      _errorMessage = '';
                    });
                  },
                  onPageFinished: (String url) {
                    print("انتهى تحميل الصفحة: $url");
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  onWebResourceError: (WebResourceError error) {
                    print("خطأ في تحميل الموارد: ${error.description}");
                    setState(() {
                      _isLoading = false;
                      _errorMessage = "خطأ: ${error.description}";
                    });
                  },
                  onNavigationRequest: (NavigationRequest request) {
                    print("طلب تنقل: ${request.url}");
                    if (request.url.contains('download_pdf=') || request.url.contains('download_user_sales=')) {
                      String fileName = request.url.contains('download_pdf=')
                          ? "فاتورة_${request.url.split('download_pdf=')[1].split('&')[0]}.pdf"
                          : "مبيعات_${request.url.split('download_user_sales=')[1].split('&')[0]}_${DateTime.now().millisecondsSinceEpoch}.pdf";
                      _downloadFile(request.url, fileName);
                      return NavigationDecision.prevent;
                    }
                    return NavigationDecision.navigate;
                  },
                ),
              )
              ..loadRequest(Uri.parse("https://essalmy.com/phone/login.php")),
          ),
          if (_isLoading) Center(child: CircularProgressIndicator()),
          if (_errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}