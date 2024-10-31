import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:incampus/student/post_detail_screen.dart';
import 'package:incampus/student/reel_detail_screen.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isFriend;
  final bool isClassTeacher; // Add this line
  final Function(String, bool) onFriendStatusChanged;

  UserProfilePage({
    required this.user,
    required this.isFriend,
    this.isClassTeacher = false, // Add this line
    required this.onFriendStatusChanged,
  });

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isFriend = false;
  bool _requestSent = false;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  bool _isLoading = true;
  bool _isPublic = false;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  // Add this new property
  late RefreshController _refreshController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isFriend = widget.isFriend;
    _isPublic = widget.user['isPublic'] ?? false;
    _loadUserContent();
    _checkFriendRequestStatus();
    
    // Initialize the RefreshController
    _refreshController = RefreshController(initialRefresh: false);
  }

  void _checkFriendRequestStatus() async {
    DatabaseEvent event = await _database
        .child('users/${widget.user['uid']}/friendRequests/$_currentUserId')
        .once();
    setState(() {
      _requestSent = event.snapshot.value != null;
    });
  }

  void _loadUserContent() async {
    setState(() {
      _isLoading = true;
    });

    // Load content if the user is a friend, the profile is public, or the viewer is the class teacher
    if (_isFriend || _isPublic || widget.isClassTeacher) {
      // Load posts
      DatabaseEvent postsEvent =
          await _database.child('posts').child(widget.user['uid']).once();

      if (postsEvent.snapshot.value != null) {
        Map<dynamic, dynamic> postsMap =
            postsEvent.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> newPosts = postsMap.entries
            .map((entry) => {
                  'id': entry.key,
                  ...Map<String, dynamic>.from(entry.value as Map)
                })
            .toList();

        // Sort posts by timestamp (most recent first)
        newPosts.sort(
            (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        setState(() {
          _posts = newPosts;
        });
      }

      // Load reels
      DatabaseEvent reelsEvent =
          await _database.child('reels').child(widget.user['uid']).once();

      if (reelsEvent.snapshot.value != null) {
        Map<dynamic, dynamic> reelsMap =
            reelsEvent.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> newReels = reelsMap.entries
            .map((entry) => {
                  'id': entry.key,
                  ...Map<String, dynamic>.from(entry.value as Map)
                })
            .toList();

        // Sort reels by timestamp (most recent first)
        newReels.sort(
            (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        setState(() {
          _reels = newReels;
        });
      }
    } else {
      // If not a friend and the profile is private, clear the posts and reels
      setState(() {
        _posts = [];
        _reels = [];
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _toggleFriendship() async {
    if (_isFriend) {
      await _database
          .child('users')
          .child(_currentUserId)
          .child('friends')
          .child(widget.user['uid'])
          .remove();
      await _database
          .child('users')
          .child(widget.user['uid'])
          .child('friends')
          .child(_currentUserId)
          .remove();
    } else {
      await _database
          .child('users')
          .child(_currentUserId)
          .child('friends')
          .child(widget.user['uid'])
          .set(true);
      await _database
          .child('users')
          .child(widget.user['uid'])
          .child('friends')
          .child(_currentUserId)
          .set(true);
    }

    setState(() {
      _isFriend = !_isFriend;
    });
    widget.onFriendStatusChanged(widget.user['uid'], _isFriend);
    _loadUserContent(); // Reload content after friendship status change
  }

  void _sendFriendRequest() async {
    await _database
        .child('users/${widget.user['uid']}/friendRequests/$_currentUserId')
        .set(true);
    setState(() {
      _requestSent = true;
    });
  }

  // Add this new method
  void _onRefresh() async {
    _loadUserContent();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: _primaryColor,
        hintColor: _accentColor,
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          elevation: 0,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: _accentColor,
          unselectedLabelColor: _onSurfaceColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.user['name'],
              style: TextStyle(color: _onSurfaceColor)),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SmartRefresher(
                controller: _refreshController,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      _buildProfileStats(),
                      _buildBio(),
                      _buildFriendshipButton(),
                      if (_isFriend || _isPublic || widget.isClassTeacher) ...[
                        TabBar(
                          controller: _tabController,
                          tabs: [
                            Tab(icon: Icon(Icons.grid_on)),
                            Tab(icon: Icon(Icons.video_library)),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height *
                              0.5, // Adjust this value as needed
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPostsGrid(),
                              _buildReelsGrid(),
                            ],
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'This profile is private. Add as a friend to see posts and reels.',
                            style: TextStyle(color: _onSurfaceColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(widget.user['profilePicture'] ??
                'https://via.placeholder.com/150'),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.user['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _onSurfaceColor,
                      ),
                    ),
                    if (widget.user['isVerified'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.verified, color: Colors.blue, size: 20),
                      ),
                  ],
                ),
                Text(widget.user['department'] ?? 'No department',
                    style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats() {
    return FutureBuilder<DataSnapshot>(
      future: _database.child('users/${widget.user['uid']}/friends').get(),
      builder: (context, snapshot) {
        int friendCount = snapshot.hasData ? snapshot.data!.children.length : 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatColumn(_posts.length.toString(), 'Posts'),
            _buildStatColumn(friendCount.toString(), 'Friends'),
          ],
        );
      },
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _onSurfaceColor)),
        Text(label, style: TextStyle(color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildBio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        widget.user['bio'] ?? 'No bio available',
        style: TextStyle(color: _onSurfaceColor),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildFriendshipButton() {
    if (_isFriend) {
      return ElevatedButton(
        onPressed: _toggleFriendship,
        child: Text('Unfriend'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red,
          minimumSize: Size(double.infinity, 36),
        ),
      );
    } else if (_requestSent) {
      return ElevatedButton(
        onPressed: null, // Disable the button when request is pending
        child: Text('Pending Request'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.grey,
          minimumSize: Size(double.infinity, 36),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _sendFriendRequest,
        child: Text('Add Friend'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          minimumSize: Size(double.infinity, 36),
        ),
      );
    }
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
      return Center(
          child: Text('No posts available',
              style: TextStyle(color: _onSurfaceColor)));
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: _posts[index]['id'],
                  post: _posts[index],
                  userId: widget.user['uid'],
                ),
              ),
            );
          },
          child: Image.network(
            _posts[index]['imageUrl'],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey,
                child: Icon(Icons.error, color: Colors.white),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    if (_reels.isEmpty) {
      return Center(
          child: Text('No reels available',
              style: TextStyle(color: _onSurfaceColor)));
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelDetailScreen(
                  reelId: _reels[index]['id'],
                  videoUrl: _reels[index]['videoUrl'] ?? '',
                  uploaderId: widget.user['uid'],
                  description: _reels[index]['description'] ?? '',
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                _reels[index]['thumbnailUrl'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey,
                    child: Icon(Icons.error, color: Colors.white),
                  );
                },
              ),
              Center(
                child: Icon(Icons.play_circle_outline,
                    size: 40, color: _accentColor),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose(); // Add this line
    super.dispose();
  }
}
