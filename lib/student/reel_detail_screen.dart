// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReelDetailScreen extends StatefulWidget {
  final String reelId;
  final String videoUrl;
  final String uploaderId;
  String description;

  ReelDetailScreen({
    required this.reelId,
    required this.videoUrl,
    required this.uploaderId,
    required this.description,
  });

  @override
  _ReelDetailScreenState createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;
  bool isLiked = false;
  int likeCount = 0;
  List<Map<String, dynamic>> comments = [];
  String uploaderName = '';
  String uploaderProfileUrl = '';
  TextEditingController _commentController = TextEditingController();
  late String currentUserId;
  bool canEditDelete = false;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
    _loadReelData();
    _checkEditDeletePermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadReelData() async {
    DatabaseReference reelRef = FirebaseDatabase.instance
        .ref('reels/${widget.uploaderId}/${widget.reelId}');
    DatabaseReference userRef =
        FirebaseDatabase.instance.ref('users/${widget.uploaderId}');

    try {
      DatabaseEvent reelEvent = await reelRef.once();
      DatabaseEvent userEvent = await userRef.once();

      Map<dynamic, dynamic>? reelData = reelEvent.snapshot.value as Map?;
      Map<dynamic, dynamic>? userData = userEvent.snapshot.value as Map?;

      if (reelData != null && userData != null) {
        setState(() {
          likeCount = reelData['likes'] ?? 0;
          isLiked = (reelData['likedBy'] as Map?)
                  ?.containsKey(FirebaseAuth.instance.currentUser?.uid) ??
              false;

          if (reelData['comments'] != null) {
            comments = (reelData['comments'] as Map)
                .entries
                .map((e) => {
                      'id': e.key,
                      ...Map<String, dynamic>.from(e.value as Map),
                    })
                .toList();
          }

          uploaderName = userData['name'] ?? '';
          uploaderProfileUrl = userData['profilePicture'] ??
              ''; // Changed from 'profilePictureUrl' to 'profilePicture'
        });
      }
    } catch (e) {
      print('Error loading reel data: $e');
    }
  }

  void _checkEditDeletePermission() async {
    if (currentUserId == widget.uploaderId) {
      setState(() {
        canEditDelete = true;
      });
    } else {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$currentUserId');
      DatabaseEvent event = await userRef.once();
      Map<dynamic, dynamic>? userData = event.snapshot.value as Map?;

      if (userData != null &&
          userData['role'] == 'Teacher' &&
          userData['isClassTeacher'] == true) {
        DatabaseReference uploaderRef =
            FirebaseDatabase.instance.ref('users/${widget.uploaderId}');
        DatabaseEvent uploaderEvent = await uploaderRef.once();
        Map<dynamic, dynamic>? uploaderData =
            uploaderEvent.snapshot.value as Map?;

        if (uploaderData != null &&
            uploaderData['classTeacher'] == currentUserId) {
          setState(() {
            canEditDelete = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Video player
          GestureDetector(
            onTap: () {
              setState(() {
                _isPlaying = !_isPlaying;
                _isPlaying ? _controller.play() : _controller.pause();
              });
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: _controller.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : Center(child: CircularProgressIndicator()),
            ),
          ),
          // Overlay content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Reel',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    canEditDelete
                        ? IconButton(
                            icon: Icon(Icons.more_vert, color: Colors.white),
                            onPressed: _showOptionsMenu,
                          )
                        : SizedBox(width: 48), // Placeholder to maintain layout
                  ],
                ),
                // Bottom content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Reel info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              uploaderName,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (widget.description.isNotEmpty)
                              Text(
                                widget.description,
                                style: TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Like and comment buttons
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInteractionButton(
                            icon: isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                            count: likeCount,
                            onTap: () => _handleLike(context),
                          ),
                          SizedBox(height: 16),
                          _buildInteractionButton(
                            icon: Icons.comment,
                            color: Colors.white,
                            count: comments.length,
                            onTap: () => _showComments(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 32),
          onPressed: onTap,
        ),
        Text(
          '$count',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  void _handleLike(BuildContext context) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference reelRef = FirebaseDatabase.instance
          .ref('reels/${widget.uploaderId}/${widget.reelId}');

      try {
        DatabaseEvent event = await reelRef.once();
        Map<dynamic, dynamic>? reelData = event.snapshot.value as Map?;

        if (reelData != null) {
          Map<String, dynamic> likedBy =
              Map<String, dynamic>.from(reelData['likedBy'] ?? {});

          if (likedBy.containsKey(userId)) {
            likedBy.remove(userId);
            await reelRef.update({
              'likes': ServerValue.increment(-1),
              'likedBy': likedBy,
            });
            setState(() {
              isLiked = false;
              likeCount--;
            });
          } else {
            likedBy[userId] = true;
            await reelRef.update({
              'likes': ServerValue.increment(1),
              'likedBy': likedBy,
            });
            setState(() {
              isLiked = true;
              likeCount++;
            });
          }
        }
      } catch (e) {
        print('Error updating like count: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like. Please try again.')),
        );
      }
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.75,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(comments[index]['comment']),
                      subtitle: Text(
                          '${comments[index]['username']} • ${_formatTimestamp(comments[index]['timestamp'])}'),
                    );
                  },
                ),
              ),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () => _addComment(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addComment(BuildContext context) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && _commentController.text.isNotEmpty) {
      DatabaseReference reelRef = FirebaseDatabase.instance
          .ref('reels/${widget.uploaderId}/${widget.reelId}/comments');
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$userId');

      try {
        DatabaseEvent userEvent = await userRef.once();
        Map<dynamic, dynamic>? userData = userEvent.snapshot.value as Map?;
        String username = userData?['name'] ?? 'Anonymous';

        String commentId = reelRef.push().key ??
            DateTime.now().millisecondsSinceEpoch.toString();
        await reelRef.child(commentId).set({
          'userId': userId,
          'username': username,
          'comment': _commentController.text,
          'timestamp': ServerValue.timestamp,
        });

        // Refresh comments
        _loadReelData();

        // Clear the comment input field
        _commentController.clear();

        // Close the keyboard
        FocusScope.of(context).unfocus();
      } catch (e) {
        print('Error adding comment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment. Please try again.')),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showOptionsMenu() {
    if (!canEditDelete) return;

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
                title: Text('Delete Reel'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteReel();
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
        String newDescription = widget.description;
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
                      .ref('reels/${widget.uploaderId}/${widget.reelId}')
                      .update({'description': newDescription});
                  setState(() {
                    widget.description = newDescription;
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

  void _deleteReel() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Reel'),
          content: Text('Are you sure you want to delete this reel?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  // Reference to the reel in the database
                  DatabaseReference reelRef = FirebaseDatabase.instance
                      .ref('reels/${widget.uploaderId}/${widget.reelId}');

                  // Get the reel data
                  DatabaseEvent event = await reelRef.once();
                  Map<dynamic, dynamic>? reelData =
                      event.snapshot.value as Map?;

                  if (reelData != null) {
                    // Delete the video from storage
                    String videoUrl = reelData['videoUrl'];
                    await FirebaseStorage.instance
                        .refFromURL(videoUrl)
                        .delete();

                    // Delete the thumbnail from storage if it exists
                    if (reelData.containsKey('thumbnailUrl')) {
                      String thumbnailUrl = reelData['thumbnailUrl'];
                      await FirebaseStorage.instance
                          .refFromURL(thumbnailUrl)
                          .delete();
                    }

                    // Delete the reel from the database
                    await reelRef.remove();

                    // Use a post-frame callback to pop the screen
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(context).pop(true);
                      }
                    });
                  } else {
                    throw Exception('Reel data not found');
                  }
                } catch (e) {
                  print('Error deleting reel: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to delete reel. Please try again.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
