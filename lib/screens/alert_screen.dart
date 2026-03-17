import 'dart:io';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';      // Required for XFile

class CreateAlertScreen extends StatelessWidget {
  final XFile mediaFile; // Changed to XFile
  final bool isVideo;

  const CreateAlertScreen({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Alert'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: isVideo ? _buildVideoPreview() : _buildImagePreview(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // TODO: Implement your upload logic here
              // e.g., final bytes = await mediaFile.readAsBytes();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Processing Alert...")),
              );
            },
            child: const Text('Submit Alert', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  // --- IMAGE PREVIEW WIDGET ---
  Widget _buildImagePreview() {
    // 1. If running on Web, use Image.network for the Blob URL
    if (kIsWeb) {
      return Image.network(
        mediaFile.path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => 
          const Text("Error loading image on web", style: TextStyle(color: Colors.white)),
      );
    } 
    // 2. If running on Mobile, use Image.file
    else {
      return Image.file(
        File(mediaFile.path),
        fit: BoxFit.contain,
      );
    }
  }

  // --- VIDEO PREVIEW WIDGET ---
  Widget _buildVideoPreview() {
    // Note: To play the video, you will need the 'video_player' package.
    // For now, this safely shows a placeholder with the file path.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, color: Colors.white70, size: 80),
        const SizedBox(height: 16),
        const Text(
          "Video Captured Successfully!",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            mediaFile.path,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}