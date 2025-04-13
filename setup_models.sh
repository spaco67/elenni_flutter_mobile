#!/bin/bash

# Create necessary directories
mkdir -p assets/models assets/labels assets/tessdata

# Download COCO labels
echo "Downloading COCO labels..."
curl -L https://raw.githubusercontent.com/tensorflow/models/master/research/object_detection/data/mscoco_label_map.pbtxt -o assets/labels/coco_labels.txt

# Download pre-trained Tesseract data
echo "Downloading Tesseract trained data..."
curl -L https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata -o assets/tessdata/eng.traineddata

# Download pre-converted TensorFlow Lite model
echo "Downloading TensorFlow Lite model..."
curl -L https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip -o coco_ssd_mobilenet.zip
unzip coco_ssd_mobilenet.zip -d assets/models/
mv assets/models/detect.tflite assets/models/ssd_mobilenet.tflite
mv assets/models/labelmap.txt assets/labels/coco_labels.txt
rm coco_ssd_mobilenet.zip

echo "Setup complete! Model files are in the assets directory." 