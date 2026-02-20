import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 IMPORT ADDED
import 'dart:async'; // 🔥 IMPORT ADDED
import '../../services/call_service.dart'; // 🔥 IMPORT ADDED

class AudioCallScreen extends StatefulWidget {
  final String channelId;
  final String receiverName;
  final String? receiverPhoto;

  const AudioCallScreen({
    super.key,
    required this.channelId,
    required this.receiverName,
    this.receiverPhoto,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late RtcEngine _engine;
  bool _muted = false;
  final String appId = "e7c6cc3a98f04ca3a31b7d2971644704"; // ✅ App ID

  // 🔥 NEW VARIABLES
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    initAgora();
    _listenToCallStatus(); // 🔥 START LISTENER
  }

  // 🎧 Call Status Listener (Fix for Waiting Screen issue)
  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelId)
        .snapshots()
        .listen((snapshot) {

      // Agar document delete ho gaya ya status 'ended' ho gaya -> Call Khatam
      if (!snapshot.exists || (snapshot.data() != null && snapshot.data()!['status'] == 'ended')) {
        _onCallEnd(endFromMySide: false); // Khud mat delete karo, bas niklo
      }
    });
  }

  Future<void> initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        _onCallEnd(endFromMySide: true); // Samne wala gaya, toh hum bhi end karenge
      },
    ));

    // 🛑 Audio Only Mode
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.disableVideo();

    await _engine.joinChannel(
      token: "",
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel(); // 🔥 LISTENER BAND KARO
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  // 🔥 Call End Logic Updated
  void _onCallEnd({bool endFromMySide = true}) {
    // Listener loop na bane, isliye check karte hain
    _callSubscription?.cancel();

    if (endFromMySide) {
      _callService.endCall(widget.channelId); // DB me status update karo
    }

    if (mounted) Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.receiverPhoto != null
                  ? NetworkImage(widget.receiverPhoto!)
                  : null,
              child: widget.receiverPhoto == null
                  ? Text(widget.receiverName[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white))
                  : null,
            ),
            const SizedBox(height: 20),
            Text(widget.receiverName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const Text("Voice Call", style: TextStyle(color: Colors.white54, fontSize: 16)),
            const Spacer(),

            // Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: "mute",
                    backgroundColor: _muted ? Colors.white : Colors.grey[800],
                    onPressed: _onToggleMute,
                    child: Icon(_muted ? Icons.mic_off : Icons.mic, color: _muted ? Colors.black : Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: "end",
                    backgroundColor: Colors.red,
                    onPressed: () => _onCallEnd(endFromMySide: true), // 🔥 Button dabaya toh DB update hoga
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}