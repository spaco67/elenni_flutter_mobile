import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class TextReadingScreen extends StatefulWidget {
  const TextReadingScreen({super.key});

  @override
  State<TextReadingScreen> createState() => _TextReadingScreenState();
}

class _TextReadingScreenState extends State<TextReadingScreen> {
  CameraController? _controller;
  FlutterTts _flutterTts = FlutterTts();
  bool _isProcessing = false;
  String _detectedText = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTts();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      // TODO: Handle no camera available
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // TODO: Handle camera initialization error
    }
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _startTextRecognition() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectedText = '';
    });

    // TODO: Implement OCR logic
    // This is where we'll integrate Tesseract OCR
    await Future.delayed(const Duration(seconds: 2));

    // Simulated OCR results
    _detectedText =
        'Sample text detected from the image. This is a placeholder for actual OCR results.';

    // Provide haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 200);
    }

    // Speak the results
    await _flutterTts.speak(_detectedText);

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Text Results Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected Text:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detectedText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Recognition Button
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isProcessing ? null : _startTextRecognition,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.text_fields),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
