// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:incampus/student/feed_page.dart';
import 'package:incampus/student/for_you_page.dart';
import 'package:incampus/student/profile_page.dart';
import 'package:incampus/student/reels_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_compress/video_compress.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';

class StudentDashboard extends StatefulWidget {
  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentIndex = 0;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  void _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: _primaryColor,
        hintColor: _accentColor,
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _primaryColor,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: _surfaceColor,
          selectedItemColor: _accentColor,
          unselectedItemColor: Colors.grey,
        ),
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: _primaryColor,
          onPrimary: _onSurfaceColor,
          secondary: _accentColor,
          onSecondary: _onSurfaceColor,
          error: Colors.red,
          onError: _onSurfaceColor,
          background: _backgroundColor,
          onBackground: _onSurfaceColor,
          surface: _surfaceColor,
          onSurface: _onSurfaceColor,
        ),
      ),
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
              _showNewContentDialog();
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add'),
            BottomNavigationBarItem(
                icon: Icon(Icons.video_library), label: 'Reels'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return FeedPage();
      case 1:
        return ForYouPage();
      case 3:
        return ReelsPage();
      case 4:
        return ProfilePage();
      default:
        return FeedPage();
    }
  }

  void _showNewContentDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt, color: _onSurfaceColor),
                title: Text('Take Photo',
                    style: TextStyle(color: _onSurfaceColor)),
                onTap: () {
                  Navigator.pop(context);
                  _openCameraAwesome(false, false);
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: _onSurfaceColor),
                title: Text('Record Reels',
                    style: TextStyle(color: _onSurfaceColor)),
                onTap: () {
                  Navigator.pop(context);
                  _openCameraAwesome(true, true);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo, color: _onSurfaceColor),
                title: Text('Add New Post from Gallery',
                    style: TextStyle(color: _onSurfaceColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(false, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library, color: _onSurfaceColor),
                title: Text('Add New Reel from Gallery',
                    style: TextStyle(color: _onSurfaceColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(true, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCameraAwesome(bool isVideo, bool isReel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraAwesomePage(
          isVideo: isVideo,
          onCapture: (String? path) {
            if (path != null) {
              Navigator.of(context).pop();
              _showConfirmationDialog(File(path), isVideo, isReel);
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickMedia(bool isReel, ImageSource source) async {
    final ImagePicker _picker = ImagePicker();
    try {
      final XFile? pickedFile = isReel
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source);
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        bool isVideo = pickedFile.name.toLowerCase().endsWith('.mp4');
        _showConfirmationDialog(file, isVideo, isReel);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  void _showConfirmationDialog(File file, bool isVideo, bool isReel) {
    String description = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isReel ? 'New Reel' : 'New Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isVideo
                  ? Text('Video selected')
                  : Image.file(file, height: 200, fit: BoxFit.cover),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(hintText: "Enter description"),
                maxLines: 3,
                onChanged: (value) {
                  description = value;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Post'),
              onPressed: () {
                Navigator.of(context).pop();
                if (isReel) {
                  _createNewReel(file, description);
                } else {
                  _createNewPost(file, isVideo, description);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewPost(
      File file, bool isVideo, String description) async {
    String fileName =
        'posts/${DateTime.now().millisecondsSinceEpoch}.${isVideo ? 'mp4' : 'jpg'}';

    // Show uploading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Uploading post...'), duration: Duration(seconds: 2)),
    );

    try {
      // Upload file to Firebase Storage
      TaskSnapshot snapshot =
          await FirebaseStorage.instance.ref(fileName).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save post metadata to Firebase Realtime Database
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseDatabase.instance.ref('posts/$userId').push().set({
          'imageUrl': downloadUrl,
          'description': description,
          'timestamp': ServerValue.timestamp,
          'type': 'post'
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post uploaded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to create post: $e')));
    }
  }

  Future<void> _createNewReel(File videoFile, String description) async {
    String videoFileName = 'reels/${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Show uploading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Uploading reel...'), duration: Duration(seconds: 2)),
    );

    try {
      // Generate thumbnail using video_compress
      final thumbnailFile =
          await VideoCompress.getFileThumbnail(videoFile.path);
      String thumbnailFileName =
          'thumbnails/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload video to Firebase Storage
      TaskSnapshot videoSnapshot =
          await FirebaseStorage.instance.ref(videoFileName).putFile(videoFile);
      String videoUrl = await videoSnapshot.ref.getDownloadURL();

      // Upload thumbnail to Firebase Storage
      TaskSnapshot thumbnailSnapshot = await FirebaseStorage.instance
          .ref(thumbnailFileName)
          .putFile(thumbnailFile);
      String thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();

      // Get current user data
      User? currentUser = FirebaseAuth.instance.currentUser;
      String? userId = currentUser?.uid;

      if (userId != null) {
        // Fetch username from the 'users' node
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('users/$userId');
        DatabaseEvent event = await userRef.once();

        String username = 'Anonymous';
        if (event.snapshot.value != null) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          username = userData['name'] ?? 'Anonymous';
        }

        await FirebaseDatabase.instance.ref('reels/$userId').push().set({
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'description': description,
          'timestamp': ServerValue.timestamp,
          'type': 'reel',
          'likes': 0,
          'likedBy': {},
          'comments': {},
          'username': username,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reel uploaded successfully')),
        );
      }

      // Clean up: delete the temporary thumbnail file
      await thumbnailFile.delete();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to create reel: $e')));
    }
  }

  Future<String?> _getDescription(BuildContext context, String title) async {
    TextEditingController _descriptionController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add a description for your $title'),
          content: TextField(
            controller: _descriptionController,
            decoration: InputDecoration(hintText: "Enter description"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () =>
                  Navigator.of(context).pop(_descriptionController.text),
            ),
          ],
        );
      },
    );
  }
}

class CameraAwesomePage extends StatelessWidget {
  final bool isVideo;
  final Function(String?) onCapture;

  CameraAwesomePage({required this.isVideo, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode: isVideo ? CaptureMode.video : CaptureMode.photo,
          photoPathBuilder: (sensors) async {
            final path = await _tempPath('.jpg');
            return SingleCaptureRequest(path, sensors.first);
          },
          videoOptions: VideoOptions(
            enableAudio: true,
          ),
          videoPathBuilder: (sensors) async {
            final path = await _tempPath('.mp4');
            return SingleCaptureRequest(path, sensors.first);
          },
        ),
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          aspectRatio: CameraAspectRatios.ratio_16_9,
        ),
        onMediaTap: (mediaCapture) {
          mediaCapture.captureRequest.when(
            single: (single) {
              onCapture(single.file?.path);
            },
            multiple: (multiple) {
              // Handle multiple captures if needed
            },
          );
        },
      ),
    );
  }

  Future<String> _tempPath(String extension) async {
    final Directory extDir = await getTemporaryDirectory();
    final testDir =
        await Directory('${extDir.path}/camerawesome').create(recursive: true);
    return '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}$extension';
  }
}
