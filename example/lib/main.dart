// ignore_for_file: library_private_types_in_public_api

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_cura_sdk/cura_view.dart';
import 'package:flutter_cura_sdk_example/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // Add any custom logic here if needed, e.g., logging, analytics, etc.
}

void main() async {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    PushNotificationService().initialize();
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const pushNotificationChannel =
      MethodChannel('PushNotificationChannel'); // Same name as in iOS

  String? _deviceToken;
  Map<String, dynamic>? _notificationData;

  @override
  void initState() {
    super.initState();
    _initializeSDK(); // Pass context here after the first frame
    if (Platform.isIOS) {
      _requestNotificationPermissions();
      _registerForPushNotifications();
      _getDeviceToken();
      _setupNotificationHandler();
    }
  }

  Future<bool> _shouldShowNotification(Map<String, dynamic> userInfo) async {
    print("_shouldShowNotification userInfo $userInfo");

    bool result = await CuraSDKView().checkIsNotificationShouldShow(userInfo);
    print("_shouldShowNotification result $result");

    return result;
  }

  Future<void> _registerForPushNotifications() async {
    try {
      await pushNotificationChannel
          .invokeMethod('registerForPushNotifications');
      print("Push notification registration initiated.");
    } on PlatformException catch (e) {
      print("Failed to register for push notifications: ${e.message}");
    }
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      final granted = await pushNotificationChannel
          .invokeMethod('requestNotificationPermissions');
      if (granted) {
        print("Notification permissions granted.");
      } else {
        print("Notification permissions denied.");
      }
    } on PlatformException catch (e) {
      print("Failed to request notification permissions: ${e.message}");
    }
  }

  void _setupNotificationHandler() {
    pushNotificationChannel.setMethodCallHandler((call) async {
      if (call.method == "onPushNotificationTap") {
        setState(() {
          _notificationData = Map<String, dynamic>.from(call.arguments);
        });

        print("Full Notification Data: $_notificationData");

        // Perform actions based on the data received
        if (_notificationData != null) {
          CuraSDKView().handleNotificationTap(_notificationData!);
        }
      }
      if (call.method == "onPushNotificationCheck") {
        print("onPushNotificationCheck $call");

        // Safely cast call.arguments to a Map<String, dynamic>
        final arguments = call.arguments as Map<dynamic, dynamic>?;

        if (arguments != null) {
          print("arguments: $arguments");

          // Safely access requestId from arguments
          final requestId = arguments["requestId"] as String?;

          if (requestId != null) {
            print("requestId: $requestId");

            // Your logic to determine whether to show the notification
            bool shouldShow = await _shouldShowNotification(
                arguments.cast<String, dynamic>());
            print("shouldShow: $shouldShow");

            // Send the response back to Swift with the requestId
            pushNotificationChannel.invokeMethod("onPushNotificationResponse", {
              "requestId": requestId,
              "shouldShow": shouldShow,
            });
          } else {
            print("Error: requestId is missing or not a String.");
            print("Error arguments: $arguments");
          }
        } else {
          print("Error: arguments is not a Map<String, dynamic>.");
        }
      }
    });
  }

  Future<void> _getDeviceToken() async {
    try {
      pushNotificationChannel.setMethodCallHandler((call) async {
        if (call.method == "onPushNotification") {
          setState(() {
            _deviceToken = call.arguments; // Store the token
          });
          print("Device Token from iOS: $_deviceToken");
        }
      });

      // Optionally, if you want to request the token actively from the iOS side:
      final token = await pushNotificationChannel
          .invokeMethod<String>('retrieveDeviceToken');
      if (token != null) {
        setState(() {
          _deviceToken = token;
        });
        print("Retrieved Device Token from iOS: $_deviceToken");
      }
      _setDeviceToken(token);
    } on PlatformException catch (e) {
      print("Failed to get device token: '${e.message}'.");
    }
  }

  void _initializeSDK() {
    CuraSDKView().initialize(
      apiKey: "6b15c73d-9bc0-4342-acc3-416a8de02146",
      organizationId: "7f268ba2-5094-4137-886a-4ed3d48cd27c",
      locale: "ar",
      env: "development",
      appName: "com.ubieva.cura",
    );
  }

  void _setDeviceToken(String? token) {
    CuraSDKView().setDeviceToken(token);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    CuraSDKView.eventDismiss.listen((event) {
      Navigator.of(context!).pop();
    });
    CuraSDKView.eventPresent.listen((event) {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (context) {
          return const Curascreen();
        },
      ));
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cura Hosted'),
      ),
      // body: CuraSDKView(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Centers the buttons vertically

          children: [
            ElevatedButton(
              onPressed: () {
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (context) {
                    CuraSDKView.setJourney(CuraSDKJourneys.instantConsultation);
                    return const Curascreen();
                  },
                ));
              },
              child: const Text("Instant Consutation"),
            ),
            ElevatedButton(
              onPressed: () {
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (context) {
                    CuraSDKView.setJourney(CuraSDKJourneys.consultations);
                    return const Curascreen();
                  },
                ));
              },
              child: const Text("My Consultation"),
            ),
            ElevatedButton(
              onPressed: () {
                CuraSDKView.setJourney(CuraSDKJourneys.labTest);
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (context) {
                    return const Curascreen();
                  },
                ));
              },
              child: const Text("My LabTest"),
            ),
            ElevatedButton(
              onPressed: () {
                CuraSDKView.setJourney(CuraSDKJourneys.prescriptions);
                navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (context) {
                    return const Curascreen();
                  },
                ));
              },
              child: const Text("My Prescription"),
            ),
            const SizedBox(height: 64), // Adds space between the buttons
            ElevatedButton(
              onPressed: () {
                CuraSDKView().authenticate({                  
                  "FirstName": "ahmedflutter",
                  "LastName": "Ob",
                  "Gender": "Female",
                  "MobileNumber": "+96278232111",
                  "DeviceToken":
                      "c4YCEQDpTYKQQYb2qsFM4m:APA91bHa7Bmm91uLdJoAPtVaFShppduYbFTNizC3LG8E41Sx5WgKUsGaRuvaeiOUddq7YgXx7uksMI6vSJKzSWl-j-R7TXH8bstkOch1jcnVE1xBY4hwWa8u4jDoQK5YrWHHtYR",
                  "IntegratorUserId": "",
                  "UserName": "ahmedflutter",
                  "DisplayName": "ahmedflutter",
                  "Email": "ahmedflutter@yahoo.com",
                  "Password": "ahmed12345",
                  "Birthdate": "2000-11-19T00:00:00.0000000Z",
                  "LocationCountryId": 1,
                  "Created": "2024-06-24T09:42:37.0000000Z",
                  "Modified": "2024-06-24T09:42:37.0000000Z",
                  "patients": [
                    {
                      "FullName": "RORO kk",
                      "DateOfBirth": "2020-01-01T00:00:00.0000000Z",
                      "MobileNumber": "999888777",
                      "Gender": "Female",
                      "OfficalIdNumber": "1092837463",
                      "OfficialIdType": 1,
                      "BeneficiaryRelationshipId": null
                    },
                    {
                      "FullName": "JOJO ll new",
                      "DateOfBirth": "2019-01-01T00:00:00.0000000Z",
                      "MobileNumber": "888777999",
                      "Gender": "Male",
                      "OfficalIdNumber": "1785948578",
                      "OfficialIdType": 2,
                      "BeneficiaryRelationshipId": 3
                    }
                  ]
                });
              },
              child: const Text("Login"),
            ),
            const SizedBox(height: 16), // Adds space between the buttons
            ElevatedButton(
              onPressed: () {
                CuraSDKView().logout();
              },
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}

class Curascreen extends StatelessWidget {
  const Curascreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Cura SDK'),
      // ),
      body: CuraSDKView(),
    );
  }
}
