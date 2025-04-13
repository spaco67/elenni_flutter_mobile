import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:async';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

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
  late ObjectDetector _objectDetector;
  bool _isDetecting = false;
  Timer? _processingTimer;
  bool _isTextMode = true; // Default to text mode

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initObjectDetector();
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

  Future<void> _initObjectDetector() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
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
    _objectDetector.close();
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
        await _processObjectImage(inputImage);
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
        // Split text into words and filter out noise
        final words = recognizedText.text
            .split(RegExp(r'[\s\n]+'))
            .where((word) => word.length > 2)
            .where((word) => !word.contains(RegExp(r'[^a-zA-Z0-9]')))
            .toList();

        if (words.isNotEmpty) {
          final bestWord = words.first;
          setState(() {
            _lastDetection = bestWord;
            _lastConfidence = 1.0;
          });

          await _speak('I see the text "$bestWord"');
        }
      }
    } catch (e) {
      print('Error processing text image: $e');
    }
  }

  Future<void> _processObjectImage(InputImage inputImage) async {
    try {
      final objects = await _objectDetector.processImage(inputImage);
      if (objects.isNotEmpty) {
        // Get the object with highest confidence
        final detectedObject = objects.reduce((curr, next) =>
            curr.labels.first.confidence > next.labels.first.confidence
                ? curr
                : next);

        if (detectedObject.labels.isNotEmpty) {
          final label = detectedObject.labels.first;
          setState(() {
            _lastDetection = label.text;
            _lastConfidence = label.confidence;
          });

          await _speak('I see a ${label.text}');
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Camera'),
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
        return const HistoryScreen();
      case 2:
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
