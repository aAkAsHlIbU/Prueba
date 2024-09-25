import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for sign-out functionality
import 'login_page.dart';
class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final CollectionReference classTeacherRequests = FirebaseFirestore.instance.collection('class_teacher_requests');

  Future<void> _approveRequest(String docId, String name, String email) async {
    try {
      // Update the teacher request status to 'approved'
      await classTeacherRequests.doc(docId).update({'status': 'approved'});

      // Save the approved teacher in the 'class_teachers' collection
      await FirebaseFirestore.instance.collection('class_teachers').doc(docId).set({
        'name': name,
        'email': email,
        'role': 'class Teacher',
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Class Teacher approved successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving teacher')));
    }
  }

  Future<void> _deleteRequest(String docId) async {
    try {
      // Delete the request from Firestore
      await classTeacherRequests.doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request removed successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing request')));
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Use pushReplacement to navigate back to the LoginPage and remove the AdminDashboard from the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()), // Make sure to import LoginPage
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        leading: IconButton(
          icon: Icon(Icons.logout),
          onPressed: _signOut, // Sign out on button press
        ),
      ),
      body: Column(
        children: [
          // Pending Requests Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: classTeacherRequests.where('status', isEqualTo: 'pending').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final pendingRequests = snapshot.data!.docs;

                return ExpansionTile(
                  title: Text('Pending Requests'),
                  initiallyExpanded: true, // By default, expand the pending section
                  children: pendingRequests.isEmpty
                      ? [Center(child: Text('No pending class teacher requests'))]
                      : pendingRequests.map((request) {
                          final String name = request['name'];
                          final String email = request['email'];

                          return ListTile(
                            title: Text(name),
                            subtitle: Text(email),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _approveRequest(request.id, name, email),
                                  child: Text('Approve'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRequest(request.id),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                );
              },
            ),
          ),

          // Approved Requests Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: classTeacherRequests.where('status', isEqualTo: 'approved').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final approvedRequests = snapshot.data!.docs;

                return ExpansionTile(
                  title: Text('Approved Requests'),
                  initiallyExpanded: false, // The approved section is collapsed by default
                  children: approvedRequests.isEmpty
                      ? [Center(child: Text('No approved class teacher requests'))]
                      : approvedRequests.map((request) {
                          final String name = request['name'];
                          final String email = request['email'];

                          return ListTile(
                            title: Text(name),
                            subtitle: Text(email),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteRequest(request.id),
                            ),
                          );
                        }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
