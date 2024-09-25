import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'admin_dashboard.dart'; // Import the admin dashboard
import 'class_teacher_home_page.dart'; // Import the teacher dashboard
import 'registration_page.dart'; // Import the admin registration page
import 'class_TeacherRegPage.dart'; // Import the teacher registration page

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: 'YOUR_GOOGLE_CLIENT_ID', // Use your Client ID here
    scopes: ['email'],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Normal login method for Admins and Class Teachers
  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      // Firebase Authentication login
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if the user is an Admin
      QuerySnapshot<Map<String, dynamic>> adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .get();

      // If admin exists, navigate to the admin dashboard
      if (adminDoc.docs.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => AdminDashboard()),
        );
      } else {
        // Check if the user is a Class Teacher
        QuerySnapshot<Map<String, dynamic>> teacherDoc = await FirebaseFirestore.instance
            .collection('class_teachers')
            .where('email', isEqualTo: email)
            .get();

        // If Class Teacher exists, navigate to the class teacher dashboard
        if (teacherDoc.docs.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ClassTeacherHomePage()),
          );
        } else {
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unauthorized login, contact the admin.')));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No user found for that email.')));
      } else if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wrong password provided for that user.')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Google Sign-In method
  Future<void> _googleSignInMethod() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

        // Navigate based on role
        _handleUserNavigation(userCredential.user);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed.')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleUserNavigation(User? user) async {
    if (user != null) {
      // Check if the user is an Admin
      QuerySnapshot<Map<String, dynamic>> adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .get();

      if (adminDoc.docs.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => AdminDashboard()),
        );
      } else {
        // Check if the user is a Class Teacher
        QuerySnapshot<Map<String, dynamic>> teacherDoc = await FirebaseFirestore.instance
            .collection('class_teachers')
            .where('email', isEqualTo: user.email)
            .get();

        if (teacherDoc.docs.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ClassTeacherHomePage()),
          );
        } else {
          await FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unauthorized login, contact the admin.')));
        }
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/glitter.jpeg', // Update the path based on your asset file
          fit: BoxFit.cover,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(flex: 2, child: Container()),

                // Container with a fixed width for email input
                Container(
                  width: 300, // Set the desired width
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 24),

                // Container with a fixed width for password input
                Container(
                  width: 300, // Set the desired width
                  child: TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                    obscureText: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Login button
                InkWell(
                  onTap: _login,
                  child: Container(
                    width: 300, // Adjust to match the input fields
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue,
                    ),
                    child: !_isLoading
                        ? const Text('Log in', style: TextStyle(color: Colors.white))
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),

                // Google Sign-in button
                Container(
                  width: 300, // Set the desired width to match input fields
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: Size(300, 50), // Adjust to match the input fields
                  ),
                  onPressed: _googleSignInMethod,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/google_icon.png', height: 24), // Add your Google icon image
                      const SizedBox(width: 8),
                      const Text('Sign in with Google', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
                const SizedBox(height: 12),

                
                
                // Sign Up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Don\'t have an account?'),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => RegistrationPage()), // Adjust path
                      ),
                      child: const Text(
                        ' Sign Up.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Flexible(flex: 2, child: Container()),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
