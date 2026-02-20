import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// Services
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';

// Screens
import '../home/home_screen.dart'; // ✅ FIX: Home Screen Import

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _adminId;
  String? _currentPhotoUrl;

  // 🎨 UI Constants
  static const Color kBackground = Color(0xFFF7F8FA);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kPrimary = Color(0xFF0ACF83);
  static const Color kTextPrimary = Color(0xFF101010);
  static const Color kTextSecondary = Color(0xFF9C9C9C);

  // 🔥 NEW: ADD MEMBER BOTTOM SHEET
  void _showAddMemberBottomSheet(List<dynamic> currentMembers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: const [
                    Text(
                      "Add New Member",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));

                    final users = snapshot.data!.docs;
                    // Filter users who are NOT already in the group
                    final availableUsers = users.where((doc) => !currentMembers.contains(doc.id)).toList();

                    if (availableUsers.isEmpty) {
                      return Center(
                        child: Text(
                          "No new contacts to add",
                          style: TextStyle(color: kTextSecondary, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: availableUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final userData = availableUsers[index].data() as Map<String, dynamic>;
                        final uid = availableUsers[index].id;
                        final name = "${userData['firstName']} ${userData['lastName']}";

                        return Container(
                          decoration: BoxDecoration(
                            color: kBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null,
                              child: userData['photoUrl'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_rounded, color: kPrimary, size: 32),
                              onPressed: () async {
                                // 🔥 Use ChatService or Direct
                                await _chatService.addMemberToGroup(widget.groupId, uid);
                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text("$name added!"),
                                  backgroundColor: kPrimary,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          "Group Info",
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: kBackground,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Group no longer exists"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> users = data['users'] ?? [];
          _adminId = data['adminId'];
          _currentPhotoUrl = data['photoUrl'];
          String currentGroupName = data['groupName'] ?? "Group";
          bool isAdmin = myUid == _adminId;

          // Logic: Agar main member nahi hu, toh Home bhej do
          if (!users.contains(myUid)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
              }
            });
            return const SizedBox();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 📸 GROUP HEADER CARD
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: isAdmin ? _updateGroupIcon : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade100, width: 4),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: kBackground,
                                backgroundImage: _currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null,
                                child: _currentPhotoUrl == null ? Icon(Icons.groups_rounded, size: 50, color: Colors.grey.shade400) : null,
                              ),
                            ),
                            if (isAdmin)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kCard, width: 3),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentGroupName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: InkWell(
                                onTap: () => _editGroupName(currentGroupName),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.edit_rounded, color: kTextSecondary, size: 18),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${users.length} members",
                        style: const TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ➕ ADD MEMBERS BUTTON (Admin Only)
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddMemberBottomSheet(users),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text("Add Participants", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: kPrimary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                if (_isLoading) const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(color: kPrimary, backgroundColor: kBackground),
                ),

                const SizedBox(height: 24),

                // 👥 PARTICIPANTS LABEL
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: kPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Participants",
                        style: TextStyle(
                          color: kTextPrimary.withOpacity(0.8),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 👥 MEMBERS LIST
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    String uid = users[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        var userData = userSnap.data!.data() as Map<String, dynamic>;
                        String name = userData['firstName'] ?? 'User';
                        bool isMemberAdmin = uid == _adminId;

                        return Container(
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null,
                              child: userData['photoUrl'] == null ? const Icon(Icons.person_rounded, color: Colors.grey) : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    uid == myUid ? "You" : name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: kTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMemberAdmin)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "Admin",
                                      style: TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: (isAdmin && !isMemberAdmin)
                                ? PopupMenuButton( // 🔥 ADMIN MENU
                              icon: const Icon(Icons.more_vert_rounded, color: kTextSecondary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'admin') _makeAdmin(uid, name);
                                if (value == 'remove') _removeMember(uid, name);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'admin', child: Text("Make Group Admin")),
                                const PopupMenuItem(value: 'remove', child: Text("Remove from Group", style: TextStyle(color: Colors.red))),
                              ],
                            )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 30),

                // 🚪 EXIT GROUP
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    onTap: () => _leaveGroup(context),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                    ),
                    title: const Text(
                      "Exit Group",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🛠️ LOGIC FUNCTIONS (UNCHANGED)

  // 1. Rename Group
  void _editGroupName(String currentName) {
    TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter new subject"),
        content: TextField(controller: nameController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () {
            if (nameController.text.isNotEmpty) {
              _chatService.updateGroupName(widget.groupId, nameController.text.trim());
              Navigator.pop(context);
            }
          }, child: const Text("Save")),
        ],
      ),
    );
  }

  // 2. Change Icon
  Future<void> _updateGroupIcon() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      File file = File(pickedFile.path);
      String? url = await _storageService.uploadProfileImage(file, "group_${widget.groupId}");
      if (url != null) {
        String finalUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";
        await _chatService.updateGroupProfile(widget.groupId, finalUrl);
      }
      setState(() => _isLoading = false);
    }
  }

  // 3. Make Admin
  void _makeAdmin(String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Make $name admin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () {
            _chatService.changeGroupAdmin(widget.groupId, uid);
            Navigator.pop(context);
          }, child: const Text("Confirm")),
        ],
      ),
    );
  }

  // 4. Remove Member
  void _removeMember(String uid, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      _chatService.removeMemberFromGroup(widget.groupId, uid);
    }
  }

  // 5. Leave Group (With Home Navigation)
  Future<void> _leaveGroup(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group?"),
        content: const Text("You won't receive messages from this group anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _chatService.leaveGroup(widget.groupId);
      if (!mounted) return;
      // ✅ Fix: Navigate to Home Screen properly
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    }
  }
}