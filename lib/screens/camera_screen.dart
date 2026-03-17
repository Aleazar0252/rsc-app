import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'alert_screen.dart';  

class CustomCameraScreen extends StatefulWidget {
  const CustomCameraScreen({super.key});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = []; 
  int _selectedCameraIndex = 0; 
  
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  FlashMode _flashMode = FlashMode.off;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  // --- 1. INITIALIZE ---
  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = "No cameras found.");
        return;
      }
      
      // Try to find back camera, otherwise use first available
      _selectedCameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _startCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error: $e");
    }
  }

  Future<void> _startCamera(CameraDescription cameraDescription) async {
    final oldController = _controller;
    if (oldController != null) await oldController.dispose();

    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // 'medium' is safer for web browsers
      enableAudio: false,      // Disabled audio to prevent web permission blocks
    );

    _controller = newController;

    try {
      await newController.initialize();
      // Flash mode often fails on Web, so we wrap it safely
      try { await newController.setFlashMode(FlashMode.off); } catch (_) {}
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _flashMode = FlashMode.off; 
        });
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
      setState(() => _errorMessage = "Camera Error: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });
    await _startCamera(_cameras[_selectedCameraIndex]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_cameras[_selectedCameraIndex]);
    }
  }

  // --- ACTIONS ---
  Future<void> _takePhoto() async {
    if (!_controller!.value.isInitialized || _isRecording) return;
    try {
      final XFile image = await _controller!.takePicture();
      _navigateToReport(image, false); // Passing XFile
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _startVideo() async {
    if (!_controller!.value.isInitialized || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Error starting video: $e");
    }
  }

  Future<void> _stopVideo() async {
    if (!_isRecording) return;
    try {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      _navigateToReport(video, true); // Passing XFile
    } catch (e) {
      debugPrint("Error stopping video: $e");
    }
  }

  void _navigateToReport(XFile file, bool isVideo) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAlertScreen(mediaFile: file, isVideo: isVideo),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off);
    try {
      _controller?.setFlashMode(_flashMode);
    } catch (e) {
      debugPrint("Flash not supported: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
      );
    }
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. CAMERA PREVIEW
          SizedBox(
            width: size.width,
            height: size.height,
            child: FittedBox(
              fit: BoxFit.cover, 
              child: SizedBox(
                width: 100, 
                height: 100 * _controller!.value.aspectRatio, 
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // 2. TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on, color: Colors.white, size: 30),
                        onPressed: _toggleFlash,
                      ),
                      if (_cameras.length > 1) ...[
                        const SizedBox(width: 15),
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                          onPressed: _switchCamera,
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. BOTTOM CONTROLS
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isRecording ? "Recording..." : "Tap for Photo • Hold for Video",
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)]
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _takePhoto,
                  onLongPress: _startVideo,
                  onLongPressUp: _stopVideo,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isRecording ? 100 : 80,
                    width: _isRecording ? 100 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isRecording ? Colors.red : Colors.white.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Container(
                        height: _isRecording ? 40 : 60,
                        width: _isRecording ? 40 : 60,
                        decoration: BoxDecoration(
                          shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.white,
                          borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}