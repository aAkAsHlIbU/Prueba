import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class AssignClassTeachersPage extends StatefulWidget {
  @override
  _AssignClassTeachersPageState createState() =>
      _AssignClassTeachersPageState();
}

class _AssignClassTeachersPageState extends State<AssignClassTeachersPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String _filterRole = 'All';
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () => _generateFilteredUsersPDF(),
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _database.child('users').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text('No users found in the database'));
          }

          Map<dynamic, dynamic> users =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> userList = users.entries.toList();

          // Filter out admin users
          userList = userList.where((entry) {
            Map<dynamic, dynamic> userData =
                entry.value as Map<dynamic, dynamic>;
            return userData['role'] != 'admin';
          }).toList();

          // Apply filters
          userList = userList.where((entry) {
            Map<dynamic, dynamic> userData =
                entry.value as Map<dynamic, dynamic>;
            bool roleMatch =
                _filterRole == 'All' || userData['role'] == _filterRole;
            bool searchMatch = _searchQuery.isEmpty ||
                userData['name']
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                userData['email']
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
            return roleMatch && searchMatch;
          }).toList();

          // Apply sorting
          userList.sort((a, b) {
            Map<dynamic, dynamic> userDataA = a.value as Map<dynamic, dynamic>;
            Map<dynamic, dynamic> userDataB = b.value as Map<dynamic, dynamic>;
            int comparison;
            switch (_sortBy) {
              case 'name':
                comparison = userDataA['name'].compareTo(userDataB['name']);
                break;
              case 'email':
                comparison = userDataA['email'].compareTo(userDataB['email']);
                break;
              case 'role':
                comparison = userDataA['role'].compareTo(userDataB['role']);
                break;
              default:
                comparison = 0;
            }
            return _sortAscending ? comparison : -comparison;
          });

          return ListView.builder(
            itemCount: userList.length,
            itemBuilder: (context, index) {
              MapEntry<dynamic, dynamic> entry = userList[index];
              Map<dynamic, dynamic> userData =
                  entry.value as Map<dynamic, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(userData['name'] ?? 'No name'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${userData['email'] ?? 'No email'}'),
                      Text('Role: ${userData['role'] ?? 'No role'}'),
                      Text(
                          'Department: ${userData['department'] ?? 'Not specified'}'),
                      if (userData['teacherId'] != null)
                        Text('Teacher ID: ${userData['teacherId']}'),
                      if (userData['studentId'] != null)
                        Text('Student ID: ${userData['studentId']}'),
                      Text('Status: ${userData['status'] ?? 'Not specified'}'),
                      if (userData['role'] == 'Teacher')
                        Text('Class Teacher: ${userData['isClassTeacher'] == true ? 'Yes' : 'No'}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf),
                        onPressed: () => generateUserDetailsPDF(userData),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String result) {
                          switch (result) {
                            case 'toggleClassTeacher':
                              _toggleClassTeacher(context, entry.key,
                                  userData['isClassTeacher'] == true);
                              break;
                            case 'toggleDisable':
                              _toggleDisableUser(context, entry.key,
                                  userData['status'] == 'disabled');
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          if (userData['role'] == 'Teacher')
                            PopupMenuItem<String>(
                              value: 'toggleClassTeacher',
                              child: Text(userData['isClassTeacher'] == true
                                  ? 'Remove Class Teacher'
                                  : 'Make Class Teacher'),
                            ),
                          PopupMenuItem<String>(
                            value: 'toggleDisable',
                            child: Text(userData['status'] == 'disabled'
                                ? 'Enable User'
                                : 'Disable User'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _toggleClassTeacher(
      BuildContext context, String userId, bool isCurrentlyClassTeacher) async {
    try {
      await _database.child('users').child(userId).update({
        'isClassTeacher': !isCurrentlyClassTeacher,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isCurrentlyClassTeacher
                ? 'Teacher removed as class teacher successfully'
                : 'Teacher assigned as class teacher successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating class teacher status: $e')),
      );
    }
  }

  void _toggleDisableUser(
      BuildContext context, String userId, bool isCurrentlyDisabled) async {
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter Users'),
          content: DropdownButton<String>(
            value: _filterRole,
            items: <String>['All', 'Student', 'Teacher']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _filterRole = newValue!;
              });
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search Users'),
          content: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Enter name or email',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sort Users'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _sortBy,
                items: <String>['name', 'email', 'role']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.capitalize()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _sortBy = newValue!;
                  });
                },
              ),
              SwitchListTile(
                title: Text('Ascending'),
                value: _sortAscending,
                onChanged: (bool value) {
                  setState(() {
                    _sortAscending = value;
                  });
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Apply'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> generateUserDetailsPDF(Map<dynamic, dynamic> userData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with title
              pw.Header(
                level: 0,
                child: pw.Text('User Details Report', 
                  style: pw.TextStyle(
                    fontSize: 24, 
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900
                  )
                ),
              ),
              pw.SizedBox(height: 20),

              // Basic Information Section
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Basic Information',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                    ),
                    pw.SizedBox(height: 10),
                    _buildInfoRow('Name', userData['name'] ?? 'Not specified'),
                    _buildInfoRow('Email', userData['email'] ?? 'Not specified'),
                    _buildInfoRow('Role', userData['role'] ?? 'Not specified'),
                    _buildInfoRow('Department', userData['department'] ?? 'Not specified'),
                    _buildInfoRow('Status', userData['status'] ?? 'Not specified'),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Additional Details Section
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Additional Details',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                    ),
                    pw.SizedBox(height: 10),
                    if (userData['teacherId'] != null)
                      _buildInfoRow('Teacher ID', userData['teacherId']),
                    if (userData['studentId'] != null)
                      _buildInfoRow('Student ID', userData['studentId']),
                    if (userData['role'] == 'Teacher')
                      _buildInfoRow('Class Teacher', 
                        userData['isClassTeacher'] == true ? 'Yes' : 'No'),
                    _buildInfoRow('Verified User', 
                      userData['isVerified'] == true ? 'Yes' : 'No'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save the PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/user_details.pdf');
    await file.writeAsBytes(await pdf.save());

    // Open the PDF
    await OpenFile.open(file.path);
  }

  Future<void> _generateFilteredUsersPDF() async {
    final pdf = pw.Document();
    final filteredUsers = await _getFilteredUsers();

    // Split users into chunks for pagination
    final int usersPerPage = 4; // Adjust this number based on your needs
    for (var i = 0; i < filteredUsers.length; i += usersPerPage) {
      final endIdx = (i + usersPerPage < filteredUsers.length) 
          ? i + usersPerPage 
          : filteredUsers.length;
      final pageUsers = filteredUsers.sublist(i, endIdx);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Show header only on first page
                if (i == 0) ...[
                  pw.Header(
                    level: 0,
                    child: pw.Text('Filtered Users Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900
                      )
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Filter Information
                  pw.Container(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Filter Settings',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                        ),
                        pw.SizedBox(height: 10),
                        _buildInfoRow('Role Filter', _filterRole),
                        _buildInfoRow('Search Query', _searchQuery.isEmpty ? 'None' : _searchQuery),
                        _buildInfoRow('Sort By', _sortBy),
                        _buildInfoRow('Sort Order', _sortAscending ? 'Ascending' : 'Descending'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Users List
                pw.Text('User List${i > 0 ? ' (Continued)' : ''}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                ),
                pw.SizedBox(height: 10),

                // Users for this page
                ...pageUsers.map((userData) => pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Name', userData['name'] ?? 'No name'),
                            _buildInfoRow('Email', userData['email'] ?? 'No email'),
                            _buildInfoRow('Role', userData['role'] ?? 'No role'),
                            _buildInfoRow('Department', userData['department'] ?? 'Not specified'),
                            _buildInfoRow('Status', userData['status'] ?? 'Not specified'),
                            if (userData['teacherId'] != null)
                              _buildInfoRow('Teacher ID', userData['teacherId']),
                            if (userData['studentId'] != null)
                              _buildInfoRow('Student ID', userData['studentId']),
                            if (userData['role'] == 'Teacher')
                              _buildInfoRow('Class Teacher', userData['isClassTeacher'] == true ? 'Yes' : 'No'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            );
          },
        ),
      );
    }

    // Save and open the PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/filtered_users.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  Future<List<Map<dynamic, dynamic>>> _getFilteredUsers() async {
    if (!mounted) return [];
    
    final event = await _database.child('users').onValue.first;
    if (event.snapshot.value == null) return [];
    
    Map<dynamic, dynamic> users = event.snapshot.value as Map<dynamic, dynamic>;
    List<MapEntry<dynamic, dynamic>> userList = users.entries.toList();
    
    // Apply existing filters
    userList = userList.where((entry) {
      Map<dynamic, dynamic> userData = entry.value as Map<dynamic, dynamic>;
      bool roleMatch = _filterRole == 'All' || userData['role'] == _filterRole;
      bool searchMatch = _searchQuery.isEmpty ||
          userData['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          userData['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      return roleMatch && searchMatch;
    }).toList();
    
    // Apply sorting
    userList.sort((a, b) {
      Map<dynamic, dynamic> userDataA = a.value as Map<dynamic, dynamic>;
      Map<dynamic, dynamic> userDataB = b.value as Map<dynamic, dynamic>;
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = userDataA['name'].compareTo(userDataB['name']);
          break;
        case 'email':
          comparison = userDataA['email'].compareTo(userDataB['email']);
          break;
        case 'role':
          comparison = userDataA['role'].compareTo(userDataB['role']);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    return userList.map((entry) => entry.value as Map<dynamic, dynamic>).toList();
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
            ),
          ),
          pw.Text(': '),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
