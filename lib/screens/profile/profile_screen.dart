import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/painting.dart';

// Service Imports
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  String? _currentPhotoUrl;

  bool loading = true;
  bool saving = false;
  bool deleting = false;

  final user = FirebaseAuth.instance.currentUser;

  // 🎨 THEME COLORS
  final Color _primaryGreen = const Color(0xFF00C27C);
  final Color _darkGreen = const Color(0xFF008069);
  final Color _surfaceWhite = const Color(0xFFFFFFFF);
  final Color _lightBg = const Color(0xFFF7F8FA);
  final Color _textPrimary = const Color(0xFF1D1E20);
  final Color _textSecondary = const Color(0xFF6B6D72);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();
      final data = doc.data();

      if (data != null) {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        setState(() {
          _currentPhotoUrl = data['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _updateProfilePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() => loading = true);
      File file = File(pickedFile.path);

      String? url = await _storageService.uploadProfileImage(file, user!.uid);

      if (url != null) {
        String newPhotoUrl = "$url?v=${DateTime.now().millisecondsSinceEpoch}";

        try {
          await NetworkImage(newPhotoUrl).evict();
          if (_currentPhotoUrl != null) {
            await NetworkImage(_currentPhotoUrl!).evict();
          }
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (e) {
          debugPrint("Cache clear error: $e");
        }

        await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
          "photoUrl": newPhotoUrl
        });

        setState(() {
          _currentPhotoUrl = newPhotoUrl;
        });

        _snack("Profile photo updated!", success: true);
      }
      setState(() => loading = false);
    }
  }

  Future<void> _deleteProfilePhoto() async {
    if (_currentPhotoUrl == null) return;

    setState(() => loading = true);
    try {
      await _storageService.deleteFile('profiles/${user!.uid}.jpg');

      await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
        "photoUrl": null
      });

      setState(() {
        _currentPhotoUrl = null;
      });
      _snack("Profile photo removed", success: true);
    } catch (e) {
      _snack("Error removing photo");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logOut() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out?"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } catch (e) {
      _snack("Error logging out");
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      _snack("Please enter full name");
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
        "firstName": _firstNameController.text.trim(),
        "lastName": _lastNameController.text.trim(),
      });
      _snack("Profile updated", success: true);
    } catch (e) {
      _snack("Error saving profile");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This action cannot be undone. All your data will be permanently lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;
    setState(() => deleting = true);
    try {
      await FirebaseFirestore.instance.collection("users").doc(user!.uid).delete();
      await user!.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      _snack("Account deleted successfully", success: true);
    } catch (e) {
      setState(() => deleting = false);
      _snack("Error: Something went wrong.");
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? _primaryGreen : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceWhite,
      appBar: AppBar(
        title: Text(
          "Edit Profile",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: _surfaceWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // 📸 AVATAR SECTION
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: _lightBg,
                        backgroundImage: _currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null,
                        child: _currentPhotoUrl == null
                            ? Icon(Icons.person_rounded, size: 65, color: Colors.grey.shade400)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: GestureDetector(
                        onTap: _updateProfilePhoto,
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: _primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: _surfaceWhite, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryGreen.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_currentPhotoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    onPressed: _deleteProfilePhoto,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Remove Photo", style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                )
              else
                const SizedBox(height: 32),

              const SizedBox(height: 20),

              // 📝 INPUT FIELDS
              _buildModernTextField(
                controller: _firstNameController,
                label: "First Name",
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 20),
              _buildModernTextField(
                controller: _lastNameController,
                label: "Last Name",
                icon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 40),

              // 💾 SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: _primaryGreen.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: saving
                      ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Divider(color: const Color(0xFFEDEDED), thickness: 1),
              const SizedBox(height: 32),

              // 🚪 LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _logOut,
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 🗑️ DELETE ACCOUNT
              if (deleting)
                CircularProgressIndicator(color: Colors.red)
              else
                TextButton(
                  onPressed: _deleteAccount,
                  child: const Text(
                    "Delete Account",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ✨ MODERN TEXT FIELD WIDGET
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _lightBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _textSecondary),
          labelText: label,
          labelStyle: TextStyle(color: _textSecondary, fontWeight: FontWeight.w500),
          floatingLabelStyle: TextStyle(color: _darkGreen, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent, // Handled by Container
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}