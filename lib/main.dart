import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_api.dart';
import 'page/notification_screen.dart';
import 'package:package_info/package_info.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseApi firebaseApi = FirebaseApi();
  String fCMToken = await firebaseApi.getFCMToken();
  await firebaseApi.initNotifications();

  // Get the app version before running the app
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String appVersion = packageInfo.version;

  runApp(MaterialApp(
    home: WebViewApp(fCMToken: fCMToken, appVersion: appVersion),
    routes: {
      NotificationScreen.route: (context) => const NotificationScreen(),
    },
    navigatorKey: navigatorKey,
  ));
}

class WebViewApp extends StatefulWidget {
  final String fCMToken;
  final String appVersion;

  const WebViewApp({required this.fCMToken, required this.appVersion, Key? key}) : super(key: key);

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late WebViewController _controller;
  bool _initialized = false; // Added a flag to track initialization

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        _getToken();
        _checkForUpdates();
      });
    }
  }

  _getToken() {
    String fCMToken = widget.fCMToken;
  }

  _checkForUpdates() async {
    String latestVersion = await _getLatestAppVersion();
    if (_compareVersions(widget.appVersion, latestVersion) == -1) {
      showForceUpdateDialog(true);
    }
  }

  Future<String> _getLatestAppVersion() async {
    String latestVersion = '1.4.0';
    return latestVersion;
  }

  // Function to compare versions
  // Returns -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    List<String> parts1 = v1.split('.');
    List<String> parts2 = v2.split('.');

    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      int parsed1 = int.parse(parts1[i]);
      int parsed2 = int.parse(parts2[i]);
      if (parsed1 < parsed2) return -1;
      if (parsed1 > parsed2) return 1;
    }

    if (parts1.length < parts2.length) return -1;
    if (parts1.length > parts2.length) return 1;
    return 0;
  }

  void openWebView(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(),
          body: WebView(
            initialUrl: url,
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (controller) {
              setState(() {
                _controller = controller;
              });
            },
            onPageStarted: (url) {
              // 로딩 중임을 사용자에게 알림
              // (예: CircularProgressIndicator 표시)
            },
            onPageFinished: (url) {
              // 로딩 완료되었음을 사용자에게 알림
              // (예: CircularProgressIndicator 숨김)
            },
            navigationDelegate: (NavigationRequest request) async {
              if (_isCustomScheme(request.url)) {
                Uri url = Uri.parse(request.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                  return NavigationDecision.prevent; // Prevent navigation for custom schemes
                } else {
                  return NavigationDecision.prevent; // Prevent navigation if custom scheme cannot be launched
                }
              }
              return NavigationDecision.navigate; // Allow navigation for other URLs
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        } else {
          exit(0);
          return true;
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: WebView(
            initialUrl: "https://heycosmetics.kr?token=${widget.fCMToken}&ver=${widget.appVersion}",
            javascriptMode: JavascriptMode.unrestricted,
            userAgent: 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Mobile Safari/537.36',
            onWebViewCreated: (WebViewController controller) {
              _controller = controller;
            },
            navigationDelegate: (NavigationRequest request) async {
              if (_isCustomScheme(request.url)) {
                Uri url = Uri.parse(request.url);
                if (await canLaunchUrl(url)) {
                  openWebView(context, request.url);
                  return NavigationDecision.prevent;

                } else {
                  await launchUrl(
                      url
                  );
                  return NavigationDecision.prevent;
                }
              }
              return NavigationDecision.navigate;
            },
          ),
        ),
      ),
    );
  }

  bool _isCustomScheme(String url) {
    return !(url.startsWith('http://') || url.startsWith('https://'));
  }

  // show force update dialog
  void showForceUpdateDialog(bool forceUpdate) {
    showDialog(
      barrierDismissible: false,

      context: context,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Text(forceUpdate ? '꿀스메틱 업데이트 안내' : '새로운 버전 출시'),
            content: Text(forceUpdate ? '최신버전이 업데이트 되었어요. 원활한 서비스를 위한 업데이트를 진행해 주세요.' : '최신버전이 업데이트 되었어요. 지금 업데이트 하고 새로운 기능을 만나보세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () async {
                  StoreRedirect.redirect(androidAppId: 'com.solutionfocus.cosmetic', iOSAppId: "6458139565");
                },
                child: const Text('업데이트'),
              ),
            ],
          ),
        );
      },
    );
  }
}
