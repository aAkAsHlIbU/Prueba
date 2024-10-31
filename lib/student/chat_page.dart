import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> friend;

  ChatPage({required this.friend});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startMarkingMessagesAsRead(); // Start periodic checking when chat opens
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _markMessagesAsRead();
  }

  void _loadMessages() {
    // First, get all existing messages
    _database
        .child('messages')
        .child(_currentUserId)
        .child(widget.friend['id'])
        .once()
        .then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          final messages =
              Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          _messages = messages.values
              .map((msg) => Map<String, dynamic>.from(msg as Map))
              .toList();
          _messages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        });
      }
    });

    // Listen for new messages
    _database
        .child('messages')
        .child(_currentUserId)
        .child(widget.friend['id'])
        .onChildAdded
        .listen((event) {
      if (!_messages.any((msg) =>
          msg['timestamp'] == (event.snapshot.value as Map)['timestamp'] &&
          msg['text'] == (event.snapshot.value as Map)['text'])) {
        setState(() {
          _messages.insert(
              0, Map<String, dynamic>.from(event.snapshot.value as Map));
        });
      }
    });

    // Listen for message updates (including read status changes)
    _database
        .child('messages')
        .child(_currentUserId)
        .child(widget.friend['id'])
        .onChildChanged
        .listen((event) {
      setState(() {
        final updatedMessage =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        final index = _messages.indexWhere((msg) =>
            msg['timestamp'] == updatedMessage['timestamp'] &&
            msg['text'] == updatedMessage['text']);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
      });
    });
  }

  void _markMessagesAsRead() {
    // Only mark messages from friend as read
    _database
        .child('messages')
        .child(_currentUserId)
        .child(widget.friend['id'])
        .orderByChild('read')
        .equalTo(false)
        .once()
        .then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> unreadMessages =
            event.snapshot.value as Map<dynamic, dynamic>;
        unreadMessages.forEach((key, value) {
          Map<dynamic, dynamic> message = value as Map<dynamic, dynamic>;
          // Only mark messages from friend as read
          if (message['senderId'] == widget.friend['id']) {
            _database
                .child('messages')
                .child(_currentUserId)
                .child(widget.friend['id'])
                .child(key)
                .update({'read': true});

            // Update in friend's database as well
            _database
                .child('messages')
                .child(widget.friend['id'])
                .child(_currentUserId)
                .orderByChild('timestamp')
                .equalTo(message['timestamp'])
                .once()
                .then((DatabaseEvent matchEvent) {
              if (matchEvent.snapshot.value != null) {
                Map<dynamic, dynamic> matchMessages =
                    matchEvent.snapshot.value as Map<dynamic, dynamic>;
                matchMessages.forEach((matchKey, matchValue) {
                  _database
                      .child('messages')
                      .child(widget.friend['id'])
                      .child(_currentUserId)
                      .child(matchKey)
                      .update({'read': true});
                });
              }
            });
          }
        });
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final message = {
        'senderId': _currentUserId,
        'text': _messageController.text,
        'timestamp': timestamp,
        'read': false,
        if (_replyingTo != null)
          'replyTo': {
            'text': _replyingTo!['text'],
            'timestamp': _replyingTo!['timestamp'],
            'senderId': _replyingTo!['senderId'],
          },
      };

      _database
          .child('messages')
          .child(_currentUserId)
          .child(widget.friend['id'])
          .push()
          .set(message);

      _database
          .child('messages')
          .child(widget.friend['id'])
          .child(_currentUserId)
          .push()
          .set(message);

      setState(() {
        _replyingTo = null;
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          widget.friend['name'],
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isCurrentUser = message['senderId'] == _currentUserId;
                return _buildMessageBubble(message, isCurrentUser);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    return Dismissible(
      key: Key(message['timestamp'].toString()),
      direction: isCurrentUser
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = message;
        });
        return false;
      },
      background: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        color: Colors.blue.withOpacity(0.2),
        child: Transform(
          transform: Matrix4.identity()
            ..scale(isCurrentUser ? -1.0 : 1.0, 1.0, 1.0),
          alignment: Alignment.center,
          child: Icon(
            Icons.reply,
            color: Colors.white,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (message['replyTo'] != null) ...[
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[900]!.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['replyTo']['senderId'] == _currentUserId
                                  ? 'You'
                                  : widget.friend['name'],
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              message['replyTo']['text'],
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      message['text'],
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(message['timestamp']),
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        SizedBox(width: 4),
                        if (isCurrentUser) _buildReadReceipt(message['read']),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadReceipt(bool isRead) {
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 16,
      color: isRead ? const Color.fromARGB(255, 21, 133, 30) : Colors.grey[400],
    );
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        Container(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[850],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyingTo!['senderId'] == _currentUserId
                      ? 'You'
                      : widget.friend['name'],
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _replyingTo!['text'],
                  style: TextStyle(color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[400]),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat.jm().format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  // Add this method to periodically mark messages as read while chat is open
  void _startMarkingMessagesAsRead() {
    // Mark messages as read every few seconds while the chat is open
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        // Check if widget is still mounted
        _markMessagesAsRead();
        _startMarkingMessagesAsRead(); // Schedule next check
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
