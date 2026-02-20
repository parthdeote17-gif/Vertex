import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

//  IMPORTS
import '../../services/call_service.dart';
import '../call/call_screen.dart';
import '../call/audio_call_screen.dart';
import '../chat/chat_screen.dart';
import '../group/create_group_screen.dart';
import '../profile/profile_screen.dart';
import '../group/group_info_screen.dart';

class UsersListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const UsersListScreen({super.key, this.isSelectionMode = false});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final CallService _callService = CallService();

  String _searchQuery = "";
  String _selectedFilter = "All";

  //  Cached Data for Optimization
  Map<String, dynamic>? _myCachedData;

  @override
  void initState() {
    super.initState();
    _preloadMyData();
  }

  void _preloadMyData() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (mounted) {
          setState(() {
            _myCachedData = doc.data();
          });
        }
      } catch (e) {
        print("Error preloading user data: $e");
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return DateFormat('hh:mm a').format(date);
    }
    return DateFormat('MM/dd').format(date);
  }

  //  OPTIMIZED CALL FUNCTION (Fixed for Nullable String)
  Future<void> _initiateCall({
    required String receiverId,
    required String receiverName,
    required String receiverPic,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw "User not logged in";

      String myName = _myCachedData?['firstName'] ?? 'User';
      String myPic = _myCachedData?['photoUrl'] ?? '';

      // Fallback if cache is empty
      if (_myCachedData == null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        var data = userDoc.data();
        myName = data?['firstName'] ?? 'User';
        myPic = data?['photoUrl'] ?? '';
        _myCachedData = data;
      }

      //  FIX: Handle Nullable String (String?)
      String? callId = await _callService.makeCall(
        callerId: currentUser.uid,
        callerName: myName,
        callerPic: myPic,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPic: receiverPic,
        isVideo: isVideo,
        isGroup: false,
      );

      //  FIX: Check if callId is not null before navigating
      if (callId != null && mounted) {
        if (isVideo) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(channelId: callId, isGroup: false)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AudioCallScreen(channelId: callId, receiverName: receiverName, receiverPhoto: receiverPic)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Unable to connect call. Please try again."))
        );
      }
    } catch (e) {
      print("❌ Call Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection failed. Try again.")));
      }
    }
  }

  // ... (Rest of UI Logic remains EXACTLY same to preserve your design) ...

  // 1. SHOW USER OPTIONS
  void _showUserOptions(String uid, String name, String? photoUrl) {
    if (widget.isSelectionMode) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: const Color(0xFFE9F5EA),
                      child: photoUrl == null
                          ? Icon(Icons.person, size: 32, color: const Color(0xFF008069).withOpacity(0.7))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey.shade300,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _optionItem(
                Icons.account_circle_outlined,
                "View Profile",
                    () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiverProfileScreen(uid: uid, name: name)));
                },
                iconColor: const Color(0xFF008069),
              ),
              _optionItem(
                Icons.chat_bubble_outline_rounded,
                "Message",
                    () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: uid, receiverName: name)));
                },
                iconColor: const Color(0xFF25D366),
              ),
              _optionItem(
                Icons.call_rounded,
                "Audio Call",
                    () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Calling $name..."),
                      duration: const Duration(milliseconds: 800),
                      backgroundColor: const Color(0xFF008069),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  _initiateCall(receiverId: uid, receiverName: name, receiverPic: photoUrl ?? '', isVideo: false);
                },
                iconColor: const Color(0xFF008069),
              ),
              _optionItem(
                Icons.videocam_rounded,
                "Video Call",
                    () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Video calling $name..."),
                      duration: const Duration(milliseconds: 800),
                      backgroundColor: const Color(0xFF008069),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  _initiateCall(receiverId: uid, receiverName: name, receiverPic: photoUrl ?? '', isVideo: true);
                },
                iconColor: const Color(0xFF008069),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 2. SHOW GROUP OPTIONS
  void _showGroupOptions(String groupId, String groupName, String? photoUrl) {
    if (widget.isSelectionMode) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: const Color(0xFFE9F5EA),
                      child: photoUrl == null
                          ? Icon(Icons.groups, size: 32, color: const Color(0xFF008069).withOpacity(0.7))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey.shade300,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _optionItem(
                Icons.info_outline,
                "Group Info",
                    () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: groupId, groupName: groupName)));
                },
                iconColor: const Color(0xFF008069),
              ),
              _optionItem(
                Icons.chat,
                "Open Chat",
                    () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: groupId, receiverName: groupName, isGroup: true)));
                },
                iconColor: const Color(0xFF25D366),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionItem(IconData icon, String text, VoidCallback onTap, {Color iconColor = const Color(0xFF008069)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF008069).withOpacity(0.1),
        highlightColor: const Color(0xFF008069).withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withOpacity(0.1), width: 1),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: widget.isSelectionMode
          ? AppBar(
        title: Text(
          "Forward to...",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF008069),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      )
          : null,

      floatingActionButton: widget.isSelectionMode
          ? null
          : Container(
        margin: const EdgeInsets.only(bottom: 24, right: 20),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF25D366),
          elevation: 6,
          shape: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF00A884)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_comment_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const CreateGroupScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ✨ HEADER SECTION
            if (!widget.isSelectionMode) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chats",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1.0,
                            height: 0.9,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection("chats").where("users", arrayContains: myUid).snapshots(),
                          builder: (context, snapshot) {
                            int unreadCount = 0;
                            int chatCount = 0;
                            if (snapshot.hasData) {
                              final chats = snapshot.data!.docs;
                              chatCount = chats.length;
                              for (var chat in chats) {
                                final data = chat.data() as Map<String, dynamic>;
                                if (data['lastSenderId'] != myUid && data['isRead'] == false) {
                                  unreadCount++;
                                }
                              }
                            }
                            return Text(
                              "$chatCount conversations • $unreadCount unread",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(40),
                      splashColor: const Color(0xFF008069).withOpacity(0.1),
                      highlightColor: const Color(0xFF008069).withOpacity(0.05),
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF008069),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ✨ ENHANCED SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 2,
                      offset: const Offset(0, -1),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search chats, contacts...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        Icons.search_rounded,
                        color: const Color(0xFF008069).withOpacity(0.8),
                        size: 22,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                        : null,
                  ),
                ),
              ),
            ),

            // ✨ ENHANCED FILTER CHIPS
            if (!widget.isSelectionMode) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterChip("All", Icons.chat_bubble_outline_rounded),
                    const SizedBox(width: 10),
                    _buildFilterChip("Unread", Icons.mark_chat_unread_rounded),
                    const SizedBox(width: 10),
                    _buildFilterChip("Groups", Icons.groups_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ✨ CHAT LIST
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: _buildChatList(myUid),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF008069)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF008069).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF008069).withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(String myUid) {
    if (_searchQuery.isNotEmpty) return _buildSearchResults(myUid);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("chats").where("users", arrayContains: myUid).orderBy("lastTime", descending: true).snapshots(),
      builder: (context, chatSnap) {
        if (!chatSnap.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF008069).withOpacity(0.8)),
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Loading conversations",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait a moment",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        final chats = chatSnap.data!.docs;
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 70,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  "No conversations yet",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Start a conversation by tapping the + button below",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: chats.length,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chat = chatDoc.data() as Map<String, dynamic>;
            bool isGroup = chat['isGroup'] == true;
            bool isUnread = (chat['lastSenderId'] != myUid) && (chat['isRead'] == false);

            if (!widget.isSelectionMode && _selectedFilter == "Unread" && !isUnread) return const SizedBox();
            if (!widget.isSelectionMode && _selectedFilter == "Groups" && !isGroup) return const SizedBox();

            if (isGroup) {
              return _buildTileUI(
                context,
                id: chatDoc.id,
                name: chat['groupName'] ?? "Group",
                lastMsg: chat['lastMessage'],
                time: chat['lastTime'],
                isUnread: isUnread,
                isGroup: true,
                photoUrl: chat['photoUrl'],
              );
            } else {
              final users = List<String>.from(chat['users']);
              final otherUserId = users.firstWhere((id) => id != myUid, orElse: () => "");

              if (otherUserId.isEmpty) return const SizedBox(); // Safer check

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection("users").doc(otherUserId).snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  final user = userSnap.data!.data() as Map<String, dynamic>?;
                  final userName = "${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}";
                  return _buildTileUI(
                    context,
                    id: otherUserId,
                    name: userName,
                    photoUrl: user?['photoUrl'],
                    lastMsg: chat['lastMessage'],
                    time: chat['lastTime'],
                    isUnread: isUnread,
                    isGroup: false,
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildSearchResults(String myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF008069).withOpacity(0.8),
            ),
          );
        }
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (doc.id == myUid) return false;
          final fullName = "${data['firstName']} ${data['lastName']}".toLowerCase();
          return fullName.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 70,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 20),
                Text(
                  "No contacts found",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Try a different search term",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: docs.length,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final name = "${data['firstName']} ${data['lastName']}";
            return _buildTileUI(
              context,
              id: docs[index].id,
              name: name,
              photoUrl: data['photoUrl'],
              lastMsg: data['email'],
              time: null,
              isUnread: false,
              isGroup: false,
              isSearchResult: true,
            );
          },
        );
      },
    );
  }

  // ✨ ENHANCED TILE UI
  Widget _buildTileUI(
      BuildContext context, {
        required String id,
        required String name,
        String? photoUrl,
        String? lastMsg,
        Timestamp? time,
        bool isUnread = false,
        bool isGroup = false,
        bool isSearchResult = false,
      }) {
    bool isDeleted = lastMsg != null && lastMsg.contains('This message was deleted');
    bool isCleared = lastMsg == null || lastMsg.isEmpty;
    bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode) {
            Navigator.pop(context, {'id': id, 'name': name, 'isGroup': isGroup});
          } else {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => ChatScreen(receiverId: id, receiverName: name, isGroup: isGroup),
                transitionDuration: const Duration(milliseconds: 250),
                transitionsBuilder: (_, animation, __, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          }
        },
        onLongPress: widget.isSelectionMode
            ? null
            : () => isGroup ? _showGroupOptions(id, name, photoUrl) : _showUserOptions(id, name, photoUrl),
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFF008069).withOpacity(0.1),
        highlightColor: const Color(0xFF008069).withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread
                ? const Color(0xFFE9F5EA).withOpacity(0.3)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (isUnread)
                BoxShadow(
                  color: const Color(0xFF008069).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isUnread
                  ? const Color(0xFF008069).withOpacity(0.1)
                  : Colors.grey.shade100,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFE9F5EA),
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
                      child: !hasPhoto
                          ? Icon(
                        isGroup ? Icons.groups_rounded : Icons.person_rounded,
                        color: const Color(0xFF008069).withOpacity(0.6),
                        size: 30,
                      )
                          : null,
                    ),
                  ),
                  if (isUnread && !isGroup && !isSearchResult)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: Colors.black87,
                              overflow: TextOverflow.ellipsis,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        if (time != null && !isCleared)
                          Text(
                            _formatTime(time),
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnread ? const Color(0xFF008069) : Colors.grey.shade500,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isGroup && !isSearchResult)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF008069).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF008069).withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups,
                                  size: 12,
                                  color: const Color(0xFF008069).withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Group",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF008069).withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isGroup && !isSearchResult) const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isCleared
                                ? (widget.isSelectionMode ? "Tap to select" : "Start chatting")
                                : isDeleted
                                ? "Message deleted"
                                : lastMsg!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread ? Colors.black87 : Colors.grey.shade600,
                              fontSize: 14.5,
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                              fontStyle: (isDeleted || isCleared) ? FontStyle.italic : FontStyle.normal,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Unread message count
              if (isUnread && !widget.isSelectionMode && !isSearchResult)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF00A884)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "1",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}