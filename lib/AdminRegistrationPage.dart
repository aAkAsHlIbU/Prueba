import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart'; // Ensure you have this page for the admin dashboard

class AdminRegistrationPage extends StatefulWidget {
  @override
  _AdminRegistrationPageState createState() => _AdminRegistrationPageState();
}

class _AdminRegistrationPageState extends State<AdminRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  void _registerAdmin() async {
    if (_formKey.currentState!.validate()) {
      // Check if passwords match
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
        return;
      }

      try {
        // Create admin user in Firebase Authentication
        UserCredential adminCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Store the admin details in Firestore
        await FirebaseFirestore.instance.collection('admins').doc(adminCredential.user?.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'Admin',
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration successful')));

        // Automatically navigate to the admin dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => AdminDashboard()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register. Try again later.')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Enter your name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Enter your email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Enter your password' : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Confirm your password' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registerAdmin,
                child: Text('Register as Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
