import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  final Set<String> _selectedUserIds = {};
  String _searchQuery = "";
  bool _isLoading = false;

  // 🎨 UI Constants
  static const Color kBackground = Color(0xFFF7F8FA);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kPrimary = Color(0xFF0ACF83);
  static const Color kTextPrimary = Color(0xFF101010);
  static const Color kTextSecondary = Color(0xFF9C9C9C);

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter group name")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> members = List.from(_selectedUserIds)..add(myUid);

      await FirebaseFirestore.instance.collection('chats').add({
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

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          "New Group",
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        ),
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isLoading ? null : _createGroup,
              style: TextButton.styleFrom(
                backgroundColor: kPrimary.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                  : const Text("CREATE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimary)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 📝 Group Name Input (Modern Card Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _groupNameController,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary),
                decoration: InputDecoration(
                  labelText: "Group Subject",
                  labelStyle: const TextStyle(color: kTextSecondary, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.groups_rounded, color: kPrimary),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),

          // 🔍 Search Users (Modern Floating Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: kTextPrimary),
                decoration: InputDecoration(
                  hintText: "Search users to add...",
                  hintStyle: const TextStyle(color: kTextSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: kTextSecondary),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 👥 User List (Filtered by Search)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _searchQuery.isEmpty
                  ? FirebaseFirestore.instance.collection("users").where("uid", isNotEqualTo: myUid).snapshots()
                  : FirebaseFirestore.instance
                  .collection("users")
                  .where("firstName", isGreaterThanOrEqualTo: _searchQuery)
                  .where("firstName", isLessThan: '${_searchQuery}z')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: kPrimary));
                }

                final users = snapshot.data!.docs;
                // Double check to remove self if query fetches me
                final filteredUsers = users.where((doc) => doc.id != myUid).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No users found", style: TextStyle(color: kTextSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = filteredUsers[index].data() as Map<String, dynamic>;
                    final uid = filteredUsers[index].id;
                    final name = "${data['firstName']} ${data['lastName']}";
                    final isSelected = _selectedUserIds.contains(uid);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(uid);
                          } else {
                            _selectedUserIds.add(uid);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? kPrimary : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? kPrimary.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade100, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFE9F5EA),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name & Email
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data['email'] ?? '',
                                    style: const TextStyle(color: kTextSecondary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Custom Checkbox
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? kPrimary : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? kPrimary : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ],
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
  }
}