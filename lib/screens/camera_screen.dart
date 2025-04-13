import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/object_detection_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  ObjectDetectionService? _objectDetectionService;
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  String? _lastDetectedObject;
  DateTime? _lastAnnouncementTime;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _currentDetections = [];
  String _status = "Initializing...";
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _initializeCamera();
      }
    }
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _initializeServices() async {
    setState(() {
      _status = "Initializing services...";
    });

    try {
      // Initialize object detection first
      _objectDetectionService = ObjectDetectionService();
      await _objectDetectionService!.initialize();

      // Initialize TTS
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setVolume(1.0);

      setState(() {
        _status = "Services initialized, setting up camera...";
      });

      await _initializeCamera();
    } catch (e) {
      setState(() {
        _status = "Error initializing services: $e";
      });
      debugPrint("Error initializing services: $e");
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _status = "No cameras available";
        });
        return;
      }

      // Use the back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Initialize the controller
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller = controller;

      // Initialize controller
      await controller.initialize();

      // Set initialized
      setState(() {
        _isInitialized = true;
        _status = "Ready! Scanning for objects...";
      });

      // Start detection using a timer for regular intervals
      _startPeriodicDetection();

      // Announce that app is ready
      await _flutterTts?.speak("Camera ready. Scanning for objects.");
    } catch (e) {
      setState(() {
        _status = "Error initializing camera: $e";
      });
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startPeriodicDetection() {
    // Clean up previous timer if exists
    _stopDetection();

    // Start a periodic timer to capture images for detection
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isProcessing &&
          _isInitialized &&
          _controller != null &&
          _controller!.value.isInitialized) {
        _captureAndDetect();
      }
    });
  }

  Future<void> _captureAndDetect() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Take a picture instead of using image stream
      final xFile = await _controller!.takePicture();

      // Process the image
      final File imageFile = File(xFile.path);
      final img.Image? capturedImage =
          img.decodeImage(await imageFile.readAsBytes());

      if (capturedImage == null) {
        debugPrint('Failed to decode captured image');
        return;
      }

      // Resize image to improve performance
      final img.Image resizedImage = img.copyResize(
        capturedImage,
        width: 300,
        height: 300 * capturedImage.height ~/ capturedImage.width,
      );

      // Detect objects
      final detections =
          await _objectDetectionService?.detectObjects(resizedImage) ?? [];

      if (mounted) {
        setState(() {
          _currentDetections = detections;
          if (detections.isEmpty) {
            _status = "No objects detected";
          } else {
            _status = "${detections.length} objects detected";
          }
        });
      }

      // Announce the most confident detection
      if (detections.isNotEmpty) {
        // Filter high confidence detections
        final highConfidenceDetections =
            detections.where((d) => (d['confidence'] as double) > 0.6).toList();

        if (highConfidenceDetections.isNotEmpty) {
          // Sort by confidence
          highConfidenceDetections.sort((a, b) =>
              (b['confidence'] as double).compareTo(a['confidence'] as double));

          final bestDetection = highConfidenceDetections.first;
          final label = bestDetection['label'] as String;
          final confidence = bestDetection['confidence'] as double;

          debugPrint("Best detection: $label with confidence $confidence");

          // Only announce if it's a new object
          if (label != _lastDetectedObject) {
            _lastDetectedObject = label;

            // Check if enough time has passed since last announcement
            final now = DateTime.now();
            if (_lastAnnouncementTime == null ||
                now.difference(_lastAnnouncementTime!).inSeconds >= 2) {
              _lastAnnouncementTime = now;

              // Provide haptic feedback
              if (await Vibration.hasVibrator() ?? false) {
                Vibration.vibrate(duration: 200);
              }

              // Announce the object
              await _flutterTts?.speak(label);
              debugPrint("Announced: $label");
            }
          }
        }
      }

      // Clean up the image file
      try {
        await imageFile.delete();
      } catch (e) {
        // Ignore file deletion errors
      }
    } catch (e) {
      debugPrint('Error capturing and detecting: $e');
      if (mounted) {
        setState(() {
          _status = "Error: $e";
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _stopDetection();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _objectDetectionService?.dispose();
    _flutterTts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(_controller!),

          // Bounding boxes
          CustomPaint(
            painter: ObjectDetectionPainter(_currentDetections),
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
          ),

          // Status text at bottom
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black54,
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjectDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  ObjectDetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    for (final detection in detections) {
      final Rect boundingBox = detection['boundingBox'] as Rect;

      // Scale bounding box to fit the screen
      final double scaleX = size.width;
      final double scaleY = size.height;

      final Rect scaledRect = Rect.fromLTRB(
        boundingBox.left * scaleX,
        boundingBox.top * scaleY,
        boundingBox.right * scaleX,
        boundingBox.bottom * scaleY,
      );

      final confidence = (detection['confidence'] as double).toStringAsFixed(2);
      final label = detection['label'] as String;

      // Draw bounding box (use scaled rect)
      canvas.drawRect(scaledRect, paint);

      // Background for text
      final backgroundPaint = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.fill;

      // Draw label with background
      textPainter.text = TextSpan(
        text: '$label ($confidence)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();

      final textBackgroundRect = Rect.fromLTWH(
        scaledRect.left,
        scaledRect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRect(textBackgroundRect, backgroundPaint);
      textPainter.paint(
        canvas,
        Offset(scaledRect.left + 4, scaledRect.top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(ObjectDetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
