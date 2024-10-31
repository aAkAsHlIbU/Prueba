import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:incampus/student/user_profile_page.dart';
import 'package:incampus/student/profile_page.dart';

class ReelsPage extends StatefulWidget {
  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _reels = [];
  bool _isLoading = false;
  int _currentIndex = 0;
  late PageController _pageController;
  int _batchSize = 5;
  int _initialLoadSize = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialReels() async {
    await _loadReels(_initialLoadSize);
    if (_reels.isNotEmpty) {
      _loadMoreReels();
    }
  }

  Future<void> _loadMoreReels() async {
    await _loadReels(_batchSize);
  }

  Future<void> _loadReels(int count) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      DatabaseEvent usersEvent = await _database.child('users').once();
      Map<dynamic, dynamic> users =
          usersEvent.snapshot.value as Map<dynamic, dynamic>;

      List<Map<String, dynamic>> newReels = [];

      for (var entry in users.entries) {
        Map<dynamic, dynamic> userData = entry.value as Map<dynamic, dynamic>;
        if (userData['isPublic'] == true && userData['role'] == 'Student') {
          DatabaseEvent reelsEvent =
              await _database.child('reels/${entry.key}').once();
          if (reelsEvent.snapshot.value != null) {
            Map<dynamic, dynamic> userReels =
                reelsEvent.snapshot.value as Map<dynamic, dynamic>;
            userReels.forEach((reelId, reelData) {
              newReels.add({
                'id': reelId,
                'userId': entry.key,
                'userName': userData['name'],
                'userProfilePicture': userData['profilePicture'],
                'isPublic': userData['isPublic'] ?? false,
                'userDepartment': userData['department'] ?? 'No department',
                'userBio': userData['bio'] ?? 'No bio available',
                'userIsVerified': userData['isVerified'] ?? false,
                ...Map<String, dynamic>.from(reelData as Map),
              });
            });
          }
        }
      }

      // Sort reels by timestamp (most recent first)
      newReels
          .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      // Limit the number of new reels added
      int startIndex = _reels.length;
      int endIndex = startIndex + count;
      if (endIndex > newReels.length) {
        endIndex = newReels.length;
      }

      setState(() {
        _reels.addAll(newReels.sublist(startIndex, endIndex));
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reels: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _reels.isEmpty
          ? Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index >= _reels.length - 3) {
                  _loadMoreReels();
                }
              },
              itemBuilder: (context, index) {
                return ReelItem(
                  reel: _reels[index],
                  currentUserId: _currentUserId,
                );
              },
            ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final String currentUserId;

  ReelItem({required this.reel, required this.currentUserId});

  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  VideoPlayerController? _nextController;
  bool _isPlaying = true;
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    // Initialize current video controller
    _controller = VideoPlayerController.network(widget.reel['videoUrl']);

    // Wait for current video to initialize
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });
    _controller.play();
    _controller.setLooping(true);

    // Immediately start loading next video if available
    if (widget.reel['nextVideoUrl'] != null) {
      _nextController =
          VideoPlayerController.network(widget.reel['nextVideoUrl'])
            ..initialize().then((_) {
              // Preload the video by starting and immediately pausing it
              _nextController?.play();
              _nextController?.pause();
            });
    }
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video URL changes, reinitialize controllers
    if (oldWidget.reel['videoUrl'] != widget.reel['videoUrl']) {
      _disposeControllers();
      _initializeControllers();
    }
  }

  void _disposeControllers() {
    _controller.dispose();
    _nextController?.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _handleLike() {
    DatabaseReference reelRef = FirebaseDatabase.instance
        .ref('reels/${widget.reel['userId']}/${widget.reel['id']}');

    setState(() {
      if (_isLiked) {
        _likeCount--;
        reelRef.child('likes').set(ServerValue.increment(-1));
        reelRef.child('likedBy/${widget.currentUserId}').remove();
      } else {
        _likeCount++;
        reelRef.child('likes').set(ServerValue.increment(1));
        reelRef.child('likedBy/${widget.currentUserId}').set(true);
      }
      _isLiked = !_isLiked;
    });
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        reelId: widget.reel['id'],
        uploaderId: widget.reel['userId'],
      ),
    );
  }

  void _openUserProfile() async {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (widget.reel['userId'] == currentUserId) {
      // If it's the current user's reel, navigate to ProfilePage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(),
        ),
      );
    } else {
      // Check if the current user is friends with the reel creator
      bool areFriends = await _checkFriendship(widget.reel['userId']);

      // If it's another user's reel, navigate to UserProfilePage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(
            user: {
              'uid': widget.reel['userId'],
              'name': widget.reel['userName'],
              'profilePicture': widget.reel['userProfilePicture'],
              'isPublic': widget.reel['isPublic'] ?? false,
              'department': widget.reel['userDepartment'] ?? 'No department',
              'bio': widget.reel['userBio'] ?? 'No bio available',
              'isVerified': widget.reel['userIsVerified'] ?? false,
            },
            isFriend: areFriends,
            onFriendStatusChanged: _handleFriendStatusChanged,
          ),
        ),
      );
    }
  }

  Future<bool> _checkFriendship(String userId) async {
    DatabaseEvent event = await FirebaseDatabase.instance
        .ref('users')
        .child(widget.currentUserId)
        .child('friends')
        .child(userId)
        .once();
    return event.snapshot.value == true;
  }

  void _handleFriendStatusChanged(String userId, bool isFriend) {
    // You might want to update the local state or refresh the reel data
    // if the friendship status changes
    setState(() {
      // Update local state if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _handleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Center(child: CircularProgressIndicator()),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video controls (optional)
        Container(
          color: Colors.transparent,
        ),

        // Bottom overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username and profile picture
                GestureDetector(
                  onTap: _openUserProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            NetworkImage(widget.reel['userProfilePicture']),
                      ),
                      SizedBox(width: 8),
                      Text(
                        widget.reel['userName'],
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      if (widget.reel['userIsVerified'] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified,
                              color: Colors.blue, size: 16),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Description
                Text(
                  widget.reel['description'] ?? '',
                  style: TextStyle(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        // Right side icons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  size: 32,
                ),
                onPressed: _handleLike,
              ),
              Text(
                '$_likeCount',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 16),
              IconButton(
                icon: Icon(Icons.comment, color: Colors.white, size: 32),
                onPressed: _showComments,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final String reelId;
  final String uploaderId;

  CommentsBottomSheet({required this.reelId, required this.uploaderId});

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    DatabaseEvent event = await _database
        .child('reels/${widget.uploaderId}/${widget.reelId}/comments')
        .once();

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> commentsData =
          event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _comments = commentsData.entries.map((entry) {
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          };
        }).toList();
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isNotEmpty) {
      DatabaseReference commentRef = _database
          .child('reels/${widget.uploaderId}/${widget.reelId}/comments')
          .push();

      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$_currentUserId');
      DatabaseEvent userEvent = await userRef.once();
      Map<dynamic, dynamic>? userData = userEvent.snapshot.value as Map?;
      String username = userData?['name'] ?? 'Anonymous';

      await commentRef.set({
        'userId': _currentUserId,
        'username': username,
        'comment': _commentController.text,
        'timestamp': ServerValue.timestamp,
      });

      _commentController.clear();
      _loadComments();
      FocusScope.of(context).unfocus();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _comments[index]['comment'],
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${_comments[index]['username']} • ${_formatTimestamp(_comments[index]['timestamp'])}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[500]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.white),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
