// ignore_for_file: unused_local_variable

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:incampus/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:incampus/student/homescreen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  void _signIn() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Attempt to sign in with email and password
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        print("User authenticated successfully: ${userCredential.user?.uid}");

        // Check if this user also has Google provider
        final signInMethods = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(_emailController.text);

        if (!signInMethods.contains('password')) {
          // Ensure the email/password provider is preserved
          try {
            await userCredential.user?.reauthenticateWithCredential(
              EmailAuthProvider.credential(
                email: _emailController.text,
                password: _passwordController.text,
              ),
            );
          } catch (e) {
            print("Reauthorization not needed: $e");
          }
        }

        // Handle user data and navigation
        await _handleUserData(userCredential.user!.uid);
      } on FirebaseAuthException catch (e) {
        _handleAuthError(e);
      } catch (e) {
        print("Unexpected error during sign in: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('An unexpected error occurred. Please try again later.'),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      // Check if user exists in your database
      final userQuery = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .orderByChild('email')
          .equalTo(googleUser.email)
          .once();

      if (userQuery.snapshot.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please register before using Google Sign-In.')),
        );
        await googleSignIn.signOut();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if email/password sign-in method exists
      final signInMethods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(googleUser.email);

      UserCredential userCredential;

      if (signInMethods.contains('password')) {
        // If email/password exists, prompt for password to preserve the provider
        String? password = await _promptForPassword();
        if (password != null) {
          try {
            // First sign in with email/password
            userCredential =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: googleUser.email,
              password: password,
            );

            // Then link with Google credential
            if (!signInMethods.contains('google.com')) {
              await userCredential.user?.linkWithCredential(credential);
            }
          } catch (e) {
            print("Error linking accounts: $e");
            // If linking fails, try direct Google sign-in
            userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
          }
        } else {
          // If user cancels password prompt, proceed with Google sign-in
          userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);
        }
      } else {
        // If no email/password method, just sign in with Google
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // Handle user data and navigation
      await _handleUserData(userCredential.user!.uid);
    } catch (e) {
      print("Error during Google sign in: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'An error occurred during Google sign in. Please try again.'),
        ),
      );
      await GoogleSignIn().signOut();
    }
  }

  Future<void> _handleUserData(String uid) async {
    DatabaseEvent event =
        await FirebaseDatabase.instance.ref().child('users').child(uid).once();

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> userData =
          event.snapshot.value as Map<dynamic, dynamic>;
      String role = userData['role'];
      String status = userData['status'];

      if (status != 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Your account is not yet approved. Please wait for admin approval.'),
          ),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      _navigateBasedOnRole(role);
    } else {
      print("User data not found in the database");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User data not found. Please try registering again.'),
        ),
      );
      await FirebaseAuth.instance.signOut();
    }
  }

  void _navigateBasedOnRole(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => StudentDashboard()),
    );
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage =
            'No user found with this email. Please check your email or register.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        errorMessage =
            'The email address is not valid. Please enter a valid email.';
        break;
      case 'user-disabled':
        errorMessage =
            'This account has been disabled. Please contact support.';
        break;
      default:
        errorMessage =
            'An error occurred while signing in. Please try again later. (${e.code})';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  Future<String?> _promptForPassword() async {
    String? password;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Preserve Email/Password Sign-In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'To maintain access to both email/password and Google sign-in methods, please enter your password.'),
              SizedBox(height: 16),
              TextField(
                obscureText: true,
                onChanged: (value) {
                  password = value;
                },
                decoration: InputDecoration(
                  hintText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Skip'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return password;
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Password reset email sent. Please check your inbox.')),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again later.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('Error in forgot password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('An unexpected error occurred. Please try again later.')),
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
                    _buildLoginForm(),
                    SizedBox(height: 24),
                    _buildSocialLogin(),
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
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: FaIcon(FontAwesomeIcons.userCircle,
              size: 80, color: Colors.deepPurple.shade800),
        ),
        SizedBox(height: 24),
        Text(
          'Sign In',
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.3),
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
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
                _buildTextField(
                  controller: _emailController,
                  icon: FontAwesomeIcons.envelope,
                  labelText: 'Email',
                ),
                SizedBox(height: 24),
                _buildTextField(
                  controller: _passwordController,
                  icon: FontAwesomeIcons.lock,
                  labelText: 'Password',
                  isPassword: true,
                ),
                SizedBox(height: 32),
                _buildLoginButton(),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTextButton('Forgot Password?', _forgotPassword),
                    _buildTextButton('Register Here!', _navigateToRegister),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String labelText,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.blue.shade800),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: FaIcon(icon, color: Colors.blue.shade800, size: 20),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: FaIcon(
                    _isPasswordVisible
                        ? FontAwesomeIcons.eyeSlash
                        : FontAwesomeIcons.eye,
                    color: Colors.blue.shade800,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your ${isPassword ? 'password' : 'email'}';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _signIn,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue.shade600,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Text('Sign In',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Text(
          'Or sign in with',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              icon: FontAwesomeIcons.google,
              color: Colors.red,
              onPressed: _signInWithGoogle,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FaIcon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildTextButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }
}
