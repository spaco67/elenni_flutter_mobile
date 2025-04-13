import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/object_detection_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  ObjectDetectionService? _objectDetectionService;
  FlutterTts? _flutterTts;
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;
  String? _lastDetectedObject;
  DateTime? _lastAnnouncementTime;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _currentDetections = [];
  String _status = "Initializing...";
  Timer? _detectionTimer;
  int _consecutiveEmptyDetections = 0;
  bool _permissionDenied = false;
  bool _isTextDetectionMode = false;
  String? _lastDetectedText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isGranted) {
      _initializeServices();
    } else {
      setState(() {
        _permissionDenied = true;
        _status = "Camera permission denied";
      });
    }
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

  void _toggleDetectionMode() {
    setState(() {
      _isTextDetectionMode = !_isTextDetectionMode;
      if (_isTextDetectionMode) {
        _status = "Text recognition mode activated";
        _flutterTts
            ?.speak("Text recognition mode activated. Point camera at text.");
      } else {
        _status = "Object detection mode activated";
        _flutterTts
            ?.speak("Object detection mode activated. Scanning for objects.");
      }
    });
  }

  Future<void> _initializeServices() async {
    setState(() {
      _status = "Initializing services...";
    });

    try {
      // Initialize object detection
      _objectDetectionService = ObjectDetectionService();
      await _objectDetectionService!.initialize();

      // Initialize text recognition
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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

      // Print available cameras for debugging
      for (var i = 0; i < cameras.length; i++) {
        debugPrint(
            'Camera $i: ${cameras[i].name}, ${cameras[i].lensDirection}');
      }

      // Use the back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Dispose of previous controller if it exists
      await _controller?.dispose();

      // Initialize the controller
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.jpeg, // Use JPEG for better compatibility
      );

      _controller = controller;

      // Initialize controller
      await controller.initialize();

      // Set flash mode to auto for low light conditions
      await controller.setFlashMode(FlashMode.auto);

      // Set initialized
      setState(() {
        _isInitialized = true;
        _status = "Ready! Scanning for objects...";
      });

      // Start detection using a timer for regular intervals
      _startPeriodicDetection();

      // Announce that app is ready
      await _flutterTts?.speak("Eleni Assistant ready. Scanning for objects.");
    } catch (e) {
      setState(() {
        _status = "Error initializing camera: $e";
      });
      debugPrint('Error initializing camera: $e');

      // Try reinitializing after a delay if it failed
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isInitialized) {
          _initializeCamera();
        }
      });
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
      // Automatically control flash based on scene detection
      // In newer versions of android, FlashMode.auto handles this well
      try {
        await _controller!.setFlashMode(FlashMode.auto);
      } catch (e) {
        // If we can't set flash, just continue
        debugPrint('Flash control error: $e');
      }

      // Take a picture instead of using image stream
      final xFile = await _controller!.takePicture();
      debugPrint('Captured image: ${xFile.path}');

      // Process the image
      final File imageFile = File(xFile.path);
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist');
        return;
      }

      final bytes = await imageFile.readAsBytes();
      debugPrint('Image size: ${bytes.length} bytes');

      // Choose between text recognition or object detection based on mode
      if (_isTextDetectionMode) {
        await _processTextRecognition(imageFile);
      } else {
        await _processObjectDetection(imageFile, bytes);
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

  Future<void> _processTextRecognition(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer?.processImage(inputImage);

      if (recognizedText != null && recognizedText.text.isNotEmpty) {
        debugPrint('Recognized text: ${recognizedText.text}');

        setState(() {
          _status = "Text detected: ${recognizedText.text.length} characters";
        });

        // Only announce if it's new text and not too similar to the last one
        if (_lastDetectedText == null ||
            !_isSimilarText(_lastDetectedText!, recognizedText.text)) {
          _lastDetectedText = recognizedText.text;

          // Provide haptic feedback
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 200);
          }

          // Speak the detected text
          await _flutterTts?.speak(recognizedText.text);
          debugPrint("Reading text: ${recognizedText.text}");
        }
      } else {
        setState(() {
          _status = "No text detected";
        });
      }
    } catch (e) {
      debugPrint('Error in text recognition: $e');
    }
  }

  bool _isSimilarText(String text1, String text2) {
    // If either text is very short, require exact match
    if (text1.length < 10 || text2.length < 10) {
      return text1 == text2;
    }

    // For longer text, allow some difference
    // Using Levenshtein distance would be better but this is simpler
    final minLength = min(text1.length, text2.length);
    final maxLength = max(text1.length, text2.length);

    // If length differs by more than 20%, consider them different
    if (minLength / maxLength < 0.8) {
      return false;
    }

    // Check if they share significant common substring
    for (int i = 0; i < minLength - 10; i++) {
      final substring = text1.substring(i, i + 10);
      if (text2.contains(substring)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _processObjectDetection(
      File imageFile, List<int> imageBytes) async {
    Uint8List uint8List = Uint8List.fromList(imageBytes);
    final img.Image? capturedImage = img.decodeImage(uint8List);

    if (capturedImage == null) {
      debugPrint('Failed to decode captured image');
      return;
    }

    debugPrint('Image decoded: ${capturedImage.width}x${capturedImage.height}');

    // Resize image to improve performance
    final img.Image resizedImage = img.copyResize(
      capturedImage,
      width: 640, // Larger size for better detection
      height: 640 * capturedImage.height ~/ capturedImage.width,
    );

    // Detect objects
    final detections =
        await _objectDetectionService?.detectObjects(resizedImage) ?? [];

    if (mounted) {
      setState(() {
        _currentDetections = detections;
        if (detections.isEmpty) {
          _consecutiveEmptyDetections++;
          if (_consecutiveEmptyDetections > 3) {
            _status = "No objects detected";
          }
        } else {
          _consecutiveEmptyDetections = 0;
          _status = "${detections.length} objects detected";
        }
      });
    }

    // Log the detections
    if (detections.isNotEmpty) {
      for (var detection in detections) {
        debugPrint(
            'Detection: ${detection['label']} (${detection['confidence']})');
      }
    }

    // Announce the most confident detection
    if (detections.isNotEmpty) {
      // Filter high confidence detections - lower threshold for better detection
      final highConfidenceDetections =
          detections.where((d) => (d['confidence'] as double) > 0.30).toList();

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
              now.difference(_lastAnnouncementTime!).inSeconds >= 1.5) {
            _lastAnnouncementTime = now;

            // Provide haptic feedback
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 200);
            }

            // Announce the specific object name
            final announcement = "I see a $label";
            await _flutterTts?.speak(announcement);
            debugPrint("Announced: $announcement");
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _stopDetection();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _objectDetectionService?.dispose();
    _textRecognizer?.close();
    _flutterTts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                "Camera permission denied",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _requestPermissions(),
                child: const Text("Request Permission"),
              ),
            ],
          ),
        ),
      );
    }

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

          // Bounding boxes (only show in object detection mode)
          if (!_isTextDetectionMode)
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

          // Header bar with name and mode toggle
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Eleni Assistant",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _toggleDetectionMode,
                    icon: Icon(_isTextDetectionMode
                        ? Icons.camera
                        : Icons.text_fields),
                    label: Text(
                        _isTextDetectionMode ? "Object Mode" : "Text Mode"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isTextDetectionMode ? Colors.blue : Colors.green,
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
}

int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b;

class ObjectDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  ObjectDetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
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

      // Draw bounding box with more prominent styling
      canvas.drawRect(scaledRect, paint);

      // Add a second outline for better visibility
      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.yellow;

      // Draw slightly larger outer box
      final outerRect = Rect.fromLTRB(
        scaledRect.left - 2,
        scaledRect.top - 2,
        scaledRect.right + 2,
        scaledRect.bottom + 2,
      );
      canvas.drawRect(outerRect, outerPaint);

      // Background for text
      final backgroundPaint = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.fill;

      // Draw label with background
      textPainter.text = TextSpan(
        text: '$label ($confidence)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();

      final textBackgroundRect = Rect.fromLTWH(
        scaledRect.left,
        scaledRect.top - textPainter.height - 8,
        textPainter.width + 16,
        textPainter.height + 8,
      );

      canvas.drawRect(textBackgroundRect, backgroundPaint);
      textPainter.paint(
        canvas,
        Offset(scaledRect.left + 8, scaledRect.top - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(ObjectDetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
