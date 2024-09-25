import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:preuba/login_page.dart';
import 'package:crypto/crypto.dart';

class TeacherRegistrationPage extends StatefulWidget {
  @override
  _TeacherRegistrationPageState createState() => _TeacherRegistrationPageState();
}

class _TeacherRegistrationPageState extends State<TeacherRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool isLoading = false; // Add loading state

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _registerTeacher() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
        return;
      }

      setState(() {
        isLoading = true; // Start loading
      });

      try {
        await FirebaseFirestore.instance.collection('registrationRequests').add({
          'name': _nameController.text.trim(),
          'department': _departmentController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'Teacher',
          'password': _hashPassword(_passwordController.text.trim()),
          'status': 'pending',
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration request sent to admin.')));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
      } finally {
        setState(() {
          isLoading = false; // Stop loading
        });
      }
    }
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
      appBar: AppBar(title: Text('Teacher Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading // Show loading indicator
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                    ),
                    TextFormField(
                      controller: _departmentController,
                      decoration: InputDecoration(labelText: 'Department Name'),
                      validator: (value) => value!.isEmpty ? 'Please enter your department' : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (value) => value!.isEmpty || !RegExp(r'\S+@\S+\.\S+').hasMatch(value)
                          ? 'Please enter a valid email'
                          : null,
                    ),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: 'Phone Number'),
                      validator: (value) => value!.isEmpty ? 'Please enter your phone number' : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Password'),
                      validator: (value) => value!.isEmpty ? 'Please enter a password' : null,
                    ),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Confirm Password'),
                      validator: (value) => value!.isEmpty ? 'Please confirm your password' : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(onPressed: _registerTeacher, child: Text('Register')),
                  ],
                ),
              ),
      ),
    );
  }
}
