import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  Timer? _typingTimer;
  bool _containsToxicWord = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startMarkingMessagesAsRead();
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

    // Listen for deleted messages
    _database
        .child('messages')
        .child(_currentUserId)
        .child(widget.friend['id'])
        .onChildRemoved
        .listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          final deletedMessage = Map<String, dynamic>.from(event.snapshot.value as Map);
          _messages.removeWhere((msg) =>
              msg['timestamp'] == deletedMessage['timestamp'] &&
              msg['text'] == deletedMessage['text']);
        });
      }
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

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      // Check for toxic content before sending
      bool hasToxicContent = await checkWordToxicity(_messageController.text);
      
      if (hasToxicContent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message contains inappropriate content'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[850],
            onSelected: (value) {
              if (value == 'clear') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Clear Chat', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
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
    return GestureDetector(
      onLongPress: () => _showDeleteOptions(message),
      child: Dismissible(
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
                          style: TextStyle(color: _containsToxicWord ? Colors.red : Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            errorText: _containsToxicWord ? 'Message contains inappropriate content' : null,
                          ),
                          onChanged: (text) {
                            // Cancel previous timer
                            _typingTimer?.cancel();
                            
                            // Start new timer to check text
                            _typingTimer = Timer(Duration(milliseconds: 500), () async {
                              bool isToxic = await checkWordToxicity(text);
                              
                              if (mounted) {
                                setState(() {
                                  _containsToxicWord = isToxic;
                                });
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _containsToxicWord ? Colors.grey : Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.send, color: Colors.white),
                  onPressed: _containsToxicWord ? null : _sendMessage,
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

  // Simplified toxic word check 
  Future<bool> checkWordToxicity(String word) async {
    if (word.trim().isEmpty) return false;
    
    final List<String> toxicWords = [
      // Violence-related
      "kill", "murder", "die", "death", "suicide", "hurt",
      "stab", "shoot", "attack", "fight", "beat up",
      
      // Existing hate speech
      "hate", "stupid", "idiot", 
      "sex", "fuck", "bitch", "asshole",
      "faggot", "retard", "nigger", "nigga",
      
      // Additional slurs and offensive terms
      "whore", "slut", "cunt", "pussy",
      "dick", "bastard", "motherfucker",
      
      // Bullying phrases
      "i hate you", "you're stupid", "you should quit",
      "nobody likes you", "you're worthless", "this is garbage",
      "you don't belong here", "you're terrible",
      "everyone thinks you're", "leave and never come back",
      
      // Threats
      "i will kill", "going to kill", "want to kill",
      "kill yourself", "hope you die", "should die",
      
      // Additional toxic phrases
      "go to hell", "rot in hell", "end your life",
      "kill yourself", "kys", "neck yourself",
      "off yourself", "end it all",
      
      // Discriminatory terms
      "terrorist", "nazi", "racist",
      "go back to", "your kind", "you people",
    ];
    
    return toxicWords.any((toxic) => 
      word.toLowerCase().trim().contains(toxic.toLowerCase()));
  }

  void _showDeleteOptions(Map<String, dynamic> message) {
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final bool canDeleteForEveryone = 
        (currentTime - message['timestamp']) <= 60000; // 60 seconds = 1 minute

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('Delete Message', 
            style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message['senderId'] == _currentUserId && canDeleteForEveryone)
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Delete for everyone',
                    style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessage(message, true);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete for me',
                  style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteMessage(message, false);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: Colors.grey),
                title: Text('Cancel',
                  style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMessage(Map<String, dynamic> message, bool deleteForEveryone) async {
    try {
      if (deleteForEveryone && message['senderId'] == _currentUserId) {
        // Delete from both sender and receiver
        await _database
            .child('messages')
            .child(_currentUserId)
            .child(widget.friend['id'])
            .orderByChild('timestamp')
            .equalTo(message['timestamp'])
            .once()
            .then((DatabaseEvent event) {
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> messages = 
                event.snapshot.value as Map<dynamic, dynamic>;
            messages.forEach((key, _) {
              _database
                  .child('messages')
                  .child(_currentUserId)
                  .child(widget.friend['id'])
                  .child(key)
                  .remove();
            });
          }
        });

        await _database
            .child('messages')
            .child(widget.friend['id'])
            .child(_currentUserId)
            .orderByChild('timestamp')
            .equalTo(message['timestamp'])
            .once()
            .then((DatabaseEvent event) {
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> messages = 
                event.snapshot.value as Map<dynamic, dynamic>;
            messages.forEach((key, _) {
              _database
                  .child('messages')
                  .child(widget.friend['id'])
                  .child(_currentUserId)
                  .child(key)
                  .remove();
            });
          }
        });

        // Update local state
        setState(() {
          _messages.removeWhere((msg) => 
            msg['timestamp'] == message['timestamp'] && 
            msg['text'] == message['text']);
        });
      } else {
        // Delete only from current user's messages
        await _database
            .child('messages')
            .child(_currentUserId)
            .child(widget.friend['id'])
            .orderByChild('timestamp')
            .equalTo(message['timestamp'])
            .once()
            .then((DatabaseEvent event) {
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> messages = 
                event.snapshot.value as Map<dynamic, dynamic>;
            messages.forEach((key, _) {
              _database
                  .child('messages')
                  .child(_currentUserId)
                  .child(widget.friend['id'])
                  .child(key)
                  .remove();
            });
          }
        });

        // Update local state
        setState(() {
          _messages.removeWhere((msg) => 
            msg['timestamp'] == message['timestamp'] && 
            msg['text'] == message['text']);
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleteForEveryone ? 'Message deleted for everyone' : 'Message deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text('Clear Chat', 
            style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to clear all messages?', 
            style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              child: Text('Cancel', 
                style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Clear', 
                style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
            ),
          ],
        );
      },
    );
  }

  void _clearChat() async {
    try {
      // Clear messages from current user's side
      await _database
          .child('messages')
          .child(_currentUserId)
          .child(widget.friend['id'])
          .remove();

      // Update local state
      setState(() {
        _messages.clear();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear chat'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }
}
