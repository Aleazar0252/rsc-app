import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart'; // Add this for video preview
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class MissionReportScreen extends StatefulWidget {
  final String alertId;
  final String victimName;
  final String incidentType;

  const MissionReportScreen({
    super.key, 
    required this.alertId, 
    required this.victimName,
    required this.incidentType,
  });

  @override
  State<MissionReportScreen> createState() => _MissionReportScreenState();
}

class _MissionReportScreenState extends State<MissionReportScreen> {
  // Controllers
  final _actionController = TextEditingController();
  final _descController = TextEditingController();
  
  // Media State
  File? _mediaFile;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _videoController?.dispose(); // Clean up video player to prevent leaks
    super.dispose();
  }

  // --- 1. PICK PHOTO ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    
    if (pickedFile != null) {
      _disposeVideo(); // Clear any previous video
      setState(() {
        _mediaFile = File(pickedFile.path);
        _isVideo = false;
      });
    }
  }

  // --- 2. PICK VIDEO ---
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    // Limit video to 30 seconds to save bandwidth
    final pickedFile = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
    
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      _disposeVideo(); // Clear previous
      
      // Initialize the player to show a preview
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      
      setState(() {
        _mediaFile = file;
        _isVideo = true;
        _videoController = controller;
      });
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  // --- 3. SUBMIT REPORT ---
  Future<void> _submitReport() async {
    if (_actionController.text.isEmpty || _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add proof (Photo/Video) and action taken.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // A. Upload to Supabase
      final String ext = _isVideo ? 'mp4' : 'jpg';
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final String path = 'reports/$fileName'; // Folder: reports/
      
      await Supabase.instance.client.storage
          .from('readytoservethecommunity') // Your bucket name
          .upload(path, _mediaFile!);

      // Get URL
      final String mediaUrl = Supabase.instance.client.storage
          .from('readytoservethecommunity')
          .getPublicUrl(path);

      // B. Save to Firebase
      final dbRef = FirebaseDatabase.instance.ref();
      
      // 1. Mark Alert as Resolved
      await dbRef.child('alerts/${widget.alertId}').update({
        'status': 'resolved',
        'resolved_at': ServerValue.timestamp,
        'proof_url': mediaUrl,
        'proof_type': _isVideo ? 'video' : 'image',
        'action_taken': _actionController.text,
      });

      // 2. Add to History Log
      await dbRef.child('reports').push().set({
        'alert_id': widget.alertId,
        'victim': widget.victimName,
        'type': widget.incidentType,
        'action': _actionController.text,
        'description': _descController.text,
        'proof_url': mediaUrl,
        'proof_type': _isVideo ? 'video' : 'image',
        'timestamp': ServerValue.timestamp,
      });

      if (!mounted) return;
      Navigator.pop(context); // Close Screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mission Completed & Report Sent!")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Submit Report")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Responding to: ${widget.incidentType}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Victim: ${widget.victimName}"),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // MEDIA PREVIEW AREA
            const Text("Proof of Rescue", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _mediaFile == null
                  ? const Center(child: Text("No Media Selected", style: TextStyle(color: Colors.grey)))
                  : _isVideo
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : Image.file(_mediaFile!, fit: BoxFit.cover),
            ),

            // MEDIA BUTTONS
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Take Photo"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text("Record Video"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            
            // PLAY BUTTON (Only if video is selected)
            if (_isVideo && _videoController != null)
              Center(
                child: TextButton.icon(
                  icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_videoController!.value.isPlaying ? "Pause Preview" : "Play Preview"),
                  onPressed: () {
                    setState(() {
                      _videoController!.value.isPlaying 
                        ? _videoController!.pause() 
                        : _videoController!.play();
                    });
                  },
                ),
              ),

            const SizedBox(height: 20),

            // TEXT FIELDS
            TextField(
              controller: _actionController,
              decoration: const InputDecoration(
                labelText: "Action Taken", 
                hintText: "e.g. Administered First Aid, Evacuated to safe zone",
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description (Optional)", border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 30),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SUBMIT MISSION REPORT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}