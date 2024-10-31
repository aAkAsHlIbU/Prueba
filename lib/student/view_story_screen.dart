import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ViewStoryScreen extends StatefulWidget {
  final Map<String, dynamic> story;

  ViewStoryScreen({required this.story});

  @override
  _ViewStoryScreenState createState() => _ViewStoryScreenState();
}

class _ViewStoryScreenState extends State<ViewStoryScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // Define dark theme colors
  final Color _primaryColor = Colors.black;
  final Color _accentColor = Colors.blue[700]!;
  final Color _backgroundColor = Color(0xFF121212);
  final Color _surfaceColor = Color(0xFF1E1E1E);
  final Color _onSurfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.story['type'] == 'video') {
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.network(widget.story['mediaUrl'])
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: true,
          showControls: false,
          aspectRatio: _videoController!.value.aspectRatio,
        );
        setState(() {
          _isVideoInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: _primaryColor,
        hintColor: _accentColor,
        scaffoldBackgroundColor: _backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: _buildMediaContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (widget.story['type'] == 'image') {
      return Image.network(widget.story['mediaUrl']);
    } else if (widget.story['type'] == 'video') {
      if (_isVideoInitialized) {
        return Chewie(controller: _chewieController!);
      } else {
        return CircularProgressIndicator(color: _accentColor);
      }
    } else {
      return Text('Unsupported media type',
          style: TextStyle(color: _onSurfaceColor));
    }
  }
}
