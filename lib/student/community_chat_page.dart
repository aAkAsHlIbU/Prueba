// lib/student/community_chat_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CommunityChatPage extends StatefulWidget {
  final String communityId;
  final String communityName;

  CommunityChatPage({required this.communityId, required this.communityName});

  @override
  _CommunityChatPageState createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isTeacher = false;
  bool _isMember = false;
  Map<String, String> _userNames = {};
  Map<String, String> _communityMembers = {};
  String _creatorId = '';
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _checkMembershipStatus();
    _loadCommunityMembers();
    _loadCreatorId();
  }

  void _checkMembershipStatus() {
    _database
        .child('communities/${widget.communityId}/members/$_currentUserId')
        .onValue
        .listen((event) {
      setState(() {
        _isMember = event.snapshot.value != null;
      });
      if (_isMember) {
        _loadMessages();
        _checkTeacherStatus();
      }
    });
  }

  void _loadMessages() {
    _messages.clear(); // Clear existing messages before loading

    _database
        .child('community_messages/${widget.communityId}')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messagesMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> messagesList = [];

        messagesMap.forEach((key, value) {
          Map<String, dynamic> message = Map<String, dynamic>.from(value);
          message['key'] =
              key; // Store the Firebase key for potential future use
          messagesList.add(message);
        });

        // Sort messages by timestamp in descending order (newest first)
        messagesList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        setState(() {
          _messages = messagesList;
          _messages.forEach((message) {
            _fetchUserName(message['senderId']);
          });
        });
      }
    });

    // Listen for new messages
    _database
        .child('community_messages/${widget.communityId}')
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value != null) {
        Map<String, dynamic> message =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        message['key'] = event.snapshot.key;

        setState(() {
          // Only add the message if it's not already in the list
          if (!_messages.any((m) => m['key'] == message['key'])) {
            _messages.insert(0, message);
            _fetchUserName(message['senderId']);
          }
        });
      }
    });

    // Listen for removed messages
    _database
        .child('community_messages/${widget.communityId}')
        .onChildRemoved
        .listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _messages.removeWhere((m) => m['key'] == event.snapshot.key);
        });
      }
    });
  }

  void _fetchUserName(String userId) {
    if (!_userNames.containsKey(userId)) {
      _database.child('users/$userId/name').once().then((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          setState(() {
            _userNames[userId] = event.snapshot.value as String;
          });
        }
      });
    }
  }

  void _checkTeacherStatus() async {
    DatabaseEvent event = await _database
        .child('communities/${widget.communityId}/createdBy')
        .once();
    setState(() {
      _isTeacher = event.snapshot.value == _currentUserId;
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final message = {
        'senderId': _currentUserId,
        'text': _messageController.text,
        'timestamp': ServerValue.timestamp,
        if (_replyingTo != null)
          'replyTo': {
            'text': _replyingTo!['text'],
            'senderId': _replyingTo!['senderId'],
            'senderName': _replyingTo!['senderName'],
            'timestamp': _replyingTo!['timestamp'],
          },
      };

      _database
          .child('community_messages/${widget.communityId}')
          .push()
          .set(message);
      _messageController.clear();
      setState(() {
        _replyingTo = null;
      });
    }
  }

  void _loadCommunityMembers() {
    _database
        .child('communities/${widget.communityId}/members')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> members =
            event.snapshot.value as Map<dynamic, dynamic>;
        members.forEach((key, value) {
          _fetchMemberName(key);
        });
      }
    });
  }

  void _fetchMemberName(String userId) {
    _database.child('users/$userId/name').once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _communityMembers[userId] = event.snapshot.value as String;
        });
      }
    });
  }

  void _leaveCommunity() async {
    if (_currentUserId == _creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('As the creator, you cannot leave this community.')),
      );
      return;
    }
    await _database
        .child('communities/${widget.communityId}/members/$_currentUserId')
        .remove();
    await _database
        .child('users/$_currentUserId/communities/${widget.communityId}')
        .remove();
    Navigator.of(context).pop(); // Close the info page
    Navigator.of(context).pop(); // Return to the chat list
  }

  void _loadCreatorId() {
    _database
        .child('communities/${widget.communityId}/createdBy')
        .once()
        .then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _creatorId = event.snapshot.value as String;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          widget.communityName,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => _CommunityInfoPage(
                  communityName: widget.communityName,
                  members: _communityMembers,
                  onLeave: _leaveCommunity,
                  isTeacher: _isTeacher,
                  onRemoveMember: _removeMember,
                  creatorId: _creatorId,
                  currentUserId: _currentUserId,
                ),
              ));
            },
          ),
        ],
      ),
      body: _isMember ? _buildChatInterface() : _buildNonMemberView(),
    );
  }

  Widget _buildChatInterface() {
    return Column(
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
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    final senderName = _userNames[message['senderId']] ?? 'Unknown';

    return Dismissible(
      key: Key(message['timestamp'].toString()),
      direction: isCurrentUser
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = {
            ...message,
            'senderName': senderName,
          };
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
          // Changed to Row for proper alignment
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              // Added Flexible for proper width constraints
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (message['replyTo'] != null) ...[
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['replyTo']['senderName'],
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              message['replyTo']['text'],
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
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
                    Text(
                      _formatTimestamp(message['timestamp']),
                      style: TextStyle(color: Colors.white70, fontSize: 10),
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
                  'Reply to ${_replyingTo!['senderName']}',
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

  Widget _buildNonMemberView() {
    return Center(
      child: Text(
        'You are not a member of this community. Please wait for your join request to be approved.',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
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

  void _showDeleteMessageDialog(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Message'),
          content: Text('Are you sure you want to delete this message?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                _deleteMessage(message);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(Map<String, dynamic> message) {
    _database
        .child('community_messages/${widget.communityId}')
        .orderByChild('timestamp')
        .equalTo(message['timestamp'])
        .once()
        .then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> messages =
            event.snapshot.value as Map<dynamic, dynamic>;
        String messageKey = messages.keys.first;
        _database
            .child('community_messages/${widget.communityId}/$messageKey')
            .remove()
            .then((_) {
          setState(() {
            _messages
                .removeWhere((m) => m['timestamp'] == message['timestamp']);
          });
        });
      }
    });
  }

  void _removeMember(String memberId) async {
    if (memberId == _creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The community creator cannot be removed.')),
      );
      return;
    }
    await _database
        .child('communities/${widget.communityId}/members/$memberId')
        .remove();
    await _database
        .child('users/$memberId/communities/${widget.communityId}')
        .remove();
    setState(() {
      _communityMembers.remove(memberId);
    });
    // Refresh the info page
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _CommunityInfoPage(
        communityName: widget.communityName,
        members: _communityMembers,
        onLeave: _leaveCommunity,
        isTeacher: _isTeacher,
        onRemoveMember: _removeMember,
        creatorId: _creatorId,
        currentUserId: _currentUserId,
      ),
    ));
  }
}

class _CommunityInfoPage extends StatefulWidget {
  final String communityName;
  final Map<String, String> members;
  final VoidCallback onLeave;
  final bool isTeacher;
  final Function(String) onRemoveMember;
  final String creatorId;
  final String currentUserId;

  _CommunityInfoPage({
    required this.communityName,
    required this.members,
    required this.onLeave,
    required this.isTeacher,
    required this.onRemoveMember,
    required this.creatorId,
    required this.currentUserId,
  });

  @override
  _CommunityInfoPageState createState() => _CommunityInfoPageState();
}

class _CommunityInfoPageState extends State<_CommunityInfoPage> {
  late Map<String, String> _members;

  @override
  void initState() {
    super.initState();
    _members = Map.from(widget.members);
  }

  void _removeMember(String memberId) {
    widget.onRemoveMember(memberId);
    setState(() {
      _members.remove(memberId);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCreator = widget.currentUserId == widget.creatorId;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Community Info', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.communityName,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                String memberId = _members.keys.elementAt(index);
                String memberName = _members[memberId] ?? 'Unknown';
                bool isCreatorMember = memberId == widget.creatorId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(memberName[0].toUpperCase()),
                    backgroundColor: Colors.blue,
                  ),
                  title:
                      Text(memberName, style: TextStyle(color: Colors.white)),
                  trailing: widget.isTeacher && !isCreatorMember
                      ? IconButton(
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _showRemoveMemberDialog(
                              context, memberId, memberName),
                        )
                      : null,
                );
              },
            ),
          ),
          if (!isCreator) // Only show the Leave Community button if the current user is not the creator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                child: Text('Leave Community'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Leave Community'),
                        content: Text(
                            'Are you sure you want to leave this community?'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text('Leave'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onLeave();
                            },
                          ),
                        ],
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

  void _showRemoveMemberDialog(
      BuildContext context, String memberId, String memberName) {
    if (memberId == widget.creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The community creator cannot be removed.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Member'),
          content: Text(
              'Are you sure you want to remove $memberName from the community?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Remove'),
              onPressed: () {
                _removeMember(memberId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
