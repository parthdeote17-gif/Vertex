import 'dart:developer'; // Logs ke liye
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 📞 MAKE CALL (FIXED VERSION)
  Future<String?> makeCall({
    required String callerId,
    required String callerName,
    required String callerPic,
    required String receiverId,
    required String receiverName,
    required String receiverPic,
    required bool isVideo,
    required bool isGroup,
  }) async {
    try {
      print("🔵 [CallService] Starting Call Process...");

      // 1. Validation
      if (callerId.isEmpty || receiverId.isEmpty) {
        print("❌ [CallService] Failed: CallerId or ReceiverId is empty");
        return null;
      }

      //  FIX 1: Har baar Unique ID generate karo (Chahe Group ho ya nahi)
      // Pehle ye 'receiverId' use kar raha tha group ke liye, jo galat tha.
      String callId = const Uuid().v1();

      List<String> receiverIds = [];

      // 2. Fetch Receivers
      if (isGroup) {
        print("🔵 [CallService] Fetching Group Members for $receiverId");
        var groupDoc = await _firestore.collection('chats').doc(receiverId).get();

        if (groupDoc.exists) {
          List<dynamic> members = groupDoc.data()?['users'] ?? [];
          receiverIds = List<String>.from(members);
          receiverIds.remove(callerId); // Khud ko hatao
          print("✅ [CallService] Found ${receiverIds.length} group members.");
        } else {
          print("❌ [CallService] Group document does not exist!");
          return null;
        }
      } else {
        receiverIds = [receiverId];
        print("✅ [CallService] 1-to-1 Call to: $receiverId");
      }

      if (receiverIds.isEmpty) {
        print("❌ [CallService] No receivers found. Aborting.");
        return null;
      }

      // 3. Prepare Data
      Map<String, dynamic> callData = {
        'id': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerPic': callerPic,
        'receiverName': receiverName,
        'receiverPic': receiverPic,
        'channelId': callId, // Channel ID bhi unique hoga
        'type': isVideo ? 'video' : 'audio',
        'status': 'dialing',
        'receiverIds': receiverIds,
        'receiverId': isGroup ? '' : receiverId,
        'groupId': isGroup ? receiverId : null, // 🔥 Group ID reference ke liye save kiya
        'isGroup': isGroup,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 4. Save to Firestore
      print("🔵 [CallService] Writing to Firestore...");
      await _firestore.collection('calls').doc(callId).set(callData);
      print("✅ [CallService] Document Written! Call ID: $callId");

      // 5. Send Notification
      print("🔵 [CallService] Sending Notifications...");
      await _sendCallNotifications(
        receiverIds: receiverIds,
        callerName: callerName,
        callId: callId, // 🔥 FIX 2: Yahan Call ID pass kar rahe hain
        isVideo: isVideo,
        isGroup: isGroup,
        groupName: isGroup ? receiverName : null,
      );

      return callId;

    } catch (e) {
      print("❌ [CallService] CRITICAL ERROR: $e");
      return null;
    }
  }

  // ✅ ANSWER CALL
  Future<void> answerCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'accepted',
      });
      print("✅ [CallService] Call Answered");
    } catch (e) {
      print("❌ [CallService] Error answering: $e");
    }
  }

  // ❌ END CALL
  Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await _firestore.collection('calls').doc(callId).delete();
      print("✅ [CallService] Call Ended");
    } catch (e) {
      print("❌ [CallService] Error ending: $e");
    }
  }

  // 🔔 NOTIFICATION SENDER (FIXED)
  Future<void> _sendCallNotifications({
    required List<String> receiverIds,
    required String callerName,
    required String callId, // 🔥 Changed from callerId to callId
    required bool isVideo,
    required bool isGroup,
    String? groupName,
  }) async {

    String title = isGroup
        ? '$groupName'
        : 'Incoming ${isVideo ? "Video" : "Audio"} Call';

    String body = isGroup
        ? '$callerName started a group call'
        : '$callerName is calling you...';

    for (String uid in receiverIds) {
      try {
        // Fetch User Token
        var userDoc = await _firestore.collection('users').doc(uid).get();

        if (!userDoc.exists) {
          print("⚠️ [CallService] User $uid not found in DB");
          continue;
        }

        String? token = userDoc.data()?['fcmToken'];

        if (token != null && token.isNotEmpty) {
          print("🚀 [CallService] Sending push to $uid (Token found)");

          await NotificationService.sendNotification(
            receiverToken: token,
            title: title,
            body: body,
            type: 'call',
            senderId: callId, // 🔥 FIX: Call ID bhejo taaki receiver sahi document open kare
          );
        } else {
          print("⚠️ [CallService] No Token found for user $uid");
        }
      } catch (e) {
        print("❌ [CallService] Notification Failed for $uid: $e");
      }
    }
  }
}