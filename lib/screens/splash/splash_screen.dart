import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // For ImageFilter

// ✅ Imports wahi hain (Don't change)
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 🎬 Setup Animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();
    _decideRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🧠 LOGIC: 100% SAME AS BEFORE
  Future<void> _decideRoute() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _navTo(const LoginScreen());
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = doc.data();

      bool isProfileReady = data != null &&
          (data['profileCompleted'] == true ||
              (data['firstName'] != null && data['firstName'].toString().isNotEmpty));

      if (isProfileReady) {
        _navTo(const HomeScreen());
      } else {
        _navTo(const ProfileSetupScreen());
      }
    } catch (e) {
      debugPrint("Splash Error: $e");
      _navTo(const LoginScreen());
    }
  }

  void _navTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // ⚪ Light Premium Background
      body: Stack(
        children: [
          // 🌌 Background Glow Effect (Soft Pastel Blobs)
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF42D5A4).withOpacity(0.15), // Mint Green
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF58C7F3).withOpacity(0.15), // Aqua Blue
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9C6BFF).withOpacity(0.1), // Soft Purple
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // 🎯 Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // 💎 LOGO ANIMATION (Modern Light Theme)
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF42D5A4), Color(0xFF0ACF83)], // Vibrant Green Gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0ACF83).withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 10,
                          offset: Offset(-5, -5), // Inner light reflection effect
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded, // Rounded for softer look
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // 🔡 TEXT ANIMATION (Clean Typography)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Gradient Text using ShaderMask
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF101010), Color(0xFF454545)], // Dark Grey Gradient
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          "VERTEX",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white, // Required for ShaderMask to apply colors
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "The Future of Chat",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),

                // ⏳ Loader (Updated Color)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0ACF83)), // Accent Green
                      strokeWidth: 3,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}