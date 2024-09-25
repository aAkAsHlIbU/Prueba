
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:preuba/login_page.dart';
import 'package:preuba/welcome_page.dart';
import 'package:preuba/registration_page.dart';
import 'package:preuba/class_teacherRegPage.dart'; // Import Class Teacher Registration page
import 'package:preuba/admin_dashboard.dart'; // Import AdminDashboard page
import 'package:preuba/class_teacher_home_page.dart'; // Import Class Teacher Home page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Manually configure Firebase options based on the google-services.json file
  FirebaseOptions firebaseOptions = FirebaseOptions(
    appId: '1:83542331069:android:1fc882dd8707f17eb871d4',
    apiKey: 'AIzaSyB8ChNs88Xv_veqo3nsHqox_ikdcgHG9PE',
    messagingSenderId: '83542331069',
    projectId: 'preuba-58d32',
    storageBucket: 'preuba-58d32.appspot.com',
  );

  try {
    // Initialize Firebase using the manually provided FirebaseOptions
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    print('Firebase connected successfully');
  } catch (e) {
    print('Failed to connect to Firebase: $e');
    return; // Exit the app if Firebase initialization fails
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prueba',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => WelcomePage(), // Set the welcome page as home
        '/loginpage': (context) => LoginPage(), // Login page route
        '/registration': (context) => RegistrationPage(), // Registration page route
        '/classTeacherRegistration': (context) => ClassTeacherRegistrationPage(), // Class Teacher Registration route
        '/classTeacherHome': (context) => ClassTeacherHomePage(), // Class Teacher Home route
        '/adminDashboard': (context) => AdminDashboard(), // Admin dashboard route
      },
    );
  }
}

// Define your home screen widget as needed
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: Text('Welcome to the Prueba app!'),
      ),
    );
  }
}
