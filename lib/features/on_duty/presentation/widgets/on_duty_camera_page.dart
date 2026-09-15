import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Camera permission was denied. Please allow camera access in device Settings to capture live arrival proof.';
            _isInitializing = false;
          });
        }
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No live camera device detected on this phone.';
            _isInitializing = false;
          });
        }
        return;
      }

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to initialize live camera ($e).';
          _isInitializing = false;
        });
      }
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
        _errorMessage = 'Error initializing live camera preview: $e';
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
    setState(() => _isCapturing = true);

    try {
      if (_controller != null && _controller!.value.isInitialized) {
        final file = await _controller!.takePicture();
        final bytes = await file.readAsBytes();
        List<int> compressedBytes = bytes;
        try {
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final resized = img.copyResize(
              decoded,
              width: decoded.width > 800 ? 800 : decoded.width,
            );
            compressedBytes = img.encodeJpg(resized, quality: 70);
          }
        } catch (_) {}
        final base64Image = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64Image);
          return;
        }
      }
    } catch (e) {
      // Fall through to system camera fallback if custom camera fails
    }

    // System Camera Fallback (Live Photo only)
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final base64Image = 'data:image/$ext;base64,${base64Encode(bytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64Image);
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open live camera: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
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
      body: Stack(
        children: [
          // 1. Edge-to-Edge Full Screen Live Camera Preview
          Positioned.fill(
            child: _buildCameraPreview(),
          ),

          // 4. Floating Top Navigation & Title Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_cameras.length > 1)
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                          tooltip: 'Flip Camera',
                          onPressed: _isInitializing || _isCapturing ? null : _switchCamera,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Floating Bottom Shutter Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _isCapturing || _isInitializing ? null : _capturePhoto,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: const Color(0xFF9CC70A),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isCapturing
                            ? const CircularProgressIndicator(color: Color(0xFF414A51), strokeWidth: 3.5)
                            : const Icon(Icons.camera_alt_rounded, color: Color(0xFF414A51), size: 36),
                      ),
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

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF1E293B),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isCapturing ? null : _capturePhoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Open System Live Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
        ),
      );
    }

    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (_controller!.value.aspectRatio * mediaSize.aspectRatio);

    return Transform.scale(
      scale: scale < 1.0 ? 1 / scale : scale,
      child: Center(
        child: CameraPreview(_controller!),
      ),
    );
  }
}
