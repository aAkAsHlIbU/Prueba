import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateStoryScreen extends StatefulWidget {
  @override
  _CreateStoryScreenState createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _mediaFile;
  bool _isUploading = false;
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      await Permission.storage.request();

      XFile? pickedFile;
      if (isVideo) {
        pickedFile = await _picker.pickVideo(source: source);
      } else {
        pickedFile = await _picker.pickImage(source: source);
      }

      if (pickedFile != null) {
        setState(() {
          _mediaFile = pickedFile;
          _isVideo = isVideo;
        });

        if (isVideo) {
          _videoController = VideoPlayerController.file(File(pickedFile.path))
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });
        }
      }
    } catch (e) {
      print("Error picking media: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}.${_isVideo ? 'mp4' : 'jpg'}';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('stories/$userId/$fileName');

      await storageRef.putFile(File(_mediaFile!.path));
      final String downloadUrl = await storageRef.getDownloadURL();

      final DatabaseReference dbRef =
          FirebaseDatabase.instance.ref().child('stories/$userId').push();
      await dbRef.set({
        'mediaUrl': downloadUrl,
        'type': _isVideo ? 'video' : 'image',
        'timestamp': ServerValue.timestamp,
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading story: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
      ),
      child: Scaffold(
        appBar: AppBar(title: Text('Create Story')),
        body: Center(
          child: _isUploading
              ? CircularProgressIndicator(color: _accentColor)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_mediaFile != null)
                      _isVideo
                          ? _videoController!.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                )
                              : CircularProgressIndicator()
                          : Image.file(File(_mediaFile!.path), height: 200)
                    else
                      Text('No media selected',
                          style: TextStyle(color: _onSurfaceColor)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _pickMedia(ImageSource.gallery),
                      child: Text('Pick Image from Gallery'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _pickMedia(ImageSource.gallery, isVideo: true),
                      child: Text('Pick Video from Gallery'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickMedia(ImageSource.camera),
                      child: Text('Take a Photo'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _pickMedia(ImageSource.camera, isVideo: true),
                      child: Text('Record a Video'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor),
                    ),
                    if (_mediaFile != null)
                      ElevatedButton(
                        onPressed: _uploadStory,
                        child: Text('Upload Story'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
