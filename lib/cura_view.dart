import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
// import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_cura_sdk/storage_observer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_cura_sdk/cura_auth.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore_for_file: avoid_print

final storageObserver = StorageObserver();

enum CuraSDKJourneys {
  instantConsultation,
  consultations,
  labTest,
  prescriptions,
}

class CuraSDKView extends StatefulWidget {
  @override
  State<CuraSDKView> createState() => _CuraSDKViewState();
  static final CuraSDKView _instance = CuraSDKView._internal();
  static final GlobalKey<_CuraSDKViewState> _key = GlobalKey();
  // String userAgent =
  //     Platform.isAndroid ? "Flutter Android WebView" : "Flutter iOS WebView";

  factory CuraSDKView() => _instance;


  CuraSDKView._internal() : super(key: _key);


  WebViewController? _webViewController;
  // bool _isWebViewVisible = false;
  bool _curaIsInitialized = false;
  late String _webViewUrl;
  String _journey = "/consultations";
  // Properties to be passed to the WebView
  late String apiKey;
  late String organizationId;
  late String locale;
  late bool isClinicMode = false;
  late bool isProd;
  late bool isDev;
  late String appName;
  late bool isInstantConsultPaymentHandledByHostApp = false;
  late bool isModal = true;
  late bool isAuthenticationHandledByHostApp = true;

  static final StreamController<String> _eventOnDismiss =
      StreamController<String>.broadcast();
  // Expose the stream for listeners
  static Stream<String> get eventDismiss => _eventOnDismiss.stream;

  static final StreamController<String> _eventOnPresent =
      StreamController<String>.broadcast();
  // Expose the stream for listeners
  static Stream<String> get eventPresent => _eventOnPresent.stream;

  String? deviceToken;
  // VoidCallback? onInvokeDismissCuraCalled;
  // VoidCallback? onPresentLoginCalled;
  // Function(String requestId, double amount)? onPresentPaymentScreenCalled;
  // Function()? onShowCuraScreenCalled;
  // BuildContext? _currentContext; // Store context for pop
  // GlobalKey<NavigatorState>?
  //     navigatorKey; //needed to open cura screen from sdk for push notification purpose
  // Completer<Object>? loginCompleter;
  // Completer<Object>? initPaymentCompleter;

  // Set Journey
  static void setJourney(CuraSDKJourneys journey) {
    switch (journey) {
      case CuraSDKJourneys.instantConsultation:
        _instance._journey = "/case-description-landing";
        break;
      case CuraSDKJourneys.consultations:
        _instance._journey = "/consultations";
        break;
      case CuraSDKJourneys.labTest:
        _instance._journey = "/lab-tests";
        break;
      case CuraSDKJourneys.prescriptions:
        _instance._journey = "/prescriptions";
        break;
      default:
    }

    _instance._loadWebView(forceReload: true);
    _key.currentState?.updateJourney(CuraSDKJourneys.consultations);
  }

  // Future<void> printAllStoredValues() async {
  //   final prefs = await SharedPreferences.getInstance();

  //   Set<String> keys = prefs.getKeys();

  //   if (keys.isEmpty) {
  //     print("No values found in SharedPreferences.");
  //   } else {
  //     for (String key in keys) {
  //       final value = prefs.get(key);
  //       print("Key: $key, Value: $value");
  //     }
  //   }
  // }


  void initialize({
    required String apiKey,
    required String organizationId,
    String locale = "ar",
    // bool isClinicMode = false,
    String env = "development", // production, development
    String appName = "",
    // bool isInstantConsultPaymentHandledByHostApp = false,
    // bool isModal = false,
    // bool isAuthenticationHandledByHostApp = true,
    // VoidCallback? onInvokeDismissCura,
    // Function(BuildContext? context)? onDismiss,
    // VoidCallback? onPresentLogin,
    // required Function(String requestId, double amount) onPresentPaymentScreen,
    // GlobalKey<NavigatorState>? navigatorKey
  }) {
    _curaIsInitialized = true;
    // _webViewUrl = "https://sdk-test.pages.dev";
    // _webViewUrl = "https://sdk-41o.pages.dev";
    _webViewUrl = "http://localhost:8100";
    this.apiKey = apiKey;
    this.organizationId = organizationId;
    this.locale = locale;
    // this.isClinicMode = isClinicMode;
    // this.isClinicMode = false;
    isProd = (env == "production"); // isProd;
    isDev = (env == "development");
    this.appName = appName;
    // this.isInstantConsultPaymentHandledByHostApp =
    //     isInstantConsultPaymentHandledByHostApp;
    // this.isModal = isModal;
    // this.isModal = false;
    // this.isAuthenticationHandledByHostApp = isAuthenticationHandledByHostApp;
    // this.isAuthenticationHandledByHostApp = false;
    // this.onDismiss = onDismiss;
    // onPresentLoginCalled = onPresentLogin;
    // onPresentPaymentScreenCalled = onPresentPaymentScreen;
    // this.navigatorKey = navigatorKey;


    _loadWebView(); // Preload WebView in the background
  }

Future<void> _handleRecordingPermissions(String message) async {

    var microphoneStatus = await Permission.microphone.request();


    bool isPermanentlyDenied = microphoneStatus.isPermanentlyDenied;

    final permissionStatus = {
      'microphone': microphoneStatus.isGranted,
      'permanentlyDenied': isPermanentlyDenied,
    };

    _sendPermissionsResultToJavaScript(permissionStatus);

    if (isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  void _initializeJavaScriptChannels() {
    _webViewController
      ?..addJavaScriptChannel(
        "flutter_invokeDismissCura",
        onMessageReceived: (message) {
          hideCuraScreen();
          // onInvokeDismissCuraCalled?.call();
          _eventOnDismiss.add("");
        },
      )
      ..addJavaScriptChannel(
        "flutter_Download",
        onMessageReceived: (message) async {
          if (await canLaunchUrlString(message.message)) {
            await launchUrlString(message.message);
          }
        },
      )
      ..addJavaScriptChannel(
        "flutter_PresentAndWaitHostAppLoginScreen",
        onMessageReceived: (message) {
          print("Login message received: ${message.message}");
          _handleLogin();
        },
      )
      ..addJavaScriptChannel(
        "flutter_initiatePayment",
        onMessageReceived: (message) {
          _handlePaymentMessage(message.message);
        },
      )
      ..addJavaScriptChannel(
        "flutter_permessions",
        onMessageReceived: (message) {
          _handlePermessions();
        },
      )
      ..addJavaScriptChannel(
        "flutter_getUserInfo",
        onMessageReceived: (JavaScriptMessage message) async {

        final prefs = await SharedPreferences.getInstance();
          var jwtToken = prefs.getString("jwtToken");
          var refreshToken = prefs.getString("refreshToken");
          var userId = prefs.getString("userId");
          var userInfo = prefs.getString("userInfo");
          var devicetoken = prefs.getString("deviceToken");
          var userData = <String, dynamic>{};
          userData['userId'] = userId;
          userData['_cap_jwtToken'] = jwtToken;
          userData['_cap_refreshToken'] = refreshToken;
          userData['_cap_userId'] = userId;
          userData['_cap_userInfo'] = userInfo;
          userData['_cap_DeviceToken'] = devicetoken;
          userData['journey'] = _journey;


          final Map<String, dynamic> receivedObj = json.decode(message.message);
          var channelId = receivedObj['channelId'];


          final jsFunction = """
             (function() {
              if (window.onFlutterResponse$channelId) {
                window.onFlutterResponse$channelId(${jsonEncode(userData)});
              }
            })();
          """;

            _webViewController?.runJavaScript(jsFunction).catchError((error) {
              print("Error sending onFlutterResponse result to JavaScript: $error");
            });

        },
      )
      ..addJavaScriptChannel(
      "flutter_recordingPermissions",
      onMessageReceived: (message) async {
        await _handleRecordingPermissions(message.message);
      },
    );
  }

  void _handlePermessions() async {
    var cameraStatus = await Permission.camera.request();
    var microphoneStatus = await Permission.microphone.request();

    print(
        "Permissions status: Camera - $cameraStatus, Microphone - $microphoneStatus");

    // Check if permissions are permanently denied
    if (cameraStatus.isPermanentlyDenied ||
        microphoneStatus.isPermanentlyDenied) {

      // Send the status to JavaScript with a flag for permanently denied
      _sendPermissionsResultToJavaScript({
        'camera': cameraStatus.isGranted,
        'microphone': microphoneStatus.isGranted,
        'permanentlyDenied': true,
      });
    } else {
      _sendPermissionsResultToJavaScript({
        'camera': cameraStatus.isGranted,
        'microphone': microphoneStatus.isGranted,
        'permanentlyDenied': false,
      });
    }
  }

  void _sendPermissionsResultToJavaScript(
      Map<String, dynamic> permissionStatus) {
    final jsFunction = """
    window.onRecordingPermissionsResult(${jsonEncode(permissionStatus)});
  """;

    _webViewController?.runJavaScript(jsFunction).catchError((error) {
      print("Error sending permissions result to JavaScript: $error");
    });
  }

  void _handlePaymentMessage(message) {
    try {
      final data = jsonDecode(message);

      if (data is Map<String, dynamic>) {
        String requestId = data['requestId'].toString();
        double amount = (data['productPrice'] as num).toDouble();
        _initPayment(requestId, amount);
      } else if (data is List) {
        print("Message is a JSON: $data");
      }
    } catch (e) {
      print("Message : ${e.toString()}");
    }
  }

  Future<void> _setUpVideoCallSetting() async {
    // Set up inline playback for iOS
    await _webViewController?.runJavaScript('''
    document.querySelectorAll('video').forEach(video => {
      video.setAttribute('playsinline', 'true');
      video.setAttribute('webkit-playsinline', 'true');
    });
  ''');
  }

  void _loadWebView({bool forceReload = false}) async {
    if(!_curaIsInitialized) return;
    if (_webViewController == null || forceReload)
    {
      late final PlatformWebViewControllerCreationParams params;

      // Enable inline media playback for iOS specifically
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      // Initialize the WebViewController
      _webViewController = WebViewController.fromPlatformCreationParams(params, onPermissionRequest: (WebViewPermissionRequest request) => request.grant())
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(_webViewUrl),)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (url) async {
            // _setUserAgentJavaScript();
            _setLocalStorageValues();
            _setUpVideoCallSetting();
          },
          onPageStarted: (url) async {
            await _setUpVideoCallSetting();
          },
        ));

      /**
       * Allow IOS Inspect Element
       */
      if (_webViewController?.platform is WebKitWebViewController) {
        (_webViewController?.platform as WebKitWebViewController)
            .setInspectable(true);
      }

      _initializeJavaScriptChannels();
    }
    
  }

  // void _setUserAgentJavaScript() {
  //   String userAgentScript = """
  //   Object.defineProperty(navigator, 'userAgent', {
  //     value: '$userAgent',
  //     writable: false,
  //   });
  //   """;
  //   _webViewController?.runJavaScript(userAgentScript);
  // }

  Future<void> _handleLogin() async {
    // loginCompleter = Completer<Object>();
    // onPresentLoginCalled?.call();
    // await loginCompleter!.future;
  }

  Future<void> _initPayment(String requestId, double amount) async {
    // initPaymentCompleter = Completer<Object>();
    // onPresentPaymentScreenCalled?.call(requestId, amount);
    // await initPaymentCompleter!.future;
  }

void authenticate(Map<String, dynamic> result) async {
    try {

      final authResult = await CuraAuth.loginByMobileNumber(result);

      if (result.containsKey("DeviceToken") && result["DeviceToken"] != null) {
        await Future.delayed(const Duration(seconds: 8));
        await setDeviceToken(result["DeviceToken"]);
      }
      if (authResult is Map) {
        print("Authentication success: ${JsonEncoder().convert(authResult)}");
      } else {
        print("Authentication result: $authResult");
      }
    } catch (e) {
      print("Error authentication: $e");
    }
  }

  void completePayment(Map<String, dynamic> result) {
    // if (initPaymentCompleter != null && !initPaymentCompleter!.isCompleted) {
    //   print("Login completed successfully");
    //   initPaymentCompleter!.complete(result);
    //   initPaymentCompleter = null;

    //   print("jsonEncode(result) ${jsonEncode(result)}");
    //   sendPaymentResultToJavaScript(jsonEncode(result));
    // } else {
    //   print("loginCompleter is null or already completed");
    // }
  }
Future<void> logout() async {
    try {
      await CuraAuth.logout();
      if(_webViewController != null){
        await _webViewController?.runJavaScript('''
        localStorage.clean();
      ''');
      _loadWebView(forceReload: true);
      }
      print("Logout successful.");
    } catch (e) {
      print("Error during logout: $e");
    }
  }

  Future<void> setDeviceToken(String? token) async {
    if (token != null) {
      await storageObserver.updateValue("deviceToken", token);
    } else {
      await storageObserver.removeValue("deviceToken");
    }
  }

Future<String?> getDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? deviceToken = prefs.getString("deviceToken");

      return deviceToken;
    } catch (e) {
      return null;
    }
  }

  // void sendLoginResultToJavaScript(String result) async {
  //   final jsFunction =
  //       "window.onLoginResponse && window.onLoginResponse('$result');";
  //   try {
  //     print("Login result runJavaScript");

  //     await _webViewController?.runJavaScript(jsFunction);
  //     print("Login result sent to JavaScript successfully");
  //   } catch (error) {
  //     print("Error sending login result to JavaScript: $error");
  //   }
  // }

  // void sendPaymentResultToJavaScript(String result) async {
  //   final jsFunction =
  //       "window.handlePaymentResult && window.handlePaymentResult('$result');";
  //   try {
  //     print("payment result runJavaScript");

  //     await _webViewController?.runJavaScript(jsFunction);
  //     print("payment result sent to JavaScript successfully");
  //   } catch (error) {
  //     print("Error sending payment result to JavaScript: $error");
  //   }
  // }

  void _setDeviceTokenValue(bool isRemove) {
    print("isRemove $isRemove");
    String jsCode;
    if (!isRemove) {
      print("deviceToken $deviceToken");

      jsCode = """
      localStorage.setItem('_cap_DeviceToken', '$deviceToken');  
      var event = new CustomEvent("storage", {detail:{ key: "_cap_DeviceToken", newValue: '$deviceToken' }}); 
      window.dispatchEvent(event); 
      window.DeviceToken= '$deviceToken';


    """;
    } else {
      jsCode = """
      localStorage.removeItem('_cap_DeviceToken');
      var event = new CustomEvent("storage", {detail:{ key: "_cap_DeviceToken", newValue: '' }});  
      window.dispatchEvent(event);
      window.DeviceToken= '';


    """;
    }

    _webViewController?.runJavaScript(jsCode).catchError((error) {
      print("JavaScript execution failed: $error");
    });
  }

  void _setLocalStorageValues() {
    final jsCode = """
      localStorage.setItem('_cap_ApiKey', '${this.apiKey}');
      localStorage.setItem('_cap_platform', 'flutter');
      window.platform = 'flutter';
      localStorage.setItem('_cap_OrganizationId', '${this.organizationId}');
      localStorage.setItem('_cap_Locale', '${this.locale}');
      localStorage.setItem('_cap_isClinicMode', '${this.isClinicMode}');
      localStorage.setItem('_cap_isProd', '${this.isProd}');
      localStorage.setItem('_cap_isDev', '${this.isDev}');
      localStorage.setItem('_cap_AppName', '${this.appName}');
      localStorage.setItem('_cap_isInstantConsultPaymentHandledByHostApp', '${this.isInstantConsultPaymentHandledByHostApp}');
      localStorage.setItem('_cap_isModal', '${this.isModal}');
      localStorage.setItem('_cap_isAuthenticationHandledByHostApp', '${this.isAuthenticationHandledByHostApp}');
      console.log('Local storage values set from Flutter');
    """;

    _webViewController?.runJavaScript(jsCode);
  }

  // @override
  // Widget build(BuildContext context) {
  //   // _currentContext = context;
  //   if (_curaIsInitialized) {
  //     _loadWebView();
  //     return Center(child: WebViewWidget(controller: _webViewController));
  //   } else {
  //     return const Center(child: Text("initialzied Cura First!!!"));
  //   }

  //   // final WebViewController controller = WebViewController()
  //   //       ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //   //       ..loadRequest(Uri.parse("https://sdk-41o.pages.dev"));
  //   // return WebViewWidget(controller: _webViewController);
  // }

  // void showCuraScreen(BuildContext? context) {
  //   if (_isWebViewInitialized) {
  //     _isWebViewVisible = true;
  //     if (context != null) {
  //       _currentContext = context; // Store the context to use in hideCuraScreen
  //       Navigator.of(context).push(
  //         MaterialPageRoute(
  //           builder: (context) =>
  //               WebViewContainer(controller: _webViewController),
  //         ),
  //       );
  //     } else {
  //       navigatorKey?.currentState?.push(MaterialPageRoute(
  //         builder: (context) {
  //           _currentContext = context;
  //           return WebViewContainer(controller: _webViewController);
  //         },
  //       ));
  //     }
  //   }
  // }

  void hideCuraScreen() {
    // if (_isWebViewVisible && _currentContext != null) {
    //   Navigator.of(_currentContext!).pop(); // Close the WebView screen
    //   _isWebViewVisible = false;
    // }
  }

  static bool isCuraNotification(Map<String, dynamic> message){
    if(message.containsKey('customPayLoad')){
      return true;
    }
    return false;
  }

  Future<bool> checkIsNotificationShouldShow(
      Map<String, dynamic> notificationData) async {
    String? itemEntity;
    int? itemId;
    print("notificationDatanotificationDatanotificationData $notificationData");

    // iOS payload (contains "aps" with nested data)
    if (notificationData.containsKey("aps")) {
      final aps = jsonDecode(notificationData["aps"]);
      itemEntity = aps?["ItemEntity"];
      itemId = aps?["ItemId"];
    }
    // Android payload (contains "customPayLoad" with nested data)
    else if (notificationData.containsKey("customPayLoad")) {
      final customPayload = jsonDecode(notificationData["customPayLoad"]);

      itemEntity = customPayload?["ItemEntity"] as String?;

      itemId = customPayload?["ItemId"];
    }

    if (itemEntity == null) {
      print("No ItemEntity found");
      return true;
    }
    // Build the notification key
    // var notificationMergedKey = itemEntity;
    // if (itemId != null) {
    //   notificationMergedKey += ";$itemId";
    // }

    // Retrieve the current screen from WebView's local storage
    try {
      final currentScreenMergedKey = await getCurrentScreenFromWebView();
      if (currentScreenMergedKey!.contains("$itemId")) {
        print("Same screen");
        return false;
      } else {
        print("Different screen");
        return true;
      }
    } catch (error) {
      print("Error : $error");
      return true;
    }
  }

  void handleNotificationTap(Map<String, dynamic> data) async {
    String? itemEntity;

    setJourney(CuraSDKJourneys.consultations);
    Future.delayed(Duration(seconds: 2), () {
      // iOS payload structure
      if (data.containsKey("aps")) {
        itemEntity = jsonDecode(data['aps'])?['ItemEntity'];
      }
      // Android payload structure
      else if (data.containsKey("customPayLoad")) {
        itemEntity = jsonDecode(data['customPayLoad'])?['ItemEntity'];
      }
      if (itemEntity != null) {
        // onShowCuraScreenCalled?.call();
        _eventOnPresent.add("");
        _sendNotificationTappedToWebView(data);
      }
    });
  }

  void _sendNotificationTappedToWebView(Map<String, dynamic> data) {
    final stringData = jsonEncode(data);
    var jsCode = """
    window.onNotificationTapped($stringData);  
  """;
    _webViewController?.runJavaScript(jsCode);
  }

// Helper method to get the current screen from the WebView's local storage
  Future<String?> getCurrentScreenFromWebView() async {
    try {
      if (_webViewController != null) {
        final result = await _webViewController?.currentUrl();
        print(result);
        return result;
      }
      return null;
    } catch (e) {
      print("Error retrieving current screen from WebView: $e");
      return null; // Return null if there's an error
    }
  }

Future<String?> getSNSEndPointArn() async {
    return getLocalStorageValue('_cap_SNSEndPointArn');
  }

  Future<String?> getVoIPDeviceToken() async {
    return getLocalStorageValue('_cap_VoIPDeviceToken');
  }
  Future<String?> getSNSVoIPEndPointArn() async {
    return getLocalStorageValue('_cap_SNSVoIPEndPointArn');
  }

Future<String?> getLocalStorageValue(String key) async {
    final jsCode = """
    localStorage.getItem('$key') || "";
  """;
    try {
      final result =
          await _webViewController?.runJavaScriptReturningResult(jsCode);
      return result as String?;
    } catch (e) {
      print("Error retrieving value for key '$key': $e");
      return null; 
    }
  }
}

// WebViewContainer for full-screen view
// class WebViewContainer extends StatelessWidget {
//    final WebViewController controller = WebViewController()
//         ..setJavaScriptMode(JavaScriptMode.unrestricted)
//         ..loadRequest(Uri.parse("https://sdk-41o.pages.dev"));

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: WebViewWidget(controller: controller),
//     );
//   }
// }
class _CuraSDKViewState extends State<CuraSDKView> {
  var journey = CuraSDKJourneys.instantConsultation;
  void updateJourney(newJoureny) {
    setState(() {
      journey = newJoureny;
    });
  }
  @override
  Widget build(BuildContext context) {
    widget._loadWebView();
    if (widget._webViewController != null) {
      widget._loadWebView();
      return Center(
          child: WebViewWidget(controller: widget._webViewController!));
    } else {
      return const Center(child: Text("initialzied Cura First!!!"));
    }
  }
}
