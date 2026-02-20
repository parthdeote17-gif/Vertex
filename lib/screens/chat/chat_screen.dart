import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Service Imports
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../services/call_service.dart';
import '../../services/notification_service.dart';

// Widget Imports
import '../../widgets/message_bubble.dart';
import '../group/group_info_screen.dart';
import '../call/call_screen.dart';
import '../call/audio_call_screen.dart';
import '../users/users_list_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Services
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  final CallService _callService = CallService();
  final ImagePicker _picker = ImagePicker();
  final User currentUser = FirebaseAuth.instance.currentUser!;
  final ScrollController _scrollController = ScrollController();

  // State Variables
  late Stream<QuerySnapshot> _messageStream;
  Map<String, dynamic>? _replyMessage;
  bool _isUploading = false;
  bool _showSendButton = false;

  // Colors & Design
  final Color _primaryColor = const Color(0xFF008069);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _surfaceColor = Colors.white;
  final Color _subtitleColor = const Color(0xFF667781);
  final Color _textColor = const Color(0xFF111B21);

  @override
  void initState() {
    super.initState();
    _markRead();
    NotificationService.currentChatId = widget.receiverId;
    _messageStream = _chatService.getMessages(widget.receiverId, isGroup: widget.isGroup);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  @override
  void dispose() {
    NotificationService.currentChatId = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels == 0) {
        // Reached top logic if needed
      }
    }
  }

  void _markRead() {
    _chatService.markChatAsRead(widget.receiverId, isGroup: widget.isGroup);
  }

  String get _chatId {
    if (widget.isGroup) return widget.receiverId;
    return _chatService.getChatId(currentUser.uid, widget.receiverId);
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    return DateFormat('hh:mm a').format(timestamp.toDate()).toLowerCase();
  }

  // 🔥 MODERNIZED: MESSAGE INFO DIALOG
  void _showMessageInfo(Map<String, dynamic> data) {
    Timestamp? timestamp = data['timestamp'];
    bool isRead = data['isRead'] ?? false;
    String sentTime = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
        : "Unknown";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: _surfaceColor,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "Message Info",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.access_time_rounded,
                      title: "Sent at",
                      value: sentTime,
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: Icons.done_all_rounded,
                      title: "Status",
                      value: isRead ? "Read" : "Delivered",
                      valueColor: isRead ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String title, required String value, Color valueColor = Colors.black87}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- LOGIC FUNCTIONS (Forward, Edit, Send, Pick) ---

  void _forwardMessage(String content, String type, String? url) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersListScreen(isSelectionMode: true)),
    );

    if (result != null && result is Map<String, dynamic>) {
      await _chatService.sendMessage(
        receiverId: result['id'],
        text: content,
        imageUrl: url,
        type: type,
        isGroup: result['isGroup'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Forwarded to ${result['name']}"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _editMessageDialog(String messageId, String currentText) {
    TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit Message",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: editController,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _subtitleColor,
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (editController.text.trim().isNotEmpty) {
                        _chatService.editMessage(_chatId, messageId, editController.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final replyContext = _replyMessage;
    setState(() {
      _showSendButton = false;
      _replyMessage = null;
    });

    try {
      await _chatService.sendMessage(
          receiverId: widget.receiverId,
          text: text,
          type: 'text',
          isGroup: widget.isGroup,
          replyTo: replyContext
      );
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      XFile? pickedFile;
      if (isVideo) {
        pickedFile = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2));
      } else {
        pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      }

      if (pickedFile == null) return;

      setState(() => _isUploading = true);
      File file = File(pickedFile.path);
      String? mediaUrl;

      if (isVideo) {
        mediaUrl = await _storageService.uploadVideo(file);
      } else {
        mediaUrl = await _storageService.uploadImage(file);
      }

      if (mediaUrl != null) {
        await _chatService.sendMessage(
            receiverId: widget.receiverId,
            text: "",
            imageUrl: mediaUrl,
            type: isVideo ? 'video' : 'image',
            isGroup: widget.isGroup
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload Failed: $e"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- MODERNIZED MESSAGE OPTIONS ---
  void _showMessageOptions(Map<String, dynamic> data) {
    String messageId = data['id'];
    String type = data['type'] ?? 'text';
    String text = data['text'] ?? '';
    String? url = data['imageUrl'];
    bool isMe = data['senderId'] == currentUser.uid;
    Map<String, dynamic> reactions = data['reactions'] != null ? Map<String, dynamic>.from(data['reactions']) : {};

    if (type == 'deleted') return;
    String? myReaction = reactions[currentUser.uid];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.only(top: 20, left: 15, right: 15, bottom: 30),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Reactions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) {
                bool isSelected = myReaction == emoji;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (isSelected) {
                      _chatService.removeMessageReaction(chatId: _chatId, messageId: messageId);
                    } else {
                      _chatService.addMessageReaction(chatId: _chatId, messageId: messageId, emoji: emoji);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Options List
            Column(
              children: [
                _optionTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: _primaryColor,
                  title: "Info",
                  onTap: () {
                    Navigator.pop(context);
                    _showMessageInfo(data);
                  },
                ),
                _optionTile(
                  icon: Icons.forward_rounded,
                  iconColor: Colors.blue,
                  title: "Forward",
                  onTap: () {
                    Navigator.pop(context);
                    _forwardMessage(text, type, url);
                  },
                ),
                if (isMe && type == 'text')
                  _optionTile(
                    icon: Icons.edit_rounded,
                    iconColor: Colors.black87,
                    title: "Edit",
                    onTap: () {
                      Navigator.pop(context);
                      _editMessageDialog(messageId, text);
                    },
                  ),
                if (isMe) ...[
                  const Divider(height: 1, indent: 50),
                  _optionTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red,
                    title: "Delete for everyone",
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteMessage(messageId);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: title.contains("Delete") ? Colors.red : _textColor,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                "Delete Message?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete this message for everyone?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _subtitleColor,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _chatService.deleteMessageForEveryone(_chatId, messageId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                "Clear Chat?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "This will delete all messages for everyone.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _subtitleColor,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _chatService.deleteFullChat(_chatId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Clear All"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODERNIZED ATTACHMENT SHEET ---
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        margin: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(
                  Icons.image_rounded,
                  Colors.purple,
                  "Gallery",
                      () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery, isVideo: false);
                  },
                ),
                _attachOption(
                  Icons.videocam_rounded,
                  Colors.red,
                  "Video",
                      () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery, isVideo: true);
                  },
                ),
                _attachOption(
                  Icons.camera_alt_rounded,
                  Colors.pink,
                  "Camera",
                      () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.camera, isVideo: false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, Color color, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile() {
    if (widget.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupInfoScreen(
            groupId: widget.receiverId,
            groupName: widget.receiverName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiverProfileScreen(
            uid: widget.receiverId,
            name: widget.receiverName,
          ),
        ),
      );
    }
  }

  // ✅ UPDATED CALL INITIATION (Matches new CallService)
  void _initCall(bool isVideo) async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      // ✅ FIX: String? callId
      String? callId = await _callService.makeCall(
        callerId: currentUser.uid,
        callerName: userDoc['firstName'] ?? 'User',
        callerPic: userDoc['photoUrl'] ?? '',
        receiverId: widget.receiverId,
        receiverName: widget.receiverName,
        receiverPic: '',
        isVideo: isVideo,
        isGroup: widget.isGroup,
      );

      // ✅ FIX: Null Check + Mounted Check
      if (callId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isVideo
                ? CallScreen(channelId: callId, isGroup: widget.isGroup)
                : AudioCallScreen(channelId: callId, receiverName: widget.receiverName, receiverPhoto: null),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not connect call. Please try again."))
        );
      }
    } catch (e) {
      print(e);
    }
  }

  // --- MODERNIZED BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) => _markRead(),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // 1. MODERNIZED AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surfaceColor,
      foregroundColor: _textColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      leadingWidth: 80,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: () {
            _markRead();
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _backgroundColor,
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.arrow_back_rounded, color: _textColor, size: 24),
                const SizedBox(width: 4),
                Hero(
                  tag: widget.receiverId,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: widget.isGroup
                          ? StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('chats').doc(widget.receiverId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            var data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null && data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
                              return Image.network(
                                data['photoUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _primaryColor.withOpacity(0.1),
                                  child: Icon(Icons.groups_rounded, color: _primaryColor, size: 20),
                                ),
                              );
                            }
                          }
                          return Container(
                            color: _primaryColor.withOpacity(0.1),
                            child: Icon(Icons.groups_rounded, color: _primaryColor, size: 20),
                          );
                        },
                      )
                          : StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null && data['photoUrl'] != null) {
                              return Image.network(
                                data['photoUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                              );
                            }
                          }
                          return _buildDefaultAvatar();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: InkWell(
        onTap: _openProfile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (!widget.isGroup)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    bool isOnline = data['isOnline'] ?? false;
                    return Text(
                      isOnline ? "Online" : "Last seen recently",
                      style: TextStyle(
                        color: isOnline ? _primaryColor : _subtitleColor,
                        fontSize: 12,
                        fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              )
            else
              Text(
                _isUploading ? "Sending..." : "Group • ${widget.receiverName.split(' ').length} members",
                style: TextStyle(
                  color: _subtitleColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor,
            ),
            child: Icon(Icons.videocam_rounded, color: _primaryColor, size: 22),
          ),
          onPressed: () => _initCall(true),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor,
            ),
            child: Icon(Icons.call_rounded, color: _primaryColor, size: 22),
          ),
          onPressed: () => _initCall(false),
        ),
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor,
            ),
            child: Icon(Icons.more_vert_rounded, color: _textColor, size: 22),
          ),
          color: _surfaceColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'view') _openProfile();
            if (value == 'clear') _clearChat();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.person_rounded, color: _textColor, size: 20),
                  const SizedBox(width: 12),
                  const Text("View Contact"),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    "Clear Chat",
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: _primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.person_rounded,
        color: _primaryColor,
        size: 20,
      ),
    );
  }

  // 2. MODERNIZED Message List
  Widget _buildMessageList() {
    return RepaintBoundary(
      child: StreamBuilder<QuerySnapshot>(
        stream: _messageStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
            );
          }
          final docs = snapshot.data!.docs;

          return ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            reverse: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isMe = data['senderId'] == currentUser.uid;
              bool isDeleted = data['type'] == 'deleted';

              Map<String, dynamic> reactions = data['reactions'] != null
                  ? Map<String, dynamic>.from(data['reactions'])
                  : {};
              List<String> reactionEmojis = reactions.values
                  .map((e) => e.toString())
                  .toSet()
                  .take(3)
                  .toList();
              bool hasReactions = reactionEmojis.isNotEmpty && !isDeleted;

              return Dismissible(
                key: Key(data['id']),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (direction) async {
                  setState(() {
                    _replyMessage = {
                      'id': data['id'],
                      'text': data['type'] == 'text' ? data['text'] : '📷 Media',
                      'senderName': isMe ? "You" : (widget.isGroup ? "Member" : widget.receiverName),
                    };
                  });
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.reply_rounded, color: _primaryColor, size: 20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 🔥 MODIFIED: Dynamic Group Sender Name
                    if (widget.isGroup && !isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4, top: 8),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['senderId'])
                              .snapshots(),
                          builder: (context, snapshot) {
                            String displayName = "Member";
                            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                              final userData = snapshot.data!.data() as Map<String, dynamic>;
                              // Fetch First Name
                              displayName = userData['firstName'] ?? "Member";
                            }

                            return Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600, // Semi-bold
                                color: _subtitleColor, // Subtle color
                              ),
                            );
                          },
                        ),
                      ),

                    GestureDetector(
                      onLongPress: () => _showMessageOptions(data),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MessageBubble(
                            text: data['text'] ?? '',
                            mediaUrl: data['imageUrl'],
                            type: data['type'] ?? 'text',
                            time: _formatTime(data['timestamp']),
                            isMe: isMe,
                            replyTo: data['replyTo'],
                            isRead: data['isRead'] ?? false,
                            isEdited: data['isEdited'] ?? false,
                          ),
                          if (hasReactions)
                            Positioned(
                              bottom: -16,
                              right: isMe ? 12 : null,
                              left: isMe ? null : 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: reactionEmojis
                                      .map(
                                        (e) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: Text(e, style: const TextStyle(fontSize: 14)),
                                    ),
                                  )
                                      .toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: hasReactions ? 24 : 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 3. MODERNIZED Input Area
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: _primaryColor, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, color: _primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Replying to ${_replyMessage!['senderName']}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyMessage!['text'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _subtitleColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _subtitleColor, size: 20),
                    onPressed: () => setState(() => _replyMessage = null),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {},
                        splashRadius: 20,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: 5,
                          minLines: 1,
                          onChanged: (val) {
                            if (val.trim().isNotEmpty && !_showSendButton) {
                              setState(() => _showSendButton = true);
                            } else if (val.trim().isEmpty && _showSendButton) {
                              setState(() => _showSendButton = false);
                            }
                          },
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: "Message",
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            hintStyle: TextStyle(
                              color: _subtitleColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.attach_file_rounded,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: _showAttachmentSheet,
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 4),
                      if (!_showSendButton)
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => _pickMedia(ImageSource.camera, isVideo: false),
                          splashRadius: 20,
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: _primaryColor,
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(
                      !_showSendButton ? Icons.mic_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ⚠️ FIXED: ReceiverProfileScreen Class with updated Call Logic
class ReceiverProfileScreen extends StatelessWidget {
  final String uid;
  final String name;
  final CallService _callService = CallService();

  ReceiverProfileScreen({super.key, required this.uid, required this.name});

  void _initiateCall(BuildContext context, bool isVideo, String? receiverPic) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting call..."), duration: Duration(seconds: 1)));
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      String myName = userDoc['firstName'] ?? 'User';
      String myPic = userDoc['photoUrl'] ?? '';

      // ✅ FIX: String? callId
      String? callId = await _callService.makeCall(
        callerId: currentUser.uid, callerName: myName, callerPic: myPic, receiverId: uid, receiverName: name, receiverPic: receiverPic ?? '', isVideo: isVideo, isGroup: false,
      );

      // ✅ FIX: Null Check
      if (callId != null && context.mounted) {
        if (isVideo) Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelId: callId)));
        else Navigator.push(context, MaterialPageRoute(builder: (_) => AudioCallScreen(channelId: callId, receiverName: name, receiverPhoto: receiverPic)));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to connect call")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Call Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: const Color(0xFF008069),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, style: const TextStyle(shadows: [Shadow(color: Colors.black45, blurRadius: 5)])),
              background: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final photoUrl = data?['photoUrl'];
                  if (photoUrl != null) return Image.network(photoUrl, fit: BoxFit.cover);
                  return Container(color: Colors.grey[300], child: Icon(Icons.person, size: 120, color: Colors.grey[500]));
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: LinearProgressIndicator(color: Color(0xFF008069)));
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final email = data?['email'] ?? 'No info';
                final photoUrl = data?['photoUrl'];

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildSectionCard([
                        _infoTile(Icons.email_outlined, email, "Email"),
                        const Divider(height: 1, indent: 56),
                        _infoTile(Icons.info_outline_rounded, "Available", "About"),
                      ]),
                      const SizedBox(height: 15),
                      _buildSectionCard([
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _actionButton(Icons.call_rounded, "Audio", Colors.green, () => _initiateCall(context, false, photoUrl)),
                              _actionButton(Icons.videocam_rounded, "Video", Colors.green, () => _initiateCall(context, true, photoUrl)),
                              _actionButton(Icons.search_rounded, "Search", Colors.grey, () {}),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 50),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children));
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return ListTile(leading: Icon(icon, color: Colors.grey[600]), title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])));
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))]));
  }
}