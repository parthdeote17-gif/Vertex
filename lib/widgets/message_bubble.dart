import 'package:flutter/material.dart';
import 'video_player_widget.dart';
import 'full_screen_media.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String? mediaUrl;
  final String type; // 'text', 'image', 'video', 'deleted'
  final String time;
  final bool isMe;
  final Map<String, dynamic>? replyTo;
  final bool isRead;
  final bool isEdited;

  const MessageBubble({
    super.key,
    required this.text,
    this.mediaUrl,
    this.type = 'text',
    required this.time,
    required this.isMe,
    this.replyTo,
    this.isRead = false,
    this.isEdited = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isDeleted = type == 'deleted';
    double maxWidth = MediaQuery.of(context).size.width * 0.75;

    //  Define Colors based on sender
    final Color bubbleColor = isMe ? const Color(0xFF008069) : Colors.white;
    final Color textColor = isMe ? Colors.white : const Color(0xFF111B21);
    final Color metaColor = isMe ? Colors.white70 : Colors.grey[600]!;

    // Reply Colors
    final Color replyBg = isMe ? Colors.black.withOpacity(0.1) : Colors.grey.shade100;
    final Color replyBorder = isMe ? Colors.white.withOpacity(0.8) : const Color(0xFF008069);
    final Color replyTitle = isMe ? Colors.white : const Color(0xFF008069);
    final Color replyText = isMe ? Colors.white70 : Colors.grey[700]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Reply Preview
                if (replyTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: replyBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(color: replyBorder, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo!['senderName'] ?? 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: replyTitle,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo!['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: replyText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Image Display
                if (type == 'image' && mediaUrl != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenMedia(
                            mediaUrl: mediaUrl!,
                            type: 'image',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Hero(
                        tag: mediaUrl!,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: Image.network(
                              mediaUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.black12,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: textColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 150,
                                    color: Colors.black12,
                                    child: Icon(Icons.broken_image, color: metaColor),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3. Video Display
                if (type == 'video' && mediaUrl != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenMedia(
                            mediaUrl: mediaUrl!,
                            type: 'video',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 300),
                                child: VideoPlayerWidget(videoUrl: mediaUrl!)
                            ),
                            Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.black26,
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2)
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. Text Content & Timestamp Layout
                // Using Wrap to allow timestamp to sit next to short text, or below long text
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6, // Space between text and time
                  runSpacing: 4, // Space between lines if wrapped
                  children: [
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2), // Slight tweak
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isDeleted ? metaColor : textColor,
                            fontSize: 16,
                            height: 1.3,
                            fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),

                    // Time & Status Row
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEdited && !isDeleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                "edited",
                                style: TextStyle(color: metaColor, fontSize: 10, fontStyle: FontStyle.italic),
                              ),
                            ),
                          Text(
                            time,
                            style: TextStyle(
                                fontSize: 11,
                                color: metaColor,
                                fontWeight: FontWeight.w500
                            ),
                          ),
                          if (isMe && !isDeleted) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all_rounded,
                              size: 16,
                              // Improved check color logic
                              color: isRead
                                  ? const Color(0xFF53BDEB) // Light Blue for read on Teal
                                  : Colors.white60,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}