import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OverviewPage extends StatefulWidget {
  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');
  final String _currentTeacherId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _usersRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map<dynamic, dynamic> users =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          return _buildOverviewContent(users);
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildOverviewContent(Map<dynamic, dynamic> users) {
    List<Map<String, dynamic>> myStudents = users.entries
        .where((entry) => entry.value['classTeacher'] == _currentTeacherId)
        .map((e) => Map<String, dynamic>.from(e.value))
        .toList();

    int totalStudents = myStudents.length;
    int approvedStudents =
        myStudents.where((student) => student['status'] == 'approved').length;
    int pendingStudents =
        myStudents.where((student) => student['status'] == 'pending').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          _buildStudentStatCards(
              totalStudents, approvedStudents, pendingStudents),
          SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Status Distribution',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _buildStudentStatusChart(approvedStudents, pendingStudents),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: _buildStudentList(myStudents),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStatCards(
      int totalStudents, int approvedStudents, int pendingStudents) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('Total Students', totalStudents.toString(), Colors.blue),
        _buildStatCard('Approved', approvedStudents.toString(), Colors.green),
        _buildStatCard('Pending', pendingStudents.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(count,
                style: TextStyle(
                    fontSize: 24, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentStatusChart(int approvedStudents, int pendingStudents) {
    return Container(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              color: Colors.green,
              value: approvedStudents.toDouble(),
              title: 'Approved',
              radius: 40,
              titleStyle:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            PieChartSectionData(
              color: Colors.orange,
              value: pendingStudents.toDouble(),
              title: 'Pending',
              radius: 40,
              titleStyle:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
          sectionsSpace: 0,
          centerSpaceRadius: 40,
          startDegreeOffset: -90,
        ),
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student List',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(student['profilePicture'] ??
                    'https://via.placeholder.com/150'),
              ),
              title: Text(student['name'] ?? 'Unknown'),
              subtitle: Text(student['email'] ?? 'No email'),
              trailing: Chip(
                label: Text(student['status'] ?? 'Unknown'),
                backgroundColor: student['status'] == 'approved'
                    ? Colors.green
                    : Colors.orange,
              ),
            );
          },
        ),
      ],
    );
  }
}
