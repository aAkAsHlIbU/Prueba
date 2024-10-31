// lib/student/communities_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:incampus/student/community_chat_page.dart';

class CommunitiesPage extends StatefulWidget {
  @override
  _CommunitiesPageState createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _filteredCommunities = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  void _loadCommunities() {
    _database.child('communities').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _communities = (event.snapshot.value as Map<dynamic, dynamic>)
              .entries
              .map((entry) => {
                    'id': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map),
                  })
              .toList();
          _filterCommunities();
        });
      }
    });
  }

  void _filterCommunities() {
    setState(() {
      _filteredCommunities = _communities
          .where((community) => community['name']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    });
  }

  void _joinCommunity(String communityId) {
    _database
        .child('communities/$communityId/members/$_currentUserId')
        .set(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joined community successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Communities'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterCommunities();
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Communities',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCommunities.length,
              itemBuilder: (context, index) {
                final community = _filteredCommunities[index];
                return ListTile(
                  title: Text(community['name']),
                  subtitle: Text(community['description']),
                  trailing: ElevatedButton(
                    child: Text('Join'),
                    onPressed: () => _joinCommunity(community['id']),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommunityChatPage(
                          communityId: community['id'],
                          communityName: community['name'],
                        ),
                      ),
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
}

