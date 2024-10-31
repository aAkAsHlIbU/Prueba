import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/staff/community_management_page.dart';

class CommunitiesPage extends StatefulWidget {
  @override
  _CommunitiesPageState createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _communities = [];

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  void _loadCommunities() {
    final String currentUserUid = _auth.currentUser!.uid;
    _database
        .child('communities')
        .orderByChild('createdBy')
        .equalTo(currentUserUid)
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> values = event.snapshot.value as Map;
        setState(() {
          _communities = values.entries
              .map((entry) => {
                    'id': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map),
                  })
              .toList();
        });
      }
    });
  }

  void _createCommunity() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String communityName = '';
        String communityDescription = '';
        return AlertDialog(
          title: Text('Create Community'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(hintText: "Community Name"),
                onChanged: (value) => communityName = value,
              ),
              TextField(
                decoration: InputDecoration(hintText: "Community Description"),
                onChanged: (value) => communityDescription = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Create'),
              onPressed: () {
                if (communityName.isNotEmpty) {
                  final newCommunityRef = _database.child('communities').push();
                  final newCommunityId = newCommunityRef.key;
                  newCommunityRef.set({
                    'name': communityName,
                    'description': communityDescription,
                    'createdBy': _auth.currentUser!.uid,
                    'createdAt': ServerValue.timestamp,
                    'members': {_auth.currentUser!.uid: true}
                  });

                  _database
                      .child(
                          'users/${_auth.currentUser!.uid}/communities/$newCommunityId')
                      .set(true);

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Community created successfully')),
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
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _createCommunity,
            child: Text('Create Community'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _communities.length,
              itemBuilder: (context, index) {
                final community = _communities[index];
                final bool isDeleted = community['isDeleted'] == true;
                return ListTile(
                  title: Text(
                    community['name'] ?? 'Unnamed Community',
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : null,
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    isDeleted
                        ? 'Deleted'
                        : (community['description'] ?? 'No description'),
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : null,
                    ),
                  ),
                  onTap: isDeleted
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommunityManagementPage(
                                communityId: community['id'] ?? '',
                                communityName:
                                    community['name'] ?? 'Unnamed Community',
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
