import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DepartmentsManagementPage extends StatefulWidget {
  @override
  _DepartmentsManagementPageState createState() =>
      _DepartmentsManagementPageState();
}

class _DepartmentsManagementPageState extends State<DepartmentsManagementPage> {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('departments');
  Map<String, String> _departments = {};
  TextEditingController _departmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  void _loadDepartments() {
    _database.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _departments = Map<String, String>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  void _addDepartment() {
    if (_departmentController.text.isNotEmpty) {
      _database.push().set(_departmentController.text);
      _departmentController.clear();
    }
  }

  void _editDepartment(String key, String oldDepartment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _editController =
            TextEditingController(text: oldDepartment);
        return AlertDialog(
          title: Text('Edit Department'),
          content: TextField(
            controller: _editController,
            decoration: InputDecoration(hintText: "Enter new department name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (_editController.text.isNotEmpty) {
                  _database.child(key).set(_editController.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _departmentController,
                    decoration:
                        InputDecoration(hintText: "Enter new department"),
                  ),
                ),
                ElevatedButton(
                  onPressed: _addDepartment,
                  child: Text('Add Department'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _departments.entries.map((entry) {
                  return DataRow(cells: [
                    DataCell(Text(entry.value)),
                    DataCell(
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () =>
                            _editDepartment(entry.key, entry.value),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
