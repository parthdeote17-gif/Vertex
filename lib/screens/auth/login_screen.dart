import 'package:flutter/material.dart';
import 'package:vertex/services/auth_service.dart';
import 'package:vertex/screens/auth/register_screen.dart';
import 'package:vertex/screens/splash/splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController inputController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final AuthService auth = AuthService();

  bool isPhoneMode = false;
  bool otpSent = false;
  bool loading = false;

  @override
  void dispose() {
    inputController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // 📞 phone detection logic (SAME)
  bool _isPhone(String value) {
    return RegExp(r'^\+?[0-9]{10,13}$').hasMatch(value);
  }

  Future<void> _continue() async {
    final input = inputController.text.trim();

    if (input.isEmpty) {
      _snack("Enter email or phone number");
      return;
    }

    final phoneNow = _isPhone(input);

    if (phoneNow != isPhoneMode) {
      otpSent = false;
      otpController.clear();
      passwordController.clear();
    }

    setState(() {
      isPhoneMode = phoneNow;
      loading = true;
    });

    try {
      if (isPhoneMode) {
        if (!otpSent) {
          await auth.sendOTP(input);
          if (!mounted) return;
          setState(() => otpSent = true);
          _snack("OTP sent", success: true);
        } else {
          if (otpController.text.trim().isEmpty) {
            _snack("Enter OTP");
            return;
          }
          await auth.verifyOTP(otpController.text.trim());
          if (!mounted) return;
          _goNext();
        }
      } else {
        if (passwordController.text.isEmpty) {
          _snack("Enter password");
          return;
        }
        await auth.login(input.toLowerCase(), passwordController.text.trim());
        if (!mounted) return;
        _goNext();
      }
    } catch (e) {
      _snack(_readableError(e.toString()));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => loading = true);
    try {
      await auth.signInWithGoogle();
      if (!mounted) return;
      _goNext();
    } catch (e) {
      _snack(_readableError(e.toString()));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _goNext() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
    );
  }

  String _readableError(String error) {
    if (error.contains("user-not-found")) return "User not found";
    if (error.contains("wrong-password")) return "Wrong password";
    if (error.contains("invalid-verification-code")) return "Invalid OTP";
    if (error.contains("OTP not sent")) return "Please request OTP first";
    return "Something went wrong";
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🟢 Header (Logo/Title)
                const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.black),
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to continue using Vertex",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 40),

                // 🟢 Input Field (Email/Phone)
                _buildTextField(
                  controller: inputController,
                  label: "Email or Phone",
                  icon: Icons.person_outline,
                  inputType: isPhoneMode ? TextInputType.phone : TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // 🟢 Password Field
                if (!isPhoneMode)
                  _buildTextField(
                    controller: passwordController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),

                // 🟢 OTP Field
                if (otpSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildTextField(
                      controller: otpController,
                      label: "Enter OTP Code",
                      icon: Icons.sms_outlined,
                      inputType: TextInputType.number,
                    ),
                  ),

                const SizedBox(height: 24),

                // 🟢 Main Action Button
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: loading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: loading
                        ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                        : Text(
                      otpSent ? "Verify OTP" : "Continue",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 🟢 Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),

                const SizedBox(height: 24),

                // 🟢 Google Button
                SizedBox(
                  height: 55,
                  child: OutlinedButton(
                    onPressed: loading ? null : _googleLogin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Agar assets/images/google.png nahi hai toh temporary Icon use kar sakte ho
                        Image.asset('assets/images/google.png', height: 24, errorBuilder: (c,o,s) => const Icon(Icons.g_mobiledata, size: 30)),
                        const SizedBox(width: 12),
                        const Text("Continue with Google", style: TextStyle(fontSize: 16, color: Colors.black)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 🟢 Footer (Go to Register)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text(
                        "Register",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Clean Inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}