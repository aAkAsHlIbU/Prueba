import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';

class ClassTeacherHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class Teacher Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginPage()), // Adjust with your LoginPage import
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('class_teachers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No data available'));
          }

          final teachers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index].data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(teacher['name'] ?? 'No Name'),
                  subtitle: Text('Email: ${teacher['email'] ?? 'No Email'}\nDepartment: ${teacher['department'] ?? 'No Department'}'),
                  isThreeLine: true,
                  onTap: () {
                    // Handle item tap if needed
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
