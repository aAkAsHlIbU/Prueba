import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.pexels.com/photos/301926/pexels-photo-301926.jpeg',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.6), // Darker overlay for better readability
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to Prueba!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'The In-Campus Social Platform for Amal Jyothi College.\n\n'
                    'Connect, collaborate, and share your college experiences with your peers, all in one place.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4, // For better line spacing
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 60), // Increase space between text and buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15), backgroundColor: const Color.fromARGB(255, 224, 215, 213),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ), // Customize the button color
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/loginpage');
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15), backgroundColor: const Color.fromARGB(255, 233, 240, 240),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ), // Customize for differentiation
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/registration');
                    },
                    child: Text(
                      'Register',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
