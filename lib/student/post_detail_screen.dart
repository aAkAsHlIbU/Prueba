// ignore_for_file: prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;
  final String userId;

  PostDetailScreen(
      {required this.postId, required this.post, required this.userId});

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  int _likes = 0;
  bool _isLiked = false;
  TextEditingController _commentController = TextEditingController();
  late String _currentUserId;
  Map<String, dynamic> _currentUserDetails = {};
  Map<String, dynamic> _postOwnerDetails = {};
  bool _isOriginalAspectRatio = false;
  bool _canEditDelete = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUserDetails();
    _loadPostOwnerDetails();
    _loadComments();
    _loadLikes();
    _checkEditDeletePermission();
  }

  void _loadUserDetails() {
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/$_currentUserId');
    userRef.once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _currentUserDetails =
              Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  void _loadPostOwnerDetails() {
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${widget.userId}');
    userRef.once().then((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        setState(() {
          _postOwnerDetails =
              Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  void _loadComments() {
    DatabaseReference commentsRef =
        FirebaseDatabase.instance.ref('comments/${widget.postId}');
    commentsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        List<Map<String, dynamic>> tempComments = [];
        Map<dynamic, dynamic> commentsMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        commentsMap.forEach((key, value) {
          tempComments.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map),
          });
        });
        setState(() {
          _comments = tempComments;
        });
      }
    });
  }

  void _loadLikes() {
    DatabaseReference likesRef =
        FirebaseDatabase.instance.ref('likes/${widget.postId}');
    likesRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _likes = (event.snapshot.value as Map).length;
          _isLiked = (event.snapshot.value as Map).containsKey(_currentUserId);
        });
      } else {
        setState(() {
          _likes = 0;
          _isLiked = false;
        });
      }
    });
  }

  void _toggleLike() {
    DatabaseReference likeRef =
        FirebaseDatabase.instance.ref('likes/${widget.postId}/$_currentUserId');
    if (_isLiked) {
      likeRef.remove();
    } else {
      likeRef.set(true);
    }
  }

  void _addComment() {
    if (_commentController.text.isNotEmpty) {
      DatabaseReference commentRef =
          FirebaseDatabase.instance.ref('comments/${widget.postId}').push();
      commentRef.set({
        'userId': _currentUserId,
        'text': _commentController.text,
        'timestamp': ServerValue.timestamp,
      });
      _commentController.clear();
    }
  }

  void _checkEditDeletePermission() async {
    if (_currentUserId == widget.userId) {
      setState(() {
        _canEditDelete = true;
      });
    } else {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$_currentUserId');
      DatabaseEvent event = await userRef.once();
      Map<dynamic, dynamic>? userData = event.snapshot.value as Map?;

      if (userData != null &&
          userData['role'] == 'Teacher' &&
          userData['isClassTeacher'] == true) {
        DatabaseReference postOwnerRef =
            FirebaseDatabase.instance.ref('users/${widget.userId}');
        DatabaseEvent postOwnerEvent = await postOwnerRef.once();
        Map<dynamic, dynamic>? postOwnerData =
            postOwnerEvent.snapshot.value as Map?;

        if (postOwnerData != null &&
            postOwnerData['classTeacher'] == _currentUserId) {
          setState(() {
            _canEditDelete = true;
          });
        }
      }
    }
  }

  void _showOptionsMenu() {
    if (!_canEditDelete) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Description'),
                onTap: () {
                  Navigator.pop(context);
                  _editDescription();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editDescription() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newDescription = widget.post['description'] ?? '';
        return AlertDialog(
          title: Text('Edit Description'),
          content: TextField(
            onChanged: (value) {
              newDescription = value;
            },
            controller: TextEditingController(text: newDescription),
            decoration: InputDecoration(hintText: "Enter new description"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseDatabase.instance
                      .ref('posts/${widget.userId}/${widget.postId}')
                      .update({'description': newDescription});
                  setState(() {
                    widget.post['description'] = newDescription;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Description updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update description')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Post'),
          content: Text('Are you sure you want to delete this post?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                try {
                  // Delete the post from the database
                  await FirebaseDatabase.instance
                      .ref('posts/${widget.userId}/${widget.postId}')
                      .remove();

                  // Delete the image from storage
                  await FirebaseStorage.instance
                      .refFromURL(widget.post['imageUrl'])
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Post deleted successfully')),
                  );

                  // Navigate back to the previous screen (likely the profile screen)
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete post')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundImage:
                    NetworkImage(_postOwnerDetails['profilePicture'] ?? ''),
                radius: 16,
                backgroundColor: Colors.grey,
              ),
              SizedBox(width: 8),
              Text(_postOwnerDetails['name'] ?? 'User'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                  _isOriginalAspectRatio ? Icons.crop_square : Icons.crop_3_2),
              onPressed: () {
                setState(() {
                  _isOriginalAspectRatio = !_isOriginalAspectRatio;
                });
              },
            ),
            if (_canEditDelete)
              IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: _showOptionsMenu,
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isOriginalAspectRatio
                  ? Image.network(
                      widget.post['imageUrl'],
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(
                        widget.post['imageUrl'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border),
                      color: _isLiked ? Colors.red : Colors.white,
                      onPressed: _toggleLike,
                    ),
                    IconButton(
                      icon: Icon(Icons.mode_comment_outlined),
                      color: Colors.white,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_likes likes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                              text: _postOwnerDetails['name'] ?? 'User',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_postOwnerDetails['isVerified'] == true)
                            WidgetSpan(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.verified, color: Colors.blue, size: 16),
                              ),
                            ),
                          TextSpan(
                              text: ' ${widget.post['description'] ?? ''}'),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('View all ${_comments.length} comments',
                        style: TextStyle(color: Colors.white54)),
                    SizedBox(height: 8),
                    Text(_getTimeAgo(widget.post['timestamp'] as int),
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Divider(color: Colors.white24),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  return FutureBuilder(
                    future: FirebaseDatabase.instance
                        .ref('users/${_comments[index]['userId']}')
                        .once(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListTile(title: Text('Loading...'));
                      }
                      if (snapshot.hasError) {
                        return ListTile(title: Text('Error loading comment'));
                      }
                      if (snapshot.hasData) {
                        DatabaseEvent event = snapshot.data as DatabaseEvent;
                        Map<dynamic, dynamic> userData =
                            event.snapshot.value as Map<dynamic, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage(userData['profilePicture'] ?? ''),
                            radius: 12,
                          ),
                          title: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.white),
                              children: [
                                TextSpan(
                                    text: userData['name'] ?? 'User',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: ' ${_comments[index]['text']}'),
                              ],
                            ),
                          ),
                          subtitle: Text(
                            _getTimeAgo(_comments[index]['timestamp'] as int),
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        );
                      }
                      return ListTile(title: Text('No data'));
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                          _currentUserDetails['profilePicture'] ?? ''),
                      radius: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _addComment,
                      child: Text('Post', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final difference =
        now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
