import 'dart:ui'; // For Blur Effect
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String channelId;
  final bool isGroup;

  const CallScreen({super.key, required this.channelId, this.isGroup = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // Agora & Call State
  final Set<int> _remoteUids = {};
  bool _localUserJoined = false;
  bool _muted = false;
  bool _isFrontCamera = true;

  // 🔥 FIX: Made nullable to prevent LateInitializationError
  RtcEngine? _engine;

  final CallService _callService = CallService();
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  bool _isCallEnded = false;

  // ⚠️ YOUR APP ID
  final String appId = "e7c6cc3a98f04ca3a31b7d2971644704";

  @override
  void initState() {
    super.initState();
    _initAgora();
    if (!widget.isGroup) {
      _listenToCallStatus();
    }
  }

  // 🔥 1. Call Status Listener
  void _listenToCallStatus() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _exitCall(); // Document deleted, exit
        return;
      }
      if (snapshot.data()?['status'] == 'ended') {
        _exitCall(); // Status updated to ended, exit
      }
    });
  }

  // 🔥 2. Exit Call Logic (Safe Cleanup)
  void _exitCall() async {
    if (_isCallEnded) return; // Prevent double execution
    _isCallEnded = true;

    _callSubscription?.cancel();

    // Agora Cleanup (Null Safe)
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint("Agora Cleanup Error: $e");
    }

    if (mounted) Navigator.pop(context);
  }

  // 🔥 3. Initialize Agora Engine
  Future<void> _initAgora() async {
    // Permissions request
    await [Permission.microphone, Permission.camera].request();

    // Create Engine
    _engine = createAgoraRtcEngine();

    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Local user joined");
          if (mounted) setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("✅ Remote user joined: $remoteUid");
          if (mounted) setState(() => _remoteUids.add(remoteUid));
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("❌ Remote user left");
          if (mounted) setState(() => _remoteUids.remove(remoteUid));

          // Logic: If 1-to-1 call and other user leaves, end call
          if (!widget.isGroup) _exitCall();
        },
      ),
    );

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: "", // Temp Token or Null
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    // 🔥 Trigger rebuild to show UI now that engine is ready
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    // Safety cleanup just in case _exitCall wasn't fully triggered
    if (!_isCallEnded) {
      _engine?.leaveChannel();
      _engine?.release();
    }
    super.dispose();
  }

  // Actions
  void _onCallEndButton() async {
    if (!widget.isGroup) {
      await _callService.endCall(widget.channelId);
    }
    _exitCall();
  }

  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine?.muteLocalAudioStream(_muted);
  }

  void _onSwitchCamera() {
    _engine?.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 FIX: Show Loader if engine is not ready
    if (_engine == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: Container(
        // 🔥 Dark Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1c1c1c), Color(0xFF000000)],
          ),
        ),
        child: Stack(
          children: [
            // 🎥 MAIN VIDEO LAYOUT
            SafeArea(child: _viewRows()),

            // 📞 STYLISH CONTROL BAR (Floating Glassmorphism)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: _buildControlBar(),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 CORE LOGIC: Dynamic Layout Switcher
  Widget _viewRows() {
    final int totalUsers = _remoteUids.length + 1; // Remotes + Me
    final List<int> allUsers = [0, ..._remoteUids]; // 0 is Me

    // 1. WAITING STATE (Only Me)
    if (totalUsers == 1) {
      return Stack(
        children: [
          // Full Screen Me
          AgoraVideoView(
              controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0)
              )
          ),
          // Connecting Overlay
          Container(
            color: Colors.black.withOpacity(0.6),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                      "Waiting for others...",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
          )
        ],
      );
    }

    // 2. 1-to-1 CALL (WhatsApp/FaceTime Style)
    if (totalUsers == 2 && !widget.isGroup) {
      return Stack(
        children: [
          // Remote User (Full Screen)
          AgoraVideoView(
              controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: allUsers[1]),
                  connection: RtcConnection(channelId: widget.channelId)
              )
          ),

          // Local User (Floating Window)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AgoraVideoView(
                    controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0)
                    )
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3. GROUP CALL (Dynamic Grid)
    int crossAxisCount = totalUsers <= 2 ? 1 : 2;
    double aspectRatio = totalUsers <= 2 ? 1.3 : 0.75;

    return Padding(
      padding: const EdgeInsets.only(bottom: 120, left: 10, right: 10, top: 10),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: totalUsers,
        itemBuilder: (context, index) {
          return _videoContainer(
            uid: allUsers[index],
            isMe: allUsers[index] == 0,
          );
        },
      ),
    );
  }

  // 🔥 Stylish Video Container for Grid
  Widget _videoContainer({required int uid, required bool isMe}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Video Feed
            isMe
                ? AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)))
                : AgoraVideoView(
                controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: uid),
                    connection: RtcConnection(channelId: widget.channelId)
                )
            ),

            // Gradient Overlay for text visibility
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Name Tag Capsule
            Positioned(
              bottom: 12, left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: Colors.white.withOpacity(0.2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isMe ? Icons.person : Icons.videocam, color: Colors.white, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          isMe ? "You" : "User $uid",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Glassmorphism Control Bar
  Widget _buildControlBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlButton(
                onTap: _onToggleMute,
                icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _muted ? Colors.black : Colors.white,
                bgColor: _muted ? Colors.white : Colors.white24,
              ),
              _controlButton(
                onTap: _onCallEndButton,
                icon: Icons.call_end_rounded,
                color: Colors.white,
                bgColor: Colors.redAccent,
                size: 32, // Bigger End Button
                padding: 18,
              ),
              _controlButton(
                onTap: _onSwitchCamera,
                icon: Icons.cameraswitch_rounded,
                color: Colors.white,
                bgColor: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required Color bgColor,
    double size = 26,
    double padding = 14,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              if(bgColor == Colors.redAccent)
                BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
            ]
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}