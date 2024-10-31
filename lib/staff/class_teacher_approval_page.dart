import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassTeacherApprovalPage extends StatefulWidget {
  @override
  _ClassTeacherApprovalPageState createState() =>
      _ClassTeacherApprovalPageState();
}

class _ClassTeacherApprovalPageState extends State<ClassTeacherApprovalPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _currentUserUid = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> _pendingStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingStudents();
  }

  void _loadPendingStudents() {
    _database
        .child('users')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> values = event.snapshot.value as Map;

        setState(() {
          _pendingStudents = values.entries
              .where((entry) {
                final isStudent = entry.value['role'] == 'Student';
                final hasClassTeacher = entry.value['classTeacher'] != null;
                final isCurrentTeacher =
                    entry.value['classTeacher'] == _currentUserUid;

                return isStudent && hasClassTeacher && isCurrentTeacher;
              })
              .map((entry) => Map<String, dynamic>.from(entry.value))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }, onError: (error) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _approveStudent(String studentUid) {
    _database.child('users/$studentUid').update({'status': 'approved'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No pending students'),
                      SizedBox(height: 20),
                      SizedBox(height: 10),
                      ElevatedButton(
                        child: Text('Refresh'),
                        onPressed: _loadPendingStudents,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingStudents.length,
                  itemBuilder: (context, index) {
                    final student = _pendingStudents[index];
                    return ListTile(
                      title: Text(student['name'] ?? 'No name'),
                      subtitle: Text(student['email'] ?? 'No email'),
                      trailing: ElevatedButton(
                        child: Text('Approve'),
                        onPressed: () => _approveStudent(student['uid']),
                      ),
                    );
                  },
                ),
    );
  }
}
