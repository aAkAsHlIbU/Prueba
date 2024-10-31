import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/student/chat_page.dart';
import 'package:incampus/student/community_chat_page.dart';

class ChatListPage extends StatefulWidget {
  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _communities = [];
  Map<String, bool> _userMemberships = {};
  Map<String, String> _joinRequestStatuses = {};
  late TabController _tabController;
  String _searchQuery = '';
  Map<String, int> _unreadMessages = {};

  // dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
    _loadCommunities();
    _loadUserMemberships();
    _loadJoinRequestStatuses();
    _loadUnreadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadUnreadMessages() {
    _database.child('messages').child(_currentUserId).onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> allMessages =
            event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, int> newUnreadCount = {};

        allMessages.forEach((friendId, messages) {
          if (messages is Map) {
            int unreadCount = 0;
            messages.forEach((messageId, messageData) {
              if (messageData is Map &&
                  messageData['senderId'] != _currentUserId &&
                  messageData['read'] == false) {
                unreadCount++;
              }
            });
            if (unreadCount > 0) {
              newUnreadCount[friendId] = unreadCount;
            }
          }
        });

        setState(() {
          _unreadMessages = newUnreadCount;
        });
      }
    });
  }

  void _loadFriends() {
    _database.child('users/$_currentUserId/friends').onValue.listen((event) {
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

  void _loadCommunities() {
    _database.child('communities').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> communitiesMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _communities = communitiesMap.entries
              .where((entry) => entry.value['isDeleted'] != true)
              .map((entry) {
            return {
              'id': entry.key,
              'name': entry.value['name'],
              'description': entry.value['description'],
              'createdBy': entry.value['createdBy'],
            };
          }).toList();
        });
      }
    });
  }

  void _loadUserMemberships() {
    // Listen for changes in user's communities
    _database
        .child('users/$_currentUserId/communities')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _userMemberships =
              Map<String, bool>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          _userMemberships = {};
        });
      }
    });

    // Listen for changes in community members
    _database.child('communities').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> communities =
            event.snapshot.value as Map<dynamic, dynamic>;
        communities.forEach((communityId, communityData) {
          if (communityData is Map && communityData['members'] is Map) {
            if (communityData['members'].containsKey(_currentUserId)) {
              setState(() {
                _userMemberships[communityId] = true;
              });
            }
          }
        });
      }
    });
  }

  void _loadJoinRequestStatuses() {
    _database.child('community_join_requests').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> allRequests =
            event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _joinRequestStatuses = {};
          allRequests.forEach((communityId, requests) {
            if (requests is Map && requests.containsKey(_currentUserId)) {
              _joinRequestStatuses[communityId] =
                  requests[_currentUserId]['status'];
            }
          });
        });
      }
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

  List<Map<String, dynamic>> _getFilteredList(List<Map<String, dynamic>> list) {
    return list
        .where((item) =>
            item['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _requestJoinCommunity(String communityId) {
    _database
        .child('community_join_requests/$communityId/$_currentUserId')
        .set({
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Join request sent successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        tabBarTheme: TabBarTheme(
          labelColor: _accentColor,
          unselectedLabelColor: _onSurfaceColor.withOpacity(0.6),
        ),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: _accentColor)
            .copyWith(background: _backgroundColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chats & Communities',
              style: TextStyle(color: _onSurfaceColor)),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Chats'),
              Tab(text: 'Communities'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: TextStyle(color: _onSurfaceColor),
                decoration: InputDecoration(
                  labelText: 'Search',
                  labelStyle:
                      TextStyle(color: _onSurfaceColor.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search,
                      color: _onSurfaceColor.withOpacity(0.6)),
                  fillColor: _surfaceColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatList(),
                  _buildCommunityList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final filteredFriends = _getFilteredList(_friends);
    return ListView.builder(
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        final unreadCount = _unreadMessages[friend['id']] ?? 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(friend['profilePicture']),
            backgroundColor: _surfaceColor,
          ),
          title: Text(friend['name'], style: TextStyle(color: _onSurfaceColor)),
          trailing: unreadCount > 0
              ? Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(friend: friend),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommunityList() {
    final filteredCommunities = _getFilteredList(_communities);
    return ListView.builder(
      itemCount: filteredCommunities.length,
      itemBuilder: (context, index) {
        final community = filteredCommunities[index];
        final isMember = _userMemberships[community['id']] ?? false;
        final requestStatus = _joinRequestStatuses[community['id']];

        Widget trailingWidget;
        if (isMember) {
          trailingWidget =
              Text('Member', style: TextStyle(color: _accentColor));
        } else if (requestStatus == 'pending') {
          trailingWidget =
              Text('Requested', style: TextStyle(color: Colors.orange));
        } else {
          trailingWidget = ElevatedButton(
            child: Text('Request to Join'),
            style: ElevatedButton.styleFrom(
              foregroundColor: _onSurfaceColor,
              backgroundColor: _accentColor,
            ),
            onPressed: () => _requestJoinCommunity(community['id']),
          );
        }

        return ListTile(
          title:
              Text(community['name'], style: TextStyle(color: _onSurfaceColor)),
          subtitle: Text(community['description'],
              style: TextStyle(color: _onSurfaceColor.withOpacity(0.6))),
          trailing: trailingWidget,
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
    );
  }
}
