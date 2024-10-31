import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class TeacherApprovalsPage extends StatelessWidget {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _database
          .child('users')
          .orderByChild('role')
          .equalTo('Teacher')
          .onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map<dynamic, dynamic> teachers =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> teacherList = teachers.entries
              .where((entry) =>
                  (entry.value as Map<dynamic, dynamic>)['status'] == 'pending')
              .toList();

          if (teacherList.isEmpty) {
            return Center(child: Text('No pending approval requests'));
          }

          return ListView.builder(
            itemCount: teacherList.length,
            itemBuilder: (context, index) {
              MapEntry<dynamic, dynamic> entry = teacherList[index];
              Map<dynamic, dynamic> teacher =
                  entry.value as Map<dynamic, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(teacher['name'] ?? 'Unknown'),
                  subtitle: Text(
                      '${teacher['email']}\nDepartment: ${teacher['department']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () =>
                            _approveTeacher(context, entry.key, teacher),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectTeacher(context, entry.key),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  void _approveTeacher(BuildContext context, String teacherId,
      Map<dynamic, dynamic> teacherData) async {
    try {
      await _database
          .child('users')
          .child(teacherId)
          .update({'status': 'approved'});
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teacher approved successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve teacher: $e')));
    }
  }

  void _rejectTeacher(BuildContext context, String teacherId) async {
    try {
      await _database.child('users').child(teacherId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teacher rejected successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject teacher: $e')));
    }
  }
}
