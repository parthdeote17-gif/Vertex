import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Stream Subscription ke liye
import '../../services/call_service.dart';
import 'call_screen.dart';
import 'audio_call_screen.dart';

class PickupScreen extends StatefulWidget {
  final Map<String, dynamic> callData;

  const PickupScreen({super.key, required this.callData});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  // 🎵 SOUND LOGIC REMOVED: AudioPlayer hata diya

  final CallService _callService = CallService();
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  bool _isCallAccepted = false;

  @override
  void initState() {
    super.initState();

    _listenToCallStatus(); // 👀 Document par nazar rakho
  }

  // Real-time Listener: Agar caller ne phone kaata, toh ye screen band hogi
  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callData['id'])
        .snapshots()
        .listen((snapshot) {

      // Case 1: Caller ne phone kaat diya (Doc deleted)
      if (!snapshot.exists) {
        if (mounted) {
          // _stopRingtone(); // ❌ Removed
          Navigator.pop(context);
        }
        return;
      }

      // Case 2: Kisi aur device se utha liya (Optional safety)
      var data = snapshot.data() as Map<String, dynamic>;
      if (data['status'] == 'accepted' && !_isCallAccepted) {
        // Handle glitch if needed
      }
    });
  }

  // Ringtone methods (_playRingtone, _stopRingtone) poori tarah hata diye gaye hain

  @override
  void dispose() {
    // _stopRingtone(); // ❌ Removed
    _callSubscription?.cancel(); // Listener band karna zaruri hai
    super.dispose();
  }

  // ✅ Call Accept Logic
  void _acceptCall() async {
    setState(() => _isCallAccepted = true);
    // _stopRingtone(); // ❌ Removed

    // 1. Status update karo
    await _callService.answerCall(widget.callData['id']);

    if (!mounted) return;

    // 2. Data nikalo
    bool isVideo = widget.callData['type'] == 'video';
    String channelId = widget.callData['channelId'];

    // 3. Screen hatao (Replacement taaki back dabane par wapis pickup screen na aaye)
    Navigator.pop(context);

    // 4. Video/Audio Screen par jao
    if (isVideo) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => CallScreen(channelId: channelId)
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => AudioCallScreen(
            channelId: channelId,
            receiverName: widget.callData['callerName'],
            receiverPhoto: widget.callData['callerPic'],
          )
      ));
    }
  }

  // ❌ Call Reject Logic
  void _rejectCall() async {
    // _stopRingtone(); // ❌ Removed
    // Document delete karo -> Caller ko pata chalega
    await _callService.endCall(widget.callData['id']);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.callData['callerPic'] != null && widget.callData['callerPic'].isNotEmpty
                  ? NetworkImage(widget.callData['callerPic'])
                  : null,
              child: widget.callData['callerPic'] == null || widget.callData['callerPic'].isEmpty
                  ? const Icon(Icons.person, size: 60) : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.callData['callerName'] ?? "Unknown",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              widget.callData['type'] == 'video' ? "Incoming Video Call..." : "Incoming Audio Call...",
              style: const TextStyle(fontSize: 16, color: Colors.greenAccent),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ❌ Reject
                GestureDetector(
                  onTap: _rejectCall,
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.call_end, color: Colors.white, size: 30),
                  ),
                ),
                // ✅ Accept
                GestureDetector(
                  onTap: _acceptCall,
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.call, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}