import 'package:flutter/material.dart';
import 'login_page.dart'; 
import 'package:preuba/TeacherRegistrationPage.dart';
import 'package:preuba/class_TeacherRegPage.dart';
import 'package:preuba/nonteach.dart'; // Ensure this path points to the correct file
import 'AdminRegistrationPage.dart';

class RegistrationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.network(
            'https://images.template.net/wp-content/uploads/2014/11/scroll-download-background.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for text visibility
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Content in a transparent square panel
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8, // Set width to 80% of screen
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8), // Slightly transparent background
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8.0,
                        offset: Offset(0, 4), // Shadow position
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Your Role to Register',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        _buildRoleButton(context, 'Administrator', AdminRegistrationPage()),
                        SizedBox(height: 20),
                        _buildRoleButton(context, 'Class Teacher', ClassTeacherRegistrationPage()),
                        SizedBox(height: 20),
                        _buildRoleButton(context, 'Teacher', TeacherRegistrationPage()),
                        SizedBox(height: 20),
                        _buildRoleButton(context, 'Non-Teaching Staff', NonTeachingStaffRegistrationPage()),
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? '),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => LoginPage()),
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(color: const Color.fromARGB(255, 3, 100, 175)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ElevatedButton _buildRoleButton(BuildContext context, String role, Widget page) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Button color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Rounded corners
      ),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => page)); // Navigate to the provided page
      },
      child: Text(role, style: TextStyle(color: Colors.black)), // Added text color for visibility
    );
  }
}
