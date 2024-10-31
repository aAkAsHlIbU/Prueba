import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'welcome_page.dart';
import 'student/homescreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InCampus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return WelcomePage();
          } else {
            return FutureBuilder<DatabaseEvent>(
              future: _database.child('users').child(user.uid).once(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    Map<dynamic, dynamic> userData =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    String role = userData['role'];
                    String status = userData['status'];

                    if (status != 'approved') {
                      // User is not approved, sign out and return to welcome page
                      _auth.signOut();
                      return WelcomePage();
                    }

                    switch (role) {
                      case 'admin':
                      case 'Student':
                      case 'Teacher':
                        return StudentDashboard(); // This will be renamed to HomeScreen later
                      default:
                        // Unknown role, sign out and return to welcome page
                        _auth.signOut();
                        return WelcomePage();
                    }
                  } else {
                    // User data not found, sign out and return to welcome page
                    _auth.signOut();
                    return WelcomePage();
                  }
                }
                // While checking user data, show a loading indicator
                return Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              },
            );
          }
        }
        // While checking authentication state, show a loading indicator
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
