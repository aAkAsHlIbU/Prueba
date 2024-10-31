import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:incampus/student/user_profile_page.dart';

class ForYouPage extends StatefulWidget {
  @override
  _ForYouPageState createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    _database.child('users').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _users = (event.snapshot.value as Map<dynamic, dynamic>)
              .entries
              .where((entry) =>
                  entry.key != _currentUserId &&
                  (entry.value as Map)['role'] != 'admin')
              .map((entry) => {
                    'id': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map),
                  })
              .toList();
          _filterAndSortUsers();
        });
      }
    });
  }

  void _filterAndSortUsers() {
    setState(() {
      _filteredUsers = _users
          .where((user) =>
              user['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      _filteredUsers.sort((a, b) {
        switch (_sortBy) {
          case 'name':
            return a['name'].compareTo(b['name']);
          case 'department':
            return a['department'].compareTo(b['department']);
          default:
            return 0;
        }
      });
    });
  }

  void _viewUserProfile(Map<String, dynamic> user) async {
    bool areFriends = await _checkFriendship(user['id']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          user: {
            'uid': user['id'],
            'name': user['name'],
            'isPublic': user['isPublic'] ?? false,
            ...user,
          },
          isFriend: areFriends,
          onFriendStatusChanged: _handleFriendStatusChanged,
        ),
      ),
    );
  }

  Future<bool> _checkFriendship(String userId) async {
    DatabaseEvent event = await _database
        .child('users')
        .child(_currentUserId)
        .child('friends')
        .child(userId)
        .once();
    return event.snapshot.value == true;
  }

  void _handleFriendStatusChanged(String userId, bool isFriend) {
    setState(() {
      int index = _filteredUsers.indexWhere((user) => user['id'] == userId);
      if (index != -1) {
        _filteredUsers[index]['isFriend'] = isFriend;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('For You', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _filterAndSortUsers();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'name',
                child: Text('Sort by Name'),
              ),
              PopupMenuItem<String>(
                value: 'department',
                child: Text('Sort by Department'),
              ),
            ],
            color: Colors.grey[900],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterAndSortUsers();
                });
              },
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Search Users',
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['profilePicture'] ??
                        'https://via.placeholder.com/150'),
                  ),
                  title: Row(
                    children: [
                      Text(user['name'], style: TextStyle(color: Colors.white)),
                      if (user['isVerified'] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified, color: Colors.blue, size: 16),
                        ),
                    ],
                  ),
                  subtitle: Text(user['department'] ?? 'No department',
                      style: TextStyle(color: Colors.grey)),
                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () => _viewUserProfile(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
