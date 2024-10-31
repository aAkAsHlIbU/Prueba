import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/student/user_profile_page.dart';

class FriendsListScreen extends StatefulWidget {
  final String userId;

  FriendsListScreen({required this.userId});

  @override
  _FriendsListScreenState createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _friends = [];

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    _database.child('users/${widget.userId}/friends').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> friendsMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        friendsMap.forEach((key, value) {
          _database.child('users/$key').once().then((DatabaseEvent userEvent) {
            if (userEvent.snapshot.value != null) {
              Map<dynamic, dynamic> userData =
                  userEvent.snapshot.value as Map<dynamic, dynamic>;
              setState(() {
                _friends.add({
                  'id': key,
                  'name': userData['name'] ?? 'Unknown',
                  'profilePicture': userData['profilePicture'] ?? '',
                });
              });
            }
          });
        });
      }
    });
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
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Friends', style: TextStyle(color: _onSurfaceColor)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _onSurfaceColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _friends.isEmpty
            ? Center(
                child: Text(
                  'No friends yet',
                  style: TextStyle(color: _onSurfaceColor, fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(friend['profilePicture'] ??
                          'https://via.placeholder.com/150'),
                    ),
                    title: Text(
                      friend['name'],
                      style: TextStyle(color: _onSurfaceColor),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfilePage(
                            user: friend,
                            isFriend: true,
                            onFriendStatusChanged: (_, __) {},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
