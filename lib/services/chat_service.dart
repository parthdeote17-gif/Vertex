import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔹 Helper: 1-on-1 Chat ID Generator
  String getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join("_");
  }



  //  EDIT MESSAGE
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true, // UI mein "(edited)" dikhane ke liye
    });
  }

  //  ADD REACTION
  Future<void> addMessageReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final myId = _auth.currentUser!.uid;
    await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId)
        .set({
      'reactions': {myId: emoji}
    }, SetOptions(merge: true));
  }

  //  REMOVE REACTION
  Future<void> removeMessageReaction({
    required String chatId,
    required String messageId,
  }) async {
    final myId = _auth.currentUser!.uid;
    await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId)
        .update({
      'reactions.$myId': FieldValue.delete(),
    });
  }

  // DELETE MESSAGE (FOR EVERYONE)
  Future<void> deleteMessageForEveryone(String chatId, String messageId) async {
    await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId)
        .update({
      'text': '🚫 This message was deleted',
      'type': 'deleted', // Custom UI handle karne ke liye
      'imageUrl': null,
      'videoUrl': null,
      'reactions': {}, // Reactions bhi clear kar do
    });
  }

  //  DELETE FULL CHAT (Clear All Messages)
  Future<void> deleteFullChat(String chatId) async {
    final messages = await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .get();

    WriteBatch batch = _db.batch();

    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Reset Chat Metadata
    batch.update(_db.collection("chats").doc(chatId), {
      'lastMessage': '',
      'lastSenderId': '',
    });

    await batch.commit();
  }


  // ==========================================
  // 📨 MESSAGING LOGIC (UPDATED WITH STRICT NOTIFICATION)
  // ==========================================

  // SEND MESSAGE
  Future<void> sendMessage({
    required String receiverId,
    required String text,
    String? imageUrl,
    String type = 'text',
    bool isGroup = false,
    Map<String, dynamic>? replyTo,
  }) async {
    final senderId = _auth.currentUser!.uid;
    final timestamp = FieldValue.serverTimestamp();

    // 1. Chat ID Decide
    String chatId = isGroup ? receiverId : getChatId(senderId, receiverId);

    // 2. References
    final chatRef = _db.collection("chats").doc(chatId);
    final msgRef = chatRef.collection("messages").doc();
    final String messageId = msgRef.id;

    await _db.runTransaction((tx) async {
      // A. Message Save
      tx.set(msgRef, {
        "id": messageId,
        "senderId": senderId,
        "receiverId": receiverId,
        "text": text,
        "imageUrl": imageUrl,
        "type": type,
        "timestamp": timestamp,
        "reactions": {},
        "replyTo": replyTo,
        "isRead": false,
        "isEdited": false,
      });

      // B. Chat List Metadata Update
      String listDisplayMessage = text;
      if (type == 'image') {
        listDisplayMessage = "📷 Photo";
      } else if (type == 'video') {
        listDisplayMessage = "🎥 Video";
      }

      Map<String, dynamic> updateData = {
        "lastMessage": listDisplayMessage,
        "lastSenderId": senderId,
        "lastTime": timestamp,
        "isRead": false,
      };

      if (!isGroup) {
        updateData["users"] = [senderId, receiverId];
      }

      tx.set(chatRef, updateData, SetOptions(merge: true));
    });

    //
    try {
      String msgBody = text;
      if (type == 'image') msgBody = "📷 Sent a photo";
      else if (type == 'video') msgBody = "🎥 Sent a video";

      // Sender ka naam fetch kar lo
      var myDoc = await _db.collection('users').doc(senderId).get();
      String myName = myDoc.data()?['firstName'] ?? 'User';

      if (isGroup) {
        // ✅ CASE 1: GROUP MESSAGE
        // Sabse pehle uss SPECIFIC GROUP ka document kholo
        var groupDoc = await _db.collection('chats').doc(chatId).get(); // chatId = groupId here

        if (groupDoc.exists) {
          // Sirf iss group ke 'users' array ko nikalo
          List<dynamic> groupMembers = groupDoc.data()?['users'] ?? [];
          String groupName = groupDoc.data()?['groupName'] ?? 'Group Message';

          // Loop sirf inhi members par chalega
          for (String uid in groupMembers) {
            // Khud ko notification mat bhejo
            if (uid == senderId) continue;

            // Member ka token nikalo
            var memberDoc = await _db.collection('users').doc(uid).get();
            String? token = memberDoc.data()?['fcmToken'];

            if (token != null) {
              await NotificationService.sendNotification(
                receiverToken: token,
                title: groupName, // Notification Title = Group Name
                body: '$myName: $msgBody', // Body = Rahul: Hello
                type: 'chat',
                senderId: chatId, // Click karne par group khulega
              );
            }
          }
        }
      } else {
        // ✅ CASE 2: 1-to-1 MESSAGE
        var userDoc = await _db.collection('users').doc(receiverId).get();
        String? token = userDoc.data()?['fcmToken'];

        if (token != null) {
          await NotificationService.sendNotification(
            receiverToken: token,
            title: myName,
            body: msgBody,
            type: 'chat',
            senderId: senderId,
          );
        }
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  // 📥 GET MESSAGES STREAM
  Stream<QuerySnapshot> getMessages(String receiverId, {bool isGroup = false}) {
    final myId = _auth.currentUser!.uid;
    String chatId = isGroup ? receiverId : getChatId(myId, receiverId);

    return _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // 👀 MARK READ
  Future<void> markChatAsRead(String receiverId, {bool isGroup = false}) async {
    final senderId = _auth.currentUser!.uid;
    String chatId = isGroup ? receiverId : getChatId(senderId, receiverId);

    // 1. Chat List Metadata Update
    final doc = await _db.collection("chats").doc(chatId).get();
    if (doc.exists && doc['lastSenderId'] != senderId) {
      await _db.collection("chats").doc(chatId).update({'isRead': true});
    }

    // 2. Blue Ticks Update (Only for 1-to-1)
    if (!isGroup) {
      final unreadMessagesQuery = await _db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .where('receiverId', isEqualTo: senderId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessagesQuery.docs.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (var doc in unreadMessagesQuery.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    }
  }

  // ==========================================
  // 👥 GROUP MANAGEMENT (Unchanged)
  // ==========================================

  Future<void> createGroup(String groupName, List<String> userIds) async {
    final myUid = _auth.currentUser!.uid;
    List<String> members = List.from(userIds)..add(myUid);
    await _db.collection('chats').add({
      'groupName': groupName,
      'isGroup': true,
      'users': members,
      'adminId': myUid,
      'lastMessage': 'Group created',
      'lastTime': FieldValue.serverTimestamp(),
      'lastSenderId': myUid,
      'isRead': true,
      'photoUrl': null,
    });
  }

  Future<void> updateGroupProfile(String groupId, String photoUrl) async {
    await _db.collection('chats').doc(groupId).update({'photoUrl': photoUrl});
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    await _db.collection('chats').doc(groupId).update({'groupName': newName});
  }

  Future<void> changeGroupAdmin(String groupId, String newAdminId) async {
    await _db.collection('chats').doc(groupId).update({'adminId': newAdminId});
  }

  Future<void> addMemberToGroup(String groupId, String newMemberId) async {
    await _db.collection('chats').doc(groupId).update({'users': FieldValue.arrayUnion([newMemberId])});
  }

  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    await _db.collection('chats').doc(groupId).update({'users': FieldValue.arrayRemove([memberId])});
  }

  Future<void> leaveGroup(String groupId) async {
    final myUid = _auth.currentUser!.uid;
    await _db.collection('chats').doc(groupId).update({'users': FieldValue.arrayRemove([myUid])});
  }
}