import 'dart:convert'; // ✅ JSON Decode ke liye
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

// ✅ Screens Imports
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/call/pickup_screen.dart';
import 'screens/chat/chat_screen.dart'; // ✅ Added
import 'screens/call/call_screen.dart'; // ✅ Added
import 'screens/call/audio_call_screen.dart'; // ✅ Added

// ✅ Services Imports
import 'services/notification_service.dart';
import 'services/auth_service.dart';

// 🔥 GLOBAL KEY (Navigation ke liye)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Supabase Init
  await Supabase.initialize(
    url: 'https://qjscjtgelyyzwgyozcmw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqc2NqdGdlbHl5endneW96Y213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1Njg1MjEsImV4cCI6MjA4MjE0NDUyMX0.qcPXnpDuW2lED6RCcbHzZQXJ47Cpp8R0mEpqe7hj7NQ',
  );

  runApp(const VertexApp());
}

class VertexApp extends StatefulWidget {
  const VertexApp({super.key});

  @override
  State<VertexApp> createState() => _VertexAppState();
}

class _VertexAppState extends State<VertexApp> with WidgetsBindingObserver {

  final AuthService _authService = AuthService();
  //  Track processed call ID to prevent duplicate screens
  String? _processedCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    //  FIX: Initialize Notification with Click Handler
    NotificationService.initialize((String payload) {
      try {
        Map<String, dynamic> data = jsonDecode(payload);
        _handleNotificationClick(data);
      } catch (e) {
        print("❌ Error parsing notification payload: $e");
      }
    });

    _saveToken();
    _setupCallListener();
    _setStatus(true);
  }

  // Notification Click Handler Logic
  void _handleNotificationClick(Map<String, dynamic> data) {
    String type = data['type'] ?? 'chat';
    String senderId = data['senderId'];
    String? id = data['id']; // Chat ID or Call ID or Channel ID

    // Check if user is logged in
    if (FirebaseAuth.instance.currentUser == null) return;

    if (type == 'call') {
      // 📞 Video/Audio Call Screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(channelId: id ?? senderId, isGroup: false),
        ),
      );
    } else if (type == 'chat') {
      // 💬 Chat Screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: senderId,
            receiverName: "Chat", // Notification doesn't always carry name, handled in screen
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // LIFECYCLE CHANGE DETECTION
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setStatus(true);
    } else {
      _setStatus(false);
    }
  }

  void _setStatus(bool isOnline) {
    if (FirebaseAuth.instance.currentUser != null) {
      _authService.updateUserPresence(isOnline);
    }
  }

  void _saveToken() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await NotificationService.saveUserToken();
    }
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        NotificationService.saveUserToken();
      }
    });
  }

  //  CALL LISTENER (Same Logic)
  void _setupCallListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) return;

      FirebaseFirestore.instance
          .collection('calls')
          .where('receiverIds', arrayContains: user.uid)
          .where('status', isEqualTo: 'dialing')
          .snapshots()
          .listen((snapshot) {

        if (snapshot.docs.isNotEmpty) {
          var doc = snapshot.docs.first;
          var callData = doc.data();
          String callId = callData['id'];

          //  FIX 1: Time check increased to 30 mins
          if (callData['timestamp'] != null) {
            DateTime callTime = (callData['timestamp'] as Timestamp).toDate();
            if (DateTime.now().difference(callTime).inMinutes > 30) {
              return;
            }
          }

          //  FIX 2: Duplicate Screen Check
          if (_processedCallId == callId) {
            return;
          }

          // Screen Open Karo
          if (navigatorKey.currentState != null) {
            _processedCallId = callId;

            navigatorKey.currentState!.push(
              MaterialPageRoute(builder: (_) => PickupScreen(callData: callData)),
            );
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vertex',
      navigatorKey: navigatorKey, // ✅ Key Assigned
      theme: ThemeData.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData) return const LoginScreen();
          return const SplashScreen();
        },
      ),
    );
  }
}