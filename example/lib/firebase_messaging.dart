import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_cura_sdk/cura_view.dart';

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configure local notification settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Initialize local notifications with onSelectNotification for handling taps in the foreground
    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        final payload = notificationResponse.payload;
        if (payload != null) {
          // Decode the payload and pass it to handleNotificationTap
          final data = jsonDecode(payload);
          CuraSDKView().handleNotificationTap(data);
        }
      },
    );

    // Get the device token for FCM
    String? token = await _firebaseMessaging.getToken();
    CuraSDKView().setDeviceToken(token);

    // Handle foreground messages only
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (CuraSDKView.isCuraNotification(message.data)) {
        if (await CuraSDKView().checkIsNotificationShouldShow(message.data)) {
          /**
           * Cura ask host app to show notification
           */
          _showNotification(message.data);
        }
      } else {
        /**
           * None Cura notification
           */
        _showNotification(message.data);
      }
    });

    // Handle notification taps when app is in background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Call handleNotificationTap from CuraSDKView and pass the message data
      CuraSDKView().handleNotificationTap(message.data);
    });
  }

  // Method to show a notification
  Future<void> _showNotification(Map<String, dynamic> message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cura_sdk_unique_id', // Provide a unique channel ID
      'cura_sdk_name', // Provide a name for the channel
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // Convert message data to JSON string to pass as payload
    String payload = jsonEncode(message);

    await _localNotificationsPlugin.show(
      generateRandomId(),
      "", // Title (optional, modify if needed)
      jsonDecode(message['customPayLoad'])['alert'],
      platformDetails,
      payload: payload, // Pass payload to handle taps in foreground
    );
  }


  int generateRandomId() {
    final random = Random();
    return random
        .nextInt(1000000); // Generates a random integer between 0 and 999999
  }
}
