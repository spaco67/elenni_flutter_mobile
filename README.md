# Elenni Accessibility Assistant

An app for the blind with offline object detection, OCR, and haptic feedback capabilities.

## Features

- Object Detection: Identify objects in the environment using TensorFlow Lite
- Text Reading: Read text from images using Tesseract OCR
- Haptic Feedback: Provide tactile feedback for interactions
- Voice Feedback: Read out detected objects and text

## Setup Instructions

### Required Files

1. Object Detection Model:
   - Download the SSD MobileNet v2 model from TensorFlow Hub
   - Convert it to TensorFlow Lite format
   - Place the model file at `assets/models/ssd_mobilenet.tflite`

2. COCO Labels:
   - Download the COCO labels file
   - Place it at `assets/labels/coco_labels.txt`

3. Tesseract Trained Data:
   - Download the English trained data file from Tesseract
   - Place it at `assets/tessdata/eng.traineddata`

### Development Setup

1. Install Flutter and required dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

- `lib/`
  - `screens/`: App screens
  - `services/`: Core functionality services
  - `widgets/`: Reusable UI components
  - `models/`: Data models

## Dependencies

- Flutter
- TensorFlow Lite
- Tesseract OCR
- Camera
- Text-to-Speech
- Vibration

## License

MIT License
