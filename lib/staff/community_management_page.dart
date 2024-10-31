import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityManagementPage extends StatefulWidget {
  final String communityId;
  final String communityName;

  CommunityManagementPage({
    required this.communityId,
    required this.communityName,
  });

  @override
  _CommunityManagementPageState createState() =>
      _CommunityManagementPageState();
}

class _CommunityManagementPageState extends State<CommunityManagementPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _joinRequests = [];
  List<Map<String, dynamic>> _members = [];

  // Define light theme colors
  final Color _primaryColor = Colors.white;
  final Color _accentColor = Colors.blue;
  final Color _backgroundColor = Colors.white;
  final Color _surfaceColor = Colors.grey[100]!;
  final Color _onSurfaceColor = Colors.black;

  @override
  void initState() {
    super.initState();
    if (widget.communityId.isNotEmpty) {
      _loadJoinRequests();
      _loadMembers();
    } else {
      // Handle the case where communityId is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid community ID')),
      );
    }
  }

  void _loadJoinRequests() {
    _database
        .child('community_join_requests/${widget.communityId}')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> requests =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> pendingRequests = requests.entries
            .map((entry) {
              return {
                'userId': entry.key,
                ...Map<String, dynamic>.from(entry.value as Map),
              };
            })
            .where((request) => request['status'] == 'pending')
            .toList();

        _fetchRequestUserDetails(pendingRequests);
      }
    });
  }

  void _fetchRequestUserDetails(List<Map<String, dynamic>> requests) {
    requests.forEach((request) {
      _database
          .child('users/${request['userId']}')
          .once()
          .then((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> userData =
              event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _joinRequests.add({
              ...request,
              'name': userData['name'] ?? 'Unknown',
              'email': userData['email'] ?? '',
            });
          });
        }
      });
    });
  }

  void _loadMembers() {
    _database
        .child('communities/${widget.communityId}/members')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> members =
            event.snapshot.value as Map<dynamic, dynamic>;
        _fetchMemberDetails(members.keys.cast<String>().toList());
      }
    });
  }

  void _fetchMemberDetails(List<String> memberIds) {
    memberIds.forEach((userId) {
      _database.child('users/$userId').once().then((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> userData =
              event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _members.add({
              'id': userId,
              'name': userData['name'] ?? 'Unknown',
              'email': userData['email'] ?? '',
            });
          });
        }
      });
    });
  }

  void _approveRequest(String userId) {
    // Update community members
    _database
        .child('communities/${widget.communityId}/members/$userId')
        .set(true);

    // Update join request status
    _database
        .child('community_join_requests/${widget.communityId}/$userId/status')
        .set('approved');

    // Update user's communities
    _database
        .child('users/$userId/communities/${widget.communityId}')
        .set(true);

    // Remove the request from the local list
    setState(() {
      _joinRequests.removeWhere((request) => request['userId'] == userId);
    });

    // Show a confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User approved and added to the community')),
    );
  }

  void _rejectRequest(String userId) {
    _database
        .child('community_join_requests/${widget.communityId}/$userId/status')
        .set('rejected');
    setState(() {
      _joinRequests.removeWhere((request) => request['userId'] == userId);
    });
  }

  void _markCommunityAsDeleted() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Community'),
          content: Text('Are you sure you want to delete this community?'),
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
                _database
                    .child('communities/${widget.communityId}/isDeleted')
                    .set(true);
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to previous screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Community marked as deleted')),
                );
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
      data: ThemeData.light().copyWith(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          elevation: 0,
          iconTheme: IconThemeData(color: _onSurfaceColor),
        ),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: _accentColor)
            .copyWith(background: _backgroundColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Manage ${widget.communityName}',
              style: TextStyle(color: _onSurfaceColor)),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _markCommunityAsDeleted,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildMembersList(),
                  _buildJoinRequestsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Members',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _onSurfaceColor)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final member = _members[index];
            return ListTile(
              title: Text(member['name'],
                  style: TextStyle(color: _onSurfaceColor)),
              subtitle: Text(member['email'],
                  style: TextStyle(color: _onSurfaceColor.withOpacity(0.6))),
              trailing: member['id'] != _currentUserId
                  ? IconButton(
                      icon:
                          Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        // Implement remove member functionality
                      },
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildJoinRequestsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Join Requests',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _onSurfaceColor),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _joinRequests.length,
          itemBuilder: (context, index) {
            final request = _joinRequests[index];
            return ListTile(
              title: Text(request['name'],
                  style: TextStyle(color: _onSurfaceColor)),
              subtitle: Text(request['email'],
                  style: TextStyle(color: _onSurfaceColor.withOpacity(0.6))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveRequest(request['userId']),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () => _rejectRequest(request['userId']),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
