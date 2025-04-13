import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:tesseract_ocr/tesseract_ocr.dart';

class OCRService {
  static const String _tessDataPath = 'assets/tessdata';
  bool _isInitialized = false;
  late String _tessDataDir;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      _tessDataDir = path.join(appDir.path, 'tessdata');

      // Create tessdata directory if it doesn't exist
      final dir = Directory(_tessDataDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Copy trained data files
      await _copyTrainedData();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing OCR: $e');
      rethrow;
    }
  }

  Future<void> _copyTrainedData() async {
    // TODO: Implement copying of trained data files from assets to _tessDataDir
    // This will require adding the trained data files to the assets directory
  }

  Future<String> recognizeText(img.Image image) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Convert image to bytes
      final bytes = img.encodeJpg(image);

      // Perform OCR
      final text = await TesseractOcr.extractText(
        bytes,
        language: 'eng',
        args: {
          'psm': '3', // Page segmentation mode
          'oem': '3', // OCR Engine mode
        },
      );

      return text.trim();
    } catch (e) {
      debugPrint('Error performing OCR: $e');
      return '';
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
