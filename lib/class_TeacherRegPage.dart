import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart'; // Import your LoginPage here

class ClassTeacherRegistrationPage extends StatefulWidget {
  @override
  _ClassTeacherRegistrationPageState createState() => _ClassTeacherRegistrationPageState();
}

class _ClassTeacherRegistrationPageState extends State<ClassTeacherRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  void _registerTeacher() async {
    if (_formKey.currentState!.validate()) {
      // Check if passwords match
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
        return;
      }

      try {
        // Create a new user in Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Create teacher request in Firestore after authentication
        await FirebaseFirestore.instance.collection('class_teacher_requests').doc(userCredential.user?.uid).set({
          'name': _nameController.text.trim(),
          'department': _departmentController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'status': 'pending', // initially the status is pending
          'uid': userCredential.user?.uid, // Store the user UID for future reference
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration request sent to admin')));

        // Clear fields after successful registration
        _clearFields();

        // Redirect to the login page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Registration failed';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already registered.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register. Try again later.')));
      }
    }
  }

  void _clearFields() {
    _nameController.clear();
    _departmentController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your name';
    }
    if (!RegExp(r'^[A-Z][a-zA-Z]*$').hasMatch(value)) {
      return 'Name should only contain letters and start with a capital letter';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your email';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9.-]+)\.ajce\.in$').hasMatch(value)) {
      return 'Email must contain "ajce" after "@" symbol';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your phone number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Enter a valid 10-digit phone number starting with 6, 7, 8, or 9';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{6,}$').hasMatch(value)) {
      return 'Password must be at least 6 characters, include letters, numbers, and a special character';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Class Teacher Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
                validator: _validateName,
              ),
              TextFormField(
                controller: _departmentController,
                decoration: InputDecoration(labelText: 'Department'),
                validator: (value) => value!.isEmpty ? 'Enter your department' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: _validatePhoneNumber,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: _validatePassword,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Confirm your password' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registerTeacher,
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
