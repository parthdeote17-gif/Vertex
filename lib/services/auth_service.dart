import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? _verificationId;

  // 🔥 Helper Getter
  User? get currentUser => _auth.currentUser;

  // 🔥 NEW: Update User Presence (Online/Offline) - [Fixed Error]
  Future<void> updateUserPresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error updating presence: $e");
      }
    }
  }

  /* ================= EMAIL ================= */

  Future<User?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Login successful, mark online
    await updateUserPresence(true);

    // Save/Check user doc (Optional if already exists, but safe to keep)
    await _saveUser(result.user!, provider: "email");
    return result.user;
  }

  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _saveUser(result.user!, provider: "email");
    return result.user;
  }

  /* ================= GOOGLE ================= */

  Future<User?> signInWithGoogle() async {
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);

    // 🔥 GOOGLE NAME SAFE SAVE
    await _saveUser(
      result.user!,
      provider: "google",
      googleName: result.user!.displayName,
    );

    return result.user;
  }

  /* ================= PHONE OTP ================= */

  Future<void> sendOTP(String phone) async {
    _verificationId = null;

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (credential) async {
        final result = await _auth.signInWithCredential(credential);
        await _saveUser(result.user!, provider: "phone");
      },

      verificationFailed: (e) {
        throw e.message ?? "OTP verification failed";
      },

      codeSent: (verificationId, _) {
        _verificationId = verificationId;
      },

      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<User?> verifyOTP(String otp) async {
    if (_verificationId == null) {
      throw "OTP not sent yet";
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    final result = await _auth.signInWithCredential(credential);
    await _saveUser(result.user!, provider: "phone");
    return result.user;
  }

  /* ================= SAVE USER (FINAL LOGIC) ================= */

  Future<void> _saveUser(
      User user, {
        required String provider,
        String? googleName,
      }) async {
    final docRef = _db.collection("users").doc(user.uid);
    final doc = await docRef.get();

    // 🧠 USER ALREADY EXISTS → Just ensure they are Online
    if (doc.exists) {
      await updateUserPresence(true);
      return;
    }

    String? firstName;
    String? lastName;

    // ✅ GOOGLE LOGIN → AUTO NAME
    if (provider == "google" && googleName != null) {
      final parts = googleName.trim().split(" ");
      firstName = parts.first;
      lastName = parts.length > 1 ? parts.sublist(1).join(" ") : "";
    }

    await docRef.set({
      "uid": user.uid,
      "firstName": firstName,
      "lastName": lastName,
      "email": user.email,
      "phone": user.phoneNumber,
      "photoUrl": user.photoURL,
      "provider": provider,
      "createdAt": FieldValue.serverTimestamp(),

      // 🔥 NEW FIELDS FOR PRESENCE
      "isOnline": true,
      "lastSeen": FieldValue.serverTimestamp(),
    });
  }

  /* ================= LOGOUT ================= */

  Future<void> logout() async {
    // 🔥 1. Mark Offline BEFORE signing out
    await updateUserPresence(false);

    final user = _auth.currentUser;

    if (user != null) {
      final isGoogle =
      user.providerData.any((p) => p.providerId == 'google.com');

      if (isGoogle) {
        try {
          await _googleSignIn.disconnect();
          await _googleSignIn.signOut();
        } catch (_) {}
      }
    }

    await _auth.signOut();
  }
}