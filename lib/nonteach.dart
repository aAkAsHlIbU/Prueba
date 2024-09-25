import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:preuba/login_page.dart';
import 'package:crypto/crypto.dart';

class NonTeachingStaffRegistrationPage extends StatefulWidget {
  const NonTeachingStaffRegistrationPage({super.key});

  @override
  _NonTeachingStaffRegistrationPageState createState() => _NonTeachingStaffRegistrationPageState();
}

class _NonTeachingStaffRegistrationPageState extends State<NonTeachingStaffRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String position = '';
  String phone = '';
  String password = '';
  String confirmPassword = '';
  bool isLoading = false; // Add loading state

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match!')));
        return;
      }

      setState(() {
        isLoading = true; // Start loading
      });

      try {
        await FirebaseFirestore.instance.collection('registrationRequests').add({
          'name': name,
          'email': email,
          'position': position,
          'phone': phone,
          'role': 'Non-Teaching Staff',
          'password': _hashPassword(password),
          'status': 'pending',
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration request sent to admin.')));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register. Please try again.')));
      } finally {
        setState(() {
          isLoading = false; // Stop loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Non-Teaching Staff')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading // Show loading indicator
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Name'),
                      onChanged: (value) => name = value,
                      validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Email'),
                      onChanged: (value) => email = value,
                      validator: (value) => value!.isEmpty || !RegExp(r'\S+@\S+\.\S+').hasMatch(value)
                          ? 'Please enter a valid email'
                          : null,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Position'),
                      onChanged: (value) => position = value,
                      validator: (value) => value!.isEmpty ? 'Please enter your position' : null,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Phone'),
                      onChanged: (value) => phone = value,
                      validator: (value) => value!.isEmpty ? 'Please enter your phone number' : null,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onChanged: (value) => password = value,
                      validator: (value) => value!.isEmpty ? 'Please enter a password' : null,
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Confirm Password'),
                      obscureText: true,
                      onChanged: (value) => confirmPassword = value,
                      validator: (value) => value!.isEmpty ? 'Please confirm your password' : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(onPressed: _register, child: Text('Register')),
                  ],
                ),
              ),
      ),
    );
  }
}
