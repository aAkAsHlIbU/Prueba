import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/staff/teacher_dashboard.dart';
import 'package:incampus/student/edit_profile_page.dart';
import 'package:incampus/student/friends_list_screen.dart';
import 'package:incampus/student/post_detail_screen.dart';
import 'package:incampus/student/reel_detail_screen.dart';
import 'package:incampus/admin/admin_dashboard.dart';
import 'package:incampus/student/verification_screen.dart'; // Add this import

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  Map<String, dynamic> _userProfile = {};
  int _friendsCount = 0;
  bool _postsLoading = true;
  bool _reelsLoading = true;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  // Add new loading state
  bool _profileImageLoaded = false;
  bool _postsImagesLoaded = false;
  bool _reelsImagesLoaded = false;

  // Add image loading tracking
  int _loadedPostImages = 0;
  int _loadedReelImages = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
    _loadUserContent();
    _loadFriendsCount();
  }

  void _loadUserProfile() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('users/$userId');
      userRef.onValue.listen((event) {
        if (event.snapshot.value != null) {
          setState(() {
            _userProfile =
                Map<String, dynamic>.from(event.snapshot.value as Map);
          });
        }
      });
    }
  }

  void _loadUserContent() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference postsRef =
          FirebaseDatabase.instance.ref('posts/$userId');
      DatabaseReference reelsRef =
          FirebaseDatabase.instance.ref('reels/$userId');

      try {
        postsRef.onValue.listen((event) {
          setState(() {
            if (event.snapshot.value != null) {
              _posts = (event.snapshot.value as Map)
                  .entries
                  .map((e) => {
                        'id': e.key,
                        ...Map<String, dynamic>.from(e.value as Map),
                      })
                  .toList();
            } else {
              _posts = [];
            }
            _postsLoading = false;
            _preloadImages(); // Add this line
          });
          print("Posts loaded: ${_posts.length}");
        }, onError: (error) {
          print("Error loading posts: $error");
          setState(() {
            _postsLoading = false;
          });
        });

        reelsRef.onValue.listen((event) {
          setState(() {
            if (event.snapshot.value != null) {
              _reels = (event.snapshot.value as Map)
                  .entries
                  .map((e) => {
                        'id': e.key,
                        ...Map<String, dynamic>.from(e.value as Map),
                      })
                  .toList();
            } else {
              _reels = [];
            }
            _reelsLoading = false;
          });
          print("Reels loaded: ${_reels.length}");
        }, onError: (error) {
          print("Error loading reels: $error");
          setState(() {
            _reelsLoading = false;
          });
        });
      } catch (e) {
        print("Exception in _loadUserContent: $e");
        setState(() {
          _postsLoading = false;
          _reelsLoading = false;
        });
      }
    } else {
      print("User ID is null");
      setState(() {
        _postsLoading = false;
        _reelsLoading = false;
      });
    }
  }

  void _loadFriendsCount() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      DatabaseReference friendsRef =
          FirebaseDatabase.instance.ref('users/$userId/friends');
      friendsRef.onValue.listen((event) {
        if (event.snapshot.value != null) {
          setState(() {
            _friendsCount = (event.snapshot.value as Map).length;
          });
        }
      });
    }
  }

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to the login screen or home screen after logout
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
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
          title: Text(_userProfile['username'] ?? 'Profile',
              style: TextStyle(color: _onSurfaceColor)),
          // Add actions back to include the drawer toggle icon
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: _buildDrawer(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            _buildProfileStats(),
            _buildBio(),
            _buildEditProfileButton(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsGrid(),
                  _buildReelsGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _profileImageLoaded
              ? CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(
                      _userProfile['profilePicture'] ??
                          'https://via.placeholder.com/150'),
                )
              : Container(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(),
                ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _userProfile['name'] ?? 'User Name',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _onSurfaceColor),
                    ),
                    if (_userProfile['isVerified'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child:
                            Icon(Icons.verified, color: Colors.blue, size: 20),
                      ),
                  ],
                ),
                Text(_userProfile['email'] ?? 'email@example.com',
                    style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_posts.length}', 'Posts', 0),
          _buildStatItem('${_reels.length}', 'Reels', 1),
          GestureDetector(
            onTap: () => _showFriendsList(context),
            child: _buildStatItem('$_friendsCount', 'Friends', null),
          ),
        ],
      ),
    );
  }

  void _showFriendsList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FriendsListScreen(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, int? tabIndex) {
    return GestureDetector(
      onTap: tabIndex != null ? () => _tabController.animateTo(tabIndex) : null,
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: _onSurfaceColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: _onSurfaceColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    return Container(
      width: double.infinity, // Ensure the container takes full width
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        _userProfile['bio'] ?? 'No bio available',
        style: TextStyle(color: _onSurfaceColor),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    EditProfilePage(userProfile: _userProfile)),
          );
          if (result == true) {
            // Refresh the profile data if changes were made
            _loadUserProfile();
          }
        },
        child: Text('Edit Profile'),
        style: ElevatedButton.styleFrom(
          foregroundColor: _onSurfaceColor,
          backgroundColor: _accentColor,
          minimumSize: Size(double.infinity, 36),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: [
        Tab(icon: Icon(Icons.grid_on)),
        Tab(icon: Icon(Icons.video_library)),
      ],
    );
  }

  Widget _buildPostsGrid() {
    if (_postsLoading || !_postsImagesLoaded) {
      return Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return Center(child: Text('No posts yet'));
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
                  userId: FirebaseAuth.instance.currentUser?.uid ??
                      '', // Add this line
                ),
              ),
            );
          },
          child: Image.network(
            _posts[index]['imageUrl'],
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    if (_reelsLoading || !_reelsImagesLoaded) {
      return Center(child: CircularProgressIndicator());
    }
    if (_reels.isEmpty) {
      return Center(child: Text('No reels yet'));
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
            _openReelsViewer(index);
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

  void _openReelsViewer(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelDetailScreen(
          reelId: _reels[startIndex]['id'],
          videoUrl: _reels[startIndex]['videoUrl'] ?? '',
          uploaderId: FirebaseAuth.instance.currentUser?.uid ?? '',
          description: _reels[startIndex]['description'] ?? '',
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: _primaryColor,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: _onSurfaceColor,
                fontSize: 24,
              ),
            ),
          ),
          if (_userProfile['role'] == 'admin')
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: _onSurfaceColor),
              title: Text('Admin Dashboard',
                  style: TextStyle(color: _onSurfaceColor)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminDashboard()),
                );
              },
            ),
          if (_userProfile['role'] == 'Teacher')
            ListTile(
              leading: Icon(Icons.school, color: _onSurfaceColor),
              title: Text('Teacher Dashboard',
                  style: TextStyle(color: _onSurfaceColor)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TeacherDashboard()),
                );
              },
            ),
          ListTile(
            leading: Icon(Icons.verified, color: _onSurfaceColor),
            title:
                Text('Get Verified', style: TextStyle(color: _onSurfaceColor)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VerificationScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: _onSurfaceColor),
            title: Text('Logout', style: TextStyle(color: _onSurfaceColor)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // Add new method to preload images
  Future<void> _preloadImages() async {
    // Preload profile image
    if (_userProfile['profilePicture'] != null) {
      final profileImageProvider =
          NetworkImage(_userProfile['profilePicture']!);
      await precacheImage(profileImageProvider, context);
      setState(() => _profileImageLoaded = true);
    } else {
      setState(() => _profileImageLoaded = true);
    }

    // Preload post images
    _loadedPostImages = 0;
    for (var post in _posts) {
      final imageProvider = NetworkImage(post['imageUrl']);
      await precacheImage(imageProvider, context);
      setState(() {
        _loadedPostImages++;
        if (_loadedPostImages == _posts.length) {
          _postsImagesLoaded = true;
        }
      });
    }
    if (_posts.isEmpty) {
      setState(() => _postsImagesLoaded = true);
    }

    // Preload reel thumbnails
    _loadedReelImages = 0;
    for (var reel in _reels) {
      if (reel['thumbnailUrl'] != null) {
        final imageProvider = NetworkImage(reel['thumbnailUrl']);
        await precacheImage(imageProvider, context);
        setState(() {
          _loadedReelImages++;
          if (_loadedReelImages == _reels.length) {
            _reelsImagesLoaded = true;
          }
        });
      }
    }
    if (_reels.isEmpty) {
      setState(() => _reelsImagesLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
