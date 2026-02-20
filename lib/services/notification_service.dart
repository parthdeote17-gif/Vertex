import 'dart:convert';
import 'package:flutter/services.dart'; // Asset load
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

// ✅ Background Handler (Must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? currentChatId; // Tracks open chat ID

  // ⚠️ Make sure this Project ID is correct from Firebase Console
  static const String _projectId = 'vertex-de3d1';

  // 🔥 1. Initialize Notification
  static Future<void> initialize(
      Function(String payload) onNotificationClick) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Background Handler Register
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Initialize Local Notifications (For Foreground Clicks)
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle Notification Click (Foreground)
        if (response.payload != null) {
          onNotificationClick(response.payload!);
        }
      },
    );

    // ✅ CHANNEL 1: CALLS (Custom Ringtone)
    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'call_channel', // ID
      'Incoming Calls', // Name
      description: 'Channel for incoming video/audio calls',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
    );

    // ✅ CHANNEL 2: CHATS (Default Sound)
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel', // ID
      'New Messages', // Name
      description: 'Channel for chat messages',
      importance: Importance.high,
      playSound: true,
    );

    // Create Channels
    var platform = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await platform?.createNotificationChannel(callChannel);
    await platform?.createNotificationChannel(chatChannel);

    // ==================================================
    // 🔥 NEW: Handle Background & Terminated Clicks
    // ==================================================

    // 1. App in Background -> Notification Clicked
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Background Notification Clicked!");
      onNotificationClick(jsonEncode(message.data));
    });

    // 2. App Terminated -> Notification Clicked (Cold Start)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("Terminated Notification Clicked!");
        onNotificationClick(jsonEncode(message.data));
      }
    });

    // ==================================================
    // ✅ Foreground Listener (Show Local Notification)
    // ==================================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String? senderId = message.data['senderId'];
      String? type = message.data['type']; // 'call' or 'chat'

      // 🔇 MUTE LOGIC: If chat is open, don't show notification
      if (currentChatId != null &&
          (currentChatId == senderId || currentChatId == message.data['id'])) {
        print("🔕 Chat is open, muting notification.");
        return;
      }

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // Decide which channel to use
        String channelId = type == 'call' ? 'call_channel' : 'chat_channel';

        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              type == 'call' ? 'Incoming Calls' : 'New Messages',
              channelDescription: 'Notifications for $type',
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
              // Only play ringtone if it's a call
              sound: type == 'call'
                  ? const RawResourceAndroidNotificationSound('ringtone')
                  : null,
              ongoing: type == 'call', // Keeps call notification persistent until answered
              autoCancel: type != 'call',
            ),
          ),
          payload: jsonEncode(message.data), // Pass data for click handling
        );
      }
    });
  }

  // 🔥 2. Save Token (Same logic)
  static Future<void> saveUserToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && uid != null) {
        print("🔥 FCM Token Saved: ${token.substring(0, 10)}...");
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      print("Error saving token: $e");
    }
  }

  // 🔥 3. Get Access Token (Google Auth) - UPDATED WITH SAFETY
  static Future<String?> getAccessToken() async {
    try {
      final String response =
      await rootBundle.loadString('assets/service_account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(response);

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);

      return authClient.credentials.accessToken.data;
    } catch (e) {
      print("❌ Error getting Access Token: $e");
      print("👉 Check if 'assets/service_account.json' exists and is in pubspec.yaml");
      return null;
    }
  }

  // 🔥 4. Send Notification (Updated for Debugging)
  static Future<void> sendNotification({
    required String receiverToken,
    required String title,
    required String body,
    required String type, // 'call' or 'chat'
    required String senderId,
  }) async {
    try {
      final String? accessToken = await getAccessToken();

      if (accessToken == null) {
        print("❌ Notification Failed: Access Token is null.");
        return;
      }

      final String endpoint =
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      // Select Channel based on Type
      String channelId = type == 'call' ? 'call_channel' : 'chat_channel';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': receiverToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': senderId,
              'status': 'done',
              'type': type,
              'senderId': senderId,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'channel_id': channelId,
                'sound': type == 'call' ? 'ringtone' : 'default',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Notification Sent Successfully ($type)");
      } else {
        // 🔥 DEBUGGING INFO: AGAR FAIL HUA TOH YE PRINT HOGA
        print("❌ Notification Failed: ${response.statusCode}");
        print("❌ Response Body: ${response.body}");
      }
    } catch (e) {
      print("❌ Exception sending notification: $e");
    }
  }
}