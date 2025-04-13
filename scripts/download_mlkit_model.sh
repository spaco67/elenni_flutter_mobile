#!/bin/bash

# Create necessary directories
mkdir -p assets/models

# Download the ML Kit object detection model
curl -L "https://storage.googleapis.com/mlkit-models/object-detection/object_labeler.tflite" -o "assets/models/object_labeler.tflite"

echo "ML Kit model downloaded successfully!" 