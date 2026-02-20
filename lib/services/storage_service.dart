import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 📤 1. Upload Image (Same as before)
  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = "img_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final path = 'images/$fileName';

      await _supabase.storage.from('chat-media').upload(
        path,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return _supabase.storage.from('chat-media').getPublicUrl(path);
    } catch (e) {
      print("❌ Error uploading image: $e");
      return null;
    }
  }

  // 🎥 2. Upload Video (Same as before)
  Future<String?> uploadVideo(File videoFile) async {
    try {
      final fileName = "vid_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final path = 'videos/$fileName';

      await _supabase.storage.from('chat-media').upload(
        path,
        videoFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return _supabase.storage.from('chat-media').getPublicUrl(path);
    } catch (e) {
      print("❌ Error uploading video: $e");
      return null;
    }
  }

  // 👤 3. UPDATE: Upload/Update Profile Image
  // 🔥 FIX: cacheControl '0' kar diya taaki nayi photo turant dikhe (No Cache)
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    try {
      final path = 'profiles/$uid.jpg';

      await _supabase.storage.from('chat-media').upload(
        path,
        imageFile,
        // cacheControl: '0' is important for profile pics that overwrite!
        fileOptions: const FileOptions(cacheControl: '0', upsert: true),
      );

      return _supabase.storage.from('chat-media').getPublicUrl(path);
    } catch (e) {
      print("❌ Error uploading profile image: $e");
      return null;
    }
  }

  // 🗑️ 4. Delete File (Same as before)
  Future<void> deleteFile(String path) async {
    try {
      await _supabase.storage.from('chat-media').remove([path]);
      print("✅ File deleted successfully: $path");
    } catch (e) {
      print("❌ Error deleting file: $e");
    }
  }
}