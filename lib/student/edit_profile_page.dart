import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  EditProfilePage({required this.userProfile});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  File? _image;
  bool _isLoading = false;
  bool _isPublic = true;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile['name']);
    _bioController = TextEditingController(text: widget.userProfile['bio']);
    _isPublic = widget.userProfile['isPublic'] ?? true;
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      Map<String, dynamic> updates = {
        'name': _nameController.text,
        'bio': _bioController.text,
        'isPublic': _isPublic,
      };

      if (_image != null) {
        String fileName = 'profile_pictures/$userId.jpg';
        TaskSnapshot snapshot =
            await FirebaseStorage.instance.ref(fileName).putFile(_image!);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        updates['profilePicture'] = downloadUrl;
      }

      await FirebaseDatabase.instance.ref('users/$userId').update(updates);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: _onSurfaceColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _onSurfaceColor.withOpacity(0.5)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _accentColor),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Profile', style: TextStyle(color: _onSurfaceColor)),
          actions: [
            IconButton(
              icon: Icon(Icons.check, color: _onSurfaceColor),
              onPressed: _isLoading ? null : _updateProfile,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _image != null
                        ? FileImage(_image!)
                        : NetworkImage(
                                widget.userProfile['profilePicture'] ?? '')
                            as ImageProvider,
                    child:
                        Icon(Icons.camera_alt, size: 30, color: Colors.white54),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                style: TextStyle(color: _onSurfaceColor),
              ),
              SizedBox(height: 16),
              Text('Bio',
                  style: TextStyle(color: _onSurfaceColor.withOpacity(0.7))),
              SizedBox(height: 8),
              TextField(
                controller: _bioController,
                decoration: InputDecoration(
                  hintText: 'Write your bio here...',
                  hintStyle: TextStyle(color: _onSurfaceColor.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _onSurfaceColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _accentColor),
                  ),
                ),
                style: TextStyle(color: _onSurfaceColor),
                maxLines: 4,
                textAlign: TextAlign.left,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Public Profile',
                      style: TextStyle(color: _onSurfaceColor)),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    activeColor: _accentColor,
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_isLoading)
                Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_accentColor))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
