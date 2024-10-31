import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  String? _selectedRole;
  String? _selectedClassTeacher;
  String? _selectedDepartment;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

  Map<String, String> _departments = {};
  Map<String, Map<String, dynamic>> _classTeachers = {};

  bool _isLoading = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  Map<String, IconData> _departmentIcons = {
    'MCA': FontAwesomeIcons.laptopCode,
    'MSc': FontAwesomeIcons.flask,
    'BTech': FontAwesomeIcons.microchip,
  };

  // Add this line to get a reference to the database
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Add these regex patterns
  final _nameRegex = RegExp(r'^[a-zA-Z ]+$');
  final _emailRegexStudent = RegExp(r'^[\w-\.]+@[\w-]+\.ajce\.in$');
  final _emailRegexTeacher = RegExp(r'^[\w-\.]+@amaljyothi\.ac\.in$');
  final _phoneRegex = RegExp(r'^[0-9]{10}$');
  final _passwordRegex =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$');
  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadClassTeachers();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final snapshot =
        await FirebaseDatabase.instance.ref().child('departments').once();
    if (snapshot.snapshot.value != null) {
      setState(() {
        _departments = Map<String, String>.from(snapshot.snapshot.value as Map);
      });
    }
  }

  Future<void> _loadClassTeachers() async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('users')
        .orderByChild('role')
        .equalTo('Teacher')
        .once();
    if (snapshot.snapshot.value != null) {
      final Map<dynamic, dynamic> teachers =
          snapshot.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _classTeachers = teachers.map((key, value) {
          final teacher = value as Map<dynamic, dynamic>;
          return MapEntry(key, {
            'name': teacher['name'] as String,
            'department': teacher['department'] as String,
          });
        });
      });
    }
  }

  String _generateId(String prefix) {
    Random random = Random();
    String numbers = '';
    for (int i = 0; i < 6; i++) {
      numbers += random.nextInt(10).toString();
    }
    return '$prefix$numbers';
  }

  void _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        String generatedId =
            _generateId(_selectedRole == 'Student' ? 'S' : 'T');

        Map<String, dynamic> userData = {
          'uid': userCredential.user!.uid,
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'role': _selectedRole,
          'status':
              'pending', // Set status to 'pending' for both students and teachers
          'timestamp': ServerValue.timestamp,
        };

        if (_selectedRole == 'Student') {
          userData['studentId'] = generatedId;
          userData['classTeacher'] = _selectedClassTeacher;
          userData['department'] = _departments[_selectedDepartment];
        } else {
          userData['teacherId'] = generatedId;
          userData['department'] = _departments[_selectedDepartment];
        }

        await _database
            .child('users')
            .child(userCredential.user!.uid)
            .set(userData);

        // Remove the separate 'teachers' node creation

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Registration request submitted successfully. Your ID is $generatedId')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit registration request: $e')),
        );
      }

      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createAdminUser() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: 'admin@mail.com',
        password: 'admin123',
      );

      // Store admin data in Realtime Database
      await _database.child('users').child(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': 'Admin',
        'email': 'admin@mail.com',
        'role': 'admin',
        'status': 'approved',
        'timestamp': ServerValue.timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin user created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create admin user: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.indigo.shade600,
              Colors.blue.shade500
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    SizedBox(height: 40),
                    _selectedRole == null
                        ? _buildRoleSelection()
                        : _buildRegistrationForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Text(
      'Register',
      style: GoogleFonts.poppins(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildRoleSelection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Select your role',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRoleButton('Student', FontAwesomeIcons.userGraduate),
                  _buildRoleButton(
                      'Teacher', FontAwesomeIcons.chalkboardTeacher),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(String role, IconData icon) {
    return ElevatedButton(
      onPressed: () => setState(() => _selectedRole = role),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue.shade600,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Column(
        children: [
          FaIcon(icon, size: 36),
          SizedBox(height: 8),
          Text(role,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(_nameController, 'Name', FontAwesomeIcons.user,
                    keyboardType: TextInputType.name),
                SizedBox(height: 16),
                _buildTextField(
                    _emailController, 'Email', FontAwesomeIcons.envelope,
                    keyboardType: TextInputType.emailAddress),
                SizedBox(height: 16),
                _buildTextField(
                    _phoneController, 'Phone Number', FontAwesomeIcons.phone,
                    keyboardType: TextInputType.phone),
                SizedBox(height: 16),
                _buildPasswordField(_passwordController, 'Password',
                    FontAwesomeIcons.lock, _isPasswordVisible, () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                }),
                SizedBox(height: 16),
                _buildPasswordField(
                    _confirmPasswordController,
                    'Confirm Password',
                    FontAwesomeIcons.lock,
                    _isConfirmPasswordVisible, () {
                  setState(() =>
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                }),
                SizedBox(height: 16),
                if (_selectedRole == 'Student') ...[
                  _buildDepartmentDropdown(),
                  SizedBox(height: 16),
                  if (_selectedDepartment != null) _buildClassTeacherDropdown(),
                ],
                if (_selectedRole == 'Teacher') _buildDepartmentDropdown(),
                SizedBox(height: 24),
                _buildRegisterButton(),
                // SizedBox(height: 16),
                // _buildCreateAdminButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDepartment,
      decoration: InputDecoration(
        labelText: 'Department',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 12),
          child:
              FaIcon(FontAwesomeIcons.building, color: Colors.white, size: 20),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      style: TextStyle(color: Colors.white),
      dropdownColor: Colors.blue.shade800,
      items: _departments.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value, style: TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value;
          _selectedClassTeacher =
              null; // Reset class teacher when department changes
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a department';
        }
        return null;
      },
    );
  }

  Widget _buildClassTeacherDropdown() {
    final filteredTeachers = _classTeachers.entries
        .where((entry) =>
            entry.value['department'] == _departments[_selectedDepartment])
        .toList();

    return DropdownButtonFormField<String>(
      value: _selectedClassTeacher,
      decoration: InputDecoration(
        labelText: 'Class Teacher',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 12),
          child: FaIcon(FontAwesomeIcons.chalkboardUser,
              color: Colors.white, size: 20),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      style: TextStyle(color: Colors.white),
      dropdownColor: Colors.blue.shade800,
      items: filteredTeachers.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child:
              Text(entry.value['name'], style: TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedClassTeacher = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a class teacher';
        }
        return null;
      },
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 12),
          child: FaIcon(icon, color: Colors.white, size: 20),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label == 'Name' && !_nameRegex.hasMatch(value)) {
          return 'Please enter a valid name (letters and spaces only)';
        }
        if (label == 'Email') {
          if (_selectedRole == 'Student' &&
              !_emailRegexStudent.hasMatch(value)) {
            return 'Please enter a valid student email ending with .ajce.in';
          }
          if (_selectedRole == 'Teacher' &&
              !_emailRegexTeacher.hasMatch(value)) {
            return 'Please enter a valid teacher email ending with @amaljyothi.ac.in';
          }
        }
        if (label == 'Phone Number' && !_phoneRegex.hasMatch(value)) {
          return 'Please enter a valid 10-digit phone number';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label,
      IconData icon, bool isVisible, VoidCallback toggleVisibility) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 12),
          child: FaIcon(icon, color: Colors.white, size: 20),
        ),
        suffixIcon: IconButton(
          icon: FaIcon(
            isVisible ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
            color: Colors.white,
            size: 20,
          ),
          onPressed: toggleVisibility,
        ),
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      style: TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (!_passwordRegex.hasMatch(value)) {
          return '$label must be at least 8 characters long and contain at least one letter and one number';
        }
        if (label == 'Confirm Password' && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 12),
          child: FaIcon(icon, color: Colors.white, size: 20),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      style: TextStyle(color: Colors.white),
      dropdownColor: Colors.blue.shade800,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item['id'] as String,
          child: Text(item['name'] as String,
              style: TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a $label';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitRegistration,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue.shade600,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: _isSubmitting
          ? CircularProgressIndicator(color: Colors.white)
          : Text('Register',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCreateAdminButton() {
    return ElevatedButton(
      onPressed: _createAdminUser,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red.shade600,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Text('Create Admin User',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
