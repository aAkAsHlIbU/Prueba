import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class StudentApprovalsPage extends StatefulWidget {
  @override
  _StudentApprovalsPageState createState() => _StudentApprovalsPageState();
}

class _StudentApprovalsPageState extends State<StudentApprovalsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _pendingStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingStudents();
  }

  void _loadPendingStudents() {
    print("_loadPendingStudents called");
    final String currentUserUid = _auth.currentUser!.uid;
    print("Current teacher UID: $currentUserUid");

    _database
        .child('users')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .listen((event) {
      print("Database listener triggered");
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> values = event.snapshot.value as Map;
        print("All pending users: ${values.length}");

        setState(() {
          _pendingStudents = values.entries
              .where((entry) {
                final isStudent = entry.value['role'] == 'Student';
                final hasClassTeacher = entry.value['classTeacher'] != null;
                final isCurrentTeacher =
                    entry.value['classTeacher'] == currentUserUid;
                print(
                    "User ${entry.key}: isStudent=$isStudent, hasClassTeacher=$hasClassTeacher, isCurrentTeacher=$isCurrentTeacher");
                return isStudent && hasClassTeacher && isCurrentTeacher;
              })
              .map((entry) => Map<String, dynamic>.from(entry.value))
              .toList();
          _isLoading = false;
        });

        print("Filtered pending students: ${_pendingStudents.length}");
      } else {
        print("No pending users found");
        setState(() {
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("Error fetching data: $error");
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _approveStudent(String studentUid) async {
    try {
      await _database.child('users/$studentUid').update({'status': 'approved'});
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Student approved successfully')));
      _loadPendingStudents(); // Reload the list after approval
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve student: $e')));
    }
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
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Text(
                            '${student['email']}\nCourse: ${student['course']}'),
                        trailing: ElevatedButton(
                          child: Text('Approve'),
                          onPressed: () => _approveStudent(student['uid']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
