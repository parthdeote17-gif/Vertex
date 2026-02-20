import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// Service Imports
import '../../services/storage_service.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  // 🔥 NEW SERVICES & VARIABLES
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool loading = false;

  // 🎨 UI Colors
  static const Color kBackground = Color(0xFFF7F8FA);
  static const Color kPrimary = Color(0xFF0ACF83);
  static const Color kTextPrimary = Color(0xFF101010);
  static const Color kTextSecondary = Color(0xFF9C9C9C);
  static const Color kCardColor = Colors.white;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  // 📸 PHOTO PICK LOGIC (UNCHANGED)
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // 🧠 LOGIC: UPDATED TO HANDLE PHOTO UPLOAD (UNCHANGED)
  Future<void> _saveProfile() async {
    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty) {
      _snack("Enter full name");
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? photoUrl;

      // 1. Agar photo select ki hai, toh upload karein
      if (_selectedImage != null) {
        photoUrl = await _storageService.uploadProfileImage(_selectedImage!, user.uid);
      }

      final String firstName = firstNameController.text.trim();
      final String lastName = lastNameController.text.trim();

      // 2. Firestore mein data save (Photo URL ke saath)
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "firstName": firstName,
        "lastName": lastName,
        "photoUrl": photoUrl, // Photo link yahan save hoga
        "profileCompleted": true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      // 3. Home Screen par navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
      );
    } catch (e) {
      _snack("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground, // Modern Light Grey Background
      appBar: AppBar(
        title: const Text(
          "Complete Profile",
          style: TextStyle(
              color: kTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5
          ),
        ),
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 👤 AVATAR PICKER UI (Modernized)
              GestureDetector(
                onTap: _pickImage,
                child: Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[100],
                          backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                          child: _selectedImage == null
                              ? Icon(Icons.person_rounded, size: 60, color: Colors.grey[400])
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPrimary, // Green Accent
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              _buildTextField(
                controller: firstNameController,
                label: "First Name",
                icon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: lastNameController,
                label: "Last Name",
                icon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 50),

              // Continue Button (Modern Style)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: kPrimary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: loading
                      ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                  )
                      : const Text(
                      "Continue",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "Your profile information helps others\nrecognize you on Vertex.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextSecondary.withOpacity(0.8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 Helper Widget for Inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: kTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: kTextSecondary),
          ),
          labelText: label,
          labelStyle: const TextStyle(color: kTextSecondary, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          floatingLabelStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}