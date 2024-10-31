import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String senderName;
  final DateTime timestamp;

  ChatBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bgColor = isMe
        ? (isDarkMode ? Colors.blue[700] : Colors.blue[100])
        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]);
    final textColor = isMe
        ? (isDarkMode ? Colors.white : Colors.black)
        : (isDarkMode ? Colors.white : Colors.black);
    final subtleColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final icon = isMe ? Icons.person : Icons.person_outline;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: align,
        children: <Widget>[
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) Icon(icon, size: 16, color: subtleColor),
              SizedBox(width: 4),
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: subtleColor,
                ),
              ),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 5),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(color: textColor),
                ),
                SizedBox(height: 5),
                Text(
                  DateFormat('HH:mm').format(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: subtleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
