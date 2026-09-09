import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class OnDutyCameraPage extends StatefulWidget {
  const OnDutyCameraPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<OnDutyCameraPage> createState() => _OnDutyCameraPageState();
}

class _OnDutyCameraPageState extends State<OnDutyCameraPage> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera device found.';
          _isInitializing = false;
        });
        return;
      }

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to access camera: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    setState(() => _isInitializing = true);
    final prevController = _controller;
    await prevController?.dispose();

    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (!mounted) return;
      setState(() {
        _controller = newController;
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    if (_controller != null && _controller!.value.isInitialized) {
      setState(() => _isCapturing = true);
      try {
        final file = await _controller!.takePicture();
        final bytes = await file.readAsBytes();
        final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final base64Image = 'data:image/$ext;base64,${base64Encode(bytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64Image);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to take photo: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    } else {
      // Direct camera fallback for platforms without CameraController support
      setState(() => _isCapturing = true);
      try {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 40,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          final ext = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          final base64Image = 'data:image/$ext;base64,${base64Encode(bytes)}';
          if (mounted) {
            Navigator.of(context).pop(base64Image);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open camera: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withValues(alpha: 0.8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF9CC70A),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_cameras.length > 1)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                      tooltip: 'Switch Camera',
                      onPressed: _isInitializing || _isCapturing ? null : _switchCamera,
                    ),
                ],
              ),
            ),

            // Camera Viewfinder View
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off, size: 54, color: Colors.white54),
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _isCapturing ? null : _capturePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Launch System Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9CC70A),
                                foregroundColor: const Color(0xFF414A51),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isInitializing || _controller == null || !_controller!.value.isInitialized)
                    const Center(
                      child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),

                  // Overlay Guideline Box
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Watermark / Live Badge
                  Positioned(
                    top: 36,
                    left: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF9CC70A), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                          SizedBox(width: 6),
                          Text(
                            'LIVE CAMERA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Shutter Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              color: Colors.black,
              child: Column(
                children: [
                  const Text(
                    'Position yourself / site work within frame',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isCapturing || _isInitializing ? null : _capturePhoto,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: const Color(0xFF9CC70A),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9CC70A).withValues(alpha: 0.4),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isCapturing
                                ? const CircularProgressIndicator(color: Color(0xFF414A51), strokeWidth: 3)
                                : const Icon(Icons.camera_alt, color: Color(0xFF414A51), size: 34),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
