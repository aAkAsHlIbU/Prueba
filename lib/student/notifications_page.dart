import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

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
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: _primaryColor,
          onPrimary: _onSurfaceColor,
          secondary: _accentColor,
          onSecondary: _onSurfaceColor,
          error: Colors.red,
          onError: _onSurfaceColor,
          background: _backgroundColor,
          onBackground: _onSurfaceColor,
          surface: _surfaceColor,
          onSurface: _onSurfaceColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title:
              Text('Notifications', style: TextStyle(color: _onSurfaceColor)),
        ),
        body: StreamBuilder(
          stream:
              _database.child('users/$_currentUserId/friendRequests').onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.hasData &&
                !snapshot.hasError &&
                snapshot.data!.snapshot.value != null) {
              Map<dynamic, dynamic> requests =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  String requesterId = requests.keys.elementAt(index);
                  return FutureBuilder(
                    future: _database.child('users/$requesterId').get(),
                    builder:
                        (context, AsyncSnapshot<DataSnapshot> userSnapshot) {
                      if (userSnapshot.hasData &&
                          userSnapshot.data!.value != null) {
                        Map<dynamic, dynamic> userData =
                            userSnapshot.data!.value as Map<dynamic, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                                userData['profilePicture'] ??
                                    'https://via.placeholder.com/150'),
                          ),
                          title: Row(
                            children: [
                              Text(userData['name'] ?? 'Unknown User',
                                  style: TextStyle(color: _onSurfaceColor)),
                              if (userData['isVerified'] == true)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.verified, color: Colors.blue, size: 16),
                                ),
                            ],
                          ),
                          subtitle: Text('Sent you a friend request',
                              style: TextStyle(color: Colors.grey[400])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check, color: _accentColor),
                                onPressed: () =>
                                    _acceptFriendRequest(requesterId),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.red),
                                onPressed: () =>
                                    _rejectFriendRequest(requesterId),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListTile(
                          title: Text('Loading...',
                              style: TextStyle(color: _onSurfaceColor)));
                    },
                  );
                },
              );
            }
            return Center(
                child: Text('No friend requests',
                    style: TextStyle(color: _onSurfaceColor)));
          },
        ),
      ),
    );
  }

  void _acceptFriendRequest(String requesterId) async {
    await _database
        .child('users/$_currentUserId/friends/$requesterId')
        .set(true);
    await _database
        .child('users/$requesterId/friends/$_currentUserId')
        .set(true);
    await _database
        .child('users/$_currentUserId/friendRequests/$requesterId')
        .remove();
    setState(() {});
  }

  void _rejectFriendRequest(String requesterId) async {
    await _database
        .child('users/$_currentUserId/friendRequests/$requesterId')
        .remove();
    setState(() {});
  }
}
