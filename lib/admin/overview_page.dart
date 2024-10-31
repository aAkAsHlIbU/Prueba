import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';

class OverviewPage extends StatelessWidget {
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');

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
    int totalUsers = users.length;
    int studentsCount =
        users.values.where((user) => user['role'] == 'Student').length;
    int teachersCount =
        users.values.where((user) => user['role'] == 'Teacher').length;
    int adminsCount =
        users.values.where((user) => user['role'] == 'admin').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          _buildUserStatCards(totalUsers, studentsCount, teachersCount),
          SizedBox(height: 20),
          _buildUserTypeChart(studentsCount, teachersCount, adminsCount),
          SizedBox(height: 20),
          _buildDepartmentDistribution(users),
        ],
      ),
    );
  }

  Widget _buildUserStatCards(
      int totalUsers, int studentsCount, int teachersCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('Total Users', totalUsers.toString(), Colors.blue),
        _buildStatCard('Students', studentsCount.toString(), Colors.green),
        _buildStatCard('Teachers', teachersCount.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeChart(
      int studentsCount, int teachersCount, int adminsCount) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Types',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                        value: studentsCount.toDouble(),
                        title: 'Students',
                        color: Colors.blue),
                    PieChartSectionData(
                        value: teachersCount.toDouble(),
                        title: 'Teachers',
                        color: Colors.green),
                    PieChartSectionData(
                        value: adminsCount.toDouble(),
                        title: 'Admins',
                        color: Colors.red),
                  ],
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentDistribution(Map<dynamic, dynamic> users) {
    Map<String, int> departmentCounts = {};
    users.values.forEach((user) {
      if (user['department'] != null) {
        String dept = user['department'];
        departmentCounts[dept] = (departmentCounts[dept] ?? 0) + 1;
      }
    });

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Department Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: departmentCounts.values
                      .reduce((a, b) => a > b ? a : b)
                      .toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: departmentCounts.entries
                      .map((entry) =>
                          BarChartGroupData(
                              x: departmentCounts.keys
                                  .toList()
                                  .indexOf(entry.key),
                              barRods: [
                                BarChartRodData(
                                    toY: entry.value.toDouble(),
                                    color: Colors.blue)
                              ]))
                      .toList(),
                ),
              ),
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: departmentCounts.entries
                  .map((entry) => Text('${entry.key}: ${entry.value}'))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
