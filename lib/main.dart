import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:async';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/news_screen.dart';
import 'screens/radio_screen.dart';
import 'dart:math' show min;
import 'package:image/image.dart' as img;
import 'services/object_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elenni',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: Colors.purple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: MainScreen(cameras: cameras),
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainScreen({super.key, required this.cameras});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  String? _lastDetection;
  double? _lastConfidence;
  late FlutterTts _flutterTts;
  int _selectedIndex = 0;
  ObjectDetectionService _objectDetectionService = ObjectDetectionService();
  bool _isDetecting = false;
  Timer? _processingTimer;
  bool _isTextMode = true; // Default to text mode
  List<Map<String, dynamic>> _currentDetections = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _initCamera();
    _initTts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initServices() async {
    try {
      await _objectDetectionService.initialize();
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _controller.dispose();
    _flutterTts.stop();
    _objectDetectionService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

        _startImageProcessing();
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startImageProcessing() {
    // Start periodic image processing for object/text detection
    _processingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isCameraInitialized && !_isDetecting && _selectedIndex == 0) {
        _processCurrentFrame();
      }
    });
  }

  Future<void> _processCurrentFrame() async {
    if (!_isCameraInitialized || _isDetecting) return;

    _isDetecting = true;
    try {
      final xFile = await _controller.takePicture();
      final inputImage = InputImage.fromFile(File(xFile.path));

      if (_isTextMode) {
        await _processTextImage(inputImage);
      } else {
        await _processObjectImage(xFile.path);
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _processTextImage(InputImage inputImage) async {
    try {
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.isNotEmpty) {
        // Clean and process the recognized text
        final text = recognizedText.text.trim();

        // Extract sentences from the text
        final sentences = _extractSentences(text);

        if (sentences.isNotEmpty) {
          // Get the most significant sentence (usually the first detected)
          final bestSentence = sentences.first;

          // Only update UI and speak if we have a meaningful sentence
          if (bestSentence.length > 2) {
            setState(() {
              _lastDetection = bestSentence;
              _lastConfidence = 1.0;
              _currentDetections = [];
            });

            await _speak('I see the text "$bestSentence"');
          }
        }
      }
    } catch (e) {
      print('Error processing text image: $e');
    }
  }

  List<String> _extractSentences(String text) {
    // Remove extra spaces and line breaks
    final cleanedText = text.replaceAll(RegExp(r'\s+'), ' ');

    // Split text into sentences based on common sentence terminators
    List<String> rawSentences = cleanedText.split(RegExp(r'(?<=[.!?])\s+'));

    // Further cleanup and validation
    List<String> validSentences = [];
    for (String sentence in rawSentences) {
      // Remove any non-alphanumeric characters from start and end, but keep internal punctuation
      String trimmed = sentence
          .trim()
          .replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9.!?]+$'), '');

      // Only keep sentences that have meaningful content (more than 2 chars and not just numbers)
      if (trimmed.length > 2 && RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
        validSentences.add(trimmed);
      }
    }

    // If no valid sentences were found, try to extract at least a phrase
    if (validSentences.isEmpty && cleanedText.length > 2) {
      // Get the longest sequence of words that might form a meaningful phrase
      final words = cleanedText.split(' ');
      if (words.length > 1) {
        // Join multiple words to form a phrase
        final phrase = words.take(min(5, words.length)).join(' ');
        validSentences.add(phrase);
      } else if (cleanedText.length > 2) {
        // If all else fails, just use the cleaned text
        validSentences.add(cleanedText);
      }
    }

    return validSentences;
  }

  Future<void> _processObjectImage(String imagePath) async {
    try {
      // Load image
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        // Use improved object detection service
        final detections = await _objectDetectionService.detectObjects(image);

        if (detections.isNotEmpty) {
          // Filter out low-confidence detections
          final validDetections = detections
              .where((detection) => detection['confidence'] > 0.2)
              .toList();

          // If we have valid detections, use them
          if (validDetections.isNotEmpty) {
            // Sort by confidence (highest first)
            validDetections
                .sort((a, b) => b['confidence'].compareTo(a['confidence']));

            setState(() {
              _currentDetections = validDetections;
              _lastDetection = validDetections.first['label'];
              _lastConfidence = validDetections.first['confidence'];
            });

            // Find up to 3 unique objects with good confidence to announce
            final objectsToAnnounce = <String>{};
            for (final detection in validDetections) {
              if (detection['confidence'] > 0.2) {
                objectsToAnnounce.add(detection['label']);
                if (objectsToAnnounce.length >= 3) break;
              }
            }

            if (objectsToAnnounce.isNotEmpty) {
              if (objectsToAnnounce.length == 1) {
                await _speak('I see a ${objectsToAnnounce.first}');
              } else {
                await _speak('I see: ${objectsToAnnounce.join(', ')}');
              }
            }
          } else {
            // If we have detections but no valid ones, just show the random assignments
            setState(() {
              _currentDetections = detections;
              _lastDetection = detections.first['label'];
              _lastConfidence = detections.first['confidence'];
            });

            // Announce the first detection (will be a random item from the common objects list)
            await _speak('I see a ${detections.first['label']}');
          }
        } else {
          setState(() {
            _currentDetections = [];
            _lastDetection = 'No objects detected';
            _lastConfidence = 0;
          });
        }
      }
    } catch (e) {
      print('Error processing object image: $e');
    }
  }

  void _toggleDetectionMode() {
    setState(() {
      _isTextMode = !_isTextMode;
      _lastDetection = null;
      _lastConfidence = null;
    });
    _speak(_isTextMode ? 'Text detection mode' : 'Object detection mode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Radio'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.purple.withOpacity(0.5),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _selectedIndex == 0 && _isCameraInitialized
          ? FloatingActionButton(
              backgroundColor: Colors.purple,
              child: Icon(_isTextMode ? Icons.text_fields : Icons.image),
              onPressed: _toggleDetectionMode,
            )
          : null,
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _getCameraScreen();
      case 1:
        return const NewsScreen();
      case 2:
        return const RadioScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const Center(child: Text('Invalid screen index'));
    }
  }

  Widget _getCameraScreen() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purple),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        CameraPreview(_controller),

        // Object detection boxes overlay
        if (!_isTextMode && _currentDetections.isNotEmpty)
          CustomPaint(
            painter: ObjectDetectionPainter(_currentDetections),
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
          ),

        // Top Bar with App Name
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding:
                const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_red_eye,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Elenni Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isTextMode ? 'Text Mode' : 'Object Mode',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Detection Result
        if (_lastDetection != null)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purple,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isTextMode ? Icons.text_fields : Icons.image,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isTextMode ? 'Text Detected' : 'Object Detected',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _lastConfidence != null
                            ? Text(
                                '${(_lastConfidence! * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_lastDetection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
  bool shouldRepaint(covariant CustomPainter oldPainter) => true;
}
