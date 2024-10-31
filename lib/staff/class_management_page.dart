import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/student/user_profile_page.dart';

class ClassManagementPage extends StatefulWidget {
  @override
  _ClassManagementPageState createState() => _ClassManagementPageState();
}

class _ClassManagementPageState extends State<ClassManagementPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    _database.child('users').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> users =
            event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _students = users.entries
              .where((entry) =>
                  entry.value['role'] == 'Student' &&
                  entry.value['classTeacher'] == _currentUserId)
              .map((entry) => {
                    'id': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map),
                  })
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("Error loading students: $error");
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _toggleDisableUser(String userId, bool isCurrentlyDisabled) async {
    try {
      await _database.child('users').child(userId).update({
        'status': isCurrentlyDisabled ? 'approved' : 'disabled',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCurrentlyDisabled
              ? 'User enabled successfully'
              : 'User disabled successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          user: user,
          isFriend: false,
          isClassTeacher: true,
          onFriendStatusChanged: (_, __) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(child: Text('No students in your class'))
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                            student['profilePicture'] ??
                                'https://via.placeholder.com/150'),
                      ),
                      title: Text(student['name'] ?? 'No name'),
                      subtitle: Text(student['email'] ?? 'No email'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String result) {
                          switch (result) {
                            case 'viewProfile':
                              _viewUserProfile(student);
                              break;
                            case 'toggleDisable':
                              _toggleDisableUser(student['id'],
                                  student['status'] == 'disabled');
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'viewProfile',
                            child: Text('View Profile'),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggleDisable',
                            child: Text(student['status'] == 'disabled'
                                ? 'Enable User'
                                : 'Disable User'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
